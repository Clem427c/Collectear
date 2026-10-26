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

Les images arrivent dans art/candidates/ (001_a.png, 001_b.png, …). Choisis la meilleure,
renomme-la 001.png et place-la dans art/raw/. Les cartes déjà présentes dans art/raw/ sont sautées.
Aucune dépendance : uniquement la bibliothèque standard de Python.
"""
import argparse
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


def workflow(prompt: str, seed: int, prefix: str) -> dict:
    return {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "flux1-schnell.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "DualCLIPLoader",
              "inputs": {"clip_name1": "t5xxl_fp16.safetensors", "clip_name2": "clip_l.safetensors", "type": "flux"}},
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
    while True:
        time.sleep(1)
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
    args = ap.parse_args()

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


if __name__ == "__main__":
    main()
