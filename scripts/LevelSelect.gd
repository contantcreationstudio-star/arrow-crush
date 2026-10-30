extends Control
## Level map: one card per world (25 worlds x 20 levels). Each card has a coloured
## header (world name, progress, Affinity props peeking over the edge) and a 5 x 4 grid
## of chunky level tiles: finished tiles in the world colour with their stars, the
## current level in gold (pulsing, with the mascot), locked ones grey with a padlock.
## Worlds more than one ahead stay folded ("Unlocks at level N") - something to look
## forward to, and a light page even with 500 levels.
## Top bar: back, quiver, total stars, streak, Options. Bottom: Daily + big PLAY.

const GAME_SCENE := "res://scenes/GameScene.tscn"
const DAILY_SCENE := "res://scenes/Daily.tscn"
const STAR_TEXTURE := preload("res://icons/star.svg")
const FLAME := preload("res://icons/flame.svg")
const TITLE_FONT := preload("res://theme/fonts/LuckiestGuy-Regular.ttf")
const MASCOT := preload("res://icons/fx/mascot_happy.png")
const DECO_CLOUD := preload("res://icons/fx/deco_cloud.png")
const DECO := {
	"tree": [preload("res://icons/fx/deco_tree.png"), preload("res://icons/fx/deco_pine.png"), preload("res://icons/fx/deco_bush.png"),
		preload("res://icons/fx/deco_mushroom.png")],
	"bubble": [preload("res://icons/fx/deco_palm.png"), preload("res://icons/fx/deco_shell.png"), preload("res://icons/fx/deco_rock.png")],
	"candy": [preload("res://icons/fx/deco_lollipop.png"), preload("res://icons/fx/deco_cane.png"), preload("res://icons/fx/deco_castle.png")],
	"cactus": [preload("res://icons/fx/deco_cactus.png"), preload("res://icons/fx/deco_pyramid.png"), preload("res://icons/fx/deco_rock.png")],
	"space": [preload("res://icons/fx/deco_planet.png"), preload("res://icons/fx/deco_crystal.png")],
}
const STAR_ON := Color("#fbbf24")
const STAR_OFF := Color(0.39, 0.45, 0.55, 0.35)
const INK := Color("#3b0764")
const GOLD := Color("#fbbf24")
const GOLD_LIP := Color("#b45309")
const GOLD_TEXT := Color("#7c2d12")
const COLS := 5
const TOP_PAD := 168.0       # under the top bar
const BOTTOM_PAD := 200.0    # above the bottom dock
const BAR_H := 128.0         # top bar height (plus the safe area)
const DOCK_H := 168.0        # bottom dock height (plus the safe area)
const BAR_FACE := Color("#6d28d9")
const BAR_LIP := Color("#4c1d95")
const SIDE := 22.0
const CONFETTI: Array[Color] = [Color("#f59e0b"), Color("#ef4444"), Color("#22c55e"), Color("#3b82f6"), Color("#ec4899")]

var _w := 720.0
var _current := 1
var _buttons := {}              # level -> Button (only worlds that are unfolded)
var _stars := {}                # level -> Array of star TextureRects
var _scroll: ScrollContainer
var _list: VBoxContainer
var _scrolled_at := -10000      # msec of the last scroll move (a drag must not open a level)
var _quiver_label: Label        # top bar: arrows in the quiver + refill countdown
var _heavy: SystemFont


func _ready() -> void:
	GameData.daily_day = -1  # back to normal levels
	GameData.set_music_pitch(1.02)
	_current = clampi(GameData.unlocked_level, 1, GameData.MAX_LEVELS)
	var seen := GameData.map_seen_level
	var hop_from := seen if seen >= 1 and seen < _current else 0
	GameData.map_seen_level = _current
	_w = get_viewport_rect().size.x
	_heavy = SystemFont.new()
	_heavy.font_names = PackedStringArray(["Nunito", "Roboto", "Segoe UI", "Arial", "sans-serif"])
	_heavy.font_weight = 900

	_build_background()
	_build_map()
	_build_top_bar()
	_build_dock()

	# Wait for the cards to be laid out before scrolling to the current level.
	for i in 10:
		await get_tree().process_frame
		if _list.size.y > 0.0:
			break
	await get_tree().process_frame
	_scroll.scroll_vertical = _scroll_target(_current)
	if hop_from > 0:
		_hop(hop_from)
	else:
		_start_pulse(_current)
	_check_streak()


# --- Map -------------------------------------------------------------------------------------

func _build_background() -> void:
	var g := Gradient.new()
	g.set_color(0, Color("#f5f3ff"))
	g.set_color(1, Color("#e0e7ff"))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var bg := TextureRect.new()
	bg.texture = tex
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Faint arrow pattern, so the page isn't a flat colour.
	var pattern := Control.new()
	pattern.set_anchors_preset(Control.PRESET_FULL_RECT)
	pattern.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pattern.draw.connect(func() -> void:
		var sz := pattern.size
		var ink := Color(0.49, 0.23, 0.93, 0.05)
		var y := 40.0
		var row := 0
		while y < sz.y:
			var x := 30.0 + (row % 2) * 70.0
			while x < sz.x:
				var p := Vector2(x, y)
				pattern.draw_line(p - Vector2(22, 0), p + Vector2(14, 0), ink, 6.0, true)
				pattern.draw_colored_polygon(PackedVector2Array([p + Vector2(26, 0), p + Vector2(8, -13), p + Vector2(8, 13)]), ink)
				x += 140.0
			y += 90.0
			row += 1)
	add_child(pattern)


func _build_map() -> void:
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	_scroll.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void:
		_scrolled_at = Time.get_ticks_msec())
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_top", int(TOP_PAD + GameData.safe_insets().x))
	margin.add_theme_constant_override("margin_bottom", int(BOTTOM_PAD + GameData.safe_insets().y))
	margin.add_theme_constant_override("margin_left", int(SIDE))
	margin.add_theme_constant_override("margin_right", int(SIDE))
	_scroll.add_child(margin)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 46)
	margin.add_child(_list)
	var last_world := Worlds.of(GameData.MAX_LEVELS)
	var open_until := mini(Worlds.of(_current) + 1, last_world)
	for w in last_world + 1:
		_list.add_child(_world_card(w, w <= open_until))
	_list.add_child(_soon_card())


## One world: the coloured header and (when unfolded) its grid of level tiles.
func _world_card(w: int, unfolded: bool) -> Control:
	var info: Dictionary = Worlds.LIST[w]
	var first := Worlds.first_level(w)
	var last := mini(first + Worlds.LEVELS_PER_WORLD - 1, GameData.MAX_LEVELS)
	var reached := _current >= first
	var card := PanelContainer.new()
	var box := GameSkin.box(Color.WHITE, Color("#ddd6fe"), 40, 10)
	box.shadow_color = Color(0.2, 0.05, 0.45, 0.16)
	box.shadow_size = 16
	box.shadow_offset = Vector2(0, 8)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 18
	box.content_margin_bottom = 26
	card.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	card.add_child(col)
	col.add_child(_world_header(w, info, first, last, reached))
	if unfolded:
		var grid := GridContainer.new()
		grid.columns = COLS
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 18)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(grid)
		var tile := floorf((_w - SIDE * 2.0 - 36.0 - 14.0 * (COLS - 1)) / COLS)
		for n in range(first, last + 1):
			grid.add_child(_level_tile(n, w, tile))
	else:
		var lock_row := HBoxContainer.new()
		lock_row.alignment = BoxContainer.ALIGNMENT_CENTER
		lock_row.add_theme_constant_override("separation", 12)
		var padlock := _padlock(Color("#94a3b8"))
		padlock.custom_minimum_size = Vector2(40, 44)
		lock_row.add_child(padlock)
		lock_row.add_child(_text("Unlocks at level %d" % first, 28, Color("#64748b"), _heavy))
		col.add_child(lock_row)
	if not reached:
		card.modulate = Color(1, 1, 1, 0.92)
	return card


func _world_header(w: int, info: Dictionary, first: int, last: int, reached: bool) -> Control:
	var head := Control.new()
	head.custom_minimum_size = Vector2(0, 168)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top: Color = info.top if reached else Color("#cbd5e1")
	var bottom: Color = info.bottom if reached else Color("#64748b")
	# Lip under the face (3D edge).
	var lip := Panel.new()
	var lip_box := StyleBoxFlat.new()
	lip_box.set_corner_radius_all(30)
	lip_box.anti_aliasing = true
	lip_box.bg_color = bottom.darkened(0.3)
	lip.add_theme_stylebox_override("panel", lip_box)
	lip.set_anchors_preset(Control.PRESET_FULL_RECT)
	lip.offset_top = 8
	lip.offset_bottom = 8
	lip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(lip)
	# Face: a rounded panel that clips a vertical gradient and a gloss band.
	var face := Panel.new()
	var face_box := StyleBoxFlat.new()
	face_box.set_corner_radius_all(30)
	face_box.anti_aliasing = true
	face_box.bg_color = bottom
	face.add_theme_stylebox_override("panel", face_box)
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(face)
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.2, 0)
	gt.fill_to = Vector2(0.4, 1)
	var fill := TextureRect.new()
	fill.texture = gt
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(fill)
	var gloss := Panel.new()
	var gloss_box := StyleBoxFlat.new()
	gloss_box.set_corner_radius_all(22)
	gloss_box.anti_aliasing = true
	gloss_box.bg_color = Color(1, 1, 1, 0.2)
	gloss.add_theme_stylebox_override("panel", gloss_box)
	gloss.set_anchors_preset(Control.PRESET_TOP_WIDE)
	gloss.offset_left = 16
	gloss.offset_right = -16
	gloss.offset_top = 10
	gloss.offset_bottom = 42
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(gloss)
	# Affinity props peeking over the right edge (seeded per world, always the same).
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + w * 31
	var list: Array = DECO[info.deco]
	for k in 2:
		var prop := TextureRect.new()
		prop.texture = list[(w + k) % list.size()]
		prop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		prop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		var s := 150.0 if k == 0 else 108.0
		prop.size = Vector2(s, s * 1.1)
		prop.position = Vector2(_w - SIDE * 2.0 - 36.0 - s - (12.0 if k == 0 else 128.0), -s * 0.38 + rng.randf_range(-6, 10))
		prop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not reached:
			prop.modulate = Color(0.75, 0.78, 0.84)
		head.add_child(prop)
	# Texts.
	var tag := _text("WORLD %d" % (w + 1), 24, Color(1, 1, 1, 0.85), _heavy)
	tag.position = Vector2(28, 18)
	head.add_child(tag)
	var title := _text(String(info.name), 46, Color.WHITE, TITLE_FONT)
	title.add_theme_color_override("font_outline_color", bottom.darkened(0.45))
	title.add_theme_constant_override("outline_size", 10)
	title.position = Vector2(26, 46)
	head.add_child(title)
	# Progress: stars won / possible, and a bar of levels done.
	var done := clampi(_current - first, 0, last - first + 1)
	var star_sum := 0
	for n in range(first, last + 1):
		star_sum += GameData.best_stars(n)
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 6)
	chip.position = Vector2(28, 112)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var star := TextureRect.new()
	star.texture = STAR_TEXTURE
	star.modulate = STAR_ON
	star.custom_minimum_size = Vector2(32, 32)
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chip.add_child(star)
	chip.add_child(_text("%d/%d" % [star_sum, (last - first + 1) * 3], 26, Color.WHITE, _heavy))
	head.add_child(chip)
	var bar := Control.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = Vector2(170, 120)
	bar.size = Vector2(220, 22)
	var frac := done / float(last - first + 1)
	bar.draw.connect(func() -> void:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(11)
		sb.anti_aliasing = true
		sb.bg_color = Color(0, 0, 0, 0.22)
		bar.draw_style_box(sb, Rect2(Vector2.ZERO, bar.size))
		if frac > 0.0:
			sb.bg_color = GOLD
			bar.draw_style_box(sb, Rect2(Vector2.ZERO, Vector2(maxf(22.0, bar.size.x * frac), bar.size.y))))
	head.add_child(bar)
	var count := _text("%d/%d" % [done, last - first + 1], 24, Color.WHITE, _heavy)
	count.position = Vector2(402, 113)
	head.add_child(count)
	return head


## A chunky level tile.
func _level_tile(n: int, w: int, size: float) -> Button:
	var done := n < _current
	var is_current := n == _current
	var locked := n > _current
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size * 1.08)
	b.pivot_offset = b.custom_minimum_size * 0.5
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	var accent: Color = Worlds.LIST[w].accent
	var face := accent.lightened(0.08)
	var lip := accent.darkened(0.3)
	var ink := Color.WHITE
	if is_current:
		face = GOLD
		lip = GOLD_LIP
		ink = GOLD_TEXT
	elif locked:
		face = Color("#eef2f7")
		lip = Color("#cbd5e1")
		ink = Color("#94a3b8")
	var up := GameSkin.box(face, lip, 28, 9)
	up.shadow_size = 6
	up.shadow_offset = Vector2(0, 4)
	up.shadow_color = Color(0.15, 0.05, 0.35, 0.18)
	var down := up.duplicate() as StyleBoxFlat
	down.border_width_bottom = 3
	down.expand_margin_top = -6.0
	for st in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, up)
	b.add_theme_stylebox_override("pressed", down)
	if not locked:
		GameSkin.add_gloss(b, 12)
		var num := _text(str(n), 40 if n < 100 else 34, ink, TITLE_FONT)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num.set_anchors_preset(Control.PRESET_FULL_RECT)
		num.offset_bottom = -26.0 if done else -8.0
		num.offset_top = 4.0
		num.add_theme_color_override("font_outline_color", lip.darkened(0.2) if not is_current else Color("#fde68a"))
		num.add_theme_constant_override("outline_size", 6 if not is_current else 4)
		b.add_child(num)
	else:
		var padlock := _padlock(Color("#b6c2d2"))
		padlock.size = Vector2(36, 40)
		padlock.position = (b.custom_minimum_size - padlock.size) * 0.5 - Vector2(0, 4)
		b.add_child(padlock)
	if done:
		_add_stars(b, n)
	if is_current:
		var face_icon := TextureRect.new()
		face_icon.texture = MASCOT
		face_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face_icon.size = Vector2(52, 52)
		face_icon.position = Vector2(b.custom_minimum_size.x - 34, -20)
		face_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(face_icon)
	# The hard beats (every 5th level, super hard every 10th): a small flame in the
	# corner - only on those, so the page stays calm.
	var spike := GameData.level_spike(n)
	if spike > 0.0 and not is_current:
		var fire := TextureRect.new()
		fire.texture = FLAME
		fire.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fire.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fire.size = Vector2(34, 34) if n % 10 == 0 else Vector2(28, 28)
		fire.position = Vector2(-8, -10)
		fire.modulate = Color("#ef4444") if n % 10 == 0 else Color("#fb923c")
		if locked:
			fire.modulate.a = 0.55
		fire.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(fire)
	b.pressed.connect(_on_level_pressed.bind(n))
	_buttons[n] = b
	return b


## Three small stars along the bottom of a finished tile.
func _add_stars(b: Button, n: int) -> void:
	var count := GameData.best_stars(n)
	var list: Array = []
	var sz := b.custom_minimum_size
	for i in 3:
		var star := TextureRect.new()
		star.texture = STAR_TEXTURE
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var big := 26.0 if i == 1 else 22.0
		star.size = Vector2(big, big)
		star.pivot_offset = star.size * 0.5
		star.position = Vector2(sz.x * 0.5 + (i - 1) * 24 - big * 0.5, sz.y - 38.0 - (3.0 if i == 1 else 0.0))
		star.modulate = STAR_ON if i < count else Color(1, 1, 1, 0.4)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(star)
		list.append(star)
	_stars[n] = list


## A little padlock drawn in code (body + shackle).
func _padlock(color: Color) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var s := c.size
		var body := Rect2(0, s.y * 0.42, s.x, s.y * 0.58)
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(int(s.x * 0.2))
		sb.anti_aliasing = true
		c.draw_style_box(sb, body)
		c.draw_arc(Vector2(s.x * 0.5, s.y * 0.42), s.x * 0.3, PI, TAU, 16, color, s.x * 0.14, true)
		c.draw_circle(body.get_center() - Vector2(0, 2), s.x * 0.1, color.darkened(0.3)))
	return c


func _soon_card() -> Control:
	var card := PanelContainer.new()
	var box := GameSkin.box(Color("#fef3c7"), Color("#fcd34d"), 36, 8)
	box.content_margin_top = 26
	box.content_margin_bottom = 30
	card.add_theme_stylebox_override("panel", box)
	var t := _text("More worlds coming soon!", 34, GOLD_TEXT, TITLE_FONT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(t)
	return card


func _text(s: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _scroll_target(level: int) -> int:
	var b: Button = _buttons.get(level)
	if b == null:
		return 0
	# The tile's place in the scrolled content (independent of the current scroll).
	var content := _list.get_parent() as Control
	var y := b.get_global_rect().position.y - content.get_global_rect().position.y
	return maxi(0, int(y - _scroll.size.y * 0.42))


func _start_pulse(n: int) -> void:
	var b: Button = _buttons.get(n)
	if b == null:
		return
	var pulse := b.create_tween().set_loops()
	pulse.tween_property(b, "scale", Vector2(1.07, 1.07), 0.55).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(b, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE)


# --- Overlay UI ------------------------------------------------------------------------------

func _build_top_bar() -> void:
	# Solid violet bar like the in-game header: a lip along the bottom, a soft shadow on
	# the cards below, so nothing shows through it while the map scrolls.
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = BAR_H + GameData.safe_insets().x
	var box := StyleBoxFlat.new()
	box.bg_color = BAR_FACE
	box.corner_radius_bottom_left = 36
	box.corner_radius_bottom_right = 36
	box.border_width_bottom = 8
	box.border_color = BAR_LIP
	box.shadow_color = Color(0.2, 0.05, 0.45, 0.3)
	box.shadow_size = 14
	box.shadow_offset = Vector2(0, 4)
	box.anti_aliasing = true
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 22 + GameData.safe_insets().x
	box.content_margin_bottom = 14
	bar.add_theme_stylebox_override("panel", box)
	bar.z_index = 5
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(row)
	var home := Button.new()
	home.custom_minimum_size = Vector2(76, 76)
	home.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # square art: never stretched by the row
	home.focus_mode = Control.FOCUS_NONE
	var hup := StyleBoxTexture.new()
	hup.texture = preload("res://icons/fx/btn_back.png")
	var hdown := StyleBoxTexture.new()
	hdown.texture = preload("res://icons/fx/btn_back_down.png")
	for st in ["normal", "hover", "focus"]:
		home.add_theme_stylebox_override(st, hup)
	home.add_theme_stylebox_override("pressed", hdown)
	home.pressed.connect(func() -> void:
		GameData.play_sfx("tap")
		get_tree().change_scene_to_file("res://scenes/Home.tscn"))
	row.add_child(home)

	var total := 0
	for n in GameData.stars:
		total += int(GameData.stars[n])
	var quiver := _chip("res://icons/quiver.svg", Color.WHITE, "", Color.WHITE)
	_quiver_label = quiver.get_child(0).get_child(1)
	row.add_child(quiver)
	row.add_child(_chip("res://icons/star.svg", STAR_ON, str(total), Color.WHITE))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_update_quiver)
	add_child(timer)
	_update_quiver()
	row.add_child(_chip("res://icons/flame.svg", Color.WHITE, str(GameData.streak), Color.WHITE))
	var gear := Button.new()
	gear.icon = load("res://icons/gear.svg")
	gear.expand_icon = true
	gear.add_theme_constant_override("icon_max_width", 40)
	gear.custom_minimum_size = Vector2(68, 68)
	gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gear.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear.focus_mode = Control.FOCUS_NONE
	# A round white key with a lilac lip (the gear art is dark, so it sits on white).
	var gear_box := GameSkin.box(Color.WHITE, Color("#c4b5fd"), 34, 6)
	gear_box.shadow_size = 0
	var gear_down := gear_box.duplicate() as StyleBoxFlat
	gear_down.border_width_bottom = 2
	for st in ["normal", "hover", "focus"]:
		gear.add_theme_stylebox_override(st, gear_box)
	gear.add_theme_stylebox_override("pressed", gear_down)
	gear.pressed.connect(func() -> void:
		GameData.play_sfx("tap")
		OptionsScreen.open(self))
	row.add_child(gear)


## "4  12:05": arrows in the quiver and the time until the next one ("5" when full).
func _update_quiver() -> void:
	var wait := GameData.quiver_wait()
	_quiver_label.text = str(GameData.quiver) if wait <= 0 else "%d  %s" % [GameData.quiver, GameData.clock_text(wait)]


func _chip(icon_path: String, icon_tint: Color, text: String, text_color: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# A dark glass pill on the violet bar.
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.12, 0.02, 0.3, 0.38)
	box.set_corner_radius_all(30)
	box.anti_aliasing = true
	box.content_margin_left = 10
	box.content_margin_right = 18
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	chip.add_theme_stylebox_override("panel", box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	chip.add_child(h)
	var icon := _icon(icon_path, 40)
	icon.modulate = icon_tint
	h.add_child(icon)
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _heavy)
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", text_color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(label)
	return chip


func _icon(path: String, size: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(path)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _circle(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(80)
	box.shadow_color = Color(0, 0, 0, 0.22)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 6)
	box.anti_aliasing = true
	return box


## The bottom dock: a solid white tray (rounded top, shadow up onto the map) holding the
## round Daily button and the big gold PLAY, side by side.
func _build_dock() -> void:
	var dock := PanelContainer.new()
	dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_top = -(DOCK_H + GameData.safe_insets().y)
	var box := StyleBoxFlat.new()
	box.bg_color = Color.WHITE
	box.corner_radius_top_left = 40
	box.corner_radius_top_right = 40
	box.shadow_color = Color(0.2, 0.05, 0.45, 0.2)
	box.shadow_size = 18
	box.shadow_offset = Vector2(0, -4)
	box.anti_aliasing = true
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 18
	box.content_margin_bottom = 22 + GameData.safe_insets().y
	dock.add_theme_stylebox_override("panel", box)
	dock.z_index = 5
	add_child(dock)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	dock.add_child(row)
	row.add_child(_build_daily_button())
	row.add_child(_build_play_button())


## Round "Daily" button; red badge until today's maze is done.
func _build_daily_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(112, 112)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pivot_offset = Vector2(56, 56)
	b.focus_mode = Control.FOCUS_NONE
	var normal := _circle(Color.WHITE, Color("#93c5fd"), 6)
	for state in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(state, normal)
	b.add_theme_stylebox_override("pressed", _circle(Color("#eff6ff"), Color("#60a5fa"), 6))
	var icon := _icon("res://icons/calendar.svg", 58)
	icon.position = Vector2(27, 16)
	icon.size = Vector2(58, 58)
	b.add_child(icon)
	var label := Label.new()
	label.text = "Daily"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color("#1e3a8a"))
	label.size = Vector2(112, 28)
	label.position = Vector2(0, 72)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(label)
	if not GameData.daily_done.has(GameData.utc_day()):
		var badge := Label.new()
		badge.text = "!"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 24)
		badge.add_theme_color_override("font_color", Color.WHITE)
		badge.add_theme_stylebox_override("normal", _circle(Color("#ef4444"), Color.WHITE, 3))
		badge.size = Vector2(36, 36)
		badge.position = Vector2(80, -4)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
		var wiggle := b.create_tween().set_loops()
		wiggle.tween_interval(2.2)
		wiggle.tween_property(b, "rotation", 0.12, 0.08)
		wiggle.tween_property(b, "rotation", -0.12, 0.12)
		wiggle.tween_property(b, "rotation", 0.0, 0.08)
	b.pressed.connect(func() -> void:
		GameData.play_sfx("tap")
		get_tree().change_scene_to_file(DAILY_SCENE))
	return b


func _build_play_button() -> Button:
	var b := Button.new()
	b.text = "PLAY  %d" % _current
	b.add_theme_font_size_override("font_size", 42)
	# Gold PLAY art from Affinity (same as Home), stretched in the middle only.
	var up := StyleBoxTexture.new()
	up.texture = preload("res://icons/fx/home_play.png")
	var down := StyleBoxTexture.new()
	down.texture = preload("res://icons/fx/home_play_down.png")
	# The art (640 x 160, chevrons near both ends) is scaled as a whole, never 9-sliced:
	# slicing cut through the chevrons and left broken "beaks" on the edges.
	for sb: StyleBoxTexture in [up, down]:
		sb.content_margin_top = 0
		sb.content_margin_bottom = 22
	# Pressed art sits lower (its lip squashed): the text goes down with it.
	down.content_margin_top = 12
	down.content_margin_bottom = 10
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, up)
	b.add_theme_stylebox_override("pressed", down)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, GOLD_TEXT)
	b.add_theme_font_override("font", TITLE_FONT)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(464, 116)  # exactly the art's 4:1 shape
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.pressed.connect(_start_level.bind(_current))
	var breathe := b.create_tween().set_loops()
	breathe.tween_property(b, "scale", Vector2(1.03, 1.03), 0.8).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(b, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)
	return b


# --- Win celebration -------------------------------------------------------------------------

## Back from winning: the stars pop onto the tiles just finished, then the new level's
## tile bursts open in gold.
func _hop(from: int) -> void:
	var fresh: Button = _buttons.get(_current)
	if fresh:
		fresh.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_interval(0.35)
	for n in range(from, _current):
		for star in _stars.get(n, []):
			star.scale = Vector2.ZERO
			tw.tween_callback(GameData.play_sfx.bind("star"))
			tw.tween_property(star, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if fresh == null:
		return
	tw.tween_callback(func() -> void:
		GameData.play_sfx("charge")
		GameData.vibrate(30)
		_burst(fresh.get_global_rect().get_center()))
	tw.tween_property(fresh, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_start_pulse.bind(_current))


func _burst(at: Vector2) -> void:
	for i in 16:
		var bit := ColorRect.new()
		bit.color = CONFETTI[i % CONFETTI.size()]
		bit.size = Vector2(14, 14)
		bit.pivot_offset = Vector2(7, 7)
		bit.position = at - bit.pivot_offset
		bit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bit)
		var dir := Vector2.from_angle(i * TAU / 16.0 + randf() * 0.3)
		var t := bit.create_tween().set_parallel()
		t.tween_property(bit, "position", bit.position + dir * randf_range(80, 140), 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(bit, "rotation", randf_range(-6, 6), 0.6)
		t.tween_property(bit, "modulate:a", 0.0, 0.6).set_delay(0.2)
		t.chain().tween_callback(bit.queue_free)


# --- Actions ---------------------------------------------------------------------------------

## Missed a day? Offer to save the streak with a video (or tell the player it ended).
func _check_streak() -> void:
	var info := GameData.check_streak()
	if not info.is_empty():
		StreakPopup.show_broken(self, info).closed.connect(get_tree().reload_current_scene)


func _on_level_pressed(n: int) -> void:
	if Time.get_ticks_msec() - _scrolled_at < 200:
		return  # the finger was dragging the map
	if n > GameData.unlocked_level:
		GameData.play_sfx("thud")
		GameData.vibrate(20)
		var b: Button = _buttons[n]
		var shake := b.create_tween()
		for r: float in [-0.12, 0.12, -0.07, 0.07, 0.0]:
			shake.tween_property(b, "rotation", r, 0.05)
		return
	_start_level(n)


## Opens level `n` - unless it costs a quiver arrow and the quiver is empty.
func _start_level(n: int) -> void:
	GameData.play_sfx("tap")
	GameData.refresh_quiver()
	if GameData.level_costs_arrow(n, false) and GameData.quiver <= 0:
		QuiverPopup.show_empty(self).refilled.connect(_open_level.bind(n))
		return
	_open_level(n)


func _open_level(n: int) -> void:
	GameData.daily_day = -1
	GameData.current_level = n
	get_tree().change_scene_to_file(GAME_SCENE)
