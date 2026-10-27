"""Génère les illustrations des cartes en lot avec ComfyUI + FLUX.1 Schnell (sur le PC de Clem).

Prérequis : ComfyUI lancé, avec dans ses dossiers models/ :
  diffusion_models/flux1-schnell.safetensors
  text_encoders/t5xxl_fp16.safetensors
  text_encoders/clip_l.safetensors
  vae/ae.safetensors

Usage (depuis la racine du dépôt) :
  python tool/comfy_batch.py                      # cartes 1 à 300, 3 propositions par carte
  python tool/comfy_batch.py --from 1 --to 10     # seulement les cartes 1 à 10
  python tool/comfy_batch.py --variants 4         # 4 propositions par carte
  python tool/comfy_batch.py --url http://127.0.0.1:8188   # si ComfyUI n'est pas sur le port 8000

Mode automatique (pour laisser tourner sans surveiller) :
  python tool/comfy_batch.py --auto
  → une image par carte, écrite directement dans art/raw/NNN.png, puis commit + push sur GitHub
    toutes les 25 cartes et à la fin. Les cartes déjà présentes dans art/raw/ sont sautées.
    Pour refaire des cartes qui ne plaisent pas (nouvelle graine à chaque fois, sinon FLUX redonne
    exactement la même image) :
  python tool/comfy_batch.py --redo 29,64,72

Décors, personnage jouable et ennemis (docs/prompts_decors.csv, regénéré par tool/gen_decor_prompts.py) :
  python tool/comfy_batch.py --decors             # 3 propositions par image dans art/decors/candidates/
  python tool/comfy_batch.py --decors --auto      # 1 image par élément dans art/decors/raw/ + push GitHub
  python tool/comfy_batch.py --decors --redo 3,12 # refaire certains éléments (numéros du CSV)

Les images arrivent dans art/candidates/ (001_a.png, 001_b.png, …). Choisis la meilleure,
renomme-la 001.png et place-la dans art/raw/. Les cartes déjà présentes dans art/raw/ sont sautées.
Aucune dépendance : uniquement la bibliothèque standard de Python.
"""
import argparse
import subprocess
import csv
import json
import time
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROMPTS = ROOT / "docs/prompts_flux.csv"
OUT = ROOT / "art/candidates"
RAW = ROOT / "art/raw"
WEIGHT_DTYPE = "fp8_e4m3fn"
CLIP_DEVICE = "cpu"


def workflow(prompt: str, seed: int, prefix: str, width: int = 1024, height: int = 1024) -> dict:
    return {
        # FLUX chargé en fp8 (~12 Go de VRAM au lieu de ~24) et encodeurs de texte sur le processeur :
        # sinon, à chaque nouveau prompt, ComfyUI fait des allers-retours de ~34 Go entre la RAM et la VRAM
        # et la génération devient extrêmement lente. Qualité quasi identique.
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "flux1-schnell.safetensors", "weight_dtype": WEIGHT_DTYPE}},
        "2": {"class_type": "DualCLIPLoader",
              "inputs": {"clip_name1": "t5xxl_fp16.safetensors", "clip_name2": "clip_l.safetensors", "type": "flux",
                         "device": CLIP_DEVICE}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": "ae.safetensors"}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["2", 0]}},
        "5": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["4", 0]}},
        "6": {"class_type": "EmptySD3LatentImage", "inputs": {"width": width, "height": height, "batch_size": 1}},
        "7": {"class_type": "KSampler", "inputs": {
            "model": ["1", 0], "positive": ["4", 0], "negative": ["5", 0], "latent_image": ["6", 0],
            "seed": seed, "steps": 4, "cfg": 1.0, "sampler_name": "euler", "scheduler": "simple", "denoise": 1.0}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["7", 0], "vae": ["3", 0]}},
        "9": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": prefix}},
    }


def call(url: str, path: str, data: dict | None = None):
    req = urllib.request.Request(url + path, data=json.dumps(data).encode() if data else None,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def find_server(urls):
    for u in urls:
        try:
            call(u, "/system_stats")
            return u
        except Exception:
            continue
    raise SystemExit("ComfyUI injoignable. Lance ComfyUI puis réessaie (ou précise --url).")


def generate(url: str, prompt: str, seed: int, prefix: str, dest: Path, width: int = 1024, height: int = 1024):
    client = str(uuid.uuid4())
    res = json.loads(call(url, "/prompt", {"prompt": workflow(prompt, seed, prefix, width, height), "client_id": client}))
    pid = res["prompt_id"]
    deadline = time.time() + 300
    while True:
        time.sleep(1)
        if time.time() > deadline:
            call(url, "/interrupt", {})
            raise RuntimeError("image trop longue (> 5 min), génération interrompue")
        hist = json.loads(call(url, f"/history/{pid}"))
        if pid in hist and hist[pid].get("outputs"):
            img = hist[pid]["outputs"]["9"]["images"][0]
            q = urllib.parse.urlencode({"filename": img["filename"], "subfolder": img["subfolder"], "type": img["type"]})
            dest.write_bytes(call(url, f"/view?{q}"))
            return
        if pid in hist and hist[pid].get("status", {}).get("status_str") == "error":
            raise RuntimeError(json.dumps(hist[pid]["status"])[:500])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="start", type=int, default=1)
    ap.add_argument("--to", dest="end", type=int, default=300)
    ap.add_argument("--variants", type=int, default=3)
    ap.add_argument("--url", default=None)
    ap.add_argument("--auto", action="store_true", help="1 image par carte dans art/raw/ + push GitHub")
    ap.add_argument("--no-push", action="store_true", help="en mode auto : ne pas pousser sur GitHub")
    ap.add_argument("--redo", default="",
                    help="numéros à refaire, séparés par des virgules (ex. 29,64,72) : remplace l'image avec une nouvelle graine")
    ap.add_argument("--full", action="store_true", help="FLUX en pleine précision et encodeurs sur la carte graphique")
    ap.add_argument("--decors", action="store_true",
                    help="décors, personnage jouable et ennemis (docs/prompts_decors.csv) au lieu des cartes")
    args = ap.parse_args()
    if args.full:
        global WEIGHT_DTYPE, CLIP_DEVICE
        WEIGHT_DTYPE, CLIP_DEVICE = "default", "default"
    if args.decors:
        return decors_mode(args)
    if args.auto or args.redo:
        return auto_mode(args)

    url = find_server([args.url] if args.url else ["http://127.0.0.1:8000", "http://127.0.0.1:8188"])
    print("ComfyUI trouvé :", url)
    OUT.mkdir(parents=True, exist_ok=True)
    rows = list(csv.DictReader(PROMPTS.open(encoding="utf-8"), delimiter=";"))
    letters = "abcdefghij"
    for row in rows:
        n = int(row["numero"])
        if not args.start <= n <= args.end:
            continue
        if any((RAW / f"{n:03d}.{ext}").exists() for ext in ("png", "jpg", "jpeg", "webp")):
            continue  # déjà choisie
        for v in range(args.variants):
            dest = OUT / f"{n:03d}_{letters[v]}.png"
            if dest.exists():
                continue
            t0 = time.time()
            generate(url, row["prompt"], seed=n * 1000 + v, prefix=f"collectear/{n:03d}_{letters[v]}", dest=dest)
            print(f"{dest.name}  {row['nom']}  ({time.time() - t0:.1f} s)")
    print("Terminé. Choisis tes images dans art/candidates/ et place-les dans art/raw/ (001.png…).")


def git_push(message: str, folder: str = "art/raw"):
    try:
        subprocess.run(["git", "add", folder], cwd=ROOT, check=True)
        diff = subprocess.run(["git", "diff", "--cached", "--quiet"], cwd=ROOT)
        if diff.returncode == 0:
            return
        subprocess.run(["git", "commit", "-m", message], cwd=ROOT, check=True)
        subprocess.run(["git", "pull", "--rebase", "origin", "main"], cwd=ROOT, check=True)
        subprocess.run(["git", "push", "origin", "HEAD:main"], cwd=ROOT, check=True)
        print("→ envoyé sur GitHub :", message)
    except Exception as e:  # on continue la génération même si le push échoue
        print("! push impossible pour l'instant :", e)


def parse_numbers(text: str) -> set[int]:
    """« 29, 64,72 » → {29, 64, 72}. Accepte aussi les plages « 10-12 »."""
    out = set()
    for part in text.replace(" ", "").split(","):
        if not part:
            continue
        if "-" in part:
            a, b = part.split("-", 1)
            out.update(range(int(a), int(b) + 1))
        else:
            out.add(int(part))
    return out


def auto_mode(args):
    url = find_server([args.url] if args.url else ["http://127.0.0.1:8000", "http://127.0.0.1:8188"])
    print("ComfyUI trouvé :", url)
    RAW.mkdir(parents=True, exist_ok=True)
    rows = list(csv.DictReader(PROMPTS.open(encoding="utf-8"), delimiter=";"))
    redo = parse_numbers(args.redo)
    # Graine différente à chaque relance pour les cartes à refaire (même prompt + même graine = même image).
    seed_offset = int(time.time()) % 100_000 + 1 if redo else 0
    done = 0
    for row in rows:
        n = int(row["numero"])
        if redo and n not in redo:
            continue
        if not args.start <= n <= args.end:
            continue
        dest = RAW / f"{n:03d}.png"
        if n not in redo and any((RAW / f"{n:03d}.{ext}").exists() for ext in ("png", "jpg", "jpeg", "webp")):
            continue
        for attempt in range(3):  # quelques nouvelles tentatives si ComfyUI hoquette
            try:
                t0 = time.time()
                generate(url, row["prompt"], seed=n * 1000 + seed_offset, prefix=f"collectear/{n:03d}", dest=dest)
                print(f"{dest.name}  {row['nom']}  ({time.time() - t0:.1f} s)")
                break
            except Exception as e:
                print(f"! {n:03d} tentative {attempt + 1} échouée : {e}")
                time.sleep(5)
        done += 1
        if done % 25 == 0 and not args.no_push:
            git_push(f"Illustrations : {done} nouvelles cartes (génération auto FLUX)")
    if not args.no_push:
        what = f"cartes refaites : {', '.join(f'{n:03d}' for n in sorted(redo))}" if redo else f"{done} cartes"
        git_push(f"Illustrations : génération auto FLUX ({what})")
    print(f"Terminé : {done} carte(s) générée(s).")


DECOR_PROMPTS = ROOT / "docs/prompts_decors.csv"
DECOR_RAW = ROOT / "art/decors/raw"
DECOR_OUT = ROOT / "art/decors/candidates"


def decors_mode(args):
    """Décors / perso / ennemis : 3 propositions par image dans art/decors/candidates/ (au choix de Clem,
    à copier dans art/decors/raw/ sous le nom de la colonne « fichier »), ou avec --auto une image
    directement dans art/decors/raw/ puis envoi sur GitHub. --redo marche avec les numéros du CSV."""
    url = find_server([args.url] if args.url else ["http://127.0.0.1:8000", "http://127.0.0.1:8188"])
    print("ComfyUI trouvé :", url)
    rows = list(csv.DictReader(DECOR_PROMPTS.open(encoding="utf-8"), delimiter=";"))
    redo = parse_numbers(args.redo)
    seed_offset = int(time.time()) % 100_000 + 1 if redo else 0
    auto = args.auto or bool(redo)
    (DECOR_RAW if auto else DECOR_OUT).mkdir(parents=True, exist_ok=True)
    letters = "abcdefghij"
    done = 0
    for row in rows:
        n = int(row["numero"])
        if redo and n not in redo:
            continue
        final = DECOR_RAW / row["fichier"]
        if final.exists() and n not in redo:
            continue
        w, h = int(row["largeur"]), int(row["hauteur"])
        stem = Path(row["fichier"]).stem
        targets = [final] if auto else [DECOR_OUT / f"{stem}_{letters[v]}.png" for v in range(args.variants)]
        for v, dest in enumerate(targets):
            if dest.exists() and not auto:
                continue
            for attempt in range(3):
                try:
                    t0 = time.time()
                    generate(url, row["prompt"], seed=5000 + n * 100 + v + seed_offset,
                             prefix=f"collectear_decors/{stem}", dest=dest, width=w, height=h)
                    print(f"{dest.name}  {row['nom']}  ({time.time() - t0:.1f} s)")
                    break
                except Exception as e:
                    print(f"! {dest.name} tentative {attempt + 1} échouée : {e}")
                    time.sleep(5)
        done += 1
    if auto and not args.no_push:
        git_push(f"Décors : génération auto FLUX ({done} images)", folder="art/decors/raw")
    if not auto:
        print("Terminé. Choisis dans art/decors/candidates/ et copie la meilleure dans art/decors/raw/ "
              "sous le nom de la colonne « fichier » (ex. tile_l0_vallee.png).")
    print(f"Terminé : {done} image(s).")


if __name__ == "__main__":
    main()
