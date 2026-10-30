extends Control
## Candy-Crush style level map: a winding road climbs from level 1 at the bottom
## through five themed worlds. Finished levels wear their stars, the player's pin
## stands on the newest level and hops forward (stars pop, node bursts) after wins.
## Top bar: total stars, streak, Options. Floating Daily button, big Play button.

const GAME_SCENE := "res://scenes/GameScene.tscn"
const DAILY_SCENE := "res://scenes/Daily.tscn"
const STAR_TEXTURE := preload("res://icons/star.svg")
const BANNER_ART := preload("res://icons/fx/map_banner.png")
const DECO_CLOUD := preload("res://icons/fx/deco_cloud.png")
const DECO := {
	"tree": [preload("res://icons/fx/deco_tree.png"), preload("res://icons/fx/deco_pine.png"), preload("res://icons/fx/deco_bush.png"),
		preload("res://icons/fx/deco_mushroom.png"), preload("res://icons/fx/deco_rock.png")],
	"bubble": [preload("res://icons/fx/deco_palm.png"), preload("res://icons/fx/deco_shell.png"), preload("res://icons/fx/deco_rock.png")],
	"candy": [preload("res://icons/fx/deco_lollipop.png"), preload("res://icons/fx/deco_cane.png"), preload("res://icons/fx/deco_castle.png")],
	"cactus": [preload("res://icons/fx/deco_cactus.png"), preload("res://icons/fx/deco_pyramid.png"), preload("res://icons/fx/deco_rock.png")],
	"space": [preload("res://icons/fx/deco_planet.png"), preload("res://icons/fx/deco_crystal.png")],
}
const STAR_ON := Color("#fbbf24")
const STAR_OFF := Color(0.39, 0.45, 0.55, 0.45)

const SPACING := 150.0          # vertical distance between two road slots
const TOP_PAD := 360.0
const BOTTOM_PAD := 400.0
const NODE := 96.0
const NODE_CURRENT := 116.0
const LEVELS_PER_WORLD := 20
const WORLDS: Array[Dictionary] = [
	{"name": "Sunny Meadow", "low": Color("#ecfccb"), "high": Color("#bbf7d0"), "accent": Color("#16a34a"), "deco": "tree"},
	{"name": "Bubble Bay", "low": Color("#e0f2fe"), "high": Color("#a5d8fb"), "accent": Color("#0284c7"), "deco": "bubble"},
	{"name": "Arrowland", "low": Color("#fce7f3"), "high": Color("#f9c4e1"), "accent": Color("#db2777"), "deco": "candy"},
	{"name": "Sunset Dunes", "low": Color("#ffedd5"), "high": Color("#fdc28c"), "accent": Color("#ea580c"), "deco": "cactus"},
	{"name": "Star Galaxy", "low": Color("#3b2f8f"), "high": Color("#140f3a"), "accent": Color("#7c3aed"), "deco": "space"},
	{"name": "Snake Jungle", "low": Color("#d1fae5"), "high": Color("#6ee7b7"), "accent": Color("#047857"), "deco": "tree"},
]
const CONFETTI: Array[Color] = [Color("#f59e0b"), Color("#ef4444"), Color("#22c55e"), Color("#3b82f6"), Color("#ec4899")]

var _w := 720.0
var _h := 0.0
var _cx := 360.0
var _amp := 190.0
var _current := 1
var _buttons := {}              # level -> Button
var _stars := {}                # level -> Array of star TextureRects
var _scroll: ScrollContainer
var _map: Control
var _pin: Control
var _pin_body: Control
var _scrolled_at := -10000      # msec of the last scroll move (a drag must not open a level)
var _quiver_label: Label        # top bar: arrows in the quiver + refill countdown


func _ready() -> void:
	GameData.daily_day = -1  # back to normal levels
	GameData.set_music_pitch(1.02)
	_current = clampi(GameData.unlocked_level, 1, GameData.MAX_LEVELS)
	var seen := GameData.map_seen_level
	var hop_from := seen if seen >= 1 and seen < _current else 0
	GameData.map_seen_level = _current

	_w = get_viewport_rect().size.x
	_cx = _w * 0.5
	_amp = minf(_w * 0.27, 200.0)
	_h = TOP_PAD + _slot(GameData.MAX_LEVELS) * SPACING + BOTTOM_PAD
	_build_map()
	_build_top_bar()
	_build_daily_button()
	_build_play_button()

	await get_tree().process_frame
	await get_tree().process_frame
	if hop_from > 0:
		_hop(hop_from)
	else:
		_scroll.scroll_vertical = _scroll_target(_current)
		_pin.position = _pin_spot(_current)
		_start_pulse(_current)
	_check_streak()


# --- Road geometry -----------------------------------------------------------------------

## Road slot of a level; every new world leaves one empty slot for its banner.
func _slot(level: int) -> float:
	return float(level - 1 + (level - 1) / LEVELS_PER_WORLD)


func _road(u: float) -> Vector2:
	return Vector2(_cx + _amp * sin(u * 0.95), _h - BOTTOM_PAD - u * SPACING)


func _u_at(y: float) -> float:
	return (_h - BOTTOM_PAD - y) / SPACING


func _node_pos(level: int) -> Vector2:
	return _road(_slot(level))


## Road slot of the banner that opens world `w` (0-based).
func _banner_slot(w: int) -> float:
	return -1.0 if w == 0 else _slot(w * LEVELS_PER_WORLD + 1) - 1.0


func _world_of(level: int) -> int:
	return clampi((level - 1) / LEVELS_PER_WORLD, 0, WORLDS.size() - 1)


func _pin_spot(level: int) -> Vector2:
	return _node_pos(level) - Vector2(0, NODE_CURRENT * 0.5 + 62)


func _scroll_target(level: int) -> int:
	return int(_node_pos(level).y - _scroll.size.y * 0.58)


# --- Map ---------------------------------------------------------------------------------

func _build_map() -> void:
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	_scroll.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void:
		_scrolled_at = Time.get_ticks_msec())

	_map = Control.new()
	_map.custom_minimum_size = Vector2(_w, _h)
	_map.mouse_filter = Control.MOUSE_FILTER_PASS
	_map.draw.connect(_draw_map)
	_scroll.add_child(_map)
	for n in range(1, GameData.MAX_LEVELS + 1):
		_add_level_button(n)
	_pin = _make_pin()
	_map.add_child(_pin)


func _add_level_button(n: int) -> void:
	var done := GameData.best_stars(n) > 0 or n < GameData.unlocked_level
	var is_current := n == _current
	var locked := n > GameData.unlocked_level
	var s := NODE_CURRENT if is_current else NODE
	var b := Button.new()
	b.text = str(n)
	b.size = Vector2(s, s)
	b.position = _node_pos(n) - b.size * 0.5
	b.pivot_offset = b.size * 0.5
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	# 3D pedestal art from Affinity: world-coloured (white art tinted), gold for the
	# current level, stone with a padlock for locked ones.
	b.size = Vector2(s * 1.3, s * 1.17)
	b.position = _node_pos(n) - Vector2(b.size.x * 0.5, b.size.y * 0.41)
	b.pivot_offset = b.size * Vector2(0.5, 0.41)
	var art := "map_node_current" if is_current else ("map_node_locked" if locked else "map_node")
	var up := StyleBoxTexture.new()
	up.texture = load("res://icons/fx/%s.png" % art)
	if not is_current and not locked:
		up.modulate_color = WORLDS[_world_of(n)].accent.lightened(0.1)
	up.content_margin_bottom = b.size.y * 0.24
	var down := up.duplicate() as StyleBoxTexture
	down.modulate_color = up.modulate_color.darkened(0.15)
	for state in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, up)
	b.add_theme_stylebox_override("pressed", down)
	if locked:
		b.text = ""
	var text_color := Color("#7c2d12") if is_current else Color.WHITE
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, text_color)
	b.add_theme_color_override("font_outline_color", Color("#fde68a") if is_current else Color(0, 0, 0, 0.35))
	b.add_theme_constant_override("outline_size", 6 if is_current else 10)
	b.add_theme_font_size_override("font_size", 46 if is_current else 38)

	var tier := LevelGenerator.tier_for_difficulty(GameData.difficulty_for(n))
	if tier >= LevelGenerator.Tier.HARD:
		_add_tag(b, tier)
	if done and not is_current:
		_add_stars(b, n)
	b.pressed.connect(_on_level_pressed.bind(n))
	_map.add_child(b)
	_buttons[n] = b


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


## "HARD" / "SUPER HARD" pill under the node.
func _add_tag(b: Button, tier: int) -> void:
	var tag := Label.new()
	var super_hard := tier >= LevelGenerator.Tier.SUPER_HARD
	tag.text = "SUPER HARD" if super_hard else "HARD"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 17)
	tag.add_theme_color_override("font_color", Color.WHITE)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#dc2626") if super_hard else Color("#f97316")
	box.set_corner_radius_all(12)
	box.border_color = Color.WHITE
	box.set_border_width_all(2)
	tag.add_theme_stylebox_override("normal", box)
	var tw := 136.0 if super_hard else 76.0
	tag.size = Vector2(tw, 28)
	tag.position = Vector2((b.size.x - tw) * 0.5, b.size.y - 12)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(tag)


## Three stars in a little arc above a finished node.
func _add_stars(b: Button, n: int) -> void:
	var count := GameData.best_stars(n)
	var list: Array = []
	for i in 3:
		var star := TextureRect.new()
		star.texture = STAR_TEXTURE
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var big := 36.0 if i == 1 else 30.0
		star.size = Vector2(big, big)
		star.pivot_offset = star.size * 0.5
		star.position = Vector2(b.size.x * 0.5 + (i - 1) * 32 - big * 0.5, -big * 0.5 - (14.0 if i == 1 else 4.0))
		star.modulate = STAR_ON if i < count else STAR_OFF
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(star)
		list.append(star)
	_stars[n] = list


func _make_pin() -> Control:
	var pin := Control.new()
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pin_body = Control.new()
	_pin_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.add_child(_pin_body)
	var pin_art := TextureRect.new()
	pin_art.texture = preload("res://icons/fx/map_pin.png")
	pin_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pin_art.size = Vector2(112, 144)
	pin_art.position = Vector2(-56, -54)
	pin_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pin_body.add_child(pin_art)
	var face := TextureRect.new()
	face.texture = preload("res://icons/fx/mascot_happy.png")
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.size = Vector2(84, 84)
	face.position = Vector2(-42, -48)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pin_body.add_child(face)
	var bob := _pin_body.create_tween().set_loops()
	bob.tween_property(_pin_body, "position:y", -12.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_pin_body, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return pin


func _start_pulse(n: int) -> void:
	var b: Button = _buttons[n]
	var pulse := b.create_tween().set_loops()
	pulse.tween_property(b, "scale", Vector2(1.08, 1.08), 0.55).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(b, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE)


# --- Drawing -----------------------------------------------------------------------------

func _draw_map() -> void:
	_draw_background()
	for w in WORLDS.size():
		_draw_world_deco(w)
	_draw_road()
	var glow := _node_pos(_current)
	_map.draw_circle(glow, 86, Color(1, 0.88, 0.3, 0.35))
	_map.draw_circle(glow, 72, Color(1, 1, 1, 0.45))
	for w in WORLDS.size():
		_draw_banner(_road(_banner_slot(w)).y, "WORLD %d  -  %s" % [w + 1, WORLDS[w].name], WORLDS[w].accent)
	var top := _road(_slot(GameData.MAX_LEVELS) + 1.4).y
	_draw_banner(top, "More levels coming soon!", Color("#f59e0b"))


## Soft vertical gradients per world, blended across each banner.
func _draw_background() -> void:
	var stops: Array = [[_h, WORLDS[0].low]]
	for w in WORLDS.size():
		if w < WORLDS.size() - 1:
			var y := _road(_banner_slot(w + 1)).y
			stops.append([y + 170.0, WORLDS[w].high])
			stops.append([y - 170.0, WORLDS[w + 1].low])
		else:
			stops.append([0.0, WORLDS[w].high])
	for i in stops.size() - 1:
		var y0: float = stops[i][0]
		var y1: float = stops[i + 1][0]
		var c0: Color = stops[i][1]
		var c1: Color = stops[i + 1][1]
		_map.draw_polygon(
			PackedVector2Array([Vector2(0, y1), Vector2(_w, y1), Vector2(_w, y0), Vector2(0, y0)]),
			PackedColorArray([c1, c1, c0, c0]))


func _draw_road() -> void:
	var start := -1.4
	var finish := _slot(GameData.MAX_LEVELS) + 1.4
	var reached := _slot(_current)
	var pts := PackedVector2Array()
	var shadow := PackedVector2Array()
	var done_pts := PackedVector2Array()
	var u := start
	while u <= finish:
		var p := _road(u)
		pts.append(p)
		shadow.append(p + Vector2(0, 8))
		if u <= reached:
			done_pts.append(p)
		u += 0.08
	_map.draw_polyline(shadow, Color(0, 0, 0, 0.12), 70, true)
	var side := PackedVector2Array()
	for p in pts:
		side.append(p + Vector2(0, 12))
	_map.draw_polyline(side, Color("#d6a85c"), 66, true)  # the road's thickness (3D edge)
	_map.draw_polyline(pts, Color.WHITE, 62, true)
	_map.draw_polyline(pts, Color("#fef3c7"), 46, true)
	if done_pts.size() > 1:
		_map.draw_polyline(done_pts, Color("#fcd34d"), 46, true)
	# Dotted centre line between the nodes.
	u = start
	while u <= finish:
		var frac := u - floorf(u)
		if frac > 0.28 and frac < 0.72:
			var col := Color("#d97706") if u < reached else Color(0, 0, 0, 0.13)
			_map.draw_circle(_road(u), 5, col)
		u += 0.14


func _draw_banner(y: float, text: String, color: Color) -> void:
	var bw := minf(_w - 60.0, 460.0)
	var rect := Rect2(_cx - bw * 0.5, y - 34, bw, 68)
	# Ribbon banner from Affinity, tinted in the world colour (art is 560 x 140).
	var art_w := bw + 110.0
	var art_h := art_w * 140.0 / 560.0
	_map.draw_texture_rect(BANNER_ART, Rect2(_cx - art_w * 0.5, y - art_h * 0.48, art_w, art_h), false, color)
	var font := _map.get_theme_default_font()
	var base := Vector2(rect.position.x, y + 10)
	_map.draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_CENTER, bw, 28, 6, Color(0, 0, 0, 0.18))
	_map.draw_string(font, base, text, HORIZONTAL_ALIGNMENT_CENTER, bw, 28, Color.WHITE)


## 3D decorations from Affinity scattered beside the road (drawn back to front so nearer
## pieces overlap farther ones), clouds drifting over, stars in the space worlds.
func _draw_world_deco(w: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + w * 97
	var bottom := _h if w == 0 else _road(_banner_slot(w)).y
	var top := 0.0 if w == WORLDS.size() - 1 else _road(_banner_slot(w + 1)).y
	var kind: String = WORLDS[w].deco
	var pieces: Array = []
	if kind == "space":
		for k in 120:
			_map.draw_circle(Vector2(rng.randf_range(10, _w - 10), rng.randf_range(top, bottom)), rng.randf_range(1.5, 4.0), Color(1, 1, 1, rng.randf_range(0.35, 1.0)))
	for k in 30:
		var p := Vector2(rng.randf_range(40, _w - 40), rng.randf_range(top + 80, bottom - 40))
		var sc := rng.randf_range(0.5, 0.78)
		if absf(p.x - _road(_u_at(p.y)).x) < 120.0 * sc + 60.0:
			continue
		var list: Array = DECO[kind]
		var tex: Texture2D = DECO_CLOUD if rng.randf() < 0.12 and kind != "space" else list[rng.randi() % list.size()]
		pieces.append([p, sc, tex])
	pieces.sort_custom(func(x: Array, y: Array) -> bool: return x[0].y < y[0].y)
	for piece: Array in pieces:
		var p: Vector2 = piece[0]
		var sz := Vector2(200, 220) * float(piece[1])
		_map.draw_texture_rect(piece[2], Rect2(p - Vector2(sz.x * 0.5, sz.y * 0.92), sz), false)


func _draw_cloud(p: Vector2, s: float) -> void:
	var c := Color(1, 1, 1, 0.85)
	_map.draw_circle(p, 26 * s, c)
	_map.draw_circle(p + Vector2(-28, 8) * s, 18 * s, c)
	_map.draw_circle(p + Vector2(28, 8) * s, 20 * s, c)


func _draw_tree(p: Vector2, s: float) -> void:
	_map.draw_rect(Rect2(p + Vector2(-6, 0) * s, Vector2(12, 46) * s), Color("#a16207"))
	_map.draw_circle(p + Vector2(-17, 8) * s, 20 * s, Color("#15803d"))
	_map.draw_circle(p + Vector2(17, 8) * s, 20 * s, Color("#16a34a"))
	_map.draw_circle(p + Vector2(0, -10) * s, 28 * s, Color("#22c55e"))
	_map.draw_circle(p + Vector2(-8, -18) * s, 8 * s, Color(1, 1, 1, 0.25))


func _draw_flowers(p: Vector2, s: float, rng: RandomNumberGenerator) -> void:
	for i in 3:
		var q := p + Vector2(i * 22 - 22, rng.randf_range(-8, 8)) * s
		var col := CONFETTI[(i + rng.randi()) % CONFETTI.size()]
		for a in 5:
			_map.draw_circle(q + Vector2.from_angle(a * TAU / 5.0) * 7 * s, 5 * s, col)
		_map.draw_circle(q, 4 * s, Color("#fef08a"))


func _draw_bubbles(p: Vector2, s: float) -> void:
	for b in [[Vector2.ZERO, 18.0], [Vector2(24, -26), 11.0], [Vector2(-14, -40), 7.0]]:
		var q: Vector2 = p + b[0] * s
		var r: float = b[1] * s
		_map.draw_circle(q, r, Color(1, 1, 1, 0.25))
		_map.draw_arc(q, r, 0, TAU, 28, Color(1, 1, 1, 0.9), 3, true)
		_map.draw_circle(q + Vector2(-r, -r) * 0.35, r * 0.22, Color.WHITE)


func _draw_wave(p: Vector2, s: float) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		pts.append(p + Vector2(i * 6 - 36, sin(i * 0.9) * 7) * s)
	_map.draw_polyline(pts, Color("#38bdf8"), 5 * s, true)


func _draw_lollipop(p: Vector2, s: float, col: Color) -> void:
	_map.draw_line(p, p + Vector2(0, 52) * s, Color.WHITE, 7 * s, true)
	_map.draw_circle(p, 25 * s, col)
	_map.draw_arc(p, 15 * s, 0, TAU * 0.8, 24, Color(1, 1, 1, 0.85), 5 * s, true)
	_map.draw_arc(p, 6 * s, 0, TAU * 0.8, 16, Color(1, 1, 1, 0.85), 4 * s, true)


func _draw_cactus(p: Vector2, s: float) -> void:
	var green := Color("#65a30d")
	var w := 18 * s
	_map.draw_line(p + Vector2(0, 30) * s, p + Vector2(0, -30) * s, green, w)
	_map.draw_circle(p + Vector2(0, -30) * s, w * 0.5, green)
	_map.draw_polyline(PackedVector2Array([p + Vector2(0, 2) * s, p + Vector2(-22, 2) * s, p + Vector2(-22, -18) * s]), green, 12 * s)
	_map.draw_circle(p + Vector2(-22, -18) * s, 6 * s, green)
	_map.draw_polyline(PackedVector2Array([p + Vector2(0, 12) * s, p + Vector2(20, 12) * s, p + Vector2(20, -6) * s]), green, 12 * s)
	_map.draw_circle(p + Vector2(20, -6) * s, 6 * s, green)
	_map.draw_circle(p + Vector2(0, 34) * s, 14 * s, Color("#fdba74"))


func _draw_planet(p: Vector2, s: float, col: Color) -> void:
	_map.draw_circle(p, 24 * s, col)
	_map.draw_circle(p + Vector2(-8, -8) * s, 8 * s, Color(1, 1, 1, 0.3))
	var ring := PackedVector2Array()
	for i in 33:
		var a := i * TAU / 32.0
		ring.append(p + Vector2(cos(a) * 42, sin(a) * 11).rotated(-0.35) * s)
	_map.draw_polyline(ring, Color(1, 1, 1, 0.7), 3, true)


# --- Overlay UI --------------------------------------------------------------------------

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, 132)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.94)
	box.corner_radius_bottom_left = 36
	box.corner_radius_bottom_right = 36
	box.shadow_color = Color(0, 0, 0, 0.14)
	box.shadow_size = 10
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 30 + GameData.safe_insets().x
	box.content_margin_bottom = 14
	bar.add_theme_stylebox_override("panel", box)
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)
	var home := Button.new()
	home.custom_minimum_size = Vector2(72, 72)
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
	var quiver := _chip("res://icons/quiver.svg", Color.WHITE, "", Color("#b45309"))
	_quiver_label = quiver.get_child(0).get_child(1)
	row.add_child(quiver)
	row.add_child(_chip("res://icons/star.svg", STAR_ON, str(total), Color("#b45309")))
	var spacer := Control.new()  # the quiver chip took the title's place
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_update_quiver)
	add_child(timer)
	_update_quiver()
	row.add_child(_chip("res://icons/flame.svg", Color.WHITE, str(GameData.streak), Color("#ea580c")))
	var gear := Button.new()
	gear.icon = load("res://icons/gear.svg")
	gear.custom_minimum_size = Vector2(76, 76)
	gear.focus_mode = Control.FOCUS_NONE
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
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#f1f5f9")
	box.set_corner_radius_all(30)
	box.content_margin_left = 10
	box.content_margin_right = 18
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	chip.add_theme_stylebox_override("panel", box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	chip.add_child(h)
	var icon := _icon(icon_path, 44)
	icon.modulate = icon_tint
	h.add_child(icon)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", text_color)
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


## Round "Daily" button floating on the left, red badge until today's maze is done.
func _build_daily_button() -> void:
	var b := Button.new()
	b.position = Vector2(22, 158 + GameData.safe_insets().x)
	b.size = Vector2(112, 112)
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
		b.pivot_offset = b.size * 0.5
		var wiggle := b.create_tween().set_loops()
		wiggle.tween_interval(2.2)
		wiggle.tween_property(b, "rotation", 0.12, 0.08)
		wiggle.tween_property(b, "rotation", -0.12, 0.12)
		wiggle.tween_property(b, "rotation", 0.0, 0.08)
	b.pressed.connect(func() -> void:
		GameData.play_sfx("tap")
		get_tree().change_scene_to_file(DAILY_SCENE))
	add_child(b)


func _build_play_button() -> void:
	var b := Button.new()
	b.text = "PLAY  LEVEL %d" % _current
	b.add_theme_font_size_override("font_size", 40)
	# Gold PLAY art from Affinity (same as Home), stretched in the middle only.
	var up := StyleBoxTexture.new()
	up.texture = preload("res://icons/fx/home_play.png")
	var down := StyleBoxTexture.new()
	down.texture = preload("res://icons/fx/home_play_down.png")
	for sb: StyleBoxTexture in [up, down]:
		sb.texture_margin_left = 80
		sb.texture_margin_right = 80
		sb.texture_margin_top = 40
		sb.texture_margin_bottom = 50
		sb.content_margin_top = 8
		sb.content_margin_bottom = 30
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, up)
	b.add_theme_stylebox_override("pressed", down)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, Color("#7c2d12"))
	var heavy := SystemFont.new()
	heavy.font_names = PackedStringArray(["Nunito", "Roboto", "Segoe UI", "Arial", "sans-serif"])
	heavy.font_weight = 900
	b.add_theme_font_override("font", heavy)
	b.focus_mode = Control.FOCUS_NONE
	b.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	b.offset_left = -240
	b.offset_right = 240
	b.offset_top = -156 - GameData.safe_insets().y
	b.offset_bottom = -46 - GameData.safe_insets().y
	b.pivot_offset = Vector2(240, 55)
	b.pressed.connect(_start_level.bind(_current))
	add_child(b)
	var breathe := b.create_tween().set_loops()
	breathe.tween_property(b, "scale", Vector2(1.04, 1.04), 0.8).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(b, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)


# --- Win celebration ---------------------------------------------------------------------

## Back from winning: stars pop on the finished nodes, then the pin hops node by
## node up the road to the new level, which bursts open.
func _hop(from: int) -> void:
	_scroll.scroll_vertical = _scroll_target(from)
	_pin.position = _pin_spot(from)
	var fresh: Button = _buttons[_current]
	fresh.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_interval(0.35)
	for n in range(from, _current):
		for star in _stars.get(n, []):
			star.scale = Vector2.ZERO
			tw.tween_callback(GameData.play_sfx.bind("star"))
			tw.tween_property(star, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for n in range(from, _current):
		tw.tween_callback(GameData.play_sfx.bind("slide"))
		tw.tween_method(_pin_hop.bind(_pin_spot(n), _pin_spot(n + 1)), 0.0, 1.0, 0.42) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(_scroll, "scroll_vertical", _scroll_target(n + 1), 0.42) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		GameData.play_sfx("charge")
		GameData.vibrate(30)
		_burst(_node_pos(_current)))
	tw.tween_property(fresh, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_start_pulse.bind(_current))


func _pin_hop(t: float, a: Vector2, b: Vector2) -> void:
	_pin.position = a.lerp(b, t) + Vector2(0, -sin(t * PI) * 70.0)


func _burst(at: Vector2) -> void:
	for i in 16:
		var bit := ColorRect.new()
		bit.color = CONFETTI[i % CONFETTI.size()]
		bit.size = Vector2(14, 14)
		bit.pivot_offset = Vector2(7, 7)
		bit.position = at - bit.pivot_offset
		bit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_map.add_child(bit)
		var dir := Vector2.from_angle(i * TAU / 16.0 + randf() * 0.3)
		var t := bit.create_tween().set_parallel()
		t.tween_property(bit, "position", bit.position + dir * randf_range(80, 140), 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(bit, "rotation", randf_range(-6, 6), 0.6)
		t.tween_property(bit, "modulate:a", 0.0, 0.6).set_delay(0.2)
		t.chain().tween_callback(bit.queue_free)


# --- Actions -----------------------------------------------------------------------------

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
		var x := b.position.x
		var shake := b.create_tween()
		for dx in [-10.0, 10.0, -6.0, 6.0, 0.0]:
			shake.tween_property(b, "position:x", x + dx, 0.05)
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
