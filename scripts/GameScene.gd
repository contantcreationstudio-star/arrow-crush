extends Node2D
## Arrow Crush - main controller: level state, lives, HUD, popups and "juice"
## (progress bar, difficulty banner, stars, confetti). Arrows live in MazeBoard / ArrowPath.

signal helper_used(kind: String)   # "hint" / "power" - the tutorial listens for these

const MAX_HEARTS := 3
const UNDOS_PER_LEVEL := 2    # levels 1-10; later levels get HELPERS_FROM_11 (see start_level)
const HINTS_PER_LEVEL := 0     # no free hints: a hint comes from a video (1 per ad), the shop or streak rewards
const HELPERS_FROM_11 := 1
# Booster buttons in the bottom bar (the drill is the original Super Power button).
const BOOSTER_ICONS := {"bomb": "res://icons/bomb.svg", "laser": "res://icons/laser.svg", "rainbow": "res://icons/rainbow.svg"}
const BOOSTER_BANNERS := {"drill": "SMASH", "bomb": "MEGA BOOM", "laser": "CROSS LASER", "rainbow": "COLOR WIPE"}
const STREAK_FOR_POWER := 8   # correct taps in a row (no mistakes) that earn +1 power
const POWER_COLOR := Color("#d97706")
const TIP_TEXT := "Same colour arrows CRUSH! Chain 3+ for special arrows"
const ZOOM_TIP_TEXT := "Pinch to zoom - double-tap to fit"
const LEVEL_SELECT := "res://scenes/Home.tscn"  # Main tab
const DAILY_SCENE := "res://scenes/Home.tscn"   # opens on the Daily tab (GameData.daily_day >= 0)
const HEART_ON := Color.WHITE                     # the heart icon is already red and glossy
const HEART_OFF := Color(0.45, 0.4, 0.65, 0.45)   # a spent heart: a dim violet ghost
const HEART_FULL_TEX := preload("res://icons/fx/hud_heart.png")
const HEART_EMPTY_TEX := preload("res://icons/fx/hud_heart_empty.png")
const STAR_ON := Color("#fbbf24")
const STAR_OFF := Color("#e2e8f0")
const STAR_ON_TEX := preload("res://icons/star_on.svg")
const BANNER_VOLLEY := preload("res://icons/fx/banner_final_volley.png")
const BANNER_ALL_GOALS := preload("res://icons/fx/banner_all_goals.png")
const BANNER_VICTORY := preload("res://icons/fx/banner_victory.png")
const HUD_OVER_BOARD := 50     # draw order of the top bar and the dock: above flying arrows
const DOCK_BTN := 88.0         # power keys on the dock (6 keys fit with room to the edges)
const DOCK_GAP := 14
const DOCK_ICONS := {"undo": preload("res://icons/fx/pw_undo.png"), "drill": preload("res://icons/fx/pw_smash.png"),
	"bomb": preload("res://icons/fx/pw_bomb.png"), "laser": preload("res://icons/fx/pw_laser.png"),
	"rainbow": preload("res://icons/fx/pw_rainbow.png"), "hint": preload("res://icons/fx/pw_hint.png")}
const POWER_BANNER := preload("res://icons/fx/banner_new_power.png")
const POWER_SUNBURST := preload("res://icons/fx/pw_sunburst.png")
const POWER_ICONS := {"bomb": preload("res://icons/fx/pw_bomb.png"), "laser": preload("res://icons/fx/pw_laser.png"),
	"rainbow": preload("res://icons/fx/pw_rainbow.png"), "drill": preload("res://icons/fx/pw_smash.png")}
const STAR_OFF_TEX := preload("res://icons/star_off.svg")
# Level goals (LevelGenerator.goal_for): a move limit, a clock, both, or neither.
# The clock lives in the difficulty badge (badge keeps its tier colour); moves sit
# next to the hearts. Both get tighter as the levels go up.
const ESCAPE_BONUS := 2.0      # clock: every single arrow that flies out
const CRUSH_BONUS := 5.0       # clock: same-colour crush (2 arrows in one tap)
const CHAIN_PER_ARROW := 3.0   # clock: chain of 3+ arrows, per arrow (3 arrows = +9s)
const AD_SECONDS := 20.0       # "Time's Up" rewarded video
const AD_MOVES := 5            # "Out of Moves" rewarded video
const TIME_COLOR := Color("#dc2626")
const MOVES_COLOR := Color("#2563eb")
const BOTH_COLOR := Color("#7c3aed")
const BONUS_COLOR := Color("#16a34a")
## One-time tips the first time each goal shows up.
const GOAL_TIPS := {
	5: "Limited moves! Crush same colours to save moves",
	10: "Beat the clock! Every crush adds extra seconds",
	17: "Moves AND clock! Crush to save both",
}
## The level each board piece first shows up (LevelGenerator.features_for): banner + tip.
## The first time a player meets a board piece (on whatever level): banner + tip.
const FEATURE_INTROS := {
	"balloons": ["POP THE BALLOONS!", "Pop all balloons too! Clear arrows next to them or fly through them"],
	"color": ["COLOUR ORDER!", "Clear the arrows of the colour shown in the goal card too!"],
	"crates": ["NEW: CRATES!", "Crates block the way. Shoot arrows into them or clear arrows beside them"],
	"targets": ["NEW: TARGETS!", "Hit every target too! Fly arrows out through the bullseyes"],
	"ice": ["NEW: ICE SHIELD!", "Frozen arrows can't move. Shoot them or clear their neighbours to crack the ice"],
	"mirrors": ["NEW: MIRRORS!", "Mirrors turn arrows 90 degrees - follow the lane!"],
	"golden": ["GOLDEN ARROW!", "Fly the golden arrow out! Nothing can crush or blast it"],
	"bonus": ["BONUS ARROW!", "Fly the coin arrow out before its count hits 0 for +15 coins!"],
	"links": ["LINKED ARROWS!", "Chained arrows only fly out together - clear both lanes"],
	"flips": ["FLIP ARROW!", "This arrow turns around after every move - tap it at the right time"],
	"chain": ["CHAIN CRUSH!", "Same-colour arrows in a line? Tap the first one - the whole line crushes!"],
	"prism": ["NEW: PRISM ARROW!", "Any colour crushes a prism - and the chain carries on in the prism's colour!"],
	"wavy": ["SNAKE ARROWS!", "Long wavy arrows! Only the head decides where it flies - the body just follows"],
	"creep": ["ARROWS ON THE MOVE!", "Arrows slide into gaps - and a same colour just ahead gets pulled in and CRUSHED!"],
}
const GOAL_DONE_COLOR := Color("#16a34a")
const GOAL_INK := Color("#3b0764")      # numbers on the cream goal card
const VOLLEY_SHOTS := 12      # most fireworks the Final Volley fires
const PICTURE_HOLD := 1.5     # seconds the finished painting stays in full view before the win card
## The level in progress, saved on this phone only (never sent anywhere): if the app is
## closed, killed or crashes mid-level - a phone call, a stuck ad - the player continues
## right where they were instead of starting over.
const RESUME_PATH := "user://resume_level.save"

# Header ribbon colours per difficulty tier: [face, dark edge]
const RIBBON_COLORS := [
	[Color("#fbbf24"), Color("#b45309")],  # Easy - gold pill (UI kit v2)
	[Color("#fbbf24"), Color("#b45309")],  # Normal - gold pill
	[Color("#f97316"), Color("#c2410c")],  # Hard
	[Color("#ef4444"), Color("#b91c1c")],  # Super Hard
]
# Badge colours per difficulty tier: [background, text]
const TIER_COLORS := [
	[Color("#dcfce7"), Color("#15803d")],  # Easy
	[Color("#dbeafe"), Color("#1d4ed8")],  # Normal
	[Color("#ffedd5"), Color("#c2410c")],  # Hard
	[Color("#fee2e2"), Color("#b91c1c")],  # Super Hard
]

@onready var maze: MazeBoard = %Maze
@onready var hud: CanvasLayer = $HUD
@onready var board_space: Control = %BoardSpace
@onready var back_button: Button = %BackButton
@onready var level_label: Label = %LevelLabel
@onready var hearts_row: HBoxContainer = %HeartsRow
@onready var settings_button: Button = %SettingsButton
@onready var difficulty_badge: PanelContainer = %DifficultyBadge   # the level pill, tinted by tier
@onready var quiver_label: Label = %QuiverLabel
@onready var big_number: Label = %BigNumber     # moves left (or the clock, or "∞")
@onready var big_caption: Label = %BigCaption
@onready var clock_label: Label = %ClockLabel   # the clock when a level has moves AND a clock
@onready var goal_row: HBoxContainer = %GoalRow
@onready var mascot: Mascot = %Mascot
@onready var header: HeaderBg = $HUD/Margin/VBox/Header
@onready var progress: BowMeter = %Progress
@onready var tip_label: Label = %TipLabel
@onready var undo_button: Button = %UndoButton
@onready var undo_badge: Label = %UndoBadge
@onready var power_button: PowerButton = %PowerButton
@onready var power_badge: Label = %PowerBadge
@onready var hint_button: Button = %HintButton
@onready var hint_badge: Label = %HintBadge
@onready var banner: Label = %Banner
@onready var result_popup: Control = %ResultPopup
@onready var result_panel: Control = %ResultPanel
@onready var result_title: Label = %ResultTitle
@onready var stars_row: HBoxContainer = %Stars
@onready var result_message: Label = %ResultMessage
@onready var next_button: Button = %NextButton
@onready var retry_button: Button = %RetryButton
@onready var continue_button: Button = %ContinueButton


var level := 1
var lives := MAX_HEARTS
var undos_left := UNDOS_PER_LEVEL
var hints_left := HINTS_PER_LEVEL
var total_arrows := 0
var streak := 0               # correct taps in a row since the last mistake
var playing := false

# What the player did this level - fed to GameData's behaviour model at the end.
var taps := 0
var mistakes := 0
var hints_used := 0
var undos_used := 0
var powers_used := 0
var started_msec := 0
var _power_pulse: Tween
var _armed := ""                 # booster waiting for an arrow tap ("" = none)
var _booster_buttons := {}       # kind -> Button
var _coin_continue: Button       # result popup: keep playing for coins
var _tutorial: Tutorial = null
var _is_tutorial_level := false
var _daily := -1                 # UTC day of the daily challenge being played, -1 = normal level
var has_clock := false           # this level is played against the clock
var has_moves := false           # this level has a move limit
var _tier := 0                   # difficulty tier of this level (badge colour)
var time_left := 0.0
var moves_left := 0
var _clock_delay := 0.0          # the clock waits for the intro animation
var _fail := ""                  # why the result popup is showing: "hearts" / "time" / "moves" / "goals"
var _goal_balloons := 0          # balloon layers this level started with (0 = no balloon goal)
var _goal_targets := 0           # targets this level started with
var _goal_crates := 0            # crate layers this level started with
var _goal_ice := 0               # ice layers this level started with
var _order_color := -1           # colour order: arrows of this colour to clear (-1 = none)
var _order_count := 0
var _goal_golden := 0            # golden arrows to fly out
var _crush_goal := 0             # THE goal of the level: arrows to crush (0 = old "clear the board" rules)
var _last_crushed := 0           # maze.crushed after the previous move (did that move crush anything?)
var _crush_warned := false       # the "crush, don't fly out!" warning was shown this level
var _goal_labels := {}           # goal card: "balloons" / "targets" / "arrows" -> Label
var _costs_arrow := false        # losing / leaving this level costs a quiver arrow
var _charged := false            # the arrow for this attempt was already taken
var _finishing := false          # the win celebration (release + Final Volley) is running
var _count_tween: Tween          # the moves counter rolling up at the start of a level
var _beat := 0.0                 # heartbeat clock for the hearts row
var _popup_layer: CanvasLayer    # holds the result popup above everything on the board
var _reward_row: HBoxContainer   # win card: coin / hint / power chips under the stars
var _level_data := {}            # the level as generated (saved with the board to resume it)
var _timer_chip: HBoxContainer       # goal card: stopwatch + time left (moves + clock levels)
var _timer_label: Label
var _fail_art: TextureRect          # fail card: alarm clock / empty quiver / cracked heart
var _fail_banner: TextureRect       # fail card: TIME'S UP! / OUT OF MOVES! / OUT OF HEARTS!
var _picture_frame: PanelContainer  # win card: the finished picture
var _save_dirty := false         # something changed since the level was last saved
var _paused_card := false        # the "Paused" card is showing
var _briefing := false           # the level-goal card is up; the level starts on its PLAY
var _held_banners: Array = []    # [text, colour] banners waiting for the goal card to close
var _new_piece := ""             # board piece met for the first time this level ("" = none)
var _lesson_busy := false        # a lesson is showing or about to
var _idle := 0.0                 # seconds since the last tap (the hint lesson waits for a stall)
# Pass proximity: after every tap we know how far the player is from the win. Falling
# behind only ever brings HELP (power charges faster, the hint button nudges, a shield);
# playing well never makes the level harder mid-way.
var _moves_start := 0            # moves this level started with (0 = no move limit)
var _time_start := 0.0           # seconds on the clock at the start (0 = no clock)
var _need_help := false          # struggling overall or stuck on this level (GameData.needs_help)
var _shield := 0                 # bumps that cost no heart (stuck on a level 2+ times)
var _nudges := 0                 # hint-button nudges shown this level (max 2)
# The next maze is built on a background thread while the win / fail card is up, so the
# level curtain never freezes while ~0.3-1.5 s of maze building runs.
var _pregen_thread: Thread = null
var _pregen_level := -1
var _pregen_diff := -1.0
var _in_flight := {}             # goal kind -> pieces flying up to the goal card (not counted yet)
var _fly_layer: CanvasLayer      # the flying goal pieces, above the HUD
var _flying := 0                 # pieces in the air right now (a big chain caps the show)
var _picked_boosters := {}       # goal card: boosters picked to start the level with (kind -> true)
const CHAIN_FOR := {"drill": 3, "bomb": 4, "laser": 5, "rainbow": 7}   # arrows in one tap for each special
var _away := false               # the app went to the background mid-level (clock frozen)
var _victory: VictoryScreen = null   # the full-screen win card while it is up
var _intro_hold := false         # the level curtain is up: the goal card waits for it to open
var _held_tier := 0              # tier of the level whose goal card is waiting
var _switching := false          # the curtain is closing on the way to another level


func _ready() -> void:
	maze.moved.connect(_on_moved)
	maze.combo_text.connect(_float_text)
	maze.arrow_blocked.connect(_on_arrow_blocked)
	maze.cleared.connect(_on_maze_cleared)
	maze.power_blast.connect(_on_power_blast)
	maze.zoomed.connect(_on_zoomed)
	maze.goals_changed.connect(_on_goals_changed)
	maze.special_made.connect(_on_special_made)
	maze.goal_piece.connect(_on_goal_piece)
	_fly_layer = CanvasLayer.new()
	_fly_layer.layer = 20
	add_child(_fly_layer)
	_build_goal_row()
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # long tips wrap instead of widening the HUD
	power_button.pressed.connect(_on_power)
	power_button.resized.connect(func() -> void: power_button.pivot_offset = power_button.size / 2)
	board_space.resized.connect(_fit_maze)
	result_panel.resized.connect(func() -> void: result_panel.pivot_offset = result_panel.size / 2)

	back_button.pressed.connect(_on_back)
	settings_button.pressed.connect(_on_pause_pressed)
	undo_button.pressed.connect(_on_undo)
	hint_button.pressed.connect(_on_hint)
	next_button.pressed.connect(_on_next_level)
	continue_button.pressed.connect(_on_continue_with_ad)
	retry_button.pressed.connect(func() -> void: _transition_to(level, false, retry_button.get_global_rect().get_center()))


	get_tree().quit_on_go_back = false  # the back key asks before quitting a level (see _notification)
	_build_booster_buttons()
	_build_coin_continue()
	GameSkin.apply(self)
	_add_press_feedback()
	_lift_result_popup()
	_build_reward_row()
	_apply_kit_v2()
	_style_banner()
	_fit_safe_area()
	# The level opens behind the curtain: its number (and a HARD stamp) first, then the board.
	_enter_level(LevelTransition.make(self, true), GameData.current_level, true)


## UI kit v2 touches that need the scene built: win-card order (stars on top with a warm
## glow, middle star raised), see-through goal chips on the violet header, and a lilac
## dock behind the booster buttons.
func _apply_kit_v2() -> void:
	var box := stars_row.get_parent()
	box.move_child(stars_row, 0)
	# Fail card art from Affinity: a big picture and a banner title, and the message wraps
	# so the card keeps a sensible width instead of running edge to edge.
	result_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_message.custom_minimum_size.x = 500
	result_message.add_theme_font_size_override("font_size", 26)
	_fail_art = TextureRect.new()
	_fail_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fail_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fail_art.custom_minimum_size = Vector2(0, 170)
	_fail_art.resized.connect(func() -> void: _fail_art.pivot_offset = _fail_art.size / 2.0)
	box.add_child(_fail_art)
	box.move_child(_fail_art, 0)
	_fail_banner = TextureRect.new()
	_fail_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fail_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fail_banner.custom_minimum_size = Vector2(0, 92)
	box.add_child(_fail_banner)
	box.move_child(_fail_banner, result_title.get_index())
	# The finished picture, framed like a little photo, under the title.
	_picture_frame = PanelContainer.new()
	var frame := GameSkin.box(Color("#f5f3ff"), GameSkin.CARD_LIP, 22, 6)
	frame.shadow_size = 0
	frame.set_content_margin_all(12)
	_picture_frame.add_theme_stylebox_override("panel", frame)
	_picture_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pic := Control.new()
	pic.custom_minimum_size = Vector2(230, 200)
	pic.draw.connect(func() -> void:
		if maze.cols == 0:
			return
		_draw_picture(pic))
	_picture_frame.add_child(pic)
	box.add_child(_picture_frame)
	box.move_child(_picture_frame, result_title.get_index() + 1)
	box.move_child(_reward_row, _picture_frame.get_index() + 1)
	stars_row.custom_minimum_size.y = 136
	for i in stars_row.get_child_count():
		var star := stars_row.get_child(i) as Control
		star.custom_minimum_size = Vector2.ONE * (128.0 if i == 1 else 100.0)
		star.size_flags_vertical = Control.SIZE_SHRINK_END if i != 1 else Control.SIZE_SHRINK_BEGIN
	stars_row.draw.connect(func() -> void:
		var c := stars_row.size / 2.0
		stars_row.draw_circle(c, stars_row.size.y * 0.62, Color("#fef3c7"), true, -1.0, true)
		stars_row.draw_circle(c, stars_row.size.y * 0.42, Color("#fde68a", 0.5), true, -1.0, true))

	# Top-right is the Pause key (the kit's layout); Settings lives inside the Pause card.
	# Gem keys from Affinity: back = a fletched arrow, pause = two standing arrows.
	for pair in [[back_button, "btn_back"], [settings_button, "btn_pause"]]:
		var b: Button = pair[0]
		b.icon = null
		b.custom_minimum_size = Vector2(70, 70)
		var up := StyleBoxTexture.new()
		up.texture = load("res://icons/fx/%s.png" % pair[1])
		var down := StyleBoxTexture.new()
		down.texture = load("res://icons/fx/%s_down.png" % pair[1])
		for st in ["normal", "hover", "focus"]:
			b.add_theme_stylebox_override(st, up)
		b.add_theme_stylebox_override("pressed", down)
	for h: TextureRect in hearts_row.get_children():
		h.texture = HEART_FULL_TEX
		h.custom_minimum_size = Vector2(28, 28)
	# The shield's top edge slopes down at the corners: drop the hearts inside it.
	var heart_gap := Control.new()
	heart_gap.custom_minimum_size = Vector2(0, 14)
	heart_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hearts_row.get_parent().add_child(heart_gap)
	hearts_row.get_parent().move_child(heart_gap, 0)
	hearts_row.add_theme_constant_override("separation", 2)
	# Goal card: a bright cream card with a gold rim and lip, so "what to do" stands out
	# on the violet header (a see-through card got lost there).
	var card := StyleBoxFlat.new()
	card.bg_color = Color("#fffbeb")
	card.set_corner_radius_all(26)
	card.set_border_width_all(3)
	card.border_width_bottom = 6
	card.border_color = Color("#f59e0b")
	card.shadow_color = Color(0.1, 0.02, 0.25, 0.45)
	card.shadow_size = 8
	card.shadow_offset = Vector2(0, 4)
	card.content_margin_left = 14
	card.content_margin_right = 18
	card.content_margin_top = 2
	card.content_margin_bottom = 2
	card.anti_aliasing = true
	(goal_row.get_parent() as Control).add_theme_stylebox_override("panel", card)
	var goal_tag := Label.new()
	goal_tag.text = "GOAL"
	goal_tag.add_theme_font_override("font", banner.get_theme_font("font"))
	goal_tag.add_theme_font_size_override("font_size", 18)
	goal_tag.add_theme_color_override("font_color", Color("#b45309"))
	goal_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	goal_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_row.add_child(goal_tag)
	goal_row.move_child(goal_tag, 0)
	# Timer chip (levels with moves AND a clock): stopwatch + time, first in the goal card.
	_timer_chip = HBoxContainer.new()
	_timer_chip.add_theme_constant_override("separation", 6)
	_timer_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var watch := TextureRect.new()
	watch.texture = preload("res://icons/fx/ic_timer.png")
	watch.custom_minimum_size = Vector2(40, 40)
	watch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	watch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_timer_chip.add_child(watch)
	_timer_label = Label.new()
	_timer_label.add_theme_font_override("font", banner.get_theme_font("font"))
	_timer_label.add_theme_font_size_override("font_size", 28)
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer_chip.add_child(_timer_label)
	_timer_chip.visible = false
	goal_row.add_child(_timer_chip)
	goal_row.move_child(_timer_chip, 1)  # after the GOAL tag
	# Booster buttons: a soft white highlight on the upper-left, like the kit's round keys.
	for b: Control in dock_buttons():
		b.draw.connect(func() -> void:
			b.draw_circle(b.size * Vector2(0.3, 0.24), b.size.x * 0.11, Color(1, 1, 1, 0.55), true, -1.0, true))

	# Power dock: Affinity icons on every key, and a lilac dock that hugs the keys
	# (with room to the screen edges) instead of running edge to edge.
	var dock_icons := {undo_button: DOCK_ICONS["undo"], power_button: DOCK_ICONS["drill"], hint_button: DOCK_ICONS["hint"]}
	for kind: String in BOOSTER_ICONS:
		dock_icons[_booster_buttons[kind]] = DOCK_ICONS[kind]
	for b: Button in dock_icons:
		b.icon = dock_icons[b]
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", int(DOCK_BTN * 0.84))
	var dock_bar := undo_button.get_parent() as BoxContainer
	dock_bar.add_theme_constant_override("separation", DOCK_GAP)
	var dock_margin := MarginContainer.new()
	dock_bar.get_parent().add_child(dock_margin)
	dock_bar.get_parent().move_child(dock_margin, dock_bar.get_index())
	dock_bar.reparent(dock_margin)
	for side in ["margin_left", "margin_right"]:
		dock_margin.add_theme_constant_override(side, 20)
	dock_margin.add_theme_constant_override("margin_top", 10)
	dock_margin.add_theme_constant_override("margin_bottom", 14)
	var dock := StyleBoxFlat.new()
	dock.bg_color = Color("#e9e3ff")
	dock.set_corner_radius_all(48)
	dock.border_width_bottom = 7
	dock.border_color = Color("#c4b5fd")
	dock.shadow_color = Color(0.1, 0.0, 0.3, 0.12)
	dock.shadow_size = 10
	dock.shadow_offset = Vector2(0, 4)
	dock.anti_aliasing = true
	dock_bar.draw.connect(func() -> void:
		# Only the keys on show: a hidden key keeps an old position and would pull the dock aside.
		var keys := dock_buttons().filter(func(k: Control) -> bool: return k.visible)
		if keys.is_empty():
			return
		var left: float = keys[0].position.x
		var right: float = keys[-1].position.x + keys[-1].size.x
		dock_bar.draw_style_box(dock, Rect2(Vector2(left - 22, -12), Vector2(right - left + 44, dock_bar.size.y + 24))))
	# Keys move whenever one is shown / hidden or the screen resizes: redraw the dock to follow.
	dock_bar.sort_children.connect(dock_bar.queue_redraw)
	dock_bar.resized.connect(dock_bar.queue_redraw)
	dock_bar.queue_redraw()
	# The top bar and the power dock sit above everything on the board, so an escaping
	# arrow (ArrowPath.FLY_Z) flies off screen UNDER them, never over them.
	header.z_index = HUD_OVER_BOARD
	dock_margin.z_index = HUD_OVER_BOARD


func dock_buttons() -> Array[Control]:
	var out: Array[Control] = []
	for c in (undo_button.get_parent() as Control).get_children():
		if c is Button:
			out.append(c)
	return out


## The row of reward chips on the win card, right under the stars.
func _build_reward_row() -> void:
	_reward_row = HBoxContainer.new()
	_reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_reward_row.add_theme_constant_override("separation", 14)
	_reward_row.visible = false
	var box := stars_row.get_parent()
	box.add_child(_reward_row)
	box.move_child(_reward_row, stars_row.get_index() + 1)


## Banners ("FINAL VOLLEY!", "HARD LEVEL"...) in the chunky title font with a white
## outline and a soft drop shadow, like the game logo.
func _style_banner() -> void:
	banner.add_theme_font_override("font", TitleLogo.FONT)
	banner.add_theme_font_size_override("font_size", 76)
	banner.add_theme_constant_override("outline_size", 22)
	banner.add_theme_color_override("font_outline_color", Color.WHITE)
	banner.add_theme_color_override("font_shadow_color", Color(0.1, 0.02, 0.25, 0.45))
	banner.add_theme_constant_override("shadow_offset_x", 0)
	banner.add_theme_constant_override("shadow_offset_y", 8)
	banner.add_theme_constant_override("shadow_outline_size", 22)


## The result popup gets its own canvas layer above the HUD. A z_index alone is not
## enough: the board sits inside a clipping container, and its marks (ice, flip badges,
## gold stars) could still draw over the popup.
func _lift_result_popup() -> void:
	_popup_layer = CanvasLayer.new()
	_popup_layer.layer = 35  # above the HUD (1) and tutorial (30), below ad / options / shop
	add_child(_popup_layer)
	result_popup.reparent(_popup_layer, false)
	result_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Keeps the header clear of the phone's camera / notch and the buttons clear of the
## gesture bar (the header's colour still runs up behind the camera).
func _fit_safe_area() -> void:
	var inset := GameData.safe_insets()
	header.add_theme_constant_override("margin_top", 20 + int(inset.x))
	($HUD/Margin as MarginContainer).add_theme_constant_override("margin_bottom", 48 + int(inset.y))


func _check_streak() -> void:
	if _is_tutorial_level:
		return
	var info := GameData.check_streak()
	if not info.is_empty():
		maze.input_enabled = false
		StreakPopup.show_broken(self, info).closed.connect(func() -> void: maze.input_enabled = playing)


func _exit_tree() -> void:
	get_tree().quit_on_go_back = true  # other screens: the phone's back key closes the app as before
	Engine.time_scale = 1.0  # never leave a hit-stop running when the scene closes
	_join_pregen()  # a background maze build must finish before the scene goes away


## Every HUD button squishes a little while pressed and springs back on release.
func _add_press_feedback() -> void:
	for node in hud.find_children("*", "Button", true, false):
		var b := node as Button
		b.button_down.connect(func() -> void:
			b.pivot_offset = b.size / 2.0
			create_tween().tween_property(b, "scale", Vector2.ONE * 0.9, 0.06))
		b.button_up.connect(func() -> void:
			create_tween().tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


func start_level(n: int) -> void:
	level = clampi(n, 1, GameData.MAX_LEVELS)
	GameData.current_level = level
	lives = MAX_HEARTS
	undos_left = UNDOS_PER_LEVEL if level <= 10 else HELPERS_FROM_11
	hints_left = HINTS_PER_LEVEL
	streak = 0
	taps = 0
	mistakes = 0
	hints_used = 0
	undos_used = 0
	powers_used = 0
	started_msec = Time.get_ticks_msec()
	playing = true
	_finishing = false
	_charged = false
	result_popup.hide()
	maze.input_enabled = true

	# First launch: the hand-made tutorial level. Otherwise the maze is built from the
	# player's behaviour model, not from the level number.
	_daily = GameData.daily_day
	GameData.set_music_pitch(GameData.music_pitch_for(level, _daily >= 0))
	_is_tutorial_level = _daily < 0 and level == 1 and not GameData.tutorial_done
	var data: Dictionary
	var saved := _read_resume()
	var resuming := not _is_tutorial_level and int(saved.get("level", -1)) == level \
		and int(saved.get("daily", -2)) == _daily and saved.get("data") is Dictionary \
		and saved.get("board") is Dictionary
	# A fresh level opens with the goal card (what to do, moves / time); a resumed one
	# just carries on.
	_briefing = not resuming
	_held_banners.clear()
	_in_flight.clear()
	_flying = 0
	if _fly_layer:
		for piece in _fly_layer.get_children():
			piece.queue_free()
	_idle = 0.0
	if resuming:
		data = saved.data  # the exact maze the player left
	elif _daily >= 0:
		data = LevelGenerator.daily_level(_daily)  # same maze on every phone today
	elif _is_tutorial_level:
		data = LevelGenerator.tutorial_level()
	else:
		var pre := _take_pregen(level)
		if pre.is_empty():
			data = LevelGenerator.generate(level, GameData.lock_difficulty(level), GameData.play_style(),
				LevelGenerator.features_for(level))
		else:
			data = pre
	_costs_arrow = GameData.level_costs_arrow(level, _daily >= 0) and not _is_tutorial_level
	if not resuming and _daily < 0 and GameData.needs_help(level) and int(data.get("creep_waves", 0)) > 1:
		data.creep_waves = int(data.creep_waves) - 1  # stuck here: a calmer board (help only, never harder)
	_level_data = data
	if resuming:
		maze.restore(data, saved.board)
	else:
		maze.build(data)
	_style_progress(maze.set_palette(level - 1))
	# Hard mazes give fewer free helpers - more help is one short video away.
	if data.difficulty >= 0.55:
		undos_left = 1
	total_arrows = maze.arrows.size()
	_fit_maze.call_deferred()  # wait for the HUD containers to lay out
	get_tree().create_timer(1.0).timeout.connect(_fit_maze)  # once more, after the layout has settled

	var tier: int = data.tier
	level_label.text = "Level %d" % level
	_style_badge(tier)
	mascot.calm()
	if _daily >= 0:
		level_label.text = GameData.day_label(_daily)
		_style_badge(LevelGenerator.Tier.NORMAL)
	_set_power_armed(false)
	if data.cols >= 16 and not GameData.zoom_tip_seen:
		tip_label.text = ZOOM_TIP_TEXT
		tip_label.visible = true
	_setup_goal(data, tier)  # shows the goal banner on moves / clock levels
	_moves_start = moves_left if has_moves else 0
	_time_start = time_left if has_clock else 0.0
	_setup_help(resuming)
	if not (has_moves or has_clock) and tier >= LevelGenerator.Tier.HARD and _daily < 0:
		_show_banner("HARD LEVEL" if tier == LevelGenerator.Tier.HARD else "SUPER HARD", TIER_COLORS[tier][1])
	_goal_balloons = maze.balloons_left()
	_goal_targets = maze.targets_left()
	_goal_crates = maze.crates_left()
	_goal_ice = maze.ice_left()
	_goal_golden = maze.golden_left()
	var order: Dictionary = data.get("color_order", {})
	_order_color = int(order.get("color", -1))
	_order_count = int(order.get("count", 0))
	_crush_goal = _crush_goal_for(data)
	_crush_warned = false
	if resuming:
		_apply_resume(saved)
	_last_crushed = maze.crushed
	for l: Label in _goal_labels.values():
		l.set_meta("shown", "")  # a new level: counts appear without the "changed" animation
	_update_goals()
	_new_piece = _introduce_new_piece(data)
	_refresh_hud()
	if _briefing:
		maze.input_enabled = false
		_held_tier = tier
		if not _intro_hold:
			_show_briefing.call_deferred(tier)
	else:
		_level_started()


## Starts building level `n` in the background (normal levels only).
func _pregenerate(n: int) -> void:
	if _daily >= 0 or n < 1 or n > GameData.MAX_LEVELS:
		return
	_join_pregen()
	var d := GameData.lock_difficulty(n)
	var style := GameData.play_style()
	var feats: Variant = LevelGenerator.features_for(n)
	_pregen_level = n
	_pregen_diff = d
	_pregen_thread = Thread.new()
	_pregen_thread.start(func() -> Dictionary: return LevelGenerator.generate(n, d, style, feats), Thread.PRIORITY_LOW)


## The maze built in the background for level `n`, or {} if there is none (or it was
## built for a difficulty that has changed since, e.g. after another loss).
func _take_pregen(n: int) -> Dictionary:
	if _pregen_thread == null:
		return {}
	var matches := _pregen_level == n and is_equal_approx(_pregen_diff, GameData.difficulty_for(n))
	var data: Variant = _join_pregen()
	return data if matches and data is Dictionary else {}


func _join_pregen() -> Variant:
	if _pregen_thread == null:
		return null
	var data: Variant = _pregen_thread.wait_to_finish() if _pregen_thread.is_started() else null
	_pregen_thread = null
	_pregen_level = -1
	return data


## Help for players who are stuck, decided once per attempt (never on the tutorial or
## the daily challenge, where everyone plays the same maze):
##   2+ losses here in a row -> one bump is forgiven (a shield, shown on a banner)
##   3+ losses here in a row -> a free hint for this try
func _setup_help(resuming: bool) -> void:
	_nudges = 0
	_shield = 0
	_need_help = false
	if _daily >= 0 or _is_tutorial_level:
		return
	_need_help = GameData.needs_help(level)
	var fails := int(GameData.level_fails.get(level, 0))
	if fails >= 2:
		_shield = 1
	if fails >= 3 and not resuming:
		hints_left += 1
	if resuming:
		return
	if fails >= 3:
		_held_banners.append(["FREE HINT + SHIELD!", GOAL_DONE_COLOR])
	elif fails >= 2:
		_held_banners.append(["SHIELD: 1 FREE BUMP", GOAL_DONE_COLOR])


## Pass proximity: is the player falling behind on this attempt? Compares how much of
## the board is cleared with how much of the moves / clock / hearts is used up.
func _behind() -> bool:
	if not playing or total_arrows <= 0:
		return false
	if lives == 1:
		return true
	var cleared := 1.0 - float(maze.arrows.size()) / total_arrows
	if _crush_goal > 0:
		cleared = float(maze.crushed) / _crush_goal
	var spent := 0.0
	if _moves_start > 0:
		spent = maxf(spent, 1.0 - float(moves_left) / _moves_start)
	if _time_start > 0.0:
		spent = maxf(spent, 1.0 - time_left / _time_start)
	return spent > cleared + 0.2


## Correct taps in a row that earn +1 power: fewer when the player could use a hand.
func _power_streak_need() -> int:
	return STREAK_FOR_POWER - 2 if _need_help or _behind() else STREAK_FOR_POWER


## The hint button gives a little bounce when the player has been stuck a while.
## It is only a pointer to help - no popup, no ad starts by itself.
func _nudge_hint() -> void:
	if maze.hint_arrow() == null:
		return
	_nudges += 1
	hint_button.pivot_offset = hint_button.size / 2.0
	var tw := create_tween()
	for i in 3:
		tw.tween_property(hint_button, "scale", Vector2.ONE * 1.18, 0.16).set_trans(Tween.TRANS_SINE)
		tw.tween_property(hint_button, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SINE)


## "So close" line for the fail card when only a few arrows were left.
func _near_miss(fallback: String) -> String:
	if _crush_goal > 0:
		var need := _crush_goal - maze.crushed
		if need > 0:
			if need <= 3:
				return "So close - only %d more crush%s!" % [need, "" if need == 1 else "es"]
			return fallback
	var left := maze.arrows.size()
	if left > 0 and left <= 3:
		return "So close - only %d arrow%s left!" % [left, "" if left == 1 else "s"]
	return fallback


## The level really begins (after the goal card's PLAY, or straight away when resuming):
## held banners play, then the tutorial / a lesson / a new power card if one is due.
func _level_started() -> void:
	_briefing = false
	maze.input_enabled = playing
	var delay := 0.1
	for b: Array in _held_banners:
		get_tree().create_timer(delay).timeout.connect(_show_banner.bind(b[0], b[1]))
		delay += 1.4
	_held_banners.clear()
	_apply_picked_boosters()
	if _is_tutorial_level:
		_start_lesson("level1")
		return
	if _daily < 0 and not GameData.new_unlocks().is_empty():
		get_tree().create_timer(0.6).timeout.connect(_introduce_new_power)
	if level == 2 and _lesson_due("bump"):
		_start_lesson("bump")
	elif level == 5 and _lesson_due("power"):
		_start_lesson("power")


## Lessons after level 1 are for players who did the new short level-1 tutorial (older
## players learned everything in the old one). Each shows once.
func _lesson_due(kind: String) -> bool:
	return _daily < 0 and not _lesson_busy and GameData.seen_features.has("lessons") \
		and not GameData.seen_features.has("lesson_" + kind)


## Shows one lesson (or the level-1 tutorial) after `delay` seconds.
func _start_lesson(kind: String, arrow: ArrowPath = null, delay: float = 1.3) -> void:
	if _lesson_busy:
		return
	_lesson_busy = true
	await get_tree().create_timer(delay).timeout
	if not playing or (arrow != null and not is_instance_valid(arrow)):
		_lesson_busy = false
		return
	_tutorial = Tutorial.new(self, maze)
	add_child(_tutorial)
	var tip_was := tip_label.visible
	tip_label.visible = false  # the lesson bubbles say it all
	_tutorial.finished.connect(func() -> void:
		_tutorial = null
		_lesson_busy = false
		_idle = 0.0
		tip_label.visible = tip_was or (kind == "level1" and level <= 3))
	if kind == "level1":
		_tutorial.run()
	else:
		_tutorial.lesson(kind, arrow)


## Hint lesson, when a player on an early level stalls or bumps: one free hint to try.
func _hint_lesson() -> void:
	if not playing or not _lesson_due("hint") or maze.hint_arrow() == null:
		return
	hints_left += 1
	_refresh_hud()
	_start_lesson("hint", null, 0.4)


## A goal piece was used up on the board: a copy flies up into its goal chip and the
## count there drops when it lands (Candy Crush style), with a pop and a bump.
func _on_goal_piece(kind: String, pos: Vector2, delay: float, tex: Texture2D, color: int) -> void:
	if kind == "arrow":
		if _order_color >= 0 and color == _order_color:
			kind = "color"
		elif _arrows_chip_shown():
			kind = "arrows"
		else:
			return
	elif kind == "crush":
		# The piece is sent right after the crush is counted: maze.crushed is its number.
		if _crush_goal <= 0 or maze.crushed > _crush_goal:
			return  # no crush goal, or it is already reached
	if not _goal_labels.has(kind):
		return
	var label: Label = _goal_labels[kind]
	var chip := label.get_parent() as Control
	if not chip.visible or _flying >= 14:
		return  # nothing to count, or a huge chain: the rest just count down
	var icon := chip.get_node("Icon") as TextureRect
	if tex == null:
		tex = icon.texture
	_in_flight[kind] = int(_in_flight.get(kind, 0)) + 1
	_flying += 1
	var start: Vector2 = maze.get_global_transform_with_canvas() * pos
	var piece := TextureRect.new()
	piece.texture = tex
	piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	piece.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	piece.size = Vector2(64, 64)
	piece.pivot_offset = piece.size / 2.0
	piece.modulate = icon.modulate if kind == "color" or kind == "arrows" else Color.WHITE
	piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	piece.visible = false
	_fly_layer.add_child(piece)
	var land := func() -> void:
		_in_flight[kind] = maxi(0, int(_in_flight.get(kind, 0)) - 1)
		_flying = maxi(0, _flying - 1)
		piece.queue_free()
		GameData.play_sfx("pop", randf_range(1.15, 1.45))
		_update_goals()
	var fly := func(t: float) -> void:
		# Up and over in a curve: a little hop first, then into the chip.
		var end := icon.get_global_rect().get_center()
		var ctrl := start.lerp(end, 0.35) + Vector2((start.x - end.x) * 0.25, -160.0)
		var a := start.lerp(ctrl, t)
		var b := ctrl.lerp(end, t)
		piece.position = a.lerp(b, t) - piece.size / 2.0
		var grow := 1.0 + 0.45 * sin(minf(t * 2.0, 1.0) * PI)
		piece.scale = Vector2.ONE * lerpf(grow, 0.6, clampf((t - 0.6) / 0.4, 0.0, 1.0))
	var tw := create_tween()
	tw.tween_interval(delay + 0.05)
	tw.tween_callback(func() -> void: piece.visible = true)
	tw.tween_method(fly, 0.0, 1.0, randf_range(0.55, 0.7)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(land)


## The first special arrow a chain makes: stop and show it.
func _on_special_made(arrow: ArrowPath) -> void:
	if not playing or _daily >= 0 or _lesson_busy:
		return
	var kind: String = GameData.BOOSTERS[int(arrow.special) - 1]
	if GameData.seen_features.has("made_" + kind):
		return
	GameData.seen_features["made_" + kind] = true
	GameData.save_game()
	await get_tree().create_timer(0.8).timeout
	if playing:
		_special_showcase(kind)


# --- Continue where you left off --------------------------------------------------------------------

## The app is going to the background or closing: save right now.
func _notification(what: int) -> void:
	# The phone's own back key works like the Back button on screen (same arrow rule).
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree():
		if _victory:
			_victory.home_pressed.emit()
		elif not _paused_card:
			_on_back()
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if playing and not _finishing and maze and maze.is_settled():
			_write_resume()
	# Going to the background: only freeze the clock here - no UI is built while Android is
	# tearing the screen down. The "Paused" card comes up once the app is back.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if playing and not _finishing and not _paused_card and not _is_tutorial_level 				and maze and maze.input_enabled and not AdManager.is_showing():
			_away = true
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if _away and is_inside_tree():
			_pause_on_return()


## Back from the background: wait until the screen is drawing again, then the "Paused" card.
func _pause_on_return() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _away and not _paused_card and playing and not _finishing:
		_show_pause()
	_away = false


## The "Paused" card: Resume carries on, Restart starts the level over.
func _show_pause() -> void:
	_paused_card = true
	var msg := "Your timer is stopped." if has_clock else "Take your time!"
	var pop := _small_popup("res://icons/pause.svg", "Paused", msg)
	var close: Callable = pop.close
	var font: Font = pop.font
	var col: VBoxContainer = pop.col
	# Where the level stands: level, moves left, time left.
	var bits: Array[String] = [level_label.text]
	if has_moves:
		bits.append("%d MOVES" % moves_left)
	if has_clock:
		var sec := maxi(ceili(time_left), 0)
		bits.append("%d:%02d LEFT" % [sec / 60, sec % 60])
	col.add_child(_briefing_pill("  ·  ".join(bits).to_upper(), Color("#f5f3ff"), GameSkin.VIOLET, font))
	var resume := _glyph_button("Resume", "play", Color("#22c55e"), Color("#15803d"), Color.WHITE, font, 104.0, 38)
	col.add_child(resume)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	var restart := _glyph_button("Restart", "restart", Color("#ede9fe"), GameSkin.CARD_LIP, GameSkin.VIOLET, font, 86.0, 30)
	var settings := _glyph_button("Settings", "gear", Color.WHITE, Color("#ddd6fe"), GameSkin.VIOLET, font, 86.0, 30)
	for b: Button in [restart, settings]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	resume.pressed.connect(func() -> void:
		GameData.play_sfx("tap")
		_paused_card = false
		close.call())
	restart.pressed.connect(func() -> void:
		GameData.play_sfx("tap")
		_paused_card = false
		close.call()
		_leave_level(func() -> void: _transition_to(level, false)))
	settings.pressed.connect(func() -> void:
		_paused_card = false
		close.call()
		_open_options())
	_stagger_in(col, resume)


## A chunky 3D button whose icon and text sit together in the middle (a Button's own
## icon pushes the text off-centre). The icon is drawn, so it is crisp in any colour,
## and the whole label sinks with the face when pressed.
func _glyph_button(text: String, glyph: String, face: Color, lip: Color, ink: Color, font: Font,
		height: float, font_size: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, height)
	b.focus_mode = Control.FOCUS_NONE
	GameSkin.button_3d(b, face, lip, ink, font)
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.offset_bottom = -6  # the lip
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(holder)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(row)
	var icon := Control.new()
	var side := font_size * 1.05
	icon.custom_minimum_size = Vector2(side, side)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void: _draw_glyph(icon, glyph, ink, face))
	row.add_child(icon)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", ink)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	b.button_down.connect(func() -> void:
		holder.offset_top = 6
		holder.offset_bottom = 0)
	b.button_up.connect(func() -> void:
		holder.offset_top = 0
		holder.offset_bottom = -6)
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size / 2.0
		b.create_tween().tween_property(b, "scale", Vector2.ONE * 0.95, 0.06))
	b.button_up.connect(func() -> void:
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	return b


func _draw_glyph(c: Control, glyph: String, ink: Color, bg: Color) -> void:
	var r := c.size.x / 2.0
	var m := c.size / 2.0
	match glyph:
		"play":
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-r * 0.6, -r * 0.85), m + Vector2(r * 0.9, 0),
				m + Vector2(-r * 0.6, r * 0.85)]), ink)
		"restart":
			c.draw_arc(m, r * 0.68, -PI * 0.35, PI * 1.45, 32, ink, r * 0.3, true)
			var tip := m + Vector2.from_angle(-PI * 0.35) * r * 0.68
			c.draw_colored_polygon(PackedVector2Array([tip + Vector2(-r * 0.05, -r * 0.5), tip + Vector2(r * 0.5, r * 0.12),
				tip + Vector2(-r * 0.32, r * 0.3)]), ink)
		"gear":
			for i in 8:
				var a := TAU * i / 8.0
				var d := Vector2.from_angle(a)
				var n := d.orthogonal()
				var o := m + d * r * 0.62
				c.draw_colored_polygon(PackedVector2Array([o - n * r * 0.17, o + n * r * 0.17,
					o + n * r * 0.13 + d * r * 0.36, o - n * r * 0.13 + d * r * 0.36]), ink)
			c.draw_circle(m, r * 0.66, ink, true, -1.0, true)
			c.draw_circle(m, r * 0.27, bg, true, -1.0, true)


## The Pause key in the header: the same card as when the app goes to the background.
func _on_pause_pressed() -> void:
	if _tut_blocks("options") or _finishing or _paused_card:
		return
	if not playing or not maze.input_enabled:
		_open_options()  # a popup is already up (or the level is over): settings as before
		return
	GameData.play_sfx("tap")
	_show_pause()


## Writes the level in progress to this phone. `result` = the lost-level popup
## [title, message, continue text, continue visible] while it is showing.
func _write_resume(result: Array = []) -> void:
	_save_dirty = false
	if _is_tutorial_level or _level_data.is_empty():
		return
	var state := {
		"level": level, "daily": _daily, "data": _level_data, "board": maze.snapshot(),
		"lives": lives, "moves_left": moves_left, "time_left": time_left,
		"undos_left": undos_left, "hints_left": hints_left, "streak": streak,
		"taps": taps, "mistakes": mistakes, "hints_used": hints_used, "undos_used": undos_used,
		"powers_used": powers_used, "seconds": (Time.get_ticks_msec() - started_msec) / 1000.0,
		"goals": [_goal_balloons, _goal_targets, _goal_crates, _goal_ice, _goal_golden, _order_color, _order_count,
			_crush_goal],
		"total_arrows": total_arrows, "charged": _charged, "fail": _fail, "result": result,
	}
	var f := FileAccess.open(RESUME_PATH, FileAccess.WRITE)
	if f:
		f.store_string(var_to_str(state))


func _read_resume() -> Dictionary:
	if not FileAccess.file_exists(RESUME_PATH):
		return {}
	var state: Variant = str_to_var(FileAccess.get_file_as_string(RESUME_PATH))
	return state if state is Dictionary else {}


## The saved level is finished with (won, retried, or left with Back).
static func clear_resume() -> void:
	if FileAccess.file_exists(RESUME_PATH):
		DirAccess.remove_absolute(RESUME_PATH)


## Puts hearts, moves, clock, helpers and goals back as they were when the level was saved.
func _apply_resume(saved: Dictionary) -> void:
	lives = int(saved.get("lives", MAX_HEARTS))
	undos_left = int(saved.get("undos_left", undos_left))
	hints_left = int(saved.get("hints_left", hints_left))
	streak = int(saved.get("streak", 0))
	taps = int(saved.get("taps", 0))
	mistakes = int(saved.get("mistakes", 0))
	hints_used = int(saved.get("hints_used", 0))
	undos_used = int(saved.get("undos_used", 0))
	powers_used = int(saved.get("powers_used", 0))
	started_msec = Time.get_ticks_msec() - int(float(saved.get("seconds", 0.0)) * 1000.0)
	var g: Array = saved.get("goals", [])
	if g.size() >= 7:
		_goal_balloons = int(g[0])
		_goal_targets = int(g[1])
		_goal_crates = int(g[2])
		_goal_ice = int(g[3])
		_goal_golden = int(g[4])
		_order_color = int(g[5])
		_order_count = int(g[6])
		# A level saved before the crush goal existed keeps its old "clear the board" rules.
		_crush_goal = int(g[7]) if g.size() >= 8 else 0
	total_arrows = int(saved.get("total_arrows", total_arrows))
	_charged = bool(saved.get("charged", false))
	if has_moves:
		moves_left = int(saved.get("moves_left", moves_left))
		_roll_moves_in()
	if has_clock:
		time_left = float(saved.get("time_left", time_left))
		_update_clock()
	_update_moves()
	var fail := str(saved.get("fail", ""))
	var result: Array = saved.get("result", [])
	if fail != "" and result.size() >= 4:
		# They had just lost (maybe the ad got stuck): back to the same popup.
		_fail = fail
		playing = false
		maze.input_enabled = false
		(func() -> void:
			_show_result(str(result[0]), str(result[1]), false)
			GameSkin.dress(continue_button, str(result[2]).replace("(watch video)", "").strip_edges(),
				GameSkin.VIDEO_TEX)
			continue_button.visible = bool(result[3])).call_deferred()
	elif has_clock:
		_show_pause.call_deferred()  # a clock level never starts ticking before they're ready
	else:
		_show_banner.call_deferred("WELCOME BACK!", GOAL_DONE_COLOR)


## True while the tutorial is running and pointing at something other than `kind`.
func _tut_blocks(kind: String) -> bool:
	return _tutorial != null and is_instance_valid(_tutorial) and _tutorial.allow != kind


# --- Maze events --------------------------------------------------------------------------------

## A tap resolved successfully (escape, crush or special) - `removed` arrows left.
func _on_moved(removed: int) -> void:
	taps += 1
	streak += 1
	_idle = 0.0
	if removed >= 3:
		mascot.react("wow")
	elif removed >= 2:
		mascot.react("happy")
	if has_clock and removed >= 1:
		if removed >= 3:
			_add_time(CHAIN_PER_ARROW * removed)
		elif removed == 2:
			_add_time(CRUSH_BONUS)
		else:
			_add_time(ESCAPE_BONUS)
	if streak >= _power_streak_need() and GameData.booster_unlocked("drill"):
		streak = 0
		if GameData.add_power(1):
			GameData.play_sfx("charge")
			_show_banner("+1 POWER!", POWER_COLOR)
	_refresh_hud()
	_pop_arrow_counter()
	if _goals_done():
		_win_with_move()
		return
	if _crush_short():
		return
	_crush_coaching()
	_spend_move()


## Break-through used: spend the charge, celebrate the smash.
func _on_power_blast(smashed: int) -> void:
	taps += 1
	powers_used += 1
	mascot.react("wow")
	var kind := _armed if _armed != "" else "drill"
	GameData.add_booster(kind, -1)
	GameData.play_sfx("power")
	_set_armed("")
	var banner_text: String = BOOSTER_BANNERS[kind]
	_show_banner("%s x%d!" % [banner_text, smashed] if smashed > 0 else banner_text + "!", POWER_COLOR)
	_refresh_hud()
	_pop_arrow_counter()
	if _goals_done():
		_win_with_move()
		return
	if _crush_short():
		return
	_last_crushed = maze.crushed
	_spend_move()


## Crush goal: too few arrows are left to ever reach it - end the level now instead of
## letting the player tap on for nothing. Returns true if the level was lost.
func _crush_short() -> bool:
	if _crush_goal <= 0 or _is_tutorial_level or not playing:
		return false
	if maze.crushed + maze.arrows.size() >= _crush_goal:
		return false
	_fail = "goals"
	playing = false
	maze.input_enabled = false
	GameData.play_sfx("lose")
	GameData.vibrate(60)
	_record_result(false)
	_show_result("Missed!", _crush_miss_text() + _charge_arrow(), false)
	continue_button.visible = false
	return true


func _crush_miss_text() -> String:
	return "You crushed %d of %d arrows.\nCrush same colours - flying out doesn't count!" \
		% [mini(maze.crushed, _crush_goal), _crush_goal]


## Teaches the crush goal while the player plays: the first time an arrow just flies out,
## and once when the crush goal is getting tight.
func _crush_coaching() -> void:
	var gained := maze.crushed - _last_crushed
	_last_crushed = maze.crushed
	if _crush_goal <= 0 or _is_tutorial_level:
		return
	var left := _crush_goal - maze.crushed
	var spare := maze.arrows.size() - left  # arrows that may still fly out
	if gained == 0 and not GameData.seen_features.has("flyout_tip"):
		GameData.seen_features["flyout_tip"] = true
		GameData.save_game()
		tip_label.text = "Flying out doesn't add to the crush count - CRUSH same colours!"
		tip_label.add_theme_color_override("font_color", GOAL_DONE_COLOR)
		tip_label.visible = true
		_pulse_crush_chip()
	elif gained == 0 and left > 0 and spare <= 3 and not _crush_warned:
		_crush_warned = true
		mascot.react("worried")
		_show_banner("CRUSH, DON'T FLY!", Color("#e11d48"))
		_pulse_crush_chip()


## A little bounce on the crush chip so the eye goes to the goal.
func _pulse_crush_chip() -> void:
	if not _goal_labels.has("crush"):
		return
	var chip := (_goal_labels["crush"] as Label).get_parent() as Control
	if not chip.visible:
		return
	chip.pivot_offset = chip.size / 2.0
	var t := chip.create_tween()
	for i in 3:
		t.tween_property(chip, "scale", Vector2.ONE * 1.3, 0.12).set_trans(Tween.TRANS_SINE)
		t.tween_property(chip, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)


func _on_arrow_blocked(_arrow: ArrowPath) -> void:
	taps += 1
	mistakes += 1
	streak = 0
	_idle = 0.0
	if _shield > 0:
		# Stuck on this level: the shield takes this bump instead of a heart.
		_shield -= 1
		mascot.react("sad")
		_show_banner("SHIELD SAVED YOU!", GOAL_DONE_COLOR)
		GameData.play_sfx("charge")
		_spend_move()
		return
	lives -= 1
	mascot.react("sad")
	_refresh_hud()
	_break_heart(lives)
	if lives > 0:
		_spend_move()  # a bump wastes a move too
		if level >= 3 and level <= 8:
			_hint_lesson()  # bumped on an early level: show how to get help
	if lives <= 0:
		_fail = "hearts"
		playing = false
		maze.input_enabled = false
		await get_tree().create_timer(0.7).timeout
		GameData.play_sfx("lose")
		_record_result(false)
		_show_result("Out of Hearts", _near_miss("That arrow was blocked!") + "\nThe retry will be a little gentler." + _charge_arrow(), false)
		GameSkin.dress(continue_button, "+1 Heart", GameSkin.VIDEO_TEX)


## Every arrow is gone. Normally that's the win; on a goal level with targets still
## standing it is a loss (balloons always pop by the end, targets need aiming).
func _on_maze_cleared() -> void:
	if not playing:
		return
	if not _goals_done():
		_fail = "goals"
		playing = false
		maze.input_enabled = false
		GameData.play_sfx("lose")
		GameData.vibrate(60)
		_record_result(false)
		var left := maze.targets_left()
		var why := "All arrows are gone but %d target%s never got hit.\nAim arrows out through the bullseyes!" \
			% [left, "" if left == 1 else "s"] if left > 0 else "All arrows are gone but the goals aren't finished."
		if _crush_goal > 0 and maze.crushed < _crush_goal:
			why = _crush_miss_text()
		_show_result("Missed!", why + _charge_arrow(), false)
		continue_button.visible = false
		return
	_win()


## The winning tap still uses up its move (no Final Volley shot for it).
func _win_with_move() -> void:
	if has_moves:
		moves_left = maxi(0, moves_left - 1)
		_update_moves()
	_win()


## The level is won: arrows still on the board fly off, leftover moves fire the
## Final Volley, then the result popup.
func _win() -> void:
	if not playing:
		return
	clear_resume()
	playing = false
	_finishing = true
	mascot.worried = false
	mascot.react("win")
	maze.input_enabled = false
	maze.celebrate_picture()
	maze.reset_zoom()  # the whole painting in view
	_set_power_armed(false)
	var wait := 0.0
	if not maze.arrows.is_empty():
		_show_banner_image(BANNER_ALL_GOALS)
		wait = maze.release_all()
		_refresh_hud()
	var bonus_hints := 0
	if has_moves and moves_left > 0:
		if wait > 0.0:
			await get_tree().create_timer(wait).timeout
		_show_banner_image(BANNER_VOLLEY)
		var shots := mini(moves_left, VOLLEY_SHOTS)
		wait = maze.volley(shots)
		# Each rocket spends one leftover move: the counter ticks down with the launches.
		var tick := create_tween()
		for i in shots:
			tick.tween_callback(func() -> void:
				moves_left -= 1
				_update_moves()
				big_number.pivot_offset = big_number.size / 2.0
				var b := create_tween()
				b.tween_property(big_number, "scale", Vector2.ONE * 1.25, 0.05)
				b.tween_property(big_number, "scale", Vector2.ONE, 0.12)).set_delay(MazeBoard.VOLLEY_GAP if i > 0 else 0.0)
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	else:
		# Board cleared by the last tap: a quick VICTORY! while the painting fills in.
		_show_banner_image(BANNER_VICTORY, 600.0)
		await get_tree().create_timer(1.6).timeout  # the banner has come and gone
	# The finished painting gets its own moment: fully revealed, then left in view
	# for a beat (the shine sweeps across it) before the win card covers the board.
	await get_tree().create_timer(maze.picture_time_left() + PICTURE_HOLD).timeout
	_finishing = false
	_on_won(bonus_hints)


func _on_won(bonus_hints: int) -> void:
	GameData.play_sfx("win")
	GameData.vibrate(40)
	header.alarm = false
	var praise: Array[String] = ["", "Phew, made it!", "Great job!", "Perfect!"]
	var message := praise[clampi(lives, 0, 3)]
	var goal := _goal_sum()
	var earned := GameData.COINS_WIN + GameData.COINS_PER_STAR * clampi(lives, 0, 3) 		+ GameData.COINS_PER_GOAL * maxi(0, goal.x - goal.y) + MazeBoard.BONUS_COINS * maze.bonus_out
	if _daily >= 0 and not GameData.daily_done.has(_daily):
		earned += GameData.COINS_DAILY
	GameData.add_coins(earned)
	var power := 0
	var info := {"stars": clampi(lives, 0, 3), "message": message, "coins": earned, "hints": bonus_hints,
		"picture": _draw_picture}
	if _daily >= 0:
		if GameData.complete_daily(_daily, lives):
			power += 1
		info.title = "Daily Challenge Done"
		info.next_text = "Calendar"
	else:
		GameData.complete_level(level, lives)
		if lives == MAX_HEARTS and GameData.add_power(1):
			power += 1
		info.title = "Level %d Complete" % level
		info.picture_name = PictureShapes.name_for(level)
		info.note = _adaptation_note(_record_result(true))
		info.next_text = "Next Level"
		info.show_next = level < GameData.MAX_LEVELS
		_pregenerate(level + 1)  # built while the win card is up
	info.power = power
	_open_victory(info)
	# First win of the day grows the streak (after the stars have landed).
	var streak_info := GameData.register_win()
	if not streak_info.is_empty():
		await get_tree().create_timer(2.8).timeout
		StreakPopup.show_reward(self, streak_info).closed.connect(_refresh_hud)


## The full-screen win card and where its buttons lead.
func _open_victory(info: Dictionary) -> void:
	if _victory:
		_victory.queue_free()
	_victory = VictoryScreen.open(self, info)
	_victory.next_pressed.connect(func(_at: Vector2) -> void: _on_next_level())
	_victory.replay_pressed.connect(func(at: Vector2) -> void: _transition_to(level, false, at))
	_victory.home_pressed.connect(func() -> void:
		clear_resume()
		get_tree().change_scene_to_file(DAILY_SCENE if _daily >= 0 else LEVEL_SELECT))


## The finished maze picture, drawn into the win card's little photo.
func _draw_picture(pic: Control) -> void:
	if maze.cols == 0:
		return
	var k := minf(pic.size.x / maze.cols, pic.size.y / maze.rows)
	var off := (pic.size - Vector2(maze.cols, maze.rows) * k) / 2.0
	# The player's own painting of this board (see MazeBoard.draw_painting).
	pic.clip_contents = true
	maze.draw_painting(pic, off, k / MazeBoard.CELL, 1.0, false)


# --- Level curtain -------------------------------------------------------------------------------

## Closes the curtain (onto the pressed button), then the next level opens behind it.
func _transition_to(n: int, with_ad: bool, at: Vector2 = Vector2(-1, -1)) -> void:
	if _switching:
		return
	_switching = true
	var tr := LevelTransition.make(self)
	await tr.close(at)
	if _victory:
		_victory.queue_free()
		_victory = null
	result_popup.hide()
	if with_ad:
		AdManager.level_finished(level, _after_curtain.bind(tr, n))
	else:
		_after_curtain(tr, n)


func _after_curtain(tr: LevelTransition, n: int) -> void:
	_switching = false
	clear_resume()
	GameData.refresh_quiver()
	if _daily >= 0 or not GameData.level_costs_arrow(n, false) or GameData.quiver > 0:
		_enter_level(tr, n)
		return
	tr.open()   # no arrow for it: lift the curtain and show the "Out of Arrows" popup
	_play_level(n)


## Builds level `n` under a closed curtain, shows its title (HARD stamp on hard ones),
## opens the curtain, then the goal card.
func _enter_level(tr: LevelTransition, n: int, first: bool = false) -> void:
	_intro_hold = true
	start_level(n)
	if _briefing:
		var stamp := ""
		if _daily < 0 and _held_tier >= LevelGenerator.Tier.HARD:
			stamp = "HARD LEVEL" if _held_tier == LevelGenerator.Tier.HARD else "SUPER HARD"
		var color: Color = RIBBON_COLORS[clampi(_held_tier, 0, 3)][0]
		await tr.show_title(level_label.text, stamp, color, _briefing_sentence(_briefing_goals(), false))
	await tr.open()
	_intro_hold = false
	if _briefing:
		_show_briefing(_held_tier)
	if first:
		_check_streak()


## Sends this level's play data to the behaviour model.
func _record_result(won: bool) -> Dictionary:
	if _is_tutorial_level:  # a guided level says nothing about the player's skill
		return {"delta": 0.0, "next": GameData.difficulty_for(level + 1)}
	var result := GameData.record_result(level, {
		"won": won, "lives_left": lives, "taps": taps, "mistakes": mistakes,
		"hints": hints_used, "undos": undos_used, "powers": powers_used,
		"seconds": (Time.get_ticks_msec() - started_msec) / 1000.0,
		"cleared": 1.0 - float(maze.arrows.size()) / maxf(1.0, total_arrows),
		"daily": _daily >= 0,
	})
	if not won:
		_pregenerate(level)  # the (gentler) retry is built while the fail card is up
	return result


## One line telling the player how the next level was tuned to them.
func _adaptation_note(result: Dictionary) -> String:
	var next_tier: String = LevelGenerator.TIER_NAMES[LevelGenerator.tier_for_difficulty(result.next)]
	if result.delta > 0.05:
		return "You're on fire! Next: %s" % next_tier
	if result.delta < -0.05:
		return "Next one is a bit gentler: %s" % next_tier
	return "Next level tuned to you: %s" % next_tier


# --- Buttons -------------------------------------------------------------------------------------

func _on_undo() -> void:
	if not playing or maze.history.is_empty() or _tut_blocks("undo"):
		return
	if undos_left <= 0:
		_offer_ad("Out of undos", "Watch a short video to get +1 Undo?", "+1 Undo", func() -> void:
			undos_left += 1
			_refresh_hud()
			_on_undo())
		return
	var entry := maze.undo()
	if entry.is_empty():
		return
	_last_crushed = maze.crushed
	undos_left -= 1
	undos_used += 1
	if has_moves:
		moves_left += 1  # the undone tap gives its move back
		_update_moves()
	if entry.power:
		# Undoing a booster gives it back.
		GameData.add_booster(GameData.BOOSTERS[int(entry.get("booster", ArrowPath.Special.DRILL)) - 1], 1)
	GameData.play_sfx("tap")
	_refresh_hud()


func _on_power() -> void:
	_on_booster("drill")


## Arms / disarms a booster. None left -> a small popup: watch a video for one, or buy it with coins.
func _on_booster(kind: String) -> void:
	if not playing or _tut_blocks("power"):
		return
	if not GameData.booster_unlocked(kind):
		_locked_power(kind)
	elif _armed == kind:
		_set_armed("")
	elif GameData.booster_count(kind) > 0:
		GameData.play_sfx("charge")
		_set_armed(kind)
		if kind == "drill":
			helper_used.emit("power")
	else:
		_offer_booster(kind)
	_refresh_hud()


func _set_power_armed(on: bool) -> void:
	_set_armed("drill" if on else "")


## The armed booster's button throbs and blinks gold - no text needed.
func _set_armed(kind: String) -> void:
	_armed = kind
	maze.armed = ArrowPath.Special.NONE if kind == "" else (GameData.BOOSTERS.find(kind) + 1) as ArrowPath.Special
	if _power_pulse and _power_pulse.is_valid():
		_power_pulse.kill()
	for b: Button in _booster_buttons.values():
		b.scale = Vector2.ONE
		b.modulate = Color.WHITE
	if kind == "":
		return
	var button: Button = _booster_buttons[kind]
	_power_pulse = create_tween().set_loops()
	_power_pulse.tween_property(button, "scale", Vector2.ONE * 1.12, 0.35).set_trans(Tween.TRANS_SINE)
	_power_pulse.parallel().tween_property(button, "modulate", Color(1.35, 1.15, 0.55), 0.35).set_trans(Tween.TRANS_SINE)
	_power_pulse.tween_property(button, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)
	_power_pulse.parallel().tween_property(button, "modulate", Color.WHITE, 0.35).set_trans(Tween.TRANS_SINE)


## Bomb / laser / colour-wipe buttons next to the drill, all a little smaller so six fit.
func _build_booster_buttons() -> void:
	var bar := power_button.get_parent() as BoxContainer
	bar.add_theme_constant_override("separation", DOCK_GAP)
	_booster_buttons["drill"] = power_button
	for b: Button in [undo_button, power_button, hint_button]:
		b.custom_minimum_size = Vector2.ONE * DOCK_BTN
	for kind: String in BOOSTER_ICONS:
		var b := Button.new()
		b.theme_type_variation = &"CircleButton"
		b.custom_minimum_size = Vector2.ONE * DOCK_BTN
		b.icon = load(BOOSTER_ICONS[kind])
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.focus_mode = Control.FOCUS_NONE
		var badge := power_badge.duplicate() as Label
		b.add_child(badge)
		b.set_meta("badge", badge)
		bar.add_child(b)
		bar.move_child(b, hint_button.get_index())
		b.pressed.connect(_on_booster.bind(kind))
		b.resized.connect(func() -> void: b.pivot_offset = b.size / 2.0)
		_booster_buttons[kind] = b


func _on_hint() -> void:
	if not playing or _tut_blocks("hint"):
		return
	if hints_left <= 0 and GameData.bonus_hints <= 0:
		# The video earns a hint INTO the button (its badge shows 1); the player taps the
		# button when they want it - nothing pops up on the board by itself.
		if maze.hint_arrow() == null:
			GameData.play_sfx("thud")
			return
		_rewarded("+1 Hint", func() -> void:
			hints_left += 1
			_save_dirty = true
			_refresh_hud()
			GameData.play_sfx("charge")
			_show_banner("+1 HINT - TAP THE BULB!", GOAL_DONE_COLOR)
			hint_button.pivot_offset = hint_button.size / 2.0
			var tw := create_tween()
			for i in 2:
				tw.tween_property(hint_button, "scale", Vector2.ONE * 1.25, 0.14).set_trans(Tween.TRANS_BACK)
				tw.tween_property(hint_button, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SINE))
		return
	var arrow := maze.hint_arrow()
	if arrow:
		if hints_left > 0:
			hints_left -= 1
		else:
			GameData.bonus_hints -= 1  # from the streak hint bank
			GameData.save_game()
		hints_used += 1
		GameData.play_sfx("hint")
		maze.show_hint(arrow)
		_refresh_hud()
		helper_used.emit("hint")


## Out of hearts: one more heart for a rewarded video, the level carries on.
## Out of time: AD_SECONDS more on the clock instead.
func _on_continue_with_ad() -> void:
	if _fail == "goals":
		return
	AdManager.show_rewarded(_continue_label(), _continue)


## The same reward paid with coins; not enough coins -> the button shakes (the video button is right above).
func _on_continue_with_coins() -> void:
	if _fail == "goals":
		return
	if not GameData.spend_coins(GameData.CONTINUE_COINS):
		_nope(_coin_continue)
		return
	_continue()


func _continue_label() -> String:
	match _fail:
		"time":
			return "+%d Seconds" % AD_SECONDS
		"moves":
			return "+%d Moves" % AD_MOVES
	return "+1 Heart"


## Gives the continue reward for the current failure and the level carries on.
func _continue() -> void:
	result_popup.hide()
	match _fail:
		"time":
			time_left = AD_SECONDS
		"moves":
			moves_left = AD_MOVES
		_:
			lives = 1
			_pop_heart(0)
	_fail = ""
	playing = true
	maze.input_enabled = true
	_save_dirty = true
	_refund_arrow()
	GameData.play_sfx("charge")
	_update_clock()
	_update_moves()
	_refresh_hud()


## "Keep playing" for coins, shown under the video button whenever that one shows.
func _build_coin_continue() -> void:
	_coin_continue = Button.new()
	_coin_continue.custom_minimum_size = Vector2(0, 92)
	_coin_continue.add_theme_font_size_override("font_size", 30)
	_coin_continue.focus_mode = Control.FOCUS_NONE
	var heavy := SystemFont.new()
	heavy.font_names = PackedStringArray(["Nunito", "Roboto", "Segoe UI", "Arial", "sans-serif"])
	heavy.font_weight = 900
	GameSkin.button_3d(_coin_continue, GameSkin.GOLD, GameSkin.GOLD_LIP, GameSkin.GOLD_TEXT, heavy)
	var box := continue_button.get_parent()
	box.add_child(_coin_continue)
	box.move_child(_coin_continue, continue_button.get_index() + 1)
	_coin_continue.pressed.connect(_on_continue_with_coins)
	continue_button.visibility_changed.connect(_update_coin_continue)
	_update_coin_continue()


func _update_coin_continue() -> void:
	_coin_continue.visible = continue_button.visible
	GameSkin.dress(_coin_continue, "Keep playing", null, GameData.CONTINUE_COINS)
	_coin_continue.modulate.a = 1.0 if GameData.coins >= GameData.CONTINUE_COINS else 0.5


func _on_next_level() -> void:
	GameData.play_sfx("tap")
	if _daily >= 0:
		get_tree().change_scene_to_file(DAILY_SCENE)
		return
	var at := Vector2(-1, -1)
	if _victory:
		at = _victory._next.get_global_rect().get_center()
	_transition_to(level + 1, true, at)


func _on_back() -> void:
	if _tut_blocks("back") or _finishing or _switching or _intro_hold:
		return
	GameData.play_sfx("tap")
	_leave_level(func() -> void:
		clear_resume()
		get_tree().change_scene_to_file(DAILY_SCENE if _daily >= 0 else LEVEL_SELECT))


func _open_options() -> void:
	if _tut_blocks("options") or _finishing:
		return
	GameData.play_sfx("tap")
	maze.input_enabled = false
	var options := OptionsScreen.open(self, true)
	options.restart_requested.connect(func() -> void: _leave_level(_play_level.bind(level)))
	options.closed.connect(func() -> void: maze.input_enabled = playing)


# --- Quiver -----------------------------------------------------------------------------------------

## Leaving a level once its PLAY was pressed is quitting it: that costs an arrow (a life),
## so ask first. Backing out from the goal card (before PLAY) is free.
func _leave_level(then: Callable) -> void:
	if not (playing and _costs_arrow and not _briefing and not _charged):
		then.call()
		return
	maze.input_enabled = false
	var popup := QuiverPopup.show_leave(self)
	popup.confirmed.connect(func() -> void:
		_charged = true
		GameData.play_sfx("quit")  # the quit costs an arrow: a soft "broken" sound
		then.call())
	popup.closed.connect(func() -> void: maze.input_enabled = playing)


## Starts level `n` if the quiver has an arrow for it; otherwise the "Out of Arrows"
## popup, and the level starts once an arrow is back (or it's back to the map).
func _play_level(n: int) -> void:
	clear_resume()
	GameData.refresh_quiver()
	if _daily >= 0 or not GameData.level_costs_arrow(n, false) or GameData.quiver > 0:
		start_level(n)
		return
	maze.input_enabled = false
	var popup := QuiverPopup.show_empty(self)
	var got := [false]
	popup.refilled.connect(func() -> void:
		got[0] = true
		start_level(n))
	popup.closed.connect(func() -> void:
		if not got[0]:
			get_tree().change_scene_to_file(LEVEL_SELECT))


## A lost level takes one arrow from the quiver. Returns a line for the result popup.
func _charge_arrow() -> String:
	if not _costs_arrow or _charged:
		return ""
	_charged = true
	GameData.spend_arrow()
	return "\nQuiver: -1 arrow (%d left)" % GameData.quiver


## A rewarded video saved the level: the arrow comes back.
func _refund_arrow() -> void:
	if _charged:
		_charged = false
		GameData.add_arrows(1)


# --- Goals: balloons and targets ------------------------------------------------------------------------

## Every goal of this level: kind -> [amount at the start, amount left].
func _goal_counts() -> Dictionary:
	var order_left := maxi(0, _order_count - maze.removed_of(_order_color)) if _order_color >= 0 else 0
	return {
		"balloons": [_goal_balloons, maze.balloons_left()],
		"targets": [_goal_targets, maze.targets_left()],
		"crates": [_goal_crates, maze.crates_left()],
		"ice": [_goal_ice, maze.ice_left()],
		"color": [_order_count if _order_color >= 0 else 0, order_left],
		"golden": [_goal_golden, maze.golden_left()],
	}


## [total, left] over all goals; [0, 0] on a plain "clear the board" level.
func _goal_sum() -> Vector2i:
	var sum := Vector2i.ZERO
	for pair: Array in _goal_counts().values():
		sum += Vector2i(pair[0], pair[1])
	return sum


func _goals_done() -> bool:
	if _is_tutorial_level:
		# Level 1 is played to the end: the lessons run, then the player clears the board.
		return maze.arrows.is_empty()
	if _crush_goal > 0:
		# Clear the board, crushing at least _crush_goal arrows on the way; balloons,
		# targets, crates... on the board must be done too. (Ending as soon as the crush
		# count was reached made levels far too short: chains reach it in a few taps.)
		return maze.arrows.is_empty() and maze.crushed >= _crush_goal and _goal_sum().y == 0
	if _goal_sum().x == 0:
		return maze.arrows.is_empty()
	return _goal_sum().y == 0


## The "arrows left" chip: on plain levels it is the goal; on crush levels it shows the
## board still to clear - only when the card has room for it. The goal card holds at
## most three chips: more makes the whole header wider than the phone (the board then
## spreads off screen too).
func _arrows_chip_shown() -> bool:
	if _crush_goal <= 0:
		return _goal_sum().x == 0
	var chips := 1  # the crush chip
	for pair: Array in _goal_counts().values():
		if int(pair[0]) > 0:
			chips += 1
	if has_moves and has_clock:
		chips += 1  # the stopwatch chip
	return chips <= 2


## Arrows to crush to win this level: a share of what a careful player can crush (see
## LevelGenerator.estimate_crushes), lower for a player who is stuck here (help only).
## 0 = too few crushes on this board: the old "clear every arrow" rule applies.
func _crush_goal_for(data: Dictionary) -> int:
	if _is_tutorial_level:
		return 2  # the one crush pair the lesson shows
	var most := int(data.get("crush_max", -1))
	if most < 0:  # a board made before the crush goal existed
		most = LevelGenerator.estimate_crushes(data.arrows, data.colors, data.cols, data.rows,
			data.get("mirrors", {}), data.get("prisms", []))
	var share := 0.65
	if _daily < 0 and GameData.needs_help(level):
		share = 0.5
	var n := floori(most * share)
	return n if n >= 2 else 0


## The first time the player meets a board piece: a tip under the board (the goal card
## shows it as NEW). Returns the piece's kind, or "".
func _introduce_new_piece(data: Dictionary) -> String:
	if _daily >= 0:
		return ""
	var present := {
		"balloons": _goal_balloons > 0, "color": _order_color >= 0, "crates": _goal_crates > 0,
		"targets": _goal_targets > 0, "ice": _goal_ice > 0, "mirrors": not data.get("mirrors", {}).is_empty(),
		"golden": _goal_golden > 0, "bonus": not data.get("timers", {}).is_empty(),
		"links": not data.get("links", []).is_empty(), "flips": not data.get("flips", []).is_empty(),
		"chain": not data.get("jackpots", []).is_empty(), "prism": not data.get("prisms", []).is_empty(),
		"wavy": float(data.get("wind", 0.0)) >= 0.5,
		"creep": int(data.get("creep", 0)) > 0,
	}
	for kind: String in FEATURE_INTROS:
		if present[kind] and not GameData.seen_features.has(kind):
			GameData.seen_features[kind] = true
			GameData.save_game()
			if _is_tutorial_level:
				continue  # the tutorial explains balloons itself
			if not _briefing:
				_show_banner(FEATURE_INTROS[kind][0], GOAL_DONE_COLOR)
			tip_label.text = FEATURE_INTROS[kind][1]
			tip_label.add_theme_color_override("font_color", GOAL_DONE_COLOR)
			tip_label.visible = true
			return kind
	return ""


func _on_goals_changed() -> void:
	if playing:
		mascot.react("happy")
	_update_goals()
	_refresh_hud()


## The goal card under the bow meter: a chip per goal, counting down - balloons and
## targets on goal levels, otherwise the arrows still to clear.
func _build_goal_row() -> void:
	for kind in ["crush", "golden", "balloons", "targets", "crates", "ice", "color", "arrows"]:
		# Icon with its count beside it (centred, big, dark ink on the cream card); when the
		# goal is done the count gives way to a green tick on the icon.
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 6)
		chip.alignment = BoxContainer.ALIGNMENT_CENTER
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.texture = load({"crush": "res://icons/fx/goal_crush.png",
			"balloons": "res://icons/fx/goal_balloon_0.png", "targets": "res://icons/fx/goal_target.png",
			"crates": "res://icons/fx/goal_crate_1.png", "ice": "res://icons/fx/goal_ice_2.png", "color": "res://icons/arrow_white.svg",
			"golden": "res://icons/fx/goal_golden.png",
			"arrows": "res://icons/arrow_white.svg"}[kind])
		icon.name = "Icon"
		# The crush goal is the main goal: its chip is a little bigger than the board pieces.
		icon.custom_minimum_size = Vector2(60, 60) if kind == "crush" else Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if kind == "arrows":
			icon.modulate = GameSkin.VIOLET  # white art: tint it so it shows on the cream card
		chip.add_child(icon)
		# Done: a green tick BESIDE the icon (where the count was), not covering the art.
		var tick := Control.new()
		tick.name = "Tick"
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.custom_minimum_size = Vector2(32, 32)
		tick.size = Vector2(32, 32)
		tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tick.pivot_offset = tick.size / 2.0
		tick.visible = false
		tick.draw.connect(func() -> void:
			var c := tick.size / 2.0
			tick.draw_circle(c + Vector2(0, 2), 14.0, Color("#15803d"), true, -1.0, true)
			tick.draw_circle(c, 14.0, Color("#22c55e"), true, -1.0, true)
			tick.draw_arc(c, 14.0, 0.0, TAU, 32, Color.WHITE, 2.5, true)
			tick.draw_polyline(PackedVector2Array([c + Vector2(-6, 0), c + Vector2(-1.5, 5), c + Vector2(7, -5)]), Color.WHITE, 4.0, true))
		var label := Label.new()
		label.add_theme_font_override("font", banner.get_theme_font("font"))
		label.add_theme_font_size_override("font_size", 34)
		label.add_theme_color_override("font_color", GOAL_INK)
		label.add_theme_color_override("font_outline_color", Color.WHITE)
		label.add_theme_constant_override("outline_size", 6)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(label)
		chip.add_child(tick)
		_goal_labels[kind] = label
		goal_row.add_child(chip)


func _update_goals() -> void:
	var counts := _goal_counts()
	counts["arrows"] = [total_arrows if _arrows_chip_shown() else 0, maze.arrows.size()]
	counts["crush"] = [_crush_goal, maxi(0, _crush_goal - maze.crushed)]
	_fit_goal_card(counts)
	if _order_color >= 0:
		(_goal_labels["color"].get_parent().get_node("Icon") as CanvasItem).modulate = 			ArrowPath.ARROW_COLORS[_order_color % ArrowPath.ARROW_COLORS.size()]
	for kind: String in counts:
		var total: int = counts[kind][0]
		var left: int = counts[kind][1] + int(_in_flight.get(kind, 0))
		var label: Label = _goal_labels[kind]
		var chip := label.get_parent() as Control
		var icon := chip.get_node("Icon") as Control
		var tick := chip.get_node("Tick") as Control
		chip.visible = total > 0
		var text := "" if left == 0 else str(left)
		var was := label.text
		var changed := was != text and str(label.get_meta("shown", "")) != "" and label.is_inside_tree() and chip.visible
		label.set_meta("shown", "1" if chip.visible else "")
		label.text = text
		label.visible = left > 0
		var done_now := left == 0 and not tick.visible
		tick.visible = left == 0
		if not changed:
			continue
		_goal_count_fx(label, icon, was)
		if done_now:
			tick.scale = Vector2.ZERO
			var t := tick.create_tween()
			t.tween_property(tick, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			GameData.play_sfx("hint")
			chip.pivot_offset = chip.size / 2.0
			var c := chip.create_tween()
			c.tween_property(chip, "scale", Vector2.ONE * 1.3, 0.08)
			c.tween_property(chip, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Keeps the goal card inside the phone: with four or more chips the "GOAL" tag hides
## and every chip gets smaller (a wider card would push the whole header - and the
## board fitted under it - off the screen).
func _fit_goal_card(counts: Dictionary) -> void:
	var chips := 1 if _timer_chip and _timer_chip.visible else 0
	for kind: String in counts:
		if int(counts[kind][0]) > 0:
			chips += 1
	var tight := chips >= 4
	goal_row.get_child(0).visible = not tight  # the GOAL tag
	goal_row.add_theme_constant_override("separation", 6 if tight else 12)
	for kind: String in _goal_labels:
		var label: Label = _goal_labels[kind]
		label.add_theme_font_size_override("font_size", 26 if tight else 34)
		var icon := label.get_parent().get_node("Icon") as Control
		var big := 60.0 if kind == "crush" else 48.0
		icon.custom_minimum_size = Vector2.ONE * (38.0 if tight else big)


## A goal count changed: the old number floats up and fades, the new one pops in with an
## orange flash, and the icon squashes like it just caught something.
func _goal_count_fx(label: Label, icon: Control, old_text: String) -> void:
	if old_text != "":
		var ghost := Label.new()
		ghost.text = old_text
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.add_theme_font_override("font", label.get_theme_font("font"))
		ghost.add_theme_font_size_override("font_size", 34)
		ghost.add_theme_color_override("font_color", Color("#f97316"))
		ghost.add_theme_color_override("font_outline_color", Color.WHITE)
		ghost.add_theme_constant_override("outline_size", 6)
		hud.add_child(ghost)
		ghost.position = label.get_global_rect().position
		var g := ghost.create_tween()
		g.tween_property(ghost, "position:y", ghost.position.y - 34.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		g.parallel().tween_property(ghost, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
		g.tween_callback(ghost.queue_free)
	if label.visible:
		label.pivot_offset = Vector2(label.get_minimum_size().x / 2.0, label.size.y / 2.0)
		label.scale = Vector2(0.5, 1.5)
		label.add_theme_color_override("font_color", Color("#f97316"))
		var t := label.create_tween()
		t.tween_property(label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		t.parallel().tween_method(func(c: Color) -> void: label.add_theme_color_override("font_color", c),
			Color("#f97316"), GOAL_INK, 0.35)
	icon.pivot_offset = icon.size / 2.0
	icon.scale = Vector2(1.3, 0.72)
	icon.create_tween().tween_property(icon, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Plays a rewarded video with the board paused; `on_reward` runs only after the full video.
func _rewarded(reward: String, on_reward: Callable) -> void:
	if AdManager.is_showing():
		return
	maze.input_enabled = false
	AdManager.ad_finished.connect(func() -> void: maze.input_enabled = playing, CONNECT_ONE_SHOT)
	AdManager.show_rewarded(reward, on_reward)


## A tap that can't be paid for: a thud and a little shake of the button.
func _nope(button: Control) -> void:
	GameData.play_sfx("thud")
	GameData.vibrate(20)
	var x := button.position.x
	var t := create_tween()
	for i in 4:
		t.tween_property(button, "position:x", x + (10.0 if i % 2 == 0 else -10.0), 0.04)
	t.tween_property(button, "position:x", x, 0.04)


## A small card over the level: optional icon, title, message. Returns
## {"col": VBoxContainer for the buttons, "close": Callable, "font": the heavy font}.
func _small_popup(icon_path: String, title: String, message: String) -> Dictionary:
	maze.input_enabled = false
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.07, 0.03, 0.2, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	var box := GameSkin.box(Color.WHITE, GameSkin.CARD_LIP, 44, 12)
	box.content_margin_left = 40
	box.content_margin_right = 40
	box.content_margin_top = 34
	box.content_margin_bottom = 38
	box.shadow_color = Color(0.05, 0.0, 0.2, 0.45)
	box.shadow_size = 24
	box.shadow_offset = Vector2(0, 10)
	panel.add_theme_stylebox_override("panel", box)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	panel.add_child(col)
	if icon_path != "":
		var badge := Panel.new()
		var round_box := StyleBoxFlat.new()
		round_box.bg_color = Color("#f5f3ff")
		round_box.border_color = GameSkin.CARD_LIP
		round_box.border_width_bottom = 6
		round_box.set_corner_radius_all(60)
		round_box.anti_aliasing = true
		badge.add_theme_stylebox_override("panel", round_box)
		badge.custom_minimum_size = Vector2(120, 120)
		badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(badge)
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 24
		icon.offset_top = 24
		icon.offset_right = -24
		icon.offset_bottom = -24
		badge.add_child(icon)
	var heavy := SystemFont.new()
	heavy.font_names = PackedStringArray(["Nunito", "Roboto", "Segoe UI", "Arial", "sans-serif"])
	heavy.font_weight = 900
	var head := Label.new()
	head.text = title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_override("font", heavy)
	head.add_theme_font_size_override("font_size", 46)
	head.add_theme_color_override("font_color", GameSkin.VIOLET_DARK)
	col.add_child(head)
	var body := Label.new()
	body.text = message
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 28)
	body.add_theme_color_override("font_color", Color("#6b6a8a"))
	col.add_child(body)
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size / 2.0)
	panel.scale = Vector2.ONE * 0.8
	create_tween().tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var close := func() -> void:
		layer.queue_free()
		maze.input_enabled = playing
	return {"col": col, "close": close, "font": heavy}


## Goal card before a level starts (like Candy Crush): what to do in one sentence, a chip
## per goal with its count, the move / time limit, a NEW! note for a piece seen for the
## first time, and PLAY. The board and the clock wait until PLAY.
func _show_briefing(tier: int) -> void:
	var title := GameData.day_label(_daily) if _daily >= 0 else "Level %d" % level
	var goals := _briefing_goals()
	var pop := _small_popup("", title, _briefing_sentence(goals))
	var col: VBoxContainer = pop.col
	var font: Font = pop.font
	(col.get_child(1) as Label).add_theme_color_override("font_color", GameSkin.VIOLET_DARK)
	(col.get_child(1) as Label).add_theme_font_size_override("font_size", 30)
	if tier >= LevelGenerator.Tier.HARD and _daily < 0:
		col.add_child(_briefing_pill("HARD LEVEL" if tier == LevelGenerator.Tier.HARD else "SUPER HARD",
			TIER_COLORS[tier][1], Color.WHITE, font))
		col.move_child(col.get_child(col.get_child_count() - 1), 0)

	# One chip per goal: the icon in a lilac disc, the count under it.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	col.add_child(row)
	for g: Array in goals:
		var chip := VBoxContainer.new()
		chip.add_theme_constant_override("separation", 6)
		var disc := PanelContainer.new()
		var round_box := StyleBoxFlat.new()
		round_box.bg_color = Color("#f5f3ff")
		round_box.border_color = GameSkin.CARD_LIP
		round_box.border_width_bottom = 6
		round_box.set_corner_radius_all(52)
		round_box.set_content_margin_all(18)
		round_box.anti_aliasing = true
		disc.add_theme_stylebox_override("panel", round_box)
		disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var icon := TextureRect.new()
		icon.texture = load(g[1])
		icon.custom_minimum_size = Vector2(68, 68)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = g[3]
		disc.add_child(icon)
		chip.add_child(disc)
		var count := Label.new()
		count.text = ("x%d" % g[2]) if g[2] > 0 else ""
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.add_theme_font_override("font", font)
		count.add_theme_font_size_override("font_size", 34)
		count.add_theme_color_override("font_color", GameSkin.VIOLET_DARK)
		chip.add_child(count)
		row.add_child(chip)

	# The limit: moves, clock, both - or none.
	var limit := "NO MOVE LIMIT"
	var s := maxi(ceili(time_left), 0)
	var clock := "%d:%02d" % [s / 60, s % 60]
	if has_moves and has_clock:
		limit = "%d MOVES  ·  %s" % [moves_left, clock]
	elif has_moves:
		limit = "%d MOVES" % moves_left
	elif has_clock:
		limit = "TIME  %s" % clock
	var limit_color := BOTH_COLOR if (has_moves and has_clock) else (MOVES_COLOR if has_moves else (TIME_COLOR if has_clock else Color("#8b8aa6")))
	col.add_child(_briefing_pill(limit, limit_color, Color.WHITE, font))

	# A piece the player has never seen: what it does.
	if _new_piece != "":
		var note := PanelContainer.new()
		var note_box := StyleBoxFlat.new()
		note_box.bg_color = Color("#fef9c3")
		note_box.border_color = Color("#facc15")
		note_box.set_border_width_all(3)
		note_box.set_corner_radius_all(22)
		note_box.set_content_margin_all(16)
		note.add_theme_stylebox_override("panel", note_box)
		var note_text := RichTextLabel.new()
		note_text.bbcode_enabled = true
		note_text.fit_content = true
		note_text.scroll_active = false
		note_text.custom_minimum_size = Vector2(440, 0)
		note_text.add_theme_font_size_override("normal_font_size", 25)
		note_text.add_theme_font_size_override("bold_font_size", 25)
		note_text.add_theme_font_override("bold_font", font)
		note_text.add_theme_color_override("default_color", Color("#713f12"))
		note_text.text = "[b]NEW![/b]  " + str(FEATURE_INTROS[_new_piece][1])
		note.add_child(note_text)
		col.add_child(note)

	_picked_boosters.clear()
	if _daily < 0 and not _is_tutorial_level:
		var pick_title := Label.new()
		pick_title.text = "Start with a booster:"
		pick_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pick_title.add_theme_font_override("font", font)
		pick_title.add_theme_font_size_override("font_size", 26)
		pick_title.add_theme_color_override("font_color", GameSkin.VIOLET_DARK)
		col.add_child(pick_title)
		var picks := HBoxContainer.new()
		picks.alignment = BoxContainer.ALIGNMENT_CENTER
		picks.add_theme_constant_override("separation", 16)
		col.add_child(picks)
		for kind: String in GameData.BOOSTERS:
			picks.add_child(_booster_bubble(kind, font))

	var play := _popup_button(col, "PLAY", "", Color("#22c55e"), Color("#15803d"), Color.WHITE, font, 104.0)
	play.add_theme_font_size_override("font_size", 40)
	play.pressed.connect(func() -> void:
		GameData.play_sfx("tap")
		pop.close.call()
		_level_started())
	_stagger_in(col, play)


## Goal card entrance: each row pops in one after another, a HARD pill gets a shake,
## and PLAY keeps a gentle pulse so the next step is obvious.
func _stagger_in(col: VBoxContainer, play: Button) -> void:
	var rows: Array[Control] = []
	for c in col.get_children():
		if c is Control:
			rows.append(c)
			(c as Control).modulate.a = 0.0
	await get_tree().process_frame
	for i in rows.size():
		var c := rows[i]
		if not is_instance_valid(c):
			return
		c.pivot_offset = c.size / 2.0
		c.scale = Vector2.ONE * 0.55
		var t := c.create_tween()
		t.tween_interval(0.12 + i * 0.08)
		t.tween_callback(GameData.play_sfx.bind("pop", 0.9 + i * 0.06))
		t.tween_property(c, "modulate:a", 1.0, 0.12)
		t.parallel().tween_property(c, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if i == 0 and c is PanelContainer and _held_tier >= LevelGenerator.Tier.HARD and _daily < 0:
			for r: float in [0.09, -0.09, 0.06, -0.04, 0.0]:
				t.tween_property(c, "rotation", r, 0.05)
	var start := 0.12 + rows.size() * 0.08 + 0.4
	var pulse := play.create_tween().set_loops()
	pulse.tween_interval(start)
	pulse.tween_callback(func() -> void: play.pivot_offset = play.size / 2.0)
	pulse.tween_property(play, "scale", Vector2.ONE * 1.06, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(play, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## One booster on the goal card (Candy Crush style): a round bubble with the power's
## art and how many you have. Tap to take it into the level (it starts as a special
## arrow on the board). None left: buy one with coins. Locked: "Unlocks at level N".
func _booster_bubble(kind: String, font: Font) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(100, 100)
	var disc := Panel.new()
	disc.set_anchors_preset(Control.PRESET_FULL_RECT)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(disc)
	var icon := TextureRect.new()
	icon.texture = POWER_ICONS[kind]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 16
	icon.offset_top = 14
	icon.offset_right = -16
	icon.offset_bottom = -18
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(icon)
	var badge := Label.new()
	badge.add_theme_font_override("font", font)
	badge.add_theme_font_size_override("font_size", 22)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.position = Vector2(64, 64)
	badge.size = Vector2(40, 36)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(badge)
	var refresh := func() -> void:
		var unlocked := GameData.booster_unlocked(kind)
		var picked := _picked_boosters.has(kind)
		var have := GameData.booster_count(kind)
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(50)
		box.anti_aliasing = true
		box.bg_color = Color("#e0f2fe") if unlocked else Color("#e5e7eb")
		box.set_border_width_all(6 if picked else 3)
		box.border_width_bottom = 8 if picked else 6
		box.border_color = Color("#22c55e") if picked else Color("#7dd3fc") if unlocked else Color("#9ca3af")
		box.shadow_color = Color(0.05, 0.0, 0.2, 0.25)
		box.shadow_size = 6
		box.shadow_offset = Vector2(0, 3)
		disc.add_theme_stylebox_override("panel", box)
		icon.modulate = Color.WHITE if unlocked else Color(0.55, 0.55, 0.6, 0.7)
		var tag := StyleBoxFlat.new()
		tag.set_corner_radius_all(18)
		tag.anti_aliasing = true
		tag.set_border_width_all(3)
		tag.border_color = Color.WHITE
		if not unlocked:
			badge.text = "Lv%d" % int(GameData.BOOSTER_UNLOCK[kind])
			tag.bg_color = Color("#6b7280")
		elif picked:
			badge.text = "✓"
			tag.bg_color = Color("#16a34a")
		elif have > 0:
			badge.text = str(have)
			tag.bg_color = Color("#7c3aed")
		else:
			badge.text = "+"
			tag.bg_color = Color("#16a34a")
		badge.add_theme_stylebox_override("normal", tag)
	refresh.call()
	holder.gui_input.connect(func(e: InputEvent) -> void:
		if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
			return
		GameData.play_sfx("tap")
		if not GameData.booster_unlocked(kind):
			_bubble_tip(holder, "Unlocks at level %d" % int(GameData.BOOSTER_UNLOCK[kind]), font)
		elif _picked_boosters.has(kind):
			_picked_boosters.erase(kind)
		elif GameData.booster_count(kind) > 0:
			_picked_boosters[kind] = true
		elif GameData.buy_booster(kind):
			GameData.play_sfx("coin")
			_picked_boosters[kind] = true
		else:
			_bubble_tip(holder, "%d coins needed" % int(GameData.PRICES[kind]), font)
		refresh.call()
		holder.pivot_offset = holder.size / 2.0
		var t := create_tween()
		t.tween_property(holder, "scale", Vector2.ONE * 1.12, 0.07)
		t.tween_property(holder, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	return holder


## A little speech bubble above a goal-card booster, gone after a moment.
func _bubble_tip(over: Control, text: String, font: Font) -> void:
	var tip := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#fffbeb")
	box.border_color = Color("#d6c4a8")
	box.set_border_width_all(3)
	box.set_corner_radius_all(18)
	box.set_content_margin_all(14)
	box.shadow_color = Color(0, 0, 0, 0.2)
	box.shadow_size = 6
	tip.add_theme_stylebox_override("panel", box)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color("#713f12"))
	tip.add_child(l)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(tip)
	tip.top_level = true
	await get_tree().process_frame
	if not is_instance_valid(tip):
		return
	var r := over.get_global_rect()
	tip.global_position = Vector2(r.get_center().x - tip.size.x / 2.0, r.position.y - tip.size.y - 8.0)
	var t := create_tween()
	t.tween_interval(1.6)
	t.tween_property(tip, "modulate:a", 0.0, 0.3)
	t.tween_callback(tip.queue_free)


## Boosters picked on the goal card become special arrows on the board as the level starts.
func _apply_picked_boosters() -> void:
	var delay := 0.4
	for kind: String in _picked_boosters:
		var pool: Array[ArrowPath] = []
		for a in maze.arrows:
			if a.special == ArrowPath.Special.NONE and not a.golden and a.ice <= 0 and a.timer <= 0 \
					and a.link_id < 0 and not a.flip:
				pool.append(a)
		if pool.is_empty() or GameData.booster_count(kind) <= 0:
			continue
		var arrow: ArrowPath = pool[randi() % pool.size()]
		GameData.add_booster(kind, -1)
		var special := (GameData.BOOSTERS.find(kind) + 1) as ArrowPath.Special
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if is_instance_valid(arrow) and maze.arrows.has(arrow):
				arrow.set_special(special)
				GameData.play_sfx("charge")
				maze._say(ArrowPath.SPECIAL_NAMES[special] + "!", arrow.base_color(), arrow.head(), 0.0))
		delay += 0.35
	_picked_boosters.clear()
	_refresh_hud()


## "How to make it" card the first time a special arrow appears (Candy Crush's Wrapped
## Candy screen): small arrows light up one by one, rush together and turn into the
## special arrow with a burst; the card says how many arrows in one tap make it.
func _special_showcase(kind: String) -> void:
	maze.input_enabled = false
	var font: Font = banner.get_theme_font("font")
	var layer := CanvasLayer.new()
	layer.layer = 41
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.18, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	var box := GameSkin.box(Color("#eff6ff"), Color("#93c5fd"), 44, 12)
	box.set_content_margin_all(34)
	box.shadow_color = Color(0.05, 0.0, 0.2, 0.45)
	box.shadow_size = 24
	panel.add_theme_stylebox_override("panel", box)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var title := Label.new()
	title.text = ArrowPath.SPECIAL_NAMES[GameData.BOOSTERS.find(kind) + 1]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 50)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color("#1e3a8a"))
	title.add_theme_constant_override("outline_size", 14)
	col.add_child(title)

	# The little film: n arrows -> one special arrow.
	var n: int = CHAIN_FOR[kind]
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(530, 250)
	col.add_child(stage)
	var tint := ArrowPath.ARROW_COLORS[GameData.BOOSTERS.find(kind) % 6]
	var gap := minf(92.0, 480.0 / n)
	var start_x := 265.0 - gap * (n - 1) / 2.0
	var pieces: Array[TextureRect] = []
	for i in n:
		var a := TextureRect.new()
		a.texture = preload("res://icons/arrow_white.svg")
		a.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		a.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		a.size = Vector2(84, 84)
		a.pivot_offset = a.size / 2.0
		a.position = Vector2(start_x + gap * i - 42.0, 30.0)
		a.modulate = tint
		stage.add_child(a)
		pieces.append(a)
	var burst := TextureRect.new()
	burst.texture = POWER_SUNBURST
	burst.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	burst.size = Vector2(250, 250)
	burst.pivot_offset = burst.size / 2.0
	burst.position = Vector2(265.0 - 125.0, 110.0 - 125.0 + 30.0)
	stage.add_child(burst)
	var result := TextureRect.new()
	result.texture = POWER_ICONS[kind]
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.size = Vector2(150, 150)
	result.pivot_offset = result.size / 2.0
	result.position = Vector2(265.0 - 75.0, 140.0 - 75.0)
	stage.add_child(result)
	var spin := burst.create_tween().set_loops()
	spin.tween_property(burst, "rotation", TAU, 6.0).from(0.0)
	var film := stage.create_tween().set_loops()
	film.tween_callback(func() -> void:
		for i in n:
			pieces[i].position = Vector2(start_x + gap * i - 42.0, 30.0)
			pieces[i].modulate.a = 0.0
			pieces[i].scale = Vector2.ONE * 0.4
		burst.modulate.a = 0.0
		result.scale = Vector2.ZERO)
	for i in n:   # light up one by one
		film.tween_property(pieces[i], "modulate:a", 1.0, 0.1)
		film.parallel().tween_property(pieces[i], "scale", Vector2.ONE * 1.15, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		film.tween_callback(GameData.play_sfx.bind("pop", 1.0 + i * 0.08))
	film.tween_interval(0.6)
	for i in n:   # rush together (the first step starts after the pause, the rest join it)
		var step := film.tween_property(pieces[i], "position", Vector2(265.0 - 42.0, 100.0), 0.3) if i == 0 			else film.parallel().tween_property(pieces[i], "position", Vector2(265.0 - 42.0, 100.0), 0.3)
		step.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		film.parallel().tween_property(pieces[i], "modulate:a", 0.0, 0.3)
	film.tween_callback(GameData.play_sfx.bind("charge"))
	film.tween_property(burst, "modulate:a", 0.9, 0.12)
	film.parallel().tween_property(result, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	film.tween_interval(1.3)
	film.tween_property(result, "scale", Vector2.ZERO, 0.2)
	film.parallel().tween_property(burst, "modulate:a", 0.0, 0.2)
	film.tween_interval(0.3)

	var how := RichTextLabel.new()
	how.bbcode_enabled = true
	how.fit_content = true
	how.scroll_active = false
	how.custom_minimum_size = Vector2(530, 0)
	how.add_theme_font_size_override("normal_font_size", 28)
	how.add_theme_font_size_override("bold_font_size", 28)
	how.add_theme_font_override("bold_font", font)
	how.add_theme_color_override("default_color", Color("#1e3a8a"))
	how.text = "[center]Clear [b]%d arrows[/b] in ONE tap to make it.\n%s![/center]" % [n, GameData.BOOSTER_INFO[kind]]
	col.add_child(how)
	var ok := _popup_button(col, "GOT IT!", "", Color("#22c55e"), Color("#15803d"), Color.WHITE, font, 96.0)
	ok.pressed.connect(func() -> void:
		GameData.play_sfx("tap")
		layer.queue_free()
		maze.input_enabled = playing)
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size / 2.0)
	panel.scale = Vector2.ONE * 0.8
	create_tween().tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A small rounded tag with bold text (the limit, HARD LEVEL).
func _briefing_pill(text: String, bg: Color, ink: Color, font: Font) -> Control:
	var pill := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(24)
	box.content_margin_left = 26
	box.content_margin_right = 26
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	box.anti_aliasing = true
	pill.add_theme_stylebox_override("panel", box)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", ink)
	pill.add_child(l)
	return pill


## This level's goals for the card: [kind, icon path, count, icon tint].
func _briefing_goals() -> Array:
	var icons := {"golden": "res://icons/fx/goal_golden.png",
		"balloons": "res://icons/fx/goal_balloon_0.png", "targets": "res://icons/fx/goal_target.png",
		"crates": "res://icons/fx/goal_crate_1.png", "ice": "res://icons/fx/goal_ice_2.png", "color": "res://icons/arrow_white.svg"}
	var counts := _goal_counts()
	var out := []
	for kind: String in ["golden", "balloons", "targets", "crates", "ice", "color"]:
		var total: int = counts[kind][0]
		if total <= 0:
			continue
		var tint := Color.WHITE
		if kind == "color":
			tint = ArrowPath.ARROW_COLORS[_order_color % ArrowPath.ARROW_COLORS.size()]
		out.append([kind, icons[kind], total, tint])
	if _crush_goal > 0:
		out.push_front(["crush", "res://icons/fx/goal_crush.png", _crush_goal, Color.WHITE])
	elif out.is_empty():
		out.append(["arrows", "res://icons/arrow_white.svg", total_arrows, GameSkin.VIOLET])
	return out


## "Pop 3 balloons and break the crates!" - the goals in one plain sentence.
## On a crush level: "Crush 12 arrows!" and, on a line of its own, the bonus pieces.
func _briefing_sentence(goals: Array, with_bonus: bool = true) -> String:
	if not goals.is_empty() and goals[0][0] == "crush":
		var n := int(goals[0][2])
		var main := "Clear the board - crush %d on the way!" % n
		if not with_bonus:
			return "Crush %d & clear the board" % n
		if goals.size() == 1:
			return main + "\nSame colours crush - flying out doesn't add to it."
		var rest := _briefing_sentence(goals.slice(1))
		return main + "\nAnd " + rest.substr(0, 1).to_lower() + rest.substr(1)
	var parts: Array[String] = []
	for g: Array in goals:
		var n: int = g[2]
		match String(g[0]):
			"golden": parts.append("fly the golden arrow out" if n == 1 else "fly %d golden arrows out" % n)
			"balloons": parts.append("pop %d balloon%s" % [n, "" if n == 1 else "s"])
			"targets": parts.append("hit %d target%s" % [n, "" if n == 1 else "s"])
			"crates": parts.append("break the crates")
			"ice": parts.append("crack the ice")
			"color": parts.append("clear %d arrows of this colour" % n)
			_: parts.append("clear all %d arrows" % n)
	var text := parts[0]
	if parts.size() > 1:
		text = ", ".join(PackedStringArray(parts.slice(0, parts.size() - 1))) + " and " + parts[-1]
	return text.substr(0, 1).to_upper() + text.substr(1) + "!"


## Adds a chunky 3D button to a small popup's column.
func _popup_button(col: VBoxContainer, text: String, icon_path: String, face: Color, lip: Color, ink: Color,
		font: Font, height: float = 100.0, price: int = -1) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 32)
	GameSkin.button_3d(b, face, lip, ink, font)
	if icon_path != "" or price >= 0:
		# Icon, text and price as one centred group (see GameSkin.dress).
		GameSkin.dress(b, text.strip_edges(), load(icon_path) if icon_path != "" else null, price)
	col.add_child(b)
	return b


## Small "watch a video?" dialog. `on_reward` runs only after the full video.
func _offer_ad(title: String, message: String, reward: String, on_reward: Callable) -> void:
	var pop := _small_popup("", title, message)
	var close: Callable = pop.close
	var watch := _popup_button(pop.col, "Watch video", "res://icons/play_ad.svg", Color("#22c55e"), Color("#15803d"), Color.WHITE, pop.font)
	var no := _popup_button(pop.col, "No thanks", "", Color("#ede9fe"), GameSkin.CARD_LIP, GameSkin.VIOLET, pop.font, 84.0)
	no.pressed.connect(close)
	watch.pressed.connect(func() -> void:
		close.call()
		_rewarded(reward, on_reward))


## A power the player hasn't reached yet: when it unlocks, and that's all.
func _locked_power(kind: String) -> void:
	GameData.play_sfx("tap")
	var icon: String = "res://icons/bolt.svg" if kind == "drill" else BOOSTER_ICONS[kind]
	var pop := _small_popup(icon, GameData.BOOSTER_NAMES[kind],
		"%s\n\nUnlocks at level %d - keep going!" % [GameData.BOOSTER_INFO[kind], int(GameData.BOOSTER_UNLOCK[kind])])
	var ok := _popup_button(pop.col, "OK", "", Color("#ede9fe"), GameSkin.CARD_LIP, GameSkin.VIOLET, pop.font, 88.0)
	ok.pressed.connect(pop.close)


## A power just unlocked: a celebration popup, the free ones go into stock, and
## "Try it!" arms it straight away. One power per level start.
func _introduce_new_power() -> void:
	var kinds := GameData.new_unlocks()
	if kinds.is_empty() or not playing:
		return
	var kind: String = kinds[0]
	GameData.claim_unlock(kind)
	GameData.play_sfx("ding")
	GameData.play_sfx("glint")
	_power_card(kind)
	_refresh_hud()
	# The new button pops on the bar.
	var b: Button = _booster_buttons[kind]
	var t := create_tween()
	t.tween_property(b, "scale", Vector2.ONE * 1.3, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## The "NEW POWER!" card (art drawn in Affinity): banner over the top edge, a slowly
## turning gold sunburst behind the big power icon, sparkles, the gift, Try it / Later.
func _power_card(kind: String) -> void:
	maze.input_enabled = false
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.07, 0.03, 0.2, 0.68)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 0)
	var box := GameSkin.box(Color.WHITE, GameSkin.CARD_LIP, 46, 12)
	box.content_margin_left = 40
	box.content_margin_right = 40
	box.content_margin_top = 10
	box.content_margin_bottom = 38
	box.shadow_color = Color(0.05, 0.0, 0.2, 0.5)
	box.shadow_size = 26
	box.shadow_offset = Vector2(0, 10)
	panel.add_theme_stylebox_override("panel", box)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	# Banner sticking out above the card.
	var top := Control.new()
	top.custom_minimum_size = Vector2(0, 30)
	col.add_child(top)
	var ban := TextureRect.new()
	ban.texture = POWER_BANNER
	ban.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ban.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ban.size = Vector2(520, 520.0 * POWER_BANNER.get_height() / POWER_BANNER.get_width())
	ban.position = Vector2(0, -ban.size.y * 0.62)
	top.add_child(ban)
	top.resized.connect(func() -> void: ban.position.x = (top.size.x - ban.size.x) / 2.0)

	# Art: sunburst + glow + icon + sparkles.
	var art := Control.new()
	art.custom_minimum_size = Vector2(0, 250)
	col.add_child(art)
	var burst := TextureRect.new()
	burst.texture = POWER_SUNBURST
	burst.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	burst.size = Vector2(420, 420)
	burst.pivot_offset = burst.size / 2.0
	burst.modulate = Color("#fbbf24", 0.85)
	art.add_child(burst)
	var glow := Panel.new()
	var glow_box := StyleBoxFlat.new()
	glow_box.bg_color = Color("#fef3c7")
	glow_box.set_corner_radius_all(90)
	glow_box.anti_aliasing = true
	glow.add_theme_stylebox_override("panel", glow_box)
	glow.size = Vector2(180, 180)
	art.add_child(glow)
	var icon := TextureRect.new()
	icon.texture = POWER_ICONS.get(kind, POWER_ICONS["drill"])
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(210, 210)
	icon.pivot_offset = icon.size / 2.0
	art.add_child(icon)
	var sparks: Array[TextureRect] = []
	for i in 4:
		var sp := TextureRect.new()
		sp.texture = MazeBoard.FX_SPARKLE
		sp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sp.size = Vector2(46, 46)
		sp.pivot_offset = sp.size / 2.0
		sp.scale = Vector2.ZERO
		art.add_child(sp)
		sparks.append(sp)
	art.resized.connect(func() -> void:
		var c := art.size / 2.0
		burst.position = c - burst.size / 2.0
		glow.position = c - glow.size / 2.0
		icon.position = c - icon.size / 2.0
		var spots := [Vector2(-130, -70), Vector2(125, -85), Vector2(-115, 80), Vector2(135, 60)]
		for i in sparks.size():
			sparks[i].position = c + spots[i] - sparks[i].size / 2.0)
	var spin := burst.create_tween().set_loops()
	spin.tween_property(burst, "rotation", TAU, 14.0).from(0.0)
	icon.scale = Vector2.ZERO
	var pop := icon.create_tween()
	pop.tween_interval(0.15)
	pop.tween_property(icon, "scale", Vector2.ONE * 1.15, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(icon, "scale", Vector2.ONE, 0.18)
	var bob := icon.create_tween().set_loops()
	bob.tween_property(icon, "rotation", 0.07, 1.1).set_trans(Tween.TRANS_SINE)
	bob.tween_property(icon, "rotation", -0.07, 1.1).set_trans(Tween.TRANS_SINE)
	for i in sparks.size():
		var tw := sparks[i].create_tween().set_loops()
		tw.tween_interval(0.25 * i + 0.2)
		tw.tween_property(sparks[i], "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(sparks[i], "scale", Vector2.ZERO, 0.3)
		tw.tween_interval(0.6)

	var heavy := SystemFont.new()
	heavy.font_names = PackedStringArray(["Nunito", "Roboto", "Segoe UI", "Arial", "sans-serif"])
	heavy.font_weight = 900
	var name_l := Label.new()
	name_l.text = GameData.BOOSTER_NAMES[kind]
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_override("font", banner.get_theme_font("font"))
	name_l.add_theme_font_size_override("font_size", 52)
	name_l.add_theme_color_override("font_color", GameSkin.VIOLET_DARK)
	col.add_child(name_l)
	var info := Label.new()
	info.text = GameData.BOOSTER_INFO[kind]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 28)
	info.add_theme_color_override("font_color", Color("#6b6a8a"))
	col.add_child(info)

	# Gift pill: "2 FREE"
	var gift := PanelContainer.new()
	gift.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var gbox := GameSkin.box(Color("#fef3c7"), Color("#fcd34d"), 30, 5)
	gbox.shadow_size = 0
	gbox.content_margin_left = 18
	gbox.content_margin_right = 24
	gbox.content_margin_top = 4
	gbox.content_margin_bottom = 8
	gift.add_theme_stylebox_override("panel", gbox)
	var grow := HBoxContainer.new()
	grow.add_theme_constant_override("separation", 10)
	gift.add_child(grow)
	var gicon := TextureRect.new()
	gicon.texture = load("res://icons/gift.svg")
	gicon.custom_minimum_size = Vector2(40, 40)
	gicon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gicon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	grow.add_child(gicon)
	var gl := Label.new()
	gl.text = "%d FREE" % GameData.UNLOCK_GIFT
	gl.add_theme_font_override("font", banner.get_theme_font("font"))
	gl.add_theme_font_size_override("font_size", 32)
	gl.add_theme_color_override("font_color", Color("#92400e"))
	grow.add_child(gl)
	col.add_child(gift)

	var close := func() -> void:
		layer.queue_free()
		maze.input_enabled = playing
	var try_it := _popup_button(col, "Try it!", "", Color("#22c55e"), Color("#15803d"), Color.WHITE, heavy)
	var later := _popup_button(col, "Later", "", Color("#ede9fe"), GameSkin.CARD_LIP, GameSkin.VIOLET, heavy, 84.0)
	later.pressed.connect(func() -> void:
		close.call()
		_refresh_hud())
	try_it.pressed.connect(func() -> void:
		close.call()
		GameData.play_sfx("charge")
		_set_armed(kind)
		_refresh_hud())
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size / 2.0)
	panel.scale = Vector2.ONE * 0.7
	panel.create_tween().tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A booster ran out: one more for a video, or for coins - right here, no shop.
## Either way it comes back armed, ready to use on the next tap.
func _offer_booster(kind: String) -> void:
	GameData.play_sfx("tap")
	var icon: String = "res://icons/bolt.svg" if kind == "drill" else BOOSTER_ICONS[kind]
	var pop := _small_popup(icon, GameData.BOOSTER_NAMES[kind], GameData.BOOSTER_INFO[kind])
	var close: Callable = pop.close
	var price := int(GameData.PRICES[kind])
	var watch := _popup_button(pop.col, "+1 Free", "res://icons/play_ad.svg",
		Color("#22c55e"), Color("#15803d"), Color.WHITE, pop.font)
	var buy := _popup_button(pop.col, "Buy", "", GameSkin.GOLD, GameSkin.GOLD_LIP, GameSkin.GOLD_TEXT, pop.font, 92.0, price)
	var have := Label.new()
	have.text = "You have %d coins" % GameData.coins
	have.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	have.add_theme_font_override("font", pop.font)
	have.add_theme_font_size_override("font_size", 22)
	have.add_theme_color_override("font_color", Color("#92400e"))
	pop.col.add_child(have)
	pop.col.move_child(have, buy.get_index() + 1)
	if GameData.coins < price:
		buy.modulate.a = 0.5
	var no := _popup_button(pop.col, "No thanks", "", Color("#ede9fe"), GameSkin.CARD_LIP, GameSkin.VIOLET, pop.font, 84.0)
	no.pressed.connect(close)
	var give := func() -> void:
		GameData.play_sfx("charge")
		_set_armed(kind)
		if kind == "drill":
			helper_used.emit("power")
		_refresh_hud()
	watch.pressed.connect(func() -> void:
		close.call()
		_rewarded("+1 " + str(GameData.BOOSTER_NAMES[kind]), func() -> void:
			GameData.add_booster(kind, 1)
			give.call()))
	buy.pressed.connect(func() -> void:
		if not GameData.buy_booster(kind):
			_nope(buy)
			return
		close.call()
		give.call())


# --- HUD helpers ---------------------------------------------------------------------------------

func _fit_maze() -> void:
	maze.fit_to(Rect2(Vector2.ZERO, board_space.size))


func _refresh_hud() -> void:
	_save_dirty = true
	_update_goals()
	quiver_label.text = str(GameData.quiver)
	_update_worry()
	var cleared := 1.0 - float(maze.arrows.size()) / maxf(1.0, total_arrows)
	var goals := _goal_sum()
	if goals.x > 0:
		cleared = 1.0 - float(goals.y) / goals.x
	create_tween().tween_property(progress, "value", cleared, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i in hearts_row.get_child_count():
		(hearts_row.get_child(i) as TextureRect).texture = HEART_FULL_TEX if i < lives else HEART_EMPTY_TEX
	# A badge shows what's left; at zero it turns into a green "AD" (watch a video for more).
	_set_badge(undo_badge, undos_left)
	undo_button.disabled = maze.history.is_empty()
	_set_booster_badge(power_badge, GameData.power_charges)
	if GameData.booster_unlocked("drill"):
		power_button.self_modulate = Color.WHITE
	else:
		# Super Power is taught on level 5: until then a faded key with a grey "Lv 5".
		power_button.self_modulate = Color(1, 1, 1, 0.4)
		power_badge.visible = true
		power_badge.text = "Lv %d" % int(GameData.BOOSTER_UNLOCK["drill"])
		var ps := _ad_badge_style()
		ps.bg_color = Color("#8b8aa6")
		power_badge.add_theme_stylebox_override("normal", ps)
	for kind: String in BOOSTER_ICONS:
		var b: Button = _booster_buttons[kind]
		var badge: Label = b.get_meta("badge")
		if GameData.booster_unlocked(kind):
			b.self_modulate = Color.WHITE
			_set_booster_badge(badge, GameData.booster_count(kind))
		else:
			# Locked: a faded button (the tag stays crisp) with a grey "Lv 8" - a peek at what's coming.
			b.self_modulate = Color(1, 1, 1, 0.4)
			badge.visible = true
			badge.text = "Lv %d" % int(GameData.BOOSTER_UNLOCK[kind])
			var s := _ad_badge_style()
			s.bg_color = Color("#8b8aa6")
			badge.add_theme_stylebox_override("normal", s)
	power_button.progress = float(streak) / STREAK_FOR_POWER
	power_button.disabled = false
	_set_badge(hint_badge, hints_left + GameData.bonus_hints)
	hint_button.disabled = false


## Boosters: the count, or the green "AD" badge (video or coins for one more) when none are left.
func _set_booster_badge(badge: Label, count: int) -> void:
	_set_badge(badge, count)


func _set_badge(badge: Label, count: int) -> void:
	badge.visible = true
	if count > 0:
		badge.text = str(count)
		badge.remove_theme_stylebox_override("normal")
	else:
		badge.text = "AD"
		badge.add_theme_stylebox_override("normal", _ad_badge_style())


func _ad_badge_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#16a34a")
	s.border_color = Color.WHITE
	s.set_border_width_all(3)
	s.set_corner_radius_all(20)
	s.content_margin_left = 8
	s.content_margin_right = 8
	return s

## Bow meter in the level's theme colour.
func _style_progress(color: Color) -> void:
	progress.fill_color = color


# --- Level goals: moves and clock ----------------------------------------------------------------

## Spare moves on top of what the crush-first solver needs: about +30% on the first
## levels, shrinking to +1 by level 25 (hard / super-hard spike levels get less). From
## then on the player has to play close to perfectly - or use boosters.
func _move_slack(need: int) -> int:
	var k := clampf(1.0 - (level - 3) / 22.0, 0.0, 1.0)
	if GameData.level_spike(level) > 0.0:
		k *= 0.4
	return 1 + roundi(need * 0.3 * pow(k, 1.5))


## Sets this level's move limit and / or clock. Both get tighter with the level number:
## moves = taps a greedy crush-first solver needs (LevelGenerator.estimate_taps) plus
## _move_slack (+30% at the start down to +1 move by level 25); clock = seconds per
## arrow from 3.0 down to 1.4 by level 40.
func _setup_goal(data: Dictionary, tier: int) -> void:
	var goal := LevelGenerator.Goal.FREE
	if _daily < 0 and not _is_tutorial_level:
		goal = LevelGenerator.goal_for(level)
	has_moves = goal == LevelGenerator.Goal.MOVES or goal == LevelGenerator.Goal.BOTH
	has_clock = goal == LevelGenerator.Goal.TIME or goal == LevelGenerator.Goal.BOTH
	var both := has_moves and has_clock
	_tier = tier
	_fail = ""
	if has_moves:
		var need := LevelGenerator.estimate_taps(data.arrows, data.colors, data.cols, data.rows, data.get("mirrors", {}),
			data.get("prisms", []))
		need += int(data.get("hits", 0))  # taps spent smashing crates / cracking ice
		# Room for the order of play: crates and ice reward patience, not perfect play.
		var layers := 0
		for c: Vector2i in data.get("crates", {}):
			layers += int(data.crates[c])
		need += ceili(layers / 3.0)
		for i: int in data.get("ice", {}):
			need += int(data.ice[i])
		moves_left = need + _move_slack(need) + (2 if both else 0)
	if has_clock:
		# Seconds per arrow: 3.0 on the first levels down to 1.4 from level 40 on.
		var per_arrow := lerpf(3.0, 1.4, clampf((level - 1) / 39.0, 0.0, 1.0)) * (1.25 if both else 1.0)
		if GameData.level_spike(level) > 0.0:
			per_arrow *= 0.9
		# Labyrinth levels need thinking, not just fast fingers: up to +35% time.
		per_arrow *= 1.0 + 0.35 * float(data.get("harden", 0.0))
		time_left = snappedf(10.0 + total_arrows * per_arrow, 5.0)
		_clock_delay = 1.5
		_update_clock()
	_update_moves()
	if has_moves:
		_roll_moves_in()
	if both:
		_show_banner("MOVES + CLOCK", BOTH_COLOR)
	elif has_moves:
		_show_banner("%d MOVES" % moves_left, MOVES_COLOR)
	elif has_clock:
		_show_banner("BEAT THE CLOCK", TIME_COLOR)
	if GOAL_TIPS.has(level) and (has_moves or has_clock):
		tip_label.text = GOAL_TIPS[level]
		tip_label.add_theme_color_override("font_color", BOTH_COLOR if both else (MOVES_COLOR if has_moves else TIME_COLOR))
		tip_label.visible = true


## The big number in the header: moves left, else the clock, else "∞" (no limit).
## On levels with both, the clock sits small under it.
func _update_moves() -> void:
	var s := maxi(ceili(time_left), 0)
	var clock := "%d:%02d" % [s / 60, s % 60]
	if has_moves:
		big_number.text = str(maxi(moves_left, 0))
		big_caption.text = "MOVE" if moves_left == 1 else "MOVES"
	elif has_clock:
		big_number.text = clock
		big_caption.text = "TIME"
	else:
		big_number.text = "∞"
		big_caption.text = "MOVES"
	big_number.add_theme_font_size_override("font_size", 44 if big_number.text.length() > 3 else 56)
	clock_label.visible = false  # the clock has its own chip in the goal card (UI kit v2)
	clock_label.text = clock + " left"
	if _timer_chip:
		_timer_chip.visible = has_moves and has_clock
		_timer_label.text = clock
		_timer_label.add_theme_color_override("font_color", Color("#dc2626") if s <= 10 else GOAL_INK)
	var tight := (has_moves and moves_left <= 3) or (not has_moves and has_clock and s <= 10)
	big_number.add_theme_color_override("font_color", Color("#fb7185") if tight else Color("#fde047"))
	header.alarm = playing and ((has_moves and moves_left <= 5) or (has_clock and s <= 10))
	clock_label.add_theme_color_override("font_color", Color("#fb7185") if s <= 10 else Color.WHITE)
	_update_worry()


## Archie sweats while moves, time or hearts are nearly gone.
func _update_worry() -> void:
	mascot.worried = playing and ((has_moves and moves_left <= 3) or (has_clock and time_left <= 10.0) or lives == 1)


func _pulse(node: Control, amount: float = 1.25) -> void:
	node.pivot_offset = node.size / 2.0
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2.ONE * amount, 0.08)
	tw.tween_property(node, "scale", Vector2.ONE, 0.2)


## Called after every tap that counts. Runs out -> "Out of Moves" (unless that tap won).
func _spend_move() -> void:
	if not has_moves or not playing:
		return
	moves_left -= 1
	if _count_tween and _count_tween.is_valid():
		_count_tween.kill()
	_update_moves()
	_tick_moves()
	if moves_left > 0 or maze.arrows.is_empty():
		return
	_fail = "moves"
	playing = false
	maze.input_enabled = false
	await get_tree().create_timer(0.8).timeout
	if maze.arrows.is_empty() or _fail != "moves":
		return
	GameData.play_sfx("lose")
	GameData.vibrate(60)
	_record_result(false)
	_show_result("Out of Moves!", _near_miss("So close!") + "\nOne crush clears 2 arrows with 1 move." + _charge_arrow(), false)
	GameSkin.dress(continue_button, "+%d Moves" % AD_MOVES, GameSkin.VIDEO_TEX)


func _process(delta: float) -> void:
	# Heartbeat: the hearts thump every couple of seconds - fast when only one is left.
	_beat += delta
	var thump := pow(maxf(0.0, sin(_beat * (7.0 if lives == 1 else 2.6))), 14.0)
	hearts_row.pivot_offset = hearts_row.size / 2.0
	hearts_row.scale = Vector2.ONE * (1.0 + 0.12 * thump)
	# Save once the tap has fully played out (never half-way through a chain).
	if _save_dirty and playing and not _finishing and maze.is_settled():
		_write_resume()
	# Hint lesson: a player on an early level who hasn't tapped for a while is stuck.
	if playing and maze.input_enabled and not _lesson_busy and level >= 3 and level <= 8 \
			and not _paused_card and not _away:
		_idle += delta
		if _idle > 8.0:
			_idle = 0.0
			_hint_lesson()
	# Later levels: a stuck player sees the hint button bounce (sooner when they're behind).
	elif playing and maze.input_enabled and not _lesson_busy and not _paused_card and not _away \
			and not _is_tutorial_level and not _briefing and _armed == "" and _nudges < 2:
		_idle += delta
		if _idle > (10.0 if _need_help or _behind() else 20.0):
			_idle = 0.0
			_nudge_hint()
	# The clock stops whenever the board is paused (popups, options, ads).
	if not has_clock or not playing or not maze.input_enabled or _away or _paused_card:
		return
	delta = minf(delta, 0.1)  # a long frame (app hitched or just came back) never eats seconds
	if _clock_delay > 0.0:
		_clock_delay -= delta
		return
	var before := ceili(time_left)
	time_left -= delta
	if ceili(time_left) != before:
		_update_clock()
		if time_left <= 10.0 and time_left > 0.0:
			GameData.play_sfx("tap")  # tick-tock in the last 10 seconds
	if time_left <= 0.0:
		_time_up()


func _update_clock() -> void:
	if not has_clock:
		return
	_update_moves()
	if ceili(time_left) <= 10:
		_pulse(clock_label if has_moves else big_number, 1.15)


## Crush bonus: more seconds, with a green flash on the clock.
func _add_time(seconds: float) -> void:
	time_left += seconds
	_update_clock()
	var clock_node: Control = clock_label if has_moves else big_number
	var below_clock := clock_node.get_global_rect().get_center() + Vector2(0, 60)
	_float_text("+%ds" % seconds, BONUS_COLOR, maze.get_global_transform().affine_inverse() * below_clock)
	clock_node.modulate = Color("#86efac")
	create_tween().tween_property(clock_node, "modulate", Color.WHITE, 0.6)


func _time_up() -> void:
	time_left = 0.0
	_update_clock()
	playing = false
	maze.input_enabled = false
	_fail = "time"
	GameData.play_sfx("lose")
	GameData.vibrate(60)
	_record_result(false)
	_show_result("Time's Up!", _near_miss("So close!") + "\nEvery arrow out adds time - crushes add more." + _charge_arrow(), false)
	GameSkin.dress(continue_button, "+%d Seconds" % AD_SECONDS, GameSkin.VIDEO_TEX)


## The header ribbon behind the level name takes the difficulty colour.
func _style_badge(tier: int) -> void:
	header.ribbon_face = RIBBON_COLORS[tier][0]
	header.ribbon_dark = RIBBON_COLORS[tier][1]
	var gold := tier <= 1
	level_label.add_theme_color_override("font_color", Color("#6b2a0a") if gold else Color.WHITE)
	level_label.add_theme_color_override("font_outline_color", Color("#fde68a") if gold else RIBBON_COLORS[tier][1].darkened(0.3))
	level_label.add_theme_constant_override("outline_size", 4 if gold else 10)
	level_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.0 if gold else 0.25))


## A banner drawn in Affinity (FINAL VOLLEY! / ALL GOALS DONE! / VICTORY!): it slams in
## with a tilt, holds, then fades - same timing as the text banners.
func _show_banner_image(tex: Texture2D, width: float = 560.0) -> void:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := get_viewport().get_visible_rect().size
	var h := width * tex.get_height() / float(tex.get_width())
	r.size = Vector2(width, h)
	r.position = Vector2((view.x - width) / 2.0, view.y * 0.4 - h / 2.0)
	r.pivot_offset = r.size / 2.0
	banner.get_parent().add_child(r)
	r.modulate.a = 0.0
	r.scale = Vector2.ONE * 0.35
	r.rotation = -0.14
	var t := r.create_tween()
	t.tween_property(r, "modulate:a", 1.0, 0.1)
	t.parallel().tween_property(r, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(r, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.85)
	t.tween_property(r, "modulate:a", 0.0, 0.3)
	t.parallel().tween_property(r, "scale", Vector2.ONE * 1.12, 0.3)
	t.tween_callback(r.queue_free)


func _show_banner(text: String, color: Color) -> void:
	if _briefing:
		_held_banners.append([text, color])  # shown once the goal card's PLAY is pressed
		return
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.pivot_offset = banner.size / 2
	banner.show()
	banner.modulate.a = 0.0
	banner.scale = Vector2.ONE * 0.4
	banner.rotation = -0.12
	var t := create_tween()
	t.tween_property(banner, "modulate:a", 1.0, 0.12)
	t.parallel().tween_property(banner, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(banner, "rotation", 0.0, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.8)
	t.tween_property(banner, "modulate:a", 0.0, 0.3)
	t.tween_callback(banner.hide)


func _on_zoomed() -> void:
	if not GameData.zoom_tip_seen:
		GameData.zoom_tip_seen = true
		GameData.save_game()
		if tip_label.text == ZOOM_TIP_TEXT:
			tip_label.visible = level <= 3
			tip_label.text = TIP_TEXT


## Floating combo / special text that rises from the board and fades.
func _float_text(text: String, color: Color, at: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", banner.get_theme_font("font"))
	label.add_theme_font_size_override("font_size", 46 if text.length() < 12 else 40)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 14)
	hud.add_child(label)
	label.size = label.get_minimum_size()
	var view := get_viewport().get_visible_rect().size
	var screen := maze.get_global_transform() * at
	label.position = Vector2(clampf(screen.x - label.size.x / 2.0, 8.0, view.x - label.size.x - 8.0), screen.y - label.size.y / 2.0)
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2.ONE * 0.4
	label.rotation = randf_range(-0.12, 0.12)
	var t := create_tween()
	t.tween_property(label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(label, "rotation", 0.0, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(label, "position:y", label.position.y - 90.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.65)
	t.tween_callback(label.queue_free)


func _pop_arrow_counter() -> void:
	_update_goals()


## Level start: the moves counter rolls up from 0 and lands with a bounce.
func _roll_moves_in() -> void:
	var target := moves_left
	if _count_tween and _count_tween.is_valid():
		_count_tween.kill()
	big_number.text = "0"
	_count_tween = create_tween()
	_count_tween.tween_interval(0.35)
	_count_tween.tween_method(func(v: float) -> void:
		big_number.text = str(roundi(v)), 0.0, float(target), 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_count_tween.tween_callback(func() -> void:
		GameData.play_sfx("star")
		_pulse(big_number, 1.3))


## A move was used: the number squashes and bounces back, and a "-1" floats off it.
func _tick_moves() -> void:
	big_number.pivot_offset = big_number.size / 2.0
	big_number.scale = Vector2(1.35, 0.7)
	create_tween().tween_property(big_number, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var minus := Label.new()
	minus.text = "-1"
	minus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minus.add_theme_font_override("font", banner.get_theme_font("font"))
	minus.add_theme_font_size_override("font_size", 30)
	minus.add_theme_color_override("font_color", Color("#fb7185"))
	minus.add_theme_color_override("font_outline_color", Color.WHITE)
	minus.add_theme_constant_override("outline_size", 8)
	hud.add_child(minus)
	minus.size = minus.get_minimum_size()
	var rect := big_number.get_global_rect()
	minus.position = Vector2(rect.end.x - minus.size.x * 0.6, rect.position.y)
	var t := create_tween()
	t.tween_property(minus, "position:y", minus.position.y - 40.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(minus, "modulate:a", 0.0, 0.3).set_delay(0.3)
	t.tween_callback(minus.queue_free)
	if moves_left <= 5:
		GameData.vibrate(15)


## A heart is lost: two pieces of it spin away and fall, the row shakes.
func _break_heart(index: int) -> void:
	if index < 0 or index >= hearts_row.get_child_count():
		return
	var heart := hearts_row.get_child(index) as TextureRect
	var rect := heart.get_global_rect()
	for side: float in [-1.0, 1.0]:
		var piece := TextureRect.new()
		piece.texture = heart.texture
		piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		piece.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece.size = rect.size * 0.75
		piece.position = rect.get_center() - piece.size / 2.0 + Vector2(side * 5.0, 0)
		piece.pivot_offset = piece.size / 2.0
		hud.add_child(piece)
		var t := create_tween().set_parallel()
		t.tween_property(piece, "position", piece.position + Vector2(side * 34.0, 70.0), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(piece, "rotation", side * 1.4, 0.7)
		t.tween_property(piece, "modulate:a", 0.0, 0.4).set_delay(0.3)
		t.chain().tween_callback(piece.queue_free)
	var row_x := hearts_row.position.x
	var shake := create_tween()
	for dx: float in [-6.0, 6.0, -4.0, 4.0, 0.0]:
		shake.tween_property(hearts_row, "position:x", row_x + dx, 0.04)


func _pop_heart(index: int) -> void:
	if index < 0 or index >= hearts_row.get_child_count():
		return
	var heart := hearts_row.get_child(index) as Control
	heart.pivot_offset = heart.size / 2
	var t := create_tween()
	t.tween_property(heart, "scale", Vector2.ONE * 1.5, 0.08)
	t.tween_property(heart, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)



func _show_result(title: String, message: String, won: bool) -> void:
	header.alarm = false
	if not won:
		mascot.worried = false
		mascot.react("sad")
	result_title.text = title
	result_message.text = message
	stars_row.visible = won
	var fail_art := {"time": ["fail_time", "banner_time_up"], "moves": ["fail_moves", "banner_out_moves"],
		"hearts": ["fail_hearts", "banner_out_hearts"]}
	var art: Array = fail_art.get(_fail, []) if not won else []
	if _fail_art:
		_fail_art.visible = not art.is_empty()
		_fail_banner.visible = not art.is_empty()
		result_title.visible = art.is_empty()
		if not art.is_empty():
			_fail_art.texture = load("res://icons/fx/%s.png" % art[0])
			_fail_banner.texture = load("res://icons/fx/%s.png" % art[1])
			_fail_art.scale = Vector2.ZERO
			var pop := _fail_art.create_tween()
			pop.tween_interval(0.15)
			pop.tween_property(_fail_art, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			# A little shiver: the alarm rings, the heart trembles, the quiver wobbles.
			pop.tween_property(_fail_art, "rotation", 0.08, 0.06)
			pop.tween_property(_fail_art, "rotation", -0.08, 0.08)
			pop.tween_property(_fail_art, "rotation", 0.05, 0.08)
			pop.tween_property(_fail_art, "rotation", 0.0, 0.08)
	if _picture_frame:
		_picture_frame.visible = won
		_picture_frame.get_child(0).queue_redraw()
	for c in _reward_row.get_children():
		c.queue_free()
	_reward_row.visible = false
	next_button.visible = won and level < GameData.MAX_LEVELS
	retry_button.text = "Replay" if won else "Retry"
	continue_button.visible = not won
	for star: TextureRect in stars_row.get_children():
		star.texture = STAR_OFF_TEX
		star.modulate = Color.WHITE
		star.scale = Vector2.ONE
	if not won:
		(func() -> void: _write_resume([title, message, GameSkin.text_of(continue_button), continue_button.visible])).call_deferred()
	result_popup.show()
	result_popup.modulate.a = 0.0
	result_panel.scale = Vector2.ONE * 0.7
	var t := create_tween()
	t.tween_property(result_popup, "modulate:a", 1.0, 0.2)
	t.parallel().tween_property(result_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if won:
		# Stars light up one by one: 3 hearts left = 3 stars.
		for i in mini(lives, 3):
			var star := stars_row.get_child(i) as Control
			t.tween_callback(func() -> void:
				star.pivot_offset = star.size / 2
				(star as TextureRect).texture = STAR_ON_TEX
				GameData.play_sfx("star"))
			t.tween_property(star, "scale", Vector2.ONE * 1.35, 0.1)
			t.tween_property(star, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
