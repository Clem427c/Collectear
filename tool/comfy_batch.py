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
    Pour refaire une carte qui ne plaît pas : supprimer art/raw/NNN.png et relancer.

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


def workflow(prompt: str, seed: int, prefix: str) -> dict:
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
        "6": {"class_type": "EmptySD3LatentImage", "inputs": {"width": 1024, "height": 1024, "batch_size": 1}},
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


def generate(url: str, prompt: str, seed: int, prefix: str, dest: Path):
    client = str(uuid.uuid4())
    res = json.loads(call(url, "/prompt", {"prompt": workflow(prompt, seed, prefix), "client_id": client}))
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
    ap.add_argument("--full", action="store_true", help="FLUX en pleine précision et encodeurs sur la carte graphique")
    args = ap.parse_args()
    if args.full:
        global WEIGHT_DTYPE, CLIP_DEVICE
        WEIGHT_DTYPE, CLIP_DEVICE = "default", "default"
    if args.auto:
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


def git_push(message: str):
    try:
        subprocess.run(["git", "add", "art/raw"], cwd=ROOT, check=True)
        diff = subprocess.run(["git", "diff", "--cached", "--quiet"], cwd=ROOT)
        if diff.returncode == 0:
            return
        subprocess.run(["git", "commit", "-m", message], cwd=ROOT, check=True)
        subprocess.run(["git", "pull", "--rebase", "origin", "main"], cwd=ROOT, check=True)
        subprocess.run(["git", "push", "origin", "HEAD:main"], cwd=ROOT, check=True)
        print("→ envoyé sur GitHub :", message)
    except Exception as e:  # on continue la génération même si le push échoue
        print("! push impossible pour l'instant :", e)


def auto_mode(args):
    url = find_server([args.url] if args.url else ["http://127.0.0.1:8000", "http://127.0.0.1:8188"])
    print("ComfyUI trouvé :", url)
    RAW.mkdir(parents=True, exist_ok=True)
    rows = list(csv.DictReader(PROMPTS.open(encoding="utf-8"), delimiter=";"))
    done = 0
    for row in rows:
        n = int(row["numero"])
        if not args.start <= n <= args.end:
            continue
        dest = RAW / f"{n:03d}.png"
        if any((RAW / f"{n:03d}.{ext}").exists() for ext in ("png", "jpg", "jpeg", "webp")):
            continue
        for attempt in range(3):  # quelques nouvelles tentatives si ComfyUI hoquette
            try:
                t0 = time.time()
                generate(url, row["prompt"], seed=n * 1000, prefix=f"collectear/{n:03d}", dest=dest)
                print(f"{dest.name}  {row['nom']}  ({time.time() - t0:.1f} s)")
                break
            except Exception as e:
                print(f"! {n:03d} tentative {attempt + 1} échouée : {e}")
                time.sleep(5)
        done += 1
        if done % 25 == 0 and not args.no_push:
            git_push(f"Illustrations : {done} nouvelles cartes (génération auto FLUX)")
    if not args.no_push:
        git_push(f"Illustrations : génération auto FLUX ({done} cartes)")
    print(f"Terminé : {done} carte(s) générée(s).")


if __name__ == "__main__":
    main()
