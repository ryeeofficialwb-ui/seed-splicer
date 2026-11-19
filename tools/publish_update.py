"""Publishes an over-the-air update: players' games download it the next time they start.

    python tools/publish_update.py 1.0.1 "What changed"
    python tools/publish_update.py 1.0.1 "What changed" --full     (also a full Windows download)
    python tools/publish_update.py 1.0.1 --approvals-only           (only write data/approvals.json)

0. Writes the official seed list, data/approvals.json, from YOUR save: every seed you have is
   approved (players with a seed of the same name see the approval stamp + who made it), and the
   seeds you sent to the graveyard (Dictionary > Send to graveyard) are listed as denied. Your name
   comes from Settings > You (the contributor on old seeds that were made before names existed).
1. Sets GameVersion.VERSION (scripts/game_version.gd) to the new version.
2. Exports the game pack: build/SeedSplicer-<version>.pck, and its SHA-256 in .pck.sha256.
3. Commits everything, tags it v<version> and pushes to the source repo.
4. Creates the GitHub Release v<version> on GameVersion.RELEASES_REPO (this public repo) with the pack and its
   hash. Games older than <version> download it, check the hash and restart into it.
--full also exports SeedSplicer.exe (needs Godot's export templates installed) and attaches
build/SeedSplicer-<version>-windows.zip: the complete game for new players.

Needs: git, the GitHub CLI (gh, logged in), and Godot (set GODOT to its exe if it isn't the Steam one).
Only content updates go over the air: a new Godot version needs players to download the full game.
"""
import configparser
import hashlib
import json
import os
import re
import subprocess
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
VERSION_FILE = os.path.join(ROOT, "scripts", "game_version.gd")
BUILD = os.path.join(ROOT, "build")
GODOT = os.environ.get("GODOT", r"E:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe")
PRESET = "Windows"
GH = r"C:\Program Files\GitHub CLI\gh.exe"
APPROVALS = os.path.join(ROOT, "data", "approvals.json")
USER_DIR = os.environ.get("SEED_SPLICER_USER_DIR",
    os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "Seed Splicer"))
DRAW_FIELDS = ["rarity", "pattern", "colors", "sprout", "pattern_seed", "crop", "tag", "category", "drop", "fruit_count"]


def publisher_name():
    cfg = configparser.ConfigParser(interpolation=None, strict=False)
    cfg.read(os.path.join(USER_DIR, "seed_splicer_settings.cfg"), encoding="utf-8")
    raw = cfg.get("profile", "name", fallback="").strip()
    return raw.strip('"').strip()


def bake_approvals(version):
    """data/approvals.json from your save. Returns (approved, denied) counts."""
    save_path = os.path.join(USER_DIR, "seed_splicer_save.json")
    save = json.load(open(save_path, encoding="utf-8"))
    me = publisher_name()
    if not me:
        raise SystemExit("Set your name first: in the game, Settings > You > Your name. "
                         "It goes next to the approval stamp on your seeds.")
    old = {}
    if os.path.exists(APPROVALS):
        old = json.load(open(APPROVALS, encoding="utf-8"))
    names = {s["id"]: s["name"] for s in save["seeds"]}
    approved, denied, seen = [], [], set()
    for s in save["seeds"]:
        by = (s.get("made_by") or "").strip() or me
        key = s["name"].strip().lower()
        if s.get("denied"):
            d = {"name": s["name"], "made_by": by}
            d.update({k: s[k] for k in DRAW_FIELDS if k in s})
            d["parent_names"] = [names.get(p, "?") for p in s.get("parents", [])]
            denied.append(d)
        else:
            approved.append({"name": s["name"], "made_by": by})
        seen.add(key)
    # the graveyard keeps every seed denied in an earlier update (unless you have it again now)
    for d in old.get("denied", []):
        if d.get("name", "").strip().lower() not in seen:
            denied.append(d)
            seen.add(d["name"].strip().lower())
    data = {"format": "seed-splicer-approvals", "version": version, "publisher": me,
            "approved": approved, "denied": denied}
    with open(APPROVALS, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent="\t", ensure_ascii=False)
    print("Official list: %d approved seeds, %d in the graveyard (publisher: %s)" % (len(approved), len(denied), me))
    return len(approved), len(denied)


def run(*cmd, **kw):
    print("> " + " ".join(cmd))
    subprocess.run(cmd, check=True, cwd=ROOT, **kw)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    full = "--full" in sys.argv
    if not args or not re.fullmatch(r"\d+(\.\d+){0,3}", args[0]):
        raise SystemExit(__doc__)
    version, notes = args[0], (args[1] if len(args) > 1 else "")
    text = open(VERSION_FILE, encoding="utf-8").read()
    old = re.search(r'const VERSION := "([^"]+)"', text).group(1)
    repo = re.search(r'const RELEASES_REPO := "([^"]+)"', text).group(1)
    if [int(x) for x in version.split(".")] <= [int(x) for x in old.split(".")]:
        raise SystemExit("%s isn't newer than the current version %s" % (version, old))

    bake_approvals(version)
    if "--approvals-only" in sys.argv:
        return
    text = text.replace('const VERSION := "%s"' % old, 'const VERSION := "%s"' % version)
    open(VERSION_FILE, "w", encoding="utf-8", newline="\n").write(text)

    os.makedirs(BUILD, exist_ok=True)
    pack = os.path.join(BUILD, "SeedSplicer-%s.pck" % version)
    run(GODOT, "--headless", "--path", ROOT, "--export-pack", PRESET, pack)
    digest = hashlib.sha256(open(pack, "rb").read()).hexdigest()
    sha_file = pack + ".sha256"
    open(sha_file, "w", newline="\n").write("%s  %s\n" % (digest, os.path.basename(pack)))
    assets = [pack, sha_file]

    if full:
        # the exe has its pack inside (embed_pck), so one file is the whole game
        exe = os.path.join(BUILD, "windows", "SeedSplicer.exe")
        os.makedirs(os.path.dirname(exe), exist_ok=True)
        run(GODOT, "--headless", "--path", ROOT, "--export-release", PRESET, exe)
        bundle = os.path.join(BUILD, "SeedSplicer-%s-windows.zip" % version)
        with zipfile.ZipFile(bundle, "w", zipfile.ZIP_DEFLATED) as z:
            z.write(exe, "SeedSplicer.exe")
        assets.append(bundle)

    run("git", "add", "-A")
    run("git", "commit", "-m", "Release v%s" % version + ("\n\n" + notes if notes else ""))
    run("git", "tag", "v%s" % version)
    run("git", "push", "origin", "HEAD", "--tags")
    run(GH, "release", "create", "v%s" % version, *assets, "--repo", repo,
        "--title", "SeedSplicer v%s" % version, "--notes", notes or "Update v%s" % version)
    print("\nPublished v%s to %s. Games older than it update the next time they start." % (version, repo))


if __name__ == "__main__":
    main()
