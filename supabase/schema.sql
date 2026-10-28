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
-- TRUNCATE n'est pas soumis au RLS : on le retire (Supabase le donne par défaut à anon et authenticated).
revoke update, delete, truncate on public.profiles from authenticated, anon;
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
revoke update, delete, truncate on public.owned_cards from authenticated, anon;

-- ---------------------------------------------------------------------------
-- Runs : chaque run est ouverte puis fermée par le serveur (début de l'anti-triche).
-- Le joueur ne peut ni écrire ni modifier cette table directement : tout passe par
-- start_run() et finish_run(), qui vérifient les limites du jeu.
-- Les nombres ci-dessous doivent rester égaux à lib/core/config.dart et economy.dart
-- (un test le vérifie : test/core_test.dart, groupe « Serveur »).
-- ---------------------------------------------------------------------------
create table if not exists public.runs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  started_at  timestamptz not null default now(),
  finished_at timestamptz,
  kills       int not null default 0 check (kills >= 0),
  coins       int not null default 0 check (coins >= 0),
  cards       int not null default 0 check (cards between 0 and 3)
);

create index if not exists runs_user_idx on public.runs (user_id, started_at);

alter table public.runs enable row level security;

drop policy if exists "runs : lecture des siennes" on public.runs;
create policy "runs : lecture des siennes" on public.runs
  for select to authenticated using ((select auth.uid()) = user_id);

revoke insert, update, delete, truncate on public.runs from authenticated, anon;

-- Ouvre une run. Refuse au-delà de 15 runs par jour (10 gratuites + 5 énergies au plus).
-- PROVISOIRE : jour compté en heure de Paris ; les énergies achetées ne sont pas encore
-- vérifiées (les pièces sont sur l'appareil), d'où la limite large de 15.
create or replace function public.start_run() returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  runs_per_day constant int := 10;
  max_energies_per_day constant int := 5;
  today_start timestamptz := date_trunc('day', now() at time zone 'Europe/Paris') at time zone 'Europe/Paris';
  rid uuid;
begin
  if uid is null then raise exception 'non connecté' using errcode = '28000'; end if;
  if (select count(*) from public.runs r where r.user_id = uid and r.started_at >= today_start)
     >= runs_per_day + max_energies_per_day then
    raise exception 'limite de runs du jour atteinte' using errcode = 'P0001';
  end if;
  insert into public.runs (user_id) values (uid) returning id into rid;
  return rid;
end $$;

-- Ferme une run et ajoute ses cartes à la collection. p_cards = [{"card_id": 12, "seed": 345}, …].
-- Refuse : run d'un autre joueur ou déjà fermée, plus de 3 cartes, carte inconnue, run fermée
-- trop tard (30 min), ou nombre d'ennemis impossible pour la durée (2 par seconde au plus).
-- Renvoie le nombre d'exemplaires réellement ajoutés (les doublons exacts sont ignorés).
-- PROVISOIRE : la rareté des cartes n'est pas encore contrôlée (tirage fait par l'appli).
create or replace function public.finish_run(p_run uuid, p_kills int, p_coins int, p_cards jsonb)
returns int
language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  max_cards constant int := 3;
  max_minutes constant int := 30;
  max_kills_per_second constant int := 2;
  r public.runs%rowtype;
  secs double precision;
  n int;
  added int;
begin
  if uid is null then raise exception 'non connecté' using errcode = '28000'; end if;
  select * into r from public.runs where id = p_run and user_id = uid for update;
  if not found then raise exception 'run inconnue' using errcode = 'P0002'; end if;
  if r.finished_at is not null then raise exception 'run déjà terminée' using errcode = 'P0001'; end if;
  secs := extract(epoch from now() - r.started_at);
  if secs > max_minutes * 60 then raise exception 'run expirée' using errcode = 'P0001'; end if;
  if p_kills is null or p_kills < 0 or p_kills > greatest(1, ceil(secs)) * max_kills_per_second then
    raise exception 'nombre d''ennemis invalide' using errcode = 'P0001';
  end if;
  if p_coins is null or p_coins < 0 then raise exception 'pièces invalides' using errcode = 'P0001'; end if;
  if p_cards is null or jsonb_typeof(p_cards) <> 'array' then p_cards := '[]'::jsonb; end if;
  n := jsonb_array_length(p_cards);
  if n > max_cards then raise exception 'trop de cartes' using errcode = 'P0001'; end if;
  if exists (
    select 1 from jsonb_array_elements(p_cards) e
    where jsonb_typeof(e -> 'card_id') <> 'number' or jsonb_typeof(e -> 'seed') <> 'number'
       or (e ->> 'card_id')::numeric not between 1 and 300
       or (e ->> 'seed')::numeric < 0 or (e ->> 'seed')::numeric > 9223372036854775807
  ) then
    raise exception 'carte invalide' using errcode = 'P0001';
  end if;

  update public.runs set finished_at = now(), kills = p_kills, coins = p_coins, cards = n where id = r.id;
  insert into public.owned_cards (user_id, card_id, seed)
  select uid, (e ->> 'card_id')::smallint, (e ->> 'seed')::bigint from jsonb_array_elements(p_cards) e
  on conflict (user_id, card_id, seed) do nothing;
  get diagnostics added = row_count;
  return added;
end $$;

-- Statistiques du profil, calculées sur les runs terminées.
create or replace function public.my_stats()
returns table (runs bigint, kills bigint, cards bigint, best_kills int)
language sql stable security invoker set search_path = '' as $$
  select count(*), coalesce(sum(r.kills), 0), coalesce(sum(r.cards), 0), coalesce(max(r.kills), 0)
  from public.runs r
  where r.user_id = (select auth.uid()) and r.finished_at is not null
$$;

revoke execute on function public.start_run(), public.finish_run(uuid, int, int, jsonb), public.my_stats()
  from public, anon;
grant execute on function public.start_run(), public.finish_run(uuid, int, int, jsonb), public.my_stats()
  to authenticated;
