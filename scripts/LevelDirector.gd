class_name LevelDirector
extends RefCounted
## Decides what kind of board each level is, on top of GameData's Easy/Normal/Hard rhythm:
##   giant  - every 10th level from 10: one or more huge spiral arrows (ArrowPatterns).
##            Every other one (30, 50, 70 ...) the whole board is a giant arrow, too.
##   dense  - every 5th level (15, 25, 35 ...): a packed board with no gaps.
##   normal - the rest, built as before.
## The 10th levels are the Hard / Super Hard beats and the 5th the Hard ones, so the big
## boards land where the player expects a challenge.


static func plan_for(level: int) -> String:
	if level >= 10 and level % 10 == 0:
		return "giant"
	if level >= 15 and level % 10 == 5:
		return "dense"
	return "normal"


## Giant levels where the board itself is shaped like a big arrow.
static func giant_board(level: int) -> bool:
	return plan_for(level) == "giant" and level >= 30 and (level / 10) % 2 == 1


## Spirals for a giant level: [count, radius, longest length]. Level 10 gets a small taste.
static func spirals_for(level: int, cols: int, d: float) -> Vector3i:
	if level < 20:
		return Vector3i(1, 3, 40)
	if giant_board(level):
		return Vector3i(1, 3, 45)  # inside the big arrow's shaft
	if cols >= 16 and d >= 0.6:
		return Vector3i(2, 3, 45)
	return Vector3i(1, 4, 60)
