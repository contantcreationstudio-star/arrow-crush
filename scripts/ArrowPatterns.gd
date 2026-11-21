class_name ArrowPatterns
extends RefCounted
## Ways of building arrows that the plain tiler (LevelGenerator._tile) never makes:
##   - Mega Spiral: one huge arrow coiled like a snail shell (25-60 cells). Its head is on
##     the outside, so the arrows around it have to go first before it can unwind.
##   - Giant Arrow board: the whole board is the outline of one big arrow.
##   - Gap filler: grows arrows into the gaps a board was left with, so it is packed.
## LevelDirector decides which level gets which; BoardCritic checks the result.

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


# --- Mega Spiral --------------------------------------------------------------------------

## Lays `count` spiral arrows in the free part of the mask (cells not in `taken`).
## `radius` sets the square each spiral coils in ((2r+1)^2 cells), `cap` its longest length.
## Returns the spirals (tail -> head, head on the outer end pointing out of the coil).
static func mega_spirals(mask: Dictionary, taken: Dictionary, count: int, radius: int, cap: int,
		rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var busy := taken.duplicate()
	var cells := mask.keys()
	for k in count:
		var free_cells: Array = []
		for c: Vector2i in cells:
			if not busy.has(c):
				free_cells.append(c)
		if free_cells.is_empty():
			break
		# Biggest coil that fits: shrink the square until one does.
		for r in range(radius, 1, -1):
			var walk := _try_spiral(mask, busy, free_cells, r, cap, rng)
			if walk.is_empty():
				continue
			for c: Vector2i in walk:
				busy[c] = true
			out.append(walk)
			break
	return out


## One spiral of radius `r` at the roomiest spot (sampled), or [] if none fits.
static func _try_spiral(mask: Dictionary, busy: Dictionary, free_cells: Array, r: int, cap: int,
		rng: RandomNumberGenerator) -> Array[Vector2i]:
	var best := Vector2i(-1, -1)
	var best_n := -1.0
	for t in mini(80, free_cells.size()):
		var c: Vector2i = free_cells[rng.randi() % free_cells.size()]
		var n := float(_square_free(c, r, mask, busy).size()) + rng.randf() * 0.5
		if n > best_n:
			best_n = n
			best = c
	var region := _square_free(best, r, mask, busy)
	if region.size() < (2 * r + 1) * (2 * r + 1) * 0.7:
		return []
	var walk := _spiral_walk(region, rng.randi() % 8, cap)
	if walk.size() < mini(cap, 20):
		return []
	walk.reverse()  # head = the outer end
	return walk


static func _square_free(center: Vector2i, r: int, mask: Dictionary, busy: Dictionary) -> Dictionary:
	var region := {}
	for y in range(center.y - r, center.y + r + 1):
		for x in range(center.x - r, center.x + r + 1):
			var c := Vector2i(x, y)
			if mask.has(c) and not busy.has(c):
				region[c] = true
	return region


## Walks a region from its outer edge inwards, always turning the same way when blocked.
## `variant` 0..7 picks the starting corner and the way it turns, so spirals differ.
## Returns cells from the outside in.
static func _spiral_walk(region: Dictionary, variant: int, cap: int) -> Array[Vector2i]:
	# Work in a flipped / swapped frame so one walking rule gives all 8 spirals.
	var local := {}   # local cell -> original cell
	for c: Vector2i in region:
		var p := c
		if variant & 4:
			p = Vector2i(p.y, p.x)
		if variant & 1:
			p.x = -p.x
		if variant & 2:
			p.y = -p.y
		local[p] = c
	var start: Vector2i = local.keys()[0]
	for p: Vector2i in local:
		if p.y < start.y or (p.y == start.y and p.x < start.x):
			start = p
	var walk: Array[Vector2i] = [start]
	var seen := {start: true}
	var heading := Vector2i.RIGHT
	while walk.size() < cap:
		var moved := false
		for turn in 2:
			var nxt: Vector2i = walk[-1] + heading
			if local.has(nxt) and not seen.has(nxt):
				walk.append(nxt)
				seen[nxt] = true
				moved = true
				break
			heading = Vector2i(-heading.y, heading.x)  # turn right
		if not moved:
			break
	var out: Array[Vector2i] = []
	for p in walk:
		out.append(local[p])
	return out


# --- Giant Arrow board ----------------------------------------------------------------------

## A ShapeFactory-style recipe whose outline is one big arrow. Every level gets its own
## mix of direction, head size, shaft width and tail (seeded by the level).
static func giant_arrow_recipe(level: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = level * 7919 + 3
	var hb := rng.randf_range(-0.3, 0.02)     # where the head's wide base sits (v, -1 = top)
	var hw := rng.randf_range(0.88, 0.98)     # head half-width
	var sw := rng.randf_range(0.42, 0.56)     # shaft half-width (room for a spiral inside)
	var top := -0.98
	var bottom := 0.98
	var pts := PackedVector2Array()
	match rng.randi() % 3:
		0:  # plain arrow
			pts = [Vector2(0, top), Vector2(hw, hb), Vector2(sw, hb), Vector2(sw, bottom),
				Vector2(-sw, bottom), Vector2(-sw, hb), Vector2(-hw, hb)]
		1:  # with a V-notched tail (fletching)
			var notch := rng.randf_range(0.2, 0.32)
			pts = [Vector2(0, top), Vector2(hw, hb), Vector2(sw, hb), Vector2(sw, bottom),
				Vector2(0, bottom - notch), Vector2(-sw, bottom), Vector2(-sw, hb), Vector2(-hw, hb)]
		2:  # double-headed
			var hb2 := -hb * 0.9
			pts = [Vector2(0, top), Vector2(hw, hb * 0.75), Vector2(sw, hb * 0.75), Vector2(sw, hb2 * 0.75),
				Vector2(hw, hb2 * 0.75), Vector2(0, bottom), Vector2(-hw, hb2 * 0.75), Vector2(-sw, hb2 * 0.75),
				Vector2(-sw, hb * 0.75), Vector2(-hw, hb * 0.75)]
	# Up or down only: the board is taller than wide, a lying arrow would be squashed.
	var rots := [0.0, PI]
	return {
		"parts": [{"kind": "poly", "pos": Vector2.ZERO, "size": Vector2.ONE, "rot": 0.0, "pts": pts}],
		"holes": [], "rot": rots[(level / 20) % rots.size()], "mirror": false,
		"fit": Vector4(0.0, 0.0, 1.0, 1.0), "giant_arrow": true,
	}


# --- Gap filler ------------------------------------------------------------------------------

## Packs a solvable board tighter: first stretches arrow tails into empty neighbouring
## cells, then grows new short arrows in the gaps that are left. Every change is kept only
## if the board can still be solved. Mirror cells stay empty.
## Returns how many cells were filled.
static func fill_gaps(arrows: Array, mask: Dictionary, cols: int, rows: int, mirrors: Dictionary,
		max_len: int, rng: RandomNumberGenerator) -> int:
	var owner := {}
	for i in arrows.size():
		for c: Vector2i in arrows[i]:
			owner[c] = i
	var empty: Array = []
	for c: Vector2i in mask:
		if not owner.has(c) and not mirrors.has(c):
			empty.append(c)
	LevelGenerator._shuffle(empty, rng)
	var filled := 0
	# 1. Longer tails: the tail never changes where an arrow flies, it only takes room.
	for c: Vector2i in empty:
		for d: Vector2i in DIRS:
			var i: int = owner.get(c + d, -1)
			if i < 0 or arrows[i][0] != c + d or arrows[i].size() >= max_len:
				continue
			arrows[i].insert(0, c)
			if LevelGenerator._solvable(arrows, cols, rows, mirrors):
				owner[c] = i
				filled += 1
				break
			arrows[i].remove_at(0)
	# 2. New arrows in what is still empty.
	for c: Vector2i in empty:
		if owner.has(c):
			continue
		var walk: Array[Vector2i] = [c]
		while walk.size() < 4:
			var nxt := Vector2i(-1, -1)
			for d: Vector2i in DIRS:
				var nb: Vector2i = walk[-1] + d
				if mask.has(nb) and not owner.has(nb) and not mirrors.has(nb) and not walk.has(nb):
					nxt = nb
					break
			if nxt.x < 0:
				break
			walk.append(nxt)
		if walk.size() < 2:
			continue
		arrows.append(walk)
		var ok := LevelGenerator._solvable(arrows, cols, rows, mirrors)
		if not ok:
			walk.reverse()
			ok = LevelGenerator._solvable(arrows, cols, rows, mirrors)
		if not ok:
			arrows.pop_back()
			continue
		for w: Vector2i in walk:
			owner[w] = arrows.size() - 1
		filled += walk.size()
	return filled
