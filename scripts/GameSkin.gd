class_name GameSkin
extends RefCounted
## Light touches on the white level screen: chunky 3D round helper buttons with a lilac
## lip and a matching result popup (gold Next, green video, lilac Retry). Only styling -
## GameScene keeps all the game logic.

const CARD_LIP := Color("#c4b5fd")
const VIOLET := Color("#7c3aed")
const VIOLET_DARK := Color("#4c1d95")
const GOLD := Color("#fbbf24")
const GOLD_LIP := Color("#b45309")
const GOLD_TEXT := Color("#7c2d12")


static func apply(game: Node) -> void:
	for node in (game.get_node("%PowerButton") as Control).get_parent().get_children():
		var b := node as Button
		if b == null:
			continue
		b.add_theme_stylebox_override("normal", box(Color("#f5f3ff"), CARD_LIP, 80, 8))
		b.add_theme_stylebox_override("hover", box(Color("#faf8ff"), CARD_LIP, 80, 8))
		b.add_theme_stylebox_override("pressed", box(Color("#f3f0ff"), CARD_LIP, 80, 3))
		b.add_theme_stylebox_override("disabled", box(Color("#e9e5f7"), Color("#d4cdee"), 80, 8))

	# Result popup.
	(game.get_node("HUD/ResultPopup/Dim") as ColorRect).color = Color(0.07, 0.03, 0.2, 0.6)
	var panel: PanelContainer = game.get_node("%ResultPanel")
	var panel_box := box(Color.WHITE, CARD_LIP, 44, 12)
	panel_box.content_margin_left = 40
	panel_box.content_margin_right = 40
	panel_box.content_margin_top = 36
	panel_box.content_margin_bottom = 40
	panel_box.shadow_color = Color(0.05, 0.0, 0.2, 0.45)
	panel_box.shadow_size = 24
	panel_box.shadow_offset = Vector2(0, 10)
	panel.add_theme_stylebox_override("panel", panel_box)
	var heavy := SystemFont.new()
	heavy.font_names = PackedStringArray(["Nunito", "Roboto", "Segoe UI", "Arial", "sans-serif"])
	heavy.font_weight = 900
	var title: Label = game.get_node("%ResultTitle")
	title.add_theme_color_override("font_color", VIOLET_DARK)
	title.add_theme_font_override("font", heavy)
	(game.get_node("%ResultMessage") as Label).add_theme_color_override("font_color", Color("#6b6a8a"))
	button_3d(game.get_node("%NextButton"), GOLD, GOLD_LIP, GOLD_TEXT, heavy)
	button_3d(game.get_node("%ContinueButton"), Color("#22c55e"), Color("#15803d"), Color.WHITE, heavy)
	button_3d(game.get_node("%RetryButton"), Color("#ede9fe"), CARD_LIP, VIOLET, heavy)


## Rounded box with a darker lip of `lip_h` pixels along the bottom.
static func box(face: Color, lip: Color, radius: int, lip_h: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = face
	b.set_corner_radius_all(radius)
	b.border_width_bottom = lip_h
	b.border_color = lip
	b.anti_aliasing = true
	b.shadow_color = Color(0.05, 0.0, 0.2, 0.25)
	b.shadow_size = 8
	b.shadow_offset = Vector2(0, 5)
	return b


## Chunky pill button whose lip squashes when pressed (like the Home buttons).
static func button_3d(b: Button, face: Color, lip: Color, ink: Color, font: Font) -> void:
	var normal := box(face, lip, 34, 9)
	normal.content_margin_bottom = 6
	# Keeps an icon (video, coin) clear of the rounded ends instead of touching the edge.
	normal.content_margin_left = 28
	normal.content_margin_right = 28
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = face.lightened(0.06)
	var down := normal.duplicate() as StyleBoxFlat
	down.border_width_bottom = 3
	down.expand_margin_top = -6.0
	down.shadow_size = 3
	for s in ["normal", "focus"]:
		b.add_theme_stylebox_override(s, normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", down)
	for s in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(s, ink)
	b.add_theme_font_override("font", font)
	add_gloss(b)


## UI kit v2: a soft white stripe across the top of a chunky button (one light source,
## top-left). It hides while the button is held down, so the press reads as "sunk".
static func add_gloss(b: Control, radius: int = 16) -> void:
	if b.has_node("Gloss"):
		return
	var g := Panel.new()
	g.name = "Gloss"
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.24)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	g.add_theme_stylebox_override("panel", box)
	g.set_anchors_preset(Control.PRESET_TOP_WIDE)
	g.offset_left = 22
	g.offset_right = -22
	g.offset_top = 6
	g.offset_bottom = 6 + 16
	b.add_child(g)
	if b is BaseButton:
		var bb := b as BaseButton
		bb.button_down.connect(func() -> void: g.visible = false)
		bb.button_up.connect(func() -> void: g.visible = true)
