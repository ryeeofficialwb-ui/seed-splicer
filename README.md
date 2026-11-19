# Seed Splicer

A seed-combining sandbox (Godot 4.7). Four seeds float in an empty void. Drag one onto another to splice them into a new seed, name and color it, and add it to your dictionary.

## Controls
| Action | Input |
|---|---|
| Splice | Drag a seed onto another seed in the void (or drag one from the Seeds tab onto a floating seed) |
| Spawn a seed | Click it in the **Seeds** tab, or drag it into the void |
| Sort / filter the Seeds list | The sort menu has **Bountiful first**, **Farmable first** and **Not Farmable first** (the other tags follow best to worst, rarest first inside each group). The **Show** menu under it lists only one tag. Both work together with search |
| Edit a seed (name, pattern, colors, tag) | **Double-click** it, in the void or in the Seeds tab (right-click in the Seeds tab also works) |
| Remove / copy a floating seed | Right-click / Ctrl+click it |
| See every splice | The floating **Splices** window (click a row, or drag it into the void, to get its result) |
| Move, collapse or hide the Splices window | Drag its title bar / **–** button or double-click the title / **×** button. The **Splices** button (top right) brings it back |
| See how a seed is made, as a tree | **Recipe Tree** button (top right). Pick a seed on the left (it has the same search, sort and tag filter as the Seeds panel, and tints each seed by its tag). Drag to pan, mouse wheel to zoom, click a seed to center the tree on it, **Back** / **Fit** at the top |
| Hide or show the Seeds panel | **Seeds** button (top right) or **Ctrl+B**. The void takes the whole window while it's hidden |
| Make the Seeds panel wider / narrower | Drag the thin strip on its left edge (320 to 640 px) |
| Fullscreen, window size, UI size | **Display** button (top right), or **F11** to toggle fullscreen |
| Make your own Tier 1 seed | **+ Add Seed** |
| Share with friends | **Export List** saves your seeds + splices to a `.json` file (plus a sprite sheet of every seed, see below); **Import List** merges a friend's file into yours |
| Draw your blocks | **Export Sprite Sheet** saves just the sprite sheet PNG; draw in the 4 boxes at the left of each row, then **Import Sprite Sheet** (see below) |

Two copies of the same seed can't be spliced together.

## Recipe Tree
The seed you pick is at the top, with the two seeds that splice into it directly below, joined by a **+**, and so on down to the Tier 1 seeds (the ones you start with or added yourself). Under the tree, a line lists which Tier 1 seeds you need in total.
- A seed can have more than one recipe (when you give a new splice the name of a seed you already have). It then shows a small **1/2** badge: click it to switch to the other recipe.
- If a recipe needs a seed that is already higher up the same branch, that branch stops at a **loop** card instead of growing forever.
- Seeds you imported from a friend show up here too.
- **Zoom:** you can zoom out as far as you like. Zoomed far out, cards shrink to colored dots.
- **Magnifier:** docked at the bottom right, it shows the part of the tree under your cursor up close. **Shift + mouse wheel** changes how strong it is, and the **Magnifier** checkbox at the top turns it on or off.
- **Side column:** above the magnifier are the seed's drop and category, and the **splice math**. For example, "To make Big Seed from scratch: 5 splices (4 different recipes to discover), longest chain: 4 splices in a row, 6 Tier 1 seeds."
  - An ingredient needed twice is spliced twice, but its recipe only has to be discovered once.
  - Hovering any card tells you how many splices that seed takes on its own.

## Categories
Every seed's drop has a **material** and a **hardness**. Materials:
- Soil & Sand, Stone, Metal, Wood
- Plant, Mushroom
- Glass & Crystal, Lava & Fire, Liquid, Light
- Building, Background, Object, Other

Hardness goes from **1 Very soft** to **5 Very hard**. In MushMantle that suggests 2, 4, 5, 8 or 12 hits to break (like Dirt 4, Wood 5, Stone 8, Obsidian 12).

- **Auto-sorting:** both are guessed from the seed's name with the word lists in `scripts/category_logic.gd`. For example, Magma Rock is Lava & Fire, Sandstone is Stone, Blueberry is Plant, and Obsidian is Very hard.
- **The Categories tab** (next to Seeds in the side panel) groups every seed by material or by hardness.
  - Each row has a **Material** dropdown, a **Hardness** dropdown and an **OK** box.
  - **Tick OK** to agree with the guess. It's kept from then on.
  - **Pick another material or hardness** to change it. That's kept too.
  - **Untick OK** to go back to the guess.
  - **Show** filters to still guesses, agreed, or changed by you. **Agree to all shown** ticks everything in the list.
- **Guesses** follow renames and improvements to the word lists. Agreed and changed ones never move.
- **Where else it shows:** the category is in the Seeds list tooltip and in the Recipe Tree.
- **Exports:** every export carries each seed's category, and the `reference` explains how hardness maps to MushMantle's `hits`.

## Drops: collision and collision damage
Every seed has a **drop**, the thing it gives when harvested, named after the seed (Glass Seed drops Glass). A drop is a **Block** or a **Decoration**, and it either has **Collision** (solid, you can't walk through it) or **No collision**. Drops that look dangerous also get **Collision damage**: touching them hurts. Collision damage always comes with collision.

**The seeds themselves never deal damage**, only their drops do. The seed item, the sprout and the crop are always harmless.

- **Auto-sorting:** drops are first sorted automatically from the name with simple word lists (`scripts/drop_logic.gd`):
  - Plants, mushrooms, lights, furniture and backgrounds are decorations without collision.
  - Chests, tables, statues and similar are decorations with collision.
  - Everything else is a block with collision, except liquids and gases (water, smoke...).
  - Lava, magma, fire, spikes, cactus, thorns, blades, acid, poison and death get collision damage.
- **Changing a drop yourself:** double-click a seed and use the Drops buttons under its picture. A drop you set yourself is marked "set by you" and is never changed again.
- **Guessed drops:** these follow the logic, so they update when you rename the seed or when the word lists improve.
- **New splices:** a new splice gets its guess from the name you type, and you can change it before adding it.
- **Lists:**
  - Each seed's row shows its drop. Damaging ones are red.
  - Sort with **Collision first**, **No collision first** or **Collision damage first**.
  - The **Drops** filter shows only blocks, decorations, collision, no collision, or collision damage.
- **Recipe Tree:** it shows the selected seed's drop under the recipe line. On each card, a small square next to the tag square is filled for collision, hollow for no collision, and red for collision damage.
- **Older saves:** these are sorted once when loaded, and a message shows the totals. A copy from before is kept as `seed_splicer_save.before_drops.json`.

**For your game (Claude Code):** **Export List** now writes a `reference` section at the top of the file. It explains every field and your rules, starting with "SEEDS THEMSELVES DO NOT DEAL DAMAGE". It also maps them onto MushMantle's block data: collision = `"solid": true`, collision damage = `"damage": N` like `BLK_LAVA`, backgrounds = `"background": true`, doors = `"door": true`. The amount of damage and the Bountiful numbers aren't decided yet, and the reference says to ask you.

## Tags
Every seed is **Farmable**, **Not Farmable** or **Bountiful**. The four base seeds are Bountiful. The Tier 1 seeds you add yourself (rarity 1) get whatever tag you pick. Anything made by splicing gets its tag **by chance**:

| Seed's rarity | Not Farmable | Farmable | Bountiful |
|---|---|---|---|
| 2 to 10 ("forgiven") | 50% | 37.5% | 12.5% |
| 11 and up | 75% | 18.75% | 6.25% |

That is: first 75% (or 50% up to rarity 10) Not Farmable, otherwise Farmable; then 1 in 4 of the Farmable ones become Bountiful.
- The roll happens when the splice popup opens, and it shows the result and the odds. You can't pick a tag for a new splice. The roll is kept for that pair, so cancelling and splicing again won't re-roll it.
- A splice that you name after a seed you already have just adds a recipe; the seed keeps its tag.
- You can still change any seed's tag afterwards by double-clicking it (and rarity 1 seeds you add can use any tag).
- **One-time reroll:** when a save from before this rule loads, every seed above rarity 1 is rerolled once (a message shows the totals). A seed's reroll is fixed by its id, so doing it again never changes the result. A copy of your save from before it is kept as `seed_splicer_save.before_reroll.json` in the game's save folder.
- Imported seeds keep the tags your friend's game gave them.

## Display
Open **Display** (top right) or press **F11**.
- **Window mode:** Windowed, Fullscreen Windowed (borderless), or Fullscreen (exclusive). The two fullscreen modes use your screen's own resolution.
- **Resolution (windowed):** a list of sizes that fit your screen (960×540 up to 4K). You can also just drag the window edges; the minimum is 960×540.
- **UI size:** 75%, 100% or 125%.
- The game lays itself out as if the window were at least 1280×720 and scales up from there, so every size shows the same screen, only sharper.
- Settings are saved separately from your game (`user://seed_splicer_settings.cfg`), so **Reset Progress** never changes them.
- If you start the game from inside the Godot editor's embedded Game tab, the editor owns the window and these settings can't change it. Turn off embedding, or run the game on its own.

## Crops
Every seed grows into one of **5 crop types**: **Round Tree**, **Pine**, **Twisted Tree**, **Big Flower** and **Giant Mushroom**.
- **Colors:** each type is one base texture, painted in that seed's own colors.
  - **Color 1:** the leaves, needles, petals or cap.
  - **Color 2:** fruit, cones, blossoms, the flower's center, or the mushroom's stalk and spots.
  - **Sprout:** stems and young leaves.
  - **Trunks:** bark brown mixed a little with Color 2.
- **4 growth stages:** seed (the seed's own art), sprout, sapling, crop. Each stage has the type's own shape.
- **Block fruit:** a fully grown crop carries **1 to 4 little copies of its seed's block**, like fruit. How many is picked once per seed. Only seeds that have block art grow fruit.
  - The block is shrunk by 4 to a 9x9 picture on the crop's own 32x32 pixel grid. Its frame stays a 1 px frame, and every other pixel takes the most common color of its 4x4 square, so there's no smoothing, no blur and no new colors.
  - Where the fruit hangs is set per crop type and per count in `FRUIT_SPOTS` in `scripts/crop_art.gd`.
- **Crisp previews:** the seed window draws every picture at a whole number of screen pixels per art pixel at any window size, so the pixel art never looks lumpy. The Grows row is 3x at the normal size.
- **Picking the type:** double-click a seed. The **Crop** row shows all 5 types fully grown in that seed's colors, and **Grows** under the picture shows its 4 stages.
- **New seeds:** a new splice starts with a random type that you can change before adding it. **Randomize look** also picks a random type.
- **Existing seeds:** seeds from before crops got a random type once, fixed by the seed's id, and a message says how many.
- **Imports:** imported seeds keep their friend's crop type.
- **The art:** `art/make_crops.lua` makes the template (`art/crop_template.aseprite` → `assets/crop_template.png`). It has one row per type and 3 columns: sprout, sapling, crop. Like the seed template it's role-coded, and the color key is at the top of the script. You can retouch it in Aseprite, or rebuild it and then re-import in Godot:

```
Aseprite.exe -b --script-param root=E:/seed-splicer --script art/make_crops.lua
```

## Sprite sheet and block art (for MushMantle)
The sprite sheet has every seed's art on a strict **32x32 grid**: no padding or spacing, and a transparent background.
- **Rows:** one row per seed, in your Seeds order.
- **Columns:** 8 boxes per row, so the sheet is 256 pixels wide:

| Box | x | What |
|---|---|---|
| 1 | 0 | **Your block art**: what the seed's drop looks like in the game |
| 2, 3, 4 | 32, 64, 96 | Spare boxes for the block's **animation** frames |
| 5 | 128 | Seed (also the seed item's icon) |
| 6 | 160 | Sprout |
| 7 | 192 | Sapling |
| 8 | 224 | Crop (fully grown, with its 1 to 4 block fruits) |

- **Ground line:** in the sprout, sapling and crop boxes, the bottom pixel row is the ground.

**Exporting only the sheet:** **Export Sprite Sheet** saves just the PNG. **Export List** still saves the `.json` plus the same sheet next to it, named `<list>_seeds.png`.

**Drawing your blocks:**
1. Click **Export Sprite Sheet**.
2. Open the PNG in Aseprite. Turn on a 32x32 grid to see the boxes.
3. Draw each seed's block in the first box of its row. Use boxes 2 to 4 if the block is animated.
4. Save the PNG and click **Import Sprite Sheet**.

**How importing works:**
- **What it takes:** only the 4 block boxes are read in and kept with each seed.
- **Keeping it:** your block art is in every sprite sheet you export from then on, and you can draw more and import again any time.
- **Matching rows:** each row is matched to its seed by the seed picture in box 5. So it doesn't matter if rows moved, or if you've discovered new seeds since.
  - If you restyled a seed after exporting, its picture won't match. That row is then matched by its row number, and the message tells you how many were.
  - Rows that match none of your seeds are skipped.
- **Erasing:** a row whose 4 block boxes are empty removes that seed's block art.
- **Seed and crop boxes:** they're always drawn from the seed's colors, so changes you paint there aren't kept.
- **Where it's kept:** in the game's save folder (`user://block_art/`, one small PNG per seed).
- **Seeing it in the game files:** the game keeps a copy in a `sprites` folder and rewrites it a moment after anything changes. Click **Open Sprites Folder** to open it.
  - Playing from Godot, the folder is `E:\seed-splicer\sprites`. In the exported game, it's next to `SeedSplicer.exe`. If that folder is read-only, the game's save folder is used instead.
  - It holds `seed_splicer_sprites.png` (the full sheet), `seed_splicer_sprites.json` (which seed is on which row) and `block_art/<seed id>.png`.
  - It's only a copy: editing it changes nothing. Godot ignores it (`.gdignore`), and it isn't put in builds.
- **Block variants:** `art/make_block_variants.lua` makes color variants of your **Purple Block**. It swaps only its 3 colors (lit rim, face, shadow side) and keeps the black frame and white shine exactly as you drew them. It never overwrites a block that already exists. The 10 color blocks from Red to Black were made with it:

```
Aseprite.exe -b --script-param dir="%APPDATA%/Godot/app_userdata/Seed Splicer/block_art" --script art/make_block_variants.lua
```
- **Reset Progress** deletes it too, so export the sheet first.

**In MushMantle:** its art is native 32x32 too, and its tile pages are 4 boxes wide (a block is a row, its variants or animation frames are the columns).
- The 4 block boxes are the drop block's tile row.
- Seed, sprout and sapling are the 3 growth stages of the `CRP_*_SPROUT` block.
- Crop is the grown `CRP_*` block.
- The `.json` from Export List has a `sprite_sheet` section with each row's seed, crop type, how many block frames you drew and how many fruit its crop carries (`crop_fruit`). Its `reference` explains all of this to Claude Code.
- **Checked 2026-11-19:** MushMantle's `tools/gen_database.py` reads the list fine: every seed gets its block, seed item and crop, and no seed or crop deals damage. But `tools/make_art.py` doesn't open the sprite sheet yet: it draws every block tile itself, so your drawn block art doesn't reach the game until that tool is changed to use the sheet.

## Sharing (import / export)
Importing merges a friend's list into yours, **but you choose which seeds come in.** After you pick the file, an **Import Seeds** window lists every seed they have that you don't, all ticked. Each row shows the seed's picture, rarity, tag, drop and what it's made from.
- **Picking seeds:** untick the seeds you don't want, or use **Yes to all** / **No to all**. Then click **Import N seeds**. **Cancel** adds nothing.
- **Splices:** they come in automatically when you end up with all three seeds involved. The window tells you how many before you import.
- **Missing ingredients:** if you keep a seed but untick something it's made from, its row warns you. That seed still comes in, without its recipe and with the rarity it had in their game. **Also take what they need** ticks the missing ingredients for you.
- **Seeds you already have:** they're matched by name, ignoring capitals, and never offered. Yours keep **your** look, tag, drop and rarity.
- **Your recipe always wins:** if your friend spliced the same pair as you, your result stays. The window also cross-checks recipes: a seed of theirs made from a pair that already makes one of your seeds (the same splice under another name) is marked "Same splice as your …" and starts unticked. If you import it anyway, it comes in without a recipe and can never take over yours.
- **Rarity:** imported rarities are worked out again from your copies of the parents, so the rarity rule always holds.

Your own Tier 1 seeds are included, so friends get them too.

## Rarity
Base seeds are rarity 1. A spliced seed's rarity is **the sum of its parents' rarities**: 1+1 = 2, a (2+1) = 3 seed + a 5 seed = 8. If a new splice is given the name of a seed you already have, it becomes a second recipe for that seed, and the seed keeps its first rarity. Tiers: 1 Common, 2-3 Uncommon, 4-7 Rare, 8-15 Epic, 16-31 Legendary, 32-63 Mythic, 64+ Cosmic.

## Art
Every seed is drawn at 32x32 from one Aseprite template, `art/seed_template.aseprite`. The template is role-coded: each gray or green shade marks a part (outline, shadow, body, light, shine, and sprout outline/dark/mid/light). At runtime the game paints those parts with the seed's pattern and its three colors (Color 1, Color 2, Sprout), with hue-shifted shading. You can retouch the template in Aseprite with the colors in its palette, then export it to `assets/seed_template.png`. You can also rebuild everything from the script:

```
Aseprite.exe -b --script-param root=E:/seed-splicer --script art/make_art.lua
```

The seed is a plump almond tilted 50° with fine grain and a shine streak. The sprout is a short stem with two round leaves. To try another shape, pass any of `angle`, `cx`, `cy`, `len`, `rad`, `pt` (tip sharpness) or `pb` (belly roundness) as extra `--script-param name=value` options, for example `--script-param angle=45 --script-param rad=8.4`. The script also writes `assets/seed_template.json` (tilt and center) so the Stripes, Zigzag and Half Color patterns line up with the seed's real axis; re-import the project in Godot after rebuilding.

Patterns: Half Color, Stripes, Zigzag Stripes, Shade + Polkadots, Vertical Lines, Horizontal Lines. **Shuffle** keeps the pattern type and changes its layout (stripe width, dot spacing and so on).

## Sound
Music plays as a shuffled playlist of 6 calm loops. Ten actions have a sound effect, one file each in `assets/audio/sfx/`, named after the action:
- `click`: a button
- `open`: a window opens
- `spawn`: a seed appears
- `pickup` / `drop`: grabbing and letting go of a seed
- `splice`: a known recipe
- `discover`: a new seed
- `remove`: right-click
- `error`
- `success`: import or export done

To change a sound, replace that file. **Sound** (top right) sets the music and effects volumes (0 turns them off), shuffles the songs or keeps one on repeat, and skips to the next song.

## Credits
- **Music:** "Abstraction" (Ben Burnes / Tallbeard Studios), *Music Loop Bundle*, public domain (CC0). https://tallbeard.itch.io/music-loop-bundle. Tracks used: Primordial Soup, Coral Reef, Evening Oasis, Glide, Chillout, Night Drive (`assets/audio/music/`, with its license).
- **Sound effects:** *Cozy FX* by Pizza Doggy ("Game Assets by Pizza Doggy"). They're licensed for use **inside a game only**:
  - You may share and sell the game itself.
  - You may NOT share the `.ogg` files on their own, put them in a public / open-source repository or an asset pack, or give them to AI tools. See `assets/audio/sfx/LICENSE_NOTE.txt`.
  - So share the exported game, never this project folder.

## Publishing (letting friends play)
The export presets are set up (`export_presets.cfg`) and the Steam version of Godot already includes the export templates. Builds go to `build/`, which git ignores.

- **Rebuild after changes:** in the Godot editor go to **Project → Export…**, pick **Windows** (or **Web**), then **Export Project**. Keep the path it suggests.
- **Windows:** one file, `build/windows/SeedSplicer.exe`, with everything inside it. Send the zip (`build/SeedSplicer-Windows.zip`) or upload it to itch.io.
  - Because the game isn't signed, Windows SmartScreen will warn your friends. They click **More info → Run anyway**.
  - Each friend gets their own save on their own PC.
- **Web:** upload `build/SeedSplicer-Web.zip` to itch.io as an HTML5 game ("This file will be played in the browser"). The web version saves in the browser.
  - **Import List / Export List don't work in a browser** (there's no file picker), so friends who want to swap lists need the Windows version.
- **Swapping lists:** friends click **Export List** and send you the `.json` file. You click **Import List** and pick the seeds you want.

## Code
- `scripts/game_state.gd` (autoload `Game`): seeds, recipes, rarity, name suggestions, save (`user://seed_splicer_save.json`)
- `scripts/seed_art.gd`: template to texture, the 6 patterns, shading
- `scripts/crop_art.gd`: the 5 crop types and their growth stages, painted in each seed's colors
- `scripts/block_art.gd`: the block art you import from the sprite sheet (4 frames per seed, kept in `user://block_art/`) and its shrunk crop-fruit version; `Game.build_sprite_sheet` / `Game.import_sprite_sheet` make and read the sheet
- `scripts/sprite_folder.gd`: the always-current copy of the sprite sheet in the `sprites` folder
- `scripts/pixel_picture.gd`: draws pixel art at a whole zoom on real screen pixels (the seed window's pictures)
- `scripts/void_field.gd`, `scripts/seed_token.gd`: the void and the floating seeds
- `scripts/side_panel.gd`, `scripts/side_grip.gd`: the Seeds dictionary and footer buttons; the drag strip that resizes it (its width and hidden state are saved)
- `scripts/floating_panel.gd`, `scripts/splices_window.gd`: the draggable / collapsible / hideable Splices window
- `scripts/splice_popup.gd`: the new-splice / add-seed / edit window
- `scripts/recipe_tree.gd`: the Recipe Tree menu and its drawn tree
- `scripts/seed_sort.gd`: the sort, tag and drop filter menus shared by the Seeds panel and the Recipe Tree list
- `scripts/audio_manager.gd` (autoload `Audio`), `scripts/sound_dialog.gd`: music playlist, sound effects, the Sound menu
- `scripts/import_dialog.gd`: the Import Seeds window (yes / no per seed); `Game.read_import` / `Game.apply_import` do the work
- `scripts/category_logic.gd`, `scripts/categories_tab.gd`: material + hardness guesses and the Categories tab
- `scripts/drop_logic.gd`: what each seed drops (block / decoration, collision, collision damage) and the word lists that guess it
- `scripts/display_manager.gd`, `scripts/settings_dialog.gd`, `scripts/user_settings.gd`: window mode, resolution, UI size and their saved settings
- `scripts/dev_shot.gd`: dev-only screenshots and self-tests (`-- --shot=path [--popup|--test|--test2|--test3|--test4|--test5|--test6|--test7|--test8|--test9|--test10|--test11|--test12|--test13|--test14|--test15|--test16|--test17] [--panel] [--res=1440x900] [--edit=seed_id]`, `-- --crops=out.png [--crop-n=3]` for an enlarged preview of every crop type in a few seeds' colors, `-- --fruit=out.png [--fruit-seeds=a,b]` for every crop type with 1 to 4 block fruits, or `-- --export=list.json` to export. It isn't included in exported builds). The tests write to your save and settings, so back them up first.

## Dictionary, Settings, planted stage, backgrounds and light (2026-11-19)

- **Planted stage**: a tiny leaf in the seed's colors (CropArt.PLANTED_ART) for right after planting. Growth order is seed, planted, sprout, sapling, crop. On the sprite sheet it is a 9th column at the far right (x = 256), so older columns did not move. Old 8-column sheets still import.
- **Dictionary** button (top right): every seed's block texture, rarity, material, hardness and tags, in tabs for All / Blocks / Decorations / Backgrounds. Click a seed for its 4 block boxes, 5 growth stages and a full tag list.
- **Settings** button (top right): Import/Export List, Import/Export Sprite Sheet, Open Sprites Folder, Display, Sound, Reset Progress. The Seeds panel only has Add Seed and Clear Void now.
- Seed tokens and the Seeds / Splices / Recipe Tree lists show only name and rarity.
- Drops: new kind **Background** (never collides or damages) with a checklist (emits light, cave / underground, sky / outdoors, animated), and a new **Emits light** tag on any drop (`drop.light`, `drop.bg_tags` in the export).
- Dev: `--test18`, `--dict=<id> [--dict-tab=N]`, `--hub`. Run tests against a copy of your data (point APPDATA elsewhere): older tests rewrote files in your real block_art.

## Update 1.0.0: approval stamps, graveyard, statistics, recipe tree tools (2026-11-20)

- **Approval stamp.** Every update ships an official seed list (`data/approvals.json`). A seed whose
  name is on it shows the stamp (your lily logo, `assets/stamp/`) and the name of the contributor who
  made it: under the rarity of a seed floating in the void, after the rarity in the Seeds list, and in
  the Dictionary's Approved column. `tools/publish_update.py` writes the list from your own save each
  time you publish: every seed you have is approved, signed with its `made_by` (or your name).
- **Your name.** Settings > You > Your name. Every seed you make from then on is signed with it, and
  the publish script refuses to run until it is set.
- **Graveyard.** Dictionary > a seed > *Send to graveyard*: it loses its stamp and moves to the new
  Graveyard tab. Publishing ships your graveyard too, so players see every seed that did not make it
  into the game. *Bring back from the graveyard* undoes it.
- **Statistics.** Settings > Statistics: time played (counted while the game runs, saved every
  30 seconds in `user://seed_splicer_stats.json`), sessions, seeds and splices found, rarest seed,
  approved seeds you have, graveyard size.
- **Recipe Tree.**
  - *Tree only* hides the seed list and all the side text.
  - *Compact* (on by default) stacks big branches downward so the tree keeps the window's shape
    instead of growing wider and wider. Turn it off for the classic wide tree.
  - Click the round **+** under a seed (or right-click the seed) to fold its branch away. A folded
    branch shows how many seeds it hides. *Fold all* and *Open all* do every branch at once.
  - *Shortest route (farm Farmable seeds)*: a Farmable or Bountiful seed in the tree is grown for more
    seeds instead of being spliced again, so its branch stops there, and seeds with several recipes
    use the one with the fewest splices. The side text counts the farmed seeds separately.

## Usernames, developer-only import, official seeds for everyone (2026-11-20)

- **Username** (Settings > You). Players need one to Export List; it's written on the export and on
  every seed they made. RyeeRue, KeepUpp, KeepUp and look-alikes (`Ry33_Rue`, `K33p-Upp`, `xKeepUpx`...)
  are refused in players' games (`scripts/dev_mode.gd`).
- **Developer mode** = running from the Godot editor, or `build/dev/SeedSplicer-Developer.exe`
  (export preset "Windows Developer", feature tag `developer`, built by `publish_update.py --full`, never
  uploaded). Only there: Import List, the reserved names, no auto-update.
- **Importing credits the creator:** a seed's own `made_by`, else the file's username, else
  "unknown". A player's file can't claim a reserved name. The import window shows who made each seed.
- **Official seeds for everyone:** publishing writes `data/official_list.json` (every approved seed,
  its recipes, who made it and its block art). When a player's game starts on the new version it adds
  every official seed it doesn't have (`scripts/official.gd`); seeds they already have stay theirs.
- Dev: `--test20`.
