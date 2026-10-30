class_name ShapeFactory
extends RefCounted
## Invents a brand-new board outline for every level.
##
## Nothing comes from a fixed list: each outline is a random "recipe" of primitives
## (ellipses, rounded boxes, polygons, stars, flowers, wobbly blobs, hearts, crosses,
## mirrored silhouettes), combined (pairs, stacks, clovers, ears, bars) and with holes
## cut into it. Later levels get more complex recipes.
##
## No repeats: every new outline is rasterised to a small signature and compared with
## the outline of every earlier level (and with its mirror image). If it overlaps one
## of them too much, it is thrown away and a new one is invented.
##
## Deterministic: level N always gets the same outline on every phone, because the
## outlines are built in order from fixed seeds (and cached for the session).

const CHAIN_LEVELS := 300      # levels that are checked against each other
const SIG_W := 16
const SIG_H := 19
const MAX_OVERLAP := 0.78      # IoU above this = "same shape as an earlier level"
const TRIES := 60
const BOARD_ASPECT := 1.2      # rows / cols of a board (cells are square on screen)

static var _chain: Array[Dictionary] = []   # recipe per level (index = level - 1)
static var _sigs: Array[PackedByteArray] = []
static var _lock := Mutex.new()


## The outline recipe for a level. Levels beyond CHAIN_LEVELS (daily challenges) get a
## complex random outline from their own seed, without the no-repeat check.
static func recipe_for(level: int) -> Dictionary:
	if level < 1 or level > CHAIN_LEVELS:
		var rng := RandomNumberGenerator.new()
		rng.seed = level * 48271 + 101
		for t in TRIES:
			var r := _random_recipe(rng, 0.85)
			if not _signature(r).is_empty():
				return r
		return _fallback()
	# GameData warms the chain up on a background thread; build one level per lock so
	# a level that is already done never waits for the rest.
	while true:
		_lock.lock()
		if _chain.size() >= level:
			var r := _chain[level - 1]
			_lock.unlock()
			return r
		_extend_chain()
		_lock.unlock()
	return {}


## True if board point (u, v) - both in [-1, 1], v down - is inside the outline.
static func inside(r: Dictionary, u: float, v: float) -> bool:
	var f: Vector4 = r.fit
	return _inside_raw(r, Vector2(f.x + u * f.z, f.y + v * f.w), true)


# --- No-repeat chain -----------------------------------------------------------------------

static func _extend_chain() -> void:
	var level := _chain.size() + 1
	# Picture levels (heart, apple, fish...) come from PictureShapes.
	var pic := PictureShapes.recipe_for(level)
	if not pic.is_empty():
		pic.fit = _fit(pic)
		_chain.append(pic)
		_sigs.append(_raster(pic))
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = level * 92821 + 17
	# Simple single shapes first, then combos, silhouettes and holes.
	var complexity := clampf((level - 1) / 70.0, 0.0, 1.0)
	var best := {}
	var best_sig := PackedByteArray()
	var best_overlap := INF
	for t in TRIES:
		var r := _random_recipe(rng, complexity)
		var sig := _signature(r)
		if sig.is_empty():
			continue
		var overlap := _max_overlap(sig)
		if overlap < best_overlap:
			best_overlap = overlap
			best = r
			best_sig = sig
		if overlap <= MAX_OVERLAP:
			break
	if best.is_empty():
		best = _fallback()
		best_sig = _signature(best)
	_chain.append(best)
	_sigs.append(best_sig)


static func _max_overlap(sig: PackedByteArray) -> float:
	var flipped := _mirror_sig(sig)
	var worst := 0.0
	for other in _sigs:
		worst = maxf(worst, maxf(_iou(sig, other), _iou(flipped, other)))
	return worst


static func _iou(a: PackedByteArray, b: PackedByteArray) -> float:
	var both := 0
	var either := 0
	for i in a.size():
		if a[i] or b[i]:
			either += 1
			if a[i] and b[i]:
				both += 1
	return float(both) / maxf(1.0, either)


static func _mirror_sig(sig: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(sig.size())
	for y in SIG_H:
		for x in SIG_W:
			out[y * SIG_W + x] = sig[y * SIG_W + (SIG_W - 1 - x)]
	return out


## Small raster of the outline, or empty if the outline would make a bad board
## (too empty, too full, split into pieces, or full of one-cell-wide strings).
static func _signature(r: Dictionary) -> PackedByteArray:
	var sig := _raster(r)
	var filled := 0
	for b in sig:
		filled += b
	var fill := float(filled) / sig.size()
	if fill < 0.32 or fill > 0.93:
		return PackedByteArray()
	# Thin strings: cells with at most one filled neighbour.
	var thin := 0
	for y in SIG_H:
		for x in SIG_W:
			if not sig[y * SIG_W + x]:
				continue
			var n := 0
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var c := Vector2i(x, y) + d
				if c.x >= 0 and c.y >= 0 and c.x < SIG_W and c.y < SIG_H and sig[c.y * SIG_W + c.x]:
					n += 1
			if n <= 1:
				thin += 1
	if thin > filled * 0.06:
		return PackedByteArray()
	if _largest_component(sig) < filled * 0.94:
		return PackedByteArray()
	return sig


static func _raster(r: Dictionary) -> PackedByteArray:
	var sig := PackedByteArray()
	sig.resize(SIG_W * SIG_H)
	for y in SIG_H:
		for x in SIG_W:
			var u := (x + 0.5) / SIG_W * 2.0 - 1.0
			var v := (y + 0.5) / SIG_H * 2.0 - 1.0
			if inside(r, u, v):
				sig[y * SIG_W + x] = 1
	return sig


static func _largest_component(sig: PackedByteArray) -> int:
	var seen := PackedByteArray()
	seen.resize(sig.size())
	var best := 0
	for start in sig.size():
		if not sig[start] or seen[start]:
			continue
		var size := 0
		var stack: Array[int] = [start]
		seen[start] = 1
		while not stack.is_empty():
			var i: int = stack.pop_back()
			size += 1
			var x := i % SIG_W
			@warning_ignore("integer_division")
			var y := i / SIG_W
			for nb: int in [i - 1 if x > 0 else -1, i + 1 if x < SIG_W - 1 else -1,
					i - SIG_W if y > 0 else -1, i + SIG_W if y < SIG_H - 1 else -1]:
				if nb >= 0 and sig[nb] and not seen[nb]:
					seen[nb] = 1
					stack.append(nb)
		best = maxi(best, size)
	return best


# --- Recipes -------------------------------------------------------------------------------
# A recipe: {parts: [part], holes: [part], mirror: bool, rot: float, fit: Vector4}
# A part:   {kind, pos: Vector2, size: Vector2, rot: float, + kind-specific values}

static func _random_recipe(rng: RandomNumberGenerator, c: float) -> Dictionary:
	var r := {"parts": [], "holes": [], "mirror": false, "rot": 0.0}
	var roll := rng.randf()
	if roll < lerpf(0.7, 0.2, c):
		r.parts.append(_primitive(rng, Vector2.ZERO, Vector2.ONE))
	elif roll < lerpf(0.85, 0.45, c):
		r.parts.append(_silhouette(rng))
		r.mirror = true
	else:
		_compound(rng, r)
	# Mostly mirror-symmetric: symmetric outlines look designed, not like random rocks.
	if not r.mirror:
		if rng.randf() < 0.8:
			r.mirror = true
		elif rng.randf() < 0.4:
			r.rot = rng.randf_range(-0.5, 0.5)
	r.fit = _fit(r)
	# Holes only once boards are big enough to show them as real gaps.
	if c > 0.25 and rng.randf() < c * 0.6:
		# Holes sit fully inside, so the fit (outer bounds) stays the same.
		_cut_holes(rng, r, 1 + roundi(rng.randf() * c * 2.0))
	return r


static func _part(kind: String, pos: Vector2, size: Vector2, rot: float = 0.0) -> Dictionary:
	return {"kind": kind, "pos": pos, "size": size, "rot": rot}


## One random primitive, roughly radius `size` around `pos`.
static func _primitive(rng: RandomNumberGenerator, pos: Vector2, size: Vector2) -> Dictionary:
	var stretch := Vector2(rng.randf_range(0.75, 1.3), rng.randf_range(0.75, 1.3))
	var p: Dictionary
	match rng.randi_range(0, 10):
		0:
			p = _part("circle", pos, size * stretch)
		1:
			p = _part("box", pos, size * stretch)
			p.a = rng.randf_range(0.0, 0.75)
		2:
			p = _part("ngon", pos, size, rng.randi_range(0, 1) * PI)
			p.n = rng.randi_range(3, 8)
		3:
			p = _part("poly", pos, size, rng.randi_range(0, 1) * PI)
			p.pts = _star_points(rng.randi_range(4, 9), rng.randf_range(0.42, 0.72))
		4:
			p = _part("super", pos, size * stretch)
			p.a = [0.7, 0.9, 1.0, 1.4, 3.0, 4.0][rng.randi_range(0, 5)]
		5:
			p = _part("flower", pos, size)
			p.n = rng.randi_range(3, 8)
			p.a = rng.randf_range(0.18, 0.45)
		6, 7:
			p = _part("blob", pos, size * stretch)
			var waves: Array[Vector3] = []
			for k in rng.randi_range(2, 3):
				waves.append(Vector3(rng.randf_range(0.05, 0.15), rng.randi_range(2, 6), rng.randf_range(0.0, TAU)))
			p.waves = waves
		8:
			p = _part("heart", pos, size * Vector2(rng.randf_range(0.85, 1.15), 1.0))
		9:
			p = _part("cross", pos, size * stretch, rng.randi_range(0, 1) * PI / 4.0)
			p.a = rng.randf_range(0.32, 0.55)
		_:
			p = _part("poly", pos, size)
			p.pts = _silhouette_points(rng)
	return p


## A mirrored outline drawn from random widths at random heights: vases, rockets,
## bottles, trees, lamps, crowns... never the same twice.
static func _silhouette(rng: RandomNumberGenerator) -> Dictionary:
	var p := _part("poly", Vector2.ZERO, Vector2.ONE)
	p.pts = _silhouette_points(rng)
	return p


static func _silhouette_points(rng: RandomNumberGenerator) -> PackedVector2Array:
	var ys: Array[float] = []
	for i in rng.randi_range(3, 6):
		ys.append(rng.randf_range(-0.85, 0.85))
	ys.sort()
	var right: Array[Vector2] = [Vector2(rng.randf_range(0.0, 0.7), -1.0)]
	for y in ys:
		right.append(Vector2(rng.randf_range(0.3, 1.0), y))
	right.append(Vector2(rng.randf_range(0.0, 0.8), 1.0))
	var pts := PackedVector2Array()
	for q in right:
		pts.append(q)
	for i in range(right.size() - 1, -1, -1):
		pts.append(Vector2(-right[i].x, right[i].y))
	return pts


static func _star_points(n: int, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var rad := 1.0 if i % 2 == 0 else inner
		var ang := -PI / 2.0 + i * PI / n
		pts.append(Vector2(cos(ang), sin(ang)) * rad)
	return pts


## Two or more primitives glued together.
static func _compound(rng: RandomNumberGenerator, r: Dictionary) -> void:
	match rng.randi_range(0, 4):
		0:  # mirrored pair (+ maybe a body between them)
			var s := rng.randf_range(0.55, 0.9)
			r.parts.append(_primitive(rng, Vector2(-rng.randf_range(0.45, 0.8), rng.randf_range(-0.4, 0.4)), Vector2(s, s)))
			if rng.randf() < 0.6:
				r.parts.append(_primitive(rng, Vector2(0, rng.randf_range(-0.3, 0.5)), Vector2.ONE * rng.randf_range(0.6, 0.9)))
			r.mirror = true
		1:  # stack, big at the bottom
			var n := rng.randi_range(2, 3)
			var y := 0.9
			var s := rng.randf_range(0.7, 0.9)
			for i in n:
				r.parts.append(_primitive(rng, Vector2(0, y), Vector2(s, s)))
				y -= s * rng.randf_range(1.1, 1.5)
				s *= rng.randf_range(0.65, 0.9)
		2:  # clover: petals around a core
			var n := rng.randi_range(3, 6)
			var rad := rng.randf_range(0.55, 0.85)
			var s := rng.randf_range(0.45, 0.7)
			var kind := _primitive(rng, Vector2.ZERO, Vector2(s, s))
			for i in n:
				var ang := -PI / 2.0 + i * TAU / n
				var petal := kind.duplicate()
				petal.pos = Vector2(cos(ang), sin(ang)) * rad
				petal.rot = float(kind.rot) + ang + PI / 2.0
				r.parts.append(petal)
			r.parts.append(_part("circle", Vector2.ZERO, Vector2.ONE * rad * 0.9))
		3:  # body with ears / arms
			r.parts.append(_primitive(rng, Vector2.ZERO, Vector2.ONE))
			var s := rng.randf_range(0.3, 0.5)
			var ang := rng.randf_range(-2.6, -0.5)  # anywhere on the upper-left side
			r.parts.append(_primitive(rng, Vector2(cos(ang), sin(ang)) * rng.randf_range(0.85, 1.05), Vector2(s, s)))
			r.mirror = true
		_:  # bars: T, L, H, plus, steps...
			var w := rng.randf_range(0.3, 0.5)
			var bars := rng.randi_range(2, 3)
			for i in bars:
				var b := _part("box", Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.7, 0.7)),
					Vector2(rng.randf_range(0.6, 1.1), w) if i % 2 == 0 else Vector2(w, rng.randf_range(0.6, 1.1)))
				b.a = rng.randf_range(0.0, 1.0)
				r.parts.append(b)
			r.mirror = rng.randf() < 0.5


## Cuts `count` holes that sit fully inside the shape.
static func _cut_holes(rng: RandomNumberGenerator, r: Dictionary, count: int) -> void:
	var f: Vector4 = r.fit
	for i in count:
		for attempt in 12:
			var s := rng.randf_range(0.2, 0.34) * minf(f.z, f.w / BOARD_ASPECT)
			var pos := Vector2(f.x + rng.randf_range(-0.6, 0.6) * f.z, f.y + rng.randf_range(-0.6, 0.6) * f.w)
			if r.mirror:
				pos.x = minf(pos.x, -s * 1.6) if rng.randf() < 0.7 else 0.0
			var ok := _inside_raw(r, pos, false)
			for k in 8:
				var ang := k * TAU / 8.0
				ok = ok and _inside_raw(r, pos + Vector2(cos(ang), sin(ang)) * s * 1.9, true)
			if not ok:
				continue
			var hole: Dictionary
			match rng.randi_range(0, 4):
				0:
					hole = _part("circle", pos, Vector2(s, s))
				1:
					hole = _part("box", pos, Vector2(s, s), rng.randi_range(0, 1) * PI / 4.0)
					hole.a = 0.3
				2:
					hole = _part("ngon", pos, Vector2(s, s) * 1.15)
					hole.n = rng.randi_range(3, 6)
				3:
					hole = _part("heart", pos, Vector2(s, s) * 1.2)
				_:
					hole = _part("poly", pos, Vector2(s, s) * 1.3)
					hole.pts = _star_points(rng.randi_range(4, 6), 0.55)
			r.holes.append(hole)
			break


static func _fallback() -> Dictionary:
	var r := {"parts": [_part("circle", Vector2.ZERO, Vector2.ONE)], "holes": [], "mirror": false, "rot": 0.0}
	r.fit = _fit(r)
	return r


## Scales the shape to fill the board without stretching it more than a little.
static func _fit(r: Dictionary) -> Vector4:
	# Coarse pass to find roughly where the shape is, then a fine pass over just that box.
	var box := _bounds(r, Vector2(-2.6, -2.6), Vector2(2.6, 2.6), 16)
	if box.size.x <= 0.0:
		return Vector4(0, 0, 1, BOARD_ASPECT)
	box = _bounds(r, box.position, box.end, 26)
	var lo := box.position
	var hi := box.end
	var center := (lo + hi) * 0.5
	var half := (hi - lo) * 0.5
	if r.mirror:
		center.x = 0.0
		half.x = maxf(absf(lo.x), absf(hi.x))
	var kx := half.x
	var ky := half.y / BOARD_ASPECT
	var k := maxf(kx, ky)
	kx = maxf(kx, k / 1.3)
	ky = maxf(ky, k / 1.3)
	return Vector4(center.x, center.y, kx, ky * BOARD_ASPECT)


## Bounding box of the shape sampled on a steps x steps grid over [from, to],
## padded by one sample so nothing is clipped. Empty rect if nothing was hit.
static func _bounds(r: Dictionary, from: Vector2, to: Vector2, steps: int) -> Rect2:
	var step := (to - from) / steps
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for y in steps:
		for x in steps:
			var p := from + Vector2(x + 0.5, y + 0.5) * step
			if _inside_raw(r, p, true):
				lo = lo.min(p)
				hi = hi.max(p)
	if lo.x == INF:
		return Rect2()
	lo -= step
	hi += step
	return Rect2(lo, hi - lo)


# --- Point tests ---------------------------------------------------------------------------

static func _inside_raw(r: Dictionary, p: Vector2, with_holes: bool) -> bool:
	if r.rot != 0.0:
		p = p.rotated(-r.rot)
	if r.mirror:
		p.x = -absf(p.x)
	var hit := false
	for part: Dictionary in r.parts:
		if _in_part(part, p):
			hit = true
			break
	if not hit:
		return false
	if with_holes:
		for hole: Dictionary in r.holes:
			if _in_part(hole, p):
				return false
	return true


static func _in_part(part: Dictionary, p: Vector2) -> bool:
	var l: Vector2 = (p - part.pos).rotated(-part.rot) / part.size
	match part.kind:
		"circle":
			return l.length_squared() <= 1.0
		"box":
			var rr: float = part.a
			var q := l.abs() - Vector2.ONE * (1.0 - rr)
			return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) <= rr
		"ngon":
			var n: int = part.n
			var ang := fposmod(l.angle() + PI / 2.0, TAU / n) - PI / n
			return l.length() * cos(ang) <= cos(PI / n)
		"super":
			return pow(absf(l.x), part.a) + pow(absf(l.y), part.a) <= 1.0
		"flower":
			var t := l.angle() + PI / 2.0
			var a: float = part.a
			return l.length() <= (1.0 - a) + a * absf(cos(part.n * t / 2.0))
		"blob":
			var t := l.angle()
			var rad := 0.85
			for w: Vector3 in part.waves:
				rad += w.x * cos(w.y * t + w.z)
			return l.length() <= rad
		"heart":
			var x := l.x * 1.18
			var y := -l.y * 1.15 + 0.12
			var a := x * x + y * y - 1.0
			return a * a * a - x * x * y * y * y <= 0.0
		"ring":
			var d2 := l.length_squared()
			return d2 <= 1.0 and d2 >= float(part.a) * float(part.a)
		"cross":
			var a: float = part.a
			return absf(l.x) <= 1.0 and absf(l.y) <= 1.0 and (absf(l.x) <= a or absf(l.y) <= a)
		"poly":
			return Geometry2D.is_point_in_polygon(l, part.pts)
	return false
