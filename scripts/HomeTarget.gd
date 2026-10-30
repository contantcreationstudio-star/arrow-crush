class_name HomeTarget
extends Control
## The big archery target on the Main tab: coral and cream rings with a 3D lip, a gold
## bullseye (Home puts the level number on it), two arrows stuck in it and a glow ring
## that keeps pulsing outwards. Tapping it shakes the target and emits `pressed`.

signal pressed

const RINGS: Array[Array] = [[1.0, "#fff1f2"], [0.82, "#fb7185"], [0.66, "#fff1f2"], [0.5, "#fb7185"]]
const BULLSEYE := 0.36
const ART := preload("res://icons/fx/home_target.png")
# Arrows: where the tip sits (in target radii from the centre) and where the shaft points.
const ARROWS: Array[Array] = [[Vector2(0.42, -0.3), Vector2(0.72, -0.69)], [Vector2(-0.54, 0.24), Vector2(-0.9, -0.44)]]

var _t := 0.0
var _hit := 0.0


func _process(delta: float) -> void:
	_t += delta
	_hit = maxf(0.0, _hit - delta * 3.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_hit = 1.0
	elif Rect2(Vector2.ZERO, size).has_point(mb.position):
		pressed.emit()
	accept_event()


## Radius of the gold bullseye, for sizing the level number on top of it.
func bullseye_radius() -> float:
	return _radius() * BULLSEYE


func _radius() -> float:
	return minf(size.x, size.y) / 2.0 - 46.0


func _draw() -> void:
	var r := _radius()
	var c := size / 2.0 + Vector2(sin(_t * 40.0) * _hit * 7.0, 0)

	var k := fmod(_t, 2.2) / 2.2
	draw_arc(c, r * (1.0 + 0.16 * k), 0.0, TAU, 72, Color(1.0, 0.82, 0.35, (1.0 - k) * 0.45), 6.0, true)
	# The target itself is drawn in Affinity: 620 px art, target centre (310, 290), radius 236.
	var k_art := r / 236.0
	var art_pos := c - Vector2(310, 290) * k_art
	draw_texture_rect(ART, Rect2(art_pos, Vector2(620, 620) * k_art), false)

	for i in 3:
		var a := _t * 0.6 + i * TAU / 3.0
		_star(c + Vector2(cos(a), sin(a)) * r * 1.12, 9.0 + 3.0 * sin(_t * 3.0 + i))


func _star(p: Vector2, s: float) -> void:
	var pts := PackedVector2Array()
	for j in 8:
		var a := j * TAU / 8.0 - PI / 2.0
		pts.append(p + Vector2(cos(a), sin(a)) * (s if j % 2 == 0 else s * 0.35))
	draw_colored_polygon(pts, Color("#fde68a"))
