import json
import os
import re
import sys


def frame_url(url):
    # Mirror game js/assets.js frameUrl(): .webp -> .frames.json
    return re.sub(r"\.webp(?:\?.*)?$", ".frames.json", url)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    game_assets = os.path.join(here, "..", "game js", "assets.json")
    links_file = os.path.join(here, "link.json")
    out_file = os.path.join(here, "link-json.json")

    with open(game_assets, "r") as f:
        assets = json.load(f)
    with open(links_file, "r") as f:
        links = json.load(f)

    # Derive the host from an absolute asset URL. link.json may contain only
    # relative generated-assets paths, so reuse the current output's host then.
    base_url = None
    sources = [links]
    if os.path.exists(out_file):
        with open(out_file, "r") as f:
            sources.append(json.load(f))

    for source in sources:
        for key, rel in assets.items():
            url = source.get(key, "").strip()
            if url.startswith(("http://", "https://")) and url.endswith(rel):
                base_url = url[: -len(rel)]
                break
        if base_url is not None:
            break

    if base_url is None:
        raise ValueError("Could not determine an absolute base URL from link.json or link-json.json")

    out = {}
    for key, rel in assets.items():
        if not rel:
            continue
        # Match game/assets.js: metadata is loaded only for transparent sheets and tiles.
        if "transparent" not in rel and "tiles" not in rel:
            continue
        full = base_url.rstrip("/") + "/" + rel.lstrip("/")
        out[key] = frame_url(full)

    with open(out_file, "w") as f:
        json.dump(out, f, indent=2)
        f.write("\n")

    print(f"Wrote {len(out)} entries to {out_file}")


if __name__ == "__main__":
    main()
