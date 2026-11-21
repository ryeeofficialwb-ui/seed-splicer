-- Seed Splicer: PROPOSED block art for the seeds that have none yet, for the designer to review in
-- Aseprite before anything goes into the game. Never touches the designer's block_art folder.
--
--   Aseprite.exe -b --script-param sheet=<the game's exported sprite sheet .png>
--                   --script-param rows="deathcap=40;well=146;..."      (seed id = its row in the sheet)
--                   --script-param names="deathcap=Deathcap;..."        (slice labels)
--                   --script-param template=<purple_block.png, the designer's glossy block>
--                   --script-param out=<folder for the .aseprite files>
--                   --script art/make_proposals.lua
--
-- Writes:
--   block_art_proposals_sheet.aseprite     the sprite sheet: layer "Current art" (the game's export, as
--                                          it is) + layer "New art (proposed)" in the 4 block boxes of
--                                          each seed below. Export it as PNG and use Settings > Import
--                                          Sprite Sheet in the game to accept it (hide or erase what you
--                                          don't want first; edit freely).
--   block_art_proposals_overview.aseprite  every proposal side by side, bigger, one slice per seed.
--
-- The designer's style: everything sits on a 2 px grid (drawn here at 16x16, doubled to 32x32).
-- Blocks: a dark frame with cut corners, a lit top + left rim, a darker bottom + right rim.
-- Decorations: a small object standing on the bottom of the box, with a dark outline.
-- The 4 boxes are the same picture (the designer's own blocks are too).

local pc = app.pixelColor
local P = app.params

local function hex(h)
  h = h:gsub("#", "")
  return pc.rgba(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16), 255)
end

-- kind "frame": 14 rows of 14 (inside the frame). "." = the face color F; the rim is automatic:
--   F on the top row / left column -> L, on the bottom row / right column -> D.
-- kind "free": up to 16 rows of 16, "." = see-through. Placed on the floor (last row on row 14)
--   unless top = true. The outline (K) is added around everything automatically (outline = false: none).
local D = {}

D.dust = { kind = "frame", K = "#262422", pal = { F = "#7c7a77", L = "#9d9b98", D = "#4f4d4a", s = "#b8b6b2", p = "#5e5c59" }, rows = {
  "..............",
  "..s......p....",
  ".......s......",
  "....p.......s.",
  ".s.........p..",
  ".......p......",
  "..p.s.........",
  "...........s..",
  ".....s..p.....",
  ".p............",
  "........s..p..",
  "...s..........",
  ".........p....",
  "..............",
} }

D.fertilizer = { kind = "frame", K = "#1f140a", pal = { F = "#6b4a26", L = "#8c6638", D = "#432a12", t = "#9e7444", g = "#7aa832", b = "#2e1c0b" }, rows = {
  "..............",
  ".tt.....b.....",
  ".t....g....tt.",
  "....b.......t.",
  "..g.....tt....",
  ".......t...b..",
  ".b..tt......g.",
  "....t..g......",
  "..........tt..",
  ".g..b......t..",
  "......tt......",
  "..t....t...b..",
  ".tt..g......g.",
  "..............",
} }

D.hay_block = { kind = "frame", K = "#3a3010", pal = { F = "#d6c440", L = "#ecdd6a", D = "#9c8a1c", h = "#b8a62a", r = "#8a5a2a", R = "#a87038" }, rows = {
  "...rR....rR...",
  ".h.rRh.h.rR.h.",
  "...rR....rR...",
  "hh.rRhhhhrRhhh",
  "...rR....rR...",
  ".h.rR.h..rRh..",
  "...rR....rR...",
  "h..rRhh..rR.hh",
  "...rR....rR...",
  ".hhrR..h.rRhh.",
  "...rR....rR...",
  "h..rR.hh.rR..h",
  "...rR....rR...",
  "...rR....rR...",
} }

D.hedge = { kind = "frame", K = "#0f2a08", pal = { F = "#2f9a1c", L = "#49c22c", D = "#1d6612", a = "#5ad63a", b = "#1f7414", t = "#6b4210" }, rows = {
  "..a....a...a..",
  ".aaa..aaa.aaa.",
  "..b..t..b...b.",
  "a...aa.....a..",
  "aa.aaab..aaab.",
  ".b..bb..t..b..",
  "..a....a...a.a",
  ".aaa..aaa.aaab",
  "..b.t..b...b..",
  "a....a....a...",
  "aa..aaa..aaa.a",
  ".b...b..t..b..",
  "...a....a.....",
  "..............",
} }

D.leaves = { kind = "frame", K = "#0e2c08", pal = { F = "#3fbf2c", L = "#63e04a", D = "#24801a", a = "#7cf060", b = "#2a9a1e", c = "#1d6a14" }, rows = {
  ".a....a.....a.",
  "aaa..aaa...aaa",
  ".bc...bc....bc",
  "...a.....a....",
  "..aaa...aaa...",
  "a..bc..a.bc..a",
  "aa....aaa....a",
  "bc.a...bc..a..",
  "..aaa.....aaa.",
  "...bc..a...bc.",
  ".a....aaa.....",
  "aaa....bc...a.",
  ".bc........aaa",
  "............bc",
} }

D.ice = { kind = "frame", K = "#1c4a58", pal = { F = "#8fe6ee", L = "#c6f8fc", D = "#4fb4c4", w = "#ffffff", s = "#b2f2f8" }, rows = {
  "ww............",
  "w.....s.......",
  "........s.....",
  "..s.......s...",
  "...s.......s..",
  "....s.......s.",
  ".....s........",
  "s.....s.......",
  ".s...........s",
  "..s.......s...",
  "...s.......s..",
  "....s.......s.",
  ".....s.......w",
  ".............w",
} }

D.iron_block = { kind = "frame", K = "#2a2426", pal = { F = "#a9a7a8", L = "#d2d0d1", D = "#6a6264", r = "#5c5456", R = "#e6e4e5", l = "#8e8a8b" }, rows = {
  "..............",
  ".Rr........Rr.",
  ".rr........rr.",
  "..............",
  "..............",
  "..............",
  "llllllllllllll",
  "..............",
  "..............",
  "..............",
  "..............",
  ".Rr........Rr.",
  ".rr........rr.",
  "..............",
} }

D.steel = { kind = "frame", K = "#1a1617", pal = { F = "#7a7476", L = "#a8a2a4", D = "#3e3638", r = "#2e2829", R = "#b8b2b4", x = "#908a8c" }, rows = {
  "..............",
  ".Rr........Rr.",
  ".rrx......xrr.",
  "...xx....xx...",
  "....xx..xx....",
  ".....xxxx.....",
  "......xx......",
  ".....xxxx.....",
  "....xx..xx....",
  "...xx....xx...",
  "..xx......xx..",
  ".Rr........Rr.",
  ".rr........rr.",
  "..............",
} }

D.gold = { kind = "frame", K = "#3a2a06", pal = { F = "#e8c22e", L = "#ffe680", D = "#a87a10", w = "#fff8d0", s = "#f6d856", d = "#c49a1c" }, rows = {
  "ww............",
  "w..s..........",
  "....s.........",
  "..............",
  "dddddddddddddd",
  "..............",
  ".s............",
  "..s...........",
  "..............",
  "dddddddddddddd",
  "..............",
  ".s..........w.",
  "..s........ww.",
  "..............",
} }

D.lapis_lazuli = { kind = "frame", K = "#2a2628", pal = { F = "#e9e4e2", L = "#fbf8f7", D = "#a9a2a0", g = "#33abbb", G = "#7ad6e0", d = "#1f7a86" }, rows = {
  "..............",
  "..Gg..........",
  "..gd.....Gg...",
  ".........gd...",
  "..............",
  "....Gg........",
  "....gd.....Gg.",
  "...........gd.",
  ".Gg...........",
  ".gd.....Gg....",
  "........gd....",
  "..............",
  "...Gg......Gg.",
  "...gd......gd.",
} }

D.limestone = { kind = "frame", K = "#22242c", pal = { F = "#a3a8b8", L = "#c6cad6", D = "#6e7282", f = "#858a9a", m = "#3f6a14", M = "#5a8a24" }, rows = {
  "..............",
  ".mM...........",
  ".m.....fff....",
  "......f...f...",
  "......f.f.f...",
  "......f..ff...",
  ".......f......",
  "..............",
  "..fff.........",
  ".f...f.....Mm.",
  ".f.f.f......m.",
  ".f..ff........",
  "..f...........",
  ".......mM.....",
} }

D.snow = { kind = "frame", K = "#3a5866", pal = { F = "#eef3f6", L = "#ffffff", D = "#a9c8d4", b = "#cfe2ea", c = "#25bcb6" }, rows = {
  "..............",
  "...b.......c..",
  "..............",
  ".......b......",
  "..c..........b",
  "..............",
  "....b....c....",
  ".b............",
  "..........b...",
  "...c..........",
  "......b....c..",
  "bb..........bb",
  "bbbb..bbb..bbb",
  "bbbbbbbbbbbbbb",
} }

D.high_tech_block = { kind = "frame", K = "#1a1818", pal = { F = "#9c9a9a", L = "#c8c6c6", D = "#5a5858", k = "#3a3838", r = "#d01010", R = "#ff6060", c = "#6e6c6c" }, rows = {
  "..............",
  ".kkkkkkkkkkkk.",
  ".kRrrRrrRrrRk.",
  ".kkkkkkkkkkkk.",
  "..............",
  ".cc...cccc....",
  "...c..c..c....",
  "...cccc..cc...",
  "..........c...",
  ".ccc......ccc.",
  "...c.cccc.....",
  "...ccc..c.....",
  "........c..rR.",
  "..............",
} }

D.space_window = { kind = "frame", K = "#1a1a22", pal = { F = "#b8b8bc", L = "#e2e2e6", D = "#78787e", s = "#0c0a1e", w = "#ffffff", p = "#6a4ac8" }, rows = {
  "..............",
  ".ssssssssssss.",
  ".swsssssspsss.",
  ".ssssssspppss.",
  ".sssswsssppss.",
  ".ssssssssssws.",
  ".spssssssssss.",
  ".pppsssswssss.",
  ".sppsssssssss.",
  ".ssssssssssss.",
  ".sssswsssspps.",
  ".swssssssssss.",
  ".ssssssssswss.",
  "..............",
} }

D.dragon_snappers = { kind = "frame", K = "#0c1a20", pal = { F = "#3fa882", L = "#6ed2a8", D = "#1f6a54", n = "#221863", w = "#ffffff", r = "#c0284a", l = "#7ae0b8" }, rows = {
  "..............",
  ".l...l....l...",
  "..nnnnnnnnnn..",
  ".nnwnwnwnwnnn.",
  ".nrrrrrrrrrrn.",
  ".nrrrrrrrrrrn.",
  ".nnwnwnwnwnnn.",
  "..nnnnnnnnnn..",
  "..............",
  ".l..l...l..l..",
  "..............",
  "...l....l....l",
  ".l....l.......",
  "..............",
} }

D.safe = { kind = "frame", K = "#1e1a1e", pal = { F = "#b8b2b5", L = "#dcd6d9", D = "#78727a", k = "#4a444a", g = "#d4b63a", G = "#f6e080" }, rows = {
  "..............",
  ".kkkkkkkkkkkk.",
  ".k..........k.",
  ".k..........k.",
  ".k...ggg....k.",
  ".k..gGkgg...k.",
  ".k..gk.kg..gk.",
  ".k..ggkgg..gk.",
  ".k...ggg...gk.",
  ".k..........k.",
  ".k..........k.",
  ".k..........k.",
  ".kkkkkkkkkkkk.",
  "..............",
} }

D.prison_door = { kind = "frame", K = "#1a0e08", pal = { F = "#af5828", L = "#d07a40", D = "#7a3a14", d = "#7a3a14", b = "#7c7f7f", B = "#b0b4b4", k = "#1a1418" }, rows = {
  "..............",
  ".kBkkBkkBkkBk.",
  ".kbkkbkkbkkbk.",
  ".kbkkbkkbkkbk.",
  ".kbkkbkkbkkbk.",
  ".kbkkbkkbkkbk.",
  "..............",
  "...d...d...d..",
  "...d...d...d..",
  "...d...d..BBd.",
  "...d...d..bbd.",
  "...d...d...d..",
  "...d...d...d..",
  "..............",
} }

-- free-standing pieces --------------------------------------------------------------------------

D.gate = { kind = "free", K = "#2a2a2c", top = true, pal = { w = "#b4b6b6", W = "#888a8a", R = "#a0a2a2", r = "#6a6c6c" }, rows = {
  "................",
  "..w....w....w...",
  "..wW...wW...wW..",
  "..wW...wW...wW..",
  ".RRRRRRRRRRRRRR.",
  ".rrrrrrrrrrrrrr.",
  "..wW...wW...wW..",
  "..wW...wW...wW..",
  "..wW...wW...wW..",
  "..wW...wW...wW..",
  "..wW...wW...wW..",
  ".RRRRRRRRRRRRRR.",
  ".rrrrrrrrrrrrrr.",
  "..wW...wW...wW..",
  "..wW...wW...wW..",
} }

D.prison_bars = { kind = "free", K = "#2a2828", top = true, pal = { b = "#e6e4e3", B = "#a8a5a4" }, rows = {
  "................",
  ".bbbbbbbbbbbbbb.",
  ".BBBBBBBBBBBBBB.",
  "..bB...bB...bB..",
  "..bB...bB...bB..",
  "..bB...bB...bB..",
  "..bB...bB...bB..",
  "..bB...bB...bB..",
  "..bB...bB...bB..",
  "..bB...bB...bB..",
  "..bB...bB...bB..",
  "..bB...bB...bB..",
  "..bB...bB...bB..",
  ".bbbbbbbbbbbbbb.",
  ".BBBBBBBBBBBBBB.",
} }

D.spike = { kind = "free", K = "#1a181c", pal = { S = "#ccd0d1", s = "#8e9496", d = "#5a5e62", b = "#756a76", B = "#4a424c" }, rows = {
  "..S....S....S...",
  "..Ss...Ss...Ss..",
  "..Ss...Ss...Ss..",
  ".SSsd.SSsd.SSsd.",
  ".SSsd.SSsd.SSsd.",
  ".SSsd.SSsd.SSsd.",
  ".SSsd.SSsd.SSsd.",
  ".bbbbbbbbbbbbbb.",
  ".bbbbbbbbbbbbbb.",
  ".BBBBBBBBBBBBBB.",
  ".BBBBBBBBBBBBBB.",
  ".BBBBBBBBBBBBBB.",
} }

D.poison_spike = { kind = "free", K = "#1c141e", pal = { S = "#b08ab8", s = "#6c4a74", d = "#3e2846", b = "#706472", B = "#4a3e4c", g = "#6cff3a", G = "#3ab81a" }, rows = {
  "..S....S....S...",
  "..Ss...Sg...Ss..",
  "..Sg...Ss...Sg..",
  ".SSsd.SSsG.SSsG.",
  ".SSgd.SSsd.SSsd.",
  ".SSsG.SSgd.SSgd.",
  ".SSsd.SSsG.SSsd.",
  ".bbgbbbbbbbgbbb.",
  ".bbGbbbbgbbGbbb.",
  ".BBBBBBBGBBBBBB.",
  ".BBBBBBBBBBBBBB.",
  ".BBBBBBBBBBBBBB.",
} }

D.plumber_pipe = { kind = "free", K = "#0e2a02", pal = { L = "#9cf060", G = "#5fc406", D = "#3a8a04", d = "#2a6a02", W = "#d8ffb0" }, rows = {
  "................",
  ".LLWGGGGGGGGGDd.",
  ".LLWGGGGGGGGGDd.",
  ".LLWGGGGGGGGGDd.",
  ".dddddddddddddd.",
  "..LWGGGGGGGGDd..",
  "..LWGGGGGGGGDd..",
  "..LWGGGGGGGGDd..",
  "..LWGGGGGGGGDd..",
  "..LWGGGGGGGGDd..",
  "..LWGGGGGGGGDd..",
  "..LWGGGGGGGGDd..",
  "..LWGGGGGGGGDd..",
  "..LWGGGGGGGGDd..",
  "..LWGGGGGGGGDd..",
} }

D.sink = { kind = "free", K = "#2a2830", pal = { W = "#fbfafa", w = "#dcd9d2", d = "#ada994", m = "#8a8a92", M = "#c8c8d0", b = "#4aa8d8" }, rows = {
  ".......MMm......",
  ".......Mm.......",
  ".WWWWWWMmWWWWWW.",
  ".WbbbbbbbbbbbbW.",
  ".wWbbbbbbbbbbWw.",
  "..wWWWWWWWWWWw..",
  "...wddddddddw...",
  "......WWw.......",
  "......WWw.......",
  ".....WWWww......",
} }

D.sprinkler = { kind = "free", K = "#1c1a1c", pal = { m = "#b9b1b2", M = "#e0dadb", d = "#6e6668", c = "#12c7ca", C = "#8af2f4" }, rows = {
  "...C.......C....",
  "...c...C...c....",
  ".......c........",
  "................",
  "....MMMMMMMM....",
  "....mmddddmm....",
  ".......md.......",
  ".......md.......",
  ".......md.......",
  ".......md.......",
  "......Mmmd......",
  ".....Mmmmdd.....",
  ".....mddddd.....",
} }

D.steel_platform = { kind = "free", K = "#1c1810", top = true, pal = { L = "#cfc9ca", F = "#a59fa0", D = "#6e6869", r = "#3e3620", d = "#635731" }, rows = {
  "................",
  ".LLLLLLLLLLLLLL.",
  ".FrFFFFFFFFFFrF.",
  ".FFFFFFFFFFFFFF.",
  ".DDDDDDDDDDDDDD.",
  "..dd......dd....",
  "...d......d.....",
} }

D.gold_platform_ = { kind = "free", K = "#2a2806", top = true, pal = { L = "#f0f4a8", F = "#d7df82", D = "#8a8a20", r = "#47460a", d = "#8a8a20" }, rows = {
  "................",
  ".LLLLLLLLLLLLLL.",
  ".FrFFFFFFFFFFrF.",
  ".FFFFFFFFFFFFFF.",
  ".DDDDDDDDDDDDDD.",
  "..dd......dd....",
  "...d......d.....",
} }

D.hanging_flytrap = { kind = "free", K = "#1e0c18", top = true, pal = { v = "#6a4430", V = "#492b1c", g = "#4a8a2a", M = "#e05ac8", m = "#be18a1", d = "#7a0e66", w = "#ffffff" }, rows = {
  ".......vV.......",
  ".......vV.......",
  ".....g.vV.g.....",
  "....gg.vV.gg....",
  ".......vV.......",
  "......MMMM......",
  "....MMmmmmMM....",
  "...MmmmmmmmmM...",
  "...dmmmmmmmmd...",
  "...wdwdwdwdw....",
  "....dddddddd....",
  "...wdwdwdwdwd...",
  "...MmmmmmmmmM...",
  "....MMmmmmMM....",
  "......MMMM......",
} }

D.lemon = { kind = "free", K = "#3a3400", pal = { y = "#f5f000", Y = "#fffa80", o = "#c8b800", l = "#4a9a2a", s = "#6a4a20" }, rows = {
  "..........s.....",
  "........lls.....",
  ".....yyyyyy.....",
  "...yYYyyyyyyo...",
  "..yYYyyyyyyyyo..",
  ".yyYyyyyyyyyyoo.",
  ".yyyyyyyyyyyyoo.",
  "..yyyyyyyyyyoo..",
  "...oyyyyyyyoo...",
  ".....oooooo.....",
} }

D.melon = { kind = "free", K = "#3a2600", pal = { m = "#e0a50b", M = "#f2c850", d = "#a87400", n = "#f5d890", s = "#4a6a20" }, rows = {
  ".......ss.......",
  ".....mmmmmm.....",
  "...mMMmnmmmmd...",
  "..mMMnmmmnmmmd..",
  ".mMnmmmnmmmnmdd.",
  ".mmmnmmmnmmmndd.",
  ".mnmmmnmmmnmmdd.",
  ".mmmnmmmnmmmndd.",
  ".mnmmmnmmmnmmdd.",
  "..mmnmmmnmmmdd..",
  "...dmmnmmmndd...",
  ".....dddddd.....",
} }

D.pumpkin = { kind = "free", K = "#3a1800", pal = { o = "#ea7217", O = "#ff9a40", d = "#b04a08", r = "#c45a0c", s = "#5a7a20", S = "#3a5a10" }, rows = {
  ".......sS.......",
  "......sS........",
  "....oOoooooo....",
  "..oOOorooroood..",
  ".oOOorooroooodd.",
  ".oOoorooroooodd.",
  ".ooorooroooordd.",
  ".ooorooroooordd.",
  ".dooroorooorddd.",
  "..ddrddrddrdd...",
  "....dddddddd....",
} }

D.starfruit = { kind = "free", K = "#2e3a10", pal = { y = "#cef37e", Y = "#effcb8", d = "#9ab84a" }, rows = {
  ".......yy.......",
  ".......yy.......",
  "......yYyd......",
  ".yyyyyYYyyyyyd..",
  "..yYYYyyyyydd...",
  "...yYyyyyyyd....",
  "...yYyyyyyyd....",
  "..yyyd...yyyd...",
  ".yyd.......yyd..",
  ".yd.........yd..",
} }

D.ruby = { kind = "free", K = "#2a0602", pal = { r = "#d42a14", R = "#ff6a3a", w = "#ffd0c0", d = "#8a1408", D = "#5a0c04" }, rows = {
  ".....RRRRRR.....",
  "....RwRrrrrr....",
  "...RwRrrrrrrr...",
  "..rrrrrrrrrrrr..",
  "...drrrrrrrrd...",
  "....drrrrrrd....",
  ".....ddrrdd.....",
  "......dDDd......",
  ".......DD.......",
} }

D.rose_quartz = { kind = "free", K = "#3a1430", pal = { P = "#ffd6fb", p = "#f2a8ee", d = "#c46aa8", q = "#b06a68" }, rows = {
  ".......P........",
  "......PPp.......",
  "...P..PPp.......",
  "..PPp.Pppd..P...",
  "..PppdPpppdPPp..",
  "..PppdPpppdPppd.",
  "..PppdPpppdPppd.",
  "..PppdPpppdPppd.",
  ".qqqqqqqqqqqqqq.",
  "..qqqqqqqqqqqq..",
} }

D.deathcap = { kind = "free", K = "#1a0622", pal = { c = "#8a2ab0", C = "#b05ad8", d = "#4a0a62", s = "#22a2c0", S = "#8ae8f8", t = "#e8dcc8", T = "#b8a890" }, rows = {
  ".....cCCCCc.....",
  "...cCCsCCCCcd...",
  "..cCsSCCCsCccd..",
  ".cCCCCCsCCCccdd.",
  ".dddddddddddddd.",
  "......ttT.......",
  "......ttT.......",
  ".....tttTT......",
} }

D.dried_mushroom = { kind = "free", K = "#2a1806", pal = { c = "#e8c870", C = "#fff0a8", d = "#b08a3a", r = "#ed221b", R = "#a01810", t = "#d8c8a0", T = "#a89870" }, rows = {
  "......cCCc......",
  "....cCcdcCcr....",
  "...rcdcCcdcrR...",
  "...RrrrrrrrrR...",
  ".......tT.......",
  "......ttT.......",
  "......tTT.......",
} }

D.fishbowl = { kind = "free", K = "#1a3a38", pal = { g = "#d8f0f0", G = "#ffffff", a = "#e4f8f6", W = "#8af0d0", w = "#1ebe87", f = "#ff8a2a", F = "#ffc070", b = "#c4c4c4" }, rows = {
  ".....ggggggg....",
  "...ggaaaaaaagg..",
  "..gGaaaaaaaaag..",
  ".gGWWWWWWWWWWWg.",
  ".gGwwwwwwwwwwwg.",
  ".gwwwfFwwwwwwwg.",
  ".gwwffFFwwwwwwg.",
  ".gwwwfFwwwwwwwg.",
  "..gwwwwwwwwwwg..",
  "...ggwwwwwwgg...",
  "....bbbbbbbb....",
} }

D.fishtank = { kind = "free", K = "#1a2a2a", pal = { M = "#e8e8e8", m = "#c2c2c2", d = "#8a8a8a", W = "#7ae0e2", w = "#31afb1", s = "#e0c890", f = "#ffcf40", F = "#ff9a20", p = "#3a9a3a" }, rows = {
  ".MMMMMMMMMMMMMM.",
  ".mWWWWWWWWWWWWd.",
  ".mwwwwwwwwwwwwd.",
  ".mwwwfFwwwwwwwd.",
  ".mwwfFFfwwwwwwd.",
  ".mwwwwwwwwwpwwd.",
  ".mwpwwwwwwwpwwd.",
  ".mwpwwwwwwppwwd.",
  ".mssssssssssssd.",
  ".dddddddddddddd.",
  "..d..........d..",
  "..d..........d..",
} }

D.lifeshroom = { kind = "free", K = "#2a2400", pal = { c = "#fff508", C = "#fffaa0", d = "#c8b800", k = "#8a7a00", t = "#4a4846", T = "#2a2928" }, rows = {
  "......cCCc......",
  "....cCCCCCCc....",
  "...cCCkCCCCcd...",
  "..cCCCCCCkCccd..",
  "..cCkCCCCCCccd..",
  "..dddddddddddd..",
  "......ttT.......",
  "......ttT.......",
  ".....tttTT......",
} }

D.pigcap = { kind = "free", K = "#2a1430", pal = { c = "#e09dff", C = "#f4c8ff", d = "#a860c8", n = "#f070b0", N = "#b03a7a", t = "#c8a870", T = "#715e20" }, rows = {
  ".....cCCCCc.....",
  "...cCCCCCCCcd...",
  "..cCCCnnnnCccd..",
  ".cCCCnNnnNncccd.",
  ".cCCCCnnnnccccd.",
  ".dddddddddddddd.",
  "......ttT.......",
  "......ttT.......",
  ".....tttTT......",
} }

D.rabbit_shroom = { kind = "free", K = "#1e221c", pal = { c = "#8a9682", C = "#b4c0ac", d = "#4a5444", e = "#c88aa8", k = "#2a2a2a", n = "#e08ab0", t = "#e0d8cc", T = "#a89c90" }, rows = {
  "....cc....cc....",
  "....ce....ce....",
  "....ce....ce....",
  "....cc....cc....",
  ".....cCCCCc.....",
  "...cCCCCCCCcd...",
  "..cCCCCCCCCccd..",
  "..cCkCCCCkCccd..",
  ".ccCCCCnCCCcccd.",
  ".dddddddddddddd.",
  "......ttT.......",
  "......ttT.......",
  ".....tttTT......",
} }

D.rose = { kind = "free", K = "#2a0606", pal = { r = "#e21111", R = "#ff5a50", d = "#900a0a", g = "#3a8a2a", G = "#5ab83a", D = "#2a6020" }, rows = {
  "......rRRr......",
  ".....rRrdRr.....",
  "....rRrdrrRd....",
  "....rrdRRdrd....",
  ".....drrrrd.....",
  "......dddd......",
  ".......g........",
  ".......g.GG.....",
  "..GG...gGG......",
  "...GGD.g........",
  ".......gD.......",
  ".......g........",
  ".......g........",
} }

D.science_shroom = { kind = "free", K = "#1a1a1a", pal = { c = "#c0bcbc", C = "#e8e4e4", d = "#7a7676", k = "#272727", a = "#4ad8ff", t = "#f0ece0", T = "#b0aca0" }, rows = {
  ".....cCCCCc.....",
  "...cCkkkkCCcd...",
  "..cCkCCCCkCccd..",
  ".cCCkCaaCkCcccd.",
  ".cCCCkkkkCCcccd.",
  ".dddddddddddddd.",
  "......ttT.......",
  "......ttT.......",
  ".....tttTT......",
} }

D.seaweed = { kind = "free", K = "#0c3a22", outline = false, pal = { g = "#29bf76", G = "#6ae8a8", d = "#1a7a48", y = "#4ab829" }, rows = {
  "....G...........",
  "....g.....G.....",
  ".....g....g.....",
  ".....g...g......",
  "....g....g...G..",
  "...g......g..g..",
  "...y......g..g..",
  "....g....y....g.",
  "....g....g....g.",
  ".....g...g...g..",
  "..G..g..g....y..",
  "..g..y..g...g...",
  "...gg...g...g...",
  "...dddddddddd...",
} }

D.sheep_shroom = { kind = "free", K = "#2a2626", pal = { W = "#ffffff", w = "#f0ece4", s = "#c6bebf", t = "#e5decc", T = "#a89e88" }, rows = {
  "....WW.WW.WW....",
  "...WwwWwwWwwW...",
  "..WwwwwwwwwwwsW.",
  ".Wwwwwwwwwwwwws.",
  ".sWwwwwwwwwwwss.",
  "..sssWwwwWssss..",
  "....ss.ss.ss....",
  "......ttT.......",
  "......ttT.......",
  ".....tttTT......",
} }

D.shroom_melons = { kind = "free", K = "#122a02", pal = { g = "#56c505", G = "#9af060", d = "#2a6a02", s = "#5d7905", t = "#e0e8c0", T = "#a8b080" }, rows = {
  "....gGGGg.......",
  "..gGsGGsGgd.....",
  ".gGsGGsGGsgd....",
  ".gsGGsGGsGgd.gg.",
  ".ddddddddddd.gsd",
  "....ttT.....ddd.",
  "....ttT......tT.",
  "...tttTT.....tT.",
} }

D.sign = { kind = "free", K = "#24160a", pal = { W = "#e09050", w = "#bc6e2d", d = "#7a4418", k = "#462e18", p = "#8a5a2a" }, rows = {
  ".WWWWWWWWWWWWWW.",
  ".Wwwwwwwwwwwwwd.",
  ".Wwkkkwkkkkwwwd.",
  ".Wwwwwwwwwwwwwd.",
  ".Wwkkkkwkkkwwwd.",
  ".Wwwwwwwwwwwwwd.",
  ".dddddddddddddd.",
  ".......pp.......",
  ".......pp.......",
  ".......pp.......",
  ".......pp.......",
  "......dppd......",
} }

D.sporeberry = { kind = "free", K = "#0e2a0e", pal = { g = "#3aa83a", G = "#6ad86a", d = "#1e6a1e", r = "#e81c23", R = "#ff7070", b = "#229dcc" }, rows = {
  "....gGg..gGGg...",
  "..gGGrRgGGgrRg..",
  ".gGrRrrgGbgrrgd.",
  ".grrrbgrRrgggdd.",
  ".ggbgrrrrgbrRdd.",
  "..dgrrdgggrrdd..",
  "...dddddddddd...",
} }

D.well = { kind = "free", K = "#1e1a16", pal = { R = "#b06a30", r = "#8a4a20", p = "#6a3a18", y = "#d8c08a", b = "#8a8a92", S = "#d4d2c0", s = "#abaa98", d = "#6e6c5c" }, rows = {
  ".......RR.......",
  ".....RRRRrr.....",
  "...RRRRrrrrrr...",
  ".rrrrrrrrrrrrrr.",
  "..p....y....p...",
  "..p....y....p...",
  "..p...bbb...p...",
  "..p...bbb...p...",
  ".SSSSSSSSSSSSSS.",
  ".sssdsssdsssdss.",
  ".sdsssdsssdsssd.",
  ".sssdsssdsssdss.",
  ".dddddddddddddd.",
} }

-- The designer's own glossy block (Purple Block), recolored: only its 3 colors change
-- (black frame and white shines stay). Same ramps as make_block_variants.lua.
local GLOSS = {
  red_blockseed = { "#dc5757", "#c16262", "#842121" },
  orange_block = { "#f6a63a", "#dc9a3e", "#9a5e10" },
  pink_block = { "#f7bff5", "#e8a9e4", "#b06aab" },
  lime = { "#c8ff8a", "#a9e874", "#5f9a33" },
  grey_block = { "#8c7c7c", "#725f5f", "#463838" },
}

-- batch 2 (2026-11-20): every other block / decoration that had no art -------------------------

D.amber = { kind = "frame", K = "#3a1e06", pal = { F = "#e8a830", L = "#ffd270", D = "#a8641a", b = "#4a2a10", w = "#fff0c0", s = "#f6c050" }, rows = {
  "ww............",
  "w....s........",
  "..............",
  "...s......s...",
  "..............",
  "......bb......",
  ".....bbbb.....",
  "....b.bb.b....",
  "......bb......",
  ".....b..b.....",
  "..............",
  "..s.......s...",
  "............w.",
  "...........ww.",
} }

D.asphalt = { kind = "frame", K = "#121110", pal = { F = "#4a4846", L = "#6a6866", D = "#2a2826", p = "#8a8886", d = "#34322f", y = "#e6c84a" }, rows = {
  "..............",
  ".p....d....p..",
  "....p.....d...",
  "..d.......p...",
  ".......p......",
  "..............",
  "yyy..yyy..yyy.",
  "..............",
  ".d...p....d...",
  "......d.p.....",
  "..p.........d.",
  ".....p..d.....",
  ".p.........p..",
  "..............",
} }

D.bacon = { kind = "frame", K = "#3a1208", pal = { F = "#e8907a", L = "#f4b0a0", D = "#a8503a", f = "#fcd8c0", r = "#c8584a" }, rows = {
  "ffffffffffffff",
  "ff.ffff..ffff.",
  "..............",
  "rr..rrrrr..rrr",
  "..............",
  "ffffffffffffff",
  "fff..fffff..ff",
  "..............",
  "rrr..rrrr..rrr",
  "..............",
  "ffffffffffffff",
  "f..ffff..fffff",
  "..............",
  "..............",
} }

D.barn_blocks = { kind = "frame", K = "#3a0808", pal = { F = "#c42424", L = "#e85050", D = "#7a1010", w = "#f3f2f1" }, rows = {
  "wwwwwwwwwwwwww",
  "www........www",
  "w.ww......ww.w",
  "w..ww....ww..w",
  "w...ww..ww...w",
  "w....wwww....w",
  "w.....ww.....w",
  "w.....ww.....w",
  "w....wwww....w",
  "w...ww..ww...w",
  "w..ww....ww..w",
  "w.ww......ww.w",
  "www........www",
  "wwwwwwwwwwwwww",
} }

D.stone_bricks = { kind = "frame", K = "#24202a", pal = { F = "#b8b0b2", L = "#dcd6d8", D = "#7e7678", m = "#8a8496" }, rows = {
  "......m.......",
  "......m.......",
  "......m.......",
  "mmmmmmmmmmmmmm",
  "..m.......m...",
  "..m.......m...",
  "..m.......m...",
  "mmmmmmmmmmmmmm",
  "......m.......",
  "......m.......",
  "......m.......",
  "mmmmmmmmmmmmmm",
  "..m.......m...",
  "..m.......m...",
} }

D.bricksw = { kind = "frame", K = "#2a0e06", pal = { F = "#c65634", L = "#e07850", D = "#8a3418", m = "#f0ece8" }, rows = {
  "......m.......",
  "......m.......",
  "......m.......",
  "mmmmmmmmmmmmmm",
  "..m.......m...",
  "..m.......m...",
  "..m.......m...",
  "mmmmmmmmmmmmmm",
  "......m.......",
  "......m.......",
  "......m.......",
  "mmmmmmmmmmmmmm",
  "..m.......m...",
  "..m.......m...",
} }

D.stone_pathway = { kind = "frame", K = "#1a1918", pal = { F = "#8a8a96", L = "#b0b0bc", D = "#4a4846", g = "#3e3c39" }, rows = {
  "....g......g..",
  "....g......g..",
  "...g.gggggg.gg",
  "ggg...g.......",
  ".......g......",
  "..g.....g.....",
  "..g.....gggggg",
  "ggggg...g.....",
  ".....g..g.....",
  ".....g...g....",
  ".....gggg.gggg",
  "gggg.g....g...",
  "....g.....g...",
  "....g.....g...",
} }

D.coal = { kind = "frame", K = "#050404", pal = { F = "#2a2828", L = "#4a4646", D = "#121010", s = "#6a6a72", w = "#b8b8c8" }, rows = {
  "..............",
  "..s.......w...",
  "..............",
  "......s.......",
  ".w..........s.",
  "..............",
  "....s.....s...",
  "..............",
  "..w.......s...",
  "........w.....",
  ".s............",
  "......s....w..",
  "..............",
  "..............",
} }

D.charcoal = { kind = "frame", K = "#0a0604", pal = { F = "#3a2a22", L = "#5a4232", D = "#1a120c", e = "#e06a1c", E = "#ffb050", g = "#6a4a32" }, rows = {
  "..............",
  ".gg.....gg....",
  "...g......g...",
  ".....e........",
  "..g.....g..gg.",
  "........eE....",
  ".gg...g.......",
  "....g.....g...",
  "..eE......g...",
  "......gg......",
  ".g.......e....",
  "....gg.....gg.",
  "..............",
  "..............",
} }

D.copper_block = { kind = "frame", K = "#2a1404", pal = { F = "#d17a2a", L = "#f0a050", D = "#8a4a10", v = "#768d51", V = "#9ab878", r = "#6a3a08", R = "#ffd0a0" }, rows = {
  "..............",
  ".Rr........Rr.",
  ".rr...vV...rr.",
  "......vv......",
  "..............",
  "vv............",
  "Vv........vV..",
  "..........vv..",
  "..............",
  "....vV........",
  "....vv........",
  ".Rr........Rr.",
  ".rr........rr.",
  "..............",
} }

D.topaz = { kind = "frame", K = "#3a2e00", pal = { F = "#e9c400", L = "#fff060", D = "#a88a00", w = "#ffffff", f = "#f8e040", d = "#c8a400" }, rows = {
  "ww....f.......",
  "w....fff......",
  "....fffff.....",
  "...f.....d....",
  "..f.......d...",
  ".f.........d..",
  "f...........d.",
  "d...........f.",
  ".d.........f..",
  "..d.......f...",
  "...d.....f....",
  "....ddddd.....",
  "..........w...",
  ".........ww...",
} }

D.wooden_window = { kind = "frame", K = "#2a1a06", pal = { F = "#c09040", L = "#e0b860", D = "#806020", g = "#bfe0f0", G = "#ffffff", b = "#9ac0d8" }, rows = {
  "..............",
  ".Ggggg..Ggggg.",
  ".Gbggg..Gbggg.",
  ".ggggg..ggggg.",
  ".ggggb..ggggb.",
  ".gggbb..gggbb.",
  "..............",
  "..............",
  ".Ggggg..Ggggg.",
  ".Gbggg..Gbggg.",
  ".ggggg..ggggg.",
  ".ggggb..ggggb.",
  ".gggbb..gggbb.",
  "..............",
} }

D.window = { kind = "frame", K = "#1e1c1c", pal = { F = "#a8a2a2", L = "#d8d2d2", D = "#6a6464", g = "#cfe8f4", G = "#ffffff", b = "#a8d0e8", m = "#77580f" }, rows = {
  "..............",
  ".GggggmmGgggg.",
  ".GbgggmmGbggg.",
  ".gggggmmggggg.",
  ".ggggbmmggggb.",
  ".gggbbmmgggbb.",
  ".mmmmmmmmmmmm.",
  ".mmmmmmmmmmmm.",
  ".GggggmmGgggg.",
  ".GbgggmmGbggg.",
  ".gggggmmggggg.",
  ".ggggbmmggggb.",
  ".gggbbmmgggbb.",
  "..............",
} }

D.sturdy_door = { kind = "frame", K = "#2a1006", pal = { F = "#c75c24", L = "#e88040", D = "#8a3a10", d = "#9a4a18", b = "#4a4a52", B = "#8a8a92", k = "#e0c040" }, rows = {
  "..............",
  "...d...d...d..",
  "bbbbbbbbbbbbbb",
  "bBbbbbbbbbbbBb",
  "...d...d...d..",
  "...d...d...d..",
  "...d...d...dk.",
  "...d...d...d..",
  "...d...d...d..",
  "bbbbbbbbbbbbbb",
  "bBbbbbbbbbbbBb",
  "...d...d...d..",
  "...d...d...d..",
  "..............",
} }

D.wooden_platform = { kind = "free", K = "#2a1a06", top = true, pal = { L = "#e8a050", F = "#cd821c", D = "#8a5210", r = "#6a5832", d = "#6a5832" }, rows = {
  "................",
  ".LLLLLLLLLLLLLL.",
  ".FFFFrFFFFFrFFF.",
  ".FFFFrFFFFFrFFF.",
  ".DDDDDDDDDDDDDD.",
  "..dd......dd....",
  "...d......d.....",
} }

D.water = { kind = "free", K = "#0a2a30", top = true, outline = false, pal = { b = "#29abb6", B = "#6ad0da", w = "#cdeff2", d = "#1a7a86" }, rows = {
  "..ww......ww....",
  ".wBBw....wBBw...",
  "BBbbBBwwBBbbBBww",
  "bbbbbbBBbbbbbbBB",
  "bbbbbbbbbbbbbbbb",
  "bbBBbbbbbbbbbbbb",
  "bbbbbbbbbbBBbbbb",
  "bbbbbbbbbbbbbbbb",
  "bbbbbBBbbbbbbbbb",
  "bbbbbbbbbbbbbBBb",
  "bbbbbbbbbbbbbbbb",
  "bbBBbbbbbbbbbbbb",
  "bbbbbbbbbBBbbbbb",
  "bbbbbbbbbbbbbbbb",
  "dbbbbbbbbbbbbbbd",
  "dddddddddddddddd",
} }

D.traffic_cone = { kind = "free", K = "#2a0e00", pal = { o = "#ff4304", O = "#ff8a50", w = "#ffffff", d = "#b02a00", b = "#e39800", B = "#a86c00" }, rows = {
  ".......Oo.......",
  "......Oood......",
  "......wwww......",
  ".....Oooood.....",
  ".....wwwwww.....",
  "....Oooooood....",
  "....Oooooood....",
  "..bbbbbbbbbbbb..",
  ".BBBBBBBBBBBBBB.",
} }

D.venus_flytrap = { kind = "free", K = "#122a06", pal = { g = "#56d016", m = "#b813b8", w = "#ffffff", l = "#3a9a10" }, rows = {
  "...g.......g....",
  "...gw.....wg....",
  "...gmw...wmg....",
  "...gmmw.wmmg....",
  "....gmmmmmg.....",
  ".....ggggg......",
  ".......g........",
  "..ll...g...ll...",
  "...ll..g..ll....",
  "....lllgll......",
  ".......g........",
  "......ggg.......",
} }

D.watermelon = { kind = "free", K = "#062a02", pal = { g = "#39cf00", G = "#7af040", d = "#0f5a0a", s = "#1a7a10" }, rows = {
  ".....gggggg.....",
  "...gGsggsggsd...",
  "..gGGsggsggsgd..",
  ".gGgsggsggsggdd.",
  ".ggsggsggsggsdd.",
  ".gsggsggsggsgdd.",
  "..gsggsggsggdd..",
  "...ddsddsddd....",
  ".....dddddd.....",
} }

D.apple = { kind = "free", K = "#2a0604", pal = { r = "#dd423a", R = "#ff8070", d = "#8a1a14", s = "#6a4a20", l = "#3dd31e" }, rows = {
  ".......s.ll.....",
  ".......sll......",
  "....rrr.rrr.....",
  "...rRRrrrrrd....",
  "..rRRrrrrrrrd...",
  "..rRrrrrrrrrd...",
  "..rrrrrrrrrrd...",
  "..rrrrrrrrrdd...",
  "...rrrrrrrdd....",
  "....dddd.ddd....",
} }

D.beetroot = { kind = "free", K = "#2a0410", pal = { r = "#db1a10", R = "#ff5a50", p = "#9a0a30", d = "#5a0620", l = "#3a9a2a", L = "#6ac83a" }, rows = {
  ".....L.l.L......",
  "......LlL.......",
  ".......l........",
  "......ppp.......",
  "....pRrrrpd.....",
  "...pRrrrrrpd....",
  "...prrrrrrpd....",
  "....prrrrpd.....",
  ".....pppd.......",
  "......pd........",
  ".......d........",
} }

D.boulder = { kind = "free", K = "#20202a", pal = { s = "#bdc4c6", S = "#e0e6e8", d = "#8c8ca4", D = "#5e5e74" }, rows = {
  ".....ssssss.....",
  "...sSSsssssd....",
  "..sSSssssssssd..",
  ".sSssssdssssssd.",
  ".ssssssddsssssd.",
  ".sssssssssssddd.",
  ".ssdsssssssssdd.",
  ".dsddsssssssddd.",
  "..dddddDDdddDd..",
  "...DDDDDDDDDD...",
} }

D.campfire = { kind = "free", K = "#1e0e04", pal = { f = "#ff8a20", F = "#ffe040", r = "#ca0e0e", l = "#8a5a2a", L = "#bf8122", d = "#4a2a10" }, rows = {
  ".......F........",
  "......FF..F.....",
  ".....FfF.FF.....",
  ".....FffFfF.....",
  "....FffrfffF....",
  "....frrrrrff....",
  "..LLLlfrrflLLL..",
  "...dLLLlLLLd....",
  "..LLLd....dLLL..",
  ".LLd........dLL.",
} }

D.carrot = { kind = "free", K = "#2a1600", pal = { o = "#ffa100", O = "#ffd060", d = "#c86a00", l = "#3a9a2a", L = "#6ac83a" }, rows = {
  ".......L.l.L....",
  "........LlL.....",
  ".......OOod.....",
  ".......Oood.....",
  "........Ood.....",
  "........ood.....",
  "........Od......",
  "........od......",
  "........d.......",
} }

D.chair = { kind = "free", K = "#2a2008", pal = { w = "#ce9a28", W = "#f0c060", d = "#6d6536" }, rows = {
  "....Wd..........",
  "....Wd..........",
  "....Wd..........",
  "....Wd..........",
  "....Wd..........",
  "....Wd..........",
  "....WWWWWWWWWWd.",
  "....dddddddddd..",
  "....Wd......Wd..",
  "....Wd......Wd..",
  "....Wd......Wd..",
} }

D.cherry_leaves = { kind = "free", K = "#4a2a52", pal = { p = "#fadfff", P = "#ffffff", d = "#eabfff", D = "#c890d8" }, rows = {
  "....pPp..pPp....",
  "..pPPpdpPPpdp...",
  ".pPPpddpPpPpddp.",
  ".pPpdpPPpdpPpdd.",
  ".dpdpPpddpPpdDd.",
  "..dDdpdDdpdDdD..",
  "...DD.DD.DD.DD..",
} }

D.chest = { kind = "free", K = "#2a1a04", pal = { w = "#dbaa2f", W = "#f0cc60", d = "#8a6a10", m = "#b3b3b3", M = "#e0e0e0", k = "#4a4a4a" }, rows = {
  "..WWWWWWWWWWWW..",
  ".Wwwwwwwwwwwwwd.",
  ".Wwwwwwwwwwwwwd.",
  ".MMMMMMkkMMMMMM.",
  ".mmmmmmMkmmmmmm.",
  ".Wwwwwwmmwwwwwd.",
  ".Wwwwwwwwwwwwwd.",
  ".Wwwwwwwwwwwwwd.",
  ".dddddddddddddd.",
} }

D.treasure_chest = { kind = "free", K = "#2a1a04", pal = { g = "#e5cc3b", G = "#fff090", d = "#a88a10", r = "#d42a14", b = "#2a8ad8", w = "#8a4a20", W = "#b06a30" }, rows = {
  "..GGGGGGGGGGGG..",
  ".gWWwwwwwwwwwwd.",
  ".gwwwwwwwwwwwwd.",
  ".GGGGGGrrGGGGGG.",
  ".gggggggrgggggd.",
  ".gwwwwwwwwwwwwd.",
  ".gwwbwwwwwwrwwd.",
  ".gwwwwwwwwwwwwd.",
  ".dddddddddddddd.",
} }

D.chicken_shroom = { kind = "free", K = "#2a2626", pal = { c = "#e8e8e8", C = "#ffffff", d = "#a8a8a8", r = "#c02c2c", y = "#f0b030", k = "#1a1a1a", t = "#f0e8d8", T = "#b8b0a0" }, rows = {
  "......rr.r......",
  ".....rrrrr......",
  "....cCCCCCc.....",
  "...cCCCCCCCcd...",
  "..cCCkCCCCCccd..",
  ".yycCCCCCCcccd..",
  "..dddddddddddd..",
  "......ttT.......",
  "......ttT.......",
  ".....tttTT......",
} }

D.cowcap = { kind = "free", K = "#1a1a1a", pal = { c = "#f0f0f0", C = "#ffffff", d = "#b0b0b0", k = "#1a1a1a", t = "#e8e0d0", T = "#a8a090" }, rows = {
  ".....cCCCCc.....",
  "...cCkkCCCkcd...",
  "..cCkkCCCCCkcd..",
  ".cCCCCCkkCCcccd.",
  ".ckkCCCkkCCckkd.",
  ".dddddddddddddd.",
  "......ttT.......",
  "......ttT.......",
  ".....tttTT......",
} }

D.bouncy_shroom = { kind = "free", K = "#102a04", pal = { c = "#4be123", C = "#9aff70", d = "#2a8a10", s = "#5e770b", t = "#e0e0c0", T = "#a8a890" }, rows = {
  ".....cCCCCc.....",
  "...cCCsCCCCcd...",
  "..cCsCCCCsCccd..",
  ".cCCCCsCCCCccdd.",
  ".dddddddddddddd.",
  "......tt........",
  ".......tt.......",
  "......tt........",
  ".......tt.......",
  ".....tttTT......",
} }

D.daffodil = { kind = "free", K = "#2a2600", pal = { y = "#ffee01", Y = "#fffdb6", o = "#f0a000", g = "#3a8a2a", l = "#5ab83a" }, rows = {
  "......Y.Y.......",
  ".....YyYyY......",
  "....YyyooyY.....",
  ".....yoooy......",
  "......yyy.......",
  ".......g........",
  "...l...g...l....",
  "...ll..g..ll....",
  "....ll.g.ll.....",
  ".......g........",
  "......ggg.......",
} }

D.tulip = { kind = "free", K = "#2a1200", pal = { o = "#ff9a03", O = "#ffc860", d = "#d16a0a", g = "#3a8a2a", l = "#5ab83a" }, rows = {
  ".....o.O.o......",
  ".....oOOoo......",
  ".....oOooo......",
  ".....doood......",
  "......ddd.......",
  ".......g........",
  "....l..g..l.....",
  "....ll.g.ll.....",
  ".....llgll......",
  ".......g........",
  "......ggg.......",
} }

D.danger_sign = { kind = "free", K = "#24160a", pal = { W = "#d89040", w = "#b67026", d = "#6a4010", y = "#ffd020", r = "#d01010", p = "#8a5a2a" }, rows = {
  ".WWWWWWWWWWWWWW.",
  ".Wwwwwwyywwwwwd.",
  ".Wwwwwyyyywwwwd.",
  ".Wwwwyyrryywwwd.",
  ".Wwwyyyrryyywwd.",
  ".Wwyyyyyyyyyywd.",
  ".dddddddddddddd.",
  ".......pp.......",
  ".......pp.......",
  ".......pp.......",
  "......dppd......",
} }

D.strawberry = { kind = "free", K = "#2a0606", pal = { s = "#eb3b3b", S = "#ff8080", d = "#9a1414", y = "#ffe080", l = "#9fe45e", L = "#5aa82a" }, rows = {
  ".....LlLlL......",
  "....LlllllL.....",
  "....sSsysSs.....",
  "...sSysssysd....",
  "...sSssysssd....",
  "...sysssssyd....",
  "....ssyssd......",
  ".....sssd.......",
  "......sd........",
} }

D.toilet = { kind = "free", K = "#2a2a2c", pal = { W = "#f4f4f4", w = "#d8d8d8", d = "#a5a6a4", k = "#6a6a6a" }, rows = {
  "..WWWWW.........",
  "..Wwwwwd........",
  "..Wwwwwd........",
  "..Wwwwwd........",
  "..Wwwwwkkkkkkk..",
  "..WWwwwwwwwwwd..",
  "...Wwwwwwwwwwd..",
  "....dwwwwwwwd...",
  ".....WwwwwWd....",
  ".....WwwwwWd....",
  "....WWWWWWWWd...",
} }

D.torch = { kind = "free", K = "#1e0e04", pal = { s = "#b7552a", S = "#d87a40", d = "#6a2a10", f = "#ff8a20", F = "#ffe040", w = "#fff8c0" }, rows = {
  ".......F........",
  "......FwF.......",
  "......fFf.......",
  "......fff.......",
  ".......sd.......",
  ".......Sd.......",
  ".......sd.......",
  ".......sd.......",
  ".......sd.......",
  ".......sd.......",
  "......dsdd......",
} }

D.wooden_fence = { kind = "free", K = "#2a1e04", pal = { w = "#cfa033", W = "#b3911b", R = "#e0b850", r = "#8a6a14" }, rows = {
  "..w....w....w...",
  "..wW...wW...wW..",
  "..wW...wW...wW..",
  ".RRRRRRRRRRRRRR.",
  ".rrrrrrrrrrrrrr.",
  "..wW...wW...wW..",
  "..wW...wW...wW..",
  ".RRRRRRRRRRRRRR.",
  ".rrrrrrrrrrrrrr.",
  "..wW...wW...wW..",
} }

D.blackberry = { kind = "free", K = "#0e1a0e", pal = { g = "#3aa83a", G = "#6ad86a", d = "#1e6a1e", b = "#290733", B = "#872bbe" }, rows = {
  "....gGg..gGGg...",
  "..gGGbBgGGgbBg..",
  ".gGbBbbgGBgbbgd.",
  ".gbbbBgbBbgggdd.",
  ".ggBgbbbbgBbBdd.",
  "..dgbbdgggbbdd..",
  "...dddddddddd...",
} }

D.bush = { kind = "free", K = "#122a04", pal = { g = "#67b926", G = "#9ae060", d = "#3a7a12", t = "#c17c2f" }, rows = {
  "....gGGg.gGg....",
  "..gGGgggGGgggd..",
  ".gGggtgggggtggd.",
  ".gggggggtgggggd.",
  ".gtggggggggggdd.",
  "..ddgggdggggdd..",
  "...dddt..tddd...",
  ".....t....t.....",
} }

D.coconut = { kind = "free", K = "#1e0e06", pal = { b = "#6a3a20", B = "#8a5a30", d = "#3a1e10", f = "#a07040" }, rows = {
  ".....bbbbbb.....",
  "...bBfBbbfbbd...",
  "..bBBbbfbbbfbd..",
  ".bBfbbbbbfbbbdd.",
  ".bbbbfbbbbbfbdd.",
  ".bfbbbbfbbbbbdd.",
  "..bbbfbbbbfbdd..",
  "...ddbbbbbbdd...",
  ".....dddddd.....",
} }

D.barrel = { kind = "free", K = "#1e1806", pal = { w = "#9a7a3a", W = "#c0a050", d = "#5a4a20", m = "#4a4a52", M = "#8a8a92" }, rows = {
  "...MMMMMMMMMM...",
  "..Wwwdwwdwwdwd..",
  ".MMMMMMMMMMMMMm.",
  ".Wwwdwwdwwdwwdd.",
  ".Wwwdwwdwwdwwdd.",
  ".Wwwdwwdwwdwwdd.",
  ".MMMMMMMMMMMMMm.",
  "..Wwwdwwdwwdwd..",
  "...mmmmmmmmmm...",
} }

GLOSS.aqua_block = { "#57cadc", "#62b4c1", "#217784" }
GLOSS.yellow_block = { "#f0dc40", "#d8c430", "#8a7810" }
GLOSS.brown_block = { "#a8744c", "#946a4a", "#613a1d" }
GLOSS.white_block = { "#f2f2f2", "#dadada", "#a3a3a3" }
GLOSS.black_block = { "#3d3d3d", "#2a2a2a", "#151515" }

-- batch 3 (2026-11-20): lava redone as a seamless tile, a better lava fishtank, the backgrounds ----

-- the designer asked to fix up the lava: their own drawing stays in block_art until they import this
D.lava = { kind = "free", K = "#2a0602", top = true, outline = false, pal = { y = "#ffe040", Y = "#fff8b0", O = "#ffa020", o = "#ff6a10", r = "#c8300a", R = "#8a1a08" }, rows = {
  "..yy......yy....",
  ".yOOy....yOOy...",
  "OOooOOyyOOooOOyy",
  "ooooooOOooooooOO",
  "oooyoooooooooooo",
  "ooyYyoooorrooooo",
  "ooOyOoooorrrooOo",
  "oooooooooooooOYO",
  "oorrrooooooooOOo",
  "orrrrroooyoooooo",
  "ooorrooooOoooooo",
  "oooooooooooorroo",
  "ooOoooooooorrrro",
  "orrroooooooooooo",
  "rrrrrrrooorrrrrr",
  "rRrrRrrrrrrrRrrr",
} }

D.lava_fishtank = { kind = "free", K = "#2a1a06", pal = { M = "#d8d860", m = "#a9a932", d = "#6a6a18", W = "#ffe040", y = "#fff8b0", w = "#ff6a10", r = "#c8300a", f = "#fff4a0", F = "#ffd040" }, rows = {
  ".MMMMMMMMMMMMMM.",
  ".mWWyWWWWyWWWWd.",
  ".mwwwwwwwwwwwwd.",
  ".mwwwfFwwwwywwd.",
  ".mwwfFFfwwwwwwd.",
  ".mwwwwwwwywwwwd.",
  ".mwywwwwwwwwrwd.",
  ".mwwwwrwwwwrrrd.",
  ".mrrrrrrrrrrrrd.",
  ".dddddddddddddd.",
  "..d..........d..",
  "..d..........d..",
} }

-- Backgrounds, in the designer's Stone / Cave Background style: a dark frame, a lit rim, a lighter
-- ring and a darker middle, all muted (backgrounds sit behind the blocks).
local function shade(h, f)
  h = h:gsub("#", "")
  local out = "#"
  for i = 0, 2 do
    local v = tonumber(h:sub(i * 2 + 1, i * 2 + 2), 16) * f
    out = out .. string.format("%02x", math.max(0, math.min(255, math.floor(v + 0.5))))
  end
  return out
end

local BG_BASE = {
  "LLLLLLLLLLLLLb",
  "LLbbbbbbbbbbbD",
  "LbbcccccccbbbD",
  "LbccccccccccbD",
  "LbccccccccccbD",
  "LbcccccccccccD",
  "LbcccccccccccD",
  "LbccccccccccbD",
  "LbbcccccccccbD",
  "LbbbcccccccbbD",
  "LbbbbcccccbbbD",
  "bbbbbbbbbbbbbD",
  "bbbbbbbbbbbDDD",
  "bDDDDDDDDDDDDD",
}

-- base color, optional pattern drawn on top ("." = keep the background), pattern colors
local function bg(base, light, pattern, ppal)
  local f = light and { L = 0.92, b = 0.80, c = 0.64, D = 0.52, K = 0.28 } or { L = 0.84, b = 0.72, c = 0.55, D = 0.42, K = 0.20 }
  local pal = { L = shade(base, f.L), b = shade(base, f.b), c = shade(base, f.c), D = shade(base, f.D) }
  for k, v in pairs(ppal or {}) do pal[k] = v end
  local rows = {}
  for r = 1, 14 do
    local row = BG_BASE[r]
    if pattern then
      local out = {}
      for c = 1, 14 do
        local ch = pattern[r]:sub(c, c)
        out[c] = (ch ~= ".") and ch or row:sub(c, c)
      end
      row = table.concat(out)
    end
    rows[r] = row
  end
  return { kind = "frame", K = shade(base, f.K), pal = pal, rows = rows }
end

local BRICKS = {
  "......m.......",
  "......m.......",
  "......m.......",
  "mmmmmmmmmmmmmm",
  "..m.......m...",
  "..m.......m...",
  "..m.......m...",
  "mmmmmmmmmmmmmm",
  "......m.......",
  "......m.......",
  "......m.......",
  "mmmmmmmmmmmmmm",
  "..m.......m...",
  "..m.......m...",
}
local PLANKS = {
  "....m....m....",
  ".n..m....m.n..",
  "....m....m....",
  "....m....m....",
  "....m.n..m....",
  "....m....m....",
  "....m....m....",
  "mmmmm....m....",
  "....m....mmmmm",
  "....m....m....",
  ".n..m....m....",
  "....m..n.m..n.",
  "....m....m....",
  "....m....m....",
}
local STRIPES = {
  "..............",
  "mmmmmmmmmmmmmm",
  "mm..mmmm..mmmm",
  "..............",
  "..............",
  "mmmmmmmmmmmmmm",
  "mmm..mmmm..mmm",
  "..............",
  "..............",
  "mmmmmmmmmmmmmm",
  "m..mmmm..mmmmm",
  "..............",
  "..............",
  "..............",
}
local SPORES = {
  "..............",
  "..m.......M...",
  "..............",
  "......M.......",
  ".M.........m..",
  "..............",
  ".....m........",
  "..........M...",
  "..M...........",
  "........m.....",
  "...........M..",
  ".m....M.......",
  "..............",
  "..............",
}

D.black_background = bg("#2a2a30")
D.blue_background = bg("#1d9fca")
D.gray_background = bg("#8a8a8e")
D.white_stone = bg("#2a9a2a")              -- Green Background (its id is white_stone)
D.orange_background = bg("#f0a020")
D.pink_background = bg("#ffa4ac", true)
D.purple_background = bg("#7a3aa8")
D.red_background = bg("#d02a2a")
D.yellow_background = bg("#e8e030")
D.white_background = bg("#e8e8ec", true)
D.bricks_background = bg("#b04a32", false, BRICKS, { m = "#4a1e14" })
D.stone_brick_background = bg("#9a8a8e", false, BRICKS, { m = "#3a3034" })
D.wooden_background = bg("#c59529", false, PLANKS, { m = "#4a3006", n = "#2a1c04" })
D.bacon_background = bg("#c87070", false, STRIPES, { m = "#e8b8a8" })
D.spore_background = bg("#6a3a2a", false, SPORES, { m = "#23b6ba", M = "#8af0f0" })

-- render -----------------------------------------------------------------------------------------

local problems = {}

local function grid16(id, d)
  local g = {}
  for y = 0, 15 do
    g[y] = {}
    for x = 0, 15 do g[y][x] = "." end
  end
  if d.kind == "frame" then
    if #d.rows ~= 14 then problems[#problems + 1] = id .. ": " .. #d.rows .. " rows (want 14)" end
    for r, row in ipairs(d.rows) do
      if #row ~= 14 then problems[#problems + 1] = id .. " row " .. r .. ": " .. #row .. " wide (want 14)" end
      for c = 1, math.min(#row, 14) do
        local ch = row:sub(c, c)
        if ch == "." then ch = "F" end
        g[r][c] = ch
      end
    end
    for y = 1, 14 do
      for x = 1, 14 do
        if g[y][x] == "F" then
          if y == 14 or x == 14 then g[y][x] = "D"
          elseif y == 1 or x == 1 then g[y][x] = "L" end
        end
      end
    end
  else
    local n = #d.rows
    if n > 16 then problems[#problems + 1] = id .. ": " .. n .. " rows (max 16)" end
    local y0 = d.top and 0 or (15 - n)  -- on the floor: the last row lands on row 14
    if d.top then y0 = 0 end
    for r, row in ipairs(d.rows) do
      if #row ~= 16 then problems[#problems + 1] = id .. " row " .. r .. ": " .. #row .. " wide (want 16)" end
      local y = y0 + r - 1
      if y >= 0 and y <= 15 then
        for c = 1, math.min(#row, 16) do g[y][c - 1] = row:sub(c, c) end
      end
    end
  end
  -- the outline: every see-through pixel next to a drawn one (left/right/up/down)
  if d.outline ~= false then
    local add = {}
    for y = 0, 15 do
      for x = 0, 15 do
        if g[y][x] == "." then
          local n = false
          for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            local yy, xx = y + o[2], x + o[1]
            if yy >= 0 and yy <= 15 and xx >= 0 and xx <= 15 and g[yy][xx] ~= "." and g[yy][xx] ~= "K" then n = true end
          end
          if n then add[#add + 1] = { x, y } end
        end
      end
    end
    for _, a in ipairs(add) do g[a[2]][a[1]] = "K" end
  end
  return g
end

local function render(id)
  local img = Image(32, 32, ColorMode.RGB)
  if GLOSS[id] then
    local tpl = Image { fromFile = P.template }
    local seen, colors = {}, {}
    for it in tpl:pixels() do
      local v = it()
      local r, g, b, a = pc.rgbaR(v), pc.rgbaG(v), pc.rgbaB(v), pc.rgbaA(v)
      if it.x < 32 and a > 0 and not seen[v] and not (r == 0 and g == 0 and b == 0) and not (r == 255 and g == 255 and b == 255) then
        seen[v] = true
        colors[#colors + 1] = { v = v, lum = r * 0.299 + g * 0.587 + b * 0.114 }
      end
    end
    table.sort(colors, function(a, b) return a.lum > b.lum end)
    local ramp = GLOSS[id]
    local swap = {}
    for i = 1, math.min(3, #colors) do swap[colors[i].v] = hex(ramp[i]) end
    for it in tpl:pixels() do
      if it.x < 32 then img:drawPixel(it.x, it.y, swap[it()] or it()) end
    end
    return img
  end
  local d = D[id]
  local g = grid16(id, d)
  local pal = {}
  for k, v in pairs(d.pal) do pal[k] = hex(v) end
  pal.K = hex(d.K or "#1c1824")
  for y = 0, 15 do
    for x = 0, 15 do
      local ch = g[y][x]
      if ch ~= "." then
        local c = pal[ch]
        if not c then
          problems[#problems + 1] = id .. ": no color for '" .. ch .. "'"
        else
          for dy = 0, 1 do
            for dx = 0, 1 do img:drawPixel(x * 2 + dx, y * 2 + dy, c) end
          end
        end
      end
    end
  end
  return img
end

-- which seeds, and where ----------------------------------------------------------------------------

local rows, names, order = {}, {}, {}
for pair in (P.rows or ""):gmatch("[^;]+") do
  local id, r = pair:match("^(.-)=(%d+)$")
  if id then rows[id] = tonumber(r); order[#order + 1] = id end
end
for pair in (P.names or ""):gmatch("[^;]+") do
  local id, n = pair:match("^(.-)=(.*)$")
  if id then names[id] = n end
end

local arts = {}
for _, id in ipairs(order) do
  if not D[id] and not GLOSS[id] then problems[#problems + 1] = id .. ": no design" else arts[id] = render(id) end
end
if #problems > 0 then
  print("PROBLEMS:\n" .. table.concat(problems, "\n"))
  return
end

-- the review sheet: the game's sheet + the proposals on their own layer
local spr = app.open(P.sheet)
spr.layers[1].name = "Current art (from the game)"
local layer = spr:newLayer()
layer.name = "New art (proposed)"
local canvas = Image(spr.width, spr.height, ColorMode.RGB)
for _, id in ipairs(order) do
  local y = rows[id] * 32
  for f = 0, 3 do canvas:drawImage(arts[id], Point(f * 32, y)) end
  local sl = spr:newSlice(Rectangle(0, y, 128, 32))
  sl.name = names[id] or id
  sl.color = Color { r = 166, g = 255, b = 110 }
end
spr:newCel(layer, 1, canvas, Point(0, 0))
spr:saveAs(P.out .. "/" .. (P.prefix or "block_art_proposals") .. "_sheet.aseprite")
spr:saveCopyAs(P.out .. "/" .. (P.prefix or "block_art_proposals") .. "_sheet_preview.png")
spr:close()

-- the overview: every proposal at 2x, 6 per row, a slice with its name
local COLS, CELL = 9, 80
local nrows = math.ceil(#order / COLS)
local ov = Sprite(COLS * CELL, nrows * CELL, ColorMode.RGB)
local prop = ov.layers[1]
prop.name = "Proposals (2x)"
local bg = ov:newLayer()
bg.name = "Backdrop"
bg.stackIndex = 1
local back = Image(ov.width, ov.height, ColorMode.RGB)
back:clear(hex("#3a3a46"))
for i, id in ipairs(order) do
  local cx, cy = ((i - 1) % COLS) * CELL, math.floor((i - 1) / COLS) * CELL
  for y = 0, 63 do for x = 0, 63 do back:drawPixel(cx + 8 + x, cy + 8 + y, hex(((x // 8 + y // 8) % 2 == 0) and "#4a4a58" or "#42424e")) end end
end
ov:newCel(bg, 1, back, Point(0, 0))
local big = Image(ov.width, ov.height, ColorMode.RGB)
for i, id in ipairs(order) do
  local cx, cy = ((i - 1) % COLS) * CELL, math.floor((i - 1) / COLS) * CELL
  local a = arts[id]
  for y = 0, 31 do
    for x = 0, 31 do
      local v = a:getPixel(x, y)
      if pc.rgbaA(v) > 0 then
        for dy = 0, 1 do for dx = 0, 1 do big:drawPixel(cx + 8 + x * 2 + dx, cy + 8 + y * 2 + dy, v) end end
      end
    end
  end
  local sl = ov:newSlice(Rectangle(cx, cy, CELL, CELL))
  sl.name = names[id] or id
end
ov:newCel(prop, 1, big, Point(0, 0))
ov:saveAs(P.out .. "/" .. (P.prefix or "block_art_proposals") .. "_overview.aseprite")
ov:saveCopyAs(P.out .. "/" .. (P.prefix or "block_art_proposals") .. "_overview_preview.png")
print("made " .. #order .. " proposals")
