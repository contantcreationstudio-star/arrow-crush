class_name ArrowPath
extends Node2D
## One bent arrow in the maze: a snake-like line through grid cells with 90-degree
## turns and an arrowhead at the front. Every arrow has a colour (same colours crush
## each other) and may be a special arrow (Drill, Bomb, Laser, Rainbow).
##
## How it is built:
##   Path2D       - the full route: every corner of the body (tail -> head), then a
##                  straight run from the head out past the board edge.
##   Line2D       - draws only a window of that route. Sliding the window forward makes
##                  the whole body follow its own bends, like a snake.
##   PathFollow2D - rides the front of the window and carries (and turns) the arrowhead.
##   _glow/_decor - pulsing halo and the special-arrow markings (stripes, bomb, cross,
##                  rainbow) drawn along the visible line.
##
## MazeBoard finds which arrow was tapped (distance_to_point), decides what happens
## (escape, crush, bump, special effect) and calls the animations below.

signal escaped(arrow: ArrowPath)

enum Special { NONE, DRILL, BOMB, LASER, RAINBOW }

## Arrow colours. Arrows of the same colour crush each other on contact.
const ARROW_COLORS: Array[Color] = [
	Color("#e11d48"),  # ruby
	Color("#2563eb"),  # blue
	Color("#059669"),  # emerald
	Color("#d97706"),  # amber
	Color("#7c3aed"),  # violet
	Color("#0891b2"),  # teal
	Color("#eab308"),  # gold - golden arrows only (LevelGenerator.GOLD)
]
const SPECIAL_NAMES: Array[String] = ["", "DRILL ARROW", "BOMB ARROW", "LASER ARROW", "RAINBOW ARROW"]
const COLOR_POWER := Color("#f59e0b")
const FADE_CELLS := 0.6   # length of the fade-out zone, far off screen
const OFF_SCREEN := 1.3   # how far past the board an escaping arrow flies, in board sizes
const FLY_Z := 30         # escaping arrows draw above the HUD
const ANTICIPATION := 0.08  # seconds the arrow pulls back before it launches (wind-up)
const WIND_UP := 0.12       # cells it pulls back before a bump or crush
const TRAIL_POINTS := 7     # head positions kept for the speed streak
const GLINT_PERIOD := 5.5   # seconds between the light glints that run along a resting arrow
const GLINT_TIME := 0.55    # how long one glint takes from tail to head
const LIGHT := Vector2(-0.45, -0.89)  # screen-space light direction (from top-left)
# Special-arrow badges and effect sprites, drawn in Affinity (soft gradients + glow).
const SP_BOMB := preload("res://icons/fx/sp_bomb.png")
const SP_SPARK := preload("res://icons/fx/sp_spark.png")
const SP_LASER := preload("res://icons/fx/sp_laser.png")
const SP_DRILL := preload("res://icons/fx/sp_drill.png")
const SP_RAINBOW := preload("res://icons/fx/sp_rainbow.png")
const SP_ORB := preload("res://icons/fx/sp_orb.png")
const FX_FLARE := preload("res://icons/fx/fx_flare.png")
const BADGE := 1.25         # badge size on the body, in cells
const CURVE := 0.5          # radius of the rounded bends, in cells (0.5 = a zigzag becomes a smooth wave)
## Chunky look (2026-10-30): a thicker tube and a bigger, bolder head, so arrows read as
## arrows even on big boards. All sizes are shares of one cell.
const BODY := 0.33          # coloured tube
const RIM := 0.08           # dark outline added around the tube
const HEAD_TIP := 0.42      # how far the tip sits in front of the head cell's centre
const HEAD_BACK := 0.17     # how far back the barbs sweep
const HEAD_HALF := 0.38     # half the head's width (barb to barb)
const ARC_STEPS := 8        # line segments per rounded bend

var cells: Array[Vector2i] = []   # grid cells, tail first, head last
var dir := Vector2i.RIGHT         # direction the head points / moves
var cell_size := 100.0
var busy := false                 # true while animating (ignores taps)
var color_index := 0
var special := Special.NONE
var ice := 0                        # layers of ice: a frozen arrow can't move (MazeBoard draws it)
var golden := false:               # goal arrow: must fly out; never crushed, shrugs off blasts
	set(v):
		golden = v
		_glow.visible = _glows() and _line.visible
var timer := 0                      # bonus arrow: moves left to fly it out for coins (0 = none)
var link_id := -1                   # linked arrows share an id and only leave together
var flip := false                   # turns around after every move
var badge_hidden := false:          # the board is animating this arrow's badge itself (wind-up)
	set(v):
		badge_hidden = v
		_decor.queue_redraw()
var prism := false:                 # any colour crushes it; a chain goes on in the prism's colour
	set(v):
		prism = v
		_glow.visible = _glows() and _line.visible
		_decor.queue_redraw()
var exit_cell := Vector2i.ZERO      # first cell outside the board on the way out
var exit_dir := Vector2i.RIGHT      # direction it leaves the board in (mirrors can turn it)

var _cols := 0
var _rows := 0
var _lane: Array[Vector2i] = []      # cells in front of the head to the edge (bent by mirrors)
var _lane_dirs: Array[Vector2i] = [] # direction of travel through each lane cell
var _path := Path2D.new()
var _follow := PathFollow2D.new()
var _glow := Line2D.new()          # soft halo under special arrows
var _shadow := Line2D.new()        # soft drop shadow, makes the arrow sit above the board
var _outline := Line2D.new()       # dark rim around the body (candy-style outline)
var _line := Line2D.new()
var _low := Line2D.new()           # darker band on the lower side: makes the body a round tube
var _hi := Line2D.new()            # lighter band on the upper side
var _shine := Line2D.new()         # thin specular streak (glossy look)
var _head_shadow := Polygon2D.new()
var _head_rim := Polygon2D.new()   # dark outline behind the arrowhead
var _facets: Array[Polygon2D] = [] # three lit faces: the arrowhead reads as a cut gem
var _facet_normals: Array[Vector2] = []
var _glint_phase := 0.0
var _trail: Array[Vector2] = []    # recent head positions while sliding
var _fade_line := Line2D.new()     # the part of the arrow crossing the maze edge
var _decor := Node2D.new()         # special-arrow markings
var _fletch := Node2D.new()        # tail feathers, drawn under the body
var _head := Polygon2D.new()
var _corners := PackedVector2Array()
var _body_pts := PackedVector2Array()  # the rounded body route at rest, tail -> head (board coordinates)
var _corner_offsets := PackedFloat32Array()  # distance along the route of each corner
var _body_length := 0.0
var _exit_length := 0.0   # how far the window must slide to leave the maze
var _edge_offset := 0.0   # distance along the route where the maze edge is
var _offset := 0.0        # how far the arrow has slid along its route
var _reveal := 1.0        # 0..1, used by the "crawl in" intro
var _color := Color.BLACK
var _fade_gradient := Gradient.new()
var _time := 0.0
var _move_tween: Tween
var _color_tween: Tween
var _press := 0.0             # 0..1 finger-down dip (UI kit v2)
var _press_tween: Tween
var _red := 0.0               # 0..1 red rim flash after a bump
var _base_widths := {}       # Line2D -> width at rest


func setup(p_cells: Array[Vector2i], p_cell_size: float, cols: int, rows: int,
		p_color: int = 0, p_special: Special = Special.NONE, mirrors: Dictionary = {}) -> void:
	cells = p_cells
	cell_size = p_cell_size
	_cols = cols
	_rows = rows
	color_index = p_color
	dir = cells[-1] - cells[-2]

	# Body route: the cell centres where the arrow turns, with every turn rounded into a
	# smooth arc - so zigzags read as waves and U-turns as loops, not sharp steps.
	var bends := PackedVector2Array()
	for i in cells.size():
		var is_end := i == 0 or i == cells.size() - 1
		if is_end or cells[i] - cells[i - 1] != cells[i + 1] - cells[i]:
			bends.append(_cell_center(cells[i]))
	_corners = _round_bends(bends, cell_size * CURVE)
	_body_pts = _corners.duplicate()
	_body_length = 0.0
	for i in range(1, _corners.size()):
		_body_length += _corners[i - 1].distance_to(_corners[i])

	var lane := LevelGenerator.trace(head(), dir, mirrors, cols, rows)
	_lane = lane.cells
	_lane_dirs = lane.dirs
	exit_cell = lane.exit
	exit_dir = lane.exit_dir
	var to_edge := _lane.size()
	# An escaping arrow flies on past the board and off the whole screen (over the HUD),
	# even with the board fully zoomed out: the route runs OFF_SCREEN board-widths past
	# the edge, and the fade zone sits out there, where nobody sees it.
	var off_screen := maxf(cols, rows) * OFF_SCREEN + 4.0
	_edge_offset = _body_length + (to_edge + 0.1 + off_screen) * cell_size
	_exit_length = _edge_offset + FADE_CELLS * cell_size

	# The way out: a corner at every mirror, then straight on past the edge.
	for c in _lane:
		if mirrors.has(c):
			_corners.append(_cell_center(c))
	_corners.append(_corners[-1] + Vector2(exit_dir) * (_exit_length + cell_size))

	var curve := Curve2D.new()
	curve.bake_interval = 4.0  # long routes (they run far off screen): coarser baking is plenty
	for p in _corners:
		curve.add_point(p)
	_path.curve = curve
	# Measured along the route (not get_closest_offset): a mirrored lane may cross itself.
	_corner_offsets.clear()
	var along := 0.0
	for i in _corners.size():
		if i > 0:
			along += _corners[i - 1].distance_to(_corners[i])
		_corner_offsets.append(along)

	for l: Line2D in _body_lines():
		l.joint_mode = Line2D.LINE_JOINT_ROUND
		l.begin_cap_mode = Line2D.LINE_CAP_ROUND
		l.end_cap_mode = Line2D.LINE_CAP_ROUND
		l.antialiased = true
		add_child(l)
	var s := cell_size
	# UI kit v2: a chunkier tube with a darker rim and a violet-tinted drop shadow.
	_glow.width = s * 0.62
	_line.width = s * BODY
	_outline.width = _line.width + s * RIM
	_shadow.width = _outline.width + s * 0.02
	_shadow.default_color = Color(0.16, 0.08, 0.43, 0.22)
	_shadow.position = Vector2(s * 0.035, s * 0.08)
	# Bands shifted toward / away from the light, kept inside the body.
	_low.width = _line.width * 0.55
	_low.position = -LIGHT * s * 0.035
	_hi.width = _line.width * 0.42
	_hi.position = LIGHT * s * 0.032
	_shine.width = _line.width * 0.26
	_shine.position = LIGHT * s * 0.055
	for l: Line2D in _body_lines():
		_base_widths[l] = l.width
	_glint_phase = randf() * GLINT_PERIOD
	set_process(true)
	_fletch.draw.connect(_draw_fletching)
	add_child(_fletch)
	move_child(_fletch, _outline.get_index())

	_fade_line.width = _line.width
	_fade_line.begin_cap_mode = Line2D.LINE_CAP_NONE
	_fade_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_fade_line.antialiased = true
	_fade_line.gradient = _fade_gradient
	_fade_line.visible = false
	add_child(_fade_line)

	_decor.draw.connect(_draw_decor)
	_decor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_decor)

	# Notched arrowhead (UI kit v2): tip, two swept-back barbs and a notch at the back.
	var tip := Vector2(s * HEAD_TIP, 0)
	var barb_l := Vector2(-s * HEAD_BACK, -s * HEAD_HALF)
	var barb_r := Vector2(-s * HEAD_BACK, s * HEAD_HALF)
	var notch := Vector2(-s * 0.05, 0)
	var head_shape := _rounded_polygon([tip, barb_l, notch, barb_r], s * 0.045)
	_head.polygon = head_shape
	_head.antialiased = true
	var rim_shape: PackedVector2Array = Geometry2D.offset_polygon(head_shape, s * RIM * 0.5, Geometry2D.JOIN_ROUND)[0]
	_head_rim.polygon = rim_shape
	_head_rim.antialiased = true
	_head_rim.show_behind_parent = true
	_head.add_child(_head_rim)
	_head_shadow.polygon = rim_shape
	_head_shadow.color = _shadow.default_color
	_head_shadow.antialiased = true
	# Two halves, each lit by how much it faces the light (upper half bright, lower half shaded).
	var inner := [tip.lerp(notch, 0.12), barb_l.lerp(notch, 0.22), notch.lerp(tip, 0.18), barb_r.lerp(notch, 0.22)]
	for half in [[inner[0], inner[1], inner[2]], [inner[0], inner[2], inner[3]]]:
		var f := Polygon2D.new()
		f.polygon = PackedVector2Array(half)
		f.antialiased = true
		_head.add_child(f)
		_facets.append(f)
		_facet_normals.append(Vector2(0, -1) if half[1] == inner[1] else Vector2(0, 1))
	# A crisp light edge along the upper barb, like the gloss stripe on the body.
	var edge := Line2D.new()
	edge.points = PackedVector2Array([tip.lerp(barb_l, 0.12), tip.lerp(barb_l, 0.78)])
	edge.width = s * 0.04
	edge.default_color = Color(1, 1, 1, 0.6)
	edge.begin_cap_mode = Line2D.LINE_CAP_ROUND
	edge.end_cap_mode = Line2D.LINE_CAP_ROUND
	edge.antialiased = true
	_head.add_child(edge)
	_follow.rotates = true
	_follow.loop = false
	add_child(_path)
	_path.add_child(_follow)
	_follow.add_child(_head_shadow)
	_follow.add_child(_head)

	set_special(p_special, false)
	_apply_color(base_color())
	_refresh()


func head() -> Vector2i:
	return cells[-1]


## Where the special badge sits (board coordinates): halfway along the visible body.
func badge_center() -> Vector2:
	if _line.points.size() >= 2:
		return _point_at_fraction(_line.points, 0.5)
	return _cell_center(cells[cells.size() / 2])


## Badge width in board px; it keeps a readable size on screen when a big board is zoomed out.
func badge_size() -> float:
	var on_screen := maxf(get_global_transform().get_scale().x, 0.01)
	return clampf(56.0 / on_screen, cell_size * BADGE, cell_size * 1.6)


## The arrow's rounded body line where it rests (the board paints it when it leaves).
func body_points() -> PackedVector2Array:
	return _body_pts


func base_color() -> Color:
	return ARROW_COLORS[color_index % ARROW_COLORS.size()]


## Turns this arrow into a special arrow (or back to normal with Special.NONE).
func set_special(kind: Special, animate: bool = true) -> void:
	special = kind
	_glow.visible = _glows() and _line.visible
	_glow.default_color = Color(base_color(), 0.25)
	_decor.queue_redraw()
	if animate and special != Special.NONE:
		_glow.width = cell_size * 1.2
		create_tween().tween_property(_glow, "width", cell_size * 0.5, 0.5) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Special and golden arrows wear a pulsing halo.
func _glows() -> bool:
	return special != Special.NONE or golden or prism


func _process(delta: float) -> void:
	_time += delta
	if _glows():
		_glow.default_color = Color(base_color(), 0.2 + 0.12 * sin(_time * 5.0))
		_decor.queue_redraw()
	elif _glint_t() < GLINT_TIME + 0.1:
		_decor.queue_redraw()


## Seconds since this arrow's latest glint started.
func _glint_t() -> float:
	return fposmod(_time + _glint_phase, GLINT_PERIOD)


# --- Tap detection ---------------------------------------------------------------------------

## Distance from `local_pos` to the visible line or arrowhead.
func distance_to_point(local_pos: Vector2) -> float:
	var best := local_pos.distance_to(_follow.position)
	var pts := _line.points
	for i in pts.size() - 1:
		var closest := Geometry2D.get_closest_point_to_segment(local_pos, pts[i], pts[i + 1])
		best = minf(best, closest.distance_to(local_pos))
	return best


# --- Intersection check -------------------------------------------------------------------------

## Walks the exit lane in front of the head (turning at mirrors).
## Returns -1 if the lane is clear to the maze edge, otherwise the number of free
## cells before the first occupied cell (another arrow, or this arrow's own body):
## that cell is lane_cells()[gap].
## `occupancy` maps Vector2i cell -> ArrowPath for every arrow still in the maze.
func blocked_gap(occupancy: Dictionary) -> int:
	for gap in _lane.size():
		if occupancy.has(_lane[gap]):
			return gap
	return -1


## Cells in front of the head up to the board edge (do not modify).
func lane_cells() -> Array[Vector2i]:
	return _lane


## Direction of travel through each lane cell (parallel to lane_cells()).
func lane_dirs() -> Array[Vector2i]:
	return _lane_dirs


# --- Animations ----------------------------------------------------------------------------------

## Level start: the arrow crawls in from its tail to its final position.
func play_intro(delay: float) -> void:
	busy = true
	modulate.a = 0.0
	_set_reveal(0.0)
	var t := _new_move_tween()
	t.tween_interval(delay)
	t.tween_property(self, "modulate:a", 1.0, 0.12)
	t.parallel().tween_method(_set_reveal, 0.0, 1.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void: busy = false)


## Lane is clear: slide the whole snake out along its Path2D, then free it.
## With `power` it glows gold (Drill / break-through).
func slide_out(power: bool = false, delay: float = 0.0) -> void:
	busy = true
	var t := _new_move_tween()
	t.tween_interval(delay)
	t.tween_callback(_lift)  # out of the board's clip and over the HUD, on its way off screen
	t.tween_callback(_apply_color.bind(COLOR_POWER if power else _highlight()))
	# Like drawing a bow: a quick pull back (the body squashes a little)...
	t.tween_method(_set_offset, 0.0, -cell_size * 0.14, ANTICIPATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# ...then it shoots away, accelerating hard.
	t.tween_method(_set_offset, -cell_size * 0.14, _exit_length, _slide_duration()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		escaped.emit(self)
		queue_free())


## Seconds after slide_out() starts until the arrow has slid `distance` px
## (matches the pull-back + quad ease-in above). Used to time ripples and smashes.
## Lifts the arrow out of the board area's clipping and above the HUD, keeping where it
## is on screen, so it can fly all the way off the screen.
func _lift() -> void:
	if top_level:
		return
	var g := global_transform
	top_level = true
	global_transform = g
	z_index = FLY_Z


## Back on the board (undo brought it home): under the HUD and clipped again.
func _land() -> void:
	if not top_level:
		return
	top_level = false
	transform = Transform2D.IDENTITY
	z_index = 0


func time_to_slide(distance: float) -> float:
	return ANTICIPATION + _slide_duration() * sqrt(clampf(distance / _exit_length, 0.0, 1.0))


func _slide_duration() -> float:
	return clampf(_exit_length / (cell_size * 40.0), 0.45, 0.95)


## Same-colour crush: rush into the blocker `gap` cells ahead, then break apart.
## `power` (MazeBoard.crush_power: 0 small, 1 normal, 2 big): a big arrow draws back
## further, glows hotter and slams in harder; a small one just flicks forward.
## Returns the moment of impact (seconds from now).
func crush_into(gap: int, delay: float = 0.0, power: int = 1) -> float:
	busy = true
	var reach := gap * cell_size + cell_size * 0.3
	var hit_time: float = (0.07 + gap * 0.035) * [1.0, 1.0, 0.85][power]
	var pull: float = -cell_size * WIND_UP * [0.6, 1.0, 2.0][power]
	var wind: float = ANTICIPATION * [0.8, 1.0, 1.9][power]
	var hot := _highlight() if power < 2 else Color.WHITE.lerp(base_color(), 0.45)
	var t := _new_move_tween()
	t.tween_interval(delay)
	t.tween_callback(_apply_color.bind(hot))
	t.tween_method(_set_offset, 0.0, pull, wind).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_method(_set_offset, pull, reach, hit_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_append_break(t)
	return delay + wind + hit_time


## Destroyed by a crush, explosion, laser or drill: white-hot flash, then gone.
## The board throws the broken pieces (MazeBoard._shatter_fx) at the same moment.
func shatter(delay: float) -> void:
	busy = true
	var t := _new_move_tween()
	t.tween_interval(delay)
	_append_break(t)


func _append_break(t: Tween) -> void:
	t.tween_callback(_apply_color.bind(Color.WHITE.lerp(base_color(), 0.25)))
	t.tween_interval(0.05)
	t.tween_property(self, "modulate:a", 0.0, 0.08)
	t.tween_callback(queue_free)


## Creep: slide forward `distance` px along the route (into the cells just freed in front),
## like a snake. The board has already put the arrow on its new cells; `done` swaps this
## node for that one when the slide lands.
func creep_forward(distance: float, delay: float, done: Callable) -> void:
	busy = true
	var t := _new_move_tween()
	t.tween_interval(delay)
	t.tween_method(_set_offset, 0.0, distance, 0.2 + distance / cell_size * 0.07) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void:
		done.call()
		queue_free())


## Different-colour blocker: creep up to it, shake on impact, slide back.
## Returns the impact time so the blocker can react in sync.
func bump(gap: int) -> float:
	busy = true
	_apply_color(_highlight())
	var reach := gap * cell_size + cell_size * 0.25
	var hit_time := 0.07 + gap * 0.035
	var perp := Vector2(-dir.y, dir.x) * cell_size * 0.07
	var pull := -cell_size * WIND_UP
	var t := _new_move_tween()
	t.tween_method(_set_offset, 0.0, pull, ANTICIPATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_method(_set_offset, pull, reach, hit_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(_squash_head)
	t.tween_callback(_flash_red)
	t.tween_property(self, "position", perp, 0.04)
	t.tween_property(self, "position", -perp, 0.06)
	t.tween_property(self, "position", Vector2.ZERO, 0.05)
	# Slides back home with a little overshoot, like a spring.
	t.tween_method(_set_offset, reach, 0.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void:
		busy = false
		_fade_color(base_color(), 0.25))
	return ANTICIPATION + hit_time


## Finger down on this arrow: it dips a little and brightens, so the player sees what
## they are about to launch before letting go (UI kit v2). `false` springs it back.
func set_pressed(on: bool) -> void:
	if _press_tween and _press_tween.is_valid():
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.tween_method(_set_press, _press, 1.0 if on else 0.0, 0.06 if on else 0.18) 		.set_trans(Tween.TRANS_SINE if on else Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_press(v: float) -> void:
	_press = v
	for l: Line2D in _base_widths:
		l.width = _base_widths[l] * (1.0 - 0.08 * v)
	_apply_color(_color if busy else base_color())


## Bump impact: the rim glows red for a moment, then cools back.
func _flash_red() -> void:
	var t := create_tween()
	t.tween_method(_set_red, 1.0, 0.0, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _set_red(v: float) -> void:
	_red = v
	_outline.width = _base_widths.get(_outline, _outline.width) + cell_size * 0.05 * v
	_apply_color(_color)


## Impact: the arrowhead flattens against the blocker and springs back.
func _squash_head() -> void:
	_head.scale = Vector2(0.6, 1.35)
	_head_shadow.scale = _head.scale
	var t := create_tween().set_parallel(true)
	t.tween_property(_head, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_head_shadow, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Hit by a different-colour arrow: it wobbles side to side, twice, dying out.
func wobble(delay: float) -> void:
	if busy:
		return
	var perp := Vector2(-dir.y, dir.x) * cell_size * 0.08
	var t := create_tween()
	t.tween_interval(delay)
	for f: float in [1.0, -0.75, 0.45, -0.2, 0.0]:
		t.tween_property(self, "position", perp * f, 0.06).set_trans(Tween.TRANS_SINE)


## Darken briefly when a different-colour arrow crashes into this one.
func flash_blocked(delay: float) -> void:
	if _color_tween and _color_tween.is_valid():
		_color_tween.kill()
	var dark := base_color().darkened(0.5)
	_color_tween = create_tween()
	_color_tween.tween_interval(delay)
	_color_tween.tween_method(_apply_color, base_color(), dark, 0.05)
	_color_tween.tween_method(_apply_color, dark, base_color(), 0.5)


## Hint: pulse bright a few times.
func play_hint(times: int = 3) -> void:
	if _color_tween and _color_tween.is_valid():
		_color_tween.kill()
	_color_tween = create_tween().set_loops(times)
	_color_tween.tween_method(_apply_color, base_color(), _highlight(), 0.2)
	_color_tween.tween_method(_apply_color, _highlight(), base_color(), 0.2)


## Ends a hint pulse early (the player tapped something).
func stop_hint() -> void:
	if _color_tween and _color_tween.is_valid():
		_color_tween.kill()
	_apply_color(base_color())


## "Did you mean me?": one quick bright blink with a little shake (unsure tap).
func nudge() -> void:
	if _color_tween and _color_tween.is_valid():
		_color_tween.kill()
	_color_tween = create_tween()
	_color_tween.tween_method(_apply_color, base_color(), _highlight(), 0.1)
	_color_tween.tween_method(_apply_color, _highlight(), base_color(), 0.3)
	var perp := Vector2(-dir.y, dir.x) * cell_size * 0.05
	var t := create_tween()
	t.tween_property(self, "position", perp, 0.04)
	t.tween_property(self, "position", -perp, 0.06)
	t.tween_property(self, "position", Vector2.ZERO, 0.05)


## Undo: start outside the maze and slide back in to the original cells.
func play_return() -> void:
	busy = true
	_lift()
	_set_offset(_exit_length)
	modulate.a = 0.0
	_apply_color(_highlight())
	var t := _new_move_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.15)
	t.parallel().tween_method(_set_offset, _exit_length, 0.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void:
		_land()
		busy = false
		_fade_color(base_color(), 0.3))


# --- Special-arrow markings --------------------------------------------------------------------------

func _draw_decor() -> void:
	_draw_trail()
	if not _line.visible:
		return
	var pts := _line.points
	if pts.size() < 2:
		return
	var s := cell_size
	_draw_glint(pts)
	if prism and special == Special.NONE:
		_draw_prism(_point_at_fraction(pts, 0.5))
	if special == Special.NONE or badge_hidden:
		return
	var mid := _point_at_fraction(pts, 0.5)
	var badge := badge_size()
	match special:
		Special.DRILL:
			# Gold spiral bands scrolling along the body (the drill spinning) ...
			var step := s * 0.32
			for sample in _samples_along(pts, step, fposmod(_time * s * 1.8, step)):
				var normal := Vector2(-sample[1].y, sample[1].x)
				var slant: Vector2 = sample[1] * s * 0.05
				_decor.draw_line(sample[0] - normal * s * 0.1 - slant, sample[0] + normal * s * 0.1 + slant,
					Color(1.0, 0.86, 0.45, 0.95), s * 0.06, true)
			# ... and the drill bit, facing the way the body runs, buzzing.
			var d := _dir_at_fraction(pts, 0.5)
			_draw_sprite(SP_DRILL, mid, d.angle(), badge * 1.12, Vector2(1.0, 1.0 + 0.07 * sin(_time * 38.0)))
		Special.BOMB:
			# A bomb that breathes, with a sputtering fuse.
			var k := 1.0 + 0.06 * sin(_time * 6.0)
			_draw_sprite(SP_BOMB, mid, 0.0, badge * k)
			var tip := mid + Vector2(94.0, -98.0) / 256.0 * badge * k
			var flick := 0.75 + 0.4 * absf(sin(_time * 23.0)) + 0.15 * sin(_time * 57.0)
			_draw_sprite(SP_SPARK, tip, _time * 9.0, badge * 0.55 * flick)
		Special.LASER:
			# The red cross orb, charged: a slowly turning flare glows behind it.
			var pulse := 0.5 + 0.5 * sin(_time * 5.0)
			_draw_sprite(FX_FLARE, mid, _time * 1.2, badge * (1.5 + 0.2 * pulse), Vector2.ONE,
				Color(1.0, 0.55, 0.65, 0.45 + 0.35 * pulse))
			_draw_sprite(SP_LASER, mid, 0.0, badge * (1.0 + 0.04 * pulse))
		Special.RAINBOW:
			# Shimmering rainbow running along the body.
			var line_pts := PackedVector2Array()
			var colors := PackedColorArray()
			var i := 0
			for sample in _samples_along(pts, s * 0.12):
				line_pts.append(sample[0])
				colors.append(Color.from_hsv(fposmod(i * 0.06 - _time * 0.5, 1.0), 0.75, 0.95))
				i += 1
			if line_pts.size() >= 2:
				_decor.draw_polyline_colors(line_pts, colors, _line.width, true)
			# Little stars twinkling along the rainbow, each on its own beat.
			for k in 3:
				var tw := maxf(0.0, sin(_time * 3.2 + k * 2.1))
				if tw > 0.05:
					_draw_sprite(FX_FLARE, _point_at_fraction(pts, 0.2 + 0.3 * k), _time * 0.8 + k,
						s * 0.75 * tw, Vector2.ONE, Color(1, 1, 1, 0.95 * tw))


## Draws `tex` centred on `pos`, `size` px wide (before `sc`), turned by `rot`.
func _draw_sprite(tex: Texture2D, pos: Vector2, rot: float, size: float, sc := Vector2.ONE,
		tint := Color.WHITE) -> void:
	var k := size / tex.get_width()
	_decor.draw_set_transform(pos, rot, sc * k)
	_decor.draw_texture(tex, -tex.get_size() / 2.0, tint)
	_decor.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Direction of the polyline at fraction `f` of its length.
func _dir_at_fraction(pts: PackedVector2Array, f: float) -> Vector2:
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var want := total * f
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if want <= seg and seg > 0.0:
			return (pts[i + 1] - pts[i]) / seg
		want -= seg
	return Vector2(dir)


## Prism arrow: a cut crystal on the body whose four faces slowly cycle through the
## rainbow, with a twinkle - "this one takes any colour".
func _draw_prism(mid: Vector2) -> void:
	var s := cell_size
	var w := s * 0.27
	var h := s * 0.36
	var gem := [mid + Vector2(0, -h), mid + Vector2(w, 0), mid + Vector2(0, h), mid + Vector2(-w, 0)]
	var rim := Geometry2D.offset_polygon(PackedVector2Array(gem), s * 0.035, Geometry2D.JOIN_ROUND)
	if not rim.is_empty():
		_decor.draw_colored_polygon(rim[0], Color("#1e1b4b"))
	for k in 4:
		var face := Color.from_hsv(fposmod(k * 0.25 + _time * 0.18, 1.0), 0.6, 1.0)
		_decor.draw_colored_polygon(PackedVector2Array([mid, gem[k], gem[(k + 1) % 4]]), face)
	_decor.draw_line(gem[3].lerp(gem[0], 0.2), gem[3].lerp(gem[0], 0.8), Color(1, 1, 1, 0.85), s * 0.035, true)
	var tw := 0.5 + 0.5 * sin(_time * 4.0)
	var star := mid + Vector2(w * 0.9, -h * 0.75)
	_decor.draw_line(star - Vector2(s * 0.07 * tw, 0), star + Vector2(s * 0.07 * tw, 0), Color.WHITE, s * 0.025, true)
	_decor.draw_line(star - Vector2(0, s * 0.07 * tw), star + Vector2(0, s * 0.07 * tw), Color.WHITE, s * 0.025, true)


## Feathers on the tail, like a real arrow: two pairs of swept-back vanes.
func _draw_fletching() -> void:
	if not _line.visible:
		return
	var pts := _line.points
	var s := cell_size
	if pts.size() < 2 or pts[0].distance_to(pts[1]) < s * 0.35:
		return
	var tail := pts[0]
	var d := (pts[1] - pts[0]).normalized()
	var n := Vector2(-d.y, d.x)
	var rim := _outline.default_color
	var fill := _color.lerp(Color.WHITE, 0.6)
	# One shield-shaped feather per side, (along, out) in cells from the tail.
	var shape := [Vector2(0.4, 0.05), Vector2(0.3, 0.15), Vector2(0.17, 0.23), Vector2(0.04, 0.29),
		Vector2(-0.07, 0.31), Vector2(-0.03, 0.2), Vector2(0.0, 0.05)]
	for side: float in [-1.0, 1.0]:
		var out := n * side
		var vane := PackedVector2Array()
		for q: Vector2 in shape:
			vane.append(tail + d * q.x * s + out * q.y * s)
		var rim_pts := Geometry2D.offset_polygon(vane, s * 0.028, Geometry2D.JOIN_ROUND)
		if not rim_pts.is_empty():
			_fletch.draw_colored_polygon(rim_pts[0], rim)
		_fletch.draw_colored_polygon(vane, fill)
		var lit := out.dot(LIGHT) > 0.0
		# Shade the feather facing away from the light.
		if not lit:
			_fletch.draw_colored_polygon(vane, Color(_color.darkened(0.3), 0.18))
		# A band of the arrow colour across the feather, and a lit outer edge.
		var band_a := tail + d * s * 0.2 + out * s * 0.06
		var band_b := tail + d * s * 0.06 + out * s * 0.26
		_fletch.draw_line(band_a, band_b, _color, s * 0.05, true)
		if lit:
			_fletch.draw_polyline(PackedVector2Array([vane[1], vane[2], vane[3]]), Color(1, 1, 1, 0.75), s * 0.022, true)
	# Nock: a small dark cap at the very end of the shaft.
	_fletch.draw_circle(tail - d * s * 0.04, _line.width * 0.42, rim, true, -1.0, true)


## A soft white gleam that runs from tail to head now and then, so resting arrows feel alive.
func _draw_glint(pts: PackedVector2Array) -> void:
	var t := _glint_t()
	if t > GLINT_TIME or busy:
		return
	var f := t / GLINT_TIME
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var at := total * f
	var half := cell_size * 0.22
	var part := _sub_polyline(pts, at - half, at + half)
	if part.size() < 2:
		return
	var alpha := sin(PI * f) * 0.75
	for i in part.size():
		part[i] += LIGHT * cell_size * 0.032
	_decor.draw_polyline(part, Color(1, 1, 1, alpha), _line.width * 0.4, true)


## The piece of a polyline between distances `from_d` and `to_d` along it.
func _sub_polyline(pts: PackedVector2Array, from_d: float, to_d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var along := 0.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		if seg <= 0.0:
			continue
		var s0 := clampf(from_d - along, 0.0, seg)
		var s1 := clampf(to_d - along, 0.0, seg)
		if s1 > s0:
			var p0 := a.lerp(b, s0 / seg)
			if out.is_empty() or out[-1] != p0:
				out.append(p0)
			out.append(a.lerp(b, s1 / seg))
		along += seg
	return out


## Speed streak behind a fast-moving head: a tapering, fading line.
func _draw_trail() -> void:
	if _trail.size() < 2:
		return
	var alpha := _head.modulate.a
	var n := _trail.size()
	for i in n - 1:
		var k := float(i + 1) / n          # 0 = oldest, 1 = newest
		_decor.draw_line(_trail[i], _trail[i + 1], Color(_color.lightened(0.35), 0.45 * k * alpha), _line.width * (0.3 + 0.6 * k), true)


## A polyline (tail -> head) with every inner corner replaced by a circular arc of up
## to `radius`. A corner never takes more than half of either side, so two bends one
## cell apart meet in one smooth S-curve. The first and last points stay where they are.
func _round_bends(pts: PackedVector2Array, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size() - 1):
		var p := pts[i]
		var a := pts[i - 1]
		var b := pts[i + 1]
		var r := minf(radius, minf(p.distance_to(a), p.distance_to(b)) * 0.5)
		var d_in := (p - a).normalized()
		var d_out := (b - p).normalized()
		var start := p - d_in * r
		var center := start + d_out * r
		var a0 := (start - center).angle()
		var sweep := wrapf((p + d_out * r - center).angle() - a0, -PI, PI)
		for k in ARC_STEPS + 1:
			var q := center + Vector2.from_angle(a0 + sweep * k / ARC_STEPS) * r
			if out[-1].distance_to(q) > 0.01:
				out.append(q)
	if out[-1].distance_to(pts[-1]) > 0.01:
		out.append(pts[-1])
	return out


## A polygon with its corners rounded off by `radius`.
func _rounded_polygon(corners: Array, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := corners.size()
	for i in n:
		var p: Vector2 = corners[i]
		var prev: Vector2 = corners[(i - 1 + n) % n]
		var next: Vector2 = corners[(i + 1) % n]
		var from := p + (prev - p).normalized() * radius * 1.6
		var to := p + (next - p).normalized() * radius * 1.6
		for s in 5:
			var t := s / 4.0
			out.append(from.lerp(p, t).lerp(p.lerp(to, t), t))  # quadratic curve around the corner
	return out


## Points every `step` px along a polyline: [[position, direction], ...], the first
## one `start` px in (default half a step).
func _samples_along(pts: PackedVector2Array, step: float, start := -1.0) -> Array:
	var out: Array = []
	var carry := step * 0.5 if start < 0.0 else start
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		if seg <= 0.0:
			continue
		var d := carry
		while d <= seg:
			out.append([a.lerp(b, d / seg), (b - a) / seg])
			d += step
		carry = d - seg
	return out


func _point_at_fraction(pts: PackedVector2Array, f: float) -> Vector2:
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var want := total * f
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if want <= seg and seg > 0.0:
			return pts[i].lerp(pts[i + 1], want / seg)
		want -= seg
	return pts[-1]


# --- Internals ------------------------------------------------------------------------------------

func _highlight() -> Color:
	return base_color().lightened(0.3)


func _set_offset(value: float) -> void:
	_offset = value
	_refresh()


func _set_reveal(value: float) -> void:
	_reveal = value
	_refresh()


## Rebuilds the visible window of the route: [offset, offset + body * reveal].
## The part inside the maze is drawn by _line; the part crossing the edge fade zone
## is drawn by _fade_line (straight, alpha 1 -> 0); anything past the zone is hidden,
## so arrows dissolve at the maze border instead of sliding under the HUD.
func _refresh() -> void:
	var curve := _path.curve
	var back := _offset
	var front := _offset + _body_length * _reveal
	var fade_end := _edge_offset + FADE_CELLS * cell_size

	var inner_front := minf(front, _edge_offset)
	if back < inner_front:
		var pts := PackedVector2Array([curve.sample_baked(back)])
		for i in _corner_offsets.size():
			if _corner_offsets[i] > back and _corner_offsets[i] < inner_front:
				pts.append(_corners[i])
		pts.append(curve.sample_baked(inner_front))
		for l: Line2D in _body_lines():
			l.points = pts
		_line.end_cap_mode = Line2D.LINE_CAP_ROUND if front <= _edge_offset else Line2D.LINE_CAP_NONE
		_line.visible = true
	else:
		_line.visible = false
	for l: Line2D in _body_lines():
		if l != _line and l != _glow:
			l.visible = _line.visible
	_outline.end_cap_mode = _line.end_cap_mode
	_glow.visible = _glows() and _line.visible

	var fade_from := maxf(back, _edge_offset)
	var fade_to := minf(front, fade_end)
	if fade_from < fade_to:
		_fade_line.points = PackedVector2Array([curve.sample_baked(fade_from), curve.sample_baked(fade_to)])
		_fade_gradient.colors = PackedColorArray([Color(_color, _edge_alpha(fade_from)), Color(_color, _edge_alpha(fade_to))])
		_fade_line.visible = true
	else:
		_fade_line.visible = false

	_follow.progress = front
	_head.modulate.a = _edge_alpha(front)
	_head_shadow.modulate.a = _head.modulate.a
	# The shadow always falls "down" on screen, whichever way the head points.
	_head_shadow.position = Vector2(cell_size * 0.035, cell_size * 0.08).rotated(-_follow.rotation)
	_shade_head()

	# Speed streak: remember where the head has been while it is moving forward.
	if _offset > cell_size * 0.05:
		_trail.append(_follow.position)
		if _trail.size() > TRAIL_POINTS:
			_trail.remove_at(0)
	elif not _trail.is_empty():
		_trail.clear()
	_decor.queue_redraw()
	_fletch.queue_redraw()


## 1 inside the maze, falling to 0 across the edge fade zone.
func _edge_alpha(d: float) -> float:
	return 1.0 - clampf((d - _edge_offset) / (FADE_CELLS * cell_size), 0.0, 1.0)


func _apply_color(color: Color) -> void:
	_color = color
	var face := color.lightened(0.12 * _press)
	var rim := color.darkened(0.45).lerp(Color("#ef4444"), _red)
	_line.default_color = face
	_outline.default_color = rim
	_low.default_color = face.darkened(0.14)
	_hi.default_color = face.lightened(0.22)
	_shine.default_color = Color(1, 1, 1, 0.6)
	_head.color = face
	_head_rim.color = rim
	_shade_head()
	_decor.queue_redraw()
	_fletch.queue_redraw()
	if _fade_line.visible:
		_refresh()


## Lights each gem face of the arrowhead by the angle it makes with the light.
func _shade_head() -> void:
	var rot := _follow.rotation
	for i in _facets.size():
		var lit := _facet_normals[i].rotated(rot).dot(LIGHT)
		var face := _color.lightened(0.12 * _press)
		_facets[i].color = face.lightened(0.18 + 0.12 * lit) if lit > -0.2 else face.darkened(0.1 - 0.12 * lit)


## Body layers, bottom to top.
func _body_lines() -> Array[Line2D]:
	return [_glow, _shadow, _outline, _line, _low, _hi, _shine]


func _fade_color(to: Color, duration: float) -> void:
	if _color_tween and _color_tween.is_valid():
		_color_tween.kill()
	_color_tween = create_tween()
	_color_tween.tween_method(_apply_color, _color, to, duration)


func _new_move_tween() -> Tween:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	return _move_tween


func _cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * cell_size


func _inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < _cols and c.y < _rows
