-- Vérifications de supabase/schema.sql (lancées par la CI sur PostgreSQL 16, voir run.sh).
-- Chaque bloc lève une erreur si la règle n'est pas respectée.
\set ON_ERROR_STOP 1
\o /dev/null

-- Fonction d'aide : vrai si la requête échoue.
create or replace function pg_temp.fails(q text) returns boolean language plpgsql as $$
begin
  execute q;
  return false;
exception when others then
  return true;
end $$;

create or replace function pg_temp.check(ok boolean, what text) returns void language plpgsql as $$
begin
  if not ok then raise exception 'ÉCHEC : %', what; end if;
  raise notice 'ok : %', what;
end $$;

grant execute on all functions in schema pg_temp to authenticated, anon;

set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);

-- Profil créé à l'inscription, pseudo modifiable, code ami non modifiable.
select pg_temp.check((select count(*) from public.profiles) = 1, 'chacun ne voit que son profil');
select pg_temp.check(not pg_temp.fails($q$update public.profiles set display_name = 'Clem' where true$q$), 'pseudo modifiable');
select pg_temp.check(pg_temp.fails($q$update public.profiles set display_name = '' where true$q$), 'pseudo vide refusé');
select pg_temp.check(pg_temp.fails($q$update public.profiles set friend_code = 'AAAAAAAA' where true$q$), 'code ami non modifiable');

-- Écritures directes interdites.
select pg_temp.check(pg_temp.fails($q$insert into public.runs (user_id) values (auth.uid())$q$), 'runs : pas d''ajout direct');
select pg_temp.check(pg_temp.fails('truncate public.owned_cards'), 'collection : pas de truncate');
select pg_temp.check(pg_temp.fails('truncate public.profiles'), 'profils : pas de truncate');
select pg_temp.check(pg_temp.fails('delete from public.owned_cards'), 'collection : pas de suppression');

-- Run normale : 2 cartes ajoutées, stats à jour.
select public.start_run() as rid \gset
select pg_sleep(1.1);
select pg_temp.check(public.finish_run(:'rid', 3, 20, '[{"card_id":12,"seed":345},{"card_id":300,"seed":0}]') = 2, 'run : 2 cartes ajoutées');
select pg_temp.check(pg_temp.fails(format('select public.finish_run(%L, 3, 20, %L)', :'rid', '[]')), 'run : déjà terminée');
select pg_temp.check((select runs = 1 and kills = 3 and cards = 2 and best_kills = 3 from public.my_stats()), 'stats du profil');

-- Run tricheuse : chaque cas est refusé.
select public.start_run() as rid2 \gset
select pg_temp.check(pg_temp.fails(format('select public.finish_run(%L, 0, 0, %L)', :'rid2',
  '[{"card_id":1,"seed":1},{"card_id":2,"seed":1},{"card_id":3,"seed":1},{"card_id":4,"seed":1}]')), 'plus de 3 cartes');
select pg_temp.check(pg_temp.fails(format('select public.finish_run(%L, 0, 0, %L)', :'rid2', '[{"card_id":301,"seed":1}]')), 'carte inconnue');
select pg_temp.check(pg_temp.fails(format('select public.finish_run(%L, 0, 0, %L)', :'rid2', '[{"card_id":"x","seed":1}]')), 'carte mal formée');
select pg_temp.check(pg_temp.fails(format('select public.finish_run(%L, 500, 0, %L)', :'rid2', '[]')), 'trop d''ennemis pour la durée');
select pg_temp.check(pg_temp.fails(format('select public.finish_run(%L, 0, -5, %L)', :'rid2', '[]')), 'pièces négatives');
select pg_temp.check(public.finish_run(:'rid2', 0, 0, '[{"card_id":12,"seed":345}]') = 0, 'doublon exact ignoré');

-- Un autre joueur ne voit rien et ne peut pas fermer la run du premier.
select public.start_run() as rid3 \gset
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
select pg_temp.check((select count(*) from public.runs) = 0, 'runs des autres invisibles');
select pg_temp.check((select count(*) from public.owned_cards) = 0, 'collection des autres invisible');
select pg_temp.check(pg_temp.fails(format('select public.finish_run(%L, 0, 0, %L)', :'rid3', '[]')), 'run d''un autre refusée');

-- Limite du jour : 15 runs (10 gratuites + 5 énergies).
select count(*) from (select public.start_run() from generate_series(1, 15)) s;
select pg_temp.check(pg_temp.fails('select public.start_run()'), '16e run du jour refusée');

-- Sans compte : rien.
reset role;
set role anon;
select set_config('request.jwt.claim.sub', '', false);
select pg_temp.check(pg_temp.fails('select public.start_run()'), 'anonyme : pas de run');
select pg_temp.check((select count(*) from public.owned_cards) = 0, 'anonyme : aucune carte visible');
reset role;
\o
\echo 'Toutes les vérifications du schéma sont passées.'
