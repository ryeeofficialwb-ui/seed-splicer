-- Seed Splicer crop art generator for Aseprite.
--
-- Run from the project folder:
--   Aseprite.exe -b --script-param root=E:/seed-splicer --script art/make_crops.lua
--
-- Makes:
--   art/crop_template.aseprite   source you can retouch by hand
--   assets/crop_template.png     the copy the game reads
--   assets/crop_template.json    the crop types, in row order (read by scripts/crop_art.gd)
--
-- There are 5 crop types (5 "base plates"). Every seed is one of them, and the game paints it in
-- that seed's own colors. Layout: one ROW per crop type, three 32x32 COLUMNS = the growth stages
-- after the seed: column 0 sprout, column 1 sapling, column 2 crop (fully grown).
-- (Stage 1, "seed", is the seed's own art from seed_template.png.)
-- The bottom pixel row of every cell is the ground: plants grow up from it.
--
-- ROLE-CODED like the seed template: the game swaps each exact color for a shade of one of the
-- seed's colors. Only paint with these (they are in the palette):
--                     outline  deep     dark     mid      light    shine
--   main   (Color 1)  #000000  #202020  #404040  #808080  #C0C0C0  #FFFFFF
--   leaf   (Sprout)   #004000  #006000  #008000  #00C000  #80FF80  #C0FFC0
--   accent (Color 2)  #400000  #600000  #800000  #C00000  #FF8080  #FFC0C0
--   wood   (bark: brown mixed with Color 2)
--                     #000040  #000060  #000080  #0000C0  #8080FF  #C0C0FF

local root = app.params["root"] or "."
local function rgba(r, g, b) return app.pixelColor.rgba(r, g, b, 255) end

local TONES = { "out", "deep", "dark", "mid", "light", "shine" }
local ROLE = {
  A = { out = rgba(0, 0, 0), deep = rgba(32, 32, 32), dark = rgba(64, 64, 64), mid = rgba(128, 128, 128), light = rgba(192, 192, 192), shine = rgba(255, 255, 255) },
  S = { out = rgba(0, 64, 0), deep = rgba(0, 96, 0), dark = rgba(0, 128, 0), mid = rgba(0, 192, 0), light = rgba(128, 255, 128), shine = rgba(192, 255, 192) },
  B = { out = rgba(64, 0, 0), deep = rgba(96, 0, 0), dark = rgba(128, 0, 0), mid = rgba(192, 0, 0), light = rgba(255, 128, 128), shine = rgba(255, 192, 192) },
  W = { out = rgba(0, 0, 64), deep = rgba(0, 0, 96), dark = rgba(0, 0, 128), mid = rgba(0, 0, 192), light = rgba(128, 128, 255), shine = rgba(192, 192, 255) },
}

local C = 32
local floor, abs, max, min = math.floor, math.abs, math.max, math.min

---------------------------------------------------------------------------
-- Raster kit. A cell is a table [y * C + x] = { mat, tone }. Light comes from the top-left.
---------------------------------------------------------------------------
local cell
local function new_cell() cell = {} end
local function inb(x, y) return x >= 0 and y >= 0 and x < C and y < C end
local function put(x, y, mat, tone)
  x, y = floor(x), floor(y)
  if inb(x, y) then cell[y * C + x] = { mat, tone } end
end
local function get(x, y)
  if not inb(x, y) then return nil end
  return cell[y * C + x]
end
local function retone(x, y, mat, tone)  -- change the shade of a pixel that is already `mat`
  local p = get(x, y)
  if p and p[1] == mat then p[2] = tone end
end
-- repeatable "random" 0..1 for a pixel (leaf texture)
local function noise(x, y, k)
  local n = (x * 7349 + y * 6653 + (k or 0) * 9973) % 1000003
  n = (n * n * 31) % 1000003
  return n / 1000003
end

-- A leafy clump: an ellipse shaded like a ball, with clustered leaf texture so it reads as
-- foliage, not as a smooth stone. opts.shine: a bright spot; opts.flat_bottom: cut at that y;
-- opts.tex: texture amount (0 = smooth, e.g. mushroom caps).
local function clump(cx, cy, rx, ry, mat, opts)
  opts = opts or {}
  local tex = opts.tex or 0.22
  for y = floor(cy - ry - 1), floor(cy + ry + 1) do
    for x = floor(cx - rx - 1), floor(cx + rx + 1) do
      local nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
      if nx * nx + ny * ny <= 1.0 and (not opts.flat_bottom or y <= opts.flat_bottom) then
        local d = nx * 0.6 + ny * 0.8
        local tone = "mid"
        if d < -0.5 then tone = "light"
        elseif d > 0.62 then tone = "deep"
        elseif d > 0.22 then tone = "dark" end
        -- leaf texture: little 2-pixel clusters of the next shade up / down
        local nz = noise(floor((x + (y % 2)) / 2), y, floor(cx * 7 + cy))
        if tex > 0 and nz < tex then
          if tone == "mid" then tone = (d < 0) and "light" or "dark"
          elseif tone == "dark" then tone = "deep"
          elseif tone == "light" and d > -0.7 then tone = "mid" end
        end
        put(x, y, mat, tone)
      end
    end
  end
  if opts.shine then
    local sx, sy = floor(cx - rx * 0.45), floor(cy - ry * 0.5)
    put(sx, sy, mat, "shine"); put(sx + 1, sy, mat, "shine")
    if rx >= 5 then put(sx, sy + 1, mat, "light") end
  end
end

-- A round fruit / spot: 2x2 with a highlight (big = 3x3).
local function fruit(x, y, mat, big)
  if big then
    put(x, y, mat, "shine"); put(x + 1, y, mat, "mid"); put(x + 2, y, mat, "dark")
    put(x, y + 1, mat, "light"); put(x + 1, y + 1, mat, "mid"); put(x + 2, y + 1, mat, "dark")
    put(x, y + 2, mat, "mid"); put(x + 1, y + 2, mat, "dark"); put(x + 2, y + 2, mat, "deep")
  else
    put(x, y, mat, "shine"); put(x + 1, y, mat, "mid")
    put(x, y + 1, mat, "mid"); put(x + 1, y + 1, mat, "deep")
  end
end

-- A thick line (trunk, branch): a row of discs of radius r, shaded left -> right.
local function limb(x0, y0, x1, y1, r, mat)
  local n = max(abs(x1 - x0), abs(y1 - y0), 1) * 2
  for i = 0, n do
    local cx, cy = x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n
    for y = floor(cy - r), floor(cy + r) do
      for x = floor(cx - r), floor(cx + r) do
        local dx = x + 0.5 - cx
        if dx * dx + (y + 0.5 - cy) ^ 2 <= r * r + 0.25 then
          local u = dx / max(r, 0.5)
          local tone = "mid"
          if u < -0.35 then tone = "light" elseif u > 0.55 then tone = "deep" elseif u > 0.15 then tone = "dark" end
          put(x, y, mat, tone)
        end
      end
    end
  end
end

-- A trunk from the ground up to `top`, `w` pixels wide, with a root flare and bark streaks.
local function trunk(cx, top, w, mat)
  mat = mat or "W"
  local x0 = floor(cx - w / 2 + 0.5)
  for y = top, 31 do
    local flare = (y >= 30) and (y - 29) or 0
    local a, b = x0 - flare, x0 + w - 1 + flare
    for x = a, b do
      local tone = "mid"
      if x == a then tone = "light" elseif x == b then tone = "deep" elseif x == b - 1 and w >= 3 then tone = "dark" end
      put(x, y, mat, tone)
    end
  end
  if w >= 3 then  -- bark: short darker streaks
    for y = top + 2, 29, 4 do retone(x0 + 1, y, mat, "dark"); retone(x0 + 1, y + 1, mat, "dark") end
  end
end

-- A 1px line, and one that only re-shades pixels of `mat` (veins).
local function line(x0, y0, x1, y1, mat, tone)
  local n = max(abs(x1 - x0), abs(y1 - y0), 1)
  for i = 0, n do put(x0 + (x1 - x0) * i / n + 0.5, y0 + (y1 - y0) * i / n + 0.5, mat, tone or "mid") end
end
local function line_over(x0, y0, x1, y1, mat, tone)
  local n = max(abs(x1 - x0), abs(y1 - y0), 1)
  for i = 0, n do retone(floor(x0 + (x1 - x0) * i / n + 0.5), floor(y0 + (y1 - y0) * i / n + 0.5), mat, tone) end
end

-- A leaf / petal: an ellipse `len` long, `wid` wide, pointing at angle `ang` (radians, 0 = right).
-- opts.vein draws a darker midrib.
local function leaf(cx, cy, len, wid, ang, mat, opts)
  opts = opts or {}
  local ca, sa = math.cos(ang), math.sin(ang)
  local r = math.ceil(len) + 1
  for y = floor(cy - r), floor(cy + r) do
    for x = floor(cx - r), floor(cx + r) do
      local dx, dy = x + 0.5 - cx, y + 0.5 - cy
      local u = (dx * ca + dy * sa) / len
      local v = (-dx * sa + dy * ca) / wid
      if u * u + v * v <= 1.0 then
        local d = (dx * 0.6 + dy * 0.8) / max(len, wid)  -- light on the side facing up-left
        local tone = "mid"
        if d < -0.35 then tone = "light" elseif d > 0.5 then tone = "deep" elseif d > 0.15 then tone = "dark" end
        -- opts.rim: a darker edge, so overlapping petals stay apart
        if opts.rim and u * u + v * v > 0.62 and u > -0.2 then
          tone = (tone == "light") and "mid" or ((tone == "mid") and "dark" or "deep")
        end
        put(x, y, mat, tone)
      end
    end
  end
  if opts.vein then
    line_over(cx - ca * len * 0.7, cy - sa * len * 0.7, cx + ca * len * 0.6, cy + sa * len * 0.6, mat, "dark")
  end
end

-- A grass tuft at the foot of a plant.
local function tuft(x, h)
  line(x, 31, x - 1, 31 - h, "S", "dark")
  line(x + 1, 31, x + 1, 30 - h, "S", "light")
  line(x + 2, 31, x + 3, 31 - h, "S", "mid")
end

-- The usual two-leaf seedling. `bud` adds a tiny bud in the seed's main color between the leaves.
local function seedling(h, bud)
  local top = 31 - h
  line(15, 31, 15, top, "S", "light"); line(16, 31, 16, top, "S", "dark")
  leaf(12.6, top - 0.6, 3.4, 2.1, math.rad(200), "S")
  leaf(19.4, top - 1.6, 3.4, 2.1, math.rad(-25), "S")
  if bud then clump(15.9, top - 1.2, 1.6, 1.8, "A", { tex = 0 }) end
end

---------------------------------------------------------------------------
-- The 5 crop types. Each has sprout(), sapling() and crop(). Drawn back to front.
-- id + name end up in assets/crop_template.json (order = row in the template).
---------------------------------------------------------------------------
local TYPES = {}
local function add(id, name, fns) fns.id = id; fns.name = name; TYPES[#TYPES + 1] = fns end

add("round_tree", "Round Tree", {
  sprout = function() seedling(7, true) end,
  sapling = function()
    trunk(15.5, 17, 2)
    limb(15.5, 21, 12.5, 17, 0.6, "W")
    clump(11.8, 15.0, 4.6, 3.8, "A")
    clump(19.8, 14.4, 4.6, 3.8, "A")
    clump(15.6, 10.6, 5.4, 4.4, "A", { shine = true })
    fruit(17, 13, "B")
  end,
  crop = function()
    trunk(15.5, 18, 4)
    limb(14.5, 22, 8.5, 15, 1.0, "W")
    limb(16.5, 21, 22.5, 14, 1.0, "W")
    -- back clumps, then the front ones
    clump(7.6, 13.0, 6.0, 5.2, "A")
    clump(24.4, 12.6, 6.0, 5.2, "A")
    clump(16.0, 7.6, 8.4, 6.4, "A")
    clump(10.8, 7.4, 6.0, 5.0, "A", { shine = true })
    clump(21.4, 6.8, 6.0, 5.0, "A")
    clump(10.4, 15.8, 5.6, 4.2, "A")
    clump(21.8, 15.4, 5.6, 4.2, "A")
    clump(16.0, 13.6, 6.6, 4.8, "A")
    for _, p in ipairs({ { 6, 12 }, { 12, 16 }, { 19, 9 }, { 24, 13 }, { 13, 5 }, { 18, 15 } }) do fruit(p[1], p[2], "B") end
  end,
})

-- one pine tier: apex (ax, ay), widest (hw) at `by`, with needle tips hanging under the bottom edge
local function tier(ax, ay, by, hw, mat)
  for y = floor(ay), floor(by) + 1 do
    local t = (y + 0.5 - ay) / (by - ay)
    local w = hw * min(t, 1)
    for x = floor(ax - w), floor(ax + w) do
      local inside = true
      if y > by then inside = ((x - floor(ax)) % 3 == 0) and abs(x - ax) > 1.5 end
      if inside then
        local u = (x + 0.5 - ax) / max(w, 0.5)
        local tone = "mid"
        if u < -0.4 then tone = "light" elseif u > 0.6 then tone = "deep" elseif u > 0.2 then tone = "dark" end
        if y >= floor(by) then tone = (u < -0.4) and "mid" or "dark" end
        if tone == "mid" and (x + y) % 4 == 0 then tone = (u < 0) and "light" or "dark" end -- needle streaks
        put(x, y, mat, tone)
      end
    end
  end
end
-- the shade a tier casts on the one below it
local function tier_shadow(ax, by, hw, mat)
  for x = floor(ax - hw), floor(ax + hw) do
    retone(x, floor(by) + 2, mat, "deep"); retone(x, floor(by) + 3, mat, "dark")
  end
end

add("pine", "Pine", {
  sprout = function()
    line(15, 31, 15, 26, "S", "light"); line(16, 31, 16, 26, "S", "dark")
    tier(15.5, 19, 25, 4, "A")
  end,
  sapling = function()
    trunk(15.5, 27, 2)
    tier(15.5, 14, 26, 8.5, "A")
    tier(15.5, 8, 18, 5.5, "A")
    tier_shadow(15.5, 18, 5.5, "A")
    put(14, 11, "A", "shine")
  end,
  crop = function()
    trunk(15.5, 26, 3)
    tier(15.5, 11, 25, 13, "A")
    tier(15.5, 5, 17, 9.5, "A")
    tier_shadow(15.5, 17, 9.5, "A")
    tier(15.5, 0, 10, 6, "A")
    tier_shadow(15.5, 10, 6, "A")
    put(14, 3, "A", "shine"); put(13, 9, "A", "shine"); put(12, 16, "A", "shine")
    -- cones hanging under the tiers
    for _, p in ipairs({ { 6, 26 }, { 24, 26 }, { 9, 18 }, { 21, 18 }, { 12, 11 } }) do
      put(p[1], p[2], "B", "light"); put(p[1] + 1, p[2], "B", "dark"); put(p[1], p[2] + 1, "B", "dark")
    end
  end,
})

add("twisted_tree", "Twisted Tree", {
  sprout = function()
    line(15, 31, 15, 27, "S", "light"); line(16, 31, 16, 27, "S", "dark")
    line(15, 27, 13, 24, "S", "mid"); line(16, 27, 14, 24, "S", "dark")
    clump(12.6, 22.4, 3.6, 1.8, "A", { tex = 0 })
    leaf(19.0, 25.5, 2.6, 1.5, math.rad(-30), "S")
  end,
  sapling = function()
    limb(15.5, 31, 15.5, 25, 1.0, "W")
    limb(15.5, 25, 12.5, 19, 0.8, "W")
    limb(15.0, 23, 20.5, 18, 0.6, "W")
    clump(11.6, 17.0, 5.2, 2.6, "A", { shine = true })
    clump(21.0, 16.4, 4.6, 2.4, "A")
    fruit(10, 16, "B")
  end,
  crop = function()
    -- crooked trunk splitting into three branches
    limb(15.5, 31, 16.0, 24, 1.6, "W")
    limb(16.0, 24, 12.5, 18, 1.3, "W")
    limb(12.5, 18, 6.5, 12, 0.9, "W")
    limb(12.5, 18, 15.5, 8, 0.9, "W")
    limb(16.5, 23, 24.0, 15, 1.0, "W")
    put(13, 31, "W", "light"); put(18, 31, "W", "deep"); put(19, 31, "W", "deep")
    -- flat leaf pads at the branch ends
    clump(6.0, 10.6, 5.8, 3.0, "A")
    clump(8.4, 8.8, 4.0, 2.4, "A", { shine = true })
    clump(24.4, 13.4, 6.2, 3.2, "A")
    clump(22.0, 11.4, 4.4, 2.6, "A", { shine = true })
    clump(15.4, 6.2, 7.2, 3.4, "A")
    clump(14.0, 3.8, 4.8, 2.6, "A", { shine = true })
    for _, p in ipairs({ { 4, 10 }, { 9, 11 }, { 23, 14 }, { 27, 12 }, { 12, 6 }, { 18, 5 } }) do fruit(p[1], p[2], "B") end
  end,
})

add("flower", "Big Flower", {
  sprout = function()
    seedling(6, false)
    leaf(15.9, 23.2, 1.6, 1.2, math.rad(-90), "A")
  end,
  sapling = function()
    line(15, 31, 15, 13, "S", "light"); line(16, 31, 16, 13, "S", "dark")
    leaf(11.2, 24.5, 4.6, 2.0, math.rad(205), "S", { vein = true })
    leaf(20.4, 20.5, 4.6, 2.0, math.rad(-25), "S", { vein = true })
    -- a closed bud with two sepals
    clump(15.8, 9.6, 2.8, 4.0, "A", { tex = 0, shine = true })
    leaf(13.8, 12.6, 2.2, 1.2, math.rad(240), "S")
    leaf(17.8, 12.6, 2.2, 1.2, math.rad(-60), "S")
  end,
  crop = function()
    line(15, 31, 15, 15, "S", "light"); line(16, 31, 16, 15, "S", "dark")
    leaf(10.2, 25.0, 5.6, 2.4, math.rad(205), "S", { vein = true })
    leaf(21.4, 21.0, 5.6, 2.4, math.rad(-25), "S", { vein = true })
    local cx, cy = 15.9, 9.4
    -- back petals (one shade darker), then the front petals
    for k = 0, 3 do
      local a = math.rad(-45 + k * 90)
      leaf(cx + math.cos(a) * 6.2, cy + math.sin(a) * 6.0, 4.2, 2.6, a, "A")
    end
    local darker = { shine = "light", light = "mid", mid = "dark", dark = "deep", deep = "deep" }
    for y = 0, 20 do
      for x = 0, C - 1 do
        local p = get(x, y)
        if p and p[1] == "A" then p[2] = darker[p[2]] end
      end
    end
    for k = 0, 3 do
      local a = math.rad(k * 90 - 90)
      leaf(cx + math.cos(a) * 6.4, cy + math.sin(a) * 6.2, 4.6, 2.9, a, "A", { rim = true })
    end
    put(13, 3, "A", "shine"); put(14, 3, "A", "shine")
    -- the center: a textured disc
    clump(cx, cy, 3.4, 3.3, "B", { tex = 0 })
    for _, p in ipairs({ { 15, 8 }, { 17, 9 }, { 15, 10 }, { 16, 11 }, { 14, 9 } }) do retone(p[1], p[2], "B", "dark") end
    put(14, 7, "B", "shine")
  end,
})

add("mushroom", "Giant Mushroom", {
  sprout = function()
    trunk(15.5, 27, 2, "B")
    clump(15.8, 26.4, 4.2, 3.4, "A", { flat_bottom = 26, tex = 0, shine = true })
    tuft(20, 2)
  end,
  sapling = function()
    trunk(15.5, 20, 4, "B")
    clump(15.8, 19.8, 9.4, 7.2, "A", { flat_bottom = 19, tex = 0.06, shine = true })
    for x = 7, 24 do retone(x, 19, "A", "deep") end
    fruit(10, 15, "B"); fruit(18, 14, "B"); fruit(14, 17, "B")
    tuft(5, 3)
  end,
  crop = function()
    trunk(15.5, 16, 8, "B")
    -- a ring around the stalk
    for x = 11, 20 do put(x, 21, "B", (x < 14) and "light" or ((x > 18) and "deep" or "dark")) end
    for x = 12, 19 do put(x, 22, "B", "deep") end
    clump(16.0, 15.6, 15.2, 13.4, "A", { flat_bottom = 15, tex = 0.06, shine = true })
    -- gills under the cap
    for x = 3, 28 do retone(x, 15, "A", "deep") end
    for x = 5, 26, 2 do put(x, 16, "A", "dark") end
    for _, p in ipairs({ { 7, 8 }, { 14, 4 }, { 21, 7 }, { 25, 11 }, { 4, 12 }, { 12, 10 }, { 18, 12 } }) do
      fruit(p[1], p[2], "B", p[2] < 9)
    end
    tuft(4, 3); tuft(25, 4)
  end,
})

---------------------------------------------------------------------------
-- Outline (selective: softer on the lit top-left side) and save
---------------------------------------------------------------------------
local function outline()
  local out = {}
  for y = 0, C - 1 do
    for x = 0, C - 1 do
      if not get(x, y) then
        local below, right, above, left = get(x, y + 1), get(x + 1, y), get(x, y - 1), get(x - 1, y)
        local p = below or right or above or left
        if p then
          -- an edge on the lit side (the plant is below / right of this pixel) gets the
          -- material's dark shade; the shadow side gets the real outline
          local lit = (below or right) and not (above or left)
          out[#out + 1] = { x, y, p[1], lit and "dark" or "out" }
        end
      end
    end
  end
  for _, o in ipairs(out) do cell[o[2] * C + o[1]] = { o[3], o[4] } end
end

local STAGES = { "sprout", "sapling", "crop" }
local img = Image(C * #STAGES, C * #TYPES, ColorMode.RGB)
for row, t in ipairs(TYPES) do
  for col, stage in ipairs(STAGES) do
    new_cell()
    t[stage]()
    outline()
    for y = 0, C - 1 do
      for x = 0, C - 1 do
        local p = get(x, y)
        if p then img:drawPixel((col - 1) * C + x, (row - 1) * C + y, ROLE[p[1]][p[2]]) end
      end
    end
  end
end

local spr = Sprite(img.width, img.height, ColorMode.RGB)
spr.filename = root .. "/art/crop_template.aseprite"
local pal = Palette(25)
pal:setColor(0, Color { r = 0, g = 0, b = 0, a = 0 })
local i = 1
for _, mat in ipairs({ "A", "S", "B", "W" }) do
  for _, tone in ipairs(TONES) do pal:setColor(i, Color(ROLE[mat][tone])); i = i + 1 end
end
spr:setPalette(pal)
spr.layers[1].name = "Crops"
spr:newCel(spr.layers[1], 1, img, Point(0, 0))
spr.gridBounds = Rectangle(0, 0, C, C)
spr:saveAs(root .. "/art/crop_template.aseprite")
spr:saveCopyAs(root .. "/assets/crop_template.png")
spr:close()

local f = io.open(root .. "/assets/crop_template.json", "w")
local parts = {}
for _, t in ipairs(TYPES) do parts[#parts + 1] = string.format('\t\t{ "id": "%s", "name": "%s" }', t.id, t.name) end
f:write('{\n\t"cell": 32,\n\t"stages": ["sprout", "sapling", "crop"],\n\t"types": [\n' .. table.concat(parts, ",\n") .. '\n\t]\n}\n')
f:close()
