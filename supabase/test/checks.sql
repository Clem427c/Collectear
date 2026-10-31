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
select pg_temp.check((select runs = 1 and kills = 3 and cards = 2 and best_kills = 3 and best_distance = 0 and places = 0
                      from public.my_stats()), 'stats du profil (ancien appel à 4 paramètres)');

-- Records d'exploration : distance et lieux enregistrés, ramenés dans les limites plausibles.
select public.start_run() as rid_d \gset
select pg_sleep(1.1);
select pg_temp.check(public.finish_run(:'rid_d', 0, 0, '[{"card_id":12,"seed":345}]', p_distance => 12, p_places => 1) = 0,
                     'run avec distance et lieu (carte déjà possédée : rien d''ajouté)');
select pg_temp.check((select best_distance = 12 and places = 1 and runs = 2 from public.my_stats()), 'stats : distance et lieux');
select public.start_run() as rid_e \gset
select pg_temp.check(public.finish_run(:'rid_e', 0, 0, '[]', p_distance => 999999, p_places => 3) = 0, 'run avec valeurs impossibles');
select pg_temp.check((select distance between 1 and 32 and places = 0 from public.runs where id = :'rid_e'),
                     'distance plafonnée (8 cases/s), pas plus de lieux que de cartes');
select pg_temp.check((select best_distance = 12 from public.my_stats()), 'record = meilleure run (la run plafonnée ne le bat pas)');
select public.start_run() as rid_f \gset
select pg_temp.check(public.finish_run(:'rid_f', 0, 0, '[]', p_distance => -4, p_places => -1) = 0, 'valeurs négatives');
select pg_temp.check((select distance = 0 and places = 0 from public.runs where id = :'rid_f'), 'valeurs négatives ramenées à 0');

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

-- Limite du jour : 18 runs (10 gratuites + 5 énergies + 3 vidéos).
select count(*) from (select public.start_run() from generate_series(1, 18)) s;
select pg_temp.check(pg_temp.fails('select public.start_run()'), '19e run du jour refusée');


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
select pg_temp.check(pg_temp.fails(format('select public.propose_trade(%L, array[%s]::bigint[], array[%s]::bigint[])', '22222222-2222-2222-2222-222222222222', :b50, :a12)), 'échange : offrir la carte d''un autre refusé');
select pg_temp.check(pg_temp.fails(format('select public.propose_trade(%L, array[%s]::bigint[], array[%s]::bigint[])', '33333333-3333-3333-3333-333333333333', :a12, :b50)), 'échange : seulement entre amis');
select pg_temp.check(pg_temp.fails(format('select public.propose_trade(%L, array[]::bigint[], array[%s]::bigint[])', '22222222-2222-2222-2222-222222222222', :b50)), 'échange : au moins une carte de chaque côté');
select pg_temp.check(pg_temp.fails(format('select public.propose_trade(%L, array[%s, %s]::bigint[], array[%s]::bigint[])', '22222222-2222-2222-2222-222222222222', :a12, :a12, :b50)), 'échange : même carte deux fois refusée');
select public.propose_trade('22222222-2222-2222-2222-222222222222', array[:a12]::bigint[], array[:b50]::bigint[]) as t1 \gset
select public.propose_trade('22222222-2222-2222-2222-222222222222', array[:a12]::bigint[], array[:b51]::bigint[]) as t2 \gset
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
select pg_temp.check((select count(*) from public.friends_leaderboard()) = 2, 'classement : moi et mon ami');
select pg_temp.check((select is_me and species = 2 from public.friends_leaderboard() order by species desc limit 1), 'classement : trié (cartes différentes, puis exemplaires, puis pseudo)');
select pg_temp.check((select count(*) = 2 and bool_and(best_distance >= 0) from public.friends_leaderboard()), 'classement : record de distance');
-- 2 contre 1 et favoris. A possède 300/0 et 50/7 ; B possède 51/8 et 12/345.
select id as a300 from public.my_cards() where card_id = 300 \gset
select id as a50 from public.my_cards() where card_id = 50 \gset
select public.propose_trade('22222222-2222-2222-2222-222222222222', array[:a300, :a50]::bigint[], array[:b51]::bigint[]) as t5 \gset
select pg_temp.check((select jsonb_array_length(offered) = 2 and jsonb_array_length(requested) = 1 from public.my_trades() where id = :t5), 'échange 2 contre 1 : proposé');
select pg_temp.check(pg_temp.fails($q$update public.owned_cards set favorite = true where true$q$), 'favori : pas de modification directe');
select pg_temp.check(public.set_favorite(300::smallint, 0, true), 'favori : 300 mise en favori');
select pg_temp.check((select status from public.trades where id = :t5) = 'expired', 'favori : échanges en attente sur la carte expirés');
select pg_temp.check(pg_temp.fails(format('select public.propose_trade(%L, array[%s]::bigint[], array[%s]::bigint[])', '22222222-2222-2222-2222-222222222222', :a300, :b51)), 'favori : ne peut pas être offert');
select pg_temp.check(not public.set_favorite(299::smallint, 0, true), 'favori : carte non possédée ignorée');
select public.set_favorite(300::smallint, 0, false);
select public.propose_trade('22222222-2222-2222-2222-222222222222', array[:a300, :a50]::bigint[], array[:b51]::bigint[]) as t6 \gset
-- B met 51 en favori par la synchro : l'échange expire, et A ne peut plus la demander.
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
select pg_temp.check((select favorite from public.my_cards() where card_id = 51) = false, 'favori : pas en favori par défaut');
select pg_temp.check(public.add_favorites('[{"card_id":51,"seed":8},{"card_id":1,"seed":1}]') = 1, 'favori : ajout par la synchro');
select pg_temp.check((select status from public.trades where id = :t6) = 'expired', 'favori : expiration aussi par la synchro');
select pg_temp.check(public.add_favorites('[{"card_id":51,"seed":8}]') = 0, 'favori : déjà en favori');
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select pg_temp.check((select favorite from public.friend_cards('22222222-2222-2222-2222-222222222222') where card_id = 51), 'favori : visible par l''ami');
select pg_temp.check(pg_temp.fails(format('select public.propose_trade(%L, array[%s]::bigint[], array[%s]::bigint[])', '22222222-2222-2222-2222-222222222222', :a50, :b51)), 'favori : ne peut pas être demandé');
-- B retire le favori ; A propose 2 contre 1, B accepte.
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
select public.set_favorite(51::smallint, 8, false);
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select public.propose_trade('22222222-2222-2222-2222-222222222222', array[:a300, :a50]::bigint[], array[:b51]::bigint[]) as t7 \gset
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
select pg_temp.check(public.accept_trade(:t7) = 'accepted', 'échange 2 contre 1 : accepté');
select pg_temp.check((select count(*) from public.owned_cards where card_id in (300, 50)) = 2
                     and not exists (select 1 from public.owned_cards where card_id = 51), 'échange 2 contre 1 : B reçoit 2 cartes, donne 51');
select pg_temp.check(not exists (select 1 from public.traded_away where card_id = 50), 'échange retour : 50 n''est plus notée comme donnée par B');
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select pg_temp.check((select count(*) from public.owned_cards) = 1 and exists (select 1 from public.owned_cards where card_id = 51), 'échange 2 contre 1 : A a 51');
-- Proposition puis annulation ; retrait d'ami.
select public.propose_trade('22222222-2222-2222-2222-222222222222', array[(select id from public.my_cards() where card_id = 51)], array[(select id from public.friend_cards('22222222-2222-2222-2222-222222222222') where card_id = 12)]) as t3 \gset
select public.close_trade(:t3);
select pg_temp.check((select status from public.trades where id = :t3) = 'cancelled', 'échange : annulé par l''auteur');
select public.propose_trade('22222222-2222-2222-2222-222222222222', array[(select id from public.my_cards() where card_id = 51)], array[(select id from public.friend_cards('22222222-2222-2222-2222-222222222222') where card_id = 12)]) as t4 \gset
select public.remove_friend('22222222-2222-2222-2222-222222222222');
select pg_temp.check((select status from public.trades where id = :t4) = 'cancelled', 'ami retiré : échanges en attente annulés');
select pg_temp.check((select count(*) from public.list_friends()) = 0, 'ami retiré');
select pg_temp.check((select count(*) from public.friends_leaderboard()) = 1, 'classement : ancien ami retiré');

-- Liste de souhaits : A et C ne sont pas amis ; A et B ne le sont plus. On refait A ↔ B amis.
select pg_temp.check((select public.set_wish(12::smallint, true)) = 1, 'souhait : ajouté');
select pg_temp.check((select public.set_wish(12::smallint, true)) = 1, 'souhait : pas de doublon');
select pg_temp.check(pg_temp.fails('select public.set_wish(301::smallint, true)'), 'souhait : carte inconnue refusée');
select pg_temp.check(pg_temp.fails('insert into public.wishlist (user_id, card_id) values (auth.uid(), 5)'), 'souhait : pas d''ajout direct');
select pg_temp.check(pg_temp.fails('delete from public.wishlist'), 'souhait : pas de suppression directe');
select count(*) from (select public.set_wish(i::smallint, true) from generate_series(100, 128) i) s;
select pg_temp.check((select count(*) from public.my_wishlist()) = 30, 'souhaits : 30 cartes');
select pg_temp.check(pg_temp.fails('select public.set_wish(200::smallint, true)'), 'souhaits : 31e refusée');
select pg_temp.check((select public.set_wish(12::smallint, true)) = 30, 'souhaits : carte déjà présente acceptée quand la liste est pleine');
select pg_temp.check((select public.set_wish(100::smallint, false)) = 29, 'souhait : retiré');
select pg_temp.check((select count(*) from public.friend_wishlist('22222222-2222-2222-2222-222222222222')) = 0
                     , 'souhaits : rien chez un non-ami');
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
select pg_temp.check((select count(*) from public.friend_wishlist('11111111-1111-1111-1111-111111111111')) = 0
                     and (select count(*) from public.wishlist) = 0, 'souhaits : invisibles pour un non-ami');
select public.add_friend(:'code_a');
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select public.respond_friend('22222222-2222-2222-2222-222222222222', true);
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
select pg_temp.check((select count(*) from public.friend_wishlist('11111111-1111-1111-1111-111111111111')) = 29
                     and exists (select 1 from public.friend_wishlist('11111111-1111-1111-1111-111111111111') where card_id = 12),
                     'souhaits : visibles par un ami');
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false);
select pg_temp.check((select count(*) from public.friend_wishlist('11111111-1111-1111-1111-111111111111')) = 0, 'souhaits : C ne voit rien');
reset role;
set role anon;
select pg_temp.check(pg_temp.fails('select public.set_wish(1::smallint, true)'), 'souhait : anonyme refusé');
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);

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
