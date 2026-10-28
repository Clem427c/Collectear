-- Vitrine de test (supabase/showcase.sql) : 3000 exemplaires, rien en double, réservée au SQL Editor.
\set ON_ERROR_STOP 1
do $$
declare n int;
begin
  n := public.grant_showcase('c@x');
  if n <> 3000 then raise exception 'ÉCHEC : vitrine, % exemplaires au lieu de 3000', n; end if;
  if public.grant_showcase('C@X ') <> 0 then raise exception 'ÉCHEC : vitrine ajoutée deux fois'; end if;
  if (select count(distinct card_id) from public.owned_cards
      where user_id = '33333333-3333-3333-3333-333333333333') <> 300 then
    raise exception 'ÉCHEC : vitrine, il manque des cartes';
  end if;
  raise notice 'ok : vitrine (3000 exemplaires, 300 cartes)';
end $$;
set role authenticated;
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false) \g /dev/null
do $$
begin
  perform public.grant_showcase('c@x');
  raise exception 'ÉCHEC : la vitrine est appelable depuis l''appli';
exception when insufficient_privilege then
  raise notice 'ok : vitrine non appelable depuis l''appli';
end $$;
