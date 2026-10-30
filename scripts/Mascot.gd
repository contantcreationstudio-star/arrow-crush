class_name Mascot
extends Control
## "Archie", the archer mascot in the header portrait: a round golden face under a
## green archer's hat with a red feather. He watches the game:
##   react("happy" | "wow" | "sad" | "win") - a short reaction with a hop
##   worried = true                       - sweats while moves / time / hearts run low

const FACE := Color("#fcd34d")
const FACE_RIM := Color("#d97706")
const HAT := Color("#16a34a")
const HAT_DARK := Color("#166534")
const FEATHER := Color("#ef4444")
const INK := Color("#1e1b4b")
const FACES := {"idle": preload("res://icons/fx/mascot_idle.png"), "blink": preload("res://icons/fx/mascot_blink.png"),
	"happy": preload("res://icons/fx/mascot_happy.png"), "wow": preload("res://icons/fx/mascot_wow.png"),
	"sad": preload("res://icons/fx/mascot_sad.png"), "win": preload("res://icons/fx/mascot_win.png"),
	"worried": preload("res://icons/fx/mascot_worried.png")}
const FRAME := preload("res://icons/fx/hud_frame.png")

var worried := false

var _mood := ""          # current short reaction ("" = idle / worried)
var _mood_left := 0.0
var _t := 0.0
var _hop := 0.0          # 1 right after a reaction, fades to 0
var _next_blink := 2.5


func react(mood: String) -> void:
	if _mood == "win" and mood != "win":
		return  # stay happy on the win screen
	_mood = mood
	_mood_left = 99.0 if mood == "win" else 1.4
	_hop = 1.0


## Back to idle (a new level starts).
func calm() -> void:
	_mood = ""
	_mood_left = 0.0
	worried = false


func _process(delta: float) -> void:
	_t += delta
	_mood_left -= delta
	if _mood_left <= 0.0:
		_mood = ""
	_hop = maxf(0.0, _hop - delta * 1.6)
	_next_blink -= delta
	if _next_blink < -0.12:
		_next_blink = randf_range(2.0, 4.5)
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var big := minf(size.x, size.y) / 2.0 - 4.0
	# Portrait: a sky and rolling hills clipped to a round window, then the gold frame
	# (Affinity art, soft shading) laid over the window's edge.
	big -= 4.0
	var window := _circle(c, big - 9.0)
	var sky := PackedColorArray()
	for p in window:
		sky.append(Color("#7dd3fc").lerp(Color("#e0f2fe"), clampf((p.y - (c.y - big)) / (2.0 * big), 0.0, 1.0)))
	draw_polygon(window, sky)
	for hill in [[Vector2(-0.45, 1.05), 0.75, Color("#4ade80")], [Vector2(0.5, 1.15), 0.8, Color("#22c55e")]]:
		for piece in Geometry2D.intersect_polygons(_circle(c + hill[0] * big, hill[1] * big), window):
			draw_colored_polygon(piece, hill[2])
	draw_arc(c, big - 9.0, 0.0, TAU, 64, Color(0.1, 0.0, 0.25, 0.25), 3.0, true)

	var mood := _mood if _mood != "" else ("worried" if worried else "idle")
	if mood == "idle" and _next_blink < 0.0:
		mood = "blink"
	var hop := -absf(sin(_t * 14.0)) * 12.0 * _hop
	var tex: Texture2D = FACES.get(mood, FACES["idle"])
	# The portrait art (drawn in Affinity) fills the window and is clipped to it.
	var side := (big - 9.0) * 2.0 * 1.32
	var rect := Rect2(c - Vector2(side, side) / 2.0 + Vector2(0, -side * 0.06 + sin(_t * 2.0) * 2.0 + hop), Vector2(side, side))
	var uvs := PackedVector2Array()
	for p in window:
		uvs.append((p - rect.position) / rect.size)
	draw_polygon(window, PackedColorArray([Color.WHITE]), uvs, tex)
	# Frame texture: 256 px, window radius 82 px, so scale it to cover the window's rim.
	var fs := (big - 7.0) / 82.0 * 256.0
	draw_texture_rect(FRAME, Rect2(c - Vector2(fs, fs) / 2.0, Vector2(fs, fs)), false)
	if mood == "win" or mood == "wow":
		for i in 4:
			var a := _t * 1.5 + i * TAU / 4.0
			_star(c + Vector2(cos(a), sin(a)) * big * 0.8, big * 0.09 * (1.0 + 0.3 * sin(_t * 8.0 + i)))


func _draw_eyes(fc: Vector2, fr: float, mood: String) -> void:
	for side in [-1.0, 1.0]:
		var e := fc + Vector2(side * fr * 0.34, -fr * 0.1)
		if mood == "happy" or mood == "win":
			draw_arc(e + Vector2(0, fr * 0.05), fr * 0.14, PI * 1.1, PI * 1.9, 12, INK, fr * 0.08, true)
		elif _next_blink < 0.0 and mood != "wow":
			draw_line(e - Vector2(fr * 0.13, 0), e + Vector2(fr * 0.13, 0), INK, fr * 0.07, true)
		else:
			var r := fr * (0.2 if mood == "wow" else 0.16)
			var look := Vector2(0, fr * 0.04) if mood == "sad" else Vector2(sin(_t * 0.7) * fr * 0.03, 0)
			draw_circle(e, r, Color.WHITE, true, -1.0, true)
			draw_circle(e + look, r * 0.6, INK, true, -1.0, true)
			draw_circle(e + look + Vector2(-r * 0.2, -r * 0.25), r * 0.2, Color.WHITE, true, -1.0, true)
		if mood == "worried" or mood == "sad":
			# Brows tilted up towards the middle.
			var inner := e + Vector2(-side * fr * 0.12, -fr * 0.3)
			var outer := e + Vector2(side * fr * 0.16, -fr * 0.22)
			draw_line(inner, outer, INK, fr * 0.06, true)


func _draw_mouth(fc: Vector2, fr: float, mood: String) -> void:
	var m := fc + Vector2(0, fr * 0.38)
	match mood:
		"happy", "win":
			var pts := PackedVector2Array()
			for i in 13:
				var a := i * PI / 12.0
				pts.append(m + Vector2(cos(a) * fr * 0.32, sin(a) * fr * 0.3 - fr * 0.05))
			draw_colored_polygon(pts, Color("#7f1d1d"))
			draw_circle(m + Vector2(0, fr * 0.14), fr * 0.12, Color("#fb7185"), true, -1.0, true)
		"wow":
			draw_circle(m + Vector2(0, fr * 0.04), fr * 0.13, Color("#7f1d1d"), true, -1.0, true)
		"sad":
			draw_arc(m + Vector2(0, fr * 0.2), fr * 0.22, PI * 1.2, PI * 1.8, 12, INK, fr * 0.07, true)
		"worried":
			var wave := PackedVector2Array()
			for i in 7:
				wave.append(m + Vector2(-fr * 0.24 + i * fr * 0.08, sin(i * 1.6 + _t * 6.0) * fr * 0.04))
			draw_polyline(wave, INK, fr * 0.06, true)
		_:
			draw_arc(m - Vector2(0, fr * 0.12), fr * 0.26, PI * 0.2, PI * 0.8, 12, INK, fr * 0.07, true)


## Archer's hat tipped to one side, with a red feather.
func _draw_hat(fc: Vector2, fr: float) -> void:
	var left := fc + Vector2(-fr * 1.05, -fr * 0.5)
	var right := fc + Vector2(fr * 0.95, -fr * 0.62)
	var tip := fc + Vector2(fr * 0.35, -fr * 1.55)
	var feather_base := fc + Vector2(-fr * 0.35, -fr * 0.75)
	var sway := sin(_t * 3.0) * 0.12
	var f_dir := Vector2.from_angle(-PI * 0.72 + sway)
	var f_tip := feather_base + f_dir * fr * 1.0
	var f_side := f_dir.orthogonal() * fr * 0.16
	draw_colored_polygon(PackedVector2Array([feather_base, feather_base.lerp(f_tip, 0.5) + f_side, f_tip,
		feather_base.lerp(f_tip, 0.5) - f_side]), FEATHER)
	draw_line(feather_base, f_tip, Color("#991b1b"), fr * 0.04, true)
	draw_colored_polygon(PackedVector2Array([left, tip, right]), HAT)
	draw_colored_polygon(PackedVector2Array([left, tip, tip.lerp(left, 0.15) + Vector2(fr * 0.12, 0)]), Color(1, 1, 1, 0.12))
	draw_line(left + Vector2(fr * 0.05, -fr * 0.02), right + Vector2(-fr * 0.05, 0), HAT_DARK, fr * 0.16, true)


func _circle(center: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 48:
		pts.append(center + Vector2.from_angle(i * TAU / 48.0) * r)
	return pts


func _star(p: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := i * PI / 4.0 + _t
		pts.append(p + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.38))
	draw_colored_polygon(pts, Color("#fde047"))
