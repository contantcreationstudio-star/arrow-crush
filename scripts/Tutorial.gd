class_name Tutorial
extends CanvasLayer
## Guided lessons, spread out so a new player learns one thing at a time:
##   run()           level 1 (hand-made board, LevelGenerator.tutorial_level): tap to launch,
##                   same-colour crush, pop every balloon - then the player finishes the level.
##   lesson("bump")  level 2: a different colour in the way costs a heart.
##   lesson("hint")  level 3+, when the player gets stuck: the bulb shows a safe arrow.
##   lesson("power") level 5: Super Power smashes through a lane.
##   lesson("special", arrow)  the first time a 3+ chain makes a special arrow.
## GameScene decides when (see _maybe_lesson); each lesson is shown once.
## Everything outside the spotlight is dimmed; only the thing being taught reacts.
## Minimal on purpose: one short line per step, the bubble never covers the board
## area being taught, and the spotlight shows the tapped arrow, its path and the
## arrow it will meet, so cause and effect are both visible.

signal finished

const HAND_TEX := preload("res://icons/fx/tut_hand.png")  # made in Affinity (design/tut_hand_v2.af)
const HAND_TIP := Vector2(136, 50)   # fingertip pad inside the texture, in texture pixels
const HAND_SCALE := 0.3
const LESSONS := 3    # dots in the bubble's progress row (level 1 only)
const TITLE_FONT := preload("res://theme/fonts/LuckiestGuy-Regular.ttf")
const FACES := {
	"idle": preload("res://icons/fx/mascot_idle.png"),
	"happy": preload("res://icons/fx/mascot_happy.png"),
	"wow": preload("res://icons/fx/mascot_wow.png"),
	"worried": preload("res://icons/fx/mascot_worried.png"),
}
const PRAISE := {
	"sweet": preload("res://icons/fx/combo_sweet.png"),
	"super": preload("res://icons/fx/combo_super.png"),
	"amazing": preload("res://icons/fx/combo_amazing.png"),
}
const VIOLET := Color("#7c3aed")

## Which HUD button may be pressed right now ("" = none). GameScene checks this.
var allow := ""

var _game: Node
var _maze: MazeBoard
var _dim: Spotlight
var _hand: Hand
var _bubble: PanelContainer
var _face: TextureRect
var _title: Label
var _dots: HBoxContainer
var _text: RichTextLabel
var _ok: Button
var _skipped := false
var _step := 0     # bumps every time a new bubble shows, so late timers know they're stale
var _lesson := 0   # 1..LESSONS, for the progress dots
var _mode := "level1"   # "level1" or the single lesson being shown ("bump", "hint", ...)


## A cartoon glove that shows exactly where to tap: it slides in, presses (with a
## ripple at the fingertip), lifts, and repeats until the player does it.
class Hand extends Node2D:
	var _sprite := Sprite2D.new()
	var _ripple := -1.0          # 0..1 while a ripple is spreading, -1 = none
	var _tween: Tween

	func _init() -> void:
		_sprite.texture = HAND_TEX
		_sprite.centered = false
		_sprite.offset = -HAND_TIP   # the node's origin is the fingertip
		_sprite.scale = Vector2.ONE * HAND_SCALE
		add_child(_sprite)
		visible = false

	## Loop a tap on `target`. Near the bottom of the screen the glove reaches down
	## from above instead, so it never hangs off the screen.
	func tap_at(target: Vector2, view: Vector2) -> void:
		stop()
		position = target
		var size := HAND_TEX.get_size() * HAND_SCALE
		var from_above := target.y + size.y - HAND_TIP.y * HAND_SCALE > view.y - 8.0
		var sy := -1.0 if from_above else 1.0
		var rest := Vector2(HAND_SCALE, HAND_SCALE * sy)
		var pressed := rest * 0.86
		var approach := Vector2(46.0, 60.0 * sy)
		visible = true
		_sprite.scale = rest
		_sprite.position = approach
		_sprite.modulate.a = 0.0
		_tween = create_tween().set_loops()
		_tween.tween_property(_sprite, "position", Vector2.ZERO, 0.38) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(_sprite, "modulate:a", 1.0, 0.22)
		for i in 2:   # double press: reads as "tap here", not "drag"
			_tween.tween_property(_sprite, "scale", pressed, 0.1).set_trans(Tween.TRANS_SINE)
			_tween.parallel().tween_property(_sprite, "position", Vector2(3.0, 5.0 * sy), 0.1)
			_tween.tween_callback(func() -> void: _ripple = 0.0)
			_tween.tween_property(_sprite, "scale", rest, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(_sprite, "position", Vector2.ZERO, 0.16)
			_tween.tween_interval(0.14)
		_tween.tween_interval(0.45)
		_tween.tween_property(_sprite, "modulate:a", 0.0, 0.22)
		_tween.parallel().tween_property(_sprite, "position", approach * 0.6, 0.22)
		_tween.tween_interval(0.25)

	func stop() -> void:
		if _tween:
			_tween.kill()
			_tween = null
		_ripple = -1.0
		visible = false
		queue_redraw()

	func _process(delta: float) -> void:
		if _ripple >= 0.0:
			_ripple += delta / 0.5
			if _ripple > 1.0:
				_ripple = -1.0
			queue_redraw()

	func _draw() -> void:
		if _ripple < 0.0:
			return
		var p := _ripple
		draw_circle(Vector2.ZERO, 16.0 * (1.0 - p), Color(1, 1, 1, 0.55 * (1.0 - p)), true, -1.0, true)
		draw_arc(Vector2.ZERO, 14.0 + 34.0 * p, 0.0, TAU, 48, Color(1, 0.86, 0.35, 0.95 * (1.0 - p)), 5.0, true)
		draw_arc(Vector2.ZERO, 8.0 + 20.0 * p, 0.0, TAU, 40, Color(1, 1, 1, 0.9 * (1.0 - p)), 3.0, true)


## A full-screen dim with a rounded, softly glowing hole, plus marching chevrons that
## show which way the arrow will fly.
class Spotlight extends Control:
	const RADIUS := 18.0
	var hole := Rect2()
	var lane_a := Vector2.ZERO   # path from the arrow head ...
	var lane_b := Vector2.ZERO   # ... to where it ends up (equal = no path shown)
	var _t := 0.0
	var _ring := StyleBoxFlat.new()

	func _init() -> void:
		_ring.draw_center = false
		_ring.set_corner_radius_all(int(RADIUS))
		_ring.set_border_width_all(4)
		_ring.border_color = Color("#fde68a")
		_ring.shadow_color = Color(1.0, 0.78, 0.2, 0.5)
		_ring.anti_aliasing = true

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var view := get_viewport_rect().size
		var shade := Color(0.04, 0.03, 0.14, 0.68)
		if hole.size == Vector2.ZERO:
			draw_rect(Rect2(Vector2.ZERO, view), shade)
			return
		var h := hole
		draw_rect(Rect2(0, 0, view.x, h.position.y), shade)
		draw_rect(Rect2(0, h.end.y, view.x, view.y - h.end.y), shade)
		draw_rect(Rect2(0, h.position.y, h.position.x, h.size.y), shade)
		draw_rect(Rect2(h.end.x, h.position.y, view.x - h.end.x, h.size.y), shade)
		# Round the hole's corners by shading the little square bits outside each arc.
		for corner in [[h.position, 180.0], [Vector2(h.end.x, h.position.y), 270.0],
				[h.end, 0.0], [Vector2(h.position.x, h.end.y), 90.0]]:
			var c: Vector2 = corner[0]
			var a0: float = deg_to_rad(corner[1])
			var centre := c - Vector2(cos(a0 + PI / 4.0), sin(a0 + PI / 4.0)) * RADIUS * sqrt(2.0)
			var pts := PackedVector2Array([c])
			for i in 9:
				var a := a0 + PI / 2.0 * i / 8.0
				pts.append(centre + Vector2(cos(a), sin(a)) * RADIUS)
			draw_colored_polygon(pts, shade)
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		_ring.shadow_size = int(8.0 + 12.0 * pulse)
		_ring.border_color.a = 0.65 + 0.35 * pulse
		draw_style_box(_ring, h)
		if lane_a != lane_b:
			_draw_chevrons()

	## Gold chevrons marching from the arrow head to where it will end up.
	func _draw_chevrons() -> void:
		var length := lane_a.distance_to(lane_b)
		if length < 1.0:
			return
		var dir := (lane_b - lane_a) / length
		var side := Vector2(-dir.y, dir.x)
		var step := 30.0
		var d := fmod(_t * 55.0, step)
		while d <= length:
			var p := lane_a + dir * d
			var fade := clampf(minf(d, length - d) / 24.0 + 0.25, 0.0, 1.0)
			var pts := PackedVector2Array([p - dir * 6.0 + side * 9.0, p + dir * 5.0, p - dir * 6.0 - side * 9.0])
			draw_polyline(pts, Color(0.12, 0.08, 0.3, 0.55 * fade), 8.0, true)
			draw_polyline(pts, Color(1.0, 0.86, 0.3, fade), 4.5, true)
			d += step


func _init(game: Node, maze: MazeBoard) -> void:
	_game = game
	_maze = maze
	layer = 30
	_dim = Spotlight.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE  # taps go through to the board / buttons
	add_child(_dim)

	_hand = Hand.new()  # added after the bubble below, so it draws on top of it
	_build_bubble()
	add_child(_hand)

	var skip := Button.new()
	skip.text = "Skip"
	skip.flat = true
	skip.add_theme_font_size_override("font_size", 22)
	skip.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	# Top-right corner, below the phone's camera / notch.
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -120
	skip.offset_right = -10
	skip.offset_top = 6 + GameData.safe_insets().x
	skip.offset_bottom = 62 + GameData.safe_insets().x
	skip.pressed.connect(_skip)
	add_child(skip)


## The guide card: mascot on the left; title, progress dots, text and "Got it" on the right.
func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# White card with a chunky violet "3D" bottom edge, like the game's other panels.
	var card := StyleBoxFlat.new()
	card.bg_color = Color("#fdfcff")
	card.set_corner_radius_all(30)
	card.set_border_width_all(4)
	card.border_width_bottom = 10
	card.border_color = Color("#a78bfa")
	card.shadow_color = Color(0.05, 0.02, 0.2, 0.5)
	card.shadow_size = 22
	card.shadow_offset = Vector2(0, 10)
	card.content_margin_left = 16
	card.content_margin_right = 22
	card.content_margin_top = 16
	card.content_margin_bottom = 16
	card.anti_aliasing = true
	_bubble.add_theme_stylebox_override("panel", card)
	add_child(_bubble)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(row)
	# The mascot sits in a round lavender badge.
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var disc := StyleBoxFlat.new()
	disc.bg_color = Color("#ede9fe")
	disc.set_corner_radius_all(60)
	disc.set_border_width_all(5)
	disc.border_color = Color("#c4b5fd")
	disc.set_content_margin_all(6)
	disc.anti_aliasing = true
	badge.add_theme_stylebox_override("panel", disc)
	row.add_child(badge)
	_face = TextureRect.new()
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face.custom_minimum_size = Vector2(100, 100)
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(_face)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	# Title on a violet ribbon pill.
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill_box := StyleBoxFlat.new()
	pill_box.bg_color = VIOLET
	pill_box.set_corner_radius_all(16)
	pill_box.border_width_bottom = 4
	pill_box.border_color = Color("#5b21b6")
	pill_box.content_margin_left = 14
	pill_box.content_margin_right = 14
	pill_box.content_margin_top = 3
	pill_box.content_margin_bottom = 1
	pill_box.anti_aliasing = true
	pill.add_theme_stylebox_override("panel", pill_box)
	head.add_child(pill)
	_title = Label.new()
	_title.add_theme_font_override("font", TITLE_FONT)
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color.WHITE)
	_title.add_theme_color_override("font_shadow_color", Color(0.2, 0.05, 0.4, 0.6))
	_title.add_theme_constant_override("shadow_offset_y", 2)
	pill.add_child(_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(spacer)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 5)
	_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_dots)
	for i in LESSONS:
		var dot := Panel.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dots.add_child(dot)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(400, 0)  # fixed width so the text wraps into lines
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 25)
	_text.add_theme_font_size_override("bold_font_size", 25)
	var bold := SystemFont.new()
	bold.font_names = PackedStringArray(["Nunito", "Roboto", "Segoe UI", "Arial", "sans-serif"])
	bold.font_weight = 900
	_text.add_theme_font_override("bold_font", bold)
	_text.add_theme_color_override("default_color", Color("#1e293b"))
	col.add_child(_text)
	_ok = Button.new()
	_ok.text = "GOT IT!"
	_ok.add_theme_font_override("font", TITLE_FONT)
	_ok.add_theme_font_size_override("font_size", 26)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_ok.add_theme_color_override(state, Color.WHITE)
	for state in ["normal", "hover", "pressed", "focus"]:
		var b := StyleBoxFlat.new()
		b.bg_color = Color("#22c55e") if state != "pressed" else Color("#16a34a")
		b.set_corner_radius_all(22)
		b.border_width_bottom = 2 if state == "pressed" else 7
		b.border_color = Color("#15803d")
		b.content_margin_top = 8 if state != "pressed" else 13
		b.content_margin_bottom = 4
		b.content_margin_left = 26
		b.content_margin_right = 26
		b.anti_aliasing = true
		if state == "focus":
			b.draw_center = false
			b.border_width_bottom = 0
		_ok.add_theme_stylebox_override(state, b)
	_ok.custom_minimum_size = Vector2(180, 58)
	_ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(_ok)
	_ok.resized.connect(func() -> void: _ok.pivot_offset = _ok.size / 2.0)


func _ready() -> void:
	# A gentle "press me" pulse on the button (tweens need the node in the tree).
	var pulse := _ok.create_tween().set_loops()
	pulse.tween_property(_ok, "scale", Vector2.ONE * 1.05, 0.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_ok, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


## Sets the card's header for the next step: lesson number, title and mascot face.
func _lesson_head(n: int, title: String, face: String = "idle") -> void:
	_lesson = n
	_title.text = title
	_face.texture = FACES[face]
	_dots.visible = n > 0   # single lessons (n = 0) have no progress row
	for i in LESSONS:
		var dot: Panel = _dots.get_child(i)
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(5)
		box.bg_color = VIOLET if i == n - 1 else (Color("#c4b5fd") if i < n - 1 else Color("#e2e8f0"))
		dot.add_theme_stylebox_override("panel", box)
		dot.custom_minimum_size = Vector2(22 if i == n - 1 else 10, 10)


## Level 1: tap to launch, crush, balloons. Emits `finished` at the end (or when skipped).
func run() -> void:
	_mode = "level1"
	_lesson_head(1, "Tap to launch")
	await _arrow_step(_arrow_at("free"), "[b]Tap[/b] the glowing arrow.\nIt flies out the way it [b]points[/b]!", "exit", false, "sweet")
	if _skipped: return
	_lesson_head(2, "Crush!")
	await _arrow_step(_arrow_at("crush"), "[b]Same colour[/b] in the way?\nTap it and they [color=#7c3aed][b]CRUSH![/b][/color]", "first")  # the board shows its own CRUSH! art
	if _skipped: return
	_lesson_head(3, "Pop to win", "wow")
	await _info_step(_balloons_focus(), "Arrows [color=#e11d48][b]POP[/b][/color] balloons next to them or in their path.\n[color=#059669][b]Pop every balloon to win![/b][/color]")
	if _skipped: return
	_end()


## One later lesson (see the header). `arrow` is the special arrow for "special".
func lesson(kind: String, arrow: ArrowPath = null) -> void:
	_mode = kind
	match kind:
		"bump":
			var a := _find_bump_arrow()
			if a:
				_lesson_head(0, "Watch out", "worried")
				await _info_step(_focus(a, "first"), "A [b]different colour[/b] in the way = [color=#e11d48][b]BUMP[/b][/color].\nYou lose a heart!")
		"hint":
			_lesson_head(0, "Stuck?")
			await _button_step(_game.hint_button, "hint", "Tap the [b]bulb[/b] for a free hint!")
			if _skipped: return
			await _info_step({"rect": _game.hint_button.get_global_rect()}, "The [b]glowing arrow[/b] is safe to tap.\nMore hints? Watch a short video.", true)
		"power":
			var a := _find_power_arrow()
			if a:
				if GameData.power_charges <= 0:
					GameData.add_power(1)
					_game._refresh_hud()
				_lesson_head(0, "Super Power", "wow")
				await _button_step(_game.power_button, "power", "New power! Tap the [b]lightning[/b].")
				if _skipped: return
				await _arrow_step(a, "Now tap this arrow.\nIt [color=#7c3aed][b]SMASHES[/b][/color] through everything!", "all", true, "amazing")
				if _skipped: return
				GameData.add_power(1)  # the demo was free
				_game._refresh_hud()
		"special":
			if arrow and is_instance_valid(arrow):
				_lesson_head(0, "Special arrow!", "wow")
				await _info_step(_focus(arrow, "all"), "You cleared [b]3+ arrows[/b] in one tap and made a [color=#7c3aed][b]SPECIAL[/b][/color] arrow!\nTap it to blast its whole lane.")
	if _skipped: return
	_end()


## An arrow whose way out is blocked by a different colour (for the bump lesson).
func _find_bump_arrow() -> ArrowPath:
	for a in _maze.arrows:
		if a.busy:
			continue
		for c in a.lane_cells():
			var other: ArrowPath = _maze.occupancy.get(c)
			if other != null and other != a:
				if other.color_index != a.color_index:
					return a
				break
	return null


## The arrow with the most arrows in its lane (the Super Power demo smashes them all).
func _find_power_arrow() -> ArrowPath:
	var best: ArrowPath = null
	var most := 0
	for a in _maze.arrows:
		if a.busy or a.ice > 0:
			continue
		var n := 0
		for c in a.lane_cells():
			var other: ArrowPath = _maze.occupancy.get(c)
			if other != null and other != a:
				n += 1
		if n > most:
			most = n
			best = a
	return best


## Big reward word ("SWEET!") that pops in the middle of the screen after a lesson is done.
func _praise(kind: String) -> void:
	var tex: Texture2D = PRAISE[kind]
	var pic := TextureRect.new()
	pic.texture = tex
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := _dim.get_viewport_rect().size
	var w := minf(view.x * 0.62, tex.get_width() * 0.85)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size = Vector2(w, w * tex.get_height() / tex.get_width())
	pic.position = Vector2((view.x - pic.size.x) / 2.0, view.y * 0.36 - pic.size.y / 2.0)
	pic.pivot_offset = pic.size / 2.0
	pic.scale = Vector2.ONE * 0.3
	add_child(pic)
	GameData.play_sfx("star")
	var tw := create_tween()
	tw.tween_property(pic, "scale", Vector2.ONE * 1.08, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pic, "scale", Vector2.ONE, 0.1)
	tw.tween_interval(0.45)
	tw.tween_property(pic, "position:y", pic.position.y - 40.0, 0.3)
	tw.parallel().tween_property(pic, "modulate:a", 0.0, 0.3)
	tw.tween_callback(pic.queue_free)


func _skip() -> void:
	_skipped = true
	GameData.play_sfx("tap")
	_end()


func _end() -> void:
	_maze.tutorial_only = null
	_maze.tutorial_block = false
	allow = ""
	if _mode == "level1":
		GameData.tutorial_done = true
		GameData.seen_features["lessons"] = true   # this player gets the later lessons too
	else:
		GameData.seen_features["lesson_" + _mode] = true
	GameData.save_game()
	finished.emit()
	queue_free()


# --- Step kinds -----------------------------------------------------------------------------------

## Spotlight one arrow (plus what it will meet, see _focus); continue once the player
## has tapped it and it resolved.
func _arrow_step(arrow: ArrowPath, text: String, focus: String, power: bool = false, praise: String = "") -> void:
	if arrow == null or not is_instance_valid(arrow):
		return
	_maze.tutorial_block = false
	_maze.tutorial_only = arrow
	var f := _focus(arrow, focus)
	f["tap"] = _arrow_point(arrow)
	_show(f, text, true, false)
	if power:
		await _maze.power_blast
	else:
		await _maze.moved
	_maze.tutorial_only = null
	_maze.tutorial_block = true
	_hide_bubble()
	if praise != "":
		_praise(praise)
		await get_tree().create_timer(1.3).timeout
	else:
		await get_tree().create_timer(0.9).timeout


## Spotlight a HUD button; continue once GameScene reports it was used.
func _button_step(button: Control, kind: String, text: String) -> void:
	_maze.tutorial_block = true
	allow = kind
	_show({"rect": button.get_global_rect()}, text, true, false, true)
	while true:
		var used: String = await _game.helper_used
		if used == kind:
			break
	allow = ""
	_hide_bubble()
	await get_tree().create_timer(0.5).timeout


## Explain something; continue on "Got it".
func _info_step(focus: Dictionary, text: String, near_button: bool = false) -> void:
	_maze.tutorial_block = true
	_show(focus, text, false, true, near_button)
	_point_at_ok_later(_step)
	await _ok.pressed
	GameData.play_sfx("tap")
	_hide_bubble()


# --- Helpers ----------------------------------------------------------------------------------------

## What to light up for an arrow: {rect, lane_a, lane_b}.
##   "exit":  the arrow and its clear path to the edge
##   "first": the arrow, its path and the first arrow in the way (crush / bump partner)
##   "all":   the arrow and every arrow in its lane (Super Power)
func _focus(arrow: ArrowPath, mode: String) -> Dictionary:
	if arrow == null or not is_instance_valid(arrow):
		return {}
	var xf := _maze.get_global_transform_with_canvas()
	var rect := _arrow_rect(arrow)
	var lane := arrow.lane_cells()
	var last := arrow.head()
	for c in lane:
		var other: ArrowPath = _maze.occupancy.get(c)
		if other != null and other != arrow:
			rect = rect.merge(_arrow_rect(other))
			if mode == "first":
				last = c
				break
		last = c
	rect = rect.merge(Rect2(xf * (Vector2(last) * MazeBoard.CELL), Vector2.ZERO)) \
		.merge(Rect2(xf * ((Vector2(last) + Vector2.ONE) * MazeBoard.CELL), Vector2.ZERO))
	var center := func(c: Vector2i) -> Vector2:
		return xf * ((Vector2(c) + Vector2(0.5, 0.5)) * MazeBoard.CELL)
	return {"rect": rect, "lane_a": center.call(arrow.head() + arrow.dir), "lane_b": center.call(last)}


func _show(focus: Dictionary, text: String, tap: bool, with_ok: bool, near_button: bool = false) -> void:
	_step += 1
	var hole: Rect2 = focus.get("rect", Rect2())
	_dim.hole = hole.grow(10.0) if hole.size != Vector2.ZERO else Rect2()
	_hand.stop()
	if tap:
		_hand.tap_at(focus.get("tap", hole.get_center()), _dim.get_viewport_rect().size)
	_dim.lane_a = focus.get("lane_a", Vector2.ZERO)
	_dim.lane_b = focus.get("lane_b", Vector2.ZERO)
	_text.text = text
	_ok.visible = with_ok
	_ok.mouse_filter = Control.MOUSE_FILTER_STOP
	_bubble.visible = true
	_bubble.modulate.a = 0.0
	_place_bubble.call_deferred(_dim.hole, near_button)  # after the wrapped text has been measured


## Puts the bubble where it covers nothing being taught: next to a HUD button, else in
## the header strip above the board, else in the strip above the helper buttons.
func _place_bubble(hole: Rect2, near_button: bool) -> void:
	_bubble.reset_size()
	var view := _dim.get_viewport_rect().size
	var h := _bubble.size.y
	var x := (view.x - _bubble.size.x) / 2.0
	var top_y := 70.0 + GameData.safe_insets().x                         # below Skip
	var bottom_y: float = _game.undo_button.get_global_rect().position.y - h - 20.0
	var y: float
	if hole.size == Vector2.ZERO:
		y = (view.y - h) / 2.0
	elif near_button:
		y = hole.position.y - h - 24.0
		if _hand.visible:
			y -= HAND_TEX.get_size().y * HAND_SCALE * 0.8  # the hand reaches down over the button
	elif top_y + h + 8.0 <= hole.position.y:
		y = top_y
	elif bottom_y >= hole.end.y + 8.0:
		y = bottom_y
	elif hole.get_center().y > view.y * 0.5:
		y = maxf(20.0, hole.position.y - h - 16.0)
	else:
		y = minf(view.y - h - 20.0, hole.end.y + 16.0)
	_bubble.position = Vector2(x, y)
	_bubble.modulate.a = 0.0
	_bubble.pivot_offset = _bubble.size / 2.0
	_bubble.scale = Vector2.ONE * 0.85
	var tw := create_tween().set_parallel()
	tw.tween_property(_bubble, "modulate:a", 1.0, 0.18)
	tw.tween_property(_bubble, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The mascot gives a little hop as it starts talking.
	_face.pivot_offset = _face.size * Vector2(0.5, 1.0)
	var hop := create_tween()
	hop.tween_property(_face, "scale", Vector2(0.9, 1.1), 0.12).set_delay(0.12)
	hop.tween_property(_face, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## On "read this" steps, if the player hasn't pressed "Got it" after a moment,
## the hand points at it so nobody is left tapping the board.
func _point_at_ok_later(step: int) -> void:
	await get_tree().create_timer(1.6).timeout
	if step != _step or _skipped or not _bubble.visible or not _ok.visible:
		return
	_hand.tap_at(_ok.get_global_rect().get_center(), _dim.get_viewport_rect().size)


func _hide_bubble() -> void:
	_hand.stop()
	_bubble.visible = false
	_dim.hole = Rect2()
	_dim.lane_a = Vector2.ZERO
	_dim.lane_b = Vector2.ZERO


## Spotlight around every balloon still on the board.
func _balloons_focus() -> Dictionary:
	var xf := _maze.get_global_transform_with_canvas()
	var rect := Rect2()
	for c: Vector2i in _maze.balloons:
		var cell := Rect2(xf * (Vector2(c) * MazeBoard.CELL), Vector2.ZERO) \
			.expand(xf * ((Vector2(c) + Vector2.ONE) * MazeBoard.CELL))
		rect = cell if rect.size == Vector2.ZERO else rect.merge(cell)
	return {"rect": rect} if rect.size != Vector2.ZERO else {}


func _arrow_at(key: String) -> ArrowPath:
	return _maze.occupancy.get(LevelGenerator.TUTORIAL_CELLS[key])


## Screen point of the arrow's middle cell: always on the arrow, even for bent ones.
func _arrow_point(arrow: ArrowPath) -> Vector2:
	var xf := _maze.get_global_transform_with_canvas()
	var c: Vector2i = arrow.cells[arrow.cells.size() / 2]
	return xf * ((Vector2(c) + Vector2(0.5, 0.5)) * MazeBoard.CELL)


## Screen rectangle around all of an arrow's cells.
func _arrow_rect(arrow: ArrowPath) -> Rect2:
	if arrow == null or not is_instance_valid(arrow):
		return Rect2()
	var xf := _maze.get_global_transform_with_canvas()
	var r := Rect2(xf * (Vector2(arrow.cells[0]) * MazeBoard.CELL), Vector2.ZERO)
	for c in arrow.cells:
		r = r.expand(xf * (Vector2(c) * MazeBoard.CELL))
		r = r.expand(xf * ((Vector2(c) + Vector2.ONE) * MazeBoard.CELL))
	return r
