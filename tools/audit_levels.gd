extends SceneTree
## PC tool: builds every level the way a phone would (base difficulty, no player style)
## and reports how each board measures up (see BoardCritic). Read-only: saves nothing
## but the report. Run from the project folder:
##   Godot --headless --path . --script res://tools/audit_levels.gd [-- from to]
## Writes build/level_audit.csv and prints a summary per plan (normal / giant / dense).

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var from := int(args[0]) if args.size() > 0 else 1
	var to := int(args[1]) if args.size() > 1 else 500
	var gd: Node = load("res://scripts/GameData.gd").new()  # only for the difficulty curve
	var csv := FileAccess.open("res://build/level_audit.csv", FileAccess.WRITE)
	csv.store_line("level,plan,difficulty,cols,arrows,longest,big,avg_len,turns,coverage,free_at_start,depth,ms,ok")
	var sums := {}
	var worst_ms := 0
	for lv in range(from, to + 1):
		var d: float = gd.base_difficulty(lv)
		var t := Time.get_ticks_msec()
		var data := LevelGenerator.generate(lv, d, {}, LevelGenerator.features_for(lv))
		var ms := Time.get_ticks_msec() - t
		worst_ms = maxi(worst_ms, ms)
		var plan: String = data.get("plan", "normal")
		var pieces: int = data.balloons.size() + data.crates.size() + data.mirrors.size()
		var m := BoardCritic.measure(data.arrows, data.mask, pieces)
		var ok := BoardCritic.passes(plan, m)
		if plan == "giant":  # the huge arrow must not be free at the start
			var rounds := LevelGenerator._rounds(data.arrows, data.cols, data.rows, data.mirrors)
			for i in data.arrows.size():
				if data.arrows[i].size() >= 20 and rounds[i] == 0:
					ok = false
					print("FREE GIANT L%d (%d cells)" % [lv, data.arrows[i].size()])
		csv.store_line("%d,%s,%.2f,%d,%d,%d,%d,%.1f,%.1f,%.3f,%d,%d,%d,%d" % [lv, plan, d, data.cols,
			m.arrows, m.longest, m.big, m.avg_len, m.turns, m.coverage, data.free_at_start, data.depth, ms, int(ok)])
		if not sums.has(plan):
			sums[plan] = {"n": 0, "fail": 0, "longest": 0.0, "coverage": 0.0, "arrows": 0.0, "ms": 0.0}
		var s: Dictionary = sums[plan]
		s.n += 1
		s.fail += int(not ok)
		s.longest += m.longest
		s.coverage += m.coverage
		s.arrows += m.arrows
		s.ms += ms
		if not ok:
			print("WEAK L%d (%s): longest %d, coverage %.0f%%" % [lv, plan, m.longest, m.coverage * 100.0])
	csv.close()
	gd.free()
	for plan: String in sums:
		var s: Dictionary = sums[plan]
		print("%-6s levels %3d | weak %3d | avg longest %4.1f | avg coverage %3.0f%% | avg arrows %4.1f | avg %3.0f ms" % [
			plan, s.n, s.fail, s.longest / s.n, s.coverage / s.n * 100.0, s.arrows / s.n, s.ms / s.n])
	print("slowest level: %d ms" % worst_ms)
	quit()
