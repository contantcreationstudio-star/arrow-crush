class_name BoardCritic
extends RefCounted
## Measures a board and says how well it fits the kind of level it was meant to be.
##
## LevelGenerator builds a few candidate boards per level; the critic's score is part of
## how the winner is picked, so a "giant" level really gets a giant arrow and a "dense"
## level really is packed. tools/audit_levels.gd uses measure() to report every level.


## Numbers that describe a board:
##   coverage - share of the shape's cells covered by arrows (1.0 = no gaps)
##   arrows, longest, avg_len, big (arrows of 20+ cells)
##   turns    - average bends per arrow (0 = all straight)
## `pieces` = cells holding a board piece (balloon, crate, mirror): they count as filled.
static func measure(arrows: Array, mask: Dictionary, pieces: int = 0) -> Dictionary:
	var used := pieces
	var longest := 0
	var big := 0
	var turns := 0
	for a: Array in arrows:
		used += a.size()
		longest = maxi(longest, a.size())
		if a.size() >= 20:
			big += 1
		for k in range(2, a.size()):
			if (a[k] - a[k - 1]) != (a[k - 1] - a[k - 2]):
				turns += 1
	var n := maxi(1, arrows.size())
	var in_arrows := used - pieces
	return {
		"coverage": float(used) / maxf(1.0, mask.size()),
		"arrows": arrows.size(), "longest": longest, "big": big,
		"avg_len": float(in_arrows) / n, "turns": float(turns) / n,
	}


## Extra score for a candidate board of the given plan (added to the generator's own score).
## Boards that miss what the plan promises lose a lot, so another candidate wins.
static func score(plan: String, m: Dictionary) -> float:
	match plan:
		"giant":
			# At least one huge arrow, the bigger the better (up to 60 cells).
			var s := minf(float(m.longest), 60.0) * 1.5 + float(m.big) * 12.0
			if int(m.longest) < 25:
				s -= 80.0
			return s
		"dense":
			# Packed: every gap costs, every extra arrow counts.
			var s := float(m.coverage) * 120.0 + float(m.arrows) * 1.5
			if float(m.coverage) < 0.95:
				s -= 60.0
			return s
	return 0.0


## True when a board does what its plan promises (used by the audit tool's report).
static func passes(plan: String, m: Dictionary) -> bool:
	match plan:
		"giant":
			return int(m.longest) >= 25
		"dense":
			return float(m.coverage) >= 0.95 and int(m.arrows) >= 40
	return float(m.coverage) >= 0.8


## Giant levels: a huge arrow that can fly out on the first tap is no puzzle. Bonus for
## every huge arrow (20+ cells) that has to wait for others first, more the longer it waits.
## `rounds` = LevelGenerator._rounds (0 = free at the start).
static func wait_bonus(arrows: Array, rounds: Array) -> float:
	var s := 0.0
	for i in arrows.size():
		if arrows[i].size() >= 20 and i < rounds.size():
			s += -40.0 if rounds[i] == 0 else 20.0 + 6.0 * minf(rounds[i], 4.0)
	return s
