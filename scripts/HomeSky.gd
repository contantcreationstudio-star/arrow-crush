class_name HomeSky
extends Control
## Night-violet sky behind every Home tab: a deep gradient, soft glows, twinkling stars
## and a few gold / coral arrows gliding slowly across.

const TOP := Color("#1e1b4b")
const BOTTOM := Color("#6d28d9")
const ARROW_COLORS: Array[Color] = [Color("#fbbf24"), Color("#fb7185"), Color("#c4b5fd")]
const DIR := Vector2(0.94, -0.34)   # arrows fly up and to the right

var _t := 0.0
var _stars: Array[Vector3] = []     # x, y (0..1 of the size), twinkle phase
var _arrows: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 70:
		_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf()))
	for i in 5:
		_arrows.append({
			"y": rng.randf_range(0.2, 1.1),
			"speed": rng.randf_range(0.025, 0.05),
			"start": rng.randf(),
			"length": rng.randf_range(70.0, 120.0),
			"color": ARROW_COLORS[i % ARROW_COLORS.size()],
		})


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([TOP, TOP, BOTTOM, BOTTOM]))
	draw_circle(Vector2(s.x * 0.88, s.y * 0.14), 280.0, Color(0.65, 0.55, 1.0, 0.08))
	draw_circle(Vector2(s.x * 0.05, s.y * 0.55), 320.0, Color(0.98, 0.45, 0.6, 0.06))
	draw_circle(Vector2(s.x * 0.6, s.y * 1.02), 360.0, Color(0.98, 0.75, 0.2, 0.06))

	for st in _stars:
		var a := 0.2 + 0.55 * (0.5 + 0.5 * sin(_t * 1.6 + st.z * TAU))
		draw_circle(Vector2(st.x * s.x, st.y * s.y), 1.4 + st.z * 2.0, Color(1, 1, 1, a))

	var normal := DIR.orthogonal()
	for arrow in _arrows:
		var u := fmod(float(arrow.start) + _t * float(arrow.speed), 1.0)
		var tip := Vector2(-0.25 * s.x, float(arrow.y) * s.y) + DIR * u * s.x * 1.7
		var tail := tip - DIR * float(arrow.length)
		var c: Color = arrow.color
		draw_line(tail, tip - DIR * 6.0, Color(c, 0.35), 4.0, true)
		draw_colored_polygon(PackedVector2Array([tip + DIR * 10.0, tip - DIR * 6.0 + normal * 9.0,
			tip - DIR * 6.0 - normal * 9.0]), Color(c, 0.45))
		for k in 2:
			var f := tail + DIR * (6.0 + k * 9.0)
			draw_line(f, f - DIR * 10.0 + normal * 9.0, Color(c, 0.3), 3.0, true)
			draw_line(f, f - DIR * 10.0 - normal * 9.0, Color(c, 0.3), 3.0, true)
