class_name TitleLogo
extends Control
## The big "ARROW / CRUSH" game title: chunky letters with depth (extrusion), a thick
## dark outline, a gradient face with a glossy top, and a light glint that sweeps across.
## An archery arrow pierces the logo between the two words and quivers when it sticks.
## The node's position is the centre of the logo; call play() to animate it in.

signal landed  # the arrow has struck - the logo is complete

const FONT := preload("res://theme/fonts/LuckiestGuy-Regular.ttf")
const INK := Color("#22074d")
const FILL_SHADER := """
shader_type canvas_item;
uniform vec4 top_col : source_color;
uniform vec4 mid_col : source_color;
uniform vec4 bot_col : source_color;
uniform float y_top;
uniform float y_bot;
uniform float shine_x = -9999.0;  // canvas x of the glint band
varying vec2 local_pos;
varying vec2 canvas_pos;
void vertex() {
	local_pos = VERTEX;
	canvas_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	float t = clamp((local_pos.y - y_top) / (y_bot - y_top), 0.0, 1.0);
	vec3 c = t < 0.5 ? mix(top_col.rgb, mid_col.rgb, t * 2.0) : mix(mid_col.rgb, bot_col.rgb, t * 2.0 - 1.0);
	// Glossy top: a soft white sheen over the upper part of every letter.
	c = mix(c, vec3(1.0), 0.32 * smoothstep(0.42, 0.0, t));
	// Glint: a slanted bright band moving across.
	float d = abs(canvas_pos.x + canvas_pos.y * 0.45 - shine_x);
	c += vec3(1.0) * 0.75 * smoothstep(34.0, 6.0, d);
	COLOR.rgb = c;
}
"""

## One letter: depth and outline drawn here, the gradient face on a child with the shader.
class Letter extends Control:
	const FONT := preload("res://theme/fonts/LuckiestGuy-Regular.ttf")
	const INK := Color("#22074d")
	var ch := ""
	var font_size := 100
	var depth := 12
	var side_col := Color.BLACK
	var outline := 24
	var face: Control

	func setup(text: String, fsize: int, mat: ShaderMaterial, side: Color) -> void:
		ch = text
		font_size = fsize
		side_col = side
		depth = int(fsize * 0.11)
		outline = int(fsize * 0.2)
		var w := FONT.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		size = Vector2(w, FONT.get_ascent(font_size))
		pivot_offset = Vector2(w / 2.0, size.y)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		face = Control.new()
		face.material = mat
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.draw.connect(func() -> void:
			face.draw_string(FONT, Vector2(0, size.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size))
		add_child(face)

	func _draw() -> void:
		var base := Vector2(0, size.y)
		# Drop shadow, then the extruded side (dark-edged), then the front outline.
		draw_string_outline(FONT, base + Vector2(0, depth + 10), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			outline + 6, Color(0.03, 0.0, 0.12, 0.35))
		for d in range(depth, 0, -1):
			draw_string_outline(FONT, base + Vector2(0, d), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, INK)
		for d in range(depth - 2, 0, -1):
			draw_string_outline(FONT, base + Vector2(0, d), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				int(outline * 0.45), side_col)
			draw_string(FONT, base + Vector2(0, d), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, side_col)
		draw_string_outline(FONT, base, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, INK)
		# A thin light rim just inside the outline makes the face pop.
		draw_string_outline(FONT, base, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, int(outline * 0.3),
			Color(1, 1, 1, 0.85))


## The archery arrow: drawn along +x with its tip at the origin.
class Arrow extends Control:
	const INK := Color("#22074d")
	var length := 600.0
	var wobble := 0.0   # set while it quivers after sticking
	var speed := 0.0    # > 0 while flying: draws speed streaks

	func _draw() -> void:
		var t := 26.0          # shaft thickness
		var head := 78.0
		var tail := Vector2(-length, 0)
		var neck := Vector2(-head * 0.7, 0)
		if speed > 0.0:
			for i in 4:
				var y := (i - 1.5) * 14.0
				var l := minf(speed * 0.35, 520.0) * (1.0 - absf(i - 1.5) * 0.25)
				draw_line(tail + Vector2(30, y), tail + Vector2(30 - l, y), Color(1, 1, 1, 0.28), 6.0, true)
		# Fletching: three feathers at the back.
		for side in [-1.0, 1.0]:
			var f := PackedVector2Array([tail + Vector2(10, 0), tail + Vector2(60, side * 6), tail + Vector2(96, side * 46),
				tail + Vector2(36, side * 46)])
			_rounded(f, INK, 9.0)
			_rounded(f, Color("#22d3ee"), 1.5)
			draw_line(tail + Vector2(26, side * 4), tail + Vector2(70, side * 40), Color(1, 1, 1, 0.55), 4.0, true)
		# Shaft: outline, wood-gold gradient body, highlight.
		draw_line(tail, neck, INK, t + 14.0, true)
		draw_circle(tail, (t + 14.0) / 2.0, INK, true, -1.0, true)
		var steps := 24
		for i in steps:
			var a := tail.lerp(neck, float(i) / steps)
			var b := tail.lerp(neck, float(i + 1) / steps)
			var c := Color("#fde047").lerp(Color("#fb923c"), float(i) / steps)
			draw_line(a, b, c, t, true)
		draw_circle(tail, t / 2.0, Color("#fde047"), true, -1.0, true)
		draw_line(tail + Vector2(8, -t * 0.22), neck + Vector2(0, -t * 0.22), Color(1, 1, 1, 0.55), 5.0, true)
		# Head: a broad tip with outline and a light facet.
		var tip := PackedVector2Array([Vector2(0, 0), Vector2(-head, -head * 0.5), Vector2(-head * 0.78, 0),
			Vector2(-head, head * 0.5)])
		_rounded(tip, INK, 8.0)
		_rounded(tip, Color("#f43f5e"), 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -2), Vector2(-head + 12, -head * 0.42),
			Vector2(-head * 0.74, -4)]), Color(1, 1, 1, 0.38))
		# Vibration lines while it quivers.
		if absf(wobble) > 0.01:
			for side in [-1.0, 1.0]:
				for k in 2:
					var base := tail + Vector2(40 + k * 18, side * (58 + k * 8))
					draw_arc(base, 16.0, PI * (0.15 if side < 0 else 1.15), PI * (0.85 if side < 0 else 1.85),
						8, Color(1, 1, 1, minf(absf(wobble) * 6.0, 0.8)), 4.0, true)

	func _rounded(pts: PackedVector2Array, col: Color, r: float) -> void:
		for p in Geometry2D.offset_polygon(pts, r, Geometry2D.JOIN_ROUND):
			draw_colored_polygon(p, col)


var top_word: Array[Letter] = []
var bottom_word: Array[Letter] = []
var arrow: Arrow
var _mats: Array[ShaderMaterial] = []
var _letter_rest := {}   # Letter -> resting position
var _clock := 0.0
var _glint_at := -1.0     # when the next idle glint starts
var _arrow_rest := Vector2.ZERO
var _arrow_angle := -0.12
var _stuck_at := -1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow = Arrow.new()
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(arrow)  # first, so the letters cover its middle: it looks pierced through
	_build_word("ARROW", 118, -62.0, 14.0, [Color("#fff7c2"), Color("#fcd34d"), Color("#f59e0b")], Color("#b45309"), top_word)
	_build_word("CRUSH", 150, 96.0, -18.0, [Color("#ffd1dc"), Color("#fb7185"), Color("#e11d48")], Color("#9f1239"), bottom_word)
	_arrow_rest = Vector2(268, -48)  # tip; the shaft runs back through the gap between the words
	arrow.length = 530.0
	arrow.position = _arrow_rest
	arrow.rotation = _arrow_angle
	arrow.visible = false


## Swaps the two words before play() (the win screen's "LEVEL 12 / COMPLETE!"): same
## look and the same entrance as the game title, other text and colours.
func set_words(top: String, bottom: String, top_size := 104, bottom_size := 120,
		bottom_cols: Array = [Color("#ffd1dc"), Color("#fb7185"), Color("#e11d48")], bottom_side := Color("#9f1239")) -> void:
	for l in top_word + bottom_word:
		_letter_rest.erase(l)
		remove_child(l)
		l.queue_free()
	top_word.clear()
	bottom_word.clear()
	_mats.clear()
	_build_word(top, top_size, -62.0, 14.0, [Color("#fff7c2"), Color("#fcd34d"), Color("#f59e0b")], Color("#b45309"), top_word)
	_build_word(bottom, bottom_size, 96.0, -18.0, bottom_cols, bottom_side, bottom_word)


## Lays a word out centred, its baseline at `baseline`, letters following an arc
## (`arc` > 0: the middle sits lower; < 0: the middle rises).
func _build_word(text: String, fsize: int, baseline: float, arc: float, cols: Array, side: Color, out: Array[Letter]) -> void:
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FILL_SHADER
	mat.shader = sh
	var ascent := FONT.get_ascent(fsize)
	mat.set_shader_parameter("top_col", cols[0])
	mat.set_shader_parameter("mid_col", cols[1])
	mat.set_shader_parameter("bot_col", cols[2])
	mat.set_shader_parameter("y_top", ascent * 0.22)
	mat.set_shader_parameter("y_bot", ascent)
	_mats.append(mat)
	var gap := -fsize * 0.02
	var widths: Array[float] = []
	var total := 0.0
	for ch in text:
		var w := FONT.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		widths.append(w)
		total += w + gap
	total -= gap
	var x := -total / 2.0
	var half := total / 2.0
	for i in text.length():
		var l := Letter.new()
		l.setup(text[i], fsize, mat, side)
		var cx := x + widths[i] / 2.0
		var u := cx / half
		l.position = Vector2(x, baseline - l.size.y + arc * (1.0 - u * u))
		l.rotation = -2.0 * arc * u / half * 0.9
		add_child(l)
		out.append(l)
		_letter_rest[l] = l.position
		x += widths[i] + gap


func _process(delta: float) -> void:
	_clock += delta
	# Quiver: a fast, fading swing around the arrow tip.
	if _stuck_at >= 0.0:
		var t := _clock - _stuck_at
		arrow.wobble = 0.09 * exp(-t * 4.5) * sin(t * 48.0)
		arrow.rotation = _arrow_angle + arrow.wobble
		arrow.queue_redraw()
	# Idle glint every few seconds.
	if _glint_at >= 0.0 and _clock >= _glint_at:
		_glint_at = _clock + 3.2
		glint()


func set_glint(x: float) -> void:
	for m in _mats:
		m.set_shader_parameter("shine_x", x)


## A bright band sweeps across the letters, left to right.
func glint() -> void:
	var g := global_position
	create_tween().tween_method(set_glint, g.x - 520.0, g.x + 620.0, 0.75).set_trans(Tween.TRANS_SINE)


## The full entrance. `shake` is called with a strength when something lands hard.
func play(shake: Callable) -> void:
	for l in top_word + bottom_word:
		l.modulate.a = 0.0
	# 1) ARROW: letters drop in one by one and squash as they land.
	for i in top_word.size():
		var l := top_word[i]
		var rest: Vector2 = _letter_rest[l]
		l.position = rest - Vector2(0, 260)
		l.scale = Vector2(0.8, 1.25)
		var t := create_tween()
		t.tween_interval(0.12 + 0.07 * i)
		t.tween_property(l, "modulate:a", 1.0, 0.08)
		t.parallel().tween_property(l, "position", rest, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_callback(GameData.play_sfx.bind("land", 0.9 + 0.08 * i))
		t.tween_property(l, "scale", Vector2(1.18, 0.82), 0.05)
		t.tween_property(l, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# 2) CRUSH: the whole word slams down from huge - the big hit.
	var slam_at := 0.12 + 0.07 * top_word.size() + 0.2
	# Every letter scales about the word's centre, so the word zooms in as one block.
	var word_c := Vector2.ZERO
	for l in bottom_word:
		word_c += (_letter_rest[l] as Vector2) + l.pivot_offset
	word_c /= bottom_word.size()
	var big := 2.6
	for l in bottom_word:
		var rest: Vector2 = _letter_rest[l]
		var p := rest + l.pivot_offset
		var from := word_c + (p - word_c) * big - l.pivot_offset
		l.position = from
		var t := create_tween()
		t.tween_interval(slam_at)
		t.tween_property(l, "modulate:a", 1.0, 0.06)
		t.parallel().tween_property(l, "position", rest, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(l, "scale", Vector2.ONE, 0.16).from(Vector2.ONE * big).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(l, "scale", Vector2(1.12, 0.86), 0.05)
		t.tween_property(l, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var hit := create_tween()
	hit.tween_interval(slam_at + 0.16)
	hit.tween_callback(func() -> void:
		GameData.play_sfx("slam")
		GameData.vibrate(25)
		shake.call(16.0)
		for l in top_word:  # the hit jolts the top word
			var j := create_tween()
			j.tween_property(l, "position:y", (_letter_rest[l] as Vector2).y - 14.0, 0.07).set_ease(Tween.EASE_OUT)
			j.tween_property(l, "position:y", (_letter_rest[l] as Vector2).y, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT))
	# 3) The arrow flies in from the left and thunks in.
	var fly_at := slam_at + 0.5
	var start := _arrow_rest + Vector2(-1100, 0).rotated(_arrow_angle)
	var a := create_tween()
	a.tween_interval(fly_at)
	a.tween_callback(func() -> void:
		arrow.visible = true
		arrow.position = start
		arrow.speed = 1.0
		GameData.play_sfx("whoosh"))
	var fly := func(p: float) -> void:
		arrow.position = start.lerp(_arrow_rest, p)
		arrow.speed = (1.0 - p) * 1400.0 + 200.0
		arrow.queue_redraw()
	a.tween_method(fly, 0.0, 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	a.tween_callback(func() -> void:
		arrow.speed = 0.0
		_stuck_at = _clock
		GameData.play_sfx("thunk_wood")
		GameData.play_sfx("plank", 1.2)
		GameData.vibrate(15)
		shake.call(7.0)
		landed.emit())
	# 4) A glint sweeps across and a little sparkle sound plays; idle glints follow.
	a.tween_interval(0.35)
	a.tween_callback(func() -> void:
		GameData.play_sfx("glint")
		glint()
		_glint_at = _clock + 3.0)


## The point where the arrow tip sits, in this node's space (for sparks).
func arrow_tip() -> Vector2:
	return _arrow_rest
