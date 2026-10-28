"""Génère supabase/showcase.sql : une « vitrine » de test, toutes les cartes en 10 exemplaires choisis
(un par motif, Shiny, chaque finition, finition + Shiny) pour voir le rendu de chaque variante.

Les variantes sont calculées par l'appli à partir d'une seed (lib/core/variants.dart, avec le
Random de Dart). Ce script réimplémente ce Random (même algorithme que la VM Dart et dart2js) pour
trouver, pour chaque carte, des seeds qui donnent chaque variante voulue. Le test
« vitrine » de test/core_test.dart vérifie avec le vrai code Dart que chaque seed donne bien la
variante annoncée.

Usage : python3 tool/gen_showcase.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "supabase/showcase.sql"
M64 = (1 << 64) - 1


def mix64(n: int) -> int:
    """Mélange 64 bits de Thomas Wang, utilisé par Random(seed) de Dart pour initialiser l'état."""
    n &= M64
    n = ((~n) + (n << 21)) & M64
    n ^= n >> 24
    n = (n * 265) & M64
    n ^= n >> 14
    n = (n * 21) & M64
    n ^= n >> 28
    n = (n + (n << 31)) & M64
    return n


class DartRandom:
    """math.Random(seed) de Dart : multiply-with-carry, A = 0xffffda61, base 2^32."""

    def __init__(self, seed: int):
        h = mix64(seed) or 0x5A17
        self.lo, self.hi = h & 0xFFFFFFFF, h >> 32
        for _ in range(4):
            self._next()

    def _next(self):
        s = 0xFFFFDA61 * self.lo + self.hi
        self.lo, self.hi = s & 0xFFFFFFFF, (s >> 32) & 0xFFFFFFFF

    def next_double(self) -> float:
        self._next()
        a = self.lo & ((1 << 26) - 1)
        self._next()
        b = self.lo & ((1 << 27) - 1)
        return (a * (1 << 27) + b) / (1 << 53)


def variant(seed: int):
    """Mêmes tirages, dans le même ordre, que Variant.fromSeed (lib/core/variants.dart)."""
    r = DartRandom(seed)
    r.next_double()  # teinte
    p = r.next_double()
    pattern = ("none" if p < 0.40 else "stripes" if p < 0.60 else "spots" if p < 0.78
               else "rings" if p < 0.90 else "stars")
    shiny = r.next_double() < 1 / 40
    f = r.next_double()
    g, c, s = 1 / 100, 1 / 150, 1 / 150
    finish = "golden" if f < g else "crystal" if f < g + c else "shadow" if f < g + c + s else "normal"
    return pattern, shiny, finish


def kind_of(v) -> list[str]:
    pattern, shiny, finish = v
    kinds = []
    if not shiny and finish == "normal":
        kinds.append(pattern)
    if shiny and finish == "normal":
        kinds.append("shiny")
    if finish != "normal":
        kinds.append(f"{finish}-shiny" if shiny else finish)
    return kinds


WANTED = ["none", "stripes", "spots", "rings", "stars", "shiny", "golden", "crystal", "shadow", "golden-shiny"]


def main():
    rows = []
    for card in range(1, 301):
        found = {}
        seed = card * 100_000
        while len(found) < len(WANTED):
            for k in kind_of(variant(seed)):
                if k in WANTED and k not in found:
                    found[k] = seed
            seed += 1
        rows += [(card, found[k], k) for k in WANTED]
    values = ",\n".join(f"    ({c}, {s}, '{k}')" for c, s, k in rows)
    OUT.write_text(f"""-- Vitrine de TEST (généré par tool/gen_showcase.py, ne pas modifier à la main).
-- Donne à un compte les 300 cartes en 10 exemplaires chacune : un par motif (uni, rayures, taches,
-- anneaux, étoiles), un Shiny, un Doré, un Cristal, un Ombre et un Doré Shiny.
--
-- 1. Coller tout ce fichier dans Supabase → SQL Editor → Run (crée la fonction, ne donne rien).
-- 2. Puis exécuter :   select public.grant_showcase('adresse@du.compte');
--    Résultat : le nombre d'exemplaires ajoutés (3000 la première fois, 0 ensuite).
-- 3. Dans l'appli : ⚙ → Compte → Synchroniser (ou relancer l'appli).
-- La fonction n'est appelable que depuis le SQL Editor (pas depuis l'appli).

create or replace function public.grant_showcase(p_email text) returns int
language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid;
  added int;
begin
  select u.id into uid from auth.users u where lower(u.email) = lower(trim(p_email));
  if uid is null then raise exception 'aucun compte avec cette adresse'; end if;
  insert into public.owned_cards (user_id, card_id, seed)
  select uid, v.card_id, v.seed
  from (values
{values}
  ) as v (card_id, seed, kind)
  on conflict (user_id, card_id, seed) do nothing;
  get diagnostics added = row_count;
  return added;
end $$;

revoke execute on function public.grant_showcase(text) from public, anon, authenticated;
""", encoding="utf-8")
    print(f"{len(rows)} exemplaires écrits dans {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
