extends SceneTree
## PC tool: bakes the 500-level outline chain into res://data/shape_chain.txt and checks
## that every level is unique. Run from the project folder:
##   Godot --headless --path . --script res://tools/bake_shapes.gd
## Re-run after changing ShapeFactory / PictureShapes (and bump ShapeFactory.BAKE_VERSION).

func _init() -> void:
	var t := Time.get_ticks_msec()
	var worst_chain := ShapeFactory.bake() if not OS.get_cmdline_user_args().has("check") else 0.0
	print("BAKE %d outlines in %d ms (worst overlap with an earlier level while building: %.2f)" % [
		ShapeFactory.CHAIN_LEVELS, Time.get_ticks_msec() - t, worst_chain])
	# Every pair of levels, outline against outline (mirror images count as the same).
	var n := ShapeFactory.CHAIN_LEVELS
	var sigs: Array = []
	for lv in range(1, n + 1):
		var s: PackedByteArray = ShapeFactory._raster(ShapeFactory.recipe_for(lv))
		sigs.append([s, ShapeFactory._mirror_sig(s)])
	var worst := 0.0
	var pair := Vector2i.ZERO
	var close := 0
	for a in n:
		for b in range(a + 1, n):
			var o := maxf(ShapeFactory._iou(sigs[a][0], sigs[b][0]), ShapeFactory._iou(sigs[a][1], sigs[b][0]))
			if o > worst:
				worst = o
				pair = Vector2i(a + 1, b + 1)
			if o > ShapeFactory.MAX_OVERLAP:
				close += 1
				print("CLOSE L%d%s / L%d%s = %.2f" % [a + 1, " (" + PictureShapes.id_for(a + 1) + ")" if PictureShapes.id_for(a + 1) != "" else "", b + 1, " (" + PictureShapes.id_for(b + 1) + ")" if PictureShapes.id_for(b + 1) != "" else "", o])
	print("UNIQUE outlines: most alike pair L%d / L%d = %.2f, pairs above %.2f: %d" % [pair.x, pair.y, worst, ShapeFactory.MAX_OVERLAP, close])
	# Arrow layouts: no two levels may have the same arrows.
	var seen := {}
	var dup := 0
	for lv in range(1, n + 1):
		var data := LevelGenerator.generate(lv, 0.5, {}, LevelGenerator.features_for(lv))
		var key := str(data.cols) + str(data.arrows).md5_text()
		if seen.has(key):
			dup += 1
			print("SAME ARROWS: L%d and L%d" % [seen[key], lv])
		seen[key] = lv
	print("UNIQUE arrow layouts: %d duplicates" % dup)
	quit()