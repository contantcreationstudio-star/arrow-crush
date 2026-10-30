class_name BowMeter
extends Control
## Level progress as an arrow flying along a track into a bullseye: `value` 0..1
## moves the arrow; at 1 it sits in the target. Inset dark track, glossy fill.

const TRACK := Color(0.12, 0.02, 0.3, 0.6)
const TARGET_RED := Color("#ef4444")

var value := 0.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
var _shine := 0.0
var fill_color := Color("#3b82f6"):
	set(c):
		fill_color = c
		queue_redraw()


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	_shine += delta
	queue_redraw()


func _draw() -> void:
	var h := size.y
	var mid := h * 0.5
	var r := h * 0.62
	var target := Vector2(size.x - r - 2.0, mid)
	var start := 2.0
	var track_h := h * 0.62
	var end_x := target.x - r * 0.4
	var tip_x := lerpf(start + track_h, end_x, value)

	# Track: a deep violet groove with a soft light lip under it.
	_bar(start, end_x, mid + 3.0, track_h + 4.0, Color(1, 1, 1, 0.18))
	_bar(start, end_x, mid, track_h + 4.0, Color("#2e1065"))
	_bar(start + 2.0, end_x - 2.0, mid, track_h - 2.0, Color("#3b0f8c"))
	# Quarter marks.
	for q in [0.25, 0.5, 0.75]:
		var x := lerpf(start + track_h, end_x, q)
		draw_line(Vector2(x, mid - track_h * 0.22), Vector2(x, mid + track_h * 0.22), Color(1, 1, 1, 0.14 if x > tip_x else 0.0), 2.0, true)
	# Fill: gold to orange, glossy top, a light streak sliding along it.
	if tip_x > start + track_h * 0.6:
		_bar(start + 3.0, tip_x, mid, track_h - 6.0, Color("#f59e0b"))
		_bar(start + 3.0, tip_x, mid - 1.0, track_h - 10.0, Color("#fbbf24"))
		_bar(start + 8.0, tip_x - 6.0, mid - track_h * 0.18, track_h * 0.22, Color(1, 1, 1, 0.45))
		var sx := start + fposmod(_shine * 160.0, maxf(tip_x - start, 1.0) + 120.0) - 60.0
		if sx > start + 6.0 and sx < tip_x - 10.0:
			draw_line(Vector2(sx, mid + track_h * 0.25), Vector2(sx + 14.0, mid - track_h * 0.25), Color(1, 1, 1, 0.55), 6.0, true)

	# Bullseye: gold rim, red and white rings, glows once the bar reaches it.
	if value >= 1.0:
		draw_circle(target, r * 1.35, Color("#fde68a", 0.35 + 0.15 * sin(_shine * 6.0)), true, -1.0, true)
	draw_circle(target + Vector2(0, 3), r, Color(0.1, 0.0, 0.25, 0.35), true, -1.0, true)
	draw_circle(target, r, Color("#f59e0b"), true, -1.0, true)
	draw_circle(target, r - 3.0, Color.WHITE, true, -1.0, true)
	for i in 3:
		draw_circle(target, (r - 6.0) * (1.0 - i * 0.33), TARGET_RED if i % 2 == 0 else Color.WHITE, true, -1.0, true)
	draw_circle(target + Vector2(-r * 0.35, -r * 0.4), r * 0.18, Color(1, 1, 1, 0.6), true, -1.0, true)

	# Knob riding the fill: a white disc with a violet arrow pointing at the target.
	var k := Vector2(tip_x, mid)
	var kr := h * 0.5
	draw_circle(k + Vector2(0, 3), kr, Color(0.1, 0.0, 0.25, 0.35), true, -1.0, true)
	draw_circle(k, kr, Color("#7c3aed"), true, -1.0, true)
	draw_circle(k, kr - 3.0, Color.WHITE, true, -1.0, true)
	var ink := Color("#6d28d9")
	draw_line(k - Vector2(kr * 0.45, 0), k + Vector2(kr * 0.2, 0), ink, kr * 0.22, true)
	draw_colored_polygon(PackedVector2Array([k + Vector2(kr * 0.55, 0), k + Vector2(kr * 0.05, -kr * 0.38), k + Vector2(kr * 0.05, kr * 0.38)]), ink)


## A rounded horizontal bar from x0 to x1.
func _bar(x0: float, x1: float, y: float, thick: float, color: Color) -> void:
	if x1 - x0 <= thick:
		return
	draw_line(Vector2(x0 + thick / 2.0, y), Vector2(x1 - thick / 2.0, y), color, thick, true)
	draw_circle(Vector2(x0 + thick / 2.0, y), thick / 2.0, color, true, -1.0, true)
	draw_circle(Vector2(x1 - thick / 2.0, y), thick / 2.0, color, true, -1.0, true)
