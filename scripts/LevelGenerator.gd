class_name LevelGenerator
extends RefCounted
## Builds dense, shaped arrow mazes.
##
## Nothing is hard-coded per level number: every maze is built from a continuous
## `difficulty` (0..1) and the player's `style`, both supplied by GameData's
## behaviour model (how the player actually played earlier levels).
##
## Solvable by construction: the maze is tiled with snake arrows, then played
## greedily; any deadlock is fixed by flipping a stuck arrow (or dropping one).
## Several candidates are built and the one closest to the wanted challenge wins:
## for high difficulty that means very few free arrows at the start and long
## chains of "this must go before that".

enum Tier { EASY, NORMAL, HARD, SUPER_HARD }

const TIER_NAMES: Array[String] = ["Easy", "Normal", "Hard", "Super Hard"]
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


## Badge / banner label for a difficulty value.
static func tier_for_difficulty(d: float) -> Tier:
	if d < 0.25:
		return Tier.EASY
	if d < 0.5:
		return Tier.NORMAL
	if d < 0.75:
		return Tier.HARD
	return Tier.SUPER_HARD


## Hand-made first level for the tutorial: every lesson is guaranteed to be on the board.
##   A free arrow (escape), a same-colour pair (crush), a different-colour pair (bump
##   warning) and an arrow with two arrows in its lane (Super Power demo).
## TUTORIAL_CELLS names the head cell of each arrow the tutorial points at.
const TUTORIAL_CELLS := {
	"free": Vector2i(3, 0), "crush": Vector2i(0, 2), "bump": Vector2i(4, 6), "power": Vector2i(3, 4),
}

static func tutorial_level() -> Dictionary:
	var cols := 6
	var rows := 7
	var mask := {}
	for y in rows:
		for x in cols:
			mask[Vector2i(x, y)] = true
	var arrows: Array = []
	var colors: Array[int] = []
	var add := func(cells: Array, color: int) -> void:
		var typed: Array[Vector2i] = []
		typed.assign(cells)
		arrows.append(typed)
		colors.append(color)
	add.call([Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)], 1)                # A: free, slides right
	add.call([Vector2i(0, 1), Vector2i(0, 2)], 0)                                # B: points down into C
	add.call([Vector2i(1, 4), Vector2i(0, 4)], 0)                                # C: same colour as B
	add.call([Vector2i(3, 6), Vector2i(4, 6)], 2)                                # D: blocked by E (other colour)
	add.call([Vector2i(5, 6), Vector2i(5, 5), Vector2i(5, 4)], 3)                # E: free, goes up
	add.call([Vector2i(3, 5), Vector2i(3, 4)], 4)                                # G: power demo, goes up
	add.call([Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)], 2)                # H: in G's lane
	add.call([Vector2i(4, 1), Vector2i(3, 1), Vector2i(2, 1)], 3)                # I: in G's lane
	return {
		"cols": cols, "rows": rows, "mask": mask, "shape": "rect",
		"tier": Tier.EASY, "difficulty": 0.0,
		"arrows": arrows, "colors": colors, "free_at_start": 4, "depth": 3,
		# Balloons: A pops the first on its way out, B (crush) the second, C/G/H the third.
		"balloons": {Vector2i(4, 0): 1, Vector2i(1, 2): 1, Vector2i(2, 4): 1},
	}


const DAILY_DIFFICULTY := 0.8

## The daily challenge for UTC day number `day`: one big, hard maze that is the same on
## every phone (seeded only by the date - no player style, no server).
static func daily_level(day: int) -> Dictionary:
	return generate(100000 + day, DAILY_DIFFICULTY, {})


## Board pieces a level gets, by level number. Each one is introduced alone on a few
## levels of its own, then mixed into later levels. Every level has a CRUSH goal; the
## board pieces below are goals too - the level is won when all of them are done:
##   balloons (from 1)  - short arrows are carved out and replaced by balloons; arrows
##                        pop a balloon when they leave next to it or fly through it.
##   targets (from 12)  - bullseyes just outside the shape; an escaping arrow whose lane
##                        passes one hits it.
##   mirrors (from 21)  - empty cells with a mirror that turns arrows 90 degrees.
## Returns {balloons: arrows to carve, balloon_layers: max layers, targets: n, mirrors: n}.
##
## On top of the board pieces every level also gets the "chain" touches (see _chain_touches):
##   wind     - share of arrows drawn as long wavy snakes (a little from level 2, most from 101)
##   jackpots - planted same-colour lines that crush in one big chain (from level 5)
##   prisms   - prism arrows: any colour crushes them, the chain goes on in their colour (from 7)
##   creep    - cells an arrow slides forward into a gap a move left (1 from level 2, up to 3)
static func features_for(level: int) -> Dictionary:
	var f := _board_features(level)
	f.merge(_chain_touches(level))
	if level > 110:
		f.merge(_late_world(level), true)
	return f


## Widest board (cells). Above this a cell gets too small to read on a phone.
const MAX_COLS := 18

## Arrow-length feel of a level: [shortest, longest] arrow before the difficulty bonus.
const MOODS := {
	"short": Vector2i(2, 4),    # lots of small arrows: quick, crush-heavy
	"mixed": Vector2i(2, 9),    # small and medium together
	"snakes": Vector2i(4, 11),  # wavy snakes winding round each other
	"long": Vector2i(5, 16),    # a few very long arrows across the whole board
}
const MOOD_ORDER: Array[String] = ["snakes", "short", "mixed", "long"]
## Board piece each world puts in the spotlight (cycled across worlds 7-25).
const FEATURED: Array[String] = ["balloons", "targets", "crates", "ice", "golden", "mirrors", "timers", "links", "flips"]


## Levels 111-500, 20 per world: every world has its own main arrow feel (with a change
## of pace every 5th level) and one featured board piece on most levels. Every 5th
## level from the 3rd on is a "breather" without the featured piece.
static func _late_world(level: int) -> Dictionary:
	var w := (level - 1) / 20        # world index (0-based)
	var k := (level - 1) % 20        # place in the world
	var f := {}
	var mood := MOOD_ORDER[w % MOOD_ORDER.size()]
	if k % 5 == 4:
		mood = MOOD_ORDER[(w + 1 + k / 5) % MOOD_ORDER.size()]
	f.mood = mood
	f.wind = {"short": 0.1, "mixed": 0.3, "snakes": 0.7, "long": 0.55}[mood]
	if k % 5 == 2:
		return f  # breather
	var tough := clampf((w - 5) / 19.0, 0.0, 1.0)   # 0 in world 6 .. 1 in world 25
	match FEATURED[w % FEATURED.size()]:
		"balloons":
			f.balloons = 3 + roundi(tough * 4.0)
			f.balloon_layers = 2 + int(tough > 0.5)
		"targets":
			f.targets = 2 + roundi(tough * 2.0)
		"crates":
			f.crates = 4 + roundi(tough * 5.0)
			f.crate_layers = 1  # every crate breaks in one hit
			f.erase("ice")
		"ice":
			f.ice = 3 + roundi(tough * 3.0)
			f.ice_layers = 1 + int(tough > 0.4)
			f.erase("crates")
		"golden":
			f.golden = 1 + int(tough > 0.5)
		"mirrors":
			f.mirrors = 3 + roundi(tough * 3.0)
		"timers":
			f.timers = 1 + int(tough > 0.5)
		"links":
			f.links = 1 + int(tough > 0.5)
		"flips":
			f.flips = 2 + int(tough > 0.6)
	return f


## Light touches on levels 1-100 so players keep meeting them; the full version on 101+.
## Levels 101-110 run easy -> medium -> hard: few twists first, more towards the end.
static func _chain_touches(level: int) -> Dictionary:
	var f := {}
	if level <= 1:
		return f
	if level <= 100:
		f.creep = 1 if level < 30 else (2 if level < 70 else 2 + int(level % 3 == 0))
		f.wind = lerpf(0.12, 0.35, (level - 2) / 98.0)
		if level >= 5:
			f.jackpots = 1 + int(level >= 60 and level % 4 == 0)
			f.jackpot_len = 3 if level < 30 else (4 if level < 70 else 5)
		if level in [7, 8]:
			f.prisms = 1  # the prism's own levels
		elif level >= 14 and level % 6 == 2:
			f.prisms = 1 + int(level >= 60)
		return f
	var k := (level - 101) % 10       # place in the episode: 0 = start (easy) .. 9 = end (hard)
	f.wind = 0.6 + 0.03 * k
	f.creep = 2 + int(k >= 5)
	f.jackpots = 2 + int(k >= 4)
	f.jackpot_len = 4 + int(k >= 3) + int(k >= 7)
	f.prisms = 1 + int(k >= 3) + int(k >= 7)
	return f


static func _board_features(level: int) -> Dictionary:
	var f := {}
	# Each new piece gets a few levels of its own first.
	if level in [3, 4]:
		return {"color_order": true}
	if level in [9, 10, 11]:
		return {"crates": 2 + level - 9, "crate_layers": 1}
	if level in [12, 13]:
		return {"targets": 2}
	if level in [15, 16]:
		return {"ice": 2 + level - 15, "ice_layers": 1}
	if level in [19, 20]:
		return {"golden": 1}
	if level in [21, 22, 23]:
		return {"mirrors": 2 + (level - 21)}
	if level in [26, 27]:
		return {"timers": 1}
	if level in [30, 31]:
		return {"links": 1 + level - 30}
	if level in [34, 35]:
		return {"flips": 2}
	# Special arrows mix into later levels.
	if level >= 24 and level % 7 == 2:
		f.golden = 1 + int(level >= 50)
	if level >= 28 and level % 8 == 5:
		f.timers = 1 + int(level >= 60)
	if level >= 32 and level % 9 == 4:
		f.links = 1 + int(level >= 55)
	if level >= 36 and level % 10 == 7:
		f.flips = 2 + int(level >= 70)
	if level >= 17 and level % 4 == 2:
		f.color_order = true
	if level >= 18 and level % 5 == 0:
		f.crates = clampi(3 + int(level / 15.0), 3, 9)
		f.crate_layers = 1
	if level >= 18 and level % 6 == 3:
		f.ice = clampi(2 + int(level / 20.0), 2, 6)
		f.ice_layers = 1 if level < 35 else 2
	if f.has("crates") or f.has("ice"):
		return f  # one blocker family per level keeps the board readable
	if level <= 8 or level % 3 == 0 or level % 7 == 0:
		f.balloons = clampi(2 + int(level / 12.0), 2, 7)
		f.balloon_layers = 1 if level < 15 else (2 if level < 40 else 3)
	if level >= 14 and level % 4 == 1:
		f.targets = clampi(2 + int(level / 30.0), 2, 4)
	if level >= 24 and level % 2 == 1:
		f.mirrors = clampi(2 + int((level - 21) / 15.0), 2, 6)
	return f


## `difficulty` 0..1. `style` = {pace: -1 slow thinker .. +1 fast tapper,
## accuracy: 0..1 share of correct taps}. `features` = features_for(level) or {}.
## Returns { cols, rows, mask, shape, tier, difficulty, arrows: [Array[Vector2i] tail->head],
##           colors: [int per arrow], free_at_start, depth,
##           mirrors: {cell: 0 "/" or 1 "\"}, balloons: {cell: layers}, targets: {cell beside the shape: true},
##           crates: {cell: layers}, ice: {arrow index: layers}, color_order: {} or {color, count},
##           hits: taps spent smashing crates / ice in a test play (added to the move limit) }
static func generate(level: int, difficulty: float, style: Dictionary = {}, features: Dictionary = {}) -> Dictionary:
	var d := clampf(difficulty, 0.0, 1.0)
	var pace: float = style.get("pace", 0.0)
	var accuracy: float = style.get("accuracy", 0.7)

	# Board size and arrow length grow smoothly with difficulty: from an 8x10 warm-up
	# to a 24x29 maze packed with ~100 arrows at the top end.
	# Capped at MAX_COLS: past that a cell is too small on a phone and arrows turn into
	# threads. Harder levels get harder through longer arrows and board pieces instead.
	var cols := clampi(roundi(lerpf(8.0, float(MAX_COLS), d)), 8, MAX_COLS)
	if level > 100:
		cols = clampi(roundi(lerpf(13.0, float(MAX_COLS), d)), 13, MAX_COLS)  # long snakes need room
	# Every level gets its own outline that no other level uses (see ShapeFactory). A
	# picture needs a board wide enough to stay recognisable (its min_cols).
	var recipe := ShapeFactory.recipe_for(level)
	if recipe.has("min_cols"):
		# Pictures read best with room: never below 12 cells (14 after the first worlds).
		var room := 12 if level < 20 else 14
		cols = clampi(maxi(cols, maxi(int(recipe.min_cols), room)), 8, MAX_COLS)
	var rows := roundi(cols * 1.15) + 1
	var shape := "shape-%d" % level
	var mask := _make_mask(recipe, cols, rows)

	# Fast tappers get more (shorter) arrows to scan; slow thinkers fewer, longer ones.
	var min_len := 2 + roundi(d)
	var max_len := roundi(lerpf(4.0, 15.0, d) - pace * 2.0)
	# Labyrinth levels: many short-to-medium arrows packed tight instead of a few long
	# ones - a dense board where every lane runs through a crowd is what makes it hard.
	var harden_pre := hardening_for(level, d)
	var wind: float = features.get("wind", 0.0)
	var mood: String = features.get("mood", "")
	if mood != "":
		# Worlds 111-500: each level has a feel of its own (see _late_world).
		var lens: Vector2i = MOODS[mood]
		min_len = lens.x
		max_len = lens.y + roundi(d * 2.0)
	elif level > 100:
		# Wavy chapter: fewer, longer snakes winding around each other.
		min_len = 4
		max_len += 5
	elif harden_pre > 0.0:
		min_len = 2
		max_len = roundi(lerpf(float(max_len), 6.0, harden_pre))
	# Boards get denser the further the player goes: from level 100 to 500 arrows get
	# shorter (so many more of them fit on the same board) and gaps get filled.
	var dense := density_for(level)
	if dense > 0.0:
		max_len = mini(roundi(float(max_len) * lerpf(1.0, 0.75, dense)), roundi(lerpf(17.0, 9.0, dense)))
		min_len = mini(min_len, 3 if dense < 0.5 else 2)
		wind *= lerpf(1.0, 0.45, dense)  # fewer of the extra-long wavy snakes
	var len_range := Vector2i(min_len, maxi(min_len + 1, max_len))
	var candidates := roundi(lerpf(2.0, 8.0, d))
	if harden_pre > 0.0:
		candidates = roundi(lerpf(float(candidates), 2.0, harden_pre))  # the labyrinth pass does the shaping
	if dense > 0.0:
		candidates = maxi(candidates, 4)  # more tries, so a well-filled board can be picked

	# What the chosen maze should feel like.
	var target_free := lerpf(6.0, 1.0, d)                                   # free arrows at start
	var depth_weight := (0.5 + 2.0 * clampf((accuracy - 0.5) / 0.5, 0.0, 1.0)) * d  # careful players get long chains
	var count_weight := 0.3 + 0.4 * maxf(pace, 0.0) + 0.8 * dense
	var cover_weight := 30.0 + 40.0 * dense

	var best := {}
	var best_score := -INF
	for k in candidates:
		var rng := RandomNumberGenerator.new()
		rng.seed = level * 1009 + k * 7 + roundi(d * 20.0) * 31 + 13
		# The outline first (from level 2): the arrows themselves draw the picture's edge.
		var outline: Array = []
		if level >= 2:
			var seg := Vector2i(clampi(len_range.y - 2, 4, 9), clampi(len_range.y + 3, 6, 14))
			if dense > 0.0:  # shorter edge arrows too, so the outline doesn't eat the board
				seg = Vector2i(clampi(seg.x - roundi(2.0 * dense), 3, 9), clampi(seg.y - roundi(6.0 * dense), 5, 14))
			outline = _contour_arrows(mask, 1 if cols < 13 else 2, seg, rng)
		var tiles := _tile(mask, len_range, rng, wind, outline)
		var cand_mirrors := _carve_mirrors(tiles, int(features.get("mirrors", 0)), rng)
		_make_solvable(tiles, cols, rows, rng, cand_mirrors)
		var stats := _analyse(tiles, cols, rows, cand_mirrors)
		var used := 0
		for a: Array in tiles:
			used += a.size()
		var coverage := float(used) / maxf(1.0, mask.size())
		var score := coverage * cover_weight - absf(float(stats.free_at_start) - target_free) * 6.0 \
			+ float(stats.depth) * depth_weight + tiles.size() * count_weight * d
		if score > best_score:
			best_score = score
			best = {"arrows": tiles, "free_at_start": stats.free_at_start, "depth": stats.depth, "mirrors": cand_mirrors}

	# Maze hardening: from about level 25 the arrows are turned (same cells, other end
	# as the head) until the board is a real labyrinth - see _harden.
	var harden := hardening_for(level, d)
	if harden > 0.0:
		var hrng := RandomNumberGenerator.new()
		hrng.seed = level * 6007 + roundi(d * 20.0) * 17 + 5
		_harden(best.arrows, cols, rows, best.mirrors, harden, maxf(1.0, lerpf(4.0, 1.0, harden)), hrng)
		var hs := _analyse(best.arrows, cols, rows, best.mirrors)
		best.free_at_start = hs.free_at_start
		best.depth = hs.depth

	# Balloons and targets never change which arrows can leave, so they go in last.
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = level * 4241 + 77
	var arrows: Array = best.arrows
	var mirrors: Dictionary = best.mirrors
	# Crates first: balloons count their neighbouring arrows, so nothing may be carved after them.
	var crates := _carve_crates(arrows, int(features.get("crates", 0)), int(features.get("crate_layers", 1)),
		mirrors, {}, rng2)
	var balloons := _carve_balloons(arrows, int(features.get("balloons", 0)),
		int(features.get("balloon_layers", 1)), mirrors, rng2)
	# Flip arrows change lanes, so they are settled before anything that reads lanes.
	var flips := _pick_flips(arrows, int(features.get("flips", 0)), mirrors, cols, rows, rng2)
	var targets := _pick_targets(arrows, mirrors, mask, cols, rows, int(features.get("targets", 0)), rng2)
	var ice := _pick_ice(arrows, int(features.get("ice", 0)), int(features.get("ice_layers", 1)), rng2)
	var taken := ice.duplicate()
	for i: int in flips:
		taken[i] = true
	var golden := _pick_golden(arrows, int(features.get("golden", 0)), taken, mirrors, cols, rows, rng2)
	var timers := _pick_timers(arrows, int(features.get("timers", 0)), taken, mirrors, cols, rows, rng2)
	var links := _pick_links(arrows, int(features.get("links", 0)), taken, mirrors, cols, rows, rng2)
	var hits := _play_obstacles(arrows, ice, crates, mirrors, cols, rows)
	if not (balloons.is_empty() and crates.is_empty()):
		var stats := _analyse(arrows, cols, rows, mirrors)
		best.free_at_start = stats.free_at_start
		best.depth = stats.depth
	var colors := _assign_colors(arrows, cols, rows, d, level, mirrors, harden)
	for i: int in golden:
		colors[i] = GOLD  # its own colour: nothing ever crushes a golden arrow
	# Chain touches: planted same-colour lines and prism arrows. Arrows with a job of
	# their own (golden, bonus, linked, flip, frozen) are left alone.
	var busy := ice.duplicate()
	for i: int in flips:
		busy[i] = true
	for i: int in golden:
		busy[i] = true
	for i: int in timers:
		busy[i] = true
	for pair: Array in links:
		for i: int in pair:
			busy[i] = true
	var crng := RandomNumberGenerator.new()
	crng.seed = level * 3301 + 41
	# Prisms first (they need an arrow on each side), then the jackpot lines around them.
	var prisms := _plant_prisms(arrows, colors, int(features.get("prisms", 0)), busy, mirrors, cols, rows, crng)
	var first := _first_hits(arrows, cols, rows, mirrors)
	for p: int in prisms:
		busy[p] = true
		busy[first[p]] = true  # the arrow the prism's chain runs into keeps the prism's colour
		for i in arrows.size():
			if first[i] == p:
				busy[i] = true
	var jackpots := _plant_jackpots(arrows, colors, int(features.get("jackpots", 0)),
		int(features.get("jackpot_len", 3)), busy, mirrors, cols, rows, crng)
	for chain: Array in jackpots:
		for i: int in chain:
			busy[i] = true
	var order := {}
	if features.get("color_order", false):
		order = _color_order(colors, arrows, mirrors, cols, rows, rng2, busy)

	return {
		"cols": cols, "rows": rows, "mask": mask, "shape": shape,
		"tier": tier_for_difficulty(d), "difficulty": d,
		"arrows": arrows, "colors": colors, "free_at_start": best.free_at_start, "depth": best.depth,
		"mirrors": mirrors, "balloons": balloons, "targets": targets,
		"crates": crates, "ice": ice, "color_order": order, "hits": hits,
		"golden": golden, "timers": timers, "links": links, "flips": flips,
		"harden": harden, "jackpots": jackpots, "prisms": prisms, "wind": wind,
		# Creep: light on the first levels (one cell, one wave), a longer ripple on hard mazes.
		"creep": int(features.get("creep", 0)),
		"creep_waves": 1 if level < 8 else clampi(1 + roundi(d * 4.0), 1, 5),
		# Magnet: an arrow facing a fresh gap slides over to a same-colour arrow and crushes it.
		"magnet": level >= 2,
		# Picture levels: the picture itself, drawn as a soft silhouette behind the board.
		"picture": {"bits": recipe.bitmap, "bw": recipe.bw, "bh": recipe.bh, "fit": recipe.fit} \
			if recipe.has("bitmap") else {},
		# Crushes a careful player can make (the level's crush goal is a share of this).
		"crush_max": estimate_crushes(arrows, _crush_colors(colors, links, ice), cols, rows, mirrors, prisms),
	}


# --- Maze hardening -------------------------------------------------------------------------

## How hard the labyrinth pass pushes (0..1). Nothing before level 20, then it ramps
## in over levels 20-35, scaled by the level's difficulty (spikes push harder).
## How packed the board is past level 100: 0 up to level 100, rising to 1 at level 500.
static func density_for(level: int) -> float:
	return clampf((level - 100) / 400.0, 0.0, 1.0)


static func hardening_for(level: int, d: float) -> float:
	var ramp := clampf((level - 20) / 15.0, 0.0, 1.0)
	if level > 100:
		ramp = 0.6  # the long wavy snakes are the twist; a softer labyrinth on top
	return clampf((d - 0.4) / 0.45, 0.0, 1.0) * ramp


## Labyrinth pass. Every arrow keeps its cells; only which end is the head is chosen.
## Each arrow waits for every arrow sitting in its lane, so the board is a "who must go
## first" graph - solvable exactly when that graph has no loop. Simulated annealing flips
## heads to make it a maze a human has to think through:
##   - few free arrows at the start, and few free at every step (narrow paths),
##   - long chains (an arrow deep in the maze needs many others gone first),
##   - decoys: arrows whose lane looks open but is blocked 4+ cells away.
## A floor on the paths' width keeps it a puzzle, not one single line to follow.
static func _harden(arrows: Array, cols: int, rows: int, mirrors: Dictionary, strength: float,
		target_free: float, rng: RandomNumberGenerator) -> void:
	var n := arrows.size()
	if n < 4:
		return
	var owner := {}
	for i in n:
		for c: Vector2i in arrows[i]:
			owner[c] = i
	# For both orientations (0 = as built, 1 = reversed): the arrows in the lane (null when
	# the lane runs back through the arrow itself) and how far away the first one is.
	var blk: Array = []
	var dist: Array = []
	for i in n:
		var a: Array = arrows[i]
		var pair: Array = []
		var far: Array[int] = []
		for o in 2:
			var head: Vector2i = a[-1] if o == 0 else a[0]
			var neck: Vector2i = a[-2] if o == 0 else a[1]
			var seen := {}
			var self_hit := false
			var first := 0
			var k := 0
			for c: Vector2i in trace(head, head - neck, mirrors, cols, rows).cells:
				k += 1
				if not owner.has(c):
					continue
				var j: int = owner[c]
				if j == i:
					self_hit = true
					break
				if first == 0:
					first = k
				seen[j] = true
			pair.append(null if self_hit else seen.keys())
			far.append(first)
		blk.append(pair)
		dist.append(far)

	var ori: Array[int] = []
	ori.resize(n)
	ori.fill(0)
	var cur := _hard_score(blk, dist, ori, strength, target_free)
	if cur == -INF:
		return  # should not happen (the maze was made solvable), but never break it
	# Constructive start: a few planned play orders, keep the hardest one.
	for t in 3:
		var plan := _plan_orientation(blk, rng)
		if plan.is_empty():
			continue
		var ps := _hard_score(blk, dist, plan, strength, target_free)
		if ps > cur:
			cur = ps
			ori = plan
	var best := cur
	var best_ori := ori.duplicate()
	var iters := roundi(n * lerpf(5.0, 9.0, strength))
	var temp := 2.0
	var cool := pow(0.02 / temp, 1.0 / maxf(1.0, iters))
	for it in iters:
		var i := rng.randi_range(0, n - 1)
		var o := 1 - ori[i]
		if blk[i][o] == null:
			continue
		ori[i] = o
		var sc := _hard_score(blk, dist, ori, strength, target_free)
		if sc != -INF and (sc >= cur or rng.randf() < exp((sc - cur) / temp)):
			cur = sc
			if sc > best:
				best = sc
				best_ori = ori.duplicate()
		else:
			ori[i] = 1 - o
		temp *= cool
	for i in n:
		if best_ori[i] == 1:
			arrows[i].reverse()


## Plans a play order first and points each arrow to fit it. Picking arrow i with
## orientation o is allowed once every arrow in that lane is already gone, so the
## order is always a valid solution. Arrows that can wait for a blocker are preferred
## (they are not free at the start), and among them the one deepest in the chain.
## Returns the orientation per arrow, or [] if the plan got stuck.
static func _plan_orientation(blk: Array, rng: RandomNumberGenerator) -> Array[int]:
	var n := blk.size()
	var ori: Array[int] = []
	ori.resize(n)
	ori.fill(-1)
	var round_of: Array[int] = []
	round_of.resize(n)
	round_of.fill(0)
	for step in n:
		var pick := -1
		var pick_o := 0
		var pick_score := -INF
		for i in n:
			if ori[i] >= 0:
				continue
			for o in 2:
				var b = blk[i][o]
				if b == null:
					continue
				var ok := true
				var r := 0
				for j: int in b:
					if ori[j] < 0:
						ok = false
						break
					r = maxi(r, round_of[j] + 1)
				if not ok:
					continue
				# Waiting on someone beats being free; deeper beats shallower; a little noise.
				var sc := (100.0 if not b.is_empty() else _unlocks(i, blk, ori) * 3.0) + r + rng.randf() * 2.5
				if sc > pick_score:
					pick_score = sc
					pick = i
					pick_o = o
		if pick < 0:
			return []
		ori[pick] = pick_o
		var rr := 0
		for j: int in blk[pick][pick_o]:
			rr = maxi(rr, round_of[j] + 1)
		round_of[pick] = rr
	return ori


## Planner helper: how many still-unplaced arrows would be able to wait on someone
## (a blocked lane) as soon as arrow `f` is gone - the free arrow worth spending.
static func _unlocks(f: int, blk: Array, ori: Array[int]) -> int:
	var count := 0
	for k in blk.size():
		if k == f or ori[k] >= 0:
			continue
		for o in 2:
			var b = blk[k][o]
			if b == null or not b.has(f):
				continue
			var missing := 0
			for j: int in b:
				if ori[j] < 0 and j != f:
					missing += 1
					break
			if missing == 0:
				count += 1
				break
	return count


## Hardness of one orientation set (higher = harder), -INF if it cannot be solved.
## Kahn's topological sort gives each arrow its round: 0 = free at the start,
## otherwise 1 + the latest round of the arrows in its lane.
static func _hard_score(blk: Array, dist: Array, ori: Array[int], strength: float, target_free: float) -> float:
	var n := ori.size()
	var waiting: Array[int] = []
	waiting.resize(n)
	var after: Array = []
	after.resize(n)
	for i in n:
		after[i] = []
	var decoys := 0
	for i in n:
		var b: Array = blk[i][ori[i]]
		waiting[i] = b.size()
		for j: int in b:
			after[j].append(i)
		if int(dist[i][ori[i]]) >= 4:
			decoys += 1
	var round_of: Array[int] = []
	round_of.resize(n)
	round_of.fill(0)
	var queue: Array[int] = []
	for i in n:
		if waiting[i] == 0:
			queue.append(i)
	var free0 := queue.size()
	var head := 0
	var deepest := 0
	var total := 0
	while head < queue.size():
		var j := queue[head]
		head += 1
		total += round_of[j]
		deepest = maxi(deepest, round_of[j])
		for i: int in after[j]:
			round_of[i] = maxi(round_of[i], round_of[j] + 1)
			waiting[i] -= 1
			if waiting[i] == 0:
				queue.append(i)
	if queue.size() < n:
		return -INF  # a loop: these arrows block each other forever
	var width := float(n) / (deepest + 1)          # free arrows per step on average
	var min_width := lerpf(3.0, 1.7, strength)     # narrower than this = one dull line
	return -maxf(width, min_width) * 6.0 \
		+ float(total) / n \
		- maxf(0.0, free0 - target_free) * 4.0 \
		+ float(decoys) / n * 10.0 * strength


# --- Special arrows: golden, timer, linked, flip --------------------------------------------

## Colour index of golden arrows (ArrowPath.ARROW_COLORS[GOLD]); never given to others.
const GOLD := 6


## Escape-only play: every arrow can leave in some order.
static func _solvable(arrows: Array, cols: int, rows: int, mirrors: Dictionary) -> bool:
	var occupancy := {}
	for i in arrows.size():
		for c: Vector2i in arrows[i]:
			occupancy[c] = i
	var remaining := {}
	for i in arrows.size():
		remaining[i] = true
	while not remaining.is_empty():
		var free: Array[int] = []
		for i: int in remaining:
			if _lane_clear(arrows[i], occupancy, cols, rows, mirrors):
				free.append(i)
		if free.is_empty():
			return false
		for i in free:
			remaining.erase(i)
			for c: Vector2i in arrows[i]:
				occupancy.erase(c)
	return true


## Escape round of each arrow when every free arrow leaves each round (0 = free at start).
static func _rounds(arrows: Array, cols: int, rows: int, mirrors: Dictionary) -> Array[int]:
	var round_of: Array[int] = []
	round_of.resize(arrows.size())
	round_of.fill(-1)
	var occupancy := {}
	for i in arrows.size():
		for c: Vector2i in arrows[i]:
			occupancy[c] = i
	var remaining := {}
	for i in arrows.size():
		remaining[i] = true
	var r := 0
	while not remaining.is_empty():
		var free: Array[int] = []
		for i: int in remaining:
			if _lane_clear(arrows[i], occupancy, cols, rows, mirrors):
				free.append(i)
		if free.is_empty():
			break
		for i in free:
			round_of[i] = r
			remaining.erase(i)
			for c: Vector2i in arrows[i]:
				occupancy.erase(c)
		r += 1
	return round_of


## How many arrows must leave before arrow `i` can (everything in its lane, and
## everything in their lanes, and so on).
static func _blockers_of(i: int, arrows: Array, cols: int, rows: int, mirrors: Dictionary) -> int:
	var owner := {}
	for k in arrows.size():
		for c: Vector2i in arrows[k]:
			owner[c] = k
	var seen := {i: true}
	var todo: Array[int] = [i]
	while not todo.is_empty():
		var k: int = todo.pop_back()
		var a: Array = arrows[k]
		for c: Vector2i in trace(a[-1], a[-1] - a[-2], mirrors, cols, rows).cells:
			if owner.has(c) and not seen.has(owner[c]):
				seen[owner[c]] = true
				todo.append(owner[c])
	return seen.size() - 1


static func _straight(a: Array) -> bool:
	var d: Vector2i = a[1] - a[0]
	for k in range(1, a.size()):
		if a[k] - a[k - 1] != d:
			return false
	return true


## Flip arrows turn around after every move. Only straight ones (they keep their cells),
## and only where the maze stays solvable with the arrow facing either way - so some
## arrow can always move, whichever way it faces.
static func _pick_flips(arrows: Array, n: int, mirrors: Dictionary, cols: int, rows: int,
		rng: RandomNumberGenerator) -> Array[int]:
	var flips: Array[int] = []
	if n <= 0:
		return flips
	var order: Array = range(arrows.size())
	_shuffle(order, rng)
	for i: int in order:
		if flips.size() >= n:
			break
		var a: Array = arrows[i]
		if a.size() > 4 or not _straight(a):
			continue
		a.reverse()
		var ok := _solvable(arrows, cols, rows, mirrors)
		a.reverse()
		if ok and _solvable(arrows, cols, rows, mirrors):
			flips.append(i)
	return flips


## Golden arrows: the goal is to fly them out. Always buried: never free at the start,
## picked from the deeper half of the maze so other arrows must be cleared (or crushed) first.
static func _pick_golden(arrows: Array, n: int, taken: Dictionary, mirrors: Dictionary, cols: int, rows: int,
		rng: RandomNumberGenerator) -> Array[int]:
	var golden: Array[int] = []
	if n <= 0:
		return golden
	var round_of := _rounds(arrows, cols, rows, mirrors)
	var deepest := 0
	for r: int in round_of:
		deepest = maxi(deepest, r)
	var order: Array = range(arrows.size())
	_shuffle(order, rng)
	# Deep half first, then anything not free at the start, then (tiny mazes only) anything.
	for min_round: int in [maxi(1, ceili(deepest * 0.5)), 1, 0]:
		for i: int in order:
			if golden.size() >= n:
				return golden
			if taken.has(i) or round_of[i] < min_round or (min_round > 0 and arrows[i].size() < 3):
				continue
			golden.append(i)
			taken[i] = true
	return golden


## Bonus arrows: off the board within their count of moves = bonus coins (never a loss). The count is the
## number of arrows that have to leave first, plus breathing room.
static func _pick_timers(arrows: Array, n: int, taken: Dictionary, mirrors: Dictionary, cols: int, rows: int,
		rng: RandomNumberGenerator) -> Dictionary:
	var timers := {}
	if n <= 0:
		return timers
	var order: Array = range(arrows.size())
	_shuffle(order, rng)
	for i: int in order:
		if timers.size() >= n:
			break
		if taken.has(i):
			continue
		var need := _blockers_of(i, arrows, cols, rows, mirrors)
		if need < 1 or need > 6:
			continue  # free already is dull; buried deep is unfair
		timers[i] = need + 1 + rng.randi_range(4, 6)
		taken[i] = true
	return timers


## Linked pairs: two arrows that only leave together. Both come from the same escape
## round (both are free once the earlier rounds are gone), so linking can't lock the maze.
static func _pick_links(arrows: Array, n: int, taken: Dictionary, mirrors: Dictionary, cols: int, rows: int,
		rng: RandomNumberGenerator) -> Array:
	var links: Array = []
	if n <= 0:
		return links
	var rounds := _rounds(arrows, cols, rows, mirrors)
	var order: Array = range(arrows.size())
	_shuffle(order, rng)
	for i: int in order:
		if links.size() >= n:
			break
		if taken.has(i) or rounds[i] < 0:
			continue
		for j: int in order:
			if j == i or taken.has(j) or rounds[j] != rounds[i]:
				continue
			var a: Vector2i = arrows[i][arrows[i].size() / 2]
			var b: Vector2i = arrows[j][arrows[j].size() / 2]
			if absi(a.x - b.x) + absi(a.y - b.y) > 5:
				continue
			links.append([i, j])
			taken[i] = true
			taken[j] = true
			break
	return links


# --- Crates, ice and colour orders ----------------------------------------------------------

## Carves `n` short arrows out and stacks wooden crates (1..max_layers) in their cells.
## Crates block lanes; an arrow shot into one knocks a layer off, so they never deadlock.
static func _carve_crates(arrows: Array, n: int, max_layers: int, mirrors: Dictionary, taken: Dictionary,
		rng: RandomNumberGenerator) -> Dictionary:
	var crates := {}
	if n <= 0:
		return crates
	var order: Array = range(arrows.size())
	_shuffle(order, rng)
	var picked: Array[int] = []
	for i: int in order:
		if picked.size() >= n:
			break
		var arrow: Array = arrows[i]
		if arrow.size() > 3:
			continue
		var far := true
		for j in picked:
			var a: Vector2i = arrows[j][-1]
			var b: Vector2i = arrow[-1]
			if absi(a.x - b.x) + absi(a.y - b.y) < 3:
				far = false
		if far:
			picked.append(i)
	picked.sort()
	picked.reverse()
	for i in picked:
		var layers := rng.randi_range(1, maxi(1, max_layers))
		for c: Vector2i in arrows[i]:
			if not mirrors.has(c) and not taken.has(c):
				crates[c] = layers
		arrows.remove_at(i)
	return crates


## Freezes `n` arrows in ice (1..max_layers). Frozen arrows can't move until the ice is
## cracked - by an arrow shot into them, a neighbouring arrow leaving, or a blast.
## Returns {arrow index: layers}.
static func _pick_ice(arrows: Array, n: int, max_layers: int, rng: RandomNumberGenerator) -> Dictionary:
	var ice := {}
	if n <= 0:
		return ice
	var order: Array = range(arrows.size())
	_shuffle(order, rng)
	for i: int in order:
		if ice.size() >= n:
			break
		var far := true
		for j: int in ice:
			var a: Vector2i = arrows[j][-1]
			var b: Vector2i = arrows[i][-1]
			if absi(a.x - b.x) + absi(a.y - b.y) < 3:
				far = false
		if far:
			ice[i] = rng.randi_range(1, maxi(1, max_layers))
	return ice


## Test-plays the maze with the crate / ice rules (escape a free arrow; otherwise shoot
## an arrow into a crate or frozen arrow; each obstacle cracks once per tap). If the
## play gets stuck, the ice on a stuck arrow is melted for good, and crates nobody can
## reach lose the layers that never broke - so every level can be finished.
## Returns how many taps went into smashing obstacles.
static func _play_obstacles(arrows: Array, ice: Dictionary, crates: Dictionary, mirrors: Dictionary,
		cols: int, rows: int) -> int:
	if ice.is_empty() and crates.is_empty():
		return 0
	var occ := {}
	for i in arrows.size():
		for c: Vector2i in arrows[i]:
			occ[c] = i
	var lanes: Array = []
	for a: Array in arrows:
		lanes.append(trace(a[-1], a[-1] - a[-2], mirrors, cols, rows).cells)
	var frozen := ice.duplicate()
	var boxes := crates.duplicate()
	var alive := {}
	for i in arrows.size():
		alive[i] = true
	var hits := 0
	var guard := 0
	while not alive.is_empty() and guard < 5000:
		guard += 1
		var moved := false
		var shot := Vector2i(-1, -1)   # x = arrow, y = 0 crate / 1 ice target
		var shot_target: Variant = null
		for i: int in alive:
			if frozen.get(i, 0) > 0:
				continue
			var first: Variant = null
			for c: Vector2i in lanes[i]:
				if boxes.has(c) or occ.has(c):
					first = c
					break
			if first == null:
				# Escape: neighbours crack.
				alive.erase(i)
				for c: Vector2i in arrows[i]:
					occ.erase(c)
				var near := {}
				for c: Vector2i in arrows[i]:
					for dv: Vector2i in DIRS:
						near[c + dv] = true
				var cracked := {}
				for c: Vector2i in near:
					if boxes.has(c):
						_knock(boxes, c)
					elif occ.has(c) and frozen.get(occ[c], 0) > 0 and not cracked.has(occ[c]):
						cracked[occ[c]] = true
						frozen[occ[c]] -= 1
				moved = true
				break
			if shot.x < 0:
				if boxes.has(first):
					shot = Vector2i(i, 0)
					shot_target = first
				elif occ[first] != i and frozen.get(occ[first], 0) > 0:
					shot = Vector2i(i, 1)
					shot_target = occ[first]
		if moved:
			continue
		if shot.x >= 0:
			hits += 1
			if shot.y == 0:
				_knock(boxes, shot_target)
			else:
				frozen[shot_target] -= 1
			continue
		# Stuck: melt the ice of a frozen arrow for good (in the real level too).
		var melted := false
		for i: int in alive:
			if frozen.get(i, 0) > 0:
				frozen[i] = 0
				ice.erase(i)
				melted = true
				break
		if not melted:
			break  # cannot happen: the plain maze is solvable
	for c: Vector2i in crates.keys():
		var left: int = boxes.get(c, 0)
		if left > 0:
			crates[c] -= left
			if crates[c] <= 0:
				crates.erase(c)
	return hits


static func _knock(boxes: Dictionary, c: Vector2i) -> void:
	boxes[c] -= 1
	if boxes[c] <= 0:
		boxes.erase(c)


## "Clear N arrows of colour X": the colour with the most BURIED arrows (not free at the
## start), and most of that colour's free arrows get another colour - so the order is
## earned by digging in and crushing, not by tapping the arrows on the edge.
static func _color_order(colors: Array, arrows: Array, mirrors: Dictionary, cols: int, rows: int,
		rng: RandomNumberGenerator, keep: Dictionary = {}) -> Dictionary:
	var round_of := _rounds(arrows, cols, rows, mirrors)
	var counts := {}
	var buried := {}
	for i in colors.size():
		var c: int = colors[i]
		if c == GOLD:
			continue
		counts[c] = counts.get(c, 0) + 1
		if round_of[i] > 0:
			buried[c] = buried.get(c, 0) + 1
	var best := -1
	for c: int in counts:
		if best < 0 or buried.get(c, 0) > buried.get(best, 0) 				or (buried.get(c, 0) == buried.get(best, 0) and counts[c] > counts[best]):
			best = c
	if best < 0:
		return {}
	# Free-at-start arrows of that colour: keep one as an easy first step, recolour the rest -
	# never to the colour of an arrow stuck behind it (that would hand out a new easy crush).
	var owner := {}
	for i in arrows.size():
		for c: Vector2i in arrows[i]:
			owner[c] = i
	var behind := {}  # arrow index -> colours of the arrows whose lane it blocks first
	for i in arrows.size():
		var a: Array = arrows[i]
		for c: Vector2i in trace(a[-1], a[-1] - a[-2], mirrors, cols, rows).cells:
			if owner.has(c) and owner[c] != i:
				if not behind.has(owner[c]):
					behind[owner[c]] = {}
				behind[owner[c]][colors[i]] = true
				break
	var kept := 0
	for i in colors.size():
		if colors[i] != best or round_of[i] > 0:
			continue
		if keep.has(i):
			continue  # part of a planted chain or prism: its colour is the point
		if kept < 1:
			kept += 1
			continue
		var others: Array[int] = []
		for c: int in counts:
			if c != best and not (behind.get(i, {}) as Dictionary).has(c):
				others.append(c)
		if others.is_empty():
			continue
		colors[i] = others[rng.randi_range(0, others.size() - 1)]
		counts[best] -= 1
	var total: int = counts[best]
	return {"color": best, "count": clampi(roundi(total * 0.6), mini(4, total), total)}


# --- Lanes, mirrors, balloons, targets ------------------------------------------------------

## Mirror "/" (kind 0) or "\" (kind 1) turns a moving arrow by 90 degrees.
static func reflect(d: Vector2i, kind: int) -> Vector2i:
	return Vector2i(-d.y, -d.x) if kind == 0 else Vector2i(d.y, d.x)


## The lane in front of a head moving `d`, bent by mirrors, up to the board edge.
## {cells: lane cells, dirs: direction leaving each cell, exit: first cell outside the
##  board, exit_dir: direction it leaves in}. Mirror cells are part of the lane.
static func trace(head: Vector2i, d: Vector2i, mirrors: Dictionary, cols: int, rows: int) -> Dictionary:
	var cells: Array[Vector2i] = []
	var dirs: Array[Vector2i] = []
	var c := head + d
	var guard := 4 * cols * rows + 8  # a ray can only loop back through its own head
	while _inside(c, cols, rows) and guard > 0:
		if mirrors.has(c):
			d = reflect(d, mirrors[c])
		cells.append(c)
		dirs.append(d)
		c += d
		guard -= 1
	return {"cells": cells, "dirs": dirs, "exit": c, "exit_dir": d}


## Frees `n` well-spread cells for mirrors by trimming the tail off long arrows.
static func _carve_mirrors(arrows: Array, n: int, rng: RandomNumberGenerator) -> Dictionary:
	var mirrors := {}
	if n <= 0:
		return mirrors
	var order: Array = range(arrows.size())
	_shuffle(order, rng)
	for i: int in order:
		if mirrors.size() >= n:
			break
		var arrow: Array = arrows[i]
		if arrow.size() < 3:
			continue
		var cell: Vector2i = arrow[0]
		var crowded := false
		for m: Vector2i in mirrors:
			if absi(m.x - cell.x) + absi(m.y - cell.y) < 3:
				crowded = true
		if crowded:
			continue
		arrow.remove_at(0)
		mirrors[cell] = rng.randi_range(0, 1)
	return mirrors


## Carves `n` short arrows out of the maze and puts balloons in their cells. A balloon
## pops one layer whenever a neighbouring arrow is removed, so it gets at most as many
## layers as it has neighbouring arrows: every balloon is sure to pop by the end.
static func _carve_balloons(arrows: Array, n: int, max_layers: int, mirrors: Dictionary,
		rng: RandomNumberGenerator) -> Dictionary:
	var balloons := {}
	if n <= 0:
		return balloons
	var order: Array = range(arrows.size())
	_shuffle(order, rng)
	var picked: Array[int] = []
	for i: int in order:
		if picked.size() >= n:
			break
		var arrow: Array = arrows[i]
		if arrow.size() > 4:
			continue
		var far := true
		for j in picked:
			var a: Vector2i = arrows[j][-1]
			var b: Vector2i = arrow[-1]
			if absi(a.x - b.x) + absi(a.y - b.y) < 4:
				far = false
		if far:
			picked.append(i)
	var free_cells: Array[Vector2i] = []
	picked.sort()
	picked.reverse()
	for i in picked:
		for c: Vector2i in arrows[i]:
			free_cells.append(c)
		arrows.remove_at(i)
	var owner := {}
	for i in arrows.size():
		for c: Vector2i in arrows[i]:
			owner[c] = i
	for c in free_cells:
		if mirrors.has(c):
			continue
		var near := {}
		for dir: Vector2i in DIRS:
			if owner.has(c + dir):
				near[owner[c + dir]] = true
		var layers := mini(rng.randi_range(1, maxi(1, max_layers)), near.size())
		if layers > 0:
			balloons[c] = layers
	return balloons


## Where a lane leaves the shape: the cell right after the last shape cell it crosses
## (an empty cell beside the outline, or the first cell past the board edge).
static func shape_exit(lane: Array, exit: Vector2i, mask: Dictionary) -> Vector2i:
	for i in range(lane.size() - 1, -1, -1):
		if mask.has(lane[i]):
			return lane[i + 1] if i + 1 < lane.size() else exit
	return lane[0] if not lane.is_empty() else exit


## Up to `n` targets just outside the shape where arrows fly out. An escaping arrow hits
## every target its lane passes, so exits that two or more lanes cross come first (one
## mistake doesn't lose the level). Returns {cell: true}.
static func _pick_targets(arrows: Array, mirrors: Dictionary, mask: Dictionary, cols: int, rows: int,
		n: int, rng: RandomNumberGenerator) -> Dictionary:
	var targets := {}
	if n <= 0:
		return targets
	var exits := {}
	var lanes: Array = []
	for arrow: Array in arrows:
		var t := trace(arrow[-1], arrow[-1] - arrow[-2], mirrors, cols, rows)
		var path: Array = t.cells.duplicate()
		path.append(t.exit)
		lanes.append(path)
		exits[shape_exit(t.cells, t.exit, mask)] = true
	var uses := {}
	for e: Vector2i in exits:
		uses[e] = 0
		for path: Array in lanes:
			if path.has(e):
				uses[e] += 1
	var order: Array = exits.keys()
	_shuffle(order, rng)
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return mini(uses[a], 2) > mini(uses[b], 2))
	for e: Vector2i in order:
		if targets.size() >= n:
			break
		var near := false
		for t: Vector2i in targets:
			if absi(t.x - e.x) + absi(t.y - e.y) < 3:
				near = true
		if not near:
			targets[e] = true
	return targets

## Arrow colours - crushing is the heart of Arrow Crush, so the board is seeded with
## crush pairs on purpose, while a wrong guess still costs a heart:
##  - only 3-4 colours, so same-colour meetings are common;
##  - `force_chance` of blocked arrows get the SAME colour as the arrow in their way
##    (a crush waiting to be found);
##  - `avoid_chance` deliberately get a different colour (a trap: tapping it bumps);
##  - the rest are random.
## Easy boards: about half of the blocked arrows can crush. Hard boards: about a
## quarter - you have to spot them among 100 arrows, and guessing usually costs a heart.
## Labyrinth boards (`harden`): up to 6 colours and crushes are rare, hidden finds.
static func _assign_colors(arrows: Array, cols: int, rows: int, d: float, level: int, mirrors: Dictionary = {},
		harden: float = 0.0) -> Array[int]:
	var n_colors := 3 if d < 0.4 else 4
	# Crushing is the goal of every level, so plenty of arrows get a same-colour arrow
	# right in their way (a crush pair).
	var force_chance := lerpf(0.5, 0.3, d)
	var avoid_chance := lerpf(0.15, 0.4, d)
	# Labyrinth levels: crushes are rarer finds. More colours, fewer crush pairs, and most
	# other blocked arrows are a different colour (tapping it bumps).
	if harden > 0.0:
		n_colors += roundi(2.0 * harden)
		force_chance = lerpf(force_chance, 0.14, harden)
		avoid_chance = lerpf(avoid_chance, 1.0, harden)
	var rng := RandomNumberGenerator.new()
	rng.seed = level * 7717 + 3

	var owner := {}
	for i in arrows.size():
		for c: Vector2i in arrows[i]:
			owner[c] = i
	# First arrow in front of each head (-1 = free lane), and who blocks whom.
	var blocker: Array[int] = []
	var blocked_by_me: Array = []
	for i in arrows.size():
		blocked_by_me.append([])
	for i in arrows.size():
		var arrow: Array = arrows[i]
		var hit := -1
		for c: Vector2i in trace(arrow[-1], arrow[-1] - arrow[-2], mirrors, cols, rows).cells:
			if owner.has(c) and owner[c] != i:
				hit = owner[c]
				break
		blocker.append(hit)
		if hit >= 0:
			blocked_by_me[hit].append(i)
	# Labyrinth levels look past the first arrow: every arrow in my lane (and every arrow
	# with me in its lane) may become the one in the way later, once the others are gone.
	var lane_mates: Array = []
	if harden > 0.0:
		for i in arrows.size():
			lane_mates.append({})
		for i in arrows.size():
			var arrow: Array = arrows[i]
			for c: Vector2i in trace(arrow[-1], arrow[-1] - arrow[-2], mirrors, cols, rows).cells:
				if owner.has(c) and owner[c] != i:
					lane_mates[i][owner[c]] = true
					lane_mates[owner[c]][i] = true

	var colors: Array[int] = []
	colors.resize(arrows.size())
	colors.fill(-1)
	var paired := {}  # arrows given a crush pair on purpose
	for i in arrows.size():
		if colors[i] >= 0:
			continue  # already given a colour as somebody's crush partner
		var roll := rng.randf()
		var b := blocker[i]
		if b >= 0 and roll < force_chance:
			# Crush pair: same colour as the arrow in the way.
			if colors[b] < 0:
				colors[b] = rng.randi_range(0, n_colors - 1)
			colors[i] = colors[b]
			paired[i] = true
			continue
		if harden > 0.0 and rng.randf() < harden:
			# The colour shared with the fewest lane mates (the first blocker counts triple).
			var clash: Array[float] = []
			clash.resize(n_colors)
			clash.fill(0.0)
			for j: int in lane_mates[i]:
				if colors[j] >= 0 and colors[j] < n_colors:
					clash[colors[j]] += 3.0 if (j == b or blocker[j] == i) else 1.0
			var pick := 0
			var low := INF
			for k in n_colors:
				var v := clash[k] + rng.randf() * 0.5
				if v < low:
					low = v
					pick = k
			colors[i] = pick
			continue
		var allowed: Array[int] = []
		for k in n_colors:
			allowed.append(k)
		if roll < force_chance + avoid_chance:
			var neighbours: Array = blocked_by_me[i].duplicate()
			if blocker[i] >= 0:
				neighbours.append(blocker[i])
			for j: int in neighbours:
				if colors[j] >= 0:
					allowed.erase(colors[j])
		if allowed.is_empty():
			colors[i] = rng.randi_range(0, n_colors - 1)
		else:
			colors[i] = allowed[rng.randi_range(0, allowed.size() - 1)]
	if harden > 0.0:
		# Clean-up: an accidental crush pair (not one of the planned ones) gets a colour
		# that matches neither the arrow in its way nor the arrows it is in the way of.
		for pass_i in 2:
			for i in arrows.size():
				var b := blocker[i]
				if b < 0 or paired.has(i) or colors[i] != colors[b] or rng.randf() > harden:
					continue
				var used := {colors[b]: true}
				for j: int in blocked_by_me[i]:
					used[colors[j]] = true
				for k in n_colors:
					if not used.has(k):
						colors[i] = k
						break
	return colors


# --- Chain touches ------------------------------------------------------------------------------

## The first arrow in front of each arrow's head on the full board (-1 free, -2 own body).
static func _first_hits(arrows: Array, cols: int, rows: int, mirrors: Dictionary) -> Array[int]:
	var occ := {}
	for i in arrows.size():
		for c: Vector2i in arrows[i]:
			occ[c] = i
	var hits: Array[int] = []
	for i in arrows.size():
		hits.append(_first_hit(i, arrows, occ, cols, rows, {}, mirrors))
	return hits


## Jackpot lines: up to `n` runs of arrows that each point into the next (A -> B -> C ...),
## all given one colour. Tapping the first one crushes the whole line in a single domino
## chain - the big "found it!" moment. Lines never share arrows. Returns the lines.
static func _plant_jackpots(arrows: Array, colors: Array, n: int, max_len: int, busy: Dictionary,
		mirrors: Dictionary, cols: int, rows: int, rng: RandomNumberGenerator) -> Array:
	var planted: Array = []
	if n <= 0:
		return planted
	var hits := _first_hits(arrows, cols, rows, mirrors)
	var lines: Array = []
	for i in arrows.size():
		if busy.has(i):
			continue
		var line := [i]
		var seen := {i: true}
		var cur := i
		while line.size() < max_len:
			var nxt := hits[cur]
			if nxt < 0 or seen.has(nxt) or busy.has(nxt):
				break
			line.append(nxt)
			seen[nxt] = true
			cur = nxt
		if line.size() >= 3:
			lines.append(line)
	_shuffle(lines, rng)
	lines.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
	var used := {}
	var palette := _palette_of(colors)
	for line: Array in lines:
		if planted.size() >= n:
			break
		var clash := false
		for i: int in line:
			if used.has(i):
				clash = true
				break
		if clash:
			continue
		# Not the colour of the arrow right after the line, so the chain ends where planned.
		var after := hits[line[-1]]
		var pick: int = colors[line[0]]
		if after >= 0 and colors[after] == pick and palette.size() > 1:
			pick = palette[(palette.find(pick) + 1) % palette.size()]
		for i: int in line:
			colors[i] = pick
			used[i] = true
		planted.append(line)
	return planted


## Prism arrows: an arrow P with an arrow A pointing into it and an arrow B in front of it.
## A gets another colour than P, B gets P's colour - so tapping A crushes the prism and the
## chain switches colour and carries on into B. Returns the prism arrows' indices.
static func _plant_prisms(arrows: Array, colors: Array, n: int, busy: Dictionary,
		mirrors: Dictionary, cols: int, rows: int, rng: RandomNumberGenerator) -> Array[int]:
	var prisms: Array[int] = []
	var palette := _palette_of(colors)
	if n <= 0 or palette.size() < 2:
		return prisms
	var hits := _first_hits(arrows, cols, rows, mirrors)
	var feeders := {}  # arrow -> arrows whose first hit it is
	for i in arrows.size():
		if hits[i] >= 0:
			if not feeders.has(hits[i]):
				feeders[hits[i]] = []
			feeders[hits[i]].append(i)
	var order: Array = range(arrows.size())
	_shuffle(order, rng)
	var used := {}
	for p: int in order:
		if prisms.size() >= n:
			break
		var b := hits[p]
		if busy.has(p) or used.has(p) or b < 0 or busy.has(b) or used.has(b) or not feeders.has(p):
			continue
		var a := -1
		for f: int in feeders[p]:
			if f != b and not busy.has(f) and not used.has(f):
				a = f
				break
		if a < 0:
			continue
		colors[b] = colors[p]
		if colors[a] == colors[p]:
			var step := 1 + rng.randi_range(0, palette.size() - 2)
			colors[a] = palette[(palette.find(colors[p]) + step) % palette.size()]
		for i: int in [a, p, b]:
			used[i] = true
		prisms.append(p)
	return prisms


## The normal colours used on this board (never gold).
static func _palette_of(colors: Array) -> Array[int]:
	var out: Array[int] = []
	for c: int in colors:
		if c != GOLD and not out.has(c):
			out.append(c)
	out.sort()
	return out


# --- Maze construction ---------------------------------------------------------------------

## Covers the shape with random snake-like arrows (tail -> head, random orientation).
## Walks hug cells with few free neighbours so almost no single holes are left.
## `wind` (0..1) is the share of arrows that are wavy snakes: they turn every 1-2 cells,
## either swinging left-right (a wave / staircase) or always the same way (a hook, U-turn
## or spiral that curls around its neighbours), and they are longer than the rest.
static func _tile(mask: Dictionary, len_range: Vector2i, rng: RandomNumberGenerator, wind: float = 0.0,
		pre: Array = []) -> Array:
	var owner := {}  # cell -> arrow index (-1 = permanent gap)
	var arrows: Array = []
	# Arrows already laid (the outline rings, see _contour_arrows) stay as they are.
	for walk: Array in pre:
		for c: Vector2i in walk:
			owner[c] = arrows.size()
		arrows.append(walk)
	while true:
		var start := _pick_start(mask, owner, rng)
		if start.x < 0:
			break
		var walk: Array[Vector2i] = [start]
		# Mostly short-to-medium arrows with the odd long, winding one (like real mazes).
		var want := len_range.x + roundi(pow(rng.randf(), 2.6) * (len_range.y - len_range.x))
		var heading := Vector2i.ZERO
		var straight_bias := rng.randf_range(0.3, 1.6)  # long straight runs + spirals, not zigzags
		var wavy := rng.randf() < wind
		var swing := rng.randf() < 0.6        # wavy: alternate turn sides (wave) or keep one (curl)
		var run_len := 1 + int(rng.randf() < 0.35)  # wavy: cells between turns
		var run := 0
		var last_side := 0
		if wavy:
			want = maxi(want, mini(len_range.y + 3, len_range.x + 4 + rng.randi_range(0, 4)))
		while walk.size() < want:
			var best := Vector2i.ZERO
			var best_score := -INF
			for d: Vector2i in DIRS:
				var nxt := walk[-1] + d
				if not mask.has(nxt) or owner.has(nxt) or walk.has(nxt):
					continue
				var score := -_free_neighbours(nxt, mask, owner, walk) * 0.7 + rng.randf()
				if wavy and heading != Vector2i.ZERO:
					if d == heading:
						score += 1.6 if run < run_len else -1.6
					else:
						var side := heading.x * d.y - heading.y * d.x
						if last_side == 0 or side == (-last_side if swing else last_side):
							score += 1.6
				elif d == heading:
					score += straight_bias
				if score > best_score:
					best_score = score
					best = d
			if best == Vector2i.ZERO:
				break
			walk.append(walk[-1] + best)
			if heading != Vector2i.ZERO and best != heading:
				last_side = heading.x * best.y - heading.y * best.x
				run = 0
			run += 1
			heading = best

		if walk.size() >= 2:
			if rng.randf() < 0.5:
				walk.reverse()
			for c in walk:
				owner[c] = arrows.size()
			arrows.append(walk)
			continue
		# Lonely cell: glue it onto the end of a neighbouring arrow, or leave a gap.
		owner[start] = -1
		for d: Vector2i in DIRS:
			var nb := start + d
			if owner.get(nb, -1) < 0 or arrows[owner[nb]].size() > len_range.y:
				continue
			var arrow: Array[Vector2i] = arrows[owner[nb]]
			if arrow[0] == nb:
				arrow.insert(0, start)
			elif arrow[-1] == nb:
				arrow.append(start)
			else:
				continue
			owner[start] = owner[nb]
			break
	return arrows


## Outline arrows: long arrows laid end to end along the shape's edge (and one ring further
## in on big boards), all running the same way round - so the picture is drawn by the
## arrows themselves, like a lion's mane or a butterfly's wing edge.
static func _contour_arrows(mask: Dictionary, rings: int, seg: Vector2i, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var inner := mask.duplicate()
	for r in rings:
		var ring := {}
		for c: Vector2i in inner:
			for d: Vector2i in DIRS:
				if not inner.has(c + d):
					ring[c] = true
					break
		if ring.size() < 8:
			break
		for chain: Array in _ring_chains(ring):
			var i := 0
			while i < chain.size():
				var want := rng.randi_range(seg.x, seg.y)
				var piece: Array[Vector2i] = []
				for k in range(i, mini(i + want, chain.size())):
					piece.append(chain[k])
				i += want
				if piece.size() >= 2:
					out.append(piece)
				elif not out.is_empty() and out[-1].size() < seg.y + 2 and (out[-1][-1] - piece[0]).length_squared() == 1:
					out[-1].append(piece[0])  # a one-cell end joins the arrow before it
		for c: Vector2i in ring:
			inner.erase(c)
	return out


## Orders ring cells into walks that follow the edge (wall-following, outside kept on the
## left), starting at the top-left. A ring may break into a few walks at narrow necks.
static func _ring_chains(ring: Dictionary) -> Array:
	var left := ring.duplicate()
	var chains: Array = []
	while not left.is_empty():
		var start: Vector2i = left.keys()[0]
		for c: Vector2i in left:
			if c.y < start.y or (c.y == start.y and c.x < start.x):
				start = c
		var chain: Array[Vector2i] = [start]
		left.erase(start)
		var heading := Vector2i.RIGHT
		while true:
			var moved := false
			for d: Vector2i in [Vector2i(heading.y, -heading.x), heading, Vector2i(-heading.y, heading.x)]:
				var nxt: Vector2i = chain[-1] + d
				if left.has(nxt):
					chain.append(nxt)
					left.erase(nxt)
					heading = d
					moved = true
					break
			if not moved:
				break
		chains.append(chain)
	return chains


static func _pick_start(mask: Dictionary, owner: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score := INF
	for c: Vector2i in mask:
		if owner.has(c):
			continue
		var score := _free_neighbours(c, mask, owner, []) + rng.randf() * 0.5
		if score < best_score:
			best_score = score
			best = c
	return best


static func _free_neighbours(c: Vector2i, mask: Dictionary, owner: Dictionary, walk: Array) -> int:
	var n := 0
	for d: Vector2i in DIRS:
		var nb := c + d
		if mask.has(nb) and not owner.has(nb) and not walk.has(nb):
			n += 1
	return n


## Plays the maze greedily. Whenever every remaining arrow is stuck (a deadlock),
## flip one stuck arrow end-for-end so it can leave; if no flip helps, drop the
## shortest stuck arrow. Arrows already removed stay valid, so the result is solvable.
static func _make_solvable(arrows: Array, cols: int, rows: int, rng: RandomNumberGenerator, mirrors: Dictionary = {}) -> void:
	var occupancy := {}
	for i in arrows.size():
		for c: Vector2i in arrows[i]:
			occupancy[c] = i
	var remaining: Array[int] = []
	for i in arrows.size():
		remaining.append(i)
	var dropped: Array[int] = []

	while not remaining.is_empty():
		var progressed := false
		for i in remaining.duplicate():
			if _lane_clear(arrows[i], occupancy, cols, rows, mirrors):
				remaining.erase(i)
				for c: Vector2i in arrows[i]:
					occupancy.erase(c)
				progressed = true
		if progressed:
			continue

		var order := remaining.duplicate()
		_shuffle(order, rng)
		var fixed := false
		for i: int in order:
			arrows[i].reverse()
			if _lane_clear(arrows[i], occupancy, cols, rows, mirrors):
				fixed = true
				break
			arrows[i].reverse()
		if fixed:
			continue

		var victim: int = order[0]
		for i: int in order:
			if arrows[i].size() < arrows[victim].size():
				victim = i
		remaining.erase(victim)
		for c: Vector2i in arrows[victim]:
			occupancy.erase(c)
		dropped.append(victim)

	dropped.sort()
	dropped.reverse()
	for i in dropped:
		arrows.remove_at(i)

## free_at_start = arrows that can leave immediately; depth = rounds needed if every
## free arrow is removed each round (longer = deeper dependency chains).
static func _analyse(arrows: Array, cols: int, rows: int, mirrors: Dictionary = {}) -> Dictionary:
	var occupancy := {}
	for i in arrows.size():
		for c: Vector2i in arrows[i]:
			occupancy[c] = i
	var remaining := {}
	for i in arrows.size():
		remaining[i] = true
	var free_at_start := -1
	var depth := 0
	while not remaining.is_empty():
		var free: Array[int] = []
		for i: int in remaining:
			if _lane_clear(arrows[i], occupancy, cols, rows, mirrors):
				free.append(i)
		if free.is_empty():
			break
		if free_at_start < 0:
			free_at_start = free.size()
		for i in free:
			remaining.erase(i)
			for c: Vector2i in arrows[i]:
				occupancy.erase(c)
		depth += 1
	return {"free_at_start": maxi(free_at_start, 0), "depth": depth}


static func _lane_clear(arrow: Array, occupancy: Dictionary, cols: int, rows: int, mirrors: Dictionary = {}) -> bool:
	for c: Vector2i in trace(arrow[-1], arrow[-1] - arrow[-2], mirrors, cols, rows).cells:
		if occupancy.has(c):
			return false
	return true


# --- Board shapes --------------------------------------------------------------------------

## The level's own outline (see ShapeFactory), rasterised onto the board grid.
static func _make_mask(recipe: Dictionary, cols: int, rows: int) -> Dictionary:
	var mask := {}
	for y in rows:
		for x in cols:
			var u := (x + 0.5) / cols * 2.0 - 1.0
			var v := (y + 0.5) / rows * 2.0 - 1.0
			if ShapeFactory.inside(recipe, u, v):
				mask[Vector2i(x, y)] = true
	# Clean pixel edges: trim one-cell spikes and fill one-cell pinholes.
	for pass_i in 2:
		var trim: Array[Vector2i] = []
		for c: Vector2i in mask:
			if _mask_neighbours(mask, c) <= 1:
				trim.append(c)
		for c in trim:
			mask.erase(c)
		for y in rows:
			for x in cols:
				var c := Vector2i(x, y)
				if not mask.has(c) and _mask_neighbours(mask, c) >= 3:
					mask[c] = true
	# On small boards a thin neck can split the outline: drop tiny crumbs.
	var keep := {}
	var seen := {}
	for start: Vector2i in mask:
		if seen.has(start):
			continue
		var piece: Array[Vector2i] = [start]
		seen[start] = true
		var i := 0
		while i < piece.size():
			for dir: Vector2i in DIRS:
				var nb := piece[i] + dir
				if mask.has(nb) and not seen.has(nb):
					seen[nb] = true
					piece.append(nb)
			i += 1
		if piece.size() >= maxi(6, mask.size() / 12):
			for c in piece:
				keep[c] = true
	return keep


# --- Level goals (moves / clock) ------------------------------------------------------------

enum Goal { FREE, MOVES, TIME, BOTH }

## What limits a level, so the challenge changes from level to level:
## 1-10 learn (moves from 3, clock at 7 and 10). 11-20 mix moves / clock / both. From 21
## the clock is always running - moves AND clock on most levels, pure clock rushes on the
## rest - so the player can never just sit and study the board.
static func goal_for(level: int) -> Goal:
	if level <= 10:
		return {3: Goal.MOVES, 5: Goal.MOVES, 6: Goal.MOVES, 7: Goal.TIME, 8: Goal.MOVES,
			9: Goal.MOVES, 10: Goal.TIME}.get(level, Goal.FREE)
	if level <= 20:
		const LEARN: Array[Goal] = [Goal.BOTH, Goal.MOVES, Goal.TIME, Goal.BOTH, Goal.MOVES,
			Goal.TIME, Goal.MOVES, Goal.BOTH, Goal.TIME, Goal.MOVES]
		return LEARN[level % 10]
	const CYCLE: Array[Goal] = [Goal.BOTH, Goal.BOTH, Goal.TIME, Goal.BOTH, Goal.BOTH,
		Goal.TIME, Goal.BOTH, Goal.BOTH, Goal.BOTH, Goal.TIME]
	return CYCLE[level % 10]


## How many taps it takes to clear the maze if you always pick the tap that removes the
## most arrows (escapes, same-colour crushes and their domino chains, no mistakes).
## Removing arrows only ever frees lanes, so this always finishes. The real player can
## beat it with special arrows and smarter crush order, so it is a fair move limit base.
static func estimate_taps(arrows: Array, colors: Array, cols: int, rows: int, mirrors: Dictionary = {},
		prisms: Array = []) -> int:
	var prism := {}
	for i: int in prisms:
		prism[i] = true
	var occ := {}
	for i in arrows.size():
		for c: Vector2i in arrows[i]:
			occ[c] = i
	var alive := {}
	for i in arrows.size():
		alive[i] = true
	var taps := 0
	while not alive.is_empty():
		var best: Array = []
		for i: int in alive:
			var removed := _tap_result(i, arrows, colors, occ, cols, rows, mirrors, prism)
			if removed.size() > best.size():
				best = removed
		if best.is_empty():
			break  # cannot happen on a solvable maze
		taps += 1
		for j: int in best:
			alive.erase(j)
			for c: Vector2i in arrows[j]:
				occ.erase(c)
	return taps


## Colours for the crush estimate: linked arrows never crush (they only fly out together)
## and frozen ones are left out too, so the crush goal never counts on them.
static func _crush_colors(colors: Array, links: Array, ice: Dictionary) -> Array:
	var out := colors.duplicate()
	for pair: Array in links:
		for i: int in pair:
			out[i] = 1000 + i
	for i: int in ice:
		out[i] = 1000 + i
	return out


## How many arrows a careful player can crush on this board: always take the biggest
## crush on offer; when there is none, fly out the free arrow whose leaving opens the most
## new crushes. Ignores creep, magnet and special arrows (they only add crushes), so it
## is a safe base for the level's crush goal.
static func estimate_crushes(arrows: Array, colors: Array, cols: int, rows: int, mirrors: Dictionary = {},
		prisms: Array = []) -> int:
	var prism := {}
	for i: int in prisms:
		prism[i] = true
	var occ := {}
	for i in arrows.size():
		for c: Vector2i in arrows[i]:
			occ[c] = i
	var alive := {}
	for i in arrows.size():
		alive[i] = true
	var crushed := 0
	while not alive.is_empty():
		var best: Array = []
		var free: Array[int] = []
		var hits := {}  # arrow -> first arrow in its way
		for i: int in alive:
			var removed := _tap_result(i, arrows, colors, occ, cols, rows, mirrors, prism)
			if removed.size() >= 2 and removed.size() > best.size():
				best = removed
			elif removed.size() == 1:
				free.append(i)
			if removed.size() != 1:
				hits[i] = _first_hit(i, arrows, occ, cols, rows, {}, mirrors)
		if best.is_empty():
			if free.is_empty():
				break  # cannot happen on a solvable maze
			# No crush right now: fly out the arrow that unblocks the most same-colour pairs.
			var pick := free[0]
			var most := -1
			for f: int in free:
				var opens := 0
				for j: int in hits:
					if hits[j] != f:
						continue
					var nxt := _first_hit(j, arrows, occ, cols, rows, {f: true}, mirrors)
					if nxt >= 0 and _crushes(colors, prism, j, nxt):
						opens += 1
				if opens > most:
					most = opens
					pick = f
			best = [pick]
		else:
			crushed += best.size()
		for j: int in best:
			alive.erase(j)
			for c: Vector2i in arrows[j]:
				occ.erase(c)
	return crushed


## Arrows removed by tapping arrow `i` (empty = it would bump).
static func _tap_result(i: int, arrows: Array, colors: Array, occ: Dictionary, cols: int, rows: int, mirrors: Dictionary,
		prism: Dictionary = {}) -> Array:
	var hit := _first_hit(i, arrows, occ, cols, rows, {}, mirrors)  # own body still blocks the tapped arrow
	if hit == -1:
		return [i]
	if hit == -2 or not _crushes(colors, prism, i, hit):
		return []
	var removed := [i, hit]
	var gone := {i: true, hit: true}
	var cur := hit
	while true:  # domino: the crushed arrow passes the hit on to the same colour
		var nxt := _first_hit(cur, arrows, occ, cols, rows, gone, mirrors)
		if nxt < 0 or not _crushes(colors, prism, cur, nxt):
			break
		removed.append(nxt)
		gone[nxt] = true
		cur = nxt
	return removed


## Arrow `a` hitting arrow `b` crushes it: same colour, or `b` is a prism (never golden).
static func _crushes(colors: Array, prism: Dictionary, a: int, b: int) -> bool:
	if colors[a] == GOLD or colors[b] == GOLD:
		return false
	return colors[a] == colors[b] or prism.has(b)


## First arrow in front of arrow `i`'s head, ignoring arrows in `gone`.
## -1 = clear lane, -2 = blocked by its own body.
static func _first_hit(i: int, arrows: Array, occ: Dictionary, cols: int, rows: int, gone: Dictionary,
		mirrors: Dictionary) -> int:
	var arrow: Array = arrows[i]
	for c: Vector2i in trace(arrow[-1], arrow[-1] - arrow[-2], mirrors, cols, rows).cells:
		if occ.has(c):
			var o: int = occ[c]
			if not gone.has(o):
				return -2 if o == i else o
	return -1


static func _mask_neighbours(mask: Dictionary, c: Vector2i) -> int:
	var n := 0
	for dir: Vector2i in DIRS:
		if mask.has(c + dir):
			n += 1
	return n


static func _inside(c: Vector2i, cols: int, rows: int) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
