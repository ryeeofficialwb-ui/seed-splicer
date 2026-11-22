-- Seed Splicer pixel-art UI kit for Aseprite.
--
-- Run from the project folder:
--   Aseprite.exe -b --script-param root=E:/seed-splicer --script art/make_ui.lua
--
-- Makes:
--   assets/ui/<piece>.png        every UI piece, exported at 2x (1 art pixel = 2x2 texture pixels)
--                                so 9-slice corners stay crisp when Godot stretches the middle
--   art/ui/ui_kit.aseprite       all pieces at 1x on one canvas (to look at / retouch by hand)
--   art/ui/ui_kit_preview.png    the same at 4x
--
-- The game reads the PNGs in scripts/ui_kit.gd. 9-slice margins there are in TEXTURE pixels
-- (art pixels x 2). Colors follow the game's violet panels and sprout-green accent.

local root = app.params["root"] or "."
local SCALE = 2
local function hex(s, a)
  local r = tonumber(s:sub(2, 3), 16)
  local g = tonumber(s:sub(4, 5), 16)
  local b = tonumber(s:sub(6, 7), 16)
  return app.pixelColor.rgba(r, g, b, a or 255)
end
local CLEAR = app.pixelColor.rgba(0, 0, 0, 0)

local C = {
  O        = hex("#07050c"),  -- outline
  ink      = hex("#0b0912"),
  deep     = hex("#120e1a"),
  panel    = hex("#15111e"),
  raised   = hex("#211a2e"),
  title    = hex("#241c35"),
  hover    = hex("#2c2340"),
  border   = hex("#3b3150"),
  frame    = hex("#4a3d66"),
  frame_l  = hex("#5d4f80"),
  frame_ll = hex("#7a6aa4"),
  hl       = hex("#3a2f50"),
  hl2      = hex("#45386a"),
  shadow   = hex("#050308"),
  accent   = hex("#a6ff6e"),
  accent_d = hex("#5e9a3a"),
  accent_dd= hex("#2f5a1c"),
  text     = hex("#ece8f7"),
  muted    = hex("#9a94b0"),
  gold     = hex("#ffc94a"),
  gold_l   = hex("#fff0a8"),
  gold_d   = hex("#c4842a"),
  gold_dd  = hex("#6b3f10"),
  gold_o   = hex("#2a1806"),
  red      = hex("#a8323e"),
  red_l    = hex("#e0606a"),
  red_d    = hex("#5a1520"),
  blue     = hex("#8fd0ff"),
  blue_d   = hex("#3a6ea8"),
  cloud    = hex("#d8e4f4"),
  cloud_d  = hex("#8a9ab8"),
  storm    = hex("#5a5a80"),
  storm_d  = hex("#363652"),
  white    = hex("#ffffff"),
  silver   = hex("#c0c0c0"),
  gray     = hex("#808080"),
  brown    = hex("#b98a52"),
  brown_d  = hex("#7a5430"),
  brown_l  = hex("#e2bf86"),
  green    = hex("#4fc04a"),
  green_l  = hex("#a6ff6e"),
  green_d  = hex("#2a7a2a"),
}

---------------------------------------------------------------------------
-- helpers

local function new_img(w, h)
  local img = Image(w, h, ColorMode.RGB)
  img:clear(CLEAR)
  return img
end

local function px(img, x, y, c)
  if c and x >= 0 and y >= 0 and x < img.width and y < img.height then img:drawPixel(x, y, c) end
end

local function rect(img, x, y, w, h, c)
  for j = y, y + h - 1 do for i = x, x + w - 1 do px(img, i, j, c) end end
end

-- A beveled box: outline ring (corners cut), optional inner border ring, fill, light top row
-- (+ left column), dark bottom rows (+ right column).
-- spec: { o, border, fill, top, left, bottom, right, bottom_rows, cut }
local function box(w, h, s)
  local img = new_img(w, h)
  local cut = s.cut == nil and 1 or s.cut
  rect(img, 0, 0, w, h, s.o)
  local inset = 1
  if s.border then rect(img, 1, 1, w - 2, h - 2, s.border); inset = 2 end
  rect(img, inset, inset, w - inset * 2, h - inset * 2, s.fill)
  if s.top then rect(img, inset, inset, w - inset * 2, 1, s.top) end
  if s.left then rect(img, inset, inset, 1, h - inset * 2, s.left) end
  local br = s.bottom_rows or 1
  if s.bottom then rect(img, inset, h - inset - br, w - inset * 2, br, s.bottom) end
  if s.right then rect(img, w - inset - 1, inset, 1, h - inset * 2, s.right) end
  -- cut the corners (1 = a single pixel, 2 = a rounder corner)
  local function clear_corner(cx, cy, dx, dy)
    px(img, cx, cy, CLEAR)
    if cut >= 2 then
      px(img, cx + dx, cy, CLEAR); px(img, cx, cy + dy, CLEAR)
      px(img, cx + dx, cy + dy, s.o)
    end
  end
  if cut >= 1 then
    clear_corner(0, 0, 1, 1); clear_corner(w - 1, 0, -1, 1)
    clear_corner(0, h - 1, 1, -1); clear_corner(w - 1, h - 1, -1, -1)
  end
  return img
end

-- A picture from rows of characters; legend maps a character to a color ("." = clear).
local function map(rows, legend)
  local h = #rows
  local w = 0
  for _, r in ipairs(rows) do w = math.max(w, #r) end
  local img = new_img(w, h)
  for y, r in ipairs(rows) do
    for x = 1, #r do
      local ch = r:sub(x, x)
      if ch ~= "." and ch ~= " " then px(img, x - 1, y - 1, legend[ch]) end
    end
  end
  return img
end

local function scaled(img, k)
  local out = new_img(img.width * k, img.height * k)
  for y = 0, img.height - 1 do
    for x = 0, img.width - 1 do
      local c = img:getPixel(x, y)
      if app.pixelColor.rgbaA(c) > 0 then rect(out, x * k, y * k, k, k, c) end
    end
  end
  return out
end

local function transpose(img)
  local out = new_img(img.height, img.width)
  for y = 0, img.height - 1 do
    for x = 0, img.width - 1 do out:drawPixel(y, x, img:getPixel(x, y)) end
  end
  return out
end

local function stamp(dst, src, ox, oy)
  for y = 0, src.height - 1 do
    for x = 0, src.width - 1 do
      local c = src:getPixel(x, y)
      if app.pixelColor.rgbaA(c) > 0 then px(dst, ox + x, oy + y, c) end
    end
  end
end

local pieces = {}  -- { name, img } in order, for the overview sheet
local function save(name, img)
  scaled(img, SCALE):saveAs(root .. "/assets/ui/" .. name .. ".png")
  table.insert(pieces, { name = name, img = img })
end

---------------------------------------------------------------------------
-- buttons (16x16, 9-slice margin 4 art px)

save("button_normal",   box(16, 16, { o = C.O, fill = C.raised, top = C.hl, bottom = C.deep, bottom_rows = 2 }))
save("button_hover",    box(16, 16, { o = C.accent_d, fill = C.hover, top = C.hl2, bottom = C.raised, bottom_rows = 2 }))
save("button_pressed",  box(16, 16, { o = C.accent, fill = C.ink, top = C.shadow }))
save("button_disabled", box(16, 16, { o = C.border, fill = C.panel, bottom = C.ink, bottom_rows = 2 }))
local focus = new_img(16, 16)
rect(focus, 0, 0, 16, 1, C.accent); rect(focus, 0, 15, 16, 1, C.accent)
rect(focus, 0, 0, 1, 16, C.accent); rect(focus, 15, 0, 1, 16, C.accent)
px(focus, 0, 0, CLEAR); px(focus, 15, 0, CLEAR); px(focus, 0, 15, CLEAR); px(focus, 15, 15, CLEAR)
save("button_focus", focus)

-- the gold Shop button
save("gold_normal",  box(16, 16, { o = C.gold_o, fill = C.gold, top = C.gold_l, bottom = C.gold_d, bottom_rows = 2 }))
save("gold_hover",   box(16, 16, { o = C.gold_o, border = C.white, fill = C.gold_l, bottom = C.gold, bottom_rows = 2 }))
save("gold_pressed", box(16, 16, { o = C.gold_o, fill = C.gold_d, top = C.gold_dd }))

-- red (Reset Progress, Log out)
save("danger_normal",  box(16, 16, { o = C.O, fill = C.red, top = C.red_l, bottom = C.red_d, bottom_rows = 2 }))
save("danger_hover",   box(16, 16, { o = C.red_l, fill = C.red_l, top = C.white, bottom = C.red, bottom_rows = 2 }))
save("danger_pressed", box(16, 16, { o = C.red_l, fill = C.red_d, top = C.O }))

-- flat (title-bar buttons, list rows): only shows on hover / press
save("flat_hover",   box(12, 12, { o = C.frame, fill = C.hover }))
save("flat_pressed", box(12, 12, { o = C.accent_d, fill = C.ink }))

---------------------------------------------------------------------------
-- panels and windows

save("panel",    box(16, 16, { o = C.O, border = C.border, fill = C.panel, top = C.raised }))
save("window",   box(20, 20, { o = C.O, border = C.frame, fill = C.panel, top = C.title, cut = 2 }))
save("titlebar", box(12, 12, { o = C.title, fill = C.title, top = C.hover, bottom = C.frame, cut = 0 }))
save("tooltip",  box(12, 12, { o = C.O, border = C.frame_l, fill = C.raised }))
save("chip",     box(12, 12, { o = C.O, border = C.border, fill = C.deep, cut = 2 }))
save("toast",    box(16, 16, { o = C.O, border = C.frame_l, fill = C.title, top = C.hover, cut = 2 }))
save("bubble",   box(16, 16, { o = C.O, border = C.gold, fill = C.raised, top = C.hover, cut = 2 }))

-- sunken fields: LineEdit, ItemList, slider tracks
save("inset",       box(12, 12, { o = C.O, fill = C.ink, top = C.shadow, left = C.shadow, bottom = C.hover, right = C.hover }))
save("inset_focus", box(12, 12, { o = C.accent_d, fill = C.ink, top = C.shadow, left = C.shadow, bottom = C.hover, right = C.hover }))

-- list rows
save("row_hover",    box(8, 8, { o = C.hover, fill = C.raised, cut = 0 }))
save("row_selected", box(8, 8, { o = C.accent_d, fill = C.hover, cut = 0 }))

-- tabs (open at the bottom)
local function tab(fill, top_line, o)
  local img = box(12, 12, { o = o, fill = fill, top = top_line })
  rect(img, 1, 11, 10, 1, fill)  -- no outline along the bottom: the tab joins its page
  return img
end
save("tab_selected",   tab(C.panel, C.accent, C.O))
save("tab_unselected", tab(C.ink, C.raised, C.O))
save("tab_hover",      tab(C.raised, C.hl2, C.O))
save("tab_panel",      box(12, 12, { o = C.O, border = C.border, fill = C.panel, cut = 0 }))

-- separators
local sep_h = new_img(4, 2); rect(sep_h, 0, 0, 4, 1, C.O); rect(sep_h, 0, 1, 4, 1, C.hover)
save("sep_h", sep_h)
save("sep_v", transpose(sep_h))
local divider = new_img(2, 16); rect(divider, 0, 2, 1, 12, C.O); rect(divider, 1, 2, 1, 12, C.frame)
save("divider", divider)

-- scrollbars (vertical, then the same turned sideways)
local grab   = box(6, 10, { o = C.O, fill = C.frame, left = C.frame_l })
local grab_h = box(6, 10, { o = C.O, fill = C.frame_l, left = C.frame_ll })
local grab_p = box(6, 10, { o = C.O, fill = C.accent_d, left = C.accent })
local track  = box(6, 10, { o = C.deep, fill = C.ink, cut = 0 })
save("scroll_grab", grab); save("scroll_grab_hover", grab_h); save("scroll_grab_pressed", grab_p); save("scroll_track", track)
save("hscroll_grab", transpose(grab)); save("hscroll_grab_hover", transpose(grab_h))
save("hscroll_grab_pressed", transpose(grab_p)); save("hscroll_track", transpose(track))

-- slider
save("slider_track", box(8, 6, { o = C.O, fill = C.ink, top = C.shadow, bottom = C.hover }))
save("slider_fill",  box(8, 6, { o = C.O, fill = C.accent_d, top = C.accent }))
save("slider_grab", map({
  ".oooooo.",
  "oWWWWWWo",
  "oWLLLLso",
  "oWLLLLso",
  "oWLLLLso",
  "oWLLLLso",
  "oWLLLLso",
  "oWLLLLso",
  "osssssso",
  ".oooooo.",
}, { o = C.O, W = C.white, L = C.silver, s = C.gray }))

---------------------------------------------------------------------------
-- small icons

local ink = { o = C.O, W = C.text, k = C.ink, S = C.shadow, h = C.hover, a = C.accent, A = C.accent_d,
  L = C.muted, g = C.gold, G = C.gold_d, y = C.gold_l }

save("check_off", map({
  ".oooooooo.",
  "oSSSSSSSSo",
  "oSkkkkkkho",
  "oSkkkkkkho",
  "oSkkkkkkho",
  "oSkkkkkkho",
  "oSkkkkkkho",
  "oSkkkkkkho",
  "ohhhhhhhho",
  ".oooooooo.",
}, ink))
save("check_on", map({
  ".oooooooo.",
  "oSSSSSSSSo",
  "oSkkkkkaao",
  "oSkkkkaaao",
  "oSakkaaako",
  "oSaaaaakho",
  "oSkaaakkho",
  "oSkkakkkho",
  "ohhhhhhhho",
  ".oooooooo.",
}, ink))
save("radio_off", map({
  "...oooo...",
  ".ooSSSSoo.",
  ".oSkkkkho.",
  "oSkkkkkkho",
  "oSkkkkkkho",
  "oSkkkkkkho",
  "oSkkkkkkho",
  ".oSkkkkho.",
  ".oohhhhoo.",
  "...oooo...",
}, ink))
save("radio_on", map({
  "...oooo...",
  ".ooSSSSoo.",
  ".oSkkkkho.",
  "oSkkaakkho",
  "oSkaaaakho",
  "oSkaaaakho",
  "oSkkaakkho",
  ".oSkkkkho.",
  ".oohhhhoo.",
  "...oooo...",
}, ink))
save("arrow_down", map({
  "WWWWWWW",
  ".WWWWW.",
  "..WWW..",
  "...W...",
}, ink))
save("arrow_right", transpose(map({
  "WWWWWWW",
  ".WWWWW.",
  "..WWW..",
  "...W...",
}, ink)))
save("icon_close", map({
  "WW....WW",
  "WWW..WWW",
  ".WWWWWW.",
  "..WWWW..",
  "..WWWW..",
  ".WWWWWW.",
  "WWW..WWW",
  "WW....WW",
}, ink))
save("icon_collapse", map({
  "........",
  "........",
  "........",
  "WWWWWWWW",
  "WWWWWWWW",
  "........",
  "........",
  "........",
}, ink))
save("icon_expand", map({
  "...WW...",
  "...WW...",
  "...WW...",
  "WWWWWWWW",
  "WWWWWWWW",
  "...WW...",
  "...WW...",
  "...WW...",
}, ink))
save("pointer", map({
  "...oooooo...",
  "...oyggGo...",
  "...oyggGo...",
  "...oyggGo...",
  "...oyggGo...",
  "oooogggGoooo",
  ".oyggggggGo.",
  "..oyggggGo..",
  "...oyggGo...",
  "....oygo....",
  ".....oo.....",
}, ink))
save("bubble_tail", map({
  "oyyyyyyyyo",
  ".oRRRRRRo.",
  "..oRRRRo..",
  "...oRRo...",
  "....oo....",
}, { o = C.O, y = C.gold, R = C.raised }))

---------------------------------------------------------------------------
-- toolbar icons (12x12)

save("icon_shop", map({
  ".o.o.o.o.o..",
  "oyoyoyoyoyo.",
  "oyyyyyyyyyo.",
  "oGGGGGGGGGo.",
  "ogggggggggo.",
  "ogggaAaggggo",
  "oggaAAAAggo.",
  "oggaAAAAggo.",
  "ogggaAagggo.",
  "ogggggggggo.",
  "oGGGGGGGGGo.",
  ".ooooooooo..",
}, ink))
save("icon_seeds", map({
  "........oo..",
  ".......oaao.",
  "......oaAo..",
  "....oooAo...",
  "...obbboo...",
  "..obybbbo...",
  ".obybbbbo...",
  ".obbbbbdo...",
  ".obbbbdo....",
  ".obbddo.....",
  "..oooo......",
  "............",
}, { o = C.O, a = C.accent, A = C.accent_d, b = C.brown, d = C.brown_d, y = C.brown_l }))
save("icon_splices", map({
  ".oo......oo.",
  "obbo....oppo",
  "obdo....opqo",
  ".oo......oo.",
  "..LL....LL..",
  "...LL..LL...",
  "....LLLL....",
  "....oooo....",
  "...oaaaAo...",
  "...oaaaAo...",
  "...oAAAAo...",
  "....oooo....",
}, { o = C.O, L = C.muted, a = C.accent, A = C.accent_d, b = C.brown, d = C.brown_d, p = hex("#c58bff"), q = hex("#7a4ab0") }))
save("icon_tree", map({
  "...oooooo...",
  "...oaaaao...",
  "...oAAAAo...",
  "...oooooo...",
  ".....LL.....",
  "..LLLLLLLL..",
  "..L......L..",
  "ooooo..ooooo",
  "obbbo..oppo.",
  "obbbo..oppo.",
  "odddo..oqqo.",
  "ooooo..oooo.",
}, { o = C.O, L = C.muted, a = C.accent, A = C.accent_d, b = C.brown, d = C.brown_d, p = hex("#c58bff"), q = hex("#7a4ab0") }))
save("icon_book", map({
  "..ooooooooo.",
  ".oqpppppppo.",
  ".oqpyyyyppo.",
  ".oqpppppppo.",
  ".oqpyyyppo..",
  ".oqpppppppo.",
  ".oqpppppppo.",
  ".oqpppppppo.",
  ".oqpppppppo.",
  ".oqWWWWWWWo.",
  ".oqLLLLLLLo.",
  "..ooooooooo.",
}, { o = C.O, p = hex("#7a4ab0"), q = hex("#4a2a70"), y = C.gold, W = C.text, L = C.muted }))
save("icon_gear", map({
  "....oooo....",
  ".oo.oLLo.oo.",
  ".oLooLLooLo.",
  "..oLLLLLLo..",
  "ooLLLooLLLoo",
  "oLLLo..oLLLo",
  "oLLLo..oLLLo",
  "ooLLLooLLLoo",
  "..oLLLLLLo..",
  ".oLooLLooLo.",
  ".oo.oLLo.oo.",
  "....oooo....",
}, { o = C.O, L = C.silver }))
save("icon_help", map({
  "...oooooo...",
  "..oWWWWWWo..",
  ".oWWooooWWo.",
  ".oooo..oWWo.",
  ".....ooWWo..",
  "....oWWWo...",
  "....oWWo....",
  "....oooo....",
  "....oooo....",
  "....oWWo....",
  "....oWWo....",
  "....oooo....",
}, { o = C.O, W = C.gold }))
save("icon_user", map({
  "....oooo....",
  "...oWWWWo...",
  "..oWWWWWWo..",
  "..oWWWWWWo..",
  "..oWWWWWWo..",
  "...oWWWWo...",
  "....oooo....",
  "..oooooooo..",
  ".oaaaaaaaao.",
  "oaaaaaaaaaao",
  "oAAAAAAAAAAo",
  "oooooooooooo",
}, { o = C.O, W = C.text, a = C.accent, A = C.accent_d }))
save("icon_upload", map({
  ".....oo.....",
  "....oaao....",
  "...oaaaao...",
  "..oaaaaaao..",
  ".ooooaaoooo.",
  "....oaao....",
  "....oaao....",
  "....oooo....",
  "o..........o",
  "oW........Wo",
  "oWWWWWWWWWWo",
  "oooooooooooo",
}, { o = C.O, a = C.accent, W = C.muted }))

-- weather (12x12)
save("w_rain", map({
  "............",
  "....oooo....",
  "..ooccccoo..",
  ".occcccccco.",
  "occccccccCCo",
  "oCCCCCCCCCCo",
  ".oooooooooo.",
  "..b...b...b.",
  ".b...b...b..",
  "...b...b....",
  "..b...b.....",
  "............",
}, { o = C.O, c = C.cloud, C = C.cloud_d, b = C.blue }))
save("w_star", map({
  ".....oo.....",
  "....oyyo....",
  "....oyyo....",
  "oooooyyooooo",
  "oyyyyggggggo",
  ".oyggggggGo.",
  "..oggggggo..",
  "..oggggGGo..",
  ".oggGooGGGo.",
  ".oGGo..oGGo.",
  "oGGo....oGGo",
  "ooo......ooo",
}, ink))
save("w_thunder", map({
  "....oooo....",
  "..oossssoo..",
  ".osssssssso.",
  "osssssssSSSo",
  "oSSSSSSSSSSo",
  ".oooooyoooo.",
  ".....oyyo...",
  "....oyyo....",
  "...oyyyyo...",
  "....ooyo....",
  ".....oyo....",
  ".....oo.....",
}, { o = C.O, s = C.storm, S = C.storm_d, y = C.gold }))
save("w_clear", map({
  "....oooo....",
  "..oo....oo..",
  ".o..mmmm..o.",
  ".o.mmmmmm.o.",
  "o.mmmmmmmm.o",
  "o.mmmmmmmm.o",
  "o.mmmmmmmm.o",
  "o.mmmmmmmm.o",
  ".o.mmmmmm.o.",
  ".o..mmmm..o.",
  "..oo....oo..",
  "....oooo....",
}, { o = C.border, m = C.muted }))

---------------------------------------------------------------------------
-- cards and booster packs

-- card body (dark, not tinted) + border (white, tinted with the card's rarity color in game)
save("card_base", box(16, 16, { o = C.O, border = C.hover, fill = C.deep, top = C.raised, cut = 2 }))
local cb = new_img(16, 16)
rect(cb, 1, 1, 14, 2, C.white); rect(cb, 1, 13, 14, 2, C.white)
rect(cb, 1, 1, 2, 14, C.white); rect(cb, 13, 1, 2, 14, C.white)
rect(cb, 3, 3, 10, 1, C.gray); rect(cb, 3, 12, 10, 1, C.gray)
rect(cb, 3, 3, 1, 10, C.gray); rect(cb, 12, 3, 1, 10, C.gray)
px(cb, 1, 1, CLEAR); px(cb, 14, 1, CLEAR); px(cb, 1, 14, CLEAR); px(cb, 14, 14, CLEAR)
px(cb, 2, 2, C.silver); px(cb, 13, 2, C.silver); px(cb, 2, 13, C.silver); px(cb, 13, 13, C.silver)
save("card_border", cb)

-- the seed emblem used on the card back and the pack (made from the seeds icon, 2x)
local emblem = map({
  "........oo..",
  ".......oaao.",
  "......oaAo..",
  "....oooAo...",
  "...obbboo...",
  "..obybbbo...",
  ".obybbbbo...",
  ".obbbbbdo...",
  ".obbbbdo....",
  ".obbddo.....",
  "..oooo......",
}, { o = C.O, a = C.accent, A = C.accent_d, b = C.brown, d = C.brown_d, y = C.brown_l })

-- card back 32x44
local back = box(32, 44, { o = C.O, border = C.frame_l, fill = C.title, cut = 2 })
rect(back, 2, 2, 28, 1, C.frame_ll)
for y = 4, 39 do
  for x = 4, 27 do
    if (x + y) % 4 == 0 then px(back, x, y, C.hover) end
  end
end
rect(back, 3, 3, 26, 1, C.frame); rect(back, 3, 40, 26, 1, C.frame)
rect(back, 3, 3, 1, 38, C.frame); rect(back, 28, 3, 1, 38, C.frame)
rect(back, 7, 11, 18, 22, C.deep)
rect(back, 7, 11, 18, 1, C.gold_d); rect(back, 7, 32, 18, 1, C.gold_d)
rect(back, 7, 11, 1, 22, C.gold_d); rect(back, 24, 11, 1, 22, C.gold_d)
stamp(back, scaled(emblem, 1), 10, 16)
for _, s in ipairs({ { 6, 6 }, { 25, 6 }, { 6, 37 }, { 25, 37 } }) do
  px(back, s[1], s[2], C.gold); px(back, s[1] - 1, s[2], C.gold_d); px(back, s[1] + 1, s[2], C.gold_d)
  px(back, s[1], s[2] - 1, C.gold_d); px(back, s[1], s[2] + 1, C.gold_d)
end
save("card_back", back)

-- booster pack 40x56: gold foil crimps (zigzag) top and bottom, green wrapper, the seed emblem
local pack = new_img(40, 56)
-- wrapper body
rect(pack, 1, 8, 38, 40, C.green)
for y = 8, 47 do
  px(pack, 1, y, C.green_d); px(pack, 2, y, C.green_d); px(pack, 38, y, C.green_d)
  px(pack, 37, y, C.green_d); px(pack, 3, y, C.green_l)
end
-- shine stripe
for y = 8, 47 do
  local x = 8 + math.floor((47 - y) / 5)
  px(pack, x, y, C.green_l); px(pack, x + 1, y, C.accent)
end
-- band behind the emblem
rect(pack, 1, 15, 38, 27, C.green_d)
rect(pack, 1, 15, 38, 1, C.gold); rect(pack, 1, 41, 38, 1, C.gold)
stamp(pack, scaled(emblem, 2), 8, 17)
-- crimps
local function crimp(y0, h, down)
  rect(pack, 1, y0, 38, h, C.gold)
  for x = 1, 38 do
    if x % 2 == 0 then px(pack, x, y0 + (down and h - 1 or 0), C.gold_d) end
  end
  rect(pack, 1, y0 + math.floor(h / 2), 38, 1, C.gold_l)
end
crimp(1, 7, false)
crimp(48, 7, true)
-- zigzag top / bottom edge
for x = 0, 39 do
  local zig = (x % 4 < 2) and 0 or 1
  px(pack, x, zig, C.O)
  for y = 0, zig - 1 do px(pack, x, y, CLEAR) end
  px(pack, x, 55 - zig, C.O)
  for y = 56 - zig, 55 do px(pack, x, y, CLEAR) end
end
-- outline sides
for y = 1, 54 do px(pack, 0, y, C.O); px(pack, 39, y, C.O) end
-- tear line (dotted) under the top crimp
for x = 2, 37, 2 do px(pack, x, 8, C.gold_dd) end
-- little stars
for _, s in ipairs({ { 6, 13 }, { 33, 12 }, { 31, 42 }, { 7, 43 } }) do
  px(pack, s[1], s[2], C.white); px(pack, s[1] - 1, s[2], C.gold_l); px(pack, s[1] + 1, s[2], C.gold_l)
  px(pack, s[1], s[2] - 1, C.gold_l); px(pack, s[1], s[2] + 1, C.gold_l)
end
save("pack", pack)

---------------------------------------------------------------------------
-- overview sheet (1x) + 4x preview

local cols, pad = 8, 3
local cell_w, cell_h = 0, 0
for _, p in ipairs(pieces) do
  cell_w = math.max(cell_w, p.img.width); cell_h = math.max(cell_h, p.img.height)
end
local rows = math.ceil(#pieces / cols)
local sheet = new_img(cols * (cell_w + pad) + pad, rows * (cell_h + pad) + pad)
rect(sheet, 0, 0, sheet.width, sheet.height, hex("#2a2a2a"))
for i, p in ipairs(pieces) do
  local cx = ((i - 1) % cols) * (cell_w + pad) + pad
  local cy = math.floor((i - 1) / cols) * (cell_h + pad) + pad
  stamp(sheet, p.img, cx, cy)
end
local spr = Sprite(sheet.width, sheet.height, ColorMode.RGB)
spr:newCel(spr.layers[1], 1, sheet, Point(0, 0))
spr.layers[1].name = "UI kit"
spr:saveAs(root .. "/art/ui/ui_kit.aseprite")
spr:close()
scaled(sheet, 4):saveAs(root .. "/art/ui/ui_kit_preview.png")
print("UI kit: " .. #pieces .. " pieces")
