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

-- ---------------------------------------------------------------------------
-- Amis : ajout par code ami. Une demande devient une amitié quand l'autre l'accepte
-- (ou ajoute lui aussi le code). Aucune écriture directe : tout passe par les fonctions.
-- ---------------------------------------------------------------------------
create table if not exists public.friendships (
  requester  uuid not null references auth.users (id) on delete cascade,
  addressee  uuid not null references auth.users (id) on delete cascade,
  status     text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  primary key (requester, addressee),
  check (requester <> addressee)
);

create index if not exists friendships_addressee_idx on public.friendships (addressee);

alter table public.friendships enable row level security;

drop policy if exists "amis : lecture des siens" on public.friendships;
create policy "amis : lecture des siens" on public.friendships
  for select to authenticated using ((select auth.uid()) in (requester, addressee));

revoke insert, update, delete, truncate on public.friendships from authenticated, anon;

-- Vrai si les deux comptes sont amis (demande acceptée, dans un sens ou dans l'autre).
create or replace function public.are_friends(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester = a and f.addressee = b) or (f.requester = b and f.addressee = a))
  )
$$;

-- Ajoute un ami par son code. Renvoie 'sent' (demande envoyée) ou 'accepted' (il t'avait déjà
-- demandé : vous êtes amis). Codes d'erreur lisibles par l'appli dans le message.
create or replace function public.add_friend(p_code text) returns text
language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  max_friends constant int := 200;
  other uuid;
  existing public.friendships%rowtype;
begin
  if uid is null then raise exception 'non connecté' using errcode = '28000'; end if;
  select p.id into other from public.profiles p
  where p.friend_code = upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  if other is null then raise exception 'code_inconnu' using errcode = 'P0001'; end if;
  if other = uid then raise exception 'code_perso' using errcode = 'P0001'; end if;
  if (select count(*) from public.friendships f where uid in (f.requester, f.addressee)) >= max_friends then
    raise exception 'trop_amis' using errcode = 'P0001';
  end if;
  select * into existing from public.friendships f
  where (f.requester = uid and f.addressee = other) or (f.requester = other and f.addressee = uid);
  if found then
    if existing.status = 'accepted' then raise exception 'deja_amis' using errcode = 'P0001'; end if;
    if existing.requester = uid then raise exception 'deja_demande' using errcode = 'P0001'; end if;
    update public.friendships set status = 'accepted'
    where requester = existing.requester and addressee = existing.addressee;
    return 'accepted';
  end if;
  insert into public.friendships (requester, addressee) values (uid, other);
  return 'sent';
end $$;

-- Répond à une demande reçue : accepter ou refuser (la demande est alors supprimée).
create or replace function public.respond_friend(p_other uuid, p_accept boolean) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then raise exception 'non connecté' using errcode = '28000'; end if;
  if p_accept then
    update public.friendships set status = 'accepted'
    where requester = p_other and addressee = uid and status = 'pending';
  else
    delete from public.friendships where requester = p_other and addressee = uid and status = 'pending';
  end if;
  if not found then raise exception 'demande_inconnue' using errcode = 'P0002'; end if;
end $$;

-- Retire un ami (ou annule une demande envoyée). Les échanges en attente entre vous sont annulés.
create or replace function public.remove_friend(p_other uuid) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then raise exception 'non connecté' using errcode = '28000'; end if;
  delete from public.friendships
  where (requester = uid and addressee = p_other) or (requester = p_other and addressee = uid);
  update public.trades set status = 'cancelled', resolved_at = now()
  where status = 'pending'
    and ((from_user = uid and to_user = p_other) or (from_user = p_other and to_user = uid));
end $$;

-- ---------------------------------------------------------------------------
-- Échanges : une carte contre une carte, entre amis, sans restriction de rareté
-- (décision de Clem). Les exemplaires changent de propriétaire seulement quand le
-- destinataire accepte ; les autres propositions sur ces exemplaires expirent alors.
-- ---------------------------------------------------------------------------
create table if not exists public.trades (
  id             bigint generated always as identity primary key,
  from_user      uuid not null references auth.users (id) on delete cascade,
  to_user        uuid not null references auth.users (id) on delete cascade,
  offered        bigint not null references public.owned_cards (id) on delete cascade,
  requested      bigint not null references public.owned_cards (id) on delete cascade,
  -- Copie de la carte et de sa variante, pour l'affichage et l'historique.
  offered_card   smallint not null,
  offered_seed   bigint not null,
  requested_card smallint not null,
  requested_seed bigint not null,
  status         text not null default 'pending'
                 check (status in ('pending', 'accepted', 'declined', 'cancelled', 'expired')),
  created_at     timestamptz not null default now(),
  resolved_at    timestamptz,
  check (from_user <> to_user)
);

create index if not exists trades_from_idx on public.trades (from_user, status);
create index if not exists trades_to_idx on public.trades (to_user, status);

alter table public.trades enable row level security;

drop policy if exists "échanges : lecture des siens" on public.trades;
create policy "échanges : lecture des siens" on public.trades
  for select to authenticated using ((select auth.uid()) in (from_user, to_user));

revoke insert, update, delete, truncate on public.trades from authenticated, anon;

-- Exemplaires donnés lors d'un échange : l'appli de celui qui l'a donné le retire de sa
-- collection locale, et le serveur refuse qu'il soit renvoyé en ligne par la synchro.
create table if not exists public.traded_away (
  user_id uuid not null references auth.users (id) on delete cascade,
  card_id smallint not null,
  seed    bigint not null,
  primary key (user_id, card_id, seed)
);

alter table public.traded_away enable row level security;

drop policy if exists "donnés : lecture des siens" on public.traded_away;
create policy "donnés : lecture des siens" on public.traded_away
  for select to authenticated using ((select auth.uid()) = user_id);

revoke insert, update, delete, truncate on public.traded_away from authenticated, anon;

create or replace function public.skip_traded_away() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.traded_away t
             where t.user_id = new.user_id and t.card_id = new.card_id and t.seed = new.seed) then
    return null; -- exemplaire déjà donné : ignoré sans erreur
  end if;
  return new;
end $$;

drop trigger if exists owned_cards_skip_traded on public.owned_cards;
create trigger owned_cards_skip_traded
  before insert on public.owned_cards
  for each row execute function public.skip_traded_away();

-- Propose un échange : p_offered = un de mes exemplaires (owned_cards.id), p_requested = un
-- exemplaire de l'ami. Renvoie l'identifiant de l'échange.
create or replace function public.propose_trade(p_to uuid, p_offered bigint, p_requested bigint) returns bigint
language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  max_pending constant int := 20;
  o public.owned_cards%rowtype;
  r public.owned_cards%rowtype;
  tid bigint;
begin
  if uid is null then raise exception 'non connecté' using errcode = '28000'; end if;
  if not public.are_friends(uid, p_to) then raise exception 'pas_ami' using errcode = 'P0001'; end if;
  select * into o from public.owned_cards where id = p_offered and user_id = uid;
  if not found then raise exception 'carte_offerte_absente' using errcode = 'P0001'; end if;
  select * into r from public.owned_cards where id = p_requested and user_id = p_to;
  if not found then raise exception 'carte_demandee_absente' using errcode = 'P0001'; end if;
  if (select count(*) from public.trades t where t.from_user = uid and t.status = 'pending') >= max_pending then
    raise exception 'trop_propositions' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.trades t where t.status = 'pending' and t.from_user = uid
             and t.offered = p_offered and t.requested = p_requested) then
    raise exception 'deja_propose' using errcode = 'P0001';
  end if;
  insert into public.trades (from_user, to_user, offered, requested, offered_card, offered_seed, requested_card, requested_seed)
  values (uid, p_to, o.id, r.id, o.card_id, o.seed, r.card_id, r.seed)
  returning id into tid;
  return tid;
end $$;

-- Accepte un échange reçu : les deux exemplaires changent de propriétaire.
-- Renvoie 'accepted', ou 'expired' si l'un des exemplaires n'est plus disponible.
create or replace function public.accept_trade(p_trade bigint) returns text
language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  t public.trades%rowtype;
  o public.owned_cards%rowtype;
  r public.owned_cards%rowtype;
begin
  if uid is null then raise exception 'non connecté' using errcode = '28000'; end if;
  select * into t from public.trades where id = p_trade and to_user = uid and status = 'pending' for update;
  if not found then raise exception 'echange_inconnu' using errcode = 'P0002'; end if;
  -- Verrouille les deux exemplaires dans un ordre fixe (pas d'interblocage entre deux acceptations).
  perform 1 from public.owned_cards where id in (t.offered, t.requested) order by id for update;
  select * into o from public.owned_cards where id = t.offered;
  select * into r from public.owned_cards where id = t.requested;
  if o.user_id is distinct from t.from_user or r.user_id is distinct from t.to_user
     or not public.are_friends(t.from_user, t.to_user)
     or exists (select 1 from public.owned_cards c where c.user_id = t.to_user and c.card_id = o.card_id and c.seed = o.seed)
     or exists (select 1 from public.owned_cards c where c.user_id = t.from_user and c.card_id = r.card_id and c.seed = r.seed)
  then
    update public.trades set status = 'expired', resolved_at = now() where id = t.id;
    return 'expired';
  end if;

  update public.owned_cards set user_id = t.to_user, obtained_at = now() where id = o.id;
  update public.owned_cards set user_id = t.from_user, obtained_at = now() where id = r.id;
  insert into public.traded_away (user_id, card_id, seed) values
    (t.from_user, o.card_id, o.seed), (t.to_user, r.card_id, r.seed)
  on conflict do nothing;
  delete from public.traded_away
  where (user_id = t.to_user and card_id = o.card_id and seed = o.seed)
     or (user_id = t.from_user and card_id = r.card_id and seed = r.seed);
  update public.trades set status = 'accepted', resolved_at = now() where id = t.id;
  update public.trades set status = 'expired', resolved_at = now()
  where status = 'pending' and id <> t.id
    and (offered in (o.id, r.id) or requested in (o.id, r.id));
  return 'accepted';
end $$;

-- Refuse (destinataire) ou annule (auteur) un échange en attente.
create or replace function public.close_trade(p_trade bigint) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then raise exception 'non connecté' using errcode = '28000'; end if;
  update public.trades
  set status = case when to_user = uid then 'declined' else 'cancelled' end, resolved_at = now()
  where id = p_trade and status = 'pending' and uid in (from_user, to_user);
  if not found then raise exception 'echange_inconnu' using errcode = 'P0002'; end if;
end $$;

-- Mes amis et demandes, avec leur pseudo et leur nombre de cartes différentes.
create or replace function public.list_friends()
returns table (user_id uuid, display_name text, friend_code text, status text, incoming boolean, species bigint)
language sql stable security definer set search_path = '' as $$
  select p.id, p.display_name, p.friend_code, f.status, f.addressee = (select auth.uid()),
         (select count(distinct c.card_id) from public.owned_cards c where c.user_id = p.id and f.status = 'accepted')
  from public.friendships f
  join public.profiles p on p.id = case when f.requester = (select auth.uid()) then f.addressee else f.requester end
  where (select auth.uid()) in (f.requester, f.addressee)
  order by f.status desc, p.display_name
$$;

-- Collection d'un ami (pour choisir la carte à lui demander). Vide si vous n'êtes pas amis.
create or replace function public.friend_cards(p_friend uuid)
returns table (id bigint, card_id smallint, seed bigint)
language sql stable security definer set search_path = '' as $$
  select c.id, c.card_id, c.seed from public.owned_cards c
  where c.user_id = p_friend and public.are_friends((select auth.uid()), p_friend)
  order by c.card_id, c.id
$$;

-- Mes exemplaires avec leur identifiant serveur (pour choisir la carte à offrir).
create or replace function public.my_cards()
returns table (id bigint, card_id smallint, seed bigint)
language sql stable security invoker set search_path = '' as $$
  select c.id, c.card_id, c.seed from public.owned_cards c
  where c.user_id = (select auth.uid()) order by c.card_id, c.id
$$;

-- Mes échanges : en attente, et ceux des 30 derniers jours.
create or replace function public.my_trades()
returns table (id bigint, incoming boolean, other_user uuid, other_name text,
               offered_card smallint, offered_seed bigint, requested_card smallint, requested_seed bigint,
               status text, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select t.id, t.to_user = (select auth.uid()),
         case when t.to_user = (select auth.uid()) then t.from_user else t.to_user end,
         p.display_name, t.offered_card, t.offered_seed, t.requested_card, t.requested_seed, t.status, t.created_at
  from public.trades t
  join public.profiles p on p.id = case when t.to_user = (select auth.uid()) then t.from_user else t.to_user end
  where (select auth.uid()) in (t.from_user, t.to_user)
    and (t.status = 'pending' or t.created_at > now() - interval '30 days')
  order by (t.status = 'pending') desc, t.created_at desc
  limit 100
$$;

revoke execute on function public.are_friends(uuid, uuid), public.skip_traded_away() from public, anon, authenticated;
revoke execute on function
  public.add_friend(text), public.respond_friend(uuid, boolean), public.remove_friend(uuid),
  public.propose_trade(uuid, bigint, bigint), public.accept_trade(bigint), public.close_trade(bigint),
  public.list_friends(), public.friend_cards(uuid), public.my_cards(), public.my_trades()
  from public, anon;
grant execute on function
  public.add_friend(text), public.respond_friend(uuid, boolean), public.remove_friend(uuid),
  public.propose_trade(uuid, bigint, bigint), public.accept_trade(bigint), public.close_trade(bigint),
  public.list_friends(), public.friend_cards(uuid), public.my_cards(), public.my_trades()
  to authenticated;
