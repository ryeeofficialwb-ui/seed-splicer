class_name UiKit
extends RefCounted
## The pixel-art look: the UI pieces drawn in Aseprite (art/make_ui.lua -> assets/ui/*.png),
## the Pixelify Sans pixel font, and the game-wide Theme built from them.
##
## Every PNG is exported at 2x (one art pixel = 2x2 texture pixels), so 9-slice margins below
## are given in ART pixels and doubled here. Text is crisp only at whole multiples of the font's
## 13 px pixel grid. All text is 26 px (SMALL: one font pixel = 2 screen pixels, the same size as
## one art pixel of the UI) and titles 39 px (BIG); use size() to snap anything else.
##
## Type variations (set with control.theme_type_variation):
##   ShopButton      the gold button (the Shop)          DangerButton   red (Reset, Log out)
##   FlatButton      shows only on hover (title bars)     ToolbarButton  the top bar's icon buttons
##   WindowPanel     a window frame                       TitleBar       a floating window's title
##   ChipPanel       small rounded pill (HUD, weather)    ToastPanel     messages over the void
##   BubblePanel     tutorial speech bubble (gold edge)   CardBase       a card's dark body
##   TitleLabel      big green heading                    HeadingLabel   gold section heading
##   NoteLabel       small grey explanation text          DimLabel       even quieter text

const DIR := "res://assets/ui/"
const FONT_PATH := "res://assets/fonts/PixelifySans.ttf"
const PX := 2  ## texture pixels per art pixel
const GRID := 13  ## Pixelify Sans: one font pixel per 13 px of size
const SMALL := 26  ## all text
const BIG := 39    ## titles

const INK := Color("#1c1630")
const PANEL := Color("#2b2340")
const TEXT := Color("#ece8f7")
const MUTED := Color("#9a94b0")
const ACCENT := Color("#a6ff6e")
const GOLD := Color("#ffc94a")
const RED := Color("#ff8a8a")
const SHADOW := Color("#000000")  ## text outline + hard shadow: black around light text
const OUTLINE := 4  ## a black stroke around every letter
const SHADOW_OFFSET := 3  ## ...and a hard black drop shadow

static var _tex := {}
static var _font: FontFile
static var _bold: FontVariation
static var _text: FontVariation


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(DIR + name + ".png")
	return _tex[name]


## A 9-slice StyleBox from a piece. margin = the piece's corner size in art pixels;
## pad = [left, top, right, bottom] content margins in screen pixels.
static func box(name: String, margin: int, pad: Array = [8, 6, 8, 6]) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex(name)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_texture_margin(side, margin * PX)
		sb.set_content_margin(side, pad[side])
	return sb


static func font() -> FontFile:
	if _font == null:
		# the imported font resource (the raw .ttf isn't in an exported game), set up for pixels
		_font = (load(FONT_PATH) as FontFile).duplicate()
		_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_font.hinting = TextServer.HINTING_NONE
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_font.generate_mipmaps = false
	return _font


## The everyday text font: regular weight (not bold), with wider gaps between words so the black
## stroke doesn't close them up.
static func text_font() -> FontVariation:
	if _text == null:
		_text = FontVariation.new()
		_text.base_font = font()
		_text.spacing_space = 6
	return _text


static func bold_font() -> FontVariation:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = font()
		_bold.variation_opentype = { TextServerManager.get_primary_interface().name_to_tag("wght"): 700 }
		_bold.spacing_space = 6  # wider gaps between words: the black outline would close them up
	return _bold


## The nearest crisp font size (a whole multiple of 13, never below 26).
static func size(want: float) -> int:
	return maxi(2, roundi(want / GRID)) * GRID


static func _empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = text_font()
	t.default_font_size = SMALL

	# --- buttons
	var pad := [14, 6, 14, 10]       # the bottom 2 art rows are the button's shadow
	var pad_down := [14, 10, 14, 6]  # pressed: the label sinks with the button
	for cls in ["Button", "OptionButton", "ColorPickerButton", "MenuButton"]:
		t.set_stylebox("normal", cls, box("button_normal", 4, pad))
		t.set_stylebox("hover", cls, box("button_hover", 4, pad))
		t.set_stylebox("pressed", cls, box("button_pressed", 4, pad_down))
		t.set_stylebox("hover_pressed", cls, box("button_pressed", 4, pad_down))
		t.set_stylebox("disabled", cls, box("button_disabled", 4, pad))
		t.set_stylebox("focus", cls, box("button_focus", 4, pad))
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_focus_color", cls, TEXT)
		t.set_color("font_pressed_color", cls, ACCENT)
		t.set_color("font_hover_pressed_color", cls, ACCENT)
		t.set_color("font_disabled_color", cls, Color("#6c6680"))
		t.set_color("icon_normal_color", cls, Color.WHITE)
		t.set_color("icon_disabled_color", cls, Color(1, 1, 1, 0.4))
		t.set_constant("h_separation", cls, 6)
	t.set_icon("arrow", "OptionButton", tex("arrow_down"))
	t.set_constant("arrow_margin", "OptionButton", 8)

	_button_variation(t, "ShopButton", "gold", Color("#2a1806"), Color("#2a1806"))
	_button_variation(t, "DangerButton", "danger", TEXT, Color.WHITE)
	t.set_type_variation("ToolbarButton", "Button")
	t.set_stylebox("normal", "ToolbarButton", box("button_normal", 4, [8, 5, 10, 7]))
	t.set_stylebox("hover", "ToolbarButton", box("button_hover", 4, [8, 5, 10, 7]))
	t.set_stylebox("pressed", "ToolbarButton", box("button_pressed", 4, [8, 7, 10, 5]))
	t.set_stylebox("hover_pressed", "ToolbarButton", box("button_pressed", 4, [8, 7, 10, 5]))
	t.set_type_variation("FlatButton", "Button")
	t.set_stylebox("normal", "FlatButton", _empty())
	t.set_stylebox("hover", "FlatButton", box("flat_hover", 3, [6, 4, 6, 4]))
	t.set_stylebox("pressed", "FlatButton", box("flat_pressed", 3, [6, 4, 6, 4]))
	t.set_stylebox("hover_pressed", "FlatButton", box("flat_pressed", 3, [6, 4, 6, 4]))
	t.set_stylebox("focus", "FlatButton", _empty())

	# --- check boxes / radios: just the pixel box, a row highlight on hover
	for cls in ["CheckBox", "CheckButton"]:
		for st in ["normal", "pressed", "hover_pressed", "disabled", "focus"]:
			t.set_stylebox(st, cls, _empty())
		t.set_stylebox("hover", cls, box("row_hover", 2, [2, 2, 4, 2]))
		t.set_icon("checked", cls, tex("check_on"))
		t.set_icon("unchecked", cls, tex("check_off"))
		t.set_icon("checked_disabled", cls, tex("check_on"))
		t.set_icon("unchecked_disabled", cls, tex("check_off"))
		t.set_icon("radio_checked", cls, tex("radio_on"))
		t.set_icon("radio_unchecked", cls, tex("radio_off"))
		t.set_icon("radio_checked_disabled", cls, tex("radio_on"))
		t.set_icon("radio_unchecked_disabled", cls, tex("radio_off"))
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, TEXT)
		t.set_color("font_hover_pressed_color", cls, Color.WHITE)
		t.set_color("font_focus_color", cls, TEXT)
		t.set_constant("h_separation", cls, 6)
	t.set_icon("checked", "PopupMenu", tex("check_on"))
	t.set_icon("unchecked", "PopupMenu", tex("check_off"))
	t.set_icon("radio_checked", "PopupMenu", tex("radio_on"))
	t.set_icon("radio_unchecked", "PopupMenu", tex("radio_off"))

	# --- text fields
	for cls in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", cls, box("inset", 3, [8, 6, 8, 6]))
		t.set_stylebox("focus", cls, box("inset_focus", 3, [8, 6, 8, 6]))
		t.set_stylebox("read_only", cls, box("inset", 3, [8, 6, 8, 6]))
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_placeholder_color", cls, Color("#6c6680"))
		t.set_color("caret_color", cls, ACCENT)
		t.set_color("selection_color", cls, Color(ACCENT, 0.3))
		t.set_constant("caret_width", cls, 2)

	# --- lists and trees
	t.set_stylebox("panel", "ItemList", box("inset", 3, [4, 4, 4, 4]))
	t.set_stylebox("focus", "ItemList", _empty())
	t.set_stylebox("hovered", "ItemList", box("row_hover", 2, [4, 2, 4, 2]))
	t.set_stylebox("hovered_selected", "ItemList", box("row_selected", 2, [4, 2, 4, 2]))
	t.set_stylebox("selected", "ItemList", box("row_selected", 2, [4, 2, 4, 2]))
	t.set_stylebox("selected_focus", "ItemList", box("row_selected", 2, [4, 2, 4, 2]))
	t.set_stylebox("hovered_selected_focus", "ItemList", box("row_selected", 2, [4, 2, 4, 2]))
	t.set_stylebox("cursor", "ItemList", _empty())
	t.set_stylebox("cursor_unfocused", "ItemList", _empty())
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_hovered_color", "ItemList", Color.WHITE)
	t.set_color("font_selected_color", "ItemList", ACCENT)
	t.set_color("guide_color", "ItemList", Color(0, 0, 0, 0))
	t.set_stylebox("panel", "Tree", box("inset", 3, [4, 4, 4, 4]))
	t.set_stylebox("focus", "Tree", _empty())
	t.set_stylebox("selected", "Tree", box("row_selected", 2, [4, 2, 4, 2]))
	t.set_stylebox("selected_focus", "Tree", box("row_selected", 2, [4, 2, 4, 2]))
	t.set_stylebox("hovered", "Tree", box("row_hover", 2, [4, 2, 4, 2]))
	t.set_stylebox("cursor", "Tree", _empty())
	t.set_stylebox("cursor_unfocused", "Tree", _empty())
	t.set_stylebox("title_button_normal", "Tree", box("titlebar", 3, [6, 4, 6, 4]))
	t.set_stylebox("title_button_hover", "Tree", box("titlebar", 3, [6, 4, 6, 4]))
	t.set_stylebox("title_button_pressed", "Tree", box("titlebar", 3, [6, 4, 6, 4]))
	t.set_icon("arrow", "Tree", tex("arrow_down"))
	t.set_icon("arrow_collapsed", "Tree", tex("arrow_right"))
	t.set_icon("checked", "Tree", tex("check_on"))
	t.set_icon("unchecked", "Tree", tex("check_off"))
	t.set_color("font_color", "Tree", TEXT)
	t.set_color("font_selected_color", "Tree", ACCENT)
	t.set_color("guide_color", "Tree", Color(0, 0, 0, 0))
	t.set_color("relationship_line_color", "Tree", Color("#3b3150"))

	# --- panels and windows
	t.set_stylebox("panel", "PanelContainer", box("panel", 4, [12, 12, 12, 12]))
	t.set_stylebox("panel", "Panel", box("panel", 4, [12, 12, 12, 12]))
	for v in [["WindowPanel", "window", 5, [16, 14, 16, 16]], ["TitleBar", "titlebar", 3, [10, 4, 4, 4]],
			["TopBar", "titlebar", 3, [10, 8, 10, 10]],
			["ChipPanel", "chip", 4, [8, 4, 10, 4]], ["ToastPanel", "toast", 5, [14, 10, 14, 10]],
			["BubblePanel", "bubble", 5, [16, 14, 16, 14]], ["CardBase", "card_base", 5, [8, 8, 8, 8]]]:
		t.set_type_variation(v[0], "PanelContainer")
		t.set_stylebox("panel", v[0], box(v[1], v[2], v[3]))
	t.set_stylebox("panel", "PopupPanel", box("panel", 4, [8, 8, 8, 8]))
	t.set_stylebox("panel", "PopupMenu", box("panel", 4, [6, 6, 6, 6]))
	t.set_stylebox("hover", "PopupMenu", box("row_selected", 2, [4, 2, 4, 2]))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", ACCENT)
	t.set_stylebox("separator", "PopupMenu", box("sep_h", 1, [0, 2, 0, 2]))
	t.set_stylebox("panel", "AcceptDialog", box("window", 5, [16, 14, 16, 16]))
	t.set_stylebox("embedded_border", "Window", box("window", 5, [6, 30, 6, 6]))
	t.set_stylebox("embedded_unfocused_border", "Window", box("window", 5, [6, 30, 6, 6]))
	t.set_color("title_color", "Window", ACCENT)
	t.set_font("title_font", "Window", text_font())
	t.set_font_size("title_font_size", "Window", SMALL)
	t.set_constant("title_height", "Window", 40)
	t.set_icon("close", "Window", tex("icon_close"))
	t.set_icon("close_pressed", "Window", tex("icon_close"))

	# --- tabs
	for cls in ["TabContainer", "TabBar"]:
		t.set_stylebox("tab_selected", cls, box("tab_selected", 3, [12, 6, 12, 6]))
		t.set_stylebox("tab_unselected", cls, box("tab_unselected", 3, [12, 6, 12, 6]))
		t.set_stylebox("tab_hovered", cls, box("tab_hover", 3, [12, 6, 12, 6]))
		t.set_stylebox("tab_disabled", cls, box("tab_unselected", 3, [12, 6, 12, 6]))
		t.set_stylebox("tab_focus", cls, _empty())
		t.set_color("font_selected_color", cls, ACCENT)
		t.set_color("font_unselected_color", cls, MUTED)
		t.set_color("font_hovered_color", cls, TEXT)
	t.set_stylebox("panel", "TabContainer", box("tab_panel", 3, [10, 10, 10, 10]))

	# --- scrollbars, sliders, separators
	t.set_stylebox("scroll", "VScrollBar", box("scroll_track", 2, [5, 4, 5, 4]))
	t.set_stylebox("scroll_focus", "VScrollBar", box("scroll_track", 2, [5, 4, 5, 4]))
	t.set_stylebox("grabber", "VScrollBar", box("scroll_grab", 3))
	t.set_stylebox("grabber_highlight", "VScrollBar", box("scroll_grab_hover", 3))
	t.set_stylebox("grabber_pressed", "VScrollBar", box("scroll_grab_pressed", 3))
	t.set_stylebox("scroll", "HScrollBar", box("hscroll_track", 2, [4, 5, 4, 5]))
	t.set_stylebox("scroll_focus", "HScrollBar", box("hscroll_track", 2, [4, 5, 4, 5]))
	t.set_stylebox("grabber", "HScrollBar", box("hscroll_grab", 3))
	t.set_stylebox("grabber_highlight", "HScrollBar", box("hscroll_grab_hover", 3))
	t.set_stylebox("grabber_pressed", "HScrollBar", box("hscroll_grab_pressed", 3))
	for cls in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", cls, box("slider_track", 2, [0, 6, 0, 6]))
		t.set_stylebox("grabber_area", cls, box("slider_fill", 2, [0, 6, 0, 6]))
		t.set_stylebox("grabber_area_highlight", cls, box("slider_fill", 2, [0, 6, 0, 6]))
		t.set_icon("grabber", cls, tex("slider_grab"))
		t.set_icon("grabber_highlight", cls, tex("slider_grab"))
	t.set_stylebox("separator", "HSeparator", box("sep_h", 1, [0, 0, 0, 0]))
	t.set_stylebox("separator", "VSeparator", box("sep_v", 1, [0, 0, 0, 0]))
	t.set_constant("separation", "HSeparator", 8)
	t.set_constant("separation", "VSeparator", 8)

	# --- tooltips and text
	t.set_stylebox("panel", "TooltipPanel", box("tooltip", 3, [10, 6, 10, 6]))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_color("font_color", "Label", TEXT)
	# a hard drop shadow one font pixel down and right (crisp, no blur): text stays readable over
	# the starry void, the weather and light panels
	for cls in ["Label", "RichTextLabel"]:
		t.set_color("font_shadow_color", cls, SHADOW)
		t.set_constant("shadow_offset_x", cls, SHADOW_OFFSET)
		t.set_constant("shadow_offset_y", cls, SHADOW_OFFSET)
		t.set_constant("shadow_outline_size", cls, OUTLINE)
	# a black outline around light text everywhere (the gold Shop button's dark text has none)
	for cls in ["Label", "RichTextLabel", "Button", "OptionButton", "ColorPickerButton", "MenuButton", "CheckBox",
			"CheckButton", "LineEdit", "TextEdit", "ItemList", "Tree", "TabBar", "TabContainer", "PopupMenu",
			"TooltipLabel", "Window", "DangerButton", "ToolbarButton", "FlatButton"]:
		t.set_color("font_outline_color", cls, SHADOW)
		t.set_constant("outline_size", cls, OUTLINE)
	t.set_constant("title_outline_size", "Window", OUTLINE)
	t.set_constant("outline_size", "ShopButton", 0)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("normal_font", "RichTextLabel", text_font())
	t.set_font("bold_font", "RichTextLabel", bold_font())
	t.set_font_size("normal_font_size", "RichTextLabel", SMALL)
	t.set_font_size("bold_font_size", "RichTextLabel", SMALL)
	_label_variation(t, "TitleLabel", BIG, ACCENT)
	_label_variation(t, "HeadingLabel", SMALL, GOLD)
	_label_variation(t, "NoteLabel", SMALL, Color("#d8d3ea"))
	_label_variation(t, "DimLabel", SMALL, Color("#aea8c6"))
	return t


static func _button_variation(t: Theme, type: String, piece: String, color: Color, hover_color: Color) -> void:
	t.set_type_variation(type, "Button")
	t.set_stylebox("normal", type, box(piece + "_normal", 4, [14, 6, 14, 10]))
	t.set_stylebox("hover", type, box(piece + "_hover", 4, [14, 6, 14, 10]))
	t.set_stylebox("pressed", type, box(piece + "_pressed", 4, [14, 10, 14, 6]))
	t.set_stylebox("hover_pressed", type, box(piece + "_pressed", 4, [14, 10, 14, 6]))
	t.set_color("font_color", type, color)
	t.set_color("font_hover_color", type, hover_color)
	t.set_color("font_focus_color", type, color)
	t.set_color("font_pressed_color", type, color)
	t.set_color("font_hover_pressed_color", type, color)
	t.set_color("font_shadow_color", type, Color(0, 0, 0, 0))


static func _label_variation(t: Theme, type: String, font_size: int, color: Color) -> void:
	t.set_type_variation(type, "Label")
	t.set_font_size("font_size", type, font_size)
	t.set_color("font_color", type, color)


## A small TextureRect showing a kit piece at a whole zoom (2 = the PNG's own size).
static func icon(name: String, tip := "") -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(name)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.tooltip_text = tip
	r.mouse_filter = Control.MOUSE_FILTER_PASS if tip != "" else Control.MOUSE_FILTER_IGNORE
	return r
