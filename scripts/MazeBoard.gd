class_name MazeBoard
extends Node2D
## The shaped maze: draws the board (animated dots + blast effects), spawns
## ArrowPaths from level data, owns the cell -> arrow map and resolves every tap.
##
## Tap rules
##   lane clear                    -> the arrow slides out
##   blocked by SAME colour        -> CRUSH: both break (no heart lost), and any
##                                    same-colour arrow that gets freed slides out
##                                    on its own (chain reaction)
##   blocked by OTHER colour       -> bump, the player loses a heart
##   special arrow                 -> fires its effect (never costs a heart)
##   special hits special          -> mega combo
## Every arrow removed by one tap counts towards the chain; a chain of 3/4/5/7
## turns one remaining arrow into a Drill / Bomb / Laser / Rainbow arrow.
## Everything only ever removes arrows, so a solvable maze always stays solvable.
## Works in fixed CELL units and is scaled to fit the screen.
##
## Board pieces (see LevelGenerator.features_for):
##   mirror  - an empty cell that turns every lane through it by 90 degrees
##   balloon - an empty cell; loses a layer when a neighbouring arrow is removed, when an
##             escaping arrow flies through it, or when a blast hits it
##   target  - sits just outside the shape; an escaping arrow whose lane passes it hits it
##   crate   - a wooden box (1-3 layers) that blocks lanes; an arrow shot into it, a
##             neighbouring arrow leaving or a blast knocks a layer off (no heart lost)
##   ice     - a frozen arrow (1-2 layers) can't move; an arrow shot into it, a neighbour
##             leaving or a blast cracks a layer. Each obstacle cracks once per tap.
## Special arrows (LevelGenerator._pick_*):
##   golden  - goal arrow, its own colour (never crushed), blasts can't break it: fly it out
##   bonus   - counts down every move; fly it out before 0 for bonus coins. At 0 the
##             bonus is simply gone - it never ends the level
##   linked  - two arrows on a chain: they only leave together, when both lanes are clear
##   flip    - a straight arrow that turns around after every move
## Creep (LevelGenerator: data.creep / creep_waves): after every move, arrows whose head
## faces a cell the move emptied slide forward into it, and the cells they leave pull
## the next arrows along - a small chain reaction. A creep that would leave the maze
## stuck is skipped, so the maze still always stays solvable.

signal moved(removed: int)            # a successful tap finished resolving
signal arrow_blocked(arrow: ArrowPath)
signal power_blast(smashed: int)      # the ⚡ booster was used
signal combo_text(text: String, color: Color, at: Vector2)  # board-local position
signal cleared
signal zoomed                         # the player zoomed in (for the tip)
signal goals_changed                  # a balloon popped or a target was hit (or undone)
signal special_made(arrow: ArrowPath)  # a 3+ chain turned an arrow into a special arrow
## A goal piece was used up: kind "balloons" / "crates" / "targets" / "ice" / "golden",
## or "arrow" for every arrow taken (its colour in `color`). `pos` is board-local, it
## shows `delay` seconds from now, `tex` is its art (null: the HUD picks one). The HUD
## flies a copy up into the goal card (Candy Crush style).
signal goal_piece(kind: String, pos: Vector2, delay: float, tex: Texture2D, color: int)

const CELL := 100.0
# Crush effect sprites, drawn in Affinity (UI kit v2): glow, 3 shard shapes, sparkle, combo words.
const FX_GLOW := preload("res://icons/fx/crush_glow.png")
const FX_SPARKLE := preload("res://icons/fx/crush_sparkle.png")
const FX_FIREBALL := preload("res://icons/fx/fx_fireball.png")
const FX_SMOKE := preload("res://icons/fx/fx_smoke.png")
# Final Victory fireworks, drawn in Affinity.
const FW_RAYS := preload("res://icons/fx/fw_rays.png")
const FW_CORE := preload("res://icons/fx/fw_core.png")
const FW_STAR := preload("res://icons/fx/fw_star.png")
const FW_ROCKET := preload("res://icons/fx/fw_rocket.png")
# Colour dots left behind by arrows (Affinity): a greyscale ball tinted per colour + an untinted gloss.
const BLOCK_BASE := preload("res://icons/fx/dot_base.png")
const BLOCK_GLOSS := preload("res://icons/fx/dot_gloss.png")
const BLOCK_POP := 0.32   # seconds a dot takes to pop in
const BLOCK_SIZE := 0.4   # dot diameter in cells (small: a dotted picture, not tiles)
const FX_SHARDS: Array[Texture2D] = [preload("res://icons/fx/crush_shard_0.png"),
	preload("res://icons/fx/crush_shard_1.png"), preload("res://icons/fx/crush_shard_2.png")]
const COMBO_TEX: Array[Texture2D] = [preload("res://icons/fx/combo_crush.png"), preload("res://icons/fx/combo_sweet.png"),
	preload("res://icons/fx/combo_super.png"), preload("res://icons/fx/combo_amazing.png"),
	preload("res://icons/fx/combo_incredible.png"), preload("res://icons/fx/combo_storm.png")]
const DOT_COLOR := Color("#e6ebf1")
const TRAY_COLOR := Color("#efeaff")
const TRAY_LIP := Color("#d9cff9")
const LANE_COLOR := Color("#2563eb")
const HINT_COLOR := Color("#facc15")   # hint: gold glow under the arrow + rings on its head
const HINT_TIME := 6.0                 # seconds a hint stays up (or until the next tap)
const RIPPLE_RED := Color("#fecaca")
## Each level gets one of these multi-colour themes; escape ripples run through it.
const PALETTES := [
	[Color("#22d3ee"), Color("#3b82f6"), Color("#a855f7")],  # ocean
	[Color("#fde047"), Color("#fb923c"), Color("#f43f5e")],  # sunset
	[Color("#34d399"), Color("#22d3ee"), Color("#6366f1")],  # aurora
	[Color("#f9a8d4"), Color("#c084fc"), Color("#60a5fa")],  # candy
	[Color("#a3e635"), Color("#34d399"), Color("#0ea5e9")],  # lagoon
	[Color("#fbbf24"), Color("#f472b6"), Color("#8b5cf6")],  # peach
]
const POWER_PALETTE := [Color("#fde047"), Color("#f59e0b"), Color("#f97316")]
const RIPPLE_TIME := 1.0    # seconds a dot takes to flash and fade back (the comet tail)
const DOT_RADIUS := CELL * 0.055
const MAX_ZOOM := 3.0
const MIN_ZOOM := 0.7        # players may also zoom OUT a little below the fitted view
const INTRO_ZOOM := 1.35     # a level opens a little close-up, then glides out to the whole board
const TAP_SLOP := 14.0         # px a finger may move and still count as a tap
# Unsure taps: when the finger lands between two arrows (neither is clearly closer),
# nothing launches - a wrong arrow would cost a heart. Small boards zoom in instead.
const FIT_MARGIN := 0.06       # share of the board width kept free on each side when fitted
const UNSURE_MARGIN := 0.22   # cells: the nearer arrow must win by at least this much...
const SURE_DIST := 0.12        # ...unless the finger is right on it (cells)
const SMALL_CELL_PX := 46.0    # a cell smaller than this on screen is hard to hit: zoom in
const HELP_ZOOM := 2.0
const COMBO_WORDS: Array[String] = ["", "", "Crush!", "Sweet!", "Super!", "Amazing!", "Incredible!", "ARROW STORM!"]
const BALLOON_COLORS: Array[Color] = [Color("#f43f5e"), Color("#f59e0b"), Color("#22c55e"),
	Color("#3b82f6"), Color("#a855f7"), Color("#ec4899")]
const NEIGHBOURS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
# Goal pieces drawn in Affinity (soft gradients, inner shadows, blurred gloss). 256 px each.
const BALLOON_TEX: Array[Texture2D] = [preload("res://icons/fx/goal_balloon_0.png"),
	preload("res://icons/fx/goal_balloon_1.png"), preload("res://icons/fx/goal_balloon_2.png"),
	preload("res://icons/fx/goal_balloon_3.png"), preload("res://icons/fx/goal_balloon_4.png"),
	preload("res://icons/fx/goal_balloon_5.png")]   # same order as BALLOON_COLORS
const CRATE_TEX: Array[Texture2D] = [preload("res://icons/fx/goal_crate_1.png"),
	preload("res://icons/fx/goal_crate_2.png"), preload("res://icons/fx/goal_crate_3.png")]
const TARGET_TEX := preload("res://icons/fx/goal_target.png")
const TARGET_HIT_TEX := preload("res://icons/fx/goal_target_hit.png")
const ICE_TEX: Array[Texture2D] = [preload("res://icons/fx/goal_ice_1.png"), preload("res://icons/fx/goal_ice_2.png")]


var cols := 0
var rows := 0
var mask := {}                        # Vector2i -> true for cells inside the shape
var input_enabled := true
var armed := ArrowPath.Special.NONE   # booster the next tapped arrow fires (drill / bomb / laser / rainbow)
var power_armed: bool:                # any booster armed; true arms the original drill
	get:
		return armed != ArrowPath.Special.NONE
	set(on):
		armed = ArrowPath.Special.DRILL if on else ArrowPath.Special.NONE
var tutorial_block := false           # tutorial: ignore every arrow tap
var tutorial_only: ArrowPath = null   # tutorial: only this arrow may be tapped
var occupancy := {}                   # Vector2i -> ArrowPath (arrows still in the maze)
var arrows: Array[ArrowPath] = []     # arrows still in the maze
var history: Array[Dictionary] = []   # one entry per tap, newest last (for Undo)
var mirrors := {}                     # Vector2i -> 0 "/" or 1 "\\"
var balloons := {}                    # Vector2i -> layers left (game logic)
var targets := {}                     # Vector2i beside the shape -> true once hit
var _balloon_view := {}               # layers as drawn (pops show a moment after the logic)
var _target_hit_at := {}              # target cell -> clock time its hit lands
var _aimers := {}                     # ArrowPath -> true: escaping now would hit a target
var crates := {}                      # Vector2i -> layers left (game logic)
var _crate_view := {}                 # layers as drawn (a knock shows a moment after the logic)
var color_removed := {}               # colour index -> arrows of that colour removed so far
var _cracked := {}                    # obstacles already cracked by the current tap
var golden_out := 0                   # golden arrows flown out so far
var crushed := 0                      # arrows broken (crush, domino, blast) - flying out doesn't count
var magnet := false                   # arrows facing a fresh gap slide over to a same-colour arrow and crush it
const MAGNET_REACH := 3               # most empty cells a magnet slide crosses
var bonus_out := 0                    # bonus arrows flown out before their count hit 0
const BONUS_COINS := 5                # coins per bonus arrow, paid when the level is won

var _palette := Gradient.new()
var _power_palette := Gradient.new()
var _ripples := {}                    # Vector2i -> {start, color, amp, pull}
var _fx: Array[Dictionary] = []       # blast rings, beams, pieces, lightning being drawn
var _fx_layer: Node2D                 # draws _fx above the arrows
var _clock := 0.0
var _intro_start := 0.0               # when the dots of this level started popping in
var _fit_rect := Rect2()              # board area this maze is fitted into
var _revealed := {}                  # cell -> time its picture tile lights up (arrow left it)
var _picture := 0.0                  # 0..1 - the finished-picture glow at the end of a level
var _paint := {}                     # cell -> colour the leaving arrow left there (blended where colours meet)
var _ribbons: Array = []             # brush strokes, one per arrow gone: {pts, color, at, tail, head}
var _splashes: Array = []            # colour splashes where arrows crushed: {cell, color, at}
var _block_hidden := {}              # cell -> true: a colour block an arrow is standing on (not drawn)
# Performance: the painting lives on its own layer that is only redrawn while something in
# it is changing, and the dots use one small texture with their per-cell maths cached.
var _paint_layer: Node2D
var _paint_until := 0.0              # redraw the painting every frame until this time
var _paint_version := 0              # bumped whenever _paint changes (corner cache key)
var _corner_cache := {}
var _corner_version := -1
var _dot_tex: Texture2D
var _dots_dirty := true
var _dot_cells: Array[Vector2i] = []
var _dot_pos := PackedVector2Array()
var _dot_tint := PackedColorArray()
var _dot_phase := PackedFloat32Array()
var _dot_delay := PackedFloat32Array()
const QUAD_CORNERS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]
const CORNER_CELLS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]
var _soft_tex: Texture2D             # white soft disc, tinted for every wash blob
var _picture_done_at := 0.0          # clock time the finished painting is fully shown
var user_zoom := 1.0                  # player pinch / wheel zoom (1 = whole board)
var _pan := Vector2.ZERO              # player pan offset (pixels)
var _touches := {}                    # finger index -> position
var _tap_valid := false
var _tap_start := Vector2.ZERO
var _pinch_dist := 0.0
var _pinch_mid := Vector2.ZERO
var _mouse_down := false
var _tray_boxes: Array[StyleBoxFlat] = []  # lip + face tiles of the board tray
var _pressed: ArrowPath = null         # arrow under the finger right now (dips until release)
var _last_empty_tap := -10.0
var _base_scale := Vector2.ONE
var _punch_tween: Tween
var _shake_x := 0.0
var _zoom := 1.0
var _shake_tween: Tween
var _lane_pts := PackedVector2Array()   # hint lane: head, every mirror, the edge
var _lane_alpha := 0.0
var _hint: ArrowPath = null            # arrow the hint is pointing at (null = no hint up)
var _hint_start := 0.0

# The tap currently being resolved.
var _resolving := false
var _chain := 0                       # arrows removed by this tap so far
var _chain_color := 0
var _chain_colors := {}                # colours this tap's chain has run in (a prism adds one)
var _focus := Vector2i.ZERO           # where the action is (for texts and rewards)
var _action_end := 0.0                # clock time when its animations are done
var _removed_cells := {}
var _entry := {}
var _cleared_sent := false
var creep_steps := 0                  # cells an arrow may creep forward after a move (0 = arrows stay put)
var creep_waves := 0                  # how far a creep spreads back through the maze
const CREEP_MAX := 12                 # most arrows that creep after one move
const CREEP_CHECKS := 4               # most full "still solvable?" checks per move (keeps taps snappy)


func _ready() -> void:
	_power_palette = _make_gradient(POWER_PALETTE)
	set_palette(0)


## Picks the level's colour theme. Returns its middle colour (for HUD accents).
func set_palette(index: int) -> Color:
	var colors: Array = PALETTES[posmod(index, PALETTES.size())]
	_palette = _make_gradient(colors)
	_dots_dirty = true
	return colors[1]


func _make_gradient(colors: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray(colors)
	return g


func _process(delta: float) -> void:
	_clock += delta
	for c: Vector2i in _ripples.keys():
		if _clock - _ripples[c].start > RIPPLE_TIME:
			_ripples.erase(c)
	for i in range(_fx.size() - 1, -1, -1):
		if _clock > _fx[i].start + _fx[i].dur:
			_fx.remove_at(i)
	queue_redraw()  # the dots always shimmer a little
	if _paint_layer and (_clock < _paint_until or _picture > 0.0):
		_paint_layer.queue_redraw()
	if _hint != null and (not is_instance_valid(_hint) or _hint.busy or _clock - _hint_start > HINT_TIME):
		clear_hint()
	if _fx_layer:
		_fx_layer.queue_redraw()


func build(data: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	# Blast effects draw on their own layer so they show on top of the arrows.
	_fx_layer = Node2D.new()
	_fx_layer.z_index = 10
	_fx_layer.draw.connect(_draw_fx)
	add_child(_fx_layer)
	# Picture levels: a soft, smooth silhouette of the picture (cat, teapot...) behind
	# everything, so the player sees what the arrows are drawing from the very start - the
	# board's big cells alone can't show the fine outline.
	_silhouette = null  # made below, once the board size is known
	var pic_layer := Node2D.new()
	pic_layer.show_behind_parent = true
	pic_layer.draw.connect(func() -> void:
		if _silhouette:
			pic_layer.draw_texture_rect(_silhouette, _silhouette_rect, false, SILHOUETTE_TINT))
	add_child(pic_layer)
	# The painting draws behind the dots and pieces (same order as before), on its own layer.
	_paint_layer = Node2D.new()
	_paint_layer.show_behind_parent = true
	_paint_layer.draw.connect(_draw_picture)
	add_child(_paint_layer)
	_dots_dirty = true
	arrows.clear()
	occupancy.clear()
	history.clear()
	_ripples.clear()
	_fx.clear()
	power_armed = false
	_resolving = false
	_cleared_sent = false
	Engine.time_scale = 1.0
	cols = data.cols
	rows = data.rows
	mask = data.mask
	# The soft picture silhouette behind the board is switched off: the player found it
	# distracting. The arrows' dots still draw the picture as the level is cleared.
	_silhouette = null
	creep_steps = int(data.get("creep", 0))
	creep_waves = int(data.get("creep_waves", 1))
	_intro_start = _clock
	user_zoom = INTRO_ZOOM
	_pan = Vector2.ZERO
	_revealed.clear()
	_picture = 0.0
	_paint.clear()
	_ribbons.clear()
	_splashes.clear()
	_block_hidden.clear()
	_touch_paint(0.0)
	_play_intro_zoom()
	var colors: Array = data.get("colors", [])
	mirrors = data.get("mirrors", {})
	balloons = data.get("balloons", {}).duplicate()
	_balloon_view = balloons.duplicate()
	targets = {}
	for t: Vector2i in data.get("targets", {}):
		targets[t] = false
	_target_hit_at.clear()
	crates = {}
	for c: Vector2i in data.get("crates", {}):
		crates[c] = 1  # one hit breaks a crate (older saves may hold 2-3 layers)
	_crate_view = crates.duplicate()
	color_removed = {}
	var ice: Dictionary = data.get("ice", {})
	golden_out = 0
	bonus_out = 0
	crushed = 0
	magnet = bool(data.get("magnet", false))
	var golden: Array = data.get("golden", [])
	var timers: Dictionary = data.get("timers", {})
	var flips: Array = data.get("flips", [])
	var prisms: Array = data.get("prisms", [])
	var link_of := {}
	var links: Array = data.get("links", [])
	for k in links.size():
		link_of[links[k][0]] = k
		link_of[links[k][1]] = k
	var center := Vector2(cols, rows) * CELL / 2.0
	var i := 0
	for arrow_cells: Array[Vector2i] in data.arrows:
		var arrow := _spawn(arrow_cells, colors[i] if i < colors.size() else 0)
		arrow.ice = int(ice.get(i, 0))
		arrow.golden = golden.has(i)
		arrow.timer = int(timers.get(i, 0))
		arrow.link_id = int(link_of.get(i, -1))
		arrow.flip = flips.has(i)
		arrow.prism = prisms.has(i)
		# Intro ripples outward from the middle of the board.
		var dist := (Vector2(arrow.head()) * CELL).distance_to(center) / CELL
		arrow.play_intro(0.05 + dist / maxf(cols, rows) * 0.9)
		i += 1
	_update_aimers()
	queue_redraw()


const SILHOUETTE_TINT := Color(0.66, 0.58, 0.98, 0.3)
var _silhouette: Texture2D
var _silhouette_rect := Rect2()


## The picture's bit mask (from LevelGenerator: bits, bw, bh, fit) as a smooth texture,
## and where it sits on the board. null on levels without a picture.
func _silhouette_texture(pic: Dictionary) -> Texture2D:
	if pic.is_empty():
		return null
	var bw: int = pic.bw
	var bh: int = pic.bh
	var bits: PackedByteArray = pic.bits
	var img := Image.create(bw, bh, false, Image.FORMAT_LA8)
	for y in bh:
		for x in bw:
			img.set_pixel(x, y, Color(1, 1, 1, 1.0 if bits[y * bw + x] else 0.0))
	img.resize(bw * 4, bh * 4, Image.INTERPOLATE_CUBIC)  # smooth edges instead of steps
	# Bitmap space: x -1..1, y -a..a (a = bh / bw); board: u = (x - f.x) / f.z, cell px.
	var f: Vector4 = pic.fit
	var a := float(bh) / bw
	var to_board := func(p: Vector2) -> Vector2:
		var u := (p.x - f.x) / f.z
		var v := (p.y - f.y) / f.w
		return Vector2((u + 1.0) * 0.5 * cols * CELL, (v + 1.0) * 0.5 * rows * CELL)
	var tl: Vector2 = to_board.call(Vector2(-1, -a))
	var br: Vector2 = to_board.call(Vector2(1, a))
	_silhouette_rect = Rect2(tl, br - tl)
	return ImageTexture.create_from_image(img)


## Fits the maze inside `rect` (the board area, in the parent's coordinates).
## Player zoom / pan are kept on top of this fit.
func fit_to(rect: Rect2) -> void:
	if cols == 0 or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	_fit_rect = rect
	var board := Vector2(cols, rows) * CELL
	for t: Vector2i in targets.keys():
		if not (t.x >= 0 and t.y >= 0 and t.x < cols and t.y < rows):
			board += Vector2(2, 2) * CELL  # room for targets just past the board edge
			break
	# Breathing room: the fitted maze keeps a margin on every side instead of touching the
	# screen edges (pinch-zoom still goes all the way in).
	var pad := clampf(rect.size.x * FIT_MARGIN, 24.0, 80.0)
	var room := (rect.size - Vector2(pad, pad) * 2.0).max(rect.size * 0.5)
	var k := minf(room.x / board.x, room.y / board.y)
	_base_scale = Vector2(k, k)
	_clamp_pan()
	_apply_transform()

## Undoes the last tap: brings back every arrow it removed (with colour and
## special) and reverts any special arrow it created. Returns the entry or {}.
func undo() -> Dictionary:
	if history.is_empty() or _resolving:
		return {}
	clear_hint()
	var entry: Dictionary = history.pop_back()
	for cells: Array in entry.get("flipped", []):
		var turned: ArrowPath = occupancy.get(cells[-1])
		if turned:
			_turn_around(turned, false)
	for head: Vector2i in entry.get("ticked", []):
		var ticking: ArrowPath = occupancy.get(head)
		if ticking:
			ticking.timer += 1
	for up: Dictionary in entry.upgrades:
		var upgraded: ArrowPath = occupancy.get(up.head)
		if upgraded:
			upgraded.set_special(up.old, false)
	# Crept arrows go back first: the removed arrows' cells may be under them now.
	var crept: Array = entry.get("crept", [])
	for i in range(crept.size() - 1, -1, -1):
		var move: Array = crept[i]
		var now: ArrowPath = occupancy.get(move[1][-1])
		if now == null:
			continue
		var flags := _flags_of(now)
		for c in now.cells:
			occupancy.erase(c)
		arrows.erase(now)
		now.queue_free()
		var old_cells: Array[Vector2i] = []
		old_cells.assign(move[0])
		_apply_flags(_spawn(old_cells, flags.color, flags.special), flags)
	for rec: Dictionary in entry.arrows:
		var back := _spawn(rec.cells, rec.color, rec.special)
		for c in rec.cells:
			_revealed.erase(c)
			_paint.erase(c)
		for i in range(_ribbons.size() - 1, -1, -1):
			if _ribbons[i].tail == rec.cells[0] and _ribbons[i].head == rec.cells[-1]:
				_ribbons.remove_at(i)
				break
		_touch_paint(0.0)
		_apply_flags(back, rec)
		back.play_return()
		if back.golden:
			golden_out -= 1
		if back.timer > 0:
			bonus_out -= 1
		color_removed[rec.color] = int(color_removed.get(rec.color, 1)) - 1
	crushed -= int(entry.get("crushed", 0))
	for c: Vector2i in entry.crates:
		crates[c] = int(crates.get(c, 0)) + 1
		_crate_view[c] = crates[c]
	for head: Vector2i in entry.ice:
		var thawed: ArrowPath = occupancy.get(head)
		if thawed:
			thawed.ice += 1
	for c: Vector2i in entry.balloons:
		balloons[c] = int(balloons.get(c, 0)) + 1
		_balloon_view[c] = balloons[c]
	for i in range(entry.moved.size() - 1, -1, -1):
		var move: Array = entry.moved[i]
		targets.erase(move[1])
		targets[move[0]] = false
	for c: Vector2i in entry.targets:
		targets[c] = false
		_target_hit_at.erase(c)
	goals_changed.emit()
	_update_aimers()
	return entry


## Balloon layers still to pop.
func balloons_left() -> int:
	var n := 0
	for c: Vector2i in balloons:
		n += int(balloons[c])
	return n


func targets_left() -> int:
	return targets.values().count(false)


func crates_left() -> int:
	var n := 0
	for c: Vector2i in crates:
		n += int(crates[c])
	return n


func ice_left() -> int:
	var n := 0
	for a in arrows:
		n += a.ice
	return n


func removed_of(color: int) -> int:
	return int(color_removed.get(color, 0))


## An arrow that can escape right now (null when none is free).
func hint_arrow() -> ArrowPath:
	# A ticking timer comes first: the timer arrow itself, or an arrow clearing its way.
	var urgent := _timer_way()
	var free: ArrowPath = null
	var shooter: ArrowPath = null  # no free arrow: one that can smash a crate / crack ice
	var crusher: ArrowPath = null  # crushing is the goal: a same-colour crush is the best hint
	var frees: Array[ArrowPath] = []  # arrows that can fly out right now
	for a in arrows:
		if a.busy or a.ice > 0:
			continue
		var partner := _partner(a)
		if partner:
			if _free_with(a, partner) and _free_with(partner, a) and free == null:
				free = a
			continue
		var gap := a.blocked_gap(occupancy)
		var cgap := _crate_gap(a)
		if crusher == null and gap >= 0 and (cgap < 0 or cgap > gap) and a.special == ArrowPath.Special.NONE:
			var blocker: ArrowPath = occupancy[a.lane_cells()[gap]]
			if blocker != a and blocker.ice <= 0 and _crushes(a, blocker):
				crusher = a
		if gap < 0 and cgap < 0:
			frees.append(a)
			if free == null:
				free = a
		elif shooter == null and (cgap >= 0 and (gap < 0 or cgap < gap)
				or gap >= 0 and (occupancy[a.lane_cells()[gap]] as ArrowPath).ice > 0):
			shooter = a
	# Crushing is the goal: a crush first, then a ticking bonus arrow, then a target shot.
	if crusher:
		return crusher
	for a in frees:
		if urgent.has(a):
			return a
	for a in frees:
		if _aimers.has(a):
			return a
	if not frees.is_empty():
		return _best_opener(frees)
	return shooter if shooter else free


## Of the free arrows, the one whose leaving lets another arrow crush (its lane then runs
## into a same-colour arrow). Falls back to the first one.
func _best_opener(frees: Array[ArrowPath]) -> ArrowPath:
	for f in frees:
		var opens := false
		for b in arrows:
			if b == f or b.busy or b.ice > 0:
				continue
			var lane := b.lane_cells()
			var gap := b.blocked_gap(occupancy)
			if gap < 0 or occupancy[lane[gap]] != f:
				continue
			for i in range(gap + 1, lane.size()):
				var other: ArrowPath = occupancy.get(lane[i])
				if other == null or other == f:
					continue
				opens = other != b and _crushes(b, other)
				break
			if opens:
				return f
	return frees[0]


## A crate, balloon or frozen arrow that no arrow left on the board can ever reach (no
## arrow beside it, no lane through it) gets a BONUS SHOT from the edge of the board,
## so a level can never get stuck on it.
func _rescue_obstacles() -> void:
	if crates.is_empty() and balloons.is_empty() and ice_left() == 0:
		return
	var near := {}      # cells beside an arrow
	var in_lane := {}   # cells some movable arrow's lane passes
	for a in arrows:
		for c in a.cells:
			for d in NEIGHBOURS:
				near[c + d] = a
		if a.ice == 0:
			for c in a.lane_cells():
				in_lane[c] = a
	var stuck: Array[Vector2i] = []
	for c: Vector2i in crates:
		if not near.has(c) and not in_lane.has(c):
			stuck.append(c)
	for c: Vector2i in balloons:
		if not near.has(c) and not in_lane.has(c):
			stuck.append(c)
	var frozen_stuck: Array[ArrowPath] = []
	for a in arrows:
		if a.ice <= 0:
			continue
		var reachable := false
		for c in a.cells:
			for d in NEIGHBOURS:
				var other: ArrowPath = occupancy.get(c + d)
				if other != null and other != a:
					reachable = true
			if in_lane.has(c) and in_lane[c] != a:
				reachable = true
		if not reachable:
			frozen_stuck.append(a)
	if stuck.is_empty() and frozen_stuck.is_empty():
		return
	var t := maxf(0.3, _action_end - _clock)
	var from := Vector2(cols * 0.5, rows + 1.0) * CELL
	var k := 0
	for c in stuck:
		var d := t + k * 0.12
		_add_beam(from, _center(c), ArrowPath.COLOR_POWER, d, from, 0.35)
		while crates.has(c):
			_knock_crate(c, d + 0.15, false)
		while balloons.has(c):
			_pop_balloon(c, d + 0.15)
		k += 1
	for a in frozen_stuck:
		var d := t + k * 0.12
		_add_beam(from, _center(a.head()), ArrowPath.COLOR_POWER, d, from, 0.35)
		while a.ice > 0:
			_crack_ice(a, d + 0.15, false)
		k += 1
	_say("BONUS SHOT!", ArrowPath.COLOR_POWER, Vector2i(cols / 2, rows - 1), t)
	_later(t, GameData.play_sfx.bind("laser"))


## Timer arrows and every arrow standing in their way (and in those arrows' way...).
func _timer_way() -> Dictionary:
	var way := {}
	var todo: Array[ArrowPath] = []
	for a in arrows:
		if a.timer > 0:
			way[a] = true
			todo.append(a)
	while not todo.is_empty():
		var a: ArrowPath = todo.pop_back()
		for c in a.lane_cells():
			var other: ArrowPath = occupancy.get(c)
			if other and not way.has(other):
				way[other] = true
				todo.append(other)
	return way


## The other arrow on `arrow`'s chain (null when not linked, or the partner is gone).
func _partner(arrow: ArrowPath) -> ArrowPath:
	if arrow.link_id < 0:
		return null
	for a in arrows:
		if a != arrow and a.link_id == arrow.link_id:
			return a
	return null


## `arrow` could fly out if `other` left at the same moment (no arrow or crate in the way).
func _free_with(arrow: ArrowPath, other: ArrowPath) -> bool:
	for c in arrow.lane_cells():
		if crates.has(c):
			return false
		var a: ArrowPath = occupancy.get(c)
		if a != null and a != other:
			return false
	return true


func _flags_of(arrow: ArrowPath) -> Dictionary:
	return {"cells": arrow.cells.duplicate(), "color": arrow.color_index, "special": arrow.special,
		"ice": arrow.ice, "golden": arrow.golden, "timer": arrow.timer, "link_id": arrow.link_id, "flip": arrow.flip,
		"prism": arrow.prism}


func _apply_flags(arrow: ArrowPath, rec: Dictionary) -> void:
	arrow.ice = int(rec.get("ice", 0))
	arrow.golden = bool(rec.get("golden", false))
	arrow.timer = int(rec.get("timer", 0))
	arrow.link_id = int(rec.get("link_id", -1))
	arrow.flip = bool(rec.get("flip", false))
	arrow.prism = bool(rec.get("prism", false))


# --- Continue where you left off ---------------------------------------------------------------------

## False while a tap is still being resolved (arrows flying, chains running).
func is_settled() -> bool:
	return not _resolving


## The board as it is now - with the level's original data, enough to rebuild it.
func snapshot() -> Dictionary:
	var list: Array = []
	for a in arrows:
		list.append(_flags_of(a))
	return {"arrows": list, "balloons": balloons.duplicate(), "crates": crates.duplicate(),
		"targets": targets.duplicate(), "color_removed": color_removed.duplicate(), "golden_out": golden_out,
		"bonus_out": bonus_out, "crushed": crushed}


## Builds the level from `data`, but with the board as saved in `snap` (see snapshot()).
func restore(data: Dictionary, snap: Dictionary) -> void:
	var d := data.duplicate(true)
	var cells_list: Array = []
	var colors: Array = []
	var ice := {}
	var golden: Array = []
	var timers := {}
	var flips: Array = []
	var prisms: Array = []
	var link_members := {}
	var recs: Array = snap.get("arrows", [])
	for i in recs.size():
		var rec: Dictionary = recs[i]
		var cells: Array[Vector2i] = []
		cells.assign(rec.cells)
		cells_list.append(cells)
		colors.append(int(rec.color))
		if int(rec.get("ice", 0)) > 0:
			ice[i] = int(rec.ice)
		if rec.get("golden", false):
			golden.append(i)
		if int(rec.get("timer", 0)) > 0:
			timers[i] = int(rec.timer)
		if rec.get("flip", false):
			flips.append(i)
		if rec.get("prism", false):
			prisms.append(i)
		var link := int(rec.get("link_id", -1))
		if link >= 0:
			if not link_members.has(link):
				link_members[link] = []
			link_members[link].append(i)
	var links: Array = []
	for members: Array in link_members.values():
		if members.size() == 2:
			links.append(members)
	d.arrows = cells_list
	d.colors = colors
	d.ice = ice
	d.golden = golden
	d.timers = timers
	d.flips = flips
	d.prisms = prisms
	d.links = links
	d.balloons = snap.get("balloons", {})
	d.crates = snap.get("crates", {})
	d.targets = snap.get("targets", {})
	build(d)
	for i in mini(recs.size(), arrows.size()):
		var special := int(recs[i].get("special", 0)) as ArrowPath.Special
		if special != ArrowPath.Special.NONE:
			arrows[i].set_special(special, false)
	targets = (snap.get("targets", {}) as Dictionary).duplicate()
	color_removed = (snap.get("color_removed", {}) as Dictionary).duplicate()
	golden_out = int(snap.get("golden_out", 0))
	bonus_out = int(snap.get("bonus_out", 0))
	crushed = int(snap.get("crushed", 0))
	_update_aimers()
	goals_changed.emit()
	queue_redraw()


func golden_left() -> int:
	var n := 0
	for a in arrows:
		if a.golden:
			n += 1
	return n


## After every move: bonus counts go down (0 -> the bonus is gone, nothing else), flip arrows turn around.
func _after_move() -> void:
	for a in arrows.duplicate():
		if a.timer > 0:
			a.timer -= 1
			_entry.ticked.append(a.head())
			if a.timer <= 2:
				_later(0.05, GameData.play_sfx.bind("tap", 1.6))
			if a.timer == 0:
				_say("BONUS GONE", Color("#94a3b8"), a.head(), maxf(0.25, _action_end - _clock + 0.1))
				_later(maxf(0.25, _action_end - _clock + 0.1), GameData.play_sfx.bind("pop", 0.8))
		if a.flip and not a.busy:
			var turned := _turn_around(a, true)
			_entry.flipped.append(turned.cells.duplicate())


## Replaces a flip arrow with the same arrow facing the other way (same cells).
func _turn_around(a: ArrowPath, animate: bool) -> ArrowPath:
	var rec := _flags_of(a)
	var cells: Array[Vector2i] = []
	cells.assign(a.cells)
	cells.reverse()
	for c in a.cells:
		occupancy.erase(c)
	arrows.erase(a)
	a.queue_free()
	var turned := _spawn(cells, rec.color, rec.special)
	_apply_flags(turned, rec)
	if animate:
		turned.scale = Vector2(1, 1)
		turned.modulate = Color(1.6, 1.6, 1.6)
		turned.create_tween().tween_property(turned, "modulate", Color.WHITE, 0.3)
	return turned


## Lane index of the first crate in front of `arrow` (-1 = none).
func _crate_gap(arrow: ArrowPath) -> int:
	if crates.is_empty():
		return -1
	var lane := arrow.lane_cells()
	for i in lane.size():
		if crates.has(lane[i]):
			return i
	return -1


## Hint: the arrow glows gold underneath, rings ripple out of its head, it keeps
## blinking and its free lane is drawn to the edge - until the next tap or HINT_TIME.
func show_hint(arrow: ArrowPath) -> void:
	clear_hint()
	_hint = arrow
	_hint_start = _clock
	_lane_pts = _lane_points(arrow)
	_lane_alpha = 0.0
	arrow.play_hint(roundi(HINT_TIME / 0.4))


func clear_hint() -> void:
	if _hint == null:
		return
	if is_instance_valid(_hint) and not _hint.busy:
		_hint.stop_hint()
	_hint = null
	_lane_alpha = 0.0


## 0..1 strength of the hint right now (quick fade in, fade out at the end).
func _hint_fade() -> float:
	if _hint == null or not is_instance_valid(_hint):
		return 0.0
	var t := _clock - _hint_start
	return clampf(t / 0.2, 0.0, 1.0) * clampf((HINT_TIME - t) / 0.5, 0.0, 1.0)


## Briefly draws the free lane of `arrow` as a dashed line to the edge.
func show_lane(arrow: ArrowPath) -> void:
	_lane_pts = _lane_points(arrow)
	var t := create_tween()
	t.tween_method(_set_lane_alpha, 1.0, 1.0, 0.9)
	t.tween_method(_set_lane_alpha, 1.0, 0.0, 0.5)


## Small screen shake for impacts.
func shake(strength: float = 10.0) -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	var last := 0.0
	for f: float in [1.0, -0.8, 0.5, -0.3, 0.0]:
		_shake_tween.tween_method(_set_shake, last, strength * f, 0.04)
		last = strength * f


## Camera punch: the whole board zooms in a touch and settles back.
func punch(amount: float) -> void:
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()
	_punch_tween = create_tween()
	_punch_tween.tween_method(_set_zoom, 1.0 + amount, 1.0, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _set_shake(x: float) -> void:
	_shake_x = x
	_apply_transform()


func _set_zoom(z: float) -> void:
	_zoom = z
	_apply_transform()


## Board transform = fit scale x player zoom x punch, centred in the board area,
## moved by the player's pan and the shake offset.
func _apply_transform() -> void:
	var s := _base_scale * user_zoom * _zoom
	var board := Vector2(cols, rows) * CELL
	scale = s
	position = _fit_rect.get_center() + _pan - board * s / 2.0 + Vector2(_shake_x, 0)


# --- Player zoom & pan --------------------------------------------------------------------------

## Zooms so the board point under `focus` (parent coordinates) stays under it.
func zoom_at(focus: Vector2, new_zoom: float) -> void:
	var s_old := scale.x
	var local := (focus - position) / s_old
	user_zoom = clampf(new_zoom, MIN_ZOOM, MAX_ZOOM)
	var s := _base_scale.x * user_zoom * _zoom
	var board := Vector2(cols, rows) * CELL
	_pan = focus - _fit_rect.get_center() + board * s / 2.0 - local * s
	if user_zoom <= 1.001:
		_pan = Vector2.ZERO
	_clamp_pan()
	_apply_transform()
	if user_zoom > 1.001:
		zoomed.emit()


## Level start: the board opens close-up and glides out to the whole board.
func _play_intro_zoom() -> void:
	var t := create_tween()
	t.tween_interval(0.05)
	t.tween_method(func(z: float) -> void:
		user_zoom = z
		_pan = Vector2.ZERO
		_apply_transform(), INTRO_ZOOM, 1.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Smoothly back to the whole board.
func reset_zoom() -> void:
	var start_zoom := user_zoom
	var start_pan := _pan
	create_tween().tween_method(func(t: float) -> void:
		user_zoom = lerpf(start_zoom, 1.0, t)
		_pan = start_pan.lerp(Vector2.ZERO, t)
		_apply_transform(), 0.0, 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Keeps the zoomed board covering its area (no panning off into empty space).
func _clamp_pan() -> void:
	var board_px := Vector2(cols, rows) * CELL * _base_scale * user_zoom
	var slack := CELL * _base_scale.x * user_zoom * 0.5 if user_zoom > 1.001 else 0.0
	var lim := ((board_px - _fit_rect.size) / 2.0).max(Vector2.ZERO) + Vector2(slack, slack)
	_pan = _pan.clamp(-lim, lim)


func _pan_by(delta: Vector2) -> void:
	if user_zoom <= 1.001:
		return
	_pan += delta
	_clamp_pan()
	_apply_transform()

## Hit-stop: freeze time for a split second on big impacts so they land with weight.
func _hit_stop(real_seconds: float) -> void:
	Engine.time_scale = 0.05
	get_tree().create_timer(real_seconds, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


# --- Input: tap, pinch-zoom and pan ------------------------------------------------------------------
# Phones send real touch events (emulated mouse events from them are ignored here),
# desktop sends mouse events. A tap fires on release, only if the finger didn't move,
# so dragging the zoomed board never launches an arrow by accident.

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		_touches.clear()
		_mouse_down = false
		return
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if _mouse_down:
			_single_drag(_to_parent(event.position), event.relative)
	elif event is InputEventMagnifyGesture:
		zoom_at(_to_parent(event.position), user_zoom * event.factor)
	elif event is InputEventPanGesture:
		_pan_by(-event.delta * 12.0)


func _on_touch(e: InputEventScreenTouch) -> void:
	var p := _to_parent(e.position)
	if e.pressed:
		if _touches.is_empty() and not _fit_rect.has_point(p):
			return  # started outside the board (e.g. on a HUD button)
		_touches[e.index] = p
		if _touches.size() == 1:
			_tap_valid = true
			_tap_start = p
			_press_at(p)
		else:
			_tap_valid = false
			_pinch_dist = 0.0
			_press_at(Vector2.INF)
		get_viewport().set_input_as_handled()
	elif _touches.has(e.index):
		_press_at(Vector2.INF)
		_touches.erase(e.index)
		if _tap_valid and _touches.is_empty():
			_tap(p)
		_tap_valid = false
		_pinch_dist = 0.0
		get_viewport().set_input_as_handled()


func _on_drag(e: InputEventScreenDrag) -> void:
	if not _touches.has(e.index):
		return
	var p := _to_parent(e.position)
	_touches[e.index] = p
	if _touches.size() == 1:
		_single_drag(p, e.relative)
	else:
		var pts: Array = _touches.values()
		var a: Vector2 = pts[0]
		var b: Vector2 = pts[1]
		var dist := a.distance_to(b)
		var mid := (a + b) / 2.0
		if _pinch_dist > 0.0:
			zoom_at(mid, user_zoom * dist / _pinch_dist)
			_pan_by(mid - _pinch_mid)
		_pinch_dist = dist
		_pinch_mid = mid
	get_viewport().set_input_as_handled()


func _single_drag(p: Vector2, relative: Vector2) -> void:
	if _tap_valid and p.distance_to(_tap_start) > TAP_SLOP:
		_tap_valid = false
		_press_at(Vector2.INF)  # it became a pan: let the arrow spring back
	if not _tap_valid:
		_pan_by(relative)


func _on_mouse_button(e: InputEventMouseButton) -> void:
	var p := _to_parent(e.position)
	var inside := _fit_rect.has_point(p)
	match e.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if inside and e.pressed:
				zoom_at(p, user_zoom * 1.15)
		MOUSE_BUTTON_WHEEL_DOWN:
			if inside and e.pressed:
				zoom_at(p, user_zoom / 1.15)
		MOUSE_BUTTON_LEFT:
			if e.pressed:
				if not inside:
					return
				_mouse_down = true
				_tap_valid = true
				_tap_start = p
				_press_at(p)
			elif _mouse_down:
				_press_at(Vector2.INF)
				_mouse_down = false
				if _tap_valid:
					_tap(p)
				_tap_valid = false
		_:
			return
	if inside:
		get_viewport().set_input_as_handled()


## Finger down at `p` (parent coordinates): the arrow that a tap here would launch dips.
## Vector2.INF releases whatever was pressed.
func _press_at(p: Vector2) -> void:
	var hit: ArrowPath = null
	if p != Vector2.INF and input_enabled and not _resolving:
		var local := (p - position) / scale.x
		var best_dist := CELL * 0.5
		for a in arrows:
			if a.busy:
				continue
			var d := a.distance_to_point(local)
			if d < best_dist:
				best_dist = d
				hit = a
	if hit == _pressed:
		return
	if _pressed and is_instance_valid(_pressed):
		_pressed.set_pressed(false)
	_pressed = hit
	if hit:
		hit.set_pressed(true)
		GameData.vibrate(8)


## A finished tap at `p` (parent coordinates): launch the nearest arrow, or
## double-tap on empty space to zoom back out.
func _tap(p: Vector2) -> void:
	var local := (p - position) / scale.x
	var best: ArrowPath = null
	var best_dist := INF
	var runner: ArrowPath = null       # the second-nearest arrow
	var runner_dist := INF
	for a in arrows:
		var d := a.distance_to_point(local)
		if d < best_dist:
			runner = best
			runner_dist = best_dist
			best_dist = d
			best = a
		elif d < runner_dist:
			runner_dist = d
			runner = a
	if best_dist >= CELL * 0.5:
		best = null  # nothing close enough under the finger
	if best and (tutorial_block or (tutorial_only != null and best != tutorial_only)):
		return  # the tutorial is pointing at something else
	if best and runner and tutorial_only == null and best_dist > CELL * SURE_DIST \
			and runner_dist - best_dist < CELL * UNSURE_MARGIN:
		_unsure_tap(p, local, best, runner)
		return
	if best:
		_on_arrow_tapped(best)
		return
	if _clock - _last_empty_tap < 0.35 and absf(user_zoom - 1.0) > 0.001:
		reset_zoom()
	_last_empty_tap = _clock


## The finger landed between two arrows. Launching the wrong one would cost a heart,
## so nothing moves: tiny boards zoom in on the spot, otherwise both arrows blink.
func _unsure_tap(p: Vector2, local: Vector2, a: ArrowPath, b: ArrowPath) -> void:
	if not input_enabled or _resolving:
		return
	var cell_px := CELL * scale.x
	if cell_px < SMALL_CELL_PX and user_zoom < MAX_ZOOM - 0.01:
		var from := user_zoom
		var to := minf(MAX_ZOOM, maxf(from * HELP_ZOOM, SMALL_CELL_PX * 1.4 / (CELL * _base_scale.x)))
		create_tween().tween_method(func(z: float) -> void: zoom_at(p, z), from, to, 0.3) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		zoomed.emit()
		GameData.play_sfx("tap")
		return
	for arrow: ArrowPath in [a, b]:
		if not arrow.busy:
			arrow.nudge()
	GameData.play_sfx("tap")
	combo_text.emit("TAP CLOSER", Color("#475569"), local)


func _to_parent(viewport_pos: Vector2) -> Vector2:
	var parent := get_parent() as CanvasItem
	return parent.get_global_transform_with_canvas().affine_inverse() * viewport_pos if parent else viewport_pos

func _on_arrow_tapped(arrow: ArrowPath) -> void:
	if not input_enabled or arrow.busy or _resolving:
		return
	clear_hint()
	if arrow.ice > 0 and not power_armed:
		# Frozen: it can't move. A little shiver, no heart and no move lost.
		arrow.flash_blocked(0.0)
		GameData.play_sfx("crack", 1.6)
		GameData.vibrate(20)
		_say("FROZEN!", Color("#0284c7"), arrow.head(), 0.0)
		return
	var partner := _partner(arrow)
	if partner and not power_armed:
		if _free_with(arrow, partner) and _free_with(partner, arrow) and not partner.busy:
			# Both lanes clear: the pair flies out together.
			_begin_action(arrow)
			_take(arrow, 0.08, true)
			_take(partner, 0.08, true)
			_escape(arrow, 0.0)
			_escape(partner, 0.06)
			_say("LINKED x2!", Color("#64748b"), arrow.head(), 0.1)
			_finish_action(false)
		else:
			arrow.flash_blocked(0.0)
			partner.flash_blocked(0.0)
			GameData.play_sfx("thud", 1.5)
			_say("LINKED!", Color("#475569"), arrow.head(), 0.0)
		return
	var gap := arrow.blocked_gap(occupancy)
	var blocker: ArrowPath = null
	if gap >= 0:
		blocker = occupancy[arrow.lane_cells()[gap]]
	var cgap := _crate_gap(arrow)
	if not power_armed and arrow.special == ArrowPath.Special.NONE:
		if cgap >= 0 and (gap < 0 or cgap < gap):
			_shoot_obstacle(arrow, cgap, null)
			return
		if blocker != null and blocker != arrow and blocker.ice > 0:
			_shoot_obstacle(arrow, gap, blocker)
			return

	if power_armed:
		# Booster: this arrow fires it for one shot (drill / bomb / laser / colour wipe).
		var kind := armed
		armed = ArrowPath.Special.NONE
		_begin_action(arrow, true)
		_entry.booster = kind
		_take(arrow)
		# A colour wipe takes the tapped arrow's own colour; the booster bomb is bigger.
		_fire(arrow, kind, 0.0, true, arrow if kind == ArrowPath.Special.RAINBOW else null, true)
		_finish_action(true)
	elif arrow.special != ArrowPath.Special.NONE:
		_begin_action(arrow)
		_take(arrow)
		if blocker != null and blocker != arrow and blocker.special != ArrowPath.Special.NONE:
			_combo(arrow, blocker, gap)
		else:
			_fire(arrow, arrow.special, 0.0, true, blocker)
		_finish_action(true)
	elif blocker == null:
		_begin_action(arrow)
		_take(arrow, 0.08, true)
		_escape(arrow, 0.0)
		_finish_action(false)
	elif blocker != arrow and _crushes(arrow, blocker):
		_begin_action(arrow)
		_take(arrow)
		_crush(arrow, blocker, gap)
		_finish_action(true)
	else:
		var hit_cell := arrow.lane_cells()[gap]
		var hit_time := arrow.bump(gap)
		if blocker != arrow:
			blocker.flash_blocked(hit_time)
			blocker.wobble(hit_time)
		var contact := _center(hit_cell) - Vector2(arrow.lane_dirs()[gap]) * CELL * 0.45
		_burst(contact, Color.WHITE, hit_time, 7)
		_later(hit_time, _on_impact.bind(hit_cell))
		arrow_blocked.emit(arrow)


## The arrow flies into a crate (or a frozen arrow), knocks a layer off and springs back.
## Counts as a move but never costs a heart.
func _shoot_obstacle(arrow: ArrowPath, gap: int, frozen: ArrowPath) -> void:
	_begin_action(arrow)
	var cell := arrow.lane_cells()[gap]
	var hit_time := arrow.bump(gap)
	if frozen:
		frozen.flash_blocked(hit_time)
		_crack_ice(frozen, hit_time)
	else:
		_knock_crate(cell, hit_time)
	_later(hit_time, func() -> void:
		shake(5.0)
		GameData.vibrate(25))
	_extend(hit_time + 0.35)
	_finish_action(true)


## Knocks one layer off the crate at `cell` (once per tap); the knock shows after `delay`.
func _knock_crate(cell: Vector2i, delay: float, once_per_tap: bool = true) -> void:
	if not crates.has(cell) or (once_per_tap and _cracked.has(cell)):
		return
	_cracked[cell] = true
	goal_piece.emit("crates", _center(cell), delay, CRATE_TEX[clampi(int(crates[cell]), 1, 3) - 1], -1)
	crates[cell] -= 1
	var broken: bool = crates[cell] <= 0
	if broken:
		crates.erase(cell)
		_removed_cells[cell] = true  # lanes through it are open now (same-colour cascade)
	_entry.crates.append(cell)
	_burst(_center(cell), Color("#b45309"), delay, 16 if broken else 8)
	_burst(_center(cell), Color("#fcd34d"), delay, 6)
	if broken:
		_add_ring(cell, CELL * 0.8, Color("#d97706"), delay, 0.3)
	_later(delay, func() -> void:
		_crate_view[cell] = maxi(0, int(_crate_view.get(cell, 1)) - 1)
		if _crate_view[cell] <= 0:
			_crate_view.erase(cell)
		GameData.play_sfx("wood", randf_range(0.9, 1.15) if not broken else 0.8)
		goals_changed.emit())
	_extend(delay + 0.3)


## Cracks one layer of ice on a frozen arrow (once per tap).
func _crack_ice(arrow: ArrowPath, delay: float, once_per_tap: bool = true) -> void:
	if arrow.ice <= 0 or (once_per_tap and _cracked.has(arrow)):
		return
	_cracked[arrow] = true
	arrow.ice -= 1
	_entry.ice.append(arrow.head())
	var mid := _center(arrow.cells[arrow.cells.size() / 2])
	goal_piece.emit("ice", mid, delay, ICE_TEX[1], -1)
	_burst(mid, Color("#7dd3fc"), delay, 14)
	_burst(mid, Color.WHITE, delay, 8)
	if arrow.ice == 0:
		_say("FREE!", Color("#0284c7"), arrow.head(), delay)
	# Read the ice now: the arrow itself may be gone (crushed) before the sound plays.
	var pitch := 1.0 if arrow.ice > 0 else 0.8
	_later(delay, func() -> void:
		GameData.play_sfx("crack", pitch)
		goals_changed.emit())
	_extend(delay + 0.3)


## Crates and frozen arrows next to a removed arrow crack.
## Every removed arrow knocks each neighbouring obstacle once - also when a crush or a
## blast removes several arrows in one tap (the level generator counts on that).
func _crack_beside(arrow: ArrowPath, delay: float) -> void:
	var done := {}
	for c in arrow.cells:
		for d in NEIGHBOURS:
			var n := c + d
			if crates.has(n) and not done.has(n):
				done[n] = true
				_knock_crate(n, delay, false)
			var other: ArrowPath = occupancy.get(n)
			if other != null and other.ice > 0 and not done.has(other):
				done[other] = true
				_crack_ice(other, delay, false)


func _on_impact(hit_cell: Vector2i) -> void:
	GameData.play_sfx("thud")
	GameData.vibrate(40)
	_hit_stop(0.07)  # the "ouch" moment: everything holds for a beat
	shake()
	_ripple(hit_cell, 0.0, RIPPLE_RED, 1.2)


# --- Resolving one tap ---------------------------------------------------------------------------------

func _begin_action(arrow: ArrowPath, power: bool = false) -> void:
	_resolving = true
	_chain = 0
	_chain_color = arrow.color_index
	_chain_colors = {arrow.color_index: true}
	_focus = arrow.head()
	_action_end = _clock
	_removed_cells = {}
	_entry = {"arrows": [], "power": power, "upgrades": [], "balloons": [], "targets": [], "moved": [],
		"crates": [], "ice": [], "ticked": [], "flipped": [], "crept": []}
	_cracked = {}


## Takes an arrow out of the puzzle logic right away (its animation may still run).
## Balloons next to it lose a layer `delay` seconds from now. Returns false if it was
## already taken. Everything that is not `escaping` (flying out) counts as a crush.
func _take(arrow: ArrowPath, delay: float = 0.08, escaping: bool = false) -> bool:
	if not arrows.has(arrow):
		return false
	_entry.arrows.append(_flags_of(arrow))
	for i in arrow.cells.size():
		# The paint shows through from the tail to the head, following the arrow out.
		_revealed[arrow.cells[i]] = _clock + delay + 0.08 + i * 0.035
	_leave_paint(arrow, delay)
	var at := _center(arrow.cells[arrow.cells.size() / 2])
	if arrow.golden:
		golden_out += 1
		goal_piece.emit("golden", at, delay, null, -1)
	else:
		goal_piece.emit("arrow", at, delay, null, arrow.color_index)
	if not escaping:
		crushed += 1
		_entry.crushed = int(_entry.get("crushed", 0)) + 1
		goal_piece.emit("crush", at, delay, null, arrow.color_index)
	if arrow.timer > 0:
		bonus_out += 1
		_say("BONUS +%d" % BONUS_COINS, Color("#d97706"), arrow.head(), delay)
		_later(delay, GameData.play_sfx.bind("ding", 1.2))
	for c in arrow.cells:
		occupancy.erase(c)
		_removed_cells[c] = true
	arrows.erase(arrow)
	_chain += 1
	color_removed[arrow.color_index] = int(color_removed.get(arrow.color_index, 0)) + 1
	for c: Vector2i in _balloons_beside(arrow):
		_pop_balloon(c, delay)
	_crack_beside(arrow, delay)
	return true


func _balloons_beside(arrow: ArrowPath) -> Dictionary:
	var near := {}
	for c in arrow.cells:
		for d in NEIGHBOURS:
			if balloons.has(c + d):
				near[c + d] = true
	return near


## An arrow flying out along its lane pierces the balloons in it (the ones beside it
## were already popped by _take) and hits every target on its way out.
func _fly_through(arrow: ArrowPath, delay: float) -> void:
	var beside := _balloons_beside(arrow)
	var lane: Array[Vector2i] = arrow.lane_cells().duplicate()
	lane.append(arrow.exit_cell)
	for s in lane.size():
		var c: Vector2i = lane[s]
		var t := delay + arrow.time_to_slide((arrow.cells.size() + s) * CELL)
		if balloons.has(c) and not beside.has(c):
			_pop_balloon(c, t)
		if targets.has(c) and not targets[c]:
			_hit_target(c, arrow.base_color(), t)


## Cells an arrow passes on its way out (its lane plus the first cell past the edge).
func _path_has(arrow: ArrowPath, cell: Vector2i) -> bool:
	return arrow.exit_cell == cell or arrow.lane_cells().has(cell)


## Marks the arrows that would hit a target if they flew out (they get a bullseye badge),
## so the player knows not to crush them.
func _update_aimers() -> void:
	_aimers.clear()
	for a in arrows:
		for t: Vector2i in targets:
			if not targets[t] and _path_has(a, t):
				_aimers[a] = true
				break


## A target that no arrow left on the board can reach any more (the arrows aimed at it
## were crushed or blasted) moves to where a remaining arrow flies out - so the level
## can still be won while there are arrows. Recorded for Undo.
func _rescue_targets() -> void:
	for t: Vector2i in targets.keys():
		if targets[t]:
			continue
		var reachable := false
		for a in arrows:
			if _path_has(a, t):
				reachable = true
				break
		if reachable or arrows.is_empty():
			continue
		var best := Vector2i.ZERO
		var best_score := INF
		for a in arrows:
			var e := LevelGenerator.shape_exit(a.lane_cells(), a.exit_cell, mask)
			if targets.has(e):
				continue
			var outside := not (e.x >= 0 and e.y >= 0 and e.x < cols and e.y < rows)
			var score := Vector2(e - t).length() + (100.0 if outside else 0.0)  # keep the board fit
			if score < best_score:
				best_score = score
				best = e
		if best_score == INF:
			continue
		targets.erase(t)
		targets[best] = false
		_entry.moved.append([t, best])
		_add_ring(t, CELL * 0.8, Color("#ef4444"), 0.0, 0.35)
		_add_ring(best, CELL * 1.2, Color("#ef4444"), 0.1, 0.5)
		_burst(_center(best), Color("#fbbf24"), 0.1, 16)
		_say("TARGET MOVED!", Color("#dc2626"), best, 0.1)
		if best_score >= 100.0:
			fit_to(_fit_rect)  # the new spot is past the edge: make room for it
	if not _entry.moved.is_empty():
		goals_changed.emit()


func _hit_target(c: Vector2i, color: Color, t: float) -> void:
	targets[c] = true
	_entry.targets.append(c)
	_target_hit_at[c] = _clock + t
	goal_piece.emit("targets", _center(c), t, TARGET_TEX, -1)
	_impact(_center(c), t, CELL * 1.1, color)
	_add_ring(c, CELL * 1.2, Color("#ef4444"), t, 0.4)
	_burst(_center(c), Color("#fbbf24"), t, 24)
	_say("BULLSEYE!", Color("#dc2626"), c, t)
	_later(t, func() -> void:
		GameData.play_sfx("thunk")
		GameData.vibrate(40)
		shake(6.0)
		goals_changed.emit())
	_extend(t + 0.3)


## Pops one layer of the balloon at `cell` (logic now, the pop shows after `delay`).
func _pop_balloon(cell: Vector2i, delay: float) -> void:
	if not balloons.has(cell):
		return
	balloons[cell] -= 1
	if balloons[cell] <= 0:
		balloons.erase(cell)
	_entry.balloons.append(cell)
	var color := _balloon_color(cell)
	goal_piece.emit("balloons", _center(cell), delay, BALLOON_TEX[posmod(cell.x * 7 + cell.y * 13, BALLOON_COLORS.size())], -1)
	_burst(_center(cell), color, delay, 18)
	_add_ring(cell, CELL * 0.7, color, delay, 0.3)
	_later(delay, func() -> void:
		_balloon_view[cell] = maxi(0, int(_balloon_view.get(cell, 1)) - 1)
		if _balloon_view[cell] <= 0:
			_balloon_view.erase(cell)
		GameData.play_sfx("pop", randf_range(0.9, 1.25))
		goals_changed.emit())
	_extend(delay + 0.3)


## Pops every balloon in `cells` (blasts).
func _pop_cells(cells: Array, delay: float) -> void:
	for c: Vector2i in cells:
		if balloons.has(c):
			_pop_balloon(c, delay)


func _escape(arrow: ArrowPath, delay: float) -> void:
	arrow.slide_out(false, delay)
	# A small burst of sparks right where the head crosses the board edge.
	var to_edge := (arrow.lane_cells().size() + 0.5) * CELL
	var edge_pos := _center(arrow.exit_cell) - Vector2(arrow.exit_dir) * CELL * 0.5
	_burst(edge_pos, arrow.base_color().lightened(0.45), delay + arrow.time_to_slide(to_edge), 8)
	_ripple_escape(arrow, _palette, delay)
	_fly_through(arrow, delay)
	var pitch := 1.0 + 0.08 * maxi(0, _chain - 1) + randf_range(-0.04, 0.04)
	_later(delay, func() -> void:
		GameData.play_sfx("slide", pitch)
		GameData.vibrate(15))
	_extend(delay + arrow.time_to_slide(INF))


## Same colour: `a` rushes into `b` and both break apart.
func _crush(a: ArrowPath, b: ArrowPath, gap: int, delay: float = 0.0) -> void:
	var hit_cell := a.lane_cells()[gap]
	var power := crush_power(a)
	var t := a.crush_into(gap, delay, power)
	_focus = hit_cell
	_shatter_fx(a, t, _center(hit_cell))
	_destroy(b, t)
	_power_hit(hit_cell, a.base_color(), t, power, 1.0, 0.12 * maxi(0, _chain - 2))
	_splash(hit_cell, a, b, t)
	if power == 2:
		_say("POWER CRUSH!", a.base_color(), hit_cell, t)
	_prism_turn(a, b, t)
	_domino(b, t)


## Domino crush: a crushed arrow passes the hit on to the next arrow in ITS way if
## that one has the same colour too - and so on down the line (Candy-Crush-style
## chain reactions that build big chains and special arrows).
func _domino(from: ArrowPath, delay: float, depth: int = 0) -> void:
	if depth > 40:
		return
	var gap := from.blocked_gap(occupancy)  # `from` is already out of the occupancy map
	if gap < 0:
		return
	var hit_cell := from.lane_cells()[gap]
	var next: ArrowPath = occupancy[hit_cell]
	if not _crushes(from, next) or next.ice > 0:
		return
	var t := delay + 0.14 + gap * 0.03
	var color := from.base_color()
	_add_beam(_center(from.head()), _center(hit_cell), color, delay + 0.06)
	_focus = hit_cell
	# The crushed arrow passes the hit on with its own power (its own length).
	_power_hit(hit_cell, color, t, crush_power(from), 0.85, 0.12 * maxi(0, _chain - 1))
	_destroy(next, t)
	_splash(hit_cell, from, next, t)
	_prism_turn(from, next, t)
	_domino(next, t, depth + 1)


## How hard an arrow crushes, from its length: 0 small (2-3 cells), 1 normal (4-7),
## 2 big (8+). Only the look and feel changes - the rules are the same for every size.
static func crush_power(a: ArrowPath) -> int:
	var n := a.cells.size()
	return 0 if n <= 3 else (1 if n <= 7 else 2)


## One crush impact at `hit_cell`, sized by `power`:
##   small  - a quick, bright, high "pop": light burst, tiny shake, no freeze
##   normal - the classic crush: burst, flash, shake, a short freeze-frame
##   big    - a heavy SLAM: huge burst, a shockwave ring that rolls over the board and
##            rocks nearby arrows, deep sound, long freeze, strong buzz
## `scale` shrinks it for domino hits; `rise` raises the pitch as the chain grows.
func _power_hit(hit_cell: Vector2i, color: Color, t: float, power: int, scale_k: float, rise: float) -> void:
	var pos := _center(hit_cell)
	var burst: float = [0.65, 1.0, 1.55][power] * scale_k
	_impact(pos, t, CELL * [0.6, 0.9, 1.4][power] * scale_k, color)
	_add_ring(hit_cell, CELL * [0.6, 0.9, 1.5][power] * scale_k, color, t, [0.25, 0.35, 0.45][power])
	_crush_burst(pos, color, t, burst)
	if power >= 1 and scale_k >= 1.0:
		_board_flash(Color.WHITE, [0.0, 0.45, 0.6][power], t)
	if power == 0:
		_burst(pos, Color.WHITE, t, 10)  # small arrows: a crisp white snap
	if power == 2:
		# Shockwave: a second, wider ring, the board dots ripple out two cells and the
		# arrows nearby get rocked by the blast.
		_add_ring(hit_cell, CELL * 2.8 * scale_k, color.lightened(0.3), t + 0.05, 0.5)
		_burst(pos, color.lightened(0.5), t, 24)
		var rocked := {}
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var c := hit_cell + Vector2i(dx, dy)
				var ring_t := t + Vector2(dx, dy).length() * 0.04
				_ripple(c, ring_t, color, 1.1)
				var other: ArrowPath = occupancy.get(c)
				if other != null and not rocked.has(other):
					rocked[other] = true
					other.wobble(ring_t)
	var pitch: float = [1.22, 1.0, 0.78][power] + rise
	var buzz: int = [20, 35, 70][power]
	var quake: float = [4.0, 8.0, 15.0][power] * scale_k
	var zoom: float = [0.0, 0.015, 0.035][power] * scale_k
	var freeze: float = [0.0, 0.055, 0.1][power] * scale_k
	if scale_k < 1.0 and power < 2:
		freeze = 0.0  # chain hits only freeze for the big ones, so long chains keep flowing
	_later(t, func() -> void:
		GameData.play_sfx("crush", pitch)
		if power == 2:
			GameData.play_sfx("thud", 0.7)  # a heavy body under the crack
		GameData.vibrate(buzz)
		shake(quake)
		if zoom > 0.0:
			punch(zoom)
		if freeze > 0.0:
			_hit_stop(freeze))
	_extend(t + [0.3, 0.35, 0.5][power])


## Same colour crushes, and a prism arrow takes any colour (never a golden one).
func _crushes(hitter: ArrowPath, target: ArrowPath) -> bool:
	if target.golden or hitter.golden:
		return false
	return target.color_index == hitter.color_index or target.prism


## A chain that broke a prism of another colour carries on in the prism's colour.
func _prism_turn(from: ArrowPath, prism_arrow: ArrowPath, t: float) -> void:
	if not prism_arrow.prism or prism_arrow.color_index == from.color_index:
		return
	_chain_colors[prism_arrow.color_index] = true
	_add_rainbow_ring(_center(prism_arrow.head()), CELL * 1.1, t, 0.45)
	_say("PRISM!", prism_arrow.base_color(), prism_arrow.head(), t)
	_later(t, GameData.play_sfx.bind("charge", 1.3))


const WIND_UP_FX := 0.16  # seconds a tapped bomb / laser / rainbow charges before it goes off

## A one-shot sprite effect: shows after `delay`, grows from `from_size` to `to_size` px
## wide over `dur` while turning by `spin` and drifting by `move`, and fades out after
## `fade_from` of its time.
func _sprite_fx(tex: Texture2D, pos: Vector2, delay: float, from_size: float, to_size: float, dur: float,
		spin := 0.0, tint := Color.WHITE, z := 18, move := Vector2.ZERO, fade_from := 0.4) -> void:
	_later(delay, func() -> void:
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sp.position = pos
		sp.modulate = tint
		sp.z_index = z
		sp.scale = Vector2.ONE * from_size / tex.get_width()
		add_child(sp)
		var t := sp.create_tween().set_parallel(true)
		t.tween_property(sp, "scale", Vector2.ONE * to_size / tex.get_width(), dur) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		if spin != 0.0:
			t.tween_property(sp, "rotation", spin, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if move != Vector2.ZERO:
			t.tween_property(sp, "position", pos + move, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(sp, "modulate:a", 0.0, dur * (1.0 - fade_from)).set_delay(dur * fade_from)
		t.chain().tween_callback(sp.queue_free))
	_extend(delay + dur)


## Wind-up of a tapped special: its badge swells up over the arrow with a glow, a
## rising charge sound, and a light buzz - then the effect fires WIND_UP_FX later.
## The badge copy starts exactly where (and as big as) the arrow's own badge, and that
## one is hidden at the same moment - so there is only ever one bomb / cross on screen.
func _charge(arrow: ArrowPath, badge: Texture2D, delay: float, glow: Color, spin := 0.0) -> void:
	var mid := arrow.badge_center() + arrow.position
	var size := arrow.badge_size()
	_sprite_fx(ArrowPath.FX_FLARE, mid, delay, CELL * 0.6, CELL * 2.2, WIND_UP_FX + 0.04, 1.2, glow, 19, Vector2.ZERO, 0.8)
	_sprite_fx(badge, mid, delay, size, size * 1.6, WIND_UP_FX, spin, Color.WHITE, 20, Vector2.ZERO, 0.85)
	if badge == ArrowPath.SP_RAINBOW:
		_sprite_fx(ArrowPath.SP_ORB, mid, delay, size, size * 1.6, WIND_UP_FX, 0.0, Color.WHITE, 21, Vector2.ZERO, 0.85)
	if arrow.special != ArrowPath.Special.NONE:
		if delay <= 0.0:
			arrow.badge_hidden = true
		else:
			_later(delay, func() -> void:
				if is_instance_valid(arrow):
					arrow.badge_hidden = true)
	_later(delay, func() -> void:
		GameData.play_sfx("charge", 1.5)
		GameData.vibrate(15))


## Removes an arrow with a break animation. A special arrow that gets destroyed
## fires its own effect from where it stands (chain reactions).
func _destroy(arrow: ArrowPath, delay: float) -> void:
	if arrow.golden and arrows.has(arrow):
		arrow.flash_blocked(delay)  # golden arrows shrug off blasts
		_say("SHIELDED!", ArrowPath.ARROW_COLORS[LevelGenerator.GOLD], arrow.head(), delay)
		return
	if arrow.ice > 0 and arrows.has(arrow):
		_crack_ice(arrow, delay)  # a blast cracks the ice instead of breaking the arrow
		return
	if not _take(arrow, delay):
		return
	arrow.shatter(delay)
	_shatter_fx(arrow, delay, _center(_focus))
	for c in arrow.cells:
		_ripple(c, delay, arrow.base_color(), 0.9)
	_burst(_center(arrow.cells[arrow.cells.size() / 2]), arrow.base_color(), delay, 12)
	if arrow.special != ArrowPath.Special.NONE:
		_fire(arrow, arrow.special, delay + 0.08, false, null)
	_extend(delay + 0.3)


## A special arrow's effect. `tapped` = fired by the player's tap (the arrow itself
## still has to be animated away); otherwise it was set off by another blast.
func _fire(arrow: ArrowPath, kind: ArrowPath.Special, delay: float, tapped: bool, blocker: ArrowPath,
		booster: bool = false) -> void:
	var h := arrow.head()
	var color := arrow.base_color()
	match kind:
		ArrowPath.Special.DRILL:
			if tapped:
				# Flies out along its lane, smashing everything in the way; sparks spray
				# off every cell it bores through.
				arrow.slide_out(true, delay)
				_ripple_escape(arrow, _power_palette, delay)
				_fly_through(arrow, delay)
				var step := 1
				for c in arrow.lane_cells():
					var at := delay + arrow.time_to_slide(step * CELL)
					var victim: ArrowPath = occupancy.get(c)
					if victim:
						_destroy(victim, at)
						_sprite_fx(ArrowPath.FX_FLARE, _center(c), at, CELL * 0.6, CELL * 1.6, 0.24, 1.2, Color(1.0, 0.8, 0.4))
						_burst(_center(c), Color("#fbbf24"), at, 8)
					elif step % 2 == 0:
						_sprite_fx(ArrowPath.FX_FLARE, _center(c), at, CELL * 0.3, CELL * 0.8, 0.18, 0.8, Color(1.0, 0.85, 0.5, 0.8))
					_knock_crate(c, at)
					step += 1
				_extend(delay + arrow.time_to_slide(INF))
				_later(delay, GameData.play_sfx.bind("power"))
			else:
				_drill_beam(arrow, delay)
			_say("DRILL!", ArrowPath.COLOR_POWER, h, delay)
		ArrowPath.Special.BOMB:
			var t := delay
			if tapped:
				# Wind-up: the bomb swells and flashes at the head, then blows.
				t = delay + WIND_UP_FX
				_charge(arrow, ArrowPath.SP_BOMB, delay, Color(1.0, 0.75, 0.4))
				arrow.shatter(t)
				_shatter_fx(arrow, t, _center(h))
			_explode(h, 2 if booster else 1, t, color)
			_say("MEGA BOOM!" if booster else "BOOM!", color, h, t)
		ArrowPath.Special.LASER:
			var t := delay
			if tapped:
				t = delay + WIND_UP_FX
				_charge(arrow, ArrowPath.SP_LASER, delay, Color(1.0, 0.5, 0.6))
				arrow.shatter(t)
				_shatter_fx(arrow, t, _center(h))
			_laser(h, [h.y], [h.x], t, color)
			_say("LASER!", color, h, t)
		ArrowPath.Special.RAINBOW:
			if tapped:
				arrow.shatter(delay)
				_shatter_fx(arrow, delay, _center(h))
			var target := blocker.color_index if blocker else _most_common_color()
			_color_wipe(target, h, delay)
			_say("COLOR WIPE!", ArrowPath.ARROW_COLORS[target], h, delay)


## Special arrow tapped straight into another special arrow.
func _combo(a: ArrowPath, b: ArrowPath, gap: int) -> void:
	var t := a.crush_into(gap)
	var hit := b.head()
	_take(b)          # taken without firing: the combo replaces both effects
	b.shatter(t)
	_focus = hit
	_shatter_fx(a, t, _center(hit))
	_shatter_fx(b, t, _center(hit))
	_impact(_center(hit), t, CELL * 1.6, Color.WHITE)
	_board_flash(Color.WHITE, 0.4, t)
	var ka := a.special
	var kb := b.special
	var color := b.base_color()
	if ka == ArrowPath.Special.RAINBOW and kb == ArrowPath.Special.RAINBOW:
		_say("BOARD WIPE!!", Color("#7c3aed"), hit, t)
		for victim in arrows.duplicate():
			var dv := t + Vector2(victim.head() - hit).length() * 0.04
			_add_bolt(_center(hit), _center(victim.head()), dv - 0.12)
			_destroy(victim, dv)
		_add_ring(hit, CELL * maxf(cols, rows), Color("#a855f7"), t, 0.8)
		_add_rainbow_ring(_center(hit), CELL * maxf(cols, rows) * 1.2, t, 0.9)
	elif ka == ArrowPath.Special.RAINBOW or kb == ArrowPath.Special.RAINBOW:
		var other := kb if ka == ArrowPath.Special.RAINBOW else ka
		var target := _most_common_color()
		_say("COLOR STORM!", ArrowPath.ARROW_COLORS[target], hit, t)
		_color_wipe(target, hit, t)
		_fire(b, other, t + 0.1, false, null)
	elif ka == ArrowPath.Special.BOMB and kb == ArrowPath.Special.BOMB:
		_say("MEGA BOMB!", color, hit, t)
		_explode(hit, 2, t, color)
	elif ka == ArrowPath.Special.BOMB or kb == ArrowPath.Special.BOMB:
		_say("BIG CROSS!", color, hit, t)
		_laser(hit, [hit.y - 1, hit.y, hit.y + 1], [hit.x - 1, hit.x, hit.x + 1], t, color)
	else:
		_say("CROSS BLAST!", color, hit, t)
		_laser(hit, [hit.y], [hit.x], t, color)
	_extend(t + 0.5)


## Destroys every arrow touching the (2r+1) x (2r+1) square around `center`.
func _explode(center: Vector2i, r: int, delay: float, color: Color) -> void:
	_focus = center  # pieces fly away from the blast
	_impact(_center(center), delay, CELL * (1.3 + 0.6 * r), color)
	_board_flash(Color.WHITE, 0.3 + 0.1 * r, delay)
	_add_ring(center, CELL * (r + 0.6), color, delay, 0.45)
	_add_ring(center, CELL * (r + 1.6), color.lightened(0.4), delay + 0.08, 0.6)
	_burst(_center(center), color, delay, 36)
	_burst(_center(center), Color.WHITE, delay, 14)
	# Fireball, a hot flare and smoke puffs rolling out and up.
	var o := _center(center)
	var size := CELL * (2 * r + 1) * 1.3
	_sprite_fx(FX_FIREBALL, o, delay, CELL * 0.5, size, 0.5, randf_range(-0.7, 0.7), Color.WHITE, 19, Vector2.ZERO, 0.3)
	_sprite_fx(ArrowPath.FX_FLARE, o, delay, CELL * 0.6, size * 1.4, 0.32, 0.9, Color(1.0, 0.9, 0.6), 20)
	for k in 6 + 2 * r:
		var dir := Vector2.from_angle(k * TAU / (6 + 2 * r) + randf_range(-0.3, 0.3))
		_sprite_fx(FX_SMOKE, o + dir * CELL * 0.3, delay + 0.1, CELL * 0.7, CELL * (1.5 + 0.5 * r), 0.95,
			randf_range(-1.0, 1.0), Color(0.62, 0.56, 0.72, 0.75), 14, dir * CELL * (1.1 + 0.8 * r) + Vector2(0, -CELL * 0.5), 0.25)
	_later(delay, func() -> void:
		GameData.play_sfx("boom", 1.0 - 0.1 * (r - 1))
		GameData.vibrate(70)
		shake(16.0)
		punch(0.035 * r)
		_hit_stop(0.07))
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var c := center + Vector2i(x, y)
			var victim: ArrowPath = occupancy.get(c)
			if victim:
				_destroy(victim, delay + 0.05 + (absi(x) + absi(y)) * 0.04)
			_pop_cells([c], delay + 0.05 + (absi(x) + absi(y)) * 0.04)
			_knock_crate(c, delay + 0.05 + (absi(x) + absi(y)) * 0.04)
			_ripple(c, delay + (absi(x) + absi(y)) * 0.04, color, 1.3)
	_extend(delay + 0.5)


## Destroys every arrow with a cell in one of `row_list` / `col_list`.
func _laser(origin: Vector2i, row_list: Array, col_list: Array, delay: float, color: Color) -> void:
	# Beams shoot out from the laser arrow to both board edges.
	var o := _center(origin)
	for y: int in row_list:
		if y >= 0 and y < rows:
			var a := Vector2(0, y + 0.5) * CELL
			var b := Vector2(cols, y + 0.5) * CELL
			_add_beam(a, b, color, delay, Vector2(o.x, a.y), 0.55)
			_beam_sparks(a, b, color, delay + 0.05)
	for x: int in col_list:
		if x >= 0 and x < cols:
			var a := Vector2(x + 0.5, 0) * CELL
			var b := Vector2(x + 0.5, rows) * CELL
			_add_beam(a, b, color, delay, Vector2(a.x, o.y), 0.55)
			_beam_sparks(a, b, color, delay + 0.05)
	_impact(o, delay, CELL * 1.2, color)
	_board_flash(color.lightened(0.7), 0.25, delay)
	# A big flare where the beams start, and a bright flare racing to each board edge.
	_sprite_fx(ArrowPath.FX_FLARE, o, delay, CELL * 0.8, CELL * 3.6, 0.38, 1.4, Color(1.0, 0.7, 0.75))
	for y: int in row_list:
		if y >= 0 and y < rows:
			var start := Vector2(o.x, (y + 0.5) * CELL)
			for end_x in [0.0, cols * CELL]:
				_sprite_fx(ArrowPath.FX_FLARE, start, delay, CELL * 1.1, CELL * 1.4, 0.2, 0.0, Color.WHITE, 20,
					Vector2(end_x - start.x, 0), 0.55)
	for x: int in col_list:
		if x >= 0 and x < cols:
			var start := Vector2((x + 0.5) * CELL, o.y)
			for end_y in [0.0, rows * CELL]:
				_sprite_fx(ArrowPath.FX_FLARE, start, delay, CELL * 1.1, CELL * 1.4, 0.2, 0.0, Color.WHITE, 20,
					Vector2(0, end_y - start.y), 0.55)
	_later(delay, func() -> void:
		GameData.play_sfx("laser")
		GameData.vibrate(50)
		shake(12.0)
		punch(0.025)
		_hit_stop(0.05))
	for victim in arrows.duplicate():
		for c in victim.cells:
			if row_list.has(c.y) or col_list.has(c.x):
				_destroy(victim, delay + 0.05 + Vector2(c - origin).length() * 0.025)
				break
	for c: Vector2i in balloons.keys():
		if row_list.has(c.y) or col_list.has(c.x):
			_pop_cells([c], delay + 0.05 + Vector2(c - origin).length() * 0.025)
	for c: Vector2i in crates.keys():
		if row_list.has(c.y) or col_list.has(c.x):
			_knock_crate(c, delay + 0.05 + Vector2(c - origin).length() * 0.025)
	_extend(delay + 0.5)


## A drill set off by a blast: an instant beam down its lane.
func _drill_beam(arrow: ArrowPath, delay: float) -> void:
	var pts := _lane_points(arrow)
	for i in pts.size() - 1:
		_add_beam(pts[i], pts[i + 1], ArrowPath.COLOR_POWER, delay)
	var step := 1
	for c in arrow.lane_cells():
		var victim: ArrowPath = occupancy.get(c)
		if victim:
			_destroy(victim, delay + step * 0.03)
			_sprite_fx(ArrowPath.FX_FLARE, _center(c), delay + step * 0.03, CELL * 0.5, CELL * 1.4, 0.22, 1.0, Color(1.0, 0.8, 0.4))
		_pop_cells([c], delay + step * 0.03)
		_knock_crate(c, delay + step * 0.03)
		step += 1


## Destroys every arrow of one colour, rippling outward from `origin`.
## Rainbow lightning jumps from `origin` to each victim, under a spinning rainbow ring.
func _color_wipe(color_index: int, origin: Vector2i, delay: float) -> void:
	_later(delay, func() -> void:
		GameData.play_sfx("power")
		GameData.vibrate(60)
		shake(10.0)
		_hit_stop(0.05))
	var o := _center(origin)
	_impact(o, delay, CELL * 1.4, Color.WHITE)
	_board_flash(Color.WHITE, 0.3, delay)
	_add_rainbow_ring(o, CELL * maxf(cols, rows) * 0.9, delay, 0.75)
	_focus = origin
	var strikes := 0
	for victim in arrows.duplicate():
		if victim.color_index == color_index:
			var d := delay + 0.12 + Vector2(victim.head() - origin).length() * 0.05
			_add_bolt(o, _center(victim.head()), d - 0.12)
			_destroy(victim, d)
			_add_ring(victim.head(), CELL * 0.7, ArrowPath.ARROW_COLORS[color_index], d, 0.3)
			_star_burst(_center(victim.head()), ArrowPath.ARROW_COLORS[color_index], d)
			if strikes < 14:  # one "khat" per strike (capped so a huge wipe doesn't drone)
				var pitch := 1.35 + 0.05 * strikes + randf_range(-0.06, 0.06)
				_later(d, func() -> void:
					GameData.play_sfx("crack", pitch)
					GameData.vibrate(12)
					shake(3.0))
			strikes += 1
	_strike_goals(origin, 6, delay + 0.2)


## Lightning from `origin` to the nearest `count` goal pieces (crates, balloons, ice):
## special arrows help with the level's goal, not only with arrows.
func _strike_goals(origin: Vector2i, count: int, delay: float) -> void:
	var spots: Array = []
	for c: Vector2i in crates:
		spots.append(c)
	for c: Vector2i in balloons:
		spots.append(c)
	for a in arrows:
		if a.ice > 0:
			spots.append(a.head())
	spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a - origin).length() < Vector2(b - origin).length())
	var o := _center(origin)
	for i in mini(count, spots.size()):
		var c: Vector2i = spots[i]
		var d := delay + i * 0.06
		_add_bolt(o, _center(c), d - 0.1)
		_knock_crate(c, d, false)
		if balloons.has(c):
			_pop_balloon(c, d)
		var frozen: ArrowPath = occupancy.get(c)
		if frozen and frozen.ice > 0:
			_crack_ice(frozen, d, false)


## Same-colour arrows freed by this tap slide out on their own, one after another.
func _cascade() -> void:
	var t := _action_end - _clock
	var guard := 0
	var found := true
	while found and guard < 60:
		found = false
		for a in arrows.duplicate():
			if not _chain_colors.has(a.color_index) or a.special != ArrowPath.Special.NONE or a.busy or a.ice > 0 \
					or _partner(a) != null:
				continue
			if a.blocked_gap(occupancy) >= 0 or _crate_gap(a) >= 0 or not _lane_touches_removed(a):
				continue
			_take(a, 0.08, true)
			t += 0.12
			_escape(a, t)
			found = true
			guard += 1


## Creep: arrows whose head faces a cell this move emptied slide forward into it (up to
## creep_steps cells). The cells they leave behind start the next wave, up to creep_waves
## waves - a light ripple through the maze. Undo puts them back (entry.crept).
func _creep() -> void:
	if (creep_steps <= 0 and not magnet) or _removed_cells.is_empty() or arrows.is_empty():
		return
	var freed := _removed_cells.duplicate()
	var delay := 0.22
	var moved := 0
	var checks := [CREEP_CHECKS]
	for wave in maxi(1, creep_waves):
		var next := {}
		for a in arrows.duplicate():
			if moved >= CREEP_MAX:
				break
			if a.busy or a.ice > 0 or a.link_id >= 0 or not arrows.has(a):
				continue
			var lane: Array[Vector2i] = a.lane_cells()
			if lane.is_empty() or not freed.has(lane[0]):
				continue
			var pulled := _magnet_pull(a, lane, delay + randf_range(0.0, 0.05))
			if not pulled.is_empty():
				next.merge(pulled)  # the cells it and its partner left pull the next wave
				moved += 1
				continue
			if creep_steps <= 0:
				continue
			var steps := 0
			# Never further than its own length - 1: the arrow keeps at least one of its cells.
			var reach := mini(mini(creep_steps, lane.size()), a.cells.size() - 1)
			while steps < reach and _creep_cell_ok(lane[steps]):
				steps += 1
			if steps == 0:
				continue
			var cells: Array[Vector2i] = []
			for i in range(steps, a.cells.size()):
				cells.append(a.cells[i])
			for i in steps:
				cells.append(lane[i])
			if not _creep_safe(a, cells, checks):
				continue
			for i in steps:
				next[a.cells[i]] = true  # the tail end it leaves behind pulls the next arrow
			_creep_move(a, cells, steps, delay + randf_range(0.0, 0.05))
			moved += 1
		if next.is_empty():
			break
		_later(delay, GameData.play_sfx.bind("slide", 1.7 + wave * 0.12))
		freed = next
		delay += 0.16
	if moved > 0:
		_update_aimers()


## Magnet: `a` faces a gap the last move opened, and a same-colour arrow sits just past
## the gap (at most MAGNET_REACH empty cells away). It slides across and crushes into it -
## a chain reaction set off by the player's tap. Removing arrows never makes a maze
## unsolvable, so no solvability check is needed. Returns the cells freed ({} = no pull).
func _magnet_pull(a: ArrowPath, lane: Array[Vector2i], delay: float) -> Dictionary:
	if not magnet or a.special != ArrowPath.Special.NONE or a.flip or a.golden:
		return {}
	var gap := 0
	while gap < lane.size() and gap <= MAGNET_REACH and _creep_cell_ok(lane[gap]):
		gap += 1
	if gap == 0 or gap > MAGNET_REACH or gap >= lane.size():
		return {}
	var target: ArrowPath = occupancy.get(lane[gap])
	if target == null or target == a or target.busy or target.ice > 0 or target.link_id >= 0 \
			or target.special != ArrowPath.Special.NONE or not _crushes(a, target):
		return {}
	var freed := {}
	for c in a.cells:
		freed[c] = true
	for c in target.cells:
		freed[c] = true
	_take(a, delay)
	_crush(a, target, gap, delay)
	_say("MAGNET!", a.base_color(), lane[gap], delay + 0.15)
	return freed


## A cell an arrow may creep into: inside the shape and empty (no arrow, mirror,
## balloon or crate).
func _creep_cell_ok(c: Vector2i) -> bool:
	return mask.has(c) and not occupancy.has(c) and not mirrors.has(c) \
		and int(balloons.get(c, 0)) <= 0 and int(crates.get(c, 0)) <= 0


## True if `a` moving onto `cells` keeps the maze solvable. Only a creep that steps into
## another arrow's lane can block anything, so most creeps skip the full check.
func _creep_safe(a: ArrowPath, cells: Array[Vector2i], checks: Array) -> bool:
	var new_cells := {}
	for c in cells:
		if not a.cells.has(c):
			new_cells[c] = true
	var crosses := false
	for other in arrows:
		if other == a:
			continue
		for c in other.lane_cells():
			if new_cells.has(c):
				crosses = true
				break
		if crosses:
			break
	if not crosses:
		return true
	if checks[0] <= 0:
		return false
	checks[0] -= 1
	var list: Array = []
	for other in arrows:
		list.append(cells if other == a else other.cells)
	return LevelGenerator._solvable(list, cols, rows, mirrors)


## Moves `a` onto `cells` in the logic now; the old arrow slides forward and hands over to
## the new one when it lands (taps on it wait until then).
func _creep_move(a: ArrowPath, cells: Array[Vector2i], steps: int, delay: float) -> void:
	var flags := _flags_of(a)
	_entry.crept.append([flags.cells, cells.duplicate()])
	for c in a.cells:
		occupancy.erase(c)
	arrows.erase(a)
	var moved := _spawn(cells, flags.color, flags.special)
	_touch_paint(delay + 0.5)  # blocks under the new spot hide, freed ones come back
	_apply_flags(moved, flags)
	moved.visible = false
	moved.busy = true
	# By id, not by reference: undo or a new level may free the new arrow first.
	var id := moved.get_instance_id()
	a.creep_forward(steps * CELL, delay, func() -> void:
		var landed := instance_from_id(id) as ArrowPath
		if landed:
			landed.visible = true
			landed.busy = false)
	_extend(delay + 0.4)


func _lane_touches_removed(a: ArrowPath) -> bool:
	for c in a.lane_cells():
		if _removed_cells.has(c):
			return true
	return false


func _finish_action(chainable: bool) -> void:
	if chainable:
		_cascade()
		_later(_action_end - _clock + 0.05, _settle)
	else:
		_settle()


## The tap is fully resolved: reward big chains, announce the combo, record history.
func _settle() -> void:
	_resolving = false
	_creep()
	history.append(_entry)
	var reward: ArrowPath.Special = ArrowPath.Special.NONE
	if _chain >= 7:
		reward = ArrowPath.Special.RAINBOW
	elif _chain >= 5:
		reward = ArrowPath.Special.LASER
	elif _chain >= 4:
		reward = ArrowPath.Special.BOMB
	elif _chain >= 3:
		reward = ArrowPath.Special.DRILL
	if _chain >= 2:
		_combo_pop(_chain)
	if reward != ArrowPath.Special.NONE and not _entry.power:
		var target := _pick_upgrade_target()
		if target:
			_entry.upgrades.append({"head": target.head(), "old": target.special})
			target.set_special(reward)
			GameData.play_sfx("charge")
			_say(ArrowPath.SPECIAL_NAMES[reward] + "!", target.base_color(), target.head(), 0.35)
			special_made.emit(target)
	_after_move()
	_rescue_obstacles()
	_rescue_targets()
	_update_aimers()
	if _entry.power:
		power_blast.emit(_chain - 1)
	else:
		moved.emit(_chain)
	if arrows.is_empty() and not _cleared_sent:
		_cleared_sent = true
		_later(maxf(0.2, _action_end - _clock + 0.2), cleared.emit)


## The arrow that becomes the new special: nearest normal arrow to the action,
## preferring the colour that made the chain.
func _pick_upgrade_target() -> ArrowPath:
	var best: ArrowPath = null
	var best_score := INF
	for a in arrows:
		if a.special != ArrowPath.Special.NONE or a.busy or a.prism:
			continue
		var score := Vector2(a.head() - _focus).length() + (0.0 if a.color_index == _chain_color else 6.0)
		if score < best_score:
			best_score = score
			best = a
	return best


func _most_common_color() -> int:
	var counts := {}
	for a in arrows:
		counts[a.color_index] = counts.get(a.color_index, 0) + 1
	var best := 0
	var best_n := -1
	for k: int in counts:
		if counts[k] > best_n:
			best_n = counts[k]
			best = k
	return best


# --- Helpers ---------------------------------------------------------------------------------------------

func _spawn(arrow_cells: Array[Vector2i], color: int = 0, special: ArrowPath.Special = ArrowPath.Special.NONE) -> ArrowPath:
	var arrow := ArrowPath.new()
	add_child(arrow)
	arrow.setup(arrow_cells, CELL, cols, rows, color, special, mirrors)
	for c in arrow.cells:
		occupancy[c] = arrow
	arrows.append(arrow)
	return arrow


func _say(text: String, color: Color, cell: Vector2i, delay: float) -> void:
	_later(delay, func() -> void: combo_text.emit(text, color, _center(cell)))


func _later(delay: float, callable: Callable) -> void:
	if delay <= 0.001:
		callable.call()
	else:
		get_tree().create_timer(delay).timeout.connect(callable)


func _extend(seconds_from_now: float) -> void:
	_action_end = maxf(_action_end, _clock + seconds_from_now)


func _center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * CELL


## Head, every mirror on the way out, then the cell just past the edge.
func _lane_points(arrow: ArrowPath) -> PackedVector2Array:
	var pts := PackedVector2Array([_center(arrow.head())])
	for c in arrow.lane_cells():
		if mirrors.has(c):
			pts.append(_center(c))
	pts.append(_center(arrow.exit_cell))
	return pts


func _balloon_color(cell: Vector2i) -> Color:
	return BALLOON_COLORS[posmod(cell.x * 7 + cell.y * 13, BALLOON_COLORS.size())]


# --- Effects ------------------------------------------------------------------------------------------------

func _add_ring(cell: Vector2i, radius: float, color: Color, delay: float, dur: float) -> void:
	_fx.append({"kind": "ring", "pos": _center(cell), "radius": radius, "color": color, "start": _clock + delay, "dur": dur})


## A glowing beam that shoots out from `origin` (default: `from`) to both ends.
func _add_beam(from: Vector2, to: Vector2, color: Color, delay: float, origin := Vector2.INF, dur := 0.4) -> void:
	_fx.append({"kind": "beam", "from": from, "to": to, "origin": from if origin == Vector2.INF else origin,
		"color": color, "start": _clock + delay, "dur": dur})


## The arrow breaks into tumbling pieces that fly away from `origin` and fall.
func _shatter_fx(arrow: ArrowPath, delay: float, origin: Vector2) -> void:
	var color := arrow.base_color()
	var start := _clock + delay + 0.05  # right as the arrow's white flash ends
	for c in arrow.cells:
		for k in 2:
			var p := _center(c) + Vector2(randf_range(-0.25, 0.25), randf_range(-0.25, 0.25)) * CELL
			var away := p - origin
			away = away.normalized() if away.length() > 1.0 else Vector2.from_angle(randf() * TAU)
			var vel := away * randf_range(250.0, 650.0) + Vector2.from_angle(randf() * TAU) * 150.0
			vel.y -= randf_range(100.0, 300.0)
			_fx.append({"kind": "shard", "pos": p, "vel": vel, "rot": randf() * TAU, "spin": randf_range(-14.0, 14.0),
				"len": CELL * randf_range(0.18, 0.34), "color": color if k == 0 else color.lightened(0.35),
				"start": start, "dur": randf_range(0.55, 0.8)})
	_extend(delay + 0.4)


## The crush burst from the UI kit: a warm glow swells, shards in three shades of the
## arrow colour fly out in a ring, tumble and fall, and white sparkles twinkle round it.
func _crush_burst(pos: Vector2, color: Color, delay: float, size: float = 1.0) -> void:
	_later(delay, func() -> void:
		var glow := Sprite2D.new()
		glow.texture = FX_GLOW
		glow.position = pos
		glow.z_index = 15
		glow.scale = Vector2.ONE * CELL * 0.6 / 256.0
		add_child(glow)
		var g := glow.create_tween()
		g.tween_property(glow, "scale", Vector2.ONE * CELL * 3.4 * size / 256.0, 0.32).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		g.parallel().tween_property(glow, "modulate:a", 0.0, 0.4).set_delay(0.12)
		g.tween_callback(glow.queue_free)
		var shades := [color, color.lightened(0.35), color.darkened(0.3)]
		var n := int(16 * size)
		for k in n:
			var sh := Sprite2D.new()
			sh.texture = FX_SHARDS[k % 3]
			sh.modulate = shades[k % 3]
			sh.position = pos
			sh.rotation = randf() * TAU
			sh.z_index = 16
			sh.scale = Vector2.ONE * CELL * randf_range(0.36, 0.56) * size / 100.0
			add_child(sh)
			var ang := float(k) / n * TAU + randf_range(-0.2, 0.2)
			var out := pos + Vector2.from_angle(ang) * CELL * randf_range(1.0, 1.9) * size
			var t := sh.create_tween()
			t.tween_property(sh, "position", out, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(sh, "rotation", sh.rotation + randf_range(-5.0, 5.0), 0.75)
			t.tween_property(sh, "position:y", out.y + CELL * 0.7, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(sh, "modulate:a", 0.0, 0.42)
			t.tween_callback(sh.queue_free)
		for k in 6:
			var sp := Sprite2D.new()
			sp.texture = FX_SPARKLE
			sp.z_index = 17
			sp.position = pos + Vector2.from_angle(k * TAU / 6.0 + 0.4) * CELL * randf_range(0.45, 0.9) * size
			sp.scale = Vector2.ZERO
			add_child(sp)
			var full := Vector2.ONE * CELL * randf_range(0.42, 0.6) * size / 96.0
			var t := sp.create_tween()
			t.tween_interval(randf_range(0.0, 0.12))
			t.tween_property(sp, "scale", full, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(sp, "scale", Vector2.ZERO, 0.25).set_delay(0.08)
			t.tween_callback(sp.queue_free))


## The combo word from the UI kit (CRUSH! / SWEET! / ... / ARROW STORM!) pops in over the
## action at a steady on-screen size, wobbles straight, then floats up and fades.
func _combo_pop(chain: int) -> void:
	var tex: Texture2D = COMBO_TEX[clampi(chain - 2, 0, COMBO_TEX.size() - 1)]
	var screen_w := 340.0 if chain < 7 else 440.0
	var target := Vector2.ONE * (screen_w / tex.get_width()) / maxf(scale.x, 0.01)
	var half_w := tex.get_width() * target.x * 0.5
	var p := _center(_focus) + Vector2(0, -CELL * 0.4)
	var board_w := cols * CELL
	p.x = board_w * 0.5 if half_w * 2.0 >= board_w else clampf(p.x, half_w, board_w - half_w)
	var s := Sprite2D.new()
	s.texture = tex
	s.position = p
	s.z_index = 40
	s.scale = target * 0.2
	s.rotation = -0.14
	add_child(s)
	var t := s.create_tween()
	t.tween_property(s, "scale", target * 1.15, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(s, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "scale", target, 0.12)
	t.tween_interval(0.4)
	t.tween_property(s, "position:y", p.y - CELL * 0.7, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(s, "modulate:a", 0.0, 0.35)
	t.tween_callback(s.queue_free)


## White-hot impact: a bright core and sparks shooting out in a star.
func _impact(pos: Vector2, delay: float, size: float, color: Color) -> void:
	_fx.append({"kind": "impact", "pos": pos, "size": size, "color": color, "rot": randf() * TAU,
		"start": _clock + delay, "dur": 0.24})


## The whole board flashes for a split second (big blasts only).
func _board_flash(color: Color, strength: float, delay: float) -> void:
	_fx.append({"kind": "flash", "color": color, "amp": strength, "start": _clock + delay, "dur": 0.28})


## Jagged rainbow lightning from `from` to `to`.
func _add_bolt(from: Vector2, to: Vector2, delay: float) -> void:
	var forks: Array = []
	for k in 2:
		forks.append([randf_range(0.3, 0.75), randf_range(0.45, 0.8) * (1 if k == 0 else -1), randf_range(0.18, 0.32)])
	_fx.append({"kind": "bolt", "from": from, "to": to, "seed": randi(), "forks": forks, "hue": randf(),
		"start": _clock + maxf(delay, 0.0), "dur": 0.34})


## A jagged lightning line from `from` to `to`, calm at both ends and wildest in the
## middle. The same `seed` gives the same shape; a new one makes it crackle.
func _bolt_points(from: Vector2, to: Vector2, bolt_seed: int, steps: int, amp: float) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = bolt_seed
	var side := (to - from).orthogonal().normalized()
	var pts := PackedVector2Array([from])
	for i in range(1, steps):
		var t := float(i) / steps
		pts.append(from.lerp(to, t) + side * rng.randf_range(-amp, amp) * CELL * sin(PI * t) * 1.3)
	pts.append(to)
	return pts


## Stars scattering off a lightning strike, in the struck colour.
func _star_burst(pos: Vector2, color: Color, delay: float, n := 6) -> void:
	for k in n:
		var dir := Vector2.from_angle(k * TAU / n + randf_range(-0.35, 0.35))
		var tint := color.lightened(0.35) if k % 2 == 0 else Color(1.0, 1.0, 0.85)
		_sprite_fx(FX_SPARKLE, pos, delay, CELL * 0.35, CELL * randf_range(0.45, 0.65), randf_range(0.4, 0.55),
			randf_range(-3.0, 3.0), tint, 21, dir * CELL * randf_range(0.7, 1.1), 0.45)
	_sprite_fx(ArrowPath.FX_FLARE, pos, delay, CELL * 0.5, CELL * 1.3, 0.2, 0.6, Color(1, 1, 1, 0.9), 20)


## A spinning rainbow ring that sweeps across the board.
func _add_rainbow_ring(pos: Vector2, radius: float, delay: float, dur: float) -> void:
	_fx.append({"kind": "rainbow", "pos": pos, "radius": radius, "start": _clock + delay, "dur": dur})


## Sparks spraying off a laser beam along its whole length.
func _beam_sparks(from: Vector2, to: Vector2, color: Color, delay: float) -> void:
	_later(delay, func() -> void:
		var p := CPUParticles2D.new()
		add_child(p)
		p.position = (from + to) / 2.0
		p.rotation = (to - from).angle()
		p.one_shot = true
		p.explosiveness = 0.9
		p.amount = clampi(int(from.distance_to(to) / CELL) * 3, 12, 80)
		p.lifetime = 0.5
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(from.distance_to(to) / 2.0, CELL * 0.08)
		p.direction = Vector2.UP
		p.spread = 180.0
		p.gravity = Vector2.ZERO
		p.initial_velocity_min = 120.0
		p.initial_velocity_max = 380.0
		p.damping_min = 300.0
		p.damping_max = 600.0
		p.scale_amount_min = 5.0
		p.scale_amount_max = 10.0
		p.color_ramp = _fade_ramp(color.lightened(0.5))
		p.finished.connect(p.queue_free)
		p.emitting = true)


func _fade_ramp(color: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color, 0.0))
	return g


## A puff of coloured particles.
func _burst(pos: Vector2, color: Color, delay: float, amount: int) -> void:
	_later(delay, func() -> void:
		var p := CPUParticles2D.new()
		add_child(p)
		p.position = pos
		p.one_shot = true
		p.explosiveness = 1.0
		p.amount = amount
		p.lifetime = 0.55
		p.spread = 180.0
		p.gravity = Vector2.ZERO
		p.initial_velocity_min = 220.0
		p.initial_velocity_max = 620.0
		p.damping_min = 500.0
		p.damping_max = 900.0
		p.scale_amount_min = 7.0
		p.scale_amount_max = 15.0
		p.angle_min = 0.0
		p.angle_max = 360.0
		p.angular_velocity_min = -540.0
		p.angular_velocity_max = 540.0
		p.color_ramp = _fade_ramp(color)
		p.finished.connect(p.queue_free)
		p.emitting = true)


## The dots under an escaping arrow light up in a wave that follows it out:
## body dots as the tail leaves them, lane dots as the head passes, and the dots
## beside the lane a little too. Colours run along `palette`, tail to edge.
func _ripple_escape(arrow: ArrowPath, palette: Gradient, delay: float = 0.0) -> void:
	var n := arrow.cells.size()
	var lane := arrow.lane_cells()
	var total := float(maxi(1, n + lane.size() - 1))
	for i in n:
		# cells[0] is the tail; the tail leaves cell i after sliding i cells.
		_ripple(arrow.cells[i], delay + arrow.time_to_slide((i + 0.5) * CELL), palette.sample(i / total), 1.0, arrow.dir)
	var dirs := arrow.lane_dirs()
	for s in lane.size():
		var c := lane[s]
		var side := Vector2i(dirs[s].y, dirs[s].x)
		var t := delay + arrow.time_to_slide((s + 1) * CELL)
		var color := palette.sample((n + s) / total)
		_ripple(c, t, color, 0.8, dirs[s])
		_ripple(c + side, t + 0.04, color, 0.35, arrow.dir)
		_ripple(c - side, t + 0.04, color, 0.35, arrow.dir)


func _ripple(cell: Vector2i, delay: float, color: Color, amp: float, pull := Vector2i.ZERO) -> void:
	if not mask.has(cell):
		return
	_ripples[cell] = {"start": _clock + delay, "color": color, "amp": amp, "pull": Vector2(pull)}


func _set_lane_alpha(a: float) -> void:
	_lane_alpha = a
	queue_redraw()


func _draw() -> void:
	# One small, quiet dot per cell of the shape:
	#  - a faint tint along the level palette, gently "breathing",
	#  - popping in from the centre when the level starts,
	#  - and a comet tail when an arrow rushes past: the dot flashes to the full
	#    palette colour, gets tugged along the arrow's direction, springs back
	#    and slowly fades to quiet again.
	var center_cell := Vector2(cols, rows) / 2.0
	_ensure_dots(center_cell)
	var intro_done := _clock - _intro_start > 1.1
	var has_ripples := not _ripples.is_empty()
	for i in _dot_cells.size():
		var pos := _dot_pos[i]
		var wave := sin(_clock * 2.0 - _dot_phase[i])
		var base := DOT_COLOR.lerp(_dot_tint[i], 0.1 + 0.05 * (wave + 1.0) / 2.0)
		var intro := 1.0
		if not intro_done:
			intro = _ease_out_back(clampf((_clock - _intro_start - _dot_delay[i]) / 0.35, 0.0, 1.0))
		var radius := DOT_RADIUS * (1.0 + 0.08 * wave) * intro
		if radius <= 0.0:
			continue

		var p := 0.0
		var fx: Dictionary = {}
		if has_ripples:
			fx = _ripples.get(_dot_cells[i], {})
			if not fx.is_empty():
				p = clampf((_clock - fx.start) / RIPPLE_TIME, 0.0, 1.0)
		if p <= 0.0 or p >= 1.0:
			if _paint.has(_dot_cells[i]) and _clock >= float(_revealed.get(_dot_cells[i], 0.0)):
				continue  # a colour block sits here now
			# One textured quad per dot (batched) instead of a tessellated circle.
			draw_texture_rect(_dot_tex, Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, base)
			continue

		var amp: float = fx.amp
		var color: Color = fx.color
		var pull: Vector2 = fx.pull
		# Sharp flash in, long fade out.
		var env := p / 0.08 if p < 0.08 else pow(1.0 - (p - 0.08) / 0.92, 2.0)
		env *= minf(amp, 1.0)
		# Tugged along with the arrow, then a damped spring back.
		var tug := sin(minf(p * 3.0, 1.0) * TAU) * (1.0 - p) * CELL * 0.12 * amp
		var core_pos := pos + pull * tug
		draw_circle(core_pos, radius * (1.0 + 1.8 * env), Color(color, 0.12 * env), true, -1.0, true)  # soft glow
		if p < 0.45:
			var ring_p := p / 0.45
			draw_arc(pos, radius + ring_p * CELL * 0.25, 0.0, TAU, 28, Color(color, (1.0 - ring_p) * 0.3 * env), CELL * 0.02, true)
		draw_circle(core_pos, radius * (1.0 + 0.6 * env), base.lerp(color, env), true, -1.0, true)

	_draw_pieces(center_cell)
	var hint_fade := _hint_fade()
	if hint_fade > 0.0:
		# Gold glow under the whole hint arrow (the arrow itself draws on top of it).
		var pulse := (sin((_clock - _hint_start) * 6.0) + 1.0) / 2.0
		var glow := Color(HINT_COLOR, (0.3 + 0.2 * pulse) * hint_fade)
		var width := CELL * (0.62 + 0.12 * pulse)
		var body := PackedVector2Array()
		for c in _hint.cells:
			body.append(_center(c))
			draw_circle(_center(c), width / 2.0, glow, true, -1.0, true)
		if body.size() >= 2:
			draw_polyline(body, glow, width, true)
		# Its free lane, thick and breathing, so the way out is easy to see.
		for i in _lane_pts.size() - 1:
			draw_dashed_line(_lane_pts[i], _lane_pts[i + 1], Color(HINT_COLOR.darkened(0.25), (0.55 + 0.4 * pulse) * hint_fade),
				CELL * 0.12, CELL * 0.22, true, true)
	if _lane_alpha > 0.0:
		for i in _lane_pts.size() - 1:
			draw_dashed_line(_lane_pts[i], _lane_pts[i + 1], Color(LANE_COLOR, _lane_alpha * 0.8), CELL * 0.07, CELL * 0.18, true, true)


# --- The painting ----------------------------------------------------------------------------
# Every arrow that leaves paints the board under it: a soft watercolour wash on its cells
# and a brush stroke along its body, in its own colour. Where colours meet they bleed into
# each other, and a crush splashes the two arrows' colours together. While playing the
# paint is pale; when the level is won the gaps fill in, the colours deepen and a shine
# sweeps across - a picture made by how this player cleared this board.

## Every cell the arrow covered becomes a colour block. Blocks take the level's colour
## theme (a smooth gradient across the board), not the arrow's colour, so the finished
## picture is always a clean blend however the colours were mixed on the board.
func _leave_paint(arrow: ArrowPath, delay: float) -> void:
	for c in arrow.cells:
		_paint[c] = _block_color(c)
	# Blocks pop in up to BLOCK_POP s after their reveal time (the head's comes last).
	_touch_paint(delay + 0.4 + arrow.cells.size() * 0.035 + BLOCK_POP + 0.1)


## The painting changed: bump the cache key and keep redrawing it for `secs` more.
func _touch_paint(secs: float) -> void:
	_paint_version += 1
	_paint_until = maxf(_paint_until, _clock + secs)
	if _paint_layer:
		_paint_layer.queue_redraw()


## Crush: the two colours splash together around the hit (same colours flash brighter),
## and both brush strokes take on some of the mix.
func _splash(hit_cell: Vector2i, a: ArrowPath, b: ArrowPath, t: float) -> void:
	var ca := a.base_color()
	var cb := b.base_color()
	var mix := ca.lerp(cb, 0.5)
	if ca.is_equal_approx(cb):
		mix = ca.lightened(0.22)
	# The blocks keep their clean colours; only a short flash of the mix blooms over them.
	_splashes.append({"cell": hit_cell, "color": mix, "at": _clock + t})
	_touch_paint(t + 0.5)


func _soft() -> Texture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.5, Color(1, 1, 1, 0.6))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 96
		tex.height = 96
		_soft_tex = tex
	return _soft_tex


func _draw_picture() -> void:
	if not _paint.is_empty() and _paint_layer:
		draw_painting(_paint_layer, Vector2.ZERO, 1.0, _picture, true)


## Draws the painting onto `ci`, board coordinates scaled by `k` and moved by `off`.
## `glow` 0 = pale (while playing) .. 1 = finished. `live` fades each piece in as it
## appears and runs the finishing shine; the win card draws it still.
func draw_painting(ci: CanvasItem, off: Vector2, k: float, glow: float, live: bool) -> void:
	var soft := _soft()
	# 1) Colour dots (Affinity ball, tinted): one glossy dot per cleared cell in the level's
	#    colour theme. Lighter while playing so the arrows stay the stars; full colour on
	#    the finished picture. Each dot pops in when revealed.
	var pale := lerpf(0.35, 0.0, glow)
	var alpha := lerpf(0.9, 1.0, glow)
	var full := Vector2.ONE * CELL * k * BLOCK_SIZE
	for c: Vector2i in _paint:
		var s := 1.0
		var a := 1.0
		if live:
			# An arrow crept onto this block: hide it, and pop it back once the arrow is gone.
			if occupancy.has(c):
				_block_hidden[c] = true
				continue
			if _block_hidden.has(c):
				_block_hidden.erase(c)
				_revealed[c] = _clock
				_touch_paint(BLOCK_POP + 0.1)
			var age := _clock - float(_revealed.get(c, _clock))
			if age < 0.0:
				continue
			var p := clampf(age / BLOCK_POP, 0.0, 1.0)
			s = lerpf(0.35, 1.0, _ease_out_back(p))
			a = clampf(p * 3.0, 0.0, 1.0)
		var col: Color = _paint[c]
		var tint := Color(col.r, col.g, col.b).lerp(Color.WHITE, pale)
		tint.a = alpha * a
		var size := full * s
		var rect := Rect2(off + _center(c) * k - size / 2.0, size)
		ci.draw_texture_rect(BLOCK_BASE, rect, false, tint)
		ci.draw_texture_rect(BLOCK_GLOSS, rect, false, Color(1, 1, 1, lerpf(0.75, 1.0, glow) * a))
	# 2) Crush splashes: a quick bloom of the mixed colour that fades away again.
	for sp: Dictionary in _splashes:
		if not live:
			break
		var age: float = _clock - sp.at
		if age < 0.0 or age > 0.9:
			continue
		var a := clampf(age / 0.15, 0.0, 1.0) * (1.0 - clampf((age - 0.3) / 0.6, 0.0, 1.0))
		var bloom := (sp.color as Color).lerp(Color.WHITE, 0.3)
		bloom.a = a * 0.45
		var r := CELL * k * (1.0 + 0.6 * clampf(age / 0.9, 0.0, 1.0))
		ci.draw_texture_rect(soft, Rect2(off + _center(sp.cell) * k - Vector2(r, r), Vector2(r, r) * 2.0), false, bloom)
	# 4) Finished: a soft shine sweeps across the painting now and then.
	if live and glow > 0.0:
		# The first sweep starts as the painting completes, while it is held in view.
		var band := fposmod((_clock - _picture_done_at + 0.25) * 0.8, 2.4) - 0.3
		for c: Vector2i in _paint:
			var g := (float(c.x) / maxi(1, cols) + float(c.y) / maxi(1, rows)) / 2.0
			var near := 1.0 - clampf(absf(g - band) / 0.08, 0.0, 1.0)
			if near > 0.0:
				var r := CELL * k * 0.75
				ci.draw_texture_rect(soft, Rect2(off + _center(c) * k - Vector2(r, r), Vector2(r, r) * 2.0), false,
					Color(1, 1, 1, 0.5 * near * glow))


## Colour of cell `c` in the finished picture (the win card's photo uses it too).
func picture_color(c: Vector2i) -> Color:
	if _paint.has(c):
		return _paint[c]
	return _block_color(c)


## The level theme's colour at cell `c`: top-left to bottom-right across the board.
func _block_color(c: Vector2i) -> Color:
	var g := (float(c.x) / maxi(1, cols - 1) + float(c.y) / maxi(1, rows - 1)) / 2.0
	return _palette.sample(g) if _palette else Color("#a78bfa")


## Level complete: the cells no arrow ever covered get their blocks too, the whole
## picture fills in from the middle, then the colours deepen and the shine starts.
func celebrate_picture() -> void:
	# Every cell of the shape gets its block in the level's colour theme.
	for c: Vector2i in mask:
		if not _paint.has(c):
			_paint[c] = _block_color(c)
	var mid := Vector2(cols, rows) / 2.0
	var last := 0.0
	for c: Vector2i in mask:
		var at := _clock + (Vector2(c) - mid).length() * 0.035
		_revealed[c] = minf(float(_revealed.get(c, at)), at)
		last = maxf(last, float(_revealed[c]))
	create_tween().tween_property(self, "_picture", 1.0, 0.9).set_delay(0.25)
	_picture_done_at = maxf(last + 0.45, _clock + 1.15)
	_touch_paint(_picture_done_at - _clock + 0.1)


## Seconds until the finished painting is fully revealed and at full colour.
func picture_time_left() -> float:
	return maxf(0.0, _picture_done_at - _clock)


## UI kit v2: the shape sits on a soft lilac tray with a darker lip below, so the play
## area reads as one object, separate from the HUD.
func _draw_tray() -> void:
	var pad := CELL * 0.18
	var lip := Vector2(0, CELL * 0.09)
	# Every cell is a rounded tile; neighbours overlap by 2 * pad (more than the radius),
	# so inside the shape the tiles merge and only the outer corners stay round.
	if _tray_boxes.is_empty():
		for color in [TRAY_LIP, TRAY_COLOR]:
			var box := StyleBoxFlat.new()
			box.bg_color = color
			box.set_corner_radius_all(int(CELL * 0.3))
			box.anti_aliasing = true
			_tray_boxes.append(box)
	for pass_i in 2:
		var off := lip if pass_i == 0 else Vector2.ZERO
		for c: Vector2i in mask:
			var r := Rect2(_center(c) - Vector2(CELL, CELL) * 0.5 - Vector2(pad, pad) + off, Vector2(CELL + pad * 2.0, CELL + pad * 2.0))
			draw_style_box(_tray_boxes[pass_i], r)


## Caches each dot's position, palette tint, wave phase and intro delay (they only
## change with a new board or palette), and makes the shared round dot texture.
func _ensure_dots(center_cell: Vector2) -> void:
	if _dot_tex == null:
		var size := 64
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var r := size / 2.0
		for y in size:
			for x in size:
				var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
				img.set_pixel(x, y, Color(1, 1, 1, clampf(r - d, 0.0, 1.5) / 1.5))
		_dot_tex = ImageTexture.create_from_image(img)
	if not _dots_dirty:
		return
	_dots_dirty = false
	_dot_cells.clear()
	_dot_pos.clear()
	_dot_tint.clear()
	_dot_phase.clear()
	_dot_delay.clear()
	for c: Vector2i in mask:
		_dot_cells.append(c)
		_dot_pos.append(_center(c))
		_dot_tint.append(_palette.sample((float(c.x) / maxi(1, cols) + float(c.y) / maxi(1, rows)) / 2.0))
		_dot_phase.append((c.x + c.y) * 0.55)
		_dot_delay.append((Vector2(c) - center_cell).length() / maxf(cols, rows) * 0.7)


## 0..1(+overshoot) pop-in of a cell when the level starts, rippling out from the middle.
func _intro_at(c: Vector2i, center_cell: Vector2) -> float:
	return _ease_out_back(clampf((_clock - _intro_start - (Vector2(c) - center_cell).length() / maxf(cols, rows) * 0.7) / 0.35, 0.0, 1.0))


# --- Board pieces: mirrors, balloons, targets ----------------------------------------------------

## Drawn on the board itself, so they sit under the arrows.
func _draw_pieces(center_cell: Vector2) -> void:
	for c: Vector2i in mirrors:
		_draw_mirror(c, mirrors[c], _intro_at(c, center_cell))
	for c: Vector2i in _balloon_view:
		_draw_balloons(c, int(_balloon_view[c]), _intro_at(c, center_cell))
	for c: Vector2i in targets:
		_draw_target(c, _intro_at(c, center_cell))
	for c: Vector2i in _crate_view:
		_draw_crate(c, int(_crate_view[c]), _intro_at(c, center_cell))


## A wooden crate: planks, a darker frame; 2 layers add metal corners, 3 an iron band.
func _draw_crate(c: Vector2i, layers: int, k: float) -> void:
	if k <= 0.0 or layers <= 0:
		return
	# Affinity art: plain crate, + steel corners (2 layers), + an iron band (3 layers).
	# The crate body is 216 px of the 256 px texture.
	var side := CELL * 0.84 * k * 256.0 / 216.0
	draw_texture_rect(CRATE_TEX[clampi(layers, 1, 3) - 1], Rect2(_center(c) - Vector2(side, side) / 2.0, Vector2(side, side)), false)


## A glass mirror on a pale disc, with a glint sliding along it.
func _draw_mirror(c: Vector2i, kind: int, k: float) -> void:
	if k <= 0.0:
		return
	var pos := _center(c)
	var r := CELL * 0.32 * k
	var a := pos + (Vector2(-r, r) if kind == 0 else Vector2(-r, -r))
	var b := pos + (Vector2(r, -r) if kind == 0 else Vector2(r, r))
	draw_circle(pos, CELL * 0.48 * k, Color("#bae6fd"), true, -1.0, true)
	draw_arc(pos, CELL * 0.48 * k, 0.0, TAU, 32, Color("#0ea5e9"), CELL * 0.04, true)
	var drop := Vector2(0, CELL * 0.04)
	draw_line(a + drop, b + drop, Color(0.06, 0.09, 0.16, 0.2), CELL * 0.22, true)
	draw_line(a, b, Color("#334155"), CELL * 0.22, true)
	draw_line(a, b, Color("#67e8f9"), CELL * 0.13, true)
	var g := fposmod(_clock * 0.6 + c.x * 0.37 + c.y * 0.61, 1.6)
	if g < 1.0:
		var p := a.lerp(b, g)
		var along := (b - a).normalized() * CELL * 0.06
		draw_line(p - along, p + along, Color(1, 1, 1, 0.9), CELL * 0.05, true)
	draw_circle(a, CELL * 0.06 * k, Color("#475569"), true, -1.0, true)
	draw_circle(b, CELL * 0.06 * k, Color("#475569"), true, -1.0, true)


## One balloon per layer left: a cluster of 2 or 3 means 2 or 3 pops.
func _draw_balloons(c: Vector2i, layers: int, k: float) -> void:
	if k <= 0.0 or layers <= 0:
		return
	var pos := _center(c) + Vector2(0, sin(_clock * 2.2 + c.x * 1.3 + c.y * 0.7) * CELL * 0.03)
	var spots: Array = [[Vector2.ZERO, 1.0]]
	if layers == 2:
		spots = [[Vector2(-0.14, 0.04), 0.8], [Vector2(0.14, -0.03), 0.8]]
	elif layers >= 3:
		spots = [[Vector2(-0.17, 0.08), 0.7], [Vector2(0.17, 0.08), 0.7], [Vector2(0, -0.1), 0.7]]
	for i in spots.size():
		var tint := posmod(c.x * 7 + c.y * 13 + i * 2, BALLOON_COLORS.size())
		_draw_balloon(pos + spots[i][0] * CELL, CELL * 0.3 * spots[i][1] * k, tint)


func _draw_balloon(p: Vector2, r: float, tint: int) -> void:
	if r < 2.0:
		return  # too small to see (popping in)
	# Affinity art: body centre (128, 108), half width 80 px, knot ends at y 210.
	var sc := r / 80.0
	var knot := p + Vector2(0, 104.0 * sc)
	var string := PackedVector2Array()
	for i in 6:
		var t := i / 5.0
		string.append(knot + Vector2(sin(t * 5.0 + _clock * 3.0) * r * 0.12, t * r * 0.9))
	draw_polyline(string, Color("#94a3b8"), CELL * 0.015, true)
	draw_colored_polygon(_ellipse(p + Vector2(0, CELL * 0.04), r, r * 1.18), Color(0.06, 0.09, 0.16, 0.12))
	draw_texture_rect(BALLOON_TEX[tint], Rect2(p - Vector2(128.0, 108.0) * sc, Vector2(256.0, 256.0) * sc), false)


## A bullseye just outside the edge: red until hit, then green with a tick (and a wobble).
func _draw_target(c: Vector2i, k: float) -> void:
	if k <= 0.0:
		return
	var pos := _center(c)
	var hit_at: float = _target_hit_at.get(c, INF)
	var hit := _clock >= hit_at
	var wob := 1.0 + 0.05 * sin(_clock * 4.0 + c.x + c.y)
	if hit:
		var age := _clock - hit_at
		wob = 1.0 + 0.3 * sin(minf(age * 18.0, 3.0 * PI)) * exp(-age * 4.0)
	var r := CELL * 0.4 * k * wob
	# Affinity art: the bullseye is 109 px in radius in the 256 px texture.
	var side := r * 256.0 / 109.0
	draw_texture_rect(TARGET_HIT_TEX if hit else TARGET_TEX, Rect2(pos - Vector2(side, side) / 2.0, Vector2(side, side)), false)


func _ellipse(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := i * TAU / 24.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## Marks on special arrows: a chain between linked arrows, a gold star, a countdown
## bubble, a turn-around sign.
func _draw_special_marks(cv: Node2D) -> void:
	# Marks keep a readable size on screen even when a big board is scaled down.
	var px := 1.0 / maxf(scale.x, 0.01)
	var drawn_links := {}
	for a in arrows:
		if not is_instance_valid(a) or a.modulate.a < 0.5:
			continue
		var mid := _center(a.cells[a.cells.size() / 2]) + a.position
		if a.link_id >= 0 and not drawn_links.has(a.link_id):
			var b := _partner(a)
			if b:
				drawn_links[a.link_id] = true
				var to := _center(b.cells[b.cells.size() / 2]) + b.position
				var links := maxi(2, int(mid.distance_to(to) / (CELL * 0.28)))
				for k in links + 1:
					var p := mid.lerp(to, float(k) / links)
					var rw := maxf(CELL * 0.22, 14.0 * px)
					var ring := Rect2(p - Vector2(rw / 2.0, rw * 0.32), Vector2(rw, rw * 0.64))
					var box := StyleBoxFlat.new()
					box.draw_center = false
					box.border_color = Color("#64748b") if k % 2 == 0 else Color("#94a3b8")
					box.set_border_width_all(int(maxf(CELL * 0.035, 3.0 * px)))
					box.set_corner_radius_all(int(CELL * 0.07))
					box.anti_aliasing = true
					cv.draw_style_box(box, ring)
				for q in [mid, to]:
					cv.draw_circle(q, maxf(CELL * 0.13, 8.0 * px), Color("#475569"), true, -1.0, true)
					cv.draw_circle(q, maxf(CELL * 0.07, 4.0 * px), Color("#cbd5e1"), true, -1.0, true)
		if a.golden:
			var t := _clock * 3.0 + a.cells[0].x
			_draw_star(cv, mid, maxf(CELL * 0.26, 13.0 * px) * (1.0 + 0.1 * sin(t)), Color("#fde047"), Color("#a16207"))
		if a.timer > 0:
			var p := _center(a.cells[0]) + a.position
			var last := a.timer <= 2  # last chance: the coin badge wiggles
			var r := maxf(CELL * 0.3, 17.0 * px) * (1.0 + (0.12 * sin(_clock * 10.0) if last else 0.0))
			cv.draw_circle(p + Vector2(0, CELL * 0.03), r, Color(0, 0, 0, 0.25), true, -1.0, true)
			cv.draw_circle(p, r, Color("#f97316") if last else Color("#f59e0b"), true, -1.0, true)
			cv.draw_arc(p, r, 0.0, TAU, 24, Color.WHITE, r * 0.14, true)
			var font := ThemeDB.fallback_font
			var size := int(r * 1.15)
			var text := str(a.timer)
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			cv.draw_string(font, p + Vector2(-w / 2.0, size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)
		if a.flip:
			var p := _center(a.cells[0]) + a.position
			var u := maxf(CELL, 80.0 * px)  # badge unit
			cv.draw_circle(p, u * 0.24, Color.WHITE, true, -1.0, true)
			cv.draw_circle(p, u * 0.2, Color("#7c3aed"), true, -1.0, true)
			cv.draw_arc(p, u * 0.11, PI * 0.15, PI * 0.95, 10, Color.WHITE, u * 0.045, true)
			cv.draw_arc(p, u * 0.11, PI * 1.15, PI * 1.95, 10, Color.WHITE, u * 0.045, true)
			cv.draw_colored_polygon(PackedVector2Array([p + Vector2(-0.15, 0.0) * u, p + Vector2(-0.07, 0.0) * u,
				p + Vector2(-0.11, 0.07) * u]), Color.WHITE)
			cv.draw_colored_polygon(PackedVector2Array([p + Vector2(0.15, 0.0) * u, p + Vector2(0.07, 0.0) * u,
				p + Vector2(0.11, -0.07) * u]), Color.WHITE)


func _draw_star(cv: Node2D, p: Vector2, r: float, fill: Color, edge: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI / 2.0 + i * PI / 5.0
		pts.append(p + Vector2.from_angle(ang) * (r if i % 2 == 0 else r * 0.45))
	var outline := PackedVector2Array()
	for q in pts:
		outline.append(p + (q - p) * 1.2)
	cv.draw_colored_polygon(outline, edge)
	cv.draw_colored_polygon(pts, fill)


# --- Winning: free the rest, Final Volley ---------------------------------------------------------

## The goals are done with arrows still on the board: they all fly off (no rules any
## more). Returns how long that takes.
func release_all() -> float:
	_cleared_sent = true
	_aimers.clear()
	var list := arrows.duplicate()
	arrows.clear()
	occupancy.clear()
	var t := 0.0
	for i in list.size():
		var a: ArrowPath = list[i]
		t = minf(i * 0.05, 1.2)
		a.slide_out(false, t)
		_ripple_escape(a, _palette, t)
		if i % 3 == 0:
			_later(t, GameData.play_sfx.bind("slide", 1.0 + minf(i * 0.02, 0.8)))
	return t + 0.8 if not list.is_empty() else 0.0


## The goals are done with arrows still on the board: a school of flying fish swoops
## in, each one grabs an arrow and carries it off screen, so the player never has to
## clear the rest by hand. Falls back to release_all() if the fish art is missing.
## Returns how long until the last fish is gone.
const FISH_IN := 0.5         # seconds a fish takes to reach its arrow
const FISH_OUT := 0.75       # seconds to carry it off screen
const FISH_GAP := 0.07       # seconds between fish (squeezed so big boards stay quick)
const FISH_SPREAD := 1.4     # the last fish sets off no later than this
const FISH_BODY_PATH := "res://icons/fx/fish_body.png"
const FISH_FIN_PATH := "res://icons/fx/fish_fin.png"
const FISH_FIN_ROOT := Vector2(160, 244)     # wing root inside fish_fin.png (px)
const FISH_FIN_AT := Vector2(0.086, -0.082)  # where it joins the body, in fish widths from its centre

func fish_carry_all() -> float:
	if not ResourceLoader.exists(FISH_BODY_PATH) or not ResourceLoader.exists(FISH_FIN_PATH):
		return release_all()
	var body_tex: Texture2D = load(FISH_BODY_PATH)
	var fin_tex: Texture2D = load(FISH_FIN_PATH)
	_cleared_sent = true
	_aimers.clear()
	var list := arrows.duplicate()
	arrows.clear()
	occupancy.clear()
	if list.is_empty():
		return 0.0
	list.shuffle()
	# Screen rectangle in canvas coordinates (fish fly in and out past its edges).
	var view := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	var board_scale := get_global_transform().get_scale().x
	var gap := minf(FISH_GAP, FISH_SPREAD / float(list.size()))
	var t := 0.0
	for i in list.size():
		t = i * gap
		_fish_grab(list[i], t, body_tex, fin_tex, view, board_scale, i)
	return t + FISH_IN + FISH_OUT + 0.15


func _fish_grab(a: ArrowPath, delay: float, body_tex: Texture2D, fin_tex: Texture2D,
		view: Rect2, board_scale: float, i: int) -> void:
	a.busy = true
	# Held by its middle, so long arrows hang balanced instead of swinging off one end.
	var mid := Vector2.ZERO
	var lo := Vector2(INF, INF)
	var hi := -lo
	for c: Vector2i in a.cells:
		var cp := _center(c)
		mid += cp
		lo = lo.min(cp)
		hi = hi.max(cp)
	mid /= maxf(1.0, a.cells.size())
	var target := to_global(mid)
	var span := ((hi - lo).length() + CELL) * board_scale   # arrow's length on screen
	var from_left := (i % 2 == 0) if randf() < 0.7 else randf() < 0.5
	var margin := view.size.x * 0.12
	var start := Vector2(view.position.x - margin if from_left else view.end.x + margin,
		target.y + randf_range(-0.25, 0.15) * view.size.y)
	# Off the far side and upwards: the fish keeps its swoop going.
	var finish := Vector2(view.end.x + margin if from_left else view.position.x - margin,
		target.y - randf_range(0.25, 0.55) * view.size.y)
	# Each fish a touch different in size, so the school doesn't look stamped out.
	var size := clampf(CELL * 1.5 * board_scale, 96.0, 170.0) * randf_range(0.88, 1.08)  # fish width on screen
	var hang := size * 0.34              # how far below the fish the arrow hangs
	var grab := target - Vector2(0, hang)  # fish stops here, so the arrow is caught right where it lies
	_later(delay, func() -> void:
		if not is_instance_valid(a):
			return
		var fish := Node2D.new()
		fish.top_level = true
		fish.z_index = ArrowPath.FLY_Z + 2
		fish.position = start
		add_child(fish)
		var face := 1.0 if from_left else -1.0
		var px := size / body_tex.get_width()
		var fin := Sprite2D.new()
		fin.texture = fin_tex
		fin.centered = false
		fin.offset = -FISH_FIN_ROOT        # the wing beats around its root
		fin.position = FISH_FIN_AT * size
		fin.scale = Vector2.ONE * px
		var body := Sprite2D.new()
		body.texture = body_tex
		body.scale = Vector2.ONE * px
		var look := Node2D.new()   # mirrored for fish flying leftwards
		look.scale = Vector2(face, 1.0)
		fish.add_child(look)
		look.add_child(body)
		look.add_child(fin)      # the wing sits over the body
		var tint := a.base_color()
		# One unbroken swoop: dip in under the arrow, scoop it up without stopping, climb away.
		# Speed eases down to ~40% at the catch and picks back up, so it reads as a grab,
		# not a halt. `s` holds the state the per-frame step needs.
		var bend := (start + grab) * 0.5 + Vector2(0, view.size.y * 0.14)
		var lift := (grab + finish) * 0.5 - Vector2(0, view.size.y * 0.06)
		var dur := FISH_IN + FISH_OUT
		var s := {"t": 0.0, "phase": randf() * TAU, "caught": -1.0, "held": null, "trail": 0.0,
			"hv": Vector2.ZERO}
		var step := func(u: float) -> void:
			var now := u * dur
			var dt := maxf(now - float(s.t), 0.0)
			s.t = now
			var f := u + 0.6 * sin(TAU * u) / TAU      # slow in the middle, quick at both ends
			var p: Vector2
			if f < 0.5:
				var k := f * 2.0
				p = start.lerp(bend, k).lerp(bend.lerp(grab, k), k)
			else:
				var k := (f - 0.5) * 2.0
				p = grab.lerp(lift, k).lerp(lift.lerp(finish, k), k)
			# Tilt along the flight, eased so the fish banks rather than snaps.
			var v := p - fish.position
			if v.length() > 0.5:
				var want := clampf(atan2(v.y, absf(v.x)), -0.6, 0.6) * face
				fish.rotation = lerp_angle(fish.rotation, want, 0.3)
			fish.position = p
			# Wings: a calm glide coming in, hard beats while carrying the load.
			var carrying := float(s.caught) >= 0.0
			s.phase = float(s.phase) + dt * TAU * (12.0 if carrying else 7.5)
			var beat := 0.5 + 0.5 * cos(float(s.phase))
			fin.scale = Vector2(px, px * lerpf(-0.45, 1.0, beat))
			fin.rotation = (beat - 0.5) * 0.25
			# Swimming wiggle: a soft bob and stretch in time with the wings.
			var swim := sin(float(s.phase) * 0.5)
			look.position.y = swim * size * 0.025
			var sq := Vector2.ONE
			if carrying:   # springy squash right after the catch
				var since := now - float(s.caught)
				var j := exp(-since * 9.0) * cos(since * 28.0)
				sq = Vector2(1.0 + 0.16 * j, 1.0 - 0.13 * j)
			body.scale = Vector2(px, px) * sq * Vector2(1.0 + 0.03 * swim, 1.0 - 0.03 * swim)
			# Nearer the camera as it leaves: a slight grow on the way out.
			fish.scale = Vector2.ONE * (1.0 + 0.14 * clampf((f - 0.5) * 2.0, 0.0, 1.0))
			if not carrying and f >= 0.5:
				s.caught = now
				s.held = _fish_catch(a, target, clampf(size * 1.25 / span, 0.22, 0.52), tint)
			var held: Node2D = s.held
			if is_instance_valid(held):
				# The arrow swings under the fish like a weight on a string: it trails the
				# anchor point with a spring, and leans the way it is being dragged.
				var anchor := p + Vector2(0, hang).rotated(fish.rotation * 0.5) * fish.scale.y
				var hv: Vector2 = s.hv
				hv = hv.lerp((anchor - held.position) * 22.0, minf(1.0, dt * 14.0))
				s.hv = hv
				held.position += hv * dt
				var pull := held.position - p
				held.rotation = lerp_angle(held.rotation,
					clampf(-atan2(pull.x, pull.y), -0.7, 0.7), minf(1.0, dt * 10.0))
				# A little glittering wake behind the fish while it carries.
				s.trail = float(s.trail) - dt
				if float(s.trail) <= 0.0:
					s.trail = 0.06
					var tail := p + Vector2(-size * 0.42 * face, 0).rotated(fish.rotation)
					var lp := to_local(tail)
					var sc := 1.0 / maxf(board_scale, 0.01)
					_sprite_fx(FX_SPARKLE, lp, 0.0, size * 0.10 * sc, size * randf_range(0.16, 0.24) * sc,
						randf_range(0.35, 0.5), randf_range(-2.5, 2.5),
						tint.lightened(0.45) if randf() < 0.6 else Color(1, 1, 0.88),
						ArrowPath.FLY_Z + 1, Vector2(0, size * 0.25 * sc), 0.2)
		var tw := fish.create_tween()
		tw.tween_method(step, 0.0, 1.0, dur)
		tw.tween_callback(func() -> void:
			if is_instance_valid(s.held):
				(s.held as Node2D).queue_free()
			fish.queue_free())
		)


## The moment a fish grabs its arrow: the cells it leaves ripple, a glint and a few
## stars pop where it was, and the arrow lifts off on a holder that follows the fish.
func _fish_catch(a: ArrowPath, target: Vector2, carry_scale: float, tint: Color) -> Node2D:
	if not is_instance_valid(a):
		return null
	var held := Node2D.new()
	held.top_level = true
	held.z_index = ArrowPath.FLY_Z + 1
	held.position = target
	add_child(held)
	a.reparent(held, true)
	a.z_index = 0
	var n := a.cells.size()
	for c in n:
		_ripple(a.cells[c], c * 0.02, _palette.sample(float(c) / maxf(1.0, n - 1.0)), 1.0, a.dir)
	GameData.play_sfx("slide", randf_range(1.15, 1.5))
	var local := to_local(target)
	_sprite_fx(ArrowPath.FX_FLARE, local, 0.0, CELL * 0.4, CELL * 1.5, 0.22, 0.5, Color(1, 1, 1, 0.85),
		ArrowPath.FLY_Z)
	for k in 4:
		var dir := Vector2.from_angle(k * TAU / 4.0 + randf_range(-0.5, 0.5) + PI * 0.25)
		_sprite_fx(FX_SPARKLE, local, 0.0, CELL * 0.25, CELL * randf_range(0.4, 0.55), randf_range(0.35, 0.45),
			randf_range(-3.0, 3.0), tint.lightened(0.4) if k % 2 == 0 else Color(1, 1, 0.85),
			ArrowPath.FLY_Z, dir * CELL * randf_range(0.6, 0.9), 0.4)
	# Pops a touch bigger, then tucks in small enough for a fish to carry.
	var pop := held.create_tween()
	pop.tween_property(held, "scale", Vector2.ONE * 1.08, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pop.tween_property(held, "scale", Vector2.ONE * carry_scale, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	return held


## Final Volley: `n` rockets shoot up from the bottom of the board, alternating sides,
## and burst into bright sparks that spread and fall. Returns how long until the last
## burst has bloomed (its sparks keep falling behind the result popup).
const VOLLEY_GAP := 0.13      # seconds between launches
const ROCKET_FLIGHT := 0.42
const VOLLEY_COLORS: Array[Color] = [Color("#ff4d6d"), Color("#ffd60a"), Color("#4cc9f0"), Color("#7bf1a8"),
	Color("#c77dff"), Color("#ff9f1c")]
var _spark_tex: Texture2D

func volley(n: int) -> float:
	var t := 0.0
	for i in n:
		t = i * VOLLEY_GAP
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := cols * (0.5 + side * randf_range(0.08, 0.36))
		var from := Vector2(x, rows + 0.6) * CELL
		var to := Vector2(x + side * randf_range(-0.6, 0.6), rows * randf_range(0.12, 0.45)) * CELL
		var color: Color = VOLLEY_COLORS[i % VOLLEY_COLORS.size()]
		_rocket(from, to, color, t)
		_later(t, GameData.play_sfx.bind("whoosh", randf_range(1.5, 1.9)))
		var boom := t + ROCKET_FLIGHT
		_fx.append({"kind": "glow", "pos": to, "radius": CELL * 2.6, "color": color, "start": _clock + boom, "dur": 0.45})
		_firework_bloom(to, color, boom)
		_firework(to, color, boom)
		var pitch := randf_range(0.94, 1.12)  # a little different every shot (recorded takes)
		_later(boom, func() -> void:
			GameData.play_sfx("firework", pitch)
			GameData.vibrate(20))
	return t + ROCKET_FLIGHT + 0.45 if n > 0 else 0.0


## A rocket from the Affinity set: a glowing comet that streaks up to `to`.
func _rocket(from: Vector2, to: Vector2, color: Color, delay: float) -> void:
	_later(delay, func() -> void:
		var r := Sprite2D.new()
		r.texture = FW_ROCKET
		r.offset = Vector2(0, 98)          # the comet head sits on the node position
		r.modulate = color.lightened(0.55)
		r.position = from
		r.rotation = (to - from).angle() + PI / 2.0
		r.z_index = 12
		r.scale = Vector2.ONE * CELL * 1.7 / 256.0
		add_child(r)
		var t := r.create_tween()
		t.tween_property(r, "position", to, ROCKET_FLIGHT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(r, "scale", Vector2.ONE * CELL * 1.1 / 256.0, ROCKET_FLIGHT)
		t.tween_property(r, "modulate:a", 0.0, 0.06)
		t.tween_callback(r.queue_free))


## The firework flower from the Affinity set: a white flash, then two layers of tapered
## rays with pearls (the rocket colour and a lighter tint) bloom out, turn and droop.
func _firework_bloom(pos: Vector2, color: Color, delay: float) -> void:
	_later(delay, func() -> void:
		var core := Sprite2D.new()
		core.texture = FW_CORE
		core.position = pos
		core.z_index = 13
		core.scale = Vector2.ONE * 0.2
		add_child(core)
		var c := core.create_tween()
		c.tween_property(core, "scale", Vector2.ONE * CELL * 2.4 / 256.0, 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		c.tween_property(core, "modulate:a", 0.0, 0.3)
		c.tween_callback(core.queue_free)
		var spin := randf() * TAU
		for layer in 2:
			var s := Sprite2D.new()
			s.texture = FW_RAYS
			s.position = pos
			s.z_index = 12
			s.modulate = color if layer == 0 else color.lightened(0.6)
			s.rotation = spin + (PI / 16.0 if layer == 1 else 0.0)
			var full := CELL * (4.8 if layer == 0 else 2.9) / 512.0
			s.scale = Vector2.ONE * full * 0.12
			add_child(s)
			var t := s.create_tween()
			t.tween_property(s, "scale", Vector2.ONE * full, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(s, "rotation", s.rotation + (0.35 if layer == 0 else -0.45), 1.1)
			t.parallel().tween_property(s, "position:y", pos.y + CELL * 0.6, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(s, "modulate:a", 0.0, 0.55).set_delay(0.5)
			t.tween_callback(s.queue_free))


## One firework burst: round glowing sparks that fly out, slow down and fall, then a
## short white glitter a moment later.
func _firework(pos: Vector2, color: Color, delay: float) -> void:
	if _spark_tex == null:
		var g := GradientTexture2D.new()
		g.width = 32
		g.height = 32
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		g.gradient = Gradient.new()
		g.gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
		g.gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		_spark_tex = g
	for glitter in [false, true]:
		_later(delay + (0.14 if glitter else 0.0), func() -> void:
			var p := CPUParticles2D.new()
			add_child(p)
			p.z_index = 11
			p.position = pos
			p.texture = FW_STAR if glitter else _spark_tex
			p.one_shot = true
			p.explosiveness = 1.0 if not glitter else 0.7
			p.amount = 64 if not glitter else 26
			p.lifetime = 1.15 if not glitter else 0.9
			p.spread = 180.0
			p.gravity = Vector2(0, 520)
			p.initial_velocity_min = 380.0 if not glitter else 120.0
			p.initial_velocity_max = 760.0 if not glitter else 420.0
			p.damping_min = 420.0
			p.damping_max = 700.0
			p.scale_amount_min = 0.55 if not glitter else 0.35
			p.scale_amount_max = 0.95 if not glitter else 0.55
			var ramp := Gradient.new()
			if glitter:
				ramp.colors = PackedColorArray([Color.WHITE, Color(1, 1, 0.85, 0.9), Color(1, 1, 1, 0)])
			else:
				ramp.colors = PackedColorArray([Color.WHITE, color.lightened(0.15), Color(color, 0)])
			ramp.offsets = PackedFloat32Array([0.0, 0.18, 1.0])
			p.color_ramp = ramp
			p.finished.connect(p.queue_free)
			p.emitting = true)


func _ease_out_back(x: float) -> float:
	var k := 1.70158
	return 1.0 + (k + 1.0) * pow(x - 1.0, 3.0) + k * pow(x - 1.0, 2.0)


## Blast effects are drawn on a layer above the arrows (see build()).
func _draw_fx() -> void:
	var cv := _fx_layer
	_draw_special_marks(cv)
	# Hint: rings ripple out of the hinted arrow's head, on top of everything ("tap me").
	var hint_fade := _hint_fade()
	if hint_fade > 0.0:
		var head := _center(_hint.head())
		var t := _clock - _hint_start
		for k in 2:
			var rp := fmod(t * 0.9 + k * 0.5, 1.0)
			cv.draw_arc(head, CELL * (0.35 + 0.85 * rp), 0.0, TAU, 40,
				Color(HINT_COLOR, (1.0 - rp) * 0.9 * hint_fade), CELL * 0.09, true)
		cv.draw_arc(head, CELL * 0.42, 0.0, TAU, 40, Color(Color.WHITE, 0.85 * hint_fade), CELL * 0.05, true)
	# Ice over frozen arrows: a pale block on every cell, frosty edges, cracks on the last layer.
	for a in arrows:
		if a.ice <= 0 or not is_instance_valid(a):
			continue
		for c in a.cells:
			var p := _center(c)
			# Affinity ice block (cracked on the last layer); see-through so the arrow shows.
			var r := Rect2(p - Vector2.ONE * CELL * 0.5, Vector2.ONE * CELL)
			cv.draw_texture_rect(ICE_TEX[1 if a.ice >= 2 else 0], r, false, Color(1, 1, 1, 0.85))
	# Bullseye badge on the tail of every arrow that will hit a target.
	for a in _aimers:
		if is_instance_valid(a) and not a.busy:
			var p := _center(a.cells[0])
			cv.draw_circle(p, CELL * 0.32, Color.WHITE, true, -1.0, true)
			cv.draw_circle(p, CELL * 0.27, Color("#ef4444"), true, -1.0, true)
			cv.draw_circle(p, CELL * 0.17, Color.WHITE, true, -1.0, true)
			cv.draw_circle(p, CELL * 0.08, Color("#ef4444"), true, -1.0, true)
	# Blast effects: rings, beams, flying pieces, impacts, lightning, flashes.
	for fx in _fx:
		var age: float = _clock - fx.start
		var p: float = age / fx.dur
		if p < 0.0 or p > 1.0:
			continue
		var fade := 1.0 - p
		match fx.kind:
			"ring":
				var color: Color = fx.color
				var r: float = fx.radius * (1.0 - pow(1.0 - p, 3.0))
				cv.draw_circle(fx.pos, r, Color(color, 0.12 * fade), true, -1.0, true)
				cv.draw_arc(fx.pos, r, 0.0, TAU, 48, Color(color, 0.8 * fade), CELL * (0.02 + 0.1 * fade), true)
			"rocket":
				# A glowing head rising (slowing near the top) with a tapering spark trail.
				var color: Color = fx.color
				for k in 12:
					var q := p - k * 0.03
					if q < 0.0:
						break
					var e := 1.0 - pow(1.0 - q, 2.0)
					var at: Vector2 = fx.from.lerp(fx.to, e) + Vector2(sin(q * 18.0 + k) * CELL * 0.03 * k, 0)
					var f := 1.0 - k / 12.0
					cv.draw_circle(at, CELL * (0.04 + 0.1 * f), Color(Color.WHITE.lerp(color, 1.0 - f), 0.9 * f), true, -1.0, true)
				var head: Vector2 = fx.from.lerp(fx.to, 1.0 - pow(1.0 - p, 2.0))
				cv.draw_circle(head, CELL * 0.34, Color(color, 0.3), true, -1.0, true)
				cv.draw_circle(head, CELL * 0.16, Color(color, 0.9), true, -1.0, true)
				cv.draw_circle(head, CELL * 0.08, Color.WHITE, true, -1.0, true)
			"glow":
				var color: Color = fx.color
				var e := 1.0 - pow(1.0 - p, 3.0)
				var r: float = fx.radius * (0.45 + 0.55 * e)
				cv.draw_circle(fx.pos, r, Color(color, 0.22 * fade), true, -1.0, true)
				cv.draw_circle(fx.pos, r * 0.55, Color(color.lightened(0.4), 0.35 * fade), true, -1.0, true)
				cv.draw_circle(fx.pos, r * 0.22, Color(1, 1, 1, 0.9 * fade * fade), true, -1.0, true)
			"beam":
				# Shoots out from its origin to both ends, then thins away.
				var color: Color = fx.color
				var grow := clampf(age / 0.1, 0.0, 1.0)
				var a: Vector2 = fx.origin.lerp(fx.from, grow)
				var b: Vector2 = fx.origin.lerp(fx.to, grow)
				cv.draw_line(a, b, Color(color, 0.18 * fade), CELL * (0.15 + 0.85 * fade), true)
				cv.draw_line(a, b, Color(color, 0.65 * fade), CELL * (0.06 + 0.36 * fade), true)
				cv.draw_line(a, b, Color(1, 1, 1, 0.95 * fade), CELL * (0.03 + 0.12 * fade), true)
			"shard":
				var pos: Vector2 = fx.pos + fx.vel * age + Vector2(0, 1600.0) * age * age * 0.5
				var d: Vector2 = Vector2.from_angle(fx.rot + fx.spin * age) * fx.len * 0.5
				var alpha := 1.0 - smoothstep(0.55, 1.0, p)
				cv.draw_line(pos - d, pos + d, Color(fx.color, alpha), CELL * 0.11 * (1.0 - 0.5 * p), true)
			"impact":
				var color: Color = fx.color
				var e := 1.0 - pow(1.0 - p, 3.0)
				var size: float = fx.size
				cv.draw_circle(fx.pos, size * (0.25 + 0.45 * e), Color(1, 1, 1, 0.85 * fade), true, -1.0, true)
				for i in 8:
					var dir: Vector2 = Vector2.from_angle(fx.rot + i * TAU / 8.0)
					var len_k := 1.0 if i % 2 == 0 else 0.6
					cv.draw_line(fx.pos + dir * size * 0.35 * e, fx.pos + dir * size * (0.45 + 0.85 * e) * len_k,
						Color(Color.WHITE.lerp(color, p), fade), CELL * 0.07 * fade, true)
			"flash":
				var amp: float = fx.amp
				cv.draw_rect(Rect2(Vector2.ZERO, Vector2(cols, rows) * CELL).grow(CELL), Color(fx.color, amp * fade * fade))
			"bolt":
				# Grows from the rainbow arrow to its target, colours running along it. It
				# re-jags 30 times a second (crackle) and throws two short forks, over a soft
				# rainbow glow; a white flash marks the hit.
				var flick := int(_clock * 30.0)
				var pts := _bolt_points(fx.from, fx.to, fx.seed + flick, 9, 0.24)
				var shown := clampf(age / 0.12, 0.0, 1.0) * (pts.size() - 1)
				for layer in 3:
					for i in pts.size() - 1:
						if i >= shown:
							break
						var b: Vector2 = pts[i].lerp(pts[i + 1], minf(1.0, shown - i))
						var hue: float = fmod(fx.hue + i * 0.09 + _clock * 1.5, 1.0)
						match layer:
							0:
								cv.draw_line(pts[i], b, Color.from_hsv(hue, 0.7, 1.0, 0.22 * fade), CELL * (0.24 + 0.22 * fade), true)
							1:
								cv.draw_line(pts[i], b, Color.from_hsv(hue, 0.75, 1.0, 0.95 * fade), CELL * (0.07 + 0.13 * fade), true)
							2:
								cv.draw_line(pts[i], b, Color(1, 1, 1, fade), CELL * (0.025 + 0.025 * fade), true)
				var length: float = (fx.to - fx.from).length()
				for fork: Array in fx.forks:
					var at := int(fork[0] * (pts.size() - 1))
					if at >= shown:
						continue
					var dir: Vector2 = (fx.to - fx.from).normalized().rotated(fork[1])
					var fp := _bolt_points(pts[at], pts[at] + dir * length * fork[2], fx.seed + flick + at, 4, 0.12)
					var hue: float = fmod(fx.hue + at * 0.09 + _clock * 1.5, 1.0)
					cv.draw_polyline(fp, Color.from_hsv(hue, 0.7, 1.0, 0.75 * fade), CELL * (0.03 + 0.06 * fade), true)
					cv.draw_polyline(fp, Color(1, 1, 1, 0.8 * fade), CELL * 0.018, true)
				if shown >= pts.size() - 1 and age < 0.2:
					var k := 1.0 - age / 0.2
					cv.draw_circle(fx.to, CELL * 0.32 * k, Color(1, 1, 1, 0.55 * k), true, -1.0, true)
					cv.draw_circle(fx.to, CELL * 0.14 * k, Color(1, 1, 1, 0.95 * k), true, -1.0, true)
			"rainbow":
				var r: float = fx.radius * (1.0 - pow(1.0 - p, 2.0))
				var segs := 24
				for i in segs:
					var a0 := _clock * 3.0 + i * TAU / segs
					cv.draw_arc(fx.pos, r, a0, a0 + TAU / segs, 6, Color.from_hsv(float(i) / segs, 0.7, 1.0, 0.9 * fade),
						CELL * (0.04 + 0.14 * fade), true)
