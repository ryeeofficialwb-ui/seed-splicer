"""Publishes an over-the-air update: players' games download it the next time they start.

    python tools/publish_update.py 0.2 "What changed"
    python tools/publish_update.py 0.2 "What changed" --full     (also a full Windows download)
    python tools/publish_update.py 0.2 --approvals-only           (only write data/approvals.json)

Versions: Indev 0.1 is the first official release (the earlier test releases are 0.0.1 - 0.0.4).
Releases are titled "Seed Splicer Indev <version>" (GameVersion.STAGE).

0. Writes data/official_list.json: every seed below, with its recipes and block art. Every
   player's game adds the ones they don't have when it starts on the new version.
   Also writes the official seed list, data/approvals.json, from YOUR save: every seed you have is
   approved (players with a seed of the same name see the approval stamp + who made it), and the
   seeds you sent to the graveyard (Dictionary > Send to graveyard) are listed as denied. Your name
   comes from Settings > You (the contributor on old seeds that were made before names existed).
1. Sets GameVersion.VERSION (scripts/game_version.gd) to the new version.
2. Exports the game pack: build/SeedSplicer-update-<version>.pck + its SHA-256 (.pck.sha256), and the
   music pack (SeedSplicer-music.pck). Then SELF-TESTS the pack with the real release engine:
   nothing is published unless the game builds its whole screen.
3. Commits everything, tags it v<version> and pushes to the source repo.
4. Creates the GitHub Release v<version> on GameVersion.RELEASES_REPO (this public repo) with the pack and its
   hash. Games older than <version> download it, check the hash and restart into it.
--full also exports SeedSplicer.exe (needs Godot's export templates installed) and attaches
build/SeedSplicer-<version>-windows.zip: the complete game for new players.

Needs: git, the GitHub CLI (gh, logged in), and Godot (set GODOT to its exe if it isn't the Steam one).
Only content updates go over the air: a new Godot version needs players to download the full game.
"""
import base64
import configparser
import hashlib
import json
import os
import re
import subprocess
import shutil
import sys
import tempfile
import time
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
VERSION_FILE = os.path.join(ROOT, "scripts", "game_version.gd")
BUILD = os.path.join(ROOT, "build")
GODOT = os.environ.get("GODOT", r"E:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe")
PRESET = "Windows"
GH = r"C:\Program Files\GitHub CLI\gh.exe"
APPROVALS = os.path.join(ROOT, "data", "approvals.json")
OFFICIAL = os.path.join(ROOT, "data", "official_list.json")
USER_DIR = os.environ.get("SEED_SPLICER_USER_DIR",
    os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "Seed Splicer"))
DRAW_FIELDS = ["rarity", "pattern", "colors", "sprout", "pattern_seed", "crop", "tag", "category", "drop", "fruit_count"]


def stage():
    """GameVersion.STAGE ("Indev"): shown before the version number."""
    m = re.search(r'const STAGE := "([^"]+)"', open(VERSION_FILE, encoding="utf-8").read())
    return m.group(1) if m else ""


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
    removed = {n.strip().lower() for n in save.get("graveyard_removed", [])}  # Remove from graveyard
    approved, denied, seen = [], [], set()
    for s in save["seeds"]:
        by = (s.get("made_by") or "").strip() or me
        key = s["name"].strip().lower()
        if s.get("denied"):
            if key in removed:
                seen.add(key)
                continue
            d = {"name": s["name"], "made_by": by}
            d.update({k: s[k] for k in DRAW_FIELDS if k in s})
            d["parent_names"] = [names.get(p, "?") for p in s.get("parents", [])]
            denied.append(d)
        else:
            art_file = os.path.join(USER_DIR, "block_art", s["id"] + ".png")
            art = os.path.exists(art_file) and s.get("art_ok", True) is not False
            rsr = s.get("rsr") if isinstance(s.get("rsr"), int) and 6 <= s.get("rsr") <= 10 else None
            approved.append({"name": s["name"], "made_by": by, "art": art, "rsr": rsr})
        seen.add(key)
    # players' submissions you denied (Settings > Submissions) never entered your game: add them
    for g in save.get("graveyard", []):
        key = g.get("name", "").strip().lower()
        if key and key not in seen and key not in removed:
            d = {k: v for k, v in g.items() if k != "submission_id"}
            d["made_by"] = (g.get("made_by") or "").strip() or "unknown"
            denied.append(d)
            seen.add(key)
    # the graveyard keeps every seed denied in an earlier update (unless you have it again now)
    for d in old.get("denied", []):
        if d.get("name", "").strip().lower() not in seen and d.get("name", "").strip().lower() not in removed:
            denied.append(d)
            seen.add(d["name"].strip().lower())
    data = {"format": "seed-splicer-approvals", "version": version, "publisher": me, "published": int(time.time()),
            "approved": approved, "denied": denied}
    with open(APPROVALS, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent="\t", ensure_ascii=False)
    print("Official list: %d approved seeds, %d in the graveyard (publisher: %s)" % (len(approved), len(denied), me))
    bake_official(version, save, me)
    return len(approved), len(denied)


def bake_official(version, save, me):
    """data/official_list.json: every approved seed with its recipes and block art. Players' games
    add the ones they don't have when they start on this version (see scripts/official.gd)."""
    keep = {s["id"] for s in save["seeds"] if not s.get("denied")}
    seeds = []
    art_dir = os.path.join(USER_DIR, "block_art")
    with_art = 0
    for s in save["seeds"]:
        if s["id"] not in keep:
            continue
        o = dict(s)
        o.pop("denied", None)
        o["made_by"] = (s.get("made_by") or "").strip() or me
        art = os.path.join(art_dir, s["id"] + ".png")
        if os.path.exists(art):
            o["block_art"] = base64.b64encode(open(art, "rb").read()).decode("ascii")
            with_art += 1
        seeds.append(o)
    recipes = []
    for r in save.get("recipes", []):
        pair = r["pair"].split("|")
        if len(pair) == 2 and pair[0] in keep and pair[1] in keep and r["result"] in keep:
            recipes.append(r)
    data = {"format": "seed-splicer-list", "official": True, "version": version, "username": me, "published": int(time.time()),
            "seeds": seeds, "recipes": recipes}
    with open(OFFICIAL, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent="\t", ensure_ascii=False)
    print("Shipped to every player: %d seeds (%d with block art), %d splices" % (len(seeds), with_art, len(recipes)))


# Players who installed before 0.0.4 run the official engine; new downloads ship the slim one
# (tools/engine/build_template.ps1). Updates are only the pack, so they must work on BOTH.
TEMPLATE = os.path.join(os.path.dirname(GODOT), "editor_data", "export_templates", "4.7.2.stable", "windows_release_x86_64.exe")
SLIM_TEMPLATE = os.path.join(ROOT, "tools", "engine", "bin", "seedsplicer_template_release.x86_64.exe")
MUSIC_PACK = os.path.join(BUILD, "SeedSplicer-music.pck")


SELFTEST_CODE = 42  # main.gd quits with this under --selftest once its whole screen is built


def smoke_test(pack):
    """Runs the pack on every engine players have: the official one and the slim one."""
    for name, template in (("official", TEMPLATE), ("slim", SLIM_TEMPLATE)):
        smoke_test_on(pack, name, template)


def smoke_test_on(pack, name, template):
    """Plays the update exactly like a player's PC will: a copy of the real release engine named
    SeedSplicer.exe, this pack next to it as SeedSplicer.pck, the music pack, a throwaway user
    folder, and `--selftest`. Anything but exit code 42 (or any script error) stops the publish:
    a broken update would reach every player."""
    if not os.path.exists(template):
        raise SystemExit("Can't test the build: no %s release template at %s" % (name, template))
    tmp = tempfile.mkdtemp(prefix="seedsplicer_smoke_")
    try:
        game = os.path.join(tmp, "game")
        os.makedirs(game)
        exe = os.path.join(game, "SeedSplicer.exe")
        shutil.copy(template, exe)
        shutil.copy(pack, os.path.join(game, "SeedSplicer.pck"))
        shutil.copy(MUSIC_PACK, os.path.join(game, "SeedSplicer-music.pck"))
        env = dict(os.environ, APPDATA=os.path.join(tmp, "appdata"))
        r = subprocess.run([exe, "--headless", "--quit-after", "6000", "--", "--selftest", "--no-update"],
                           capture_output=True, text=True, env=env, timeout=180)
        out = (r.stdout or "") + (r.stderr or "")
        bad = [l for l in out.splitlines() if "SCRIPT ERROR" in l or "Parse Error" in l or "Failed to load" in l
               or "Failed to instantiate" in l or "Aborting" in l]
        if bad or r.returncode != SELFTEST_CODE:
            raise SystemExit("THE BUILD IS BROKEN on the %s engine, nothing was published (self-test exit code %d):\n  %s\n%s" % (
                name, r.returncode,"\n  ".join(bad[:10]), out[-1500:]))
        print("Smoke test passed on the %s engine: the exported game starts and builds its whole screen." % name)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def build_music_pack():
    run(GODOT, "--headless", "--path", ROOT, "--script", "res://tools/make_music_pack.gd", "--", MUSIC_PACK)
    digest = hashlib.sha256(open(MUSIC_PACK, "rb").read()).hexdigest()
    open(MUSIC_PACK + ".sha256", "w", newline="\n").write("%s  %s\n" % (digest, os.path.basename(MUSIC_PACK)))
    return [MUSIC_PACK, MUSIC_PACK + ".sha256"]


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
    old_text = text
    text = text.replace('const VERSION := "%s"' % old, 'const VERSION := "%s"' % version)
    open(VERSION_FILE, "w", encoding="utf-8", newline="\n").write(text)
    try:
        assets = build_and_test(version, full)
    except BaseException:
        open(VERSION_FILE, "w", encoding="utf-8", newline="\n").write(old_text)  # nothing published
        raise
    publish(version, notes, repo, assets)


def build_and_test(version, full):

    os.makedirs(BUILD, exist_ok=True)
    music = build_music_pack()  # attached to every release: games without music fetch it once
    pack = os.path.join(BUILD, "SeedSplicer-update-%s.pck" % version)  # (0.0.1/0.0.2 looked for SeedSplicer-<v>.pck)
    run(GODOT, "--headless", "--path", ROOT, "--export-pack", PRESET, pack)
    digest = hashlib.sha256(open(pack, "rb").read()).hexdigest()
    sha_file = pack + ".sha256"
    open(sha_file, "w", newline="\n").write("%s  %s\n" % (digest, os.path.basename(pack)))
    smoke_test(pack)
    assets = [pack, sha_file] + music

    if full:
        # the game: SeedSplicer.exe (the engine) + SeedSplicer.pck (the game) + the music pack
        exe = os.path.join(BUILD, "windows", "SeedSplicer.exe")
        os.makedirs(os.path.dirname(exe), exist_ok=True)
        run(GODOT, "--headless", "--path", ROOT, "--export-release", PRESET, exe)
        shutil.copy(MUSIC_PACK, os.path.join(os.path.dirname(exe), "SeedSplicer-music.pck"))
        bundle = os.path.join(BUILD, "SeedSplicer-%s-%s-windows.zip" % (stage(), version))
        with zipfile.ZipFile(bundle, "w", zipfile.ZIP_DEFLATED) as z:
            for name in ("SeedSplicer.exe", "SeedSplicer.pck", "SeedSplicer-music.pck"):
                z.write(os.path.join(os.path.dirname(exe), name), "SeedSplicer/" + name)
        assets.append(bundle)
        # your own Developer build (Import List, reserved names, no auto-update): never uploaded
        dev_exe = os.path.join(BUILD, "dev", "SeedSplicer-Developer.exe")
        os.makedirs(os.path.dirname(dev_exe), exist_ok=True)
        run(GODOT, "--headless", "--path", ROOT, "--export-release", "Windows Developer", dev_exe)
        shutil.copy(MUSIC_PACK, os.path.join(os.path.dirname(dev_exe), "SeedSplicer-music.pck"))
    return assets


def publish(version, notes, repo, assets):
    run("git", "add", "-A")
    run("git", "commit", "-m", "Release %s %s (v%s)" % (stage(), version, version) + ("\n\n" + notes if notes else "")
        + "\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>")
    run("git", "tag", "v%s" % version)
    run("git", "push", "origin", "HEAD", "--tags")
    run(GH, "release", "create", "v%s" % version, *assets, "--repo", repo,
        "--title", "Seed Splicer %s %s" % (stage(), version), "--notes", notes or "Update %s %s" % (stage(), version))
    print("\nPublished %s %s to %s. Games older than it update the next time they start." % (stage(), version, repo))


if __name__ == "__main__":
    main()
