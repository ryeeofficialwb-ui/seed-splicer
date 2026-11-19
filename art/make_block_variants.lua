-- Seed Splicer: color variants of the designer's own block art, for Aseprite.
--
-- Run (batch mode):
--   Aseprite.exe -b --script-param dir="%APPDATA%/Godot/app_userdata/Seed Splicer/block_art"
--                   --script-param preview=C:/tmp/variants.png --script art/make_block_variants.lua
--
-- The designer drew Purple, Green and Blue Block by hand. They all use the same drawing; only
-- 3 colors change:
--     light  = the lit rim (top + left)        purple #dc57cc   green #57dc67
--     face   = the flat front                  purple #c162b6   green #62c16d
--     dark   = the shadow side (right + bottom) purple #842178   green #21842d
-- Black (#000000, the frame) and white (#ffffff, the two shine marks) never change.
-- In HSV the designer's ramp is: light S 0.60 V 0.86, face S 0.49 V 0.76, dark S 0.75 V 0.52,
-- all on the block's hue. The colored variants below follow that ramp; white / grey / black /
-- pink / brown need their own values (the same ramp would make them all mid-tones).
--
-- The script reads TEMPLATE (the designer's purple block) pixel by pixel and only swaps those
-- 3 colors, so every variant is exactly the designer's drawing. It NEVER overwrites a file that
-- already exists (that would be the designer's own art): delete a variant first to remake it.

local dir = app.params["dir"]
local preview = app.params["preview"]
local TEMPLATE = "purple_block.png"
local pc = app.pixelColor

-- seed id -> { light, face, dark }
local VARIANTS = {
  { "red_blockseed", "#dc5757", "#c16262", "#842121" },
  { "orange_block",  "#dc9557", "#c18e62", "#844f21" },
  { "yellow_block",  "#dcca57", "#c1b462", "#846b21" },
  { "lime",          "#a5dc57", "#99c162", "#5b8421" },
  { "aqua_block",    "#57cadc", "#62b4c1", "#217784" },
  { "pink_block",    "#fa96c8", "#eb9dc4", "#b85385" },
  { "brown_block",   "#a8744c", "#946a4a", "#613a1d" },
  { "white_block",   "#f2f2f2", "#dadada", "#a3a3a3" },
  { "grey_block",    "#a0a0a0", "#858585", "#545454" },
  { "black_block",   "#3d3d3d", "#2a2a2a", "#151515" },
}

local function hex(h)
  h = h:gsub("#", "")
  return pc.rgba(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16), 255)
end
local function exists(p)
  local f = io.open(p, "rb")
  if f then f:close() return true end
  return false
end

local tpl = Image { fromFile = dir .. "/" .. TEMPLATE }
-- The template's 3 recolorable colors, sorted bright -> dark (black and white stay as they are).
local seen, colors = {}, {}
for it in tpl:pixels() do
  local v = it()
  local r, g, b, a = pc.rgbaR(v), pc.rgbaG(v), pc.rgbaB(v), pc.rgbaA(v)
  local key = v
  if a > 0 and not seen[key] and not (r == 0 and g == 0 and b == 0) and not (r == 255 and g == 255 and b == 255) then
    seen[key] = true
    colors[#colors + 1] = { v = v, lum = r * 0.299 + g * 0.587 + b * 0.114 }
  end
end
table.sort(colors, function(a, b) return a.lum > b.lum end)
assert(#colors == 3, "expected 3 colors (light, face, dark) in " .. TEMPLATE .. ", found " .. #colors)

local made, skipped = {}, {}
local all = {}
for _, var in ipairs(VARIANTS) do
  local id = var[1]
  local swap = { [colors[1].v] = hex(var[2]), [colors[2].v] = hex(var[3]), [colors[3].v] = hex(var[4]) }
  local img = Image(tpl.width, tpl.height, ColorMode.RGB)
  for it in tpl:pixels() do
    local v = it()
    img:drawPixel(it.x, it.y, swap[v] or v)
  end
  all[#all + 1] = img
  local path = dir .. "/" .. id .. ".png"
  if exists(path) then
    skipped[#skipped + 1] = id
  else
    img:saveAs(path)
    made[#made + 1] = id
  end
end
print("made: " .. table.concat(made, ", "))
print("skipped (already drawn): " .. table.concat(skipped, ", "))

-- optional: one picture with the designer's 3 blocks on top and every variant under them
if preview then
  local mine = { "purple_block", "green_block", "blue_block" }
  local cols = 5
  local rows = 1 + math.ceil(#all / cols)
  local sheet = Image(cols * 36, rows * 36, ColorMode.RGB)
  local filled = {}
  for i, id in ipairs(mine) do
    filled[(i - 1) .. ",0"] = true
    sheet:drawImage(Image { fromFile = dir .. "/" .. id .. ".png" }:clone(), Point((i - 1) * 36 + 2, 2))
  end
  for i, img in ipairs(all) do
    local k = i - 1
    filled[(k % cols) .. "," .. (1 + k // cols)] = true
    sheet:drawImage(img, Point((k % cols) * 36 + 2, (1 + k // cols) * 36 + 2))
  end
  -- only the first 32x32 frame of each strip is wanted: clip by redrawing into cells
  local out = Image(cols * 36, rows * 36, ColorMode.RGB)
  for y = 0, out.height - 1 do
    for x = 0, out.width - 1 do
      if filled[(x // 36) .. "," .. (y // 36)] and (x % 36) >= 2 and (x % 36) < 34 and (y % 36) >= 2 and (y % 36) < 34 then
        out:drawPixel(x, y, sheet:getPixel(x, y))
      end
    end
  end
  out:resize(out.width * 6, out.height * 6)
  out:saveAs(preview)
end
