extends SceneTree
## PC tool for the picture library (every level is a picture: animals, birds, flowers,
## home things, school things...). Icons come from open-licence silhouette sets in
## tools/icon_src (game-icons.net CC BY 3.0, Material Design Icons Apache 2.0, Phosphor MIT),
## downloaded from https://cdn.jsdelivr.net/npm/@iconify-json/<set>/icons.json.
##
##   analyse <list> <out_dir>  - every "set:name<TAB>category" line of <list>: turn it into a
##                               board mask the way the game does, measure how clearly it
##                               survives at each board width, and draw review sheets.
##   build <list>              - write data/pictures.txt from the final, reviewed list.
##
## Run: Godot --headless --path . --script res://tools/build_pictures.gd -- analyse a.txt out/

const SETS := {
	"game-icons": "res://tools/icon_src/game-icons.json",
	"mdi": "res://tools/icon_src/mdi.json",
	"ph": "res://tools/icon_src/ph.json",
	"fluent-emoji-flat": "res://tools/icon_src/fluent-emoji-flat.json",
	"fa6-solid": "res://tools/icon_src/fa6-solid.json",
	"material-symbols": "res://tools/icon_src/material-symbols.json",
	"icon-park-solid": "res://tools/icon_src/icon-park-solid.json",
}
const SIZES: Array[int] = [8, 10, 12, 14, 16, 18]
const CLEAR := 0.8          # fidelity a board must keep to count as "clear" at that width
const BITMAP_W := 96        # stored picture width (height follows the icon's shape)

var _sets := {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 3 and args[0] == "analyse":
		_analyse(args[1], args[2])
	elif args.size() >= 2 and args[0] == "build":
		_build(args[1])
	else:
		print("usage: analyse <list> <out_dir> | build <list>")
	quit()


func _icon_set(key: String) -> Dictionary:
	if not _sets.has(key):
		_sets[key] = JSON.parse_string(FileAccess.get_file_as_string(SETS[key]))
	return _sets[key]


## The icon as a picture recipe (see ShapeFactory._inside_raw), or {} if it can't be read.
func recipe_of(id: String) -> Dictionary:
	var parts := id.split(":")
	var set := _icon_set(parts[0])
	var icon: Dictionary = set.icons.get(parts[1], {})
	if icon.is_empty():
		return {}
	var w := int(icon.get("width", set.get("width", 24)))
	var h := int(icon.get("height", set.get("height", 24)))
	var body := str(icon.body).replace("currentColor", "#000000")
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">%s</svg>' % [w, h, w, h, body]
	var img := Image.new()
	if img.load_svg_from_string(svg, 256.0 / maxf(w, h)) != OK:
		return {}
	img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	if used.size.x < 4 or used.size.y < 4:
		return {}
	img = img.get_region(used)
	var bh := maxi(4, roundi(BITMAP_W * float(used.size.y) / used.size.x))
	img.resize(BITMAP_W, bh, Image.INTERPOLATE_BILINEAR)
	var bits := PackedByteArray()
	bits.resize(BITMAP_W * bh)
	for y in bh:
		for x in BITMAP_W:
			bits[y * BITMAP_W + x] = 1 if img.get_pixel(x, y).a > 0.5 else 0
	# Only the solid outer silhouette (like a shadow): close the fine cut lines inside the
	# icon, then fill every hole. Inner details break apart on a board of big cells.
	bits = _close(bits, BITMAP_W, bh, 3)
	bits = _fill_holes(bits, BITMAP_W, bh)
	return {"bitmap": bits, "bw": BITMAP_W, "bh": bh, "rot": 0.0, "mirror": false, "parts": [], "holes": []}


## Morphological closing (grow then shrink by `r` pixels): seals thin gaps and cut lines.
func _close(bits: PackedByteArray, w: int, h: int, r: int) -> PackedByteArray:
	return _morph(_morph(bits, w, h, r, true), w, h, r, false)


func _morph(bits: PackedByteArray, w: int, h: int, r: int, grow: bool) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(w * h)
	for y in h:
		for x in w:
			var hit := not grow
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if dx * dx + dy * dy > r * r:
						continue
					var xx := x + dx
					var yy := y + dy
					var v := 0 if (xx < 0 or yy < 0 or xx >= w or yy >= h) else bits[yy * w + xx]
					if grow and v:
						hit = true
					elif not grow and not v:
						hit = false
			out[y * w + x] = 1 if hit else 0
	return out


## Fills every enclosed hole: background not reachable from the border becomes solid.
func _fill_holes(bits: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var outside := PackedByteArray()
	outside.resize(w * h)
	var stack: Array[int] = []
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	while not stack.is_empty():
		var i: int = stack.pop_back()
		if outside[i] or bits[i]:
			continue
		outside[i] = 1
		var x := i % w
		var y := i / w
		if x > 0: stack.append(i - 1)
		if x < w - 1: stack.append(i + 1)
		if y > 0: stack.append(i - w)
		if y < h - 1: stack.append(i + w)
	var out := PackedByteArray()
	out.resize(w * h)
	for i in w * h:
		out[i] = 0 if outside[i] else 1
	return out


## How the picture looks on a board `cols` wide: the board mask (exactly as the game
## builds it) and its fidelity - overlap between the cells and the true outline, sampled
## 3 x 3 per cell. 1 = perfect, below ~0.8 the picture turns into a blob.
func board_of(recipe: Dictionary, cols: int) -> Dictionary:
	var rows := roundi(cols * 1.15) + 1
	var r := recipe.duplicate()
	r.fit = ShapeFactory._fit(r)
	var mask := LevelGenerator._make_mask(r, cols, rows)
	var both := 0
	var either := 0
	for y in rows * 3:
		for x in cols * 3:
			var u := (x + 0.5) / (cols * 3) * 2.0 - 1.0
			var v := (y + 0.5) / (rows * 3) * 2.0 - 1.0
			var a := ShapeFactory.inside(r, u, v)
			var b := mask.has(Vector2i(x / 3, y / 3))
			if a or b:
				either += 1
				if a and b:
					both += 1
	return {"mask": mask, "cols": cols, "rows": rows, "fidelity": float(both) / maxf(1, either)}


## How plain a silhouette is: overlap with its own bounding box and with the ellipse in
## that box (near 1 = just a rectangle / a blob, nothing to recognise), and how much of
## the box it fills (low = a thin stick or scattered bits).
func plainness(r: Dictionary) -> Dictionary:
	var bits: PackedByteArray = r.bitmap
	var w: int = r.bw
	var h: int = r.bh
	var filled := 0
	var in_ell := 0
	var both_ell := 0
	for y in h:
		for x in w:
			var on := bits[y * w + x] != 0
			var e := Vector2((x + 0.5) / w * 2.0 - 1.0, (y + 0.5) / h * 2.0 - 1.0).length_squared() <= 1.0
			if on:
				filled += 1
			if e:
				in_ell += 1
			if on and e:
				both_ell += 1
	var ell_union := filled + in_ell - both_ell
	return {"box": snappedf(float(filled) / (w * h), 0.01), "ellipse": snappedf(float(both_ell) / maxf(1, ell_union), 0.01),
		"fill": snappedf(float(filled) / (w * h), 0.01)}


func _read_list(path: String) -> Array:
	var out: Array = []
	var seen := {}
	for line in FileAccess.get_file_as_string(path).split("\n"):
		line = line.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var cols := line.split("\t")
		if seen.has(cols[0]):
			continue
		seen[cols[0]] = true
		out.append([cols[0], cols[1] if cols.size() > 1 else ""])
	return out


func _analyse(list_path: String, out_dir: String) -> void:
	var items := _read_list(list_path)
	var report := []
	var tiles := []
	var t := Time.get_ticks_msec()
	for it: Array in items:
		var rec := recipe_of(it[0])
		if rec.is_empty():
			continue
		var fid := {}
		var min_cols := -1
		var shown := {}
		for c in SIZES:
			var b := board_of(rec, c)
			fid[c] = snappedf(b.fidelity, 0.01)
			if min_cols < 0 and b.fidelity >= CLEAR and b.mask.size() >= 24:
				min_cols = c
				shown = b
		if shown.is_empty():
			shown = board_of(rec, 18)
		var plain := plainness(rec)
		# Automatic rejects: never clear on a board, or just a box / blob / thin stick.
		var why := ""
		if min_cols < 0:
			why = "blurry"
		elif plain.box > 0.84:
			why = "box"
		elif plain.ellipse > 0.87:
			why = "blob"
		elif plain.fill < 0.3:
			why = "thin"
		report.append({"id": it[0], "cat": it[1], "min_cols": min_cols, "fid": fid, "plain": plain, "reject": why})
		if why == "":
			tiles.append([it[0], board_of(rec, 16), min_cols])  # reviewed at a typical board width
	print("ANALYSED %d icons in %d ms" % [report.size(), Time.get_ticks_msec() - t])
	var f := FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	_sheets(tiles, out_dir)


## Review sheets: 8 x 6 tiles, each the board as the player will see it (green = clear at
## that width, red = never clear). sheet_N.txt lists the names in reading order.
func _sheets(tiles: Array, out_dir: String) -> void:
	const PER := 80
	const TW := 96
	const TH := 118
	var n := 0
	while n * PER < tiles.size():
		var img := Image.create(10 * TW, 8 * TH, false, Image.FORMAT_RGB8)
		img.fill(Color.WHITE)
		var names := PackedStringArray()
		for k in PER:
			var i := n * PER + k
			if i >= tiles.size():
				break
			var tile: Array = tiles[i]
			names.append("%d\t%s\tmin_cols=%d" % [k, tile[0], tile[2]])
			var b: Dictionary = tile[1]
			var ox := (k % 10) * TW
			var oy := (k / 10) * TH
			var cell := mini((TW - 10) / b.cols, (TH - 16) / b.rows)
			var col := Color("#16a34a") if tile[2] > 0 else Color("#dc2626")
			for c: Vector2i in b.mask:
				img.fill_rect(Rect2i(ox + 5 + c.x * cell, oy + 5 + c.y * cell, cell - 1, cell - 1), Color("#7c3aed"))
			img.fill_rect(Rect2i(ox + 4, oy + TH - 8, TW - 8, 4), col)
		img.save_png(out_dir.path_join("sheet_%02d.png" % n))
		var f := FileAccess.open(out_dir.path_join("sheet_%02d.txt" % n), FileAccess.WRITE)
		f.store_string("\n".join(names))
		f.close()
		n += 1
	print("SHEETS %d" % n)


## Names shown to the player ("You drew a Rabbit!") where the icon's own name says little.
const NAME_FIX := {
	"cruelty-free": "Rabbit", "flutter-dash": "Bird", "pest-control": "Bug", "pest-control-rodent": "Mouse",
	"phishing": "Fish Hook", "spa": "Lotus", "architecture": "Compass", "local-florist": "Flower",
	"cards-heart": "Heart", "weather-night": "Moon", "lead-pencil": "Pencil", "silverware": "Cutlery",
	"silverware-fork-knife": "Fork and Knife", "bowl-mix": "Mixing Bowl", "pot-steam": "Cooking Pot",
	"glass-mug": "Mug", "glass-cocktail": "Glass", "glass-wine": "Goblet", "bus-side": "Bus",
	"car-side": "Car", "car-pickup": "Pickup Truck", "car-convertible": "Convertible", "home-variant": "Home",
	"horse-variant": "Rearing Horse", "rabbit-variant": "Bunny", "chef-hat": "Chef Hat", "fish-fins": "Goldfish",
	"kiwi-bird": "Kiwi Bird", "horse-head": "Horse Head", "plant-wilt": "Plant", "mortar-pestle": "Mortar",
	"hat-wizard": "Wizard Hat", "hat-cowboy": "Cowboy Hat", "music": "Music Note", "check-mark": "Tick",
	"skateboarding": "Skater", "hiking": "Hiker", "surfing": "Surfer", "kayaking": "Kayak", "wall-lamp": "Wall Lamp",
	"water-drop": "Water Drop", "potted-plant": "Potted Plant", "dog-side": "Dog", "chair-school": "Chair",
	"umbrella-closed": "Closed Umbrella", "umbrella-beach": "Beach Umbrella", "rocket-launch": "Rocket Launch",
}


## Writes data/pictures.txt: every picture as a packed bit mask plus the smallest board
## width it stays clear on, near-duplicates dropped, and a schedule spreading the pictures
## over levels 2-500 (simple, small ones first; the categories take turns).
func _build(list_path: String) -> void:
	var items := _read_list(list_path)
	var pics: Array = []
	var sigs: Array = []
	for it: Array in items:
		var rec := recipe_of(it[0])
		if rec.is_empty():
			continue
		var min_cols := -1
		for c in SIZES:
			var b := board_of(rec, c)
			if b.fidelity >= CLEAR and b.mask.size() >= 24:
				min_cols = c
				break
		if min_cols < 0:
			continue
		# Same silhouette as one already in? (outline overlap at a 16-cell board, mirror too)
		var r := rec.duplicate()
		r.fit = ShapeFactory._fit(r)
		var sig := ShapeFactory._raster(r)
		var dup := false
		for other: PackedByteArray in sigs:
			if maxf(ShapeFactory._iou(sig, other), ShapeFactory._iou(ShapeFactory._mirror_sig(sig), other)) > 0.85:
				dup = true
				break
		if dup:
			print("DUPLICATE dropped: ", it[0])
			continue
		sigs.append(sig)
		var base := str(it[0]).split(":")[1].trim_suffix("-fill").trim_suffix("-variant")
		var name: String = NAME_FIX.get(base, base.trim_prefix("fruit-").trim_prefix("food-").trim_prefix("local-")
			.replace("-", " ").capitalize())
		pics.append({"id": it[0], "name": name, "cat": it[1], "bw": rec.bw, "bh": rec.bh,
			"hex": _pack(rec.bitmap), "min_cols": min_cols})
	# Order: small boards first; within a width the categories take turns.
	pics.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.min_cols < b.min_cols if a.min_cols != b.min_cols else str(a.id) < str(b.id))
	var by_cat := {}
	for p: Dictionary in pics:
		var key := "%02d|%s" % [p.min_cols, p.cat]
		if not by_cat.has(key):
			by_cat[key] = []
		by_cat[key].append(p)
	var ordered: Array = []
	for w in SIZES:
		var queues: Array = []
		for key: String in by_cat:
			if key.begins_with("%02d|" % w):
				queues.append(by_cat[key])
		while true:
			var took := false
			for q: Array in queues:
				if not q.is_empty():
					ordered.append(q.pop_front())
					took = true
			if not took:
				break
	# Schedule: spread evenly over levels 2..500 (level 1 is the hand-made tutorial).
	var levels := {}
	for i in ordered.size():
		levels[2 + roundi(i * 498.0 / maxf(1, ordered.size() - 1))] = i
	var f := FileAccess.open("res://data/pictures.txt", FileAccess.WRITE)
	f.store_string(var_to_str({"version": 1, "pictures": ordered, "levels": levels}))
	f.close()
	print("BUILT %d pictures (%d dropped), levels with a picture: %d" % [ordered.size(), items.size() - ordered.size(), levels.size()])


## Bit mask -> hex string (8 cells per byte).
func _pack(bits: PackedByteArray) -> String:
	var bytes := PackedByteArray()
	bytes.resize((bits.size() + 7) / 8)
	for i in bits.size():
		if bits[i]:
			bytes[i / 8] |= 1 << (i % 8)
	return bytes.hex_encode()
