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
const VIDEO_TEX := preload("res://icons/fx/ic_video.png")   # rewarded video (drawn for the buttons)
const COIN_TEX := preload("res://icons/fx/hud_coin.png")    # the HUD coin (Affinity art)


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


## Lays out a chunky button's content as ONE centred group: [icon] Text [coin price pill].
## Buttons draw an icon pinned to the left edge with the text centred on its own, which
## looks loose; this replaces both with a row in the middle. `icon` may be the old
## play_ad.svg / coin.svg (they are swapped for the drawn art). `price` >= 0 adds a dark
## pill with a coin and the amount. Call it again to change the text (see text_of()).
static func dress(b: Button, text: String, icon: Texture2D = null, price: int = -1) -> void:
	if icon:
		var path := icon.resource_path
		if path.ends_with("play_ad.svg"):
			icon = VIDEO_TEX
		elif path.ends_with("coin.svg"):
			icon = COIN_TEX
	b.text = ""
	b.icon = null
	b.set_meta("dress_text", text)
	var old := b.get_node_or_null("Content")
	if old:
		b.remove_child(old)
		old.queue_free()
	var font := b.get_theme_font("font")
	var size := b.get_theme_font_size("font_size")
	var ink := b.get_theme_color("font_color")
	var h := b.custom_minimum_size.y if b.custom_minimum_size.y > 0.0 else 90.0
	var row := HBoxContainer.new()
	row.name = "Content"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18
	row.offset_right = -18
	row.offset_bottom = -9  # sit on the face, above the lip
	b.add_child(row)
	if icon:
		var ic := TextureRect.new()
		ic.texture = icon
		ic.custom_minimum_size = Vector2.ONE * roundf(h * 0.56)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
	if text != "":
		var label := Label.new()
		label.text = text
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", size)
		label.add_theme_color_override("font_color", ink)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
	if price >= 0:
		var pill := PanelContainer.new()
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var pb := StyleBoxFlat.new()
		pb.bg_color = Color(0.25, 0.08, 0.0, 0.16) if ink.get_luminance() < 0.5 else Color(0.0, 0.0, 0.0, 0.18)
		pb.set_corner_radius_all(40)
		pb.content_margin_left = 6
		pb.content_margin_right = 16
		pb.content_margin_top = 2
		pb.content_margin_bottom = 2
		pb.anti_aliasing = true
		pill.add_theme_stylebox_override("panel", pb)
		var pr := HBoxContainer.new()
		pr.add_theme_constant_override("separation", 6)
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(pr)
		var coin := TextureRect.new()
		coin.texture = COIN_TEX
		coin.custom_minimum_size = Vector2.ONE * roundf(h * 0.46)
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pr.add_child(coin)
		var amount := Label.new()
		amount.text = str(price)
		amount.add_theme_font_override("font", font)
		amount.add_theme_font_size_override("font_size", size)
		amount.add_theme_color_override("font_color", ink)
		amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pr.add_child(amount)
		row.add_child(pill)
	# The face sinks when pressed (the lip squashes): the content goes down with it.
	if not b.has_meta("dress_wired"):
		b.set_meta("dress_wired", true)
		b.button_down.connect(func() -> void:
			var c := b.get_node_or_null("Content") as Control
			if c: c.position.y += 5)
		b.button_up.connect(func() -> void:
			var c := b.get_node_or_null("Content") as Control
			if c: c.position.y -= 5)


## The text a dressed button shows (or its own text if it was never dressed).
static func text_of(b: Button) -> String:
	return str(b.get_meta("dress_text", b.text))


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
