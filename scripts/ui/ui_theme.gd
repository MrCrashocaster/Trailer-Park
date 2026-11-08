class_name ParkUITheme
extends RefCounted

const INK := Color("24372f")
const MUTED := Color("66736b")
const PAPER := Color("f5f1e6")
const CARD := Color("fffdf5")
const MOSS := Color("486b48")
const LIGHT_MOSS := Color("e5ecdc")
const ORANGE := Color("ba6337")
const LINE := Color("d8ddce")
const DARK := Color("22372f")

static func box(color: Color, radius: int = 9, border: Color = Color.TRANSPARENT, padding: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

static func make_theme() -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "Noto Sans", "Arial"])
	theme.default_font = font
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", INK)
	theme.set_color("default_color", "RichTextLabel", INK)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_color("font_disabled_color", "Button", Color("969e91"))
	theme.set_stylebox("normal", "Button", box(CARD, 7, LINE, 10))
	theme.set_stylebox("hover", "Button", box(LIGHT_MOSS, 7, MOSS, 10))
	theme.set_stylebox("pressed", "Button", box(Color("d0dec4"), 7, MOSS, 10))
	theme.set_stylebox("disabled", "Button", box(Color("e4e5dc"), 7, Color.TRANSPARENT, 10))
	theme.set_stylebox("focus", "Button", box(Color.TRANSPARENT, 7, ORANGE, 10))
	theme.set_stylebox("panel", "PanelContainer", box(CARD, 12, LINE, 14))
	theme.set_stylebox("normal", "LineEdit", box(Color("f0f2e9"), 7, LINE, 11))
	theme.set_stylebox("focus", "LineEdit", box(CARD, 7, MOSS, 11))
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("caret_color", "LineEdit", MOSS)
	theme.set_color("selection_color", "LineEdit", Color("b6c6a9"))
	theme.set_stylebox("normal", "OptionButton", box(CARD, 7, LINE, 10))
	theme.set_stylebox("hover", "OptionButton", box(LIGHT_MOSS, 7, MOSS, 10))
	theme.set_stylebox("pressed", "OptionButton", box(Color("d0dec4"), 7, MOSS, 10))
	theme.set_color("font_color", "OptionButton", INK)
	theme.set_stylebox("panel", "PopupMenu", box(CARD, 7, LINE, 8))
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_stylebox("hover", "PopupMenu", box(LIGHT_MOSS, 5))
	theme.set_color("font_color", "CheckButton", INK)
	theme.set_color("font_color", "CheckBox", INK)
	theme.set_constant("separation", "VBoxContainer", 9)
	theme.set_constant("separation", "HBoxContainer", 9)
	theme.set_constant("separation", "GridContainer", 8)
	theme.set_stylebox("separator", "HSeparator", box(LINE, 0, Color.TRANSPARENT, 0))
	theme.set_constant("separation", "HSeparator", 8)
	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_stylebox("normal", "PrimaryButton", box(MOSS, 7, Color.TRANSPARENT, 11))
	theme.set_stylebox("hover", "PrimaryButton", box(Color("5c7c50"), 7, Color.TRANSPARENT, 11))
	theme.set_stylebox("pressed", "PrimaryButton", box(Color("304b37"), 7, Color.TRANSPARENT, 11))
	theme.set_color("font_color", "PrimaryButton", Color.WHITE)
	theme.set_color("font_hover_color", "PrimaryButton", Color.WHITE)
	theme.set_color("font_pressed_color", "PrimaryButton", Color.WHITE)
	theme.set_type_variation("DangerButton", "Button")
	theme.set_stylebox("normal", "DangerButton", box(Color("f6e7d9"), 7, Color("d6ae90"), 10))
	theme.set_stylebox("hover", "DangerButton", box(Color("ebc9ad"), 7, ORANGE, 10))
	theme.set_color("font_color", "DangerButton", Color("853f27"))
	theme.set_type_variation("ActiveButton", "Button")
	theme.set_stylebox("normal", "ActiveButton", box(LIGHT_MOSS, 7, MOSS, 10))
	theme.set_stylebox("hover", "ActiveButton", box(Color("d5e3ca"), 7, MOSS, 10))
	theme.set_type_variation("QuietButton", "Button")
	theme.set_stylebox("normal", "QuietButton", box(Color.TRANSPARENT, 7, Color.TRANSPARENT, 8))
	theme.set_stylebox("hover", "QuietButton", box(LIGHT_MOSS, 7, Color.TRANSPARENT, 8))
	return theme
