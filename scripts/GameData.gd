extends Node
## Global autoload ("GameData"): progress, settings, local save and sound effects.

const SAVE_PATH := "user://arrow_crush.cfg"
const MAX_LEVELS := 500
const MIX_RATE := 22050
const MAX_POWER := 5
const DIFFICULTY_VERSION := 4  # bump when the difficulty curve changes
const MAX_BOOSTER := 9          # per booster kind
## Level each power unlocks at. New players start with Undo, Hint and the Drill only;
## the others arrive one by one, each with a couple free to try.
const BOOSTER_UNLOCK := {"drill": 5, "bomb": 8, "laser": 15, "rainbow": 25}  # drill: taught on level 5
const UNLOCK_GIFT := 2

# --- Coins and the booster shop ---
# Boosters: "drill" is the original Super Power (power_charges); the others use `boosters`.
const BOOSTERS: Array[String] = ["drill", "bomb", "laser", "rainbow"]   # = ArrowPath.Special 1..4
const BOOSTER_NAMES := {"drill": "Super Drill", "bomb": "Mega Bomb", "laser": "Cross Laser",
	"rainbow": "Color Wipe", "hint": "Hint"}
const BOOSTER_INFO := {"drill": "Smashes through every arrow in its path",
	"bomb": "Blows up a big 5x5 area around the arrow",
	"laser": "Clears the whole row and column",
	"rainbow": "Removes every arrow of that colour", "hint": "Shows an arrow you can move"}
const PRICES := {"hint": 60, "drill": 150, "bomb": 200, "laser": 250, "rainbow": 350}
const CONTINUE_COINS := 120     # +moves / +time / +heart after failing, paid with coins
const AD_COINS := 100           # rewarded video in the shop
const COIN_VIDEOS_PER_DAY := 5  # free-coin videos per day (keeps coins worth earning and ad traffic natural)
const START_COINS := 150
const COINS_WIN := 20           # every win ...
const COINS_PER_STAR := 10      # ... plus per star ...
const COINS_PER_GOAL := 2       # ... plus per balloon layer popped / target hit / goal piece
const COINS_DAILY := 60         # finishing a daily challenge (first time)
var _coin_video_day := -1       # local day of the free-coin videos counted below
var _coin_videos := 0           # free-coin videos watched on that day
## Quiver: arrows the player spends to try levels (5 max, one refills every 30 minutes).
## A lost level - or leaving one after the first tap - costs one. The first levels,
## the tutorial and the daily challenge are free.
const QUIVER_MAX := 5
const QUIVER_REFILL_SEC := 1800
const QUIVER_FREE_UNTIL := 10
## Replace these with your real hosted pages before publishing.
const GAME_VERSION := "1.3"

var unlocked_level := 1     # highest level the player may open (saved)
var sound_on := true        # saved
var vibration_on := true    # saved
var music_on := true        # saved
var stars := {}             # level -> best stars 1..3 (saved)
var power_charges := 1      # break-through super powers in stock (saved)
var coins := START_COINS    # saved
var boosters := {"bomb": 0, "laser": 0, "rainbow": 0}  # board boosters in stock (saved)
var boosters_seen: Array = []   # powers whose "unlocked!" popup was shown (saved)
var quiver := QUIVER_MAX    # arrows in the quiver (saved)
var quiver_stamp := 0       # unix time the next refill started counting from (saved)

# --- Player behaviour model (saved) ---------------------------------------------------
# Updated after every level from how the player actually played; it decides how the
# NEXT levels are built. Nothing about difficulty is hard-coded per level number.
var skill := 0.0            # -1 struggling .. +1 crushing it (smoothed)
var pace := 0.0             # -1 slow, careful thinker .. +1 fast tapper
var accuracy := 0.7         # share of taps that were correct (smoothed)
var levels_played := 0
var last_performance := 0.5 # 0..1 score of the most recently finished level
var level_difficulty := {}  # level -> difficulty locked the first time it was played
var level_fails := {}       # level -> losses in a row on it (cleared when it is won)
var last_played_day := -1   # local day of the last finished level (win or loss)
var comeback := false       # session only: back after 3+ days away - the next new level is gentler
var current_level := 1      # level to load when GameScene opens

# --- Consent & privacy (saved) ------------------------------------------------------------
var terms_accepted := false     # Welcome screen "Accept"
var personalized_ads := true    # Privacy Preferences
var analytics_on := true        # Privacy Preferences
var zoom_tip_seen := false      # the player has zoomed at least once
var tutorial_done := false      # first-launch guided tutorial finished or skipped
var seen_features := {}         # board pieces already introduced ("balloons", "ice", ...)

# --- Daily streak & daily challenge (saved) -----------------------------------------------
var streak := 0                 # days in a row with at least one win
var streak_last_day := -1       # local day number of the last day that counted
var streak_best := 0
var streak_freeze_day := -100   # local day a broken streak was last saved with a video
var bonus_hints := 0            # hint bank (streak rewards), used after a level's free hints
var daily_done := {}            # UTC day -> stars of a finished daily challenge
var daily_unlocked := {}        # UTC day -> true for past days opened with a video
var daily_day := -1             # session only: daily challenge being played (-1 = levels)
var map_seen_level := 0         # session only: level the map pin last stood on
var quit_notice := ""           # session only: shown on Home after a level was abandoned by closing the app

## Reward for day 1..7 of each streak week.
const STREAK_REWARDS: Array[Dictionary] = [
	{"hints": 1}, {"power": 1}, {"hints": 2}, {"power": 1}, {"hints": 2}, {"power": 2}, {"hints": 3, "power": 2},
]
const MONTHS: Array[String] = ["January", "February", "March", "April", "May", "June", "July",
	"August", "September", "October", "November", "December"]
var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_tween: Tween
const MUSIC_DB := -15.0     # calm, under the sound effects
var _music_base_db := -60.0  # the music's own level (fades in / out); ducking goes on top
var _music_pitch := 1.0      # the place's pitch (set_music_pitch)
var _duck_db := 0.0          # wanted dip right now (dB below the base) ...
var _duck_pitch := 1.0       # ... and slow-down
var _duck_until := 0.0       # seconds (real time) until the dip lets go
var _duck_cur := 0.0         # smoothed dip actually applied
var _pitch_cur := 1.0        # smoothed slow-down actually applied
## When a sound plays, the music steps back for it: [dB down, seconds held, pitch while held].
## The music dips fast and comes back slowly, so every tap, arrow and quit makes the
## background breathe a little instead of droning on at one level.
const DUCKS := {
	"tap": [3.0, 0.12, 0.99], "slide": [5.0, 0.35, 0.985], "crush": [4.0, 0.3, 1.0],
	"thud": [5.0, 0.35, 0.97], "boom": [8.0, 0.8, 0.96], "laser": [6.0, 0.5, 1.0],
	"power": [6.0, 0.6, 1.0], "charge": [3.0, 0.3, 1.0], "star": [5.0, 0.5, 1.0],
	"win": [10.0, 2.6, 1.0], "lose": [10.0, 2.2, 0.92], "quit": [14.0, 1.7, 0.85],
}
var _shape_thread := Thread.new()


func _ready() -> void:
	load_game()
	_settle_abandoned_level()
	current_level = unlocked_level
	map_seen_level = unlocked_level
	# Invent all level outlines in the background while the menus are open.
	_shape_thread.start(_warm_up_shapes, Thread.PRIORITY_LOW)
	_build_sounds()
	for i in 10:  # the Final Volley alone can ring 6+ fireworks at once
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	# Background music: one peaceful loop for the whole game, played a touch higher or
	# lower in different places (see set_music_pitch) so each world feels a little new.
	_music = AudioStreamPlayer.new()
	var loop := load("res://audio/music_bgm.ogg") as AudioStreamOggVorbis
	loop.loop = true
	_music.stream = loop
	_music.volume_db = -60.0
	add_child(_music)
	if music_on:
		_fade_music_in()


func _warm_up_shapes() -> void:
	ShapeFactory.recipe_for(100)


func _exit_tree() -> void:
	if _shape_thread.is_started():
		_shape_thread.wait_to_finish()
	if _music:
		_music.stop()
		_music.stream = null
	_kill_music_tween()
	for p in _players:
		p.stop()
		p.stream = null


# --- Save / load ---------------------------------------------------------------------

func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked_level", unlocked_level)
	cfg.set_value("progress", "stars", stars)
	cfg.set_value("progress", "power_charges", power_charges)
	cfg.set_value("progress", "coins", coins)
	cfg.set_value("progress", "coin_videos", [_coin_video_day, _coin_videos])
	cfg.set_value("progress", "boosters", boosters)
	cfg.set_value("progress", "boosters_seen", boosters_seen)
	cfg.set_value("progress", "quiver", quiver)
	cfg.set_value("progress", "quiver_stamp", quiver_stamp)
	cfg.set_value("player", "skill", skill)
	cfg.set_value("player", "pace", pace)
	cfg.set_value("player", "accuracy", accuracy)
	cfg.set_value("player", "levels_played", levels_played)
	cfg.set_value("player", "last_performance", last_performance)
	cfg.set_value("player", "level_difficulty", level_difficulty)
	cfg.set_value("player", "difficulty_version", DIFFICULTY_VERSION)
	cfg.set_value("player", "level_fails", level_fails)
	cfg.set_value("player", "last_played_day", last_played_day)
	cfg.set_value("settings", "sound_on", sound_on)
	cfg.set_value("settings", "vibration_on", vibration_on)
	cfg.set_value("settings", "music_on", music_on)
	cfg.set_value("privacy", "terms_accepted", terms_accepted)
	cfg.set_value("privacy", "personalized_ads", personalized_ads)
	cfg.set_value("privacy", "analytics_on", analytics_on)
	cfg.set_value("settings", "zoom_tip_seen", zoom_tip_seen)
	cfg.set_value("settings", "tutorial_done", tutorial_done)
	cfg.set_value("settings", "seen_features", seen_features)
	cfg.set_value("daily", "streak", streak)
	cfg.set_value("daily", "streak_last_day", streak_last_day)
	cfg.set_value("daily", "streak_best", streak_best)
	cfg.set_value("daily", "streak_freeze_day", streak_freeze_day)
	cfg.set_value("daily", "bonus_hints", bonus_hints)
	cfg.set_value("daily", "daily_done", daily_done)
	cfg.set_value("daily", "daily_unlocked", daily_unlocked)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Could not save game (error %d)" % err)


func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return  # first launch
	unlocked_level = clampi(int(cfg.get_value("progress", "unlocked_level", 1)), 1, MAX_LEVELS)
	stars = cfg.get_value("progress", "stars", {})
	# Players who had already beaten the old last level (100) go straight on to 101.
	if int(stars.get(100, 0)) > 0:
		unlocked_level = clampi(maxi(unlocked_level, 101), 1, MAX_LEVELS)
	power_charges = clampi(int(cfg.get_value("progress", "power_charges", 1)), 0, MAX_POWER)
	coins = maxi(0, int(cfg.get_value("progress", "coins", START_COINS)))
	var cv: Array = cfg.get_value("progress", "coin_videos", [-1, 0])
	if cv.size() == 2:
		_coin_video_day = int(cv[0])
		_coin_videos = int(cv[1])
	var saved_boosters: Dictionary = cfg.get_value("progress", "boosters", {})
	for kind in boosters:
		boosters[kind] = clampi(int(saved_boosters.get(kind, 0)), 0, MAX_BOOSTER)
	if cfg.has_section_key("progress", "boosters_seen"):
		boosters_seen = cfg.get_value("progress", "boosters_seen", [])
	else:
		# A save from before powers unlocked by level: whatever this player has already
		# reached counts as introduced - no stack of popups, nothing taken away.
		boosters_seen = []
		for kind: String in BOOSTER_UNLOCK:
			if booster_unlocked(kind):
				boosters_seen.append(kind)
	quiver = clampi(int(cfg.get_value("progress", "quiver", QUIVER_MAX)), 0, QUIVER_MAX)
	quiver_stamp = int(cfg.get_value("progress", "quiver_stamp", 0))
	skill = float(cfg.get_value("player", "skill", 0.0))
	pace = float(cfg.get_value("player", "pace", 0.0))
	accuracy = float(cfg.get_value("player", "accuracy", 0.7))
	levels_played = int(cfg.get_value("player", "levels_played", 0))
	last_performance = float(cfg.get_value("player", "last_performance", 0.5))
	level_difficulty = cfg.get_value("player", "level_difficulty", {})
	if int(cfg.get_value("player", "difficulty_version", 1)) < DIFFICULTY_VERSION:
		level_difficulty = {}  # locked under the old curve: rebuild on the new one
	level_fails = cfg.get_value("player", "level_fails", {})
	last_played_day = int(cfg.get_value("player", "last_played_day", -1))
	comeback = levels_played > 0 and last_played_day >= 0 and local_day() - last_played_day >= 3
	sound_on =bool(cfg.get_value("settings", "sound_on", true))
	vibration_on = bool(cfg.get_value("settings", "vibration_on", true))
	music_on = bool(cfg.get_value("settings", "music_on", true))
	terms_accepted = bool(cfg.get_value("privacy", "terms_accepted", false))
	personalized_ads = bool(cfg.get_value("privacy", "personalized_ads", true))
	analytics_on = bool(cfg.get_value("privacy", "analytics_on", true))
	zoom_tip_seen = bool(cfg.get_value("settings", "zoom_tip_seen", false))
	tutorial_done = bool(cfg.get_value("settings", "tutorial_done", false))
	seen_features = cfg.get_value("settings", "seen_features", {})
	streak = int(cfg.get_value("daily", "streak", 0))
	streak_last_day = int(cfg.get_value("daily", "streak_last_day", -1))
	streak_best = int(cfg.get_value("daily", "streak_best", 0))
	streak_freeze_day = int(cfg.get_value("daily", "streak_freeze_day", -100))
	bonus_hints = int(cfg.get_value("daily", "bonus_hints", 0))
	daily_done = cfg.get_value("daily", "daily_done", {})
	daily_unlocked = cfg.get_value("daily", "daily_unlocked", {})


func complete_level(level: int, earned_stars: int) -> void:
	unlocked_level = clampi(maxi(unlocked_level, level + 1), 1, MAX_LEVELS)
	stars[level] = maxi(int(stars.get(level, 0)), earned_stars)
	level_fails.erase(level)
	save_game()


func best_stars(level: int) -> int:
	return int(stars.get(level, 0))


# --- Behaviour-driven difficulty -----------------------------------------------------------

## The ramp across all 100 levels, front-loaded like match-3 games: about 1-7 Easy,
## 8-22 Normal, 23-50 Hard, 51-100 Super Hard (plus the spikes below). The player's
## skill nudges it.
func base_difficulty(level: int) -> float:
	if level > 100:
		# Worlds 6-25 (101-500): every world is its own sawtooth - it starts easy-ish and
		# climbs to hard by its last level (the 5th / 10th level spikes come on top). Each
		# world starts and ends a little higher than the one before.
		var k := (level - 101) % 20
		var far := clampf((level - 101) / 400.0, 0.0, 1.0)
		return lerpf(lerpf(0.28, 0.42, far), lerpf(0.62, 0.8, far), k / 19.0)
	var t := clampf((level - 1) / 99.0, 0.0, 1.0)  # the ramp spans 1-100
	return lerpf(0.06, 1.0, pow(t, 0.55))


## Rhythm on top of the player's own curve: every 5th level is a hard spike and
## every 10th a super-hard one (the "hard level" beats of match-3 games).
func level_spike(level: int) -> float:
	if level < 5:
		return 0.0
	if level % 10 == 0:
		return 0.22
	if level % 5 == 0:
		return 0.14
	return 0.0


## Difficulty for a level: locked once played. Otherwise the level's place on the
## 1..100 ramp, plus its spike, nudged by the player's skill (a strong player gets up
## to +0.1, a struggling one up to -0.05), so later levels are always harder.
func difficulty_for(level: int) -> float:
	if level_difficulty.has(level):
		return float(level_difficulty[level])
	var nudge := skill * (0.1 if skill > 0.0 else 0.05)
	if comeback:
		nudge -= 0.12  # back after days away: start again with an easy win
	return clampf(base_difficulty(level) + nudge + level_spike(level), 0.0, 1.0)


## A player who could use a hand: struggling overall, or stuck on this level.
## Only ever used to HELP (faster power, hint nudges, a shield) - never to make a level harder.
func needs_help(level: int) -> bool:
	return skill < -0.3 or int(level_fails.get(level, 0)) >= 2


## Fixes the difficulty the first time a level is played, so replays get the same maze.
func lock_difficulty(level: int) -> float:
	var d := difficulty_for(level)
	level_difficulty[level] = d
	save_game()
	return d


func play_style() -> Dictionary:
	return {"pace": pace, "accuracy": accuracy}


## Feed in how a level went; updates the behaviour model.
## stats: won, lives_left, taps, mistakes, hints, undos, powers, seconds, cleared (0..1)
## Returns {delta: skill change, next: difficulty predicted for the next level}.
func record_result(level: int, stats: Dictionary) -> Dictionary:
	var taps := maxi(1, int(stats.taps))
	var sec_per_tap: float = stats.seconds / taps
	var speed := clampf((2.5 - sec_per_tap) / 2.0, -1.0, 1.0)   # ~2.5 s per tap is "normal"
	var tap_accuracy := 1.0 - float(stats.mistakes) / taps

	var perf: float
	if stats.won:
		perf = 0.55 + 0.25 * stats.lives_left / 3.0 + 0.1 * speed \
			- 0.08 * stats.hints - 0.04 * stats.undos - 0.06 * stats.powers
	else:
		perf = 0.1 + 0.25 * stats.cleared
	perf = clampf(perf, 0.0, 1.0)
	if stats.won:
		perf = maxf(perf, 0.5)  # a win never makes the next level easier
	last_performance = perf

	# The very first level says the most about a new player.
	var weight := 0.6 if levels_played == 0 else 0.35
	var before := skill
	skill = lerpf(skill, perf * 2.0 - 1.0, weight)
	pace = lerpf(pace, speed, weight)
	accuracy = lerpf(accuracy, tap_accuracy, weight)
	levels_played += 1
	comeback = false
	last_played_day = local_day()
	if not stats.won and not stats.get("daily", false):
		# A lost level comes back a little gentler on retry - more so the longer they're stuck.
		var fails := int(level_fails.get(level, 0)) + 1
		level_fails[level] = fails
		var soften := 0.08 if fails < 3 else 0.12
		level_difficulty[level] = maxf(difficulty_for(level) - soften, base_difficulty(level) - 0.35)
	save_game()
	return {"delta": skill - before, "next": difficulty_for(level + 1)}


# --- Quiver (lives) ---------------------------------------------------------------------------

## The app was closed (swiped away / killed) in the middle of a level last time.
## Like Candy Crush: that level starts over, and if a move was made it costs a quiver arrow.
func _settle_abandoned_level() -> void:
	const RESUME_PATH := "user://resume_level.save"
	if not FileAccess.file_exists(RESUME_PATH):
		return
	var state: Variant = str_to_var(FileAccess.get_file_as_string(RESUME_PATH))
	DirAccess.remove_absolute(RESUME_PATH)
	if not state is Dictionary:
		return
	var level := int(state.get("level", 0))
	var daily := int(state.get("daily", -1)) >= 0
	if int(state.get("taps", 0)) > 0 and not bool(state.get("charged", false)) and level_costs_arrow(level, daily):
		spend_arrow()
		quit_notice = "You left Level %d - 1 arrow used." % level



## Does trying this level cost a quiver arrow?
func level_costs_arrow(level: int, daily: bool) -> bool:
	return not daily and level > QUIVER_FREE_UNTIL


## Adds the arrows that refilled while the player was away. Call before reading `quiver`.
func refresh_quiver() -> void:
	var now := int(Time.get_unix_time_from_system())
	if quiver >= QUIVER_MAX:
		quiver_stamp = now
		return
	if quiver_stamp > now:
		quiver_stamp = now  # the clock was turned back
	@warning_ignore("integer_division")
	var gained := (now - quiver_stamp) / QUIVER_REFILL_SEC
	if gained > 0:
		quiver = mini(QUIVER_MAX, quiver + gained)
		quiver_stamp += gained * QUIVER_REFILL_SEC
		if quiver >= QUIVER_MAX:
			quiver_stamp = now
		save_game()


## Seconds until the next arrow refills (0 when the quiver is full).
func quiver_wait() -> int:
	refresh_quiver()
	if quiver >= QUIVER_MAX:
		return 0
	return maxi(0, quiver_stamp + QUIVER_REFILL_SEC - int(Time.get_unix_time_from_system()))


func spend_arrow() -> void:
	refresh_quiver()
	if quiver >= QUIVER_MAX:
		quiver_stamp = int(Time.get_unix_time_from_system())
	quiver = maxi(0, quiver - 1)
	save_game()


func add_arrows(amount: int) -> void:
	refresh_quiver()
	quiver = mini(QUIVER_MAX, quiver + amount)
	save_game()


## "12:05" style countdown.
func clock_text(seconds: int) -> String:
	@warning_ignore("integer_division")
	return "%d:%02d" % [seconds / 60, seconds % 60]


## Adds (or with a negative amount, spends) power charges. Returns false if
## there was nothing to change (already full, or none left to spend).
func add_power(amount: int) -> bool:
	var before := power_charges
	power_charges = clampi(power_charges + amount, 0, MAX_POWER)
	save_game()
	return power_charges != before


## Coins: earn with `add_coins`, pay with `spend_coins` (false = not enough, nothing spent).
func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	save_game()


func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	save_game()
	return true


## How many of a booster ("drill" / "bomb" / "laser" / "rainbow" / "hint") are in stock.
func booster_count(kind: String) -> int:
	match kind:
		"drill":
			return power_charges
		"hint":
			return bonus_hints
	return int(boosters.get(kind, 0))


## Adds (or with a negative amount, uses) boosters. Returns false if nothing changed.
func add_booster(kind: String, amount: int) -> bool:
	match kind:
		"drill":
			return add_power(amount)
		"hint":
			var before := bonus_hints
			bonus_hints = maxi(0, bonus_hints + amount)
			save_game()
			return bonus_hints != before
	var had := int(boosters.get(kind, 0))
	boosters[kind] = clampi(had + amount, 0, MAX_BOOSTER)
	save_game()
	return boosters[kind] != had


## True once the player has reached the level this power unlocks at.
func booster_unlocked(kind: String) -> bool:
	return unlocked_level >= int(BOOSTER_UNLOCK.get(kind, 1))


## Powers that are unlocked but not introduced yet (the Drill is taught by the tutorial).
func new_unlocks() -> Array[String]:
	var out: Array[String] = []
	for kind: String in BOOSTERS:
		if kind != "drill" and booster_unlocked(kind) and not boosters_seen.has(kind):
			out.append(kind)
	return out


## Marks a power as introduced and gives the free ones to try.
func claim_unlock(kind: String) -> void:
	if boosters_seen.has(kind):
		return
	boosters_seen.append(kind)
	add_booster(kind, UNLOCK_GIFT)  # also saves


## Buys one booster with coins. Returns false if there are not enough coins or the stock is full.
func buy_booster(kind: String) -> bool:
	var cap := MAX_POWER if kind == "drill" else (99 if kind == "hint" else MAX_BOOSTER)
	if not booster_unlocked(kind) or booster_count(kind) >= cap or not spend_coins(int(PRICES[kind])):
		return false
	add_booster(kind, 1)
	return true


## "Delete my data": wipes the save file and every in-memory value back to defaults.
func reset_all_data() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	unlocked_level = 1
	current_level = 1
	stars = {}
	power_charges = 1
	coins = START_COINS
	boosters = {"bomb": 0, "laser": 0, "rainbow": 0}
	boosters_seen = []
	quiver = QUIVER_MAX
	quiver_stamp = 0
	skill = 0.0
	pace = 0.0
	accuracy = 0.7
	levels_played = 0
	last_performance = 0.5
	level_difficulty = {}
	level_fails = {}
	last_played_day = -1
	comeback = false
	sound_on = true
	vibration_on = true
	music_on = true
	if _music:
		_fade_music_in()
	terms_accepted = false
	personalized_ads = true
	analytics_on = true
	zoom_tip_seen = false
	tutorial_done = false
	seen_features = {}
	streak = 0
	streak_last_day = -1
	streak_best = 0
	streak_freeze_day = -100
	bonus_hints = 0
	daily_done = {}
	daily_unlocked = {}


# --- Days, streak and daily challenge -------------------------------------------------------

## Day number in the player's own time zone (for the streak).
## Free-coin videos the player may still watch today (resets at local midnight).
func coin_videos_left() -> int:
	if _coin_video_day != local_day():
		return COIN_VIDEOS_PER_DAY
	return maxi(0, COIN_VIDEOS_PER_DAY - _coin_videos)


## A free-coin video was watched to the end: count it for today.
func count_coin_video() -> void:
	if _coin_video_day != local_day():
		_coin_video_day = local_day()
		_coin_videos = 0
	_coin_videos += 1
	save_game()


func local_day() -> int:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	return int(floor((Time.get_unix_time_from_system() + bias * 60.0) / 86400.0))


## Day number in UTC (the daily challenge is the same maze for everyone that day).
func utc_day() -> int:
	return int(floor(Time.get_unix_time_from_system() / 86400.0))


## "October 15" for a UTC day number.
func day_label(day: int) -> String:
	var dt := Time.get_date_dict_from_unix_time(day * 86400)
	return "%s %d" % [MONTHS[int(dt.month) - 1], int(dt.day)]


## Call on every win. The first win of a day grows the streak and returns
## {streak, cycle_day (1..7), reward}; later wins that day return {}.
func register_win() -> Dictionary:
	var today := local_day()
	if streak_last_day == today:
		return {}
	streak = streak + 1 if streak_last_day == today - 1 else 1
	streak_last_day = today
	streak_best = maxi(streak_best, streak)
	save_game()
	var idx := (streak - 1) % STREAK_REWARDS.size()
	return {"streak": streak, "cycle_day": idx + 1, "reward": STREAK_REWARDS[idx]}


## Adds a streak reward (hints go to the hint bank, power to the stock).
func give_reward(reward: Dictionary, times: int = 1) -> void:
	bonus_hints += int(reward.get("hints", 0)) * times
	power_charges = mini(power_charges + int(reward.get("power", 0)) * times, MAX_POWER)
	save_game()


## Has the streak broken since the last win? {} = all good, otherwise
## {lost: days, can_save: true if only one day was missed and no save this week}.
func check_streak() -> Dictionary:
	if streak <= 0:
		return {}
	var today := local_day()
	if streak_last_day >= today - 1:
		return {}
	var can_save := streak_last_day == today - 2 and today - streak_freeze_day >= 7
	return {"lost": streak, "can_save": can_save}


## Streak freeze (after a rewarded video): yesterday counts as played.
func save_streak() -> void:
	streak_last_day = local_day() - 1
	streak_freeze_day = local_day()
	save_game()


func break_streak() -> void:
	streak = 0
	save_game()


## Today's challenge, past days opened with a video, or already finished days.
func daily_available(day: int) -> bool:
	return day == utc_day() or daily_unlocked.has(day) or daily_done.has(day)


## Records a finished daily challenge. Returns true the first time (gives +1 Power).
func complete_daily(day: int, earned_stars: int) -> bool:
	var first := not daily_done.has(day)
	daily_done[day] = maxi(int(daily_done.get(day, 0)), earned_stars)
	if first:
		power_charges = mini(power_charges + 1, MAX_POWER)
	save_game()
	return first


func toggle_sound() -> void:
	sound_on = not sound_on
	save_game()


func toggle_vibration() -> void:
	vibration_on = not vibration_on
	save_game()


func toggle_music() -> void:
	music_on = not music_on
	save_game()
	if music_on:
		_fade_music_in()
	elif _music.playing:
		_kill_music_tween()
		_music_tween = create_tween()
		_music_tween.tween_property(self, "_music_base_db", -60.0, 0.5)
		_music_tween.tween_callback(_music.stop)


## The same tune, slightly higher or lower (and a touch faster / slower): set by each
## screen and world so the music feels a little different in different places.
func set_music_pitch(pitch: float) -> void:
	if not _music:
		return
	_kill_music_tween()
	_music_tween = create_tween()
	_music_tween.tween_property(self, "_music_pitch", pitch, 1.5).set_trans(Tween.TRANS_SINE)
	if music_on and _music_base_db < MUSIC_DB:
		_music_tween.parallel().tween_property(self, "_music_base_db", MUSIC_DB, 1.0)


## Pitch for a level: every world its own shade of the tune; the wavy jungle lower.
static func music_pitch_for(level: int, daily: bool) -> float:
	if daily:
		return 1.06
	const SHADES := [1.0, 0.97, 1.03, 0.95, 1.05, 0.92]
	return SHADES[Worlds.of(level) % SHADES.size()]


func _fade_music_in() -> void:
	_kill_music_tween()
	if not _music.playing:
		_music_base_db = -40.0
		_music.play()
	_music_tween = create_tween()
	_music_tween.tween_property(self, "_music_base_db", MUSIC_DB, 1.5)


## The music steps back for a moment: `db` quieter (and `pitch` slower) for `hold` seconds,
## then eases back. Overlapping dips keep the deepest one.
func duck_music(db: float, hold: float, pitch := 1.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var active := now < _duck_until
	_duck_db = maxf(_duck_db if active else 0.0, db)
	_duck_pitch = minf(_duck_pitch if active else 1.0, pitch)
	_duck_until = maxf(_duck_until, now + hold)


func _process(delta: float) -> void:
	if not _music:
		return
	var dt := delta / maxf(Engine.time_scale, 0.05)  # real time: hit-stops don't freeze it
	var now := Time.get_ticks_msec() / 1000.0
	var want_db := _duck_db if now < _duck_until else 0.0
	var want_pitch := _duck_pitch if now < _duck_until else 1.0
	# Dip fast (60 dB/s), come back slowly (10 dB/s) - it breathes rather than pumps.
	_duck_cur = move_toward(_duck_cur, want_db, dt * (60.0 if want_db > _duck_cur else 10.0))
	_pitch_cur = lerpf(_pitch_cur, want_pitch, 1.0 - exp(-dt * (8.0 if want_pitch < _pitch_cur else 2.5)))
	_music.volume_db = _music_base_db - _duck_cur
	_music.pitch_scale = clampf(_music_pitch * _pitch_cur, 0.5, 2.0)


## Music pauses while the app is in the background or a full-screen ad is up.
func _notification(what: int) -> void:
	if not _music:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_music.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_music.stream_paused = false


func _kill_music_tween() -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()


var test_insets := Vector2.ZERO  # pretend to be a phone with a notch (desktop layout checks)


## Room the phone itself takes from the edges of the screen, in game units:
## x = top (status bar, notch, punch-hole camera), y = bottom (gesture / navigation bar).
## Every screen pads its top and bottom by this so nothing hides under the camera.
## 0 on desktop.
func safe_insets() -> Vector2:
	if test_insets != Vector2.ZERO:
		return test_insets
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var win_pos := Vector2(DisplayServer.window_get_position())
	var win_size := Vector2(DisplayServer.window_get_size())
	if win_size.y <= 0.0:
		return Vector2.ZERO
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var k := get_viewport().get_visible_rect().size.y / win_size.y
	var top := maxf(0.0, safe.position.y - win_pos.y)
	var bottom := maxf(0.0, win_pos.y + win_size.y - safe.end.y)
	return Vector2(top, bottom) * k


## Short haptic buzz on phones (needs the VIBRATE permission in the Android preset).
func vibrate(ms: int) -> void:
	if vibration_on and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


# --- Sound effects (synthesised, so no audio files are needed) -------------------------

## `pitch` > 1 plays higher - used to make chain reactions climb up the scale.
func play_sfx(sfx_name: String, pitch: float = 1.0) -> void:
	if not sound_on or not _sounds.has(sfx_name):
		return
	if DUCKS.has(sfx_name) and music_on:
		var d: Array = DUCKS[sfx_name]
		duck_music(d[0], d[1], d[2])
	var stream: Variant = _sounds[sfx_name]
	if stream is Array:
		stream = stream[randi() % stream.size()]  # several takes: never the same twice in a row feel
	for player in _players:
		if not player.playing:
			player.stream = stream
			player.pitch_scale = clampf(pitch, 0.5, 2.5)
			player.play()
			return
	# Every voice busy (a big volley): take over the one that has rung the longest,
	# whose tail is the quietest by now, so the new sound is never dropped.
	var oldest: AudioStreamPlayer = _players[0]
	for player in _players:
		if player.get_playback_position() > oldest.get_playback_position():
			oldest = player
	oldest.stream = stream
	oldest.pitch_scale = clampf(pitch, 0.5, 2.5)
	oldest.play()


func _build_sounds() -> void:
	# Soft recorded sounds made for Arrow Crush (see res://audio/AUDIO-LICENSE.txt).
	_sounds["tap"] = load("res://audio/sfx_tap.ogg")
	_sounds["slide"] = [load("res://audio/sfx_slide_a.ogg"), load("res://audio/sfx_slide_b.ogg")]
	_sounds["quit"] = load("res://audio/sfx_quit.ogg")  # leaving a level: a gentle heart-break
	_sounds["thud"] = _make_wav([_tone(150.0, 55.0, 0.18, 0.75)])
	_sounds["star"] = _make_wav([_tone(1200.0, 1600.0, 0.12, 0.25)])
	_sounds["crush"] = _make_wav([_tone(900.0, 260.0, 0.14, 0.45)])
	_sounds["boom"] = _make_wav([_tone(130.0, 35.0, 0.45, 0.85)])
	_sounds["laser"] = _make_wav([_tone(2200.0, 500.0, 0.28, 0.3)])
	_sounds["power"] = _make_wav([_tone(300.0, 1800.0, 0.35, 0.35)])
	_sounds["charge"] = _make_wav([_tone(660.0, 660.0, 0.07, 0.25), _tone(880.0, 880.0, 0.07, 0.25), _tone(1320.0, 1320.0, 0.15, 0.25)])
	_sounds["pop"] = _make_wav([_tone(700.0, 1500.0, 0.05, 0.4), _tone(1800.0, 900.0, 0.06, 0.2)])
	_sounds["thunk"] = _make_wav([_tone(220.0, 90.0, 0.09, 0.8), _tone(1400.0, 1400.0, 0.12, 0.2)])
	# Final Volley: three recorded takes (ElevenLabs, made for Arrow Crush), picked at random.
	_sounds["firework"] = [load("res://audio/sfx_firework_1.ogg"), load("res://audio/sfx_firework_2.ogg"),
		load("res://audio/sfx_firework_3.ogg")]
	_sounds["crack"] = _make_wav([_tone(2600.0, 1800.0, 0.04, 0.3), _tone(3200.0, 1200.0, 0.08, 0.2)])
	_sounds["wood"] = _make_wav([_tone(260.0, 140.0, 0.07, 0.7), _tone(520.0, 300.0, 0.05, 0.25)])
	_sounds["hint"] = _make_wav([_tone(990.0, 990.0, 0.08, 0.25), _tone(1320.0, 1320.0, 0.12, 0.25)])
	_sounds["win"] = load("res://audio/sfx_win_jingle.ogg")  # level-complete jingle (ElevenLabs)
	_sounds["smash"] = _smash()
	_sounds["whoosh"] = _whoosh()
	# Recorded sounds from Kenney (www.kenney.nl), CC0 / public domain - see res://audio.
	for pair in [["thunk_wood", "impactWood_heavy_000"], ["slam", "impactPunch_heavy_000"],
			["land", "impactSoft_medium_000"], ["glass", "impactGlass_light_000"],
			["plank", "impactPlank_medium_000"], ["glint", "glass_002"],
			["ding", "confirmation_002"], ["click", "click_002"]]:
		_sounds[pair[0]] = load("res://audio/%s.ogg" % pair[1])
	_sounds["lose"] = _make_wav([
		_tone(392.0, 392.0, 0.15, 0.3), _tone(330.0, 330.0, 0.15, 0.3), _tone(262.0, 200.0, 0.35, 0.3),
	])


## Air rushing past a flying arrow: noise through a filter that opens and closes.
func _whoosh() -> AudioStreamWAV:
	var count := int(MIX_RATE * 0.32)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var low := 0.0
	var band := 0.0
	for i in count:
		var t := float(i) / count
		var open := 0.04 + 0.32 * sin(t * PI)  # filter opens as the arrow passes
		low += (rng.randf_range(-1.0, 1.0) - low) * open
		band += (low - band) * 0.5
		var env := pow(sin(t * PI), 1.6)
		data.encode_s16(i * 2, int(clampf((low - band) * 2.6 * env, -1.0, 1.0) * 0.8 * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav


## The logo arrow breaking out of its tile: a deep punch, a sharp crack, a burst of
## shattering noise and a sprinkle of glassy tinkles, mixed together (not one after another).
func _smash() -> AudioStreamWAV:
	var count := int(MIX_RATE * 0.75)
	var mix := PackedFloat32Array()
	mix.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026  # same sound every launch
	var phase := 0.0
	var prev_noise := 0.0
	var low := 0.0
	for i in count:
		var t := float(i) / MIX_RATE
		# Punch: a sine diving from 150 Hz to 40 Hz, with a quick attack.
		phase += TAU * (40.0 + 110.0 * exp(-t * 14.0)) / MIX_RATE
		var punch := sin(phase) * (1.0 - exp(-t * 900.0)) * exp(-t * 7.0) * 0.85
		# Crack: bright noise (high-passed) that dies in a few milliseconds.
		var noise := rng.randf_range(-1.0, 1.0)
		var bright := noise - prev_noise
		prev_noise = noise
		var crack := bright * exp(-t * 70.0) * 0.55
		# Shatter: mid noise (low-passed a little) fading over half a second.
		low += (noise - low) * 0.35
		var shatter := (low * 0.6 + bright * 0.25) * exp(-t * 6.5) * 0.32
		mix[i] = punch + crack + shatter
	# Tinkles: short high pings from flying shards.
	for g in 16:
		var start := int(MIX_RATE * rng.randf_range(0.02, 0.4))
		var freq := rng.randf_range(2400.0, 6200.0)
		var length := int(MIX_RATE * rng.randf_range(0.05, 0.14))
		var amp := rng.randf_range(0.05, 0.13) * (1.0 - float(start) / (MIX_RATE * 0.5))
		for j in length:
			if start + j >= count:
				break
			var tt := float(j) / MIX_RATE
			mix[start + j] += sin(TAU * freq * tt) * exp(-tt * 45.0) * amp * minf(1.0, j / 20.0)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var fade := minf(1.0, float(count - i) / 400.0)  # no click at the end
		data.encode_s16(i * 2, int(tanh(mix[i] * 1.3) * 0.92 * fade * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav


## One tone as raw 16-bit mono PCM; the pitch glides from f_start to f_end.
func _tone(f_start: float, f_end: float, duration: float, volume: float) -> PackedByteArray:
	var count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		phase += TAU * lerpf(f_start, f_end, t) / MIX_RATE
		var envelope := minf(1.0, i / 120.0) * (1.0 - t)
		data.encode_s16(i * 2, int(sin(phase) * envelope * volume * 32767.0))
	return data


func _make_wav(parts: Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	for part: PackedByteArray in parts:
		data.append_array(part)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav
