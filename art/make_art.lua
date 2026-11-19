-- Seed Splicer art generator for Aseprite.
--
-- Run from the project folder:
--   Aseprite.exe -b --script-param root=E:/seed-splicer --script art/make_art.lua
--
-- Makes:
--   art/seed_template.aseprite   layered source (Outline, Body, Shading, Sprout) you can retouch by hand
--   assets/seed_template.png     flattened copy the game reads
--   art/sparkle.aseprite + assets/sparkle.png   5-frame splice sparkle (32x32 per frame)
--
-- The template is ROLE-CODED: the game swaps each of these exact colors for a
-- color worked out from the seed's pattern / sprout color. When you edit the
-- template in Aseprite, only paint with these colors (they are in its palette).
--   body outline   #000000    body shadow #404040   body #808080
--   body light     #C0C0C0    body shine  #FFFFFF
--   sprout outline #004000    sprout dark #008000   sprout #00C000   sprout light #80FF80

local root = app.params["root"] or "."
local function rgba(r, g, b, a) return app.pixelColor.rgba(r, g, b, a or 255) end

local ROLE = {
  outline   = rgba(0, 0, 0),
  shadow    = rgba(64, 64, 64),
  body      = rgba(128, 128, 128),
  light     = rgba(192, 192, 192),
  shine     = rgba(255, 255, 255),
  s_outline = rgba(0, 64, 0),
  s_dark    = rgba(0, 128, 0),
  s_mid     = rgba(0, 192, 0),
  s_light   = rgba(128, 255, 128),
}

local W, H = 32, 32

---------------------------------------------------------------------------
-- Body: a plump almond tilted 45 degrees. Round belly bottom-left, a gently
-- pointed tip top-right (the sprout grows out of it), bent a little like a
-- real almond / sunflower seed.
-- The angle and centre are written to assets/seed_template.json (see the end of this
-- file) so the game can lay its stripe / half-color patterns along the seed's real axis.
---------------------------------------------------------------------------
-- (every value can be overridden with --script-param name=value, to try shapes out)
local function param(name, default) return tonumber(app.params[name]) or default end
local ANGLE = math.rad(param("angle", 50)) -- tilt of the seed, degrees up from horizontal
local CX, CY = param("cx", 13.4), param("cy", 18.7) -- centre
local LEN, RAD = param("len", 11.6), param("rad", 7.9) -- half length along the tilt, half width
local BOW = param("bow", 0.0)  -- bend of the belly toward the bottom-right (0 = straight)
local PT = param("pt", 0.8)    -- tip profile: 0.5 = round like an egg, 1.0 = pointed cone
local PB = param("pb", 0.5)    -- belly profile: 0.5 = round
local COS, SIN = math.cos(ANGLE), math.sin(ANGLE)

local function half_width(t)
  return RAD * (1 - t * t) ^ (t > 0 and PT or PB)
end
local function centre_v(t) return BOW * (1 - t * t) end

local function in_body(x, y)
  local dx, dy = x + 0.5 - CX, y + 0.5 - CY
  local u = dx * COS - dy * SIN -- along the axis, + toward the tip (up and right)
  local v = dx * SIN + dy * COS -- across the axis, + toward bottom-right
  local t = u / LEN
  if t <= -1 or t >= 1 then return false end
  return math.abs(v - centre_v(t)) <= half_width(t)
end

local mask = {}
local function m(x, y)
  if x < 0 or y < 0 or x >= W or y >= H then return false end
  return mask[y * W + x] == true
end
for y = 0, H - 1 do
  for x = 0, W - 1 do mask[y * W + x] = in_body(x, y) end
end
-- remove lonely nubs (pixels with <= 1 filled 4-neighbour) so the edge stays clean
for _ = 1, 2 do
  local kill = {}
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      if m(x, y) then
        local n = 0
        if m(x + 1, y) then n = n + 1 end
        if m(x - 1, y) then n = n + 1 end
        if m(x, y + 1) then n = n + 1 end
        if m(x, y - 1) then n = n + 1 end
        if n <= 1 then kill[#kill + 1] = y * W + x end
      end
    end
  end
  for _, k in ipairs(kill) do mask[k] = false end
end

-- light comes from the top-left
local body_role = {}
for y = 0, H - 1 do
  for x = 0, W - 1 do
    if m(x, y) then
      local role = "body"
      -- shadow: close to the bottom-right edge
      if not m(x + 2, y + 2) then
        role = "shadow"
      -- light: right on the top-left edge
      elseif not m(x - 1, y - 1) or not m(x - 2, y) or not m(x, y - 2) then
        role = "light"
      end
      body_role[y * W + x] = role
    end
  end
end

-- point on the seed: t along the length (-1..1), f across it (-1 = lit side, +1 = shadow side)
local function seed_point(t, f)
  local v = centre_v(t) + f * half_width(t)
  local u = t * LEN
  local dx = u * COS + v * SIN
  local dy = -u * SIN + v * COS
  return math.floor(CX + dx), math.floor(CY + dy)
end
local function paint_body(x, y, role, only_over)
  if m(x, y) and (only_over == nil or body_role[y * W + x] == only_over) then
    body_role[y * W + x] = role
  end
end
-- fine grain: short dashes that run along the seed, like the ridges on an almond
local function dashes(f, t0, t1, role)
  local t = t0
  while t <= t1 do
    local x, y = seed_point(t, f)
    paint_body(x, y, role, "body")
    t = t + 0.045
  end
end
dashes(0.30, -0.62, -0.30, "shadow")
dashes(0.52, -0.10, 0.32, "shadow")
dashes(0.12, 0.05, 0.38, "shadow")
dashes(-0.28, 0.12, 0.40, "light")
dashes(-0.05, -0.80, -0.55, "light")
-- shine: a short streak inset from the lit edge, plus one bright dot
do
  local t = -0.52
  while t <= -0.04 do
    local x, y = seed_point(t, -0.50)
    paint_body(x, y, "shine")
    t = t + 0.05
  end
  local x, y = seed_point(0.22, -0.50)
  paint_body(x, y, "shine")
end

---------------------------------------------------------------------------
-- Sprout: a short upright stem out of the tip with two round leaves.
---------------------------------------------------------------------------
local sprout = {}
local function put(x, y, role)
  x, y = math.floor(x), math.floor(y)
  if x >= 0 and y >= 0 and x < W and y < H then sprout[y * W + x] = role end
end
local function leaf(cx, cy, rx, ry)
  for y = math.floor(cy - ry - 1), math.ceil(cy + ry + 1) do
    for x = math.floor(cx - rx - 1), math.ceil(cx + rx + 1) do
      local nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
      if nx * nx + ny * ny <= 1.0 then
        local s = nx + ny
        local role = "s_mid"
        if s < -0.8 then role = "s_light" elseif s > 0.7 then role = "s_dark" end
        put(x, y, role)
      end
    end
  end
end

-- the tip = body pixel furthest along the axis
local tipx, tipy, best = 0, 0, -1e9
for y = 0, H - 1 do
  for x = 0, W - 1 do
    if m(x, y) then
      local u = (x + 0.5 - CX) * COS - (y + 0.5 - CY) * SIN
      if u > best then best, tipx, tipy = u, x, y end
    end
  end
end
local STEM = 3
local topx, topy = tipx, tipy - STEM
leaf(topx - 2.8, topy - 1.4, 3.6, 2.6) -- left leaf
leaf(topx + 4.6, topy - 2.2, 3.5, 2.6) -- right leaf
for k = 0, STEM do
  local x, y = tipx, tipy - k
  put(x, y, "s_mid")
  put(x + 1, y, "s_dark")
end
local function sp(x, y)
  if x < 0 or y < 0 or x >= W or y >= H then return false end
  return sprout[y * W + x] ~= nil
end

---------------------------------------------------------------------------
-- Build the layered sprite
---------------------------------------------------------------------------
local spr = Sprite(W, H, ColorMode.RGB)
spr.filename = root .. "/art/seed_template.aseprite"
local pal = Palette(10)
pal:setColor(0, Color { r = 0, g = 0, b = 0, a = 0 })
local order = { "outline", "shadow", "body", "light", "shine", "s_outline", "s_dark", "s_mid", "s_light" }
for i, k in ipairs(order) do pal:setColor(i, Color(ROLE[k])) end
spr:setPalette(pal)

-- bottom to top
spr.layers[1].name = "Outline"
local outline_img = Image(W, H, ColorMode.RGB)
for y = 0, H - 1 do
  for x = 0, W - 1 do
    if not m(x, y) and not sp(x, y) then
      local touches_body = m(x + 1, y) or m(x - 1, y) or m(x, y + 1) or m(x, y - 1)
      local touches_sprout = sp(x + 1, y) or sp(x - 1, y) or sp(x, y + 1) or sp(x, y - 1)
      if touches_sprout then
        outline_img:drawPixel(x, y, ROLE.s_outline)
      elseif touches_body then
        outline_img:drawPixel(x, y, ROLE.outline)
      end
    end
  end
end
spr:newCel(spr.layers[1], 1, outline_img, Point(0, 0))

local function add_layer(name, fn)
  local layer = spr:newLayer()
  layer.name = name
  local img = Image(W, H, ColorMode.RGB)
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local c = fn(x, y)
      if c then img:drawPixel(x, y, c) end
    end
  end
  spr:newCel(layer, 1, img, Point(0, 0))
end

add_layer("Body", function(x, y)
  if m(x, y) and not sp(x, y) then return ROLE.body end
end)
add_layer("Shading", function(x, y)
  local r = body_role[y * W + x]
  if r and r ~= "body" and not sp(x, y) then return ROLE[r] end
end)
add_layer("Sprout", function(x, y)
  local r = sprout[y * W + x]
  if r then return ROLE[r] end
end)

spr:saveAs(root .. "/art/seed_template.aseprite")
spr:saveCopyAs(root .. "/assets/seed_template.png")
spr:close()

---------------------------------------------------------------------------
-- Sparkle: 5 frames, a burst of 4-point stars that grows and fades.
---------------------------------------------------------------------------
local fx = Sprite(W, H, ColorMode.RGB)
local WHITE = rgba(255, 255, 255)
local GOLD = rgba(255, 226, 120)
local MINT = rgba(150, 255, 190)
local function star(img, x, y, r, c)
  img:drawPixel(x, y, c)
  for i = 1, r do
    img:drawPixel(x + i, y, c); img:drawPixel(x - i, y, c)
    img:drawPixel(x, y + i, c); img:drawPixel(x, y - i, c)
  end
end
local dirs = { {1, 0}, {0.7, 0.7}, {0, 1}, {-0.7, 0.7}, {-1, 0}, {-0.7, -0.7}, {0, -1}, {0.7, -0.7} }
local frames = {
  { dist = 2,  r = 1, core = 3 },
  { dist = 6,  r = 2, core = 2 },
  { dist = 10, r = 2, core = 1 },
  { dist = 13, r = 1, core = 0 },
  { dist = 15, r = 0, core = -1 },
}
for f, spec in ipairs(frames) do
  if f > 1 then fx:newEmptyFrame() end
  local img = Image(W, H, ColorMode.RGB)
  if spec.core >= 0 then star(img, 16, 16, spec.core, WHITE) end
  for i, d in ipairs(dirs) do
    local x = math.floor(16 + d[1] * spec.dist + 0.5)
    local y = math.floor(16 + d[2] * spec.dist + 0.5)
    local c = (i % 2 == 0) and GOLD or MINT
    if spec.r > 0 then star(img, x, y, spec.r - ((i % 2 == 0) and 0 or 1), c) end
    img:drawPixel(x, y, (f <= 3) and WHITE or c)
  end
  fx:newCel(fx.layers[1], f, img, Point(0, 0))
  fx.frames[f].duration = 0.07
end
fx.layers[1].name = "Burst"
-- tell the game how the seed is tilted (read by scripts/seed_art.gd)
pcall(function()
  local f = io.open(root .. "/assets/seed_template.json", "w")
  f:write(string.format('{ "angle": %.3f, "cx": %.3f, "cy": %.3f }\n', math.deg(ANGLE), CX, CY))
  f:close()
end)
fx:saveAs(root .. "/art/sparkle.aseprite")
app.command.ExportSpriteSheet {
  ui = false,
  type = SpriteSheetType.HORIZONTAL,
  textureFilename = root .. "/assets/sparkle.png",
}
fx:close()
