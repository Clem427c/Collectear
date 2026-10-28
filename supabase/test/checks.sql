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


-- ===========================================================================
-- Amis et échanges. A = 1111…, B = 2222…, C = 3333…
-- ===========================================================================
reset role;
select friend_code as code_a from public.profiles where id = '11111111-1111-1111-1111-111111111111' \gset
select friend_code as code_b from public.profiles where id = '22222222-2222-2222-2222-222222222222' \gset
-- B possède deux cartes (insérées directement, comme la synchro).
insert into public.owned_cards (user_id, card_id, seed) values
  ('22222222-2222-2222-2222-222222222222', 50, 7), ('22222222-2222-2222-2222-222222222222', 51, 8);
set role authenticated;

-- A demande B en ami (code avec espaces et minuscules accepté).
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select pg_temp.check(pg_temp.fails('select public.add_friend(''ZZZZZZZZ'')'), 'ami : code inconnu refusé');
select pg_temp.check(pg_temp.fails(format('select public.add_friend(%L)', :'code_a')), 'ami : son propre code refusé');
select pg_temp.check(public.add_friend(lower(' ' || :'code_b' || ' ')) = 'sent', 'ami : demande envoyée');
select pg_temp.check(pg_temp.fails(format('select public.add_friend(%L)', :'code_b')), 'ami : demande en double refusée');
select pg_temp.check(pg_temp.fails($q$insert into public.friendships values (auth.uid(), '33333333-3333-3333-3333-333333333333', 'accepted')$q$), 'ami : pas d''écriture directe');
select pg_temp.check((select count(*) from public.friend_cards('22222222-2222-2222-2222-222222222222')) = 0, 'ami : collection invisible avant acceptation');

-- B voit la demande et l'accepte.
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
select pg_temp.check((select incoming and status = 'pending' and display_name = 'Clem' from public.list_friends()), 'ami : demande reçue visible avec le pseudo');
select public.respond_friend('11111111-1111-1111-1111-111111111111', true);
select pg_temp.check((select status = 'accepted' from public.list_friends()), 'ami : demande acceptée');

-- A voit la collection de B et propose 12/345 contre 50/7.
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select pg_temp.check((select count(*) from public.friend_cards('22222222-2222-2222-2222-222222222222')) = 2, 'ami : collection de l''ami visible');
select id as a12 from public.my_cards() where card_id = 12 \gset
select id as b50 from public.friend_cards('22222222-2222-2222-2222-222222222222') where card_id = 50 \gset
select id as b51 from public.friend_cards('22222222-2222-2222-2222-222222222222') where card_id = 51 \gset
select pg_temp.check(pg_temp.fails(format('select public.propose_trade(%L, %s, %s)', '22222222-2222-2222-2222-222222222222', :b50, :a12)), 'échange : offrir la carte d''un autre refusé');
select pg_temp.check(pg_temp.fails(format('select public.propose_trade(%L, %s, %s)', '33333333-3333-3333-3333-333333333333', :a12, :b50)), 'échange : seulement entre amis');
select public.propose_trade('22222222-2222-2222-2222-222222222222', :a12, :b50) as t1 \gset
select public.propose_trade('22222222-2222-2222-2222-222222222222', :a12, :b51) as t2 \gset
select pg_temp.check(pg_temp.fails(format('select public.accept_trade(%s)', :t1)), 'échange : l''auteur ne peut pas accepter');
select pg_temp.check(pg_temp.fails($q$update public.trades set status = 'accepted' where true$q$), 'échange : pas d''écriture directe');

-- B accepte le premier : les cartes changent de main, le second expire (12/345 n'est plus à A).
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
select pg_temp.check((select count(*) from public.my_trades() where incoming and status = 'pending') = 2, 'échange : propositions reçues visibles');
select pg_temp.check(public.accept_trade(:t1) = 'accepted', 'échange : accepté');
select pg_temp.check(exists (select 1 from public.owned_cards where card_id = 12 and seed = 345), 'échange : B reçoit 12');
select pg_temp.check(not exists (select 1 from public.owned_cards where card_id = 50), 'échange : B n''a plus 50');
select pg_temp.check((select status from public.trades where id = :t2) = 'expired', 'échange : propositions sur ces cartes expirées');
select pg_temp.check(exists (select 1 from public.traded_away where card_id = 50 and seed = 7), 'échange : 50 notée comme donnée par B');
-- La synchro de B renvoie 50/7 : ignorée par le serveur.
insert into public.owned_cards (user_id, card_id, seed) values (auth.uid(), 50, 7) on conflict do nothing;
select pg_temp.check(not exists (select 1 from public.owned_cards where card_id = 50), 'échange : carte donnée non renvoyable par la synchro');

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select pg_temp.check(exists (select 1 from public.owned_cards where card_id = 50 and seed = 7), 'échange : A reçoit 50');
select pg_temp.check(not exists (select 1 from public.owned_cards where card_id = 12 and seed = 345), 'échange : A n''a plus 12');
-- Proposition puis annulation ; retrait d'ami.
select public.propose_trade('22222222-2222-2222-2222-222222222222', (select id from public.my_cards() where card_id = 50), :b51) as t3 \gset
select public.close_trade(:t3);
select pg_temp.check((select status from public.trades where id = :t3) = 'cancelled', 'échange : annulé par l''auteur');
select public.propose_trade('22222222-2222-2222-2222-222222222222', (select id from public.my_cards() where card_id = 50), :b51) as t4 \gset
select public.remove_friend('22222222-2222-2222-2222-222222222222');
select pg_temp.check((select status from public.trades where id = :t4) = 'cancelled', 'ami retiré : échanges en attente annulés');
select pg_temp.check((select count(*) from public.list_friends()) = 0, 'ami retiré');

-- C ne voit aucun échange des autres.
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false);
select pg_temp.check((select count(*) from public.trades) = 0 and (select count(*) from public.my_trades()) = 0, 'échanges des autres invisibles');

reset role;
set role authenticated;
-- Sans compte : rien.
reset role;
set role anon;
select set_config('request.jwt.claim.sub', '', false);
select pg_temp.check(pg_temp.fails('select public.start_run()'), 'anonyme : pas de run');
select pg_temp.check((select count(*) from public.owned_cards) = 0, 'anonyme : aucune carte visible');
reset role;
\o
\echo 'Toutes les vérifications du schéma sont passées.'
