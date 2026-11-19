This folder is a copy that Seed Splicer writes by itself (it is redone whenever your seeds change).

seed_splicer_sprites.png  every seed's art on a 32x32 grid, one row per seed:
    4 block-art boxes (block + 3 animation frames), then seed, sprout, sapling, crop (fully grown, with its block fruits)
seed_splicer_sprites.json  which seed is on which row
block_art/  each seed's block art strip (4 boxes of 32x32)

Editing these files changes nothing in the game. To change block art: draw on the sprite sheet,
then use Import Sprite Sheet in the Seeds panel.
