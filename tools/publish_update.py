"""Publishes an over-the-air update: players' games download it the next time they start.

    python tools/publish_update.py 1.0.1 "What changed"
    python tools/publish_update.py 1.0.1 "What changed" --full     (also a full Windows download)

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
import hashlib
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
