class_name LevelTransition
extends CanvasLayer
## The curtain between levels: a violet circle closes in on the button that was pressed
## (gold rim on its edge), then the next level is announced on it - a gold medal with the
## number drops in under turning light rays, a LEVEL ribbon unfurls, the goal shows and
## the mascot peeks in. Hard levels turn the stage red: caution tape slides in, flames
## light up and a HARD LEVEL stamp slams down. Then the circle opens on the new board.

const SHADER := """
shader_type canvas_item;
uniform float radius = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform float aspect = 1.78;
uniform vec4 inner : source_color = vec4(0.40, 0.16, 0.80, 1.0);
uniform vec4 outer : source_color = vec4(0.10, 0.04, 0.30, 1.0);
uniform vec4 rim : source_color = vec4(0.98, 0.75, 0.14, 1.0);
void fragment() {
	vec2 p = UV - center;
	p.y *= aspect;
	float d = length(p);
	vec2 q = UV - vec2(0.5, 0.42);
	q.y *= aspect;
	vec3 c = mix(inner.rgb, outer.rgb, smoothstep(0.0, 1.05, length(q)));
	float s = fract((UV.x + UV.y * aspect) * 8.0 - TIME * 0.07);
	c += step(0.5, s) * 0.022;
	float open = step(0.0005, radius);
	float ring = open * smoothstep(radius - 0.003, radius + 0.002, d) * (1.0 - smoothstep(radius + 0.016, radius + 0.022, d));
	c = mix(c, rim.rgb, ring);
	float a = mix(1.0, smoothstep(radius, radius + 0.004, d), open);
	COLOR = vec4(c, a * COLOR.a);
}
"""

const VIOLET_IN := Color(0.40, 0.16, 0.80)
const VIOLET_OUT := Color(0.10, 0.04, 0.30)
const RED_IN := Color("#dc2626")
const RED_OUT := Color("#450a0a")
const RIBBON := preload("res://icons/fx/map_banner.png")
const SPARK := preload("res://icons/fx/confetti_star.png")
const GLOW := preload("res://icons/fx/crush_glow.png")
const FLAME := preload("res://icons/flame.svg")
const STAR := preload("res://icons/star_on.svg")
const MASCOT_HAPPY := preload("res://icons/fx/mascot_happy.png")
const MASCOT_WOW := preload("res://icons/fx/mascot_wow.png")
const MEDAL := 300.0

var _rect: ColorRect
var _mat: ShaderMaterial
static var _shader: Shader
var _card: Control
var _max_r := 2.2


## `covered` = start fully closed (the very first level when the game screen opens).
static func make(parent: Node, covered: bool = false) -> LevelTransition:
	var t := LevelTransition.new()
	t.layer = 38  # above the win card (36) and fail card (35); popups (40+) and ads go above
	parent.add_child(t)
	t._build(covered)
	return t


func _build(covered: bool) -> void:
	var view := get_viewport().get_visible_rect().size
	var aspect := view.y / maxf(view.x, 1.0)
	_max_r = Vector2(1.0, aspect).length() + 0.05
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP  # nothing under the curtain takes taps
	_mat = ShaderMaterial.new()
	# One shared shader: building it from code each time recompiled it on every level change.
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_mat.shader = _shader
	_mat.set_shader_parameter("aspect", aspect)
	_mat.set_shader_parameter("radius", 0.0 if covered else _max_r)
	_rect.material = _mat
	add_child(_rect)


## Closes the circle onto `at` (screen pixels; centre of the screen when not given).
func close(at: Vector2 = Vector2(-1, -1), time: float = 0.5) -> void:
	var view := get_viewport().get_visible_rect().size
	if at.x < 0.0:
		at = view / 2.0
	_mat.set_shader_parameter("center", at / view)
	GameData.play_sfx("slide", 0.8)
	var t := create_tween()
	t.tween_method(_set_radius, _max_r, 0.0, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await t.finished


## The next level announced on the curtain. `stamp` = "HARD LEVEL" / "SUPER HARD" or "";
## `sub` = the goal in a few words ("Pop 4 balloons!").
func show_title(title: String, stamp: String = "", stamp_color: Color = Color("#ef4444"), sub: String = "") -> void:
	var view := get_viewport().get_visible_rect().size
	var hard := stamp != ""
	var c := Vector2(view.x / 2.0, view.y * 0.4)   # medal centre
	_card = Control.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)

	# Light rays and a warm glow behind the medal.
	var rays := Control.new()
	rays.position = c
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.draw.connect(func() -> void:
		for i in 16:
			var a := TAU * i / 16.0
			var w := TAU / 16.0 * 0.3
			rays.draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a - w) * 1100.0,
				Vector2.from_angle(a + w) * 1100.0]), Color(1, 0.95, 0.8, 0.07)))
	_card.add_child(rays)
	rays.modulate.a = 0.0
	var spin := rays.create_tween().set_loops()
	spin.tween_property(rays, "rotation", TAU, 20.0).from(0.0)
	rays.create_tween().tween_property(rays, "modulate:a", 1.0, 0.4)
	var glow := _tex(GLOW, Vector2(620, 620), c)
	glow.modulate = Color(1, 0.8, 0.3, 0.0)
	_card.add_child(glow)

	# Caution tape for hard levels (slides in later).
	var tapes: Array[Control] = []
	if hard:
		for k in 2:
			var tape := _caution_tape(view.x)
			tape.position = Vector2(-120.0, view.y * (0.1 if k == 0 else 0.84))
			tape.rotation = -0.06 if k == 0 else 0.06
			tape.modulate.a = 0.0
			_card.add_child(tape)
			tapes.append(tape)

	# Twinkling stars around the medal.
	var twinkles: Array[TextureRect] = []
	for i in 7:
		var a := TAU * i / 7.0 + 0.4
		var d := MEDAL * (0.68 + 0.12 * (i % 2))
		var s := _tex(SPARK, Vector2.ONE * (34.0 + 10.0 * (i % 3)), c + Vector2.from_angle(a) * d)
		s.modulate = Color("#fde68a", 0.0)
		_card.add_child(s)
		twinkles.append(s)

	# The medal with the number (or a star for a day's challenge).
	var medal := Control.new()
	medal.size = Vector2.ONE * MEDAL
	medal.position = c - medal.size / 2.0
	medal.pivot_offset = medal.size / 2.0
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	medal.draw.connect(_draw_medal.bind(medal))
	_card.add_child(medal)
	var ribbon_text := "LEVEL"
	var number := ""
	if title.begins_with("Level "):
		number = title.substr(6)
	else:
		ribbon_text = title.to_upper()
	if number != "":
		var num := _label(number, 150 if number.length() <= 2 else 112, Color("#fde047"), 20)
		medal.add_child(num)
		num.size = medal.size
		num.position = Vector2(0, -8)
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		var star := _tex(STAR, Vector2(150, 150), medal.size / 2.0 - Vector2(0, 8))
		medal.add_child(star)

	# Ribbon across the bottom of the medal.
	var ribbon := Control.new()
	ribbon.size = Vector2(440, 440.0 * RIBBON.get_height() / RIBBON.get_width())
	ribbon.position = c + Vector2(-ribbon.size.x / 2.0, MEDAL * 0.3)
	ribbon.pivot_offset = ribbon.size / 2.0
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(ribbon)
	var band := _tex(RIBBON, ribbon.size, ribbon.size / 2.0)
	band.modulate = Color("#e11d48") if not hard else Color("#7f1d1d")
	ribbon.add_child(band)
	var rl := _label(ribbon_text, 50 if ribbon_text.length() <= 8 else 40, Color.WHITE, 12)
	rl.size = Vector2(ribbon.size.x, ribbon.size.y * 0.78)
	rl.position.y = 14.0
	rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ribbon.add_child(rl)
	ribbon.modulate.a = 0.0

	# The goal, under the ribbon.
	var sub_label: Label = null
	var below := ribbon.position.y + ribbon.size.y + 18.0
	if hard:
		below += 110.0  # room for the stamp
	if sub != "":
		sub_label = _label(sub, 40 if sub.length() <= 26 else 32, Color.WHITE, 12)
		sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub_label.size = Vector2(view.x - 60.0, 110)
		sub_label.position = Vector2(30, below)
		sub_label.pivot_offset = sub_label.size / 2.0
		sub_label.modulate.a = 0.0
		_card.add_child(sub_label)

	# Mascot peeking in from the bottom corner.
	var mascot := _tex(MASCOT_WOW if hard else MASCOT_HAPPY, Vector2(230, 230), Vector2(view.x - 110.0, view.y + 130.0))
	mascot.rotation = -0.18
	_card.add_child(mascot)

	# --- Timeline -----------------------------------------------------------------------
	# Medal drops in, squashes on landing, sparks fly.
	medal.position.y -= view.y * 0.6
	medal.rotation = -0.4
	var m := medal.create_tween()
	m.tween_interval(0.05)
	m.tween_property(medal, "position:y", c.y - MEDAL / 2.0, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	m.parallel().tween_property(medal, "rotation", 0.0, 0.34)
	m.tween_callback(func() -> void:
		GameData.play_sfx("thunk")
		GameData.play_sfx("star", 0.9)
		GameData.vibrate(25)
		_sparks(c, 22)
		_shake(8.0)
		glow.create_tween().tween_property(glow, "modulate:a", 0.6, 0.3)
		for i in twinkles.size():
			var s := twinkles[i]
			var tw := s.create_tween().set_loops()
			tw.tween_interval(0.12 * i)
			tw.tween_property(s, "modulate:a", 1.0, 0.25)
			tw.parallel().tween_property(s, "scale", Vector2.ONE * 1.25, 0.25)
			tw.tween_property(s, "modulate:a", 0.25, 0.5)
			tw.parallel().tween_property(s, "scale", Vector2.ONE * 0.7, 0.5))
	m.tween_property(medal, "scale", Vector2(1.18, 0.84), 0.07)
	m.tween_property(medal, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Ribbon unfurls from the middle.
	ribbon.scale = Vector2(0.05, 1.0)
	var r := ribbon.create_tween()
	r.tween_interval(0.45)
	r.tween_callback(GameData.play_sfx.bind("slide", 1.5))
	r.tween_property(ribbon, "modulate:a", 1.0, 0.08)
	r.parallel().tween_property(ribbon, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Mascot pops up and waves (tilts) a little.
	var mk := mascot.create_tween()
	mk.tween_interval(0.6)
	mk.tween_property(mascot, "position:y", view.y - 210.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	mk.tween_property(mascot, "rotation", -0.05, 0.2)
	mk.tween_property(mascot, "rotation", -0.22, 0.2)
	mk.tween_property(mascot, "rotation", -0.1, 0.25)

	var hold := 1.55
	if hard:
		hold = 2.15
		# The stage turns red, the tape slides in, then the stamp slams.
		var bg := create_tween()
		bg.tween_interval(0.55)
		bg.tween_method(func(k: float) -> void:
			_mat.set_shader_parameter("inner", VIOLET_IN.lerp(RED_IN, k))
			_mat.set_shader_parameter("outer", VIOLET_OUT.lerp(RED_OUT, k)), 0.0, 1.0, 0.35)
		for k in tapes.size():
			var tape := tapes[k]
			var home_x := tape.position.x
			tape.position.x += (-1.0 if k == 0 else 1.0) * view.x
			var tt := tape.create_tween()
			tt.tween_interval(0.6 + k * 0.08)
			tt.tween_property(tape, "modulate:a", 1.0, 0.05)
			tt.parallel().tween_property(tape, "position:x", home_x, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tt.tween_callback(func() -> void:
				var crawl := tape.create_tween().set_loops()
				crawl.tween_property(tape, "position:x", home_x - 64.0, 0.6).from(home_x))
		_stamp(stamp, stamp_color, Vector2(c.x, ribbon.position.y + ribbon.size.y + 54.0), 0.85)

	if sub_label:
		var sl := sub_label.create_tween()
		sl.tween_interval(1.2 if hard else 0.75)
		sl.tween_callback(func() -> void: sub_label.scale = Vector2.ONE * 0.5)
		sl.tween_property(sub_label, "modulate:a", 1.0, 0.12)
		sl.parallel().tween_property(sub_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(hold).timeout
	# Everything zooms past the camera as the curtain opens.
	_card.pivot_offset = c
	var out := _card.create_tween()
	out.tween_property(_card, "modulate:a", 0.0, 0.25)
	out.parallel().tween_property(_card, "scale", Vector2.ONE * 1.35, 0.25).set_ease(Tween.EASE_IN)


## Opens the circle on the new board, then removes the curtain.
func open(time: float = 0.55) -> void:
	_mat.set_shader_parameter("center", Vector2(0.5, 0.5))
	GameData.play_sfx("slide", 1.25)
	var t := create_tween()
	t.tween_method(_set_radius, 0.0, _max_r, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	queue_free()


func _set_radius(r: float) -> void:
	_mat.set_shader_parameter("radius", r)


## HARD LEVEL stamp with a flame on each side, slamming down at `at` after `delay`.
func _stamp(text: String, color: Color, at: Vector2, delay: float) -> void:
	var badge := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = color.darkened(0.4)
	box.border_width_bottom = 9
	box.set_border_width_all(4)
	box.border_width_bottom = 10
	box.set_corner_radius_all(24)
	box.content_margin_left = 34
	box.content_margin_right = 34
	box.content_margin_top = 6
	box.content_margin_bottom = 10
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 16
	box.shadow_offset = Vector2(0, 7)
	box.anti_aliasing = true
	badge.add_theme_stylebox_override("panel", box)
	var txt := _label(text, 58, Color.WHITE, 12)
	txt.add_theme_color_override("font_outline_color", color.darkened(0.5))
	badge.add_child(txt)
	_card.add_child(badge)
	badge.size = badge.get_combined_minimum_size()
	badge.position = at - badge.size / 2.0
	badge.pivot_offset = badge.size / 2.0
	badge.modulate.a = 0.0
	badge.scale = Vector2.ONE * 3.2
	badge.rotation = -0.5
	var flames: Array[TextureRect] = []
	for side: float in [-1.0, 1.0]:
		var f := _tex(FLAME, Vector2(92, 92), at + Vector2(side * (badge.size.x / 2.0 + 30.0), -14.0))
		f.scale = Vector2.ZERO
		f.pivot_offset = Vector2(46, 80)
		_card.add_child(f)
		_card.move_child(f, badge.get_index())
		flames.append(f)
	var b := badge.create_tween()
	b.tween_interval(delay)
	b.tween_property(badge, "modulate:a", 1.0, 0.08)
	b.parallel().tween_property(badge, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	b.parallel().tween_property(badge, "rotation", -0.06, 0.2)
	b.tween_callback(func() -> void:
		_stamp_hit(color)
		_sparks(at, 26)
		for i in flames.size():
			var f := flames[i]
			var lit := f.create_tween()
			lit.tween_property(f, "scale", Vector2.ONE * 1.15, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			var flicker := f.create_tween().set_loops()
			flicker.tween_interval(0.18 + i * 0.07)
			flicker.tween_property(f, "scale", Vector2(0.92, 1.18), 0.13)
			flicker.tween_property(f, "scale", Vector2(1.1, 0.95), 0.13)
			flicker.tween_property(f, "scale", Vector2.ONE, 0.1))
	b.tween_property(badge, "scale", Vector2(1.15, 0.85), 0.06)
	b.tween_property(badge, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var throb := badge.create_tween().set_loops()
	throb.tween_interval(delay + 0.9)
	throb.tween_property(badge, "scale", Vector2.ONE * 1.07, 0.18)
	throb.tween_property(badge, "scale", Vector2.ONE, 0.25)


func _stamp_hit(color: Color) -> void:
	GameData.play_sfx("boom")
	GameData.vibrate(60)
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(color.lightened(0.3), 0.5)
	add_child(flash)
	var f := flash.create_tween()
	f.tween_property(flash, "color:a", 0.0, 0.45)
	f.tween_callback(flash.queue_free)
	_shake(18.0)


func _shake(amount: float) -> void:
	if _card == null:
		return
	var s := _card.create_tween()
	for k in 7:
		var a := amount * (1.0 - k / 7.0)
		s.tween_property(_card, "position", Vector2(randf_range(-a, a), randf_range(-a, a)), 0.035)
	s.tween_property(_card, "position", Vector2.ZERO, 0.05)


func _sparks(at: Vector2, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.texture = SPARK
	p.position = at
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.9
	p.spread = 180.0
	p.direction = Vector2.UP
	p.initial_velocity_min = 320.0
	p.initial_velocity_max = 640.0
	p.gravity = Vector2(0, 800)
	p.damping_min = 120.0
	p.damping_max = 260.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.6
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color("#fff7cc"), Color(1.0, 0.75, 0.15, 0.0)])
	p.color_ramp = fade
	_card.add_child(p)
	p.finished.connect(p.queue_free)
	p.emitting = true


## Yellow-and-dark caution tape, wider than the screen so it can crawl sideways.
func _caution_tape(width: float) -> Control:
	var tape := Control.new()
	tape.size = Vector2(width + 400.0, 58)
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tape.draw.connect(func() -> void:
		var h := tape.size.y
		tape.draw_rect(Rect2(Vector2(0, 4), tape.size), Color(0, 0, 0, 0.3))
		tape.draw_rect(Rect2(Vector2.ZERO, tape.size), Color("#facc15"))
		var x := -h
		while x < tape.size.x:
			tape.draw_colored_polygon(PackedVector2Array([Vector2(x, h), Vector2(x + 32, h), Vector2(x + 32 + h, 0),
				Vector2(x + h, 0)]), Color("#1c1917"))
			x += 64.0
		tape.draw_rect(Rect2(Vector2.ZERO, Vector2(tape.size.x, 5)), Color(1, 1, 1, 0.3)))
	return tape


func _draw_medal(c: Control) -> void:
	var m := c.size / 2.0
	var r := c.size.x / 2.0
	c.draw_circle(m + Vector2(0, 14), r, Color(0, 0, 0, 0.3), true, -1.0, true)
	c.draw_circle(m + Vector2(0, 8), r, Color("#b45309"), true, -1.0, true)
	c.draw_circle(m, r, Color("#f59e0b"), true, -1.0, true)
	c.draw_circle(m - Vector2(0, 4), r * 0.95, Color("#fbbf24"), true, -1.0, true)
	for i in 16:  # rivets around the ring
		c.draw_circle(m + Vector2.from_angle(TAU * i / 16.0) * r * 0.875, r * 0.03, Color("#fff7d6"), true, -1.0, true)
	c.draw_circle(m, r * 0.79, Color("#b45309"), true, -1.0, true)
	c.draw_circle(m + Vector2(0, 4), r * 0.76, Color("#3b0764"), true, -1.0, true)
	c.draw_circle(m, r * 0.75, Color("#5b21b6"), true, -1.0, true)
	c.draw_circle(m - Vector2(0, r * 0.1), r * 0.62, Color("#6d28d9"), true, -1.0, true)
	c.draw_arc(m, r * 0.93, PI * 1.12, PI * 1.6, 24, Color(1, 1, 1, 0.6), r * 0.05, true)
	c.draw_arc(m, r * 0.66, PI * 1.15, PI * 1.45, 20, Color(1, 1, 1, 0.22), r * 0.05, true)


func _tex(tex: Texture2D, size: Vector2, center: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size = size
	t.position = center - size / 2.0
	t.pivot_offset = size / 2.0
	return t


func _label(text: String, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", TitleLogo.FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("#2e1065"))
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	l.add_theme_constant_override("shadow_offset_y", 7)
	l.add_theme_constant_override("shadow_outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
