"""Downloads CC0 models and textures from Poly Haven into assets/polyhaven/<id>/ and records them in CREDITS.

    python tools/fetch_polyhaven.py model plastic_monobloc_chair_01 Television_01
    python tools/fetch_polyhaven.py texture brown_floor_tiles
"""
import json
import pathlib
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "polyhaven"
CREDITS = ROOT / "assets" / "CREDITS.md"
RES = "1k"
TEXTURE_MAPS = {"Diffuse": "diff", "nor_gl": "nor_gl", "arm": "arm"}  # arm = AO / roughness / metallic packed


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "SneakyOkey/0.1"})
    with urllib.request.urlopen(req) as r:
        return r.read()


def save(url, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists():
        path.write_bytes(get(url))


def fetch_model(asset_id, files):
    gltf = files["gltf"][RES]["gltf"]
    folder = OUT / asset_id
    save(gltf["url"], folder / f"{asset_id}.gltf")
    for rel, inc in gltf["include"].items():
        save(inc["url"], folder / rel)


def fetch_texture(asset_id, files):
    folder = OUT / asset_id
    for key, short in TEXTURE_MAPS.items():
        entry = files[key][RES]["jpg" if "jpg" in files[key][RES] else "png"]
        save(entry["url"], folder / f"{asset_id}_{short}.{entry['url'].rsplit('.', 1)[1]}")


def credit(asset_id, info):
    authors = ", ".join(info.get("authors", {}).keys()) or "Poly Haven"
    line = f"| {info.get('name', asset_id)} by {authors} | polyhaven/{asset_id} | https://polyhaven.com/a/{asset_id} | CC0 |\n"
    text = CREDITS.read_text(encoding="utf-8")
    if f"polyhaven/{asset_id} " not in text:
        CREDITS.write_text(text + line, encoding="utf-8", newline="\n")


def main():
    kind, ids = sys.argv[1], sys.argv[2:]
    for asset_id in ids:
        files = json.loads(get(f"https://api.polyhaven.com/files/{asset_id}"))
        info = json.loads(get(f"https://api.polyhaven.com/info/{asset_id}"))
        (fetch_model if kind == "model" else fetch_texture)(asset_id, files)
        credit(asset_id, info)
        print("ok", asset_id)


main()
