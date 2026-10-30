extends Control
## Daily Challenge calendar. One big maze per day - the same maze for everyone,
## built from the date (no server). Finished days get a tick, today glows, missed
## past days can be opened with a rewarded video. Built in code.

const GAME_SCENE := "res://scenes/GameScene.tscn"
const LEVEL_SELECT := "res://scenes/LevelSelect.tscn"
const WEEKDAYS := ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

var _month_offset := 0          # 0 = this month, -1 = last month, ...
var _grid: GridContainer
var _month_label: Label
var _count_label: Label
var _next_month: Button


func _ready() -> void:
	GameData.set_music_pitch(1.06)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 40 + int(GameData.safe_insets().x))
	margin.add_theme_constant_override("margin_bottom", 40 + int(GameData.safe_insets().y))
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)
	margin.add_child(col)

	var bar := HBoxContainer.new()
	col.add_child(bar)
	var back := Button.new()
	back.icon = load("res://icons/back.svg")
	back.custom_minimum_size = Vector2(76, 76)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(LEVEL_SELECT))
	bar.add_child(back)
	var title := Label.new()
	title.text = "Daily Challenge"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("#1e3a8a"))
	bar.add_child(title)
	var streak := Button.new()
	streak.icon = load("res://icons/flame.svg")
	streak.text = str(GameData.streak)
	streak.custom_minimum_size = Vector2(110, 76)
	streak.disabled = true
	streak.add_theme_color_override("font_disabled_color", Color("#ea580c"))
	bar.add_child(streak)

	var play := Button.new()
	play.text = "Play today - " + GameData.day_label(GameData.utc_day())
	play.theme_type_variation = &"PrimaryButton"
	play.custom_minimum_size = Vector2(0, 110)
	play.add_theme_font_size_override("font_size", 36)
	play.pressed.connect(_play.bind(GameData.utc_day()))
	if GameData.daily_done.has(GameData.utc_day()):
		play.text = "Today's challenge done! Replay"
	col.add_child(play)

	var nav := HBoxContainer.new()
	col.add_child(nav)
	var prev := Button.new()
	prev.text = "‹"
	prev.custom_minimum_size = Vector2(80, 70)
	prev.pressed.connect(func() -> void:
		_month_offset -= 1
		_fill_month())
	nav.add_child(prev)
	_month_label = Label.new()
	_month_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_month_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_month_label.add_theme_font_size_override("font_size", 34)
	nav.add_child(_month_label)
	_next_month = Button.new()
	_next_month.text = "›"
	_next_month.custom_minimum_size = Vector2(80, 70)
	_next_month.pressed.connect(func() -> void:
		_month_offset += 1
		_fill_month())
	nav.add_child(_next_month)

	_grid = GridContainer.new()
	_grid.columns = 7
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_grid)

	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.add_theme_color_override("font_color", Color("#64748b"))
	col.add_child(_count_label)
	_fill_month()


## Rebuilds the calendar for the month `_month_offset` months from now (UTC).
func _fill_month() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var today := GameData.utc_day()
	var now := Time.get_date_dict_from_unix_time(today * 86400)
	var year := int(now.year)
	var month := int(now.month) + _month_offset
	while month < 1:
		month += 12
		year -= 1
	while month > 12:
		month -= 12
		year += 1
	_next_month.disabled = _month_offset >= 0
	_month_label.text = "%s %d" % [GameData.MONTHS[month - 1], year]

	var first := int(Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": 1, "hour": 0, "minute": 0, "second": 0}) / 86400)
	var weekday := int(Time.get_date_dict_from_unix_time(first * 86400).weekday)  # 0 = Sunday
	var lead := (weekday + 6) % 7  # calendar starts on Monday
	for w in WEEKDAYS:
		var h := Label.new()
		h.text = w
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_theme_color_override("font_color", Color("#94a3b8"))
		h.add_theme_font_size_override("font_size", 24)
		_grid.add_child(h)
	for i in lead:
		_grid.add_child(Control.new())

	var done_count := 0
	var days_in_month := 0
	var day := first
	while int(Time.get_date_dict_from_unix_time(day * 86400).month) == month:
		days_in_month += 1
		if GameData.daily_done.has(day):
			done_count += 1
		_grid.add_child(_day_button(day, today))
		day += 1
	_count_label.text = "%d / %d days completed" % [done_count, days_in_month]


func _day_button(day: int, today: int) -> Button:
	var b := Button.new()
	var number := int(Time.get_date_dict_from_unix_time(day * 86400).day)
	b.custom_minimum_size = Vector2(84, 84)
	b.add_theme_font_size_override("font_size", 28)
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(42)
	if GameData.daily_done.has(day):
		b.text = "✓"
		box.bg_color = Color("#22c55e")
		b.add_theme_color_override("font_color", Color.WHITE)
		b.pressed.connect(_play.bind(day))
	elif day == today:
		b.text = str(number)
		box.bg_color = Color("#2563eb")
		box.border_color = Color("#fde047")
		box.set_border_width_all(4)
		b.add_theme_color_override("font_color", Color.WHITE)
		b.pressed.connect(_play.bind(day))
	elif day < today:
		# Missed day: open it with a short video.
		b.text = str(number)
		b.icon = load("res://icons/play_ad.svg") if not GameData.daily_unlocked.has(day) else null
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 26)
		box.bg_color = Color("#e2e8f0")
		b.add_theme_color_override("font_color", Color("#475569"))
		b.pressed.connect(_unlock_past.bind(day))
	else:
		b.text = str(number)
		b.disabled = true
		box.bg_color = Color("#f8fafc")
	for s in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, box)
	return b


func _unlock_past(day: int) -> void:
	if GameData.daily_unlocked.has(day):
		_play(day)
		return
	AdManager.show_rewarded("Unlock " + GameData.day_label(day), func() -> void:
		GameData.daily_unlocked[day] = true
		GameData.save_game()
		_play(day))


func _play(day: int) -> void:
	GameData.play_sfx("tap")
	GameData.daily_day = day
	get_tree().change_scene_to_file(GAME_SCENE)
