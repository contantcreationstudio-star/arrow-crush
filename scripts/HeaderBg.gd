class_name HeaderBg
extends MarginContainer
## The in-game header card, drawn behind its children: a royal-violet panel with a thick
## 3D lip, a ribbon behind the level name (tinted by difficulty), an inset plate behind
## the moves counter, and chunky 3D buttons. The layout itself lives in GameScene.tscn.

const TOP := Color("#5b21b6")
const BOTTOM := Color("#7c3aed")
const LIP := Color("#3b0764")
const LIP_LIGHT := Color("#c4b5fd")
const RADIUS := 34.0
const LIP_H := 8.0

## Ribbon colours [face, dark edge] - set from the level's difficulty.
var ribbon_face := Color("#22c55e"):
	set(c):
		ribbon_face = c
		queue_redraw()
var ribbon_dark := Color("#15803d"):
	set(c):
		ribbon_dark = c
		queue_redraw()

## Moves / time nearly gone: the moves plate glows and throbs red.
var alarm := false:
	set(v):
		alarm = v
		set_process(v)
		queue_redraw()

var _ribbon_node: Control
var _plate_node: Control
var _caption_node: Control
var _t := 0.0


func _ready() -> void:
	_ribbon_node = get_node("%DifficultyBadge")
	_plate_node = get_node("%BigNumber").get_parent()
	_caption_node = get_node("%BigCaption")
	set_process(false)
	for n: Control in [self, _ribbon_node, _plate_node, _caption_node]:
		n.item_rect_changed.connect(queue_redraw)
	_ribbon_node.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	for b in find_children("*", "Button", true, false):
		_style_round_button(b as Button)


func _draw() -> void:
	var h := size.y - LIP_H
	# Soft shadow under the card, then the lip, then the face.
	for i in 3:
		draw_colored_polygon(_shape(h + LIP_H + 4.0 + i * 3.0), Color(0.1, 0.0, 0.25, 0.07))
	draw_colored_polygon(_shape(h + LIP_H), LIP)
	var face := _shape(h)
	var colors := PackedColorArray()
	for p in face:
		colors.append(TOP.lerp(BOTTOM, clampf(p.y / maxf(h, 1.0), 0.0, 1.0)))
	draw_polygon(face, colors)
	# A light edge where the face meets the lip.
	var edge := PackedVector2Array()
	for p in face:
		if p.y > h - RADIUS - 0.5:
			edge.append(p)
	if edge.size() >= 2:
		draw_polyline(edge, Color(LIP_LIGHT, 0.55), 3.0, true)
	_draw_plate()
	_draw_ribbon()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## The moves medallion (drawn in Affinity): a gold-framed violet shield with a ribbon
## behind the MOVES / TIME caption. Glows and blushes red while `alarm` is on.
const PLATE := preload("res://icons/fx/hud_moves_plate.png")

func _draw_plate() -> void:
	var col := _local_rect(_plate_node)
	var cap := _local_rect(_caption_node)
	var top := col.position.y - 8.0
	var h := (cap.get_center().y - top) / (237.0 / 300.0)
	var w := h * 248.0 / 300.0
	var r := Rect2(col.get_center().x - w / 2.0, top, w, h)
	var throb := 0.5 + 0.5 * sin(_t * 9.0) if alarm else 0.0
	if alarm:
		_round_rect(r.grow(4.0 + 4.0 * throb), 30.0, Color(1.0, 0.25, 0.35, 0.22 + 0.25 * throb))
	draw_texture_rect(PLATE, r, false, Color.WHITE.lerp(Color("#ffb4c0"), throb * 0.6))


## The level pill (UI kit v2): a chunky glossy pill with a 3D lip behind the level name,
## gold on easy / normal levels, orange or red on hard ones.
func _draw_ribbon() -> void:
	var r := _local_rect(_ribbon_node)
	if r.size.x <= 0.0:
		return
	var band := Rect2(r.position.x - 22, r.get_center().y - 24, r.size.x + 44, 48)
	_round_rect(Rect2(band.position + Vector2(0, 7), band.size), 24.0, Color(0.1, 0.0, 0.25, 0.3))  # shadow
	_round_rect(Rect2(band.position + Vector2(0, 5), band.size), 24.0, ribbon_dark)                   # lip
	_round_rect(band, 24.0, ribbon_face)
	_round_rect(Rect2(band.position + Vector2(14, 5), Vector2(band.size.x - 28, band.size.y * 0.34)), 9.0,
		Color(1, 1, 1, 0.32))                                                                       # gloss


func _local_rect(node: Control) -> Rect2:
	var xf := get_global_transform().affine_inverse()
	var g := node.get_global_rect()
	return Rect2(xf * g.position, g.size)


func _round_rect(r: Rect2, radius: float, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	box.anti_aliasing = true
	draw_style_box(box, r)


## Card outline down to `h`: square top, rounded bottom corners.
func _shape(h: float) -> PackedVector2Array:
	var w := size.x
	var r := minf(RADIUS, minf(w, h) / 2.0)
	var pts := PackedVector2Array([Vector2(0, -20), Vector2(w, -20)])
	for i in 13:
		var a := i * (PI / 2.0) / 12.0
		pts.append(Vector2(w - r + cos(a) * r, h - r + sin(a) * r))
	for i in 13:
		var a := PI / 2.0 + i * (PI / 2.0) / 12.0
		pts.append(Vector2(r + cos(a) * r, h - r + sin(a) * r))
	return pts


## Chunky round button: pale face, violet 3D lip that squashes when pressed.
func _style_round_button(b: Button) -> void:
	var states := {"normal": [Color("#f5f3ff"), 7], "hover": [Color("#ede9fe"), 7],
		"pressed": [Color("#ddd6fe"), 2], "focus": [Color("#f5f3ff"), 7]}
	for state: String in states:
		var box := StyleBoxFlat.new()
		box.bg_color = states[state][0]
		box.set_corner_radius_all(40)
		box.border_color = Color("#6d28d9")
		box.border_width_bottom = states[state][1]
		box.content_margin_top = 7 - states[state][1]
		box.anti_aliasing = true
		box.shadow_color = Color(0.1, 0.0, 0.25, 0.25)
		box.shadow_size = 4
		box.shadow_offset = Vector2(0, 3)
		b.add_theme_stylebox_override(state, box)
	b.add_theme_color_override("icon_normal_color", Color("#4c1d95"))
	b.add_theme_color_override("icon_pressed_color", Color("#4c1d95"))
	b.add_theme_color_override("icon_hover_color", Color("#4c1d95"))
	b.focus_mode = Control.FOCUS_NONE
