-- Collectear – schéma de la base en ligne (Supabase / PostgreSQL)
--
-- À coller une seule fois dans Supabase : SQL Editor → New query → coller → Run.
-- Le script est ré-exécutable sans risque (il ne supprime aucune donnée).
--
-- Sécurité : le RLS (Row Level Security) est activé sur toutes les tables. Avec la clé publique
-- embarquée dans l'app, un joueur ne peut lire et écrire QUE ses propres lignes.

-- ---------------------------------------------------------------------------
-- Profils : une ligne par compte, créée automatiquement à l'inscription.
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  friend_code  text not null unique,
  display_name text not null default 'Explorateur'
               check (char_length(display_name) between 1 and 24),
  created_at   timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profil : lecture du sien" on public.profiles;
create policy "profil : lecture du sien" on public.profiles
  for select to authenticated using ((select auth.uid()) = id);

drop policy if exists "profil : modification du sien" on public.profiles;
create policy "profil : modification du sien" on public.profiles
  for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- Le code ami ne doit pas être modifiable par le joueur (seul le pseudo l'est).
revoke update on public.profiles from authenticated, anon;
grant update (display_name) on public.profiles to authenticated;

-- Code ami : 8 caractères sans ambiguïté (pas de 0/O, 1/I).
create or replace function public.new_friend_code() returns text
language plpgsql volatile set search_path = '' as $$
declare
  chars constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text;
begin
  loop
    code := '';
    for i in 1..8 loop
      code := code || substr(chars, 1 + floor(random() * length(chars))::int, 1);
    end loop;
    exit when not exists (select 1 from public.profiles p where p.friend_code = code);
  end loop;
  return code;
end $$;

-- Création automatique du profil quand un compte est créé.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, friend_code) values (new.id, public.new_friend_code())
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Profils des comptes créés avant ce script (au cas où).
insert into public.profiles (id, friend_code)
select u.id, public.new_friend_code() from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id);

-- ---------------------------------------------------------------------------
-- Collection : un exemplaire = une carte (1 à 300) + la seed de sa variante.
-- ---------------------------------------------------------------------------
create table if not exists public.owned_cards (
  id          bigint generated always as identity primary key,
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  card_id     smallint not null check (card_id between 1 and 300),
  seed        bigint not null check (seed >= 0),
  obtained_at timestamptz not null default now(),
  unique (user_id, card_id, seed)
);

create index if not exists owned_cards_user_idx on public.owned_cards (user_id);

alter table public.owned_cards enable row level security;

drop policy if exists "collection : lecture de la sienne" on public.owned_cards;
create policy "collection : lecture de la sienne" on public.owned_cards
  for select to authenticated using ((select auth.uid()) = user_id);

-- PROVISOIRE : le client ajoute lui-même ses cartes. La validation serveur des récompenses
-- (anti-triche, ROADMAP étape 3) remplacera cette règle par une fonction côté serveur.
drop policy if exists "collection : ajout dans la sienne" on public.owned_cards;
create policy "collection : ajout dans la sienne" on public.owned_cards
  for insert to authenticated with check ((select auth.uid()) = user_id);

-- Pas de modification ni de suppression par le joueur (les échanges passeront par le serveur).
revoke update, delete on public.owned_cards from authenticated, anon;
