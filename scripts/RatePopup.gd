class_name RatePopup
extends StreakPopup
## "Enjoying Arrow Crush?" - asked at most twice in the game's life, only right after a win
## on the map: first after level 20, and once more after level 60 if they chose "Maybe later".
## Rating is never rewarded or required (Play policy) and "Rate now" opens the store page.

const STAR := preload("res://icons/star_win.svg")
const FIRST_ASK := 20
const SECOND_ASK := 60


## True when the map should ask now (a level was just won).
static func is_due() -> bool:
	var cleared := GameData.unlocked_level - 1
	return (GameData.rate_state == 0 and cleared >= FIRST_ASK) \
		or (GameData.rate_state == 1 and cleared >= SECOND_ASK)


static func ask(parent: Node) -> RatePopup:
	var p := RatePopup.new()
	parent.add_child(p)
	p._build_ask()
	return p


func _build_ask() -> void:
	var later_state := 1 if GameData.rate_state == 0 else 2  # the second "later" is the last ask
	_icon(STAR, 130)
	_label("Enjoying Arrow Crush?", 48, Color("#1e3a8a"))
	_label("A quick rating on Google Play helps other puzzle fans find the game. Thank you!", 28, Color("#64748b"))
	var rate := _button("Rate now", true)
	rate.pressed.connect(func() -> void:
		GameData.play_sfx("star")
		AppLinks.rate()
		_close())
	var later := _button("Maybe later", false)
	later.pressed.connect(func() -> void:
		GameData.play_sfx("tap")
		GameData.rate_state = later_state
		GameData.save_game()
		_close())
	_pop_in()
