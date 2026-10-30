extends Control
## Home - "the archer's camp" under a violet night sky (HomeSky), with a floating tab bar:
##   Main  - Archie + level chip, a big archery target with the level on its bullseye,
##           world progress, a gold PLAY button, Daily and Streak tiles
##   Daily - hero card for the picked day (countdown, play / replay / unlock) and a calendar
##   Me    - Archie with an archer rank earned by stars, stat tiles, quick sound / vibration
##           switches, help and privacy pages
## Built in code; a tab is rebuilt every time it is opened.

const GAME_SCENE := "res://scenes/GameScene.tscn"
const SLOT_TEX := preload("res://icons/fx/hud_slot.png")
const HUD_ROW := 88.0     # top-bar resource chip height (= portrait size, so centres line up)
const SLOT_H := 46.0      # dark slot body height
const SLOT_LEFT := 30.0   # where the slot starts under the icon
const VIOLET := Color("#7c3aed")
const VIOLET_DARK := Color("#4c1d95")
const LILAC := Color("#c4b5fd")
const GOLD := Color("#fbbf24")
const GOLD_LIP := Color("#b45309")
const GOLD_TEXT := Color("#7c2d12")
const CORAL := Color("#e11d48")
const TEXT := Color("#1e1b4b")
const MUTED := Color("#8b8aa8")
const CARD_LIP := Color("#c4b5fd")
const BAR_H := 112.0
const BAR_GAP := 16.0
const TABS: Array[Array] = [["Main", "tab_home"], ["Daily", "tab_daily"], ["Me", "tab_me"]]
const WEEKDAYS := ["M", "T", "W", "T", "F", "S", "S"]
const LEVELS_PER_WORLD := 20
const WORLD_NAMES: Array[String] = ["Sunny Meadow", "Bubble Bay", "Arrowland", "Sunset Dunes", "Star Galaxy",
	"Snake Jungle"]
const RANKS: Array[Array] = [[0, "Rookie"], [30, "Sharpshooter"], [90, "Bullseye Pro"], [180, "Master Archer"], [270, "Legend"]]

var _tab := -1
var _page: Control
var _tab_buttons: Array[Button] = []
var _fonts := {}                # weight -> SystemFont

# Daily tab
var _month_offset := 0          # 0 = this month, -1 = last month, ...
var _selected_day := -1         # UTC day picked in the calendar (-1 = none)
var _grid: GridContainer
var _month_label: Label
var _count_label: Label
var _month_bar: Control
var _next_month: Button
var _hero_title: Label
var _hero_sub: Label
var _hero_button: Button


func _ready() -> void:
	GameData.set_music_pitch(1.0)
	var start_tab := 1 if GameData.daily_day >= 0 else 0  # back from a daily maze
	GameData.daily_day = -1
	GameData.refresh_quiver()

	var sky := HomeSky.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sky)
	# Night scene from Affinity: moon, mountains, pine hills and fireflies over the sky.
	var scene := TextureRect.new()
	scene.texture = preload("res://icons/fx/home_backdrop.png")
	scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scene)
	_page = Control.new()
	_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_page)
	_build_tab_bar()
	show_tab(start_tab)
	_check_streak.call_deferred()
	if GameData.quit_notice != "":
		AdManager._toast.call_deferred(GameData.quit_notice)
		GameData.quit_notice = ""


func show_tab(i: int) -> void:
	if i == _tab:
		return
	_tab = i
	_style_tabs()
	for c in _page.get_children():
		c.queue_free()
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page.add_child(content)
	match i:
		0:
			_build_main(content)
		1:
			_build_daily(content)
		_:
			_build_me(content)
	content.modulate.a = 0.0
	content.create_tween().tween_property(content, "modulate:a", 1.0, 0.2)


## Room the floating tab bar takes at the bottom of every tab.
func _bottom_room() -> float:
	return BAR_H + BAR_GAP * 2.0 + GameData.safe_insets().y


# --- Floating tab bar ----------------------------------------------------------------------------

func _build_tab_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 24
	bar.offset_right = -24
	bar.offset_bottom = -(BAR_GAP + GameData.safe_insets().y)
	bar.offset_top = bar.offset_bottom - BAR_H
	var box := _round_box(Color.WHITE, 56)
	box.shadow_color = Color(0.05, 0.0, 0.2, 0.4)
	box.shadow_size = 20
	box.shadow_offset = Vector2(0, 8)
	box.set_content_margin_all(10)
	bar.add_theme_stylebox_override("panel", box)
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)
	for i in TABS.size():
		var b := _plain_button()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 10)
		b.add_child(h)
		var icon := _icon("res://icons/%s.svg" % TABS[i][1], 50)
		icon.pivot_offset = Vector2(25, 25)
		h.add_child(icon)
		h.add_child(_label(TABS[i][0], 30, Color.WHITE, 900))
		_passthrough(b)
		b.pressed.connect(func() -> void:
			if i != _tab:
				GameData.play_sfx("tap")
			show_tab(i))
		row.add_child(b)
		_tab_buttons.append(b)


## Active tab: a violet pill with icon + name. Others: just a soft icon.
func _style_tabs() -> void:
	for t in _tab_buttons.size():
		var b := _tab_buttons[t]
		var active := t == _tab
		var h := b.get_child(0)
		var icon := h.get_child(0) as TextureRect
		b.size_flags_stretch_ratio = 1.7 if active else 1.0
		var style: StyleBox = StyleBoxEmpty.new()
		if active:
			style = _round_box(VIOLET, 46)
		for s in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(s, style)
		icon.modulate = Color.WHITE if active else Color("#a09cc4")
		(h.get_child(1) as Label).visible = active
		if active:
			icon.scale = Vector2(0.6, 0.6)
			icon.create_tween().tween_property(icon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Main tab ------------------------------------------------------------------------------------

func _build_main(root: Control) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	_margin(root, 32, 24 + GameData.safe_insets().x, 32, _bottom_room() + 4).add_child(col)
	var level := _current_level()
	var world := clampi(floori((level - 1) / float(LEVELS_PER_WORLD)), 0, WORLD_NAMES.size() - 1)

	# Archie + level, then quiver and stars.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	# Top bar, Royal-Match style (design "A"): the mascot portrait stands alone with a gold
	# LEVEL ribbon under it; quiver and coins sit in dark recessed slots with their big
	# icons overlapping the slot's left end. All art is from Affinity (icons/fx/hud_*).
	top.add_theme_constant_override("separation", 16)
	# Profile: the mascot portrait, with the level and world name written beside it.
	var profile := HBoxContainer.new()
	profile.add_theme_constant_override("separation", 12)
	profile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	profile.add_child(_mascot(HUD_ROW))
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", -4)
	names.add_child(_hud_text("Level %d" % level, 28))
	var world_name := _hud_text(WORLD_NAMES[world].to_upper(), 16)
	world_name.add_theme_color_override("font_color", Color("#fde68a"))
	names.add_child(world_name)
	profile.add_child(names)
	top.add_child(profile)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)

	# Quiver: the arrow count sits in a red badge on the icon's corner, the slot shows
	# FULL or the time to the next arrow.
	var qicon := Control.new()
	var qart := _icon("res://icons/fx/hud_quiver.png", 86)
	qart.position = Vector2(-8, -8)
	qicon.add_child(qart)
	var badge := _icon("res://icons/fx/hud_badge.png", 32)
	badge.position = Vector2(44, 44)
	qicon.add_child(badge)
	var quiver_label := _hud_text("", 18)
	quiver_label.add_theme_constant_override("shadow_offset_y", 1)
	quiver_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quiver_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quiver_label.size = Vector2(32, 32)
	quiver_label.position = Vector2(44, 40)   # digits sit low in their line box, so lift it to the badge centre
	qicon.add_child(quiver_label)
	var quiver_timer := _hud_text("", 23)
	quiver_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_hud_slot(qicon, Rect2(0, 6, 70, 80), quiver_timer, 168.0))

	# Coins: a green square plus sits inside the slot's right end (opens the shop).
	var coin_label := _hud_text(_thousands(GameData.coins), 23)
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var coins := _hud_slot(_icon("res://icons/fx/hud_coin.png", 78), Rect2(-2, 5, 78, 78), coin_label, 196.0, 52.0)
	var plus := _icon("res://icons/fx/hud_plus_sq.png", 48)
	plus.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	plus.offset_left = -50
	plus.offset_right = -2
	plus.offset_top = -24
	plus.offset_bottom = 24
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coins.add_child(plus)
	coins.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_open_shop())
	top.add_child(coins)

	col.add_child(_expand())
	var target := HomeTarget.new()
	target.custom_minimum_size = Vector2(0, 470)
	target.pressed.connect(_start_level.bind(level))
	col.add_child(target)
	var num := VBoxContainer.new()
	num.set_anchors_preset(Control.PRESET_FULL_RECT)
	num.alignment = BoxContainer.ALIGNMENT_CENTER
	num.add_theme_constant_override("separation", -16)
	target.add_child(num)
	var cap := _label("LEVEL", 24, GOLD_TEXT, 900)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.add_child(cap)
	var big := _label(str(level), 84 if level < 100 else 70, GOLD_TEXT, 900)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.add_child(big)
	_passthrough(target)

	# How far through this world.
	col.add_child(_gap(4))
	var world_size := clampi(GameData.MAX_LEVELS - world * LEVELS_PER_WORLD, 1, LEVELS_PER_WORLD)  # the newest world may be shorter
	var cleared := clampi(GameData.unlocked_level - 1 - world * LEVELS_PER_WORLD, 0, world_size)
	var prog := _glass_panel(30, 26, 26, 14, 18)
	prog.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	prog.custom_minimum_size = Vector2(470, 0)
	var pvb := VBoxContainer.new()
	pvb.add_theme_constant_override("separation", 10)
	prog.add_child(pvb)
	var ph2 := HBoxContainer.new()
	pvb.add_child(ph2)
	var wl := _label("World %d · %s" % [world + 1, WORLD_NAMES[world]], 26, Color.WHITE, 800)
	wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph2.add_child(wl)
	ph2.add_child(_label("%d/%d" % [cleared, world_size], 26, GOLD, 900))
	pvb.add_child(_bar(cleared / float(world_size), GOLD, Color(1, 1, 1, 0.15), 14))
	var map_hint := _label("Tap to open the map  >", 20, LILAC, 800)
	map_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pvb.add_child(map_hint)
	col.add_child(prog)
	prog.mouse_filter = Control.MOUSE_FILTER_STOP
	prog.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			GameData.play_sfx("tap")
			get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn"))

	col.add_child(_expand())
	var play := _button_3d(GOLD, GOLD_LIP, 56, 140, false)
	_art_button(play, "home_play")
	play.text = "PLAY"
	play.add_theme_font_size_override("font_size", 66)
	for s in ["font_color", "font_hover_color", "font_focus_color"]:
		play.add_theme_color_override(s, GOLD_TEXT)
	play.add_theme_color_override("font_pressed_color", GOLD_TEXT.darkened(0.15))
	play.pressed.connect(_start_level.bind(level))
	col.add_child(play)
	play.resized.connect(func() -> void: play.pivot_offset = play.size * 0.5)
	var breathe := play.create_tween().set_loops()
	breathe.tween_property(play, "scale", Vector2(1.03, 1.03), 0.9).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(play, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)

	col.add_child(_gap(24))
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 20)
	col.add_child(tiles)
	var daily_sub := Label.new()
	tiles.add_child(_daily_tile(daily_sub))
	tiles.add_child(_streak_tile())

	var refresh := func() -> void:
		var wait := GameData.quiver_wait()
		quiver_label.text = str(GameData.quiver)
		quiver_timer.text = "FULL" if wait <= 0 else GameData.clock_text(wait)
		quiver_timer.add_theme_color_override("font_color", Color("#86efac") if wait <= 0 else Color.WHITE)
		if GameData.daily_done.has(GameData.utc_day()):
			daily_sub.text = "Next in " + _clock(_seconds_to_next_daily(), false)
	refresh.call()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(func() -> void:
		GameData.refresh_quiver()
		refresh.call())
	root.add_child(timer)


func _daily_tile(sub: Label) -> Button:
	var today := GameData.utc_day()
	var done := GameData.daily_done.has(today)
	var b := _tile_button()
	var h := _tile_row(b)
	h.add_child(_icon("res://icons/fx/home_ic_daily.png", 78))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	v.add_child(_label("Daily", 32, TEXT, 900))
	sub.text = "New maze ready!"
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_font_override("font", _font(800))
	sub.add_theme_color_override("font_color", MUTED if done else CORAL)
	v.add_child(sub)
	if not done:
		var dot := Panel.new()
		dot.add_theme_stylebox_override("panel", _round_box(CORAL, 13))
		dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		dot.offset_left = -34
		dot.offset_right = -8
		dot.offset_top = 8
		dot.offset_bottom = 34
		b.add_child(dot)
	_passthrough(b)
	b.pressed.connect(func() -> void:
		if done:
			GameData.play_sfx("tap")
			show_tab(1)
		else:
			_play_daily(today))
	return b


## Flame, streak length and seven dots for this week of the streak's reward cycle.
func _streak_tile() -> Button:
	var b := _tile_button()
	var h := _tile_row(b)
	h.add_child(_icon("res://icons/fx/home_ic_streak.png", 78))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 8)
	h.add_child(v)
	var n := GameData.streak
	v.add_child(_label("%d %s" % [n, "day" if n == 1 else "days"], 32, TEXT, 900))
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 6)
	v.add_child(dots)
	var lit := n % 7
	if n > 0 and lit == 0:
		lit = 7
	for i in 7:
		var d := Panel.new()
		d.custom_minimum_size = Vector2(16, 16)
		d.add_theme_stylebox_override("panel", _round_box(Color("#f97316") if i < lit else Color("#fde3c8"), 8))
		dots.add_child(d)
	_passthrough(b)
	b.pressed.connect(func() -> void:
		GameData.play_sfx("tap")
		show_tab(2))
	return b


func _tile_button() -> Button:
	var b := _button_3d(Color.WHITE, CARD_LIP, 32, 150, false)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _tile_row(b: Button) -> HBoxContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_bottom", 8)
	b.add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	m.add_child(h)
	return h


# --- Daily tab -----------------------------------------------------------------------------------

func _build_daily(root: Control) -> void:
	var list := _scroll_list(root, 24)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	list.add_child(head)
	head.add_child(_label("Daily Challenge", 52, Color.WHITE, 900))
	head.add_child(_label("One new maze a day, the same for everyone", 24, LILAC, 700))

	# Hero card for the picked day.
	var hero := PanelContainer.new()
	var hero_box := _round_box(Color("#5b21b6"), 38)
	hero_box.border_width_bottom = 10
	hero_box.border_color = Color("#3b0764")
	hero_box.content_margin_left = 22
	hero_box.content_margin_right = 26
	hero_box.content_margin_top = 24
	hero_box.content_margin_bottom = 26
	hero_box.shadow_color = Color(0.05, 0.0, 0.2, 0.35)
	hero_box.shadow_size = 14
	hero_box.shadow_offset = Vector2(0, 8)
	hero.add_theme_stylebox_override("panel", hero_box)
	list.add_child(hero)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 20)
	hero.add_child(hh)
	var trophy := _icon("res://icons/trophy.svg", 170)
	hh.add_child(trophy)
	trophy.pivot_offset = Vector2(85, 85)
	var pulse := trophy.create_tween().set_loops()
	pulse.tween_property(trophy, "rotation", 0.06, 1.2).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(trophy, "rotation", -0.06, 1.2).set_trans(Tween.TRANS_SINE)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_theme_constant_override("separation", 6)
	hh.add_child(hv)
	_hero_title = _label("", 42, Color.WHITE, 900)
	hv.add_child(_hero_title)
	_hero_sub = _label("", 24, LILAC, 700)
	_hero_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(_hero_sub)
	hv.add_child(_gap(8))
	_hero_button = _button_3d(GOLD, GOLD_LIP, 34, 92, true)
	_hero_button.add_theme_font_size_override("font_size", 40)
	for s in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_hero_button.add_theme_color_override(s, GOLD_TEXT)
	_hero_button.pressed.connect(_on_daily_play)
	hv.add_child(_hero_button)

	# Calendar sheet.
	var sheet := PanelContainer.new()
	var sheet_box := _round_box(Color.WHITE, 40)
	sheet_box.border_width_bottom = 10
	sheet_box.border_color = CARD_LIP
	sheet_box.content_margin_left = 22
	sheet_box.content_margin_right = 22
	sheet_box.content_margin_top = 22
	sheet_box.content_margin_bottom = 26
	sheet.add_theme_stylebox_override("panel", sheet_box)
	list.add_child(sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	sheet.add_child(v)
	var nav := HBoxContainer.new()
	v.add_child(nav)
	var prev := _nav_button("‹")
	prev.pressed.connect(_change_month.bind(-1))
	nav.add_child(prev)
	_month_label = _label("", 38, TEXT, 900)
	_month_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_month_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav.add_child(_month_label)
	_next_month = _nav_button("›")
	_next_month.pressed.connect(_change_month.bind(1))
	nav.add_child(_next_month)
	var count_row := HBoxContainer.new()
	count_row.add_theme_constant_override("separation", 12)
	v.add_child(count_row)
	count_row.add_child(_icon("res://icons/coin_star.svg", 40))
	_count_label = _label("", 26, TEXT, 800)
	count_row.add_child(_count_label)
	_month_bar = _bar(0.0, GOLD, Color("#ede9fe"), 14)
	_month_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_month_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	count_row.add_child(_month_bar)
	_grid = GridContainer.new()
	_grid.columns = 7
	_grid.add_theme_constant_override("h_separation", 0)
	_grid.add_theme_constant_override("v_separation", 4)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_grid)

	_month_offset = 0
	_selected_day = GameData.utc_day()
	_fill_month()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_update_hero)
	root.add_child(timer)


func _nav_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(68, 68)
	b.add_theme_font_override("font", _font(900))
	b.add_theme_font_size_override("font_size", 48)
	for s in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(s, VIOLET)
	b.add_theme_color_override("font_disabled_color", Color("#ddd6fe"))
	var box := _round_box(Color("#f3f0ff"), 34)
	box.content_margin_bottom = 6
	for s in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, box)
	var down := _round_box(Color("#e4dcff"), 34)
	down.content_margin_bottom = 6
	b.add_theme_stylebox_override("pressed", down)
	return b


func _change_month(step: int) -> void:
	GameData.play_sfx("tap")
	_month_offset = mini(_month_offset + step, 0)
	_selected_day = GameData.utc_day() if _month_offset == 0 else -1
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
	_next_month.disabled = _month_offset >= 0
	_month_label.text = "%s %d" % [GameData.MONTHS[month - 1], year]

	var first := floori(Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": 1, "hour": 0, "minute": 0, "second": 0}) / 86400.0)
	var weekday := int(Time.get_date_dict_from_unix_time(first * 86400).weekday)  # 0 = Sunday
	var lead := (weekday + 6) % 7  # the calendar starts on Monday
	for w in WEEKDAYS:
		var h := _label(w, 24, MUTED, 800)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(h)
	for i in lead:
		_grid.add_child(Control.new())

	var done_count := 0
	var days := 0
	var day := first
	while int(Time.get_date_dict_from_unix_time(day * 86400).month) == month:
		days += 1
		if GameData.daily_done.has(day):
			done_count += 1
		_grid.add_child(_day_cell(day, today))
		day += 1
	_count_label.text = "%d/%d days" % [done_count, days]
	var fill: Control = _month_bar.get_meta("fill")
	fill.anchor_right = done_count / float(days)
	fill.visible = done_count > 0
	_update_hero()


## One calendar day as a chunky rounded tile: picked = violet, won = gold with a star,
## today = lilac outline, past = soft lilac, future = faded number.
func _day_cell(day: int, today: int) -> Control:
	var cell := CenterContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.custom_minimum_size = Vector2(0, 82)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(72, 74)
	b.text = str(int(Time.get_date_dict_from_unix_time(day * 86400).day))
	b.add_theme_font_override("font", _font(800))
	b.add_theme_font_size_override("font_size", 30)
	cell.add_child(b)
	if day > today:
		var empty := StyleBoxEmpty.new()
		for s in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(s, empty)
		b.disabled = true
		b.add_theme_color_override("font_disabled_color", Color("#d4d2e3"))
		return cell

	var done := GameData.daily_done.has(day)
	var face := Color("#f5f3ff")
	var lip := Color("#e4e0f5")
	var ink := Color("#6b6a8a")
	if day == _selected_day:
		face = VIOLET
		lip = VIOLET_DARK
		ink = Color.WHITE
	elif done:
		face = Color("#fef3c7")
		lip = GOLD
		ink = Color("#92400e")
	elif day == today:
		face = Color("#ede9fe")
		lip = Color("#a78bfa")
		ink = Color("#5b21b6")
	var normal := _round_box(face, 22)
	if day == today and day != _selected_day:
		normal.set_border_width_all(3)
	normal.border_width_bottom = 6
	normal.border_color = lip
	if done:
		normal.content_margin_bottom = 16
	var down := normal.duplicate() as StyleBoxFlat
	down.border_width_bottom = 2
	for s in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(s, normal)
	b.add_theme_stylebox_override("pressed", down)
	for s in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(s, ink)
	if done:
		var star := _icon("res://icons/star.svg", 20)
		star.modulate = GOLD if day != _selected_day else Color.WHITE
		star.position = Vector2(26, 44)
		star.size = Vector2(20, 20)
		b.add_child(star)
	b.pressed.connect(func() -> void:
		GameData.play_sfx("tap")
		_selected_day = day
		_fill_month())
	return cell


## Hero card text and button for the picked day; the countdown ticks every second.
func _update_hero() -> void:
	if _hero_title == null or not is_instance_valid(_hero_title):
		return
	var day := _selected_day
	var today := GameData.utc_day()
	var left := _clock(_seconds_to_next_daily(), true)
	_hero_button.disabled = day < 0
	if day < 0:
		_hero_title.text = "Pick a day"
		_hero_sub.text = "Tap a day in the calendar below"
		_hero_button.text = "PLAY"
		return
	_hero_title.text = "Today" if day == today else GameData.day_label(day)
	if GameData.daily_done.has(day):
		var stars := clampi(int(GameData.daily_done[day]), 0, 3)
		_hero_sub.text = "Won  " + "★".repeat(stars) + "☆".repeat(3 - stars) + ("\nNew maze in " + left if day == today else "")
		_hero_button.text = "REPLAY"
	elif GameData.daily_available(day):
		_hero_sub.text = "Ends in " + left if day == today else "Unlocked and ready"
		_hero_button.text = "PLAY"
	else:
		_hero_sub.text = "Missed it? Watch a short video to play"
		_hero_button.text = "▶  UNLOCK"


func _on_daily_play() -> void:
	var day := _selected_day
	if day < 0:
		return
	if GameData.daily_available(day):
		_play_daily(day)
		return
	AdManager.show_rewarded("Unlock " + GameData.day_label(day), func() -> void:
		GameData.daily_unlocked[day] = true
		GameData.save_game()
		_play_daily(day))


# --- Me tab --------------------------------------------------------------------------------------

func _build_me(root: Control) -> void:
	var list := _scroll_list(root, 24)
	var stars := _total_stars()

	# Archie and the archer rank earned with stars.
	var profile := _glass_panel(40, 30, 30, 26, 28)
	list.add_child(profile)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	profile.add_child(pv)
	var mascot := _mascot(170)
	mascot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pv.add_child(mascot)
	var rank := 0
	for i in RANKS.size():
		if stars >= int(RANKS[i][0]):
			rank = i
	var name_label := _label(RANKS[rank][1], 46, Color.WHITE, 900)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(name_label)
	var cap := _label("ARCHER RANK", 22, LILAC, 900)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(cap)
	pv.add_child(_gap(8))
	var progress := "Top rank reached!"
	var fraction := 1.0
	if rank < RANKS.size() - 1:
		var low := int(RANKS[rank][0])
		var high := int(RANKS[rank + 1][0])
		fraction = (stars - low) / float(high - low)
		progress = "%d / %d ★  to %s" % [stars, high, RANKS[rank + 1][1]]
	var bar := _bar(fraction, GOLD, Color(1, 1, 1, 0.15), 16)
	bar.custom_minimum_size.x = 440
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pv.add_child(bar)
	var pl := _label(progress, 22, Color(1, 1, 1, 0.8), 800)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(pl)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	list.add_child(grid)
	grid.add_child(_stat_tile("star", GOLD, Color("#fef3c7"), str(stars), "Stars"))
	grid.add_child(_stat_tile("stat_level", Color.WHITE, Color("#ede9fe"),
		str(clampi(GameData.unlocked_level - 1, 0, GameData.MAX_LEVELS)), "Levels cleared"))
	grid.add_child(_stat_tile("flame", Color.WHITE, Color("#ffedd5"), str(GameData.streak), "Streak · best %d" % GameData.streak_best))
	grid.add_child(_stat_tile("coin", Color.WHITE, Color("#fef3c7"), str(GameData.coins), "Coins"))

	list.add_child(_section("POWERS"))
	list.add_child(_me_card([_me_row("bomb", Color("#f59e0b"), "Power Shop", "shop")]))

	list.add_child(_section("SETTINGS"))
	list.add_child(_me_card([
		_toggle_row("opt_sound", Color("#f59e0b"), "Sound", GameData.sound_on, func(on: bool) -> void:
			if on != GameData.sound_on:
				GameData.toggle_sound()),
		_toggle_row("opt_sound", Color("#8b5cf6"), "Music", GameData.music_on, func(on: bool) -> void:
			if on != GameData.music_on:
				GameData.toggle_music()),
		_toggle_row("opt_vibrate", Color("#ec4899"), "Vibration", GameData.vibration_on, func(on: bool) -> void:
			if on != GameData.vibration_on:
				GameData.toggle_vibration()),
		_me_row("opt_settings", Color("#3b82f6"), "More settings", "settings"),
	]))
	list.add_child(_section("HELP & PRIVACY"))
	list.add_child(_me_card([
		_me_row("opt_help", Color("#22c55e"), "Help", "help"),
		_me_row("opt_about", VIOLET, "About Game", "about"),
		_me_row("opt_rights", Color("#6366f1"), "Privacy Rights", "privacy_rights"),
		_me_row("opt_prefs", Color("#06b6d4"), "Privacy Preferences", "privacy_prefs"),
		_me_row("opt_policy", Color("#0ea5e9"), "Privacy Policy", "privacy_policy"),
		_me_row("opt_terms", Color("#64748b"), "Terms of Use", "terms"),
	]))
	var version := _label("Arrow Crush  v%s" % GameData.GAME_VERSION, 22, Color("#a09cc4"), 800)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(version)


func _stat_tile(icon: String, tint: Color, disc_color: Color, value: String, caption: String) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := _round_box(Color.WHITE, 30)
	box.border_width_bottom = 8
	box.border_color = CARD_LIP
	box.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	card.add_child(h)
	var disc := PanelContainer.new()
	disc.add_theme_stylebox_override("panel", _round_box(disc_color, 38))
	disc.custom_minimum_size = Vector2(76, 76)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tex := _icon("res://icons/%s.svg" % icon, 46)
	tex.modulate = tint
	tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	disc.add_child(tex)
	h.add_child(disc)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -6)
	h.add_child(v)
	v.add_child(_label(value, 42, TEXT, 900))
	v.add_child(_label(caption, 21, MUTED, 800))
	return card


func _section(text: String) -> Label:
	var l := _label("   " + text, 22, LILAC, 900)
	return l


func _me_card(rows: Array) -> Control:
	var card := PanelContainer.new()
	var box := _round_box(Color.WHITE, 30)
	box.border_width_bottom = 8
	box.border_color = CARD_LIP
	card.add_theme_stylebox_override("panel", box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	card.add_child(v)
	for i in rows.size():
		if i > 0:
			var sep := MarginContainer.new()
			sep.add_theme_constant_override("margin_left", 128)
			var line := ColorRect.new()
			line.color = Color("#efecf8")
			line.custom_minimum_size = Vector2(0, 2)
			sep.add_child(line)
			v.add_child(sep)
		v.add_child(rows[i])
	return card


## [coloured icon tile]  Title  ...  `tail` (a chevron or a switch).
func _row_parts(parent: Control, icon: String, color: Color, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 24)
	parent.add_child(h)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(4, 0)
	h.add_child(pad)
	var tile := PanelContainer.new()
	var tile_box := _round_box(color, 20)
	tile_box.border_width_bottom = 4
	tile_box.border_color = color.darkened(0.25)
	tile.add_theme_stylebox_override("panel", tile_box)
	tile.custom_minimum_size = Vector2(76, 76)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tex := _icon("res://icons/%s.svg" % icon, 46)
	tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.add_child(tex)
	h.add_child(tile)
	var label := _label(text, 34, TEXT, 800)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(label)
	return h


## A row that opens that page of the Options screen.
func _me_row(icon: String, color: Color, text: String, page: String) -> Button:
	var b := _plain_button()
	b.custom_minimum_size = Vector2(0, 112)
	var h := _row_parts(b, icon, color, text)
	var chevron := _label("›", 52, Color("#c4bfdc"), 800)
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(chevron)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(18, 0)
	h.add_child(pad)
	_passthrough(b)
	b.pressed.connect(func() -> void:
		GameData.play_sfx("tap")
		if page == "shop":
			_open_shop()
		elif page == "privacy_policy" or page == "terms":
			LegalText.open_page(page)  # these live on the website
		else:
			OptionsScreen.open(self, false, page))
	return b


func _toggle_row(icon: String, color: Color, text: String, on: bool, changed: Callable) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(0, 112)
	var h := _row_parts(row, icon, color, text)
	h.add_child(_switch(on, changed))
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(18, 0)
	h.add_child(pad)
	return row


## A violet on / off switch with a sliding knob.
func _switch(on: bool, changed: Callable) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = on
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(96, 54)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var off_box := _round_box(Color("#e4e0f5"), 27)
	var on_box := _round_box(VIOLET, 27)
	for s in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(s, off_box)
	for s in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(s, on_box)
	var knob := Panel.new()
	var knob_box := _round_box(Color.WHITE, 21)
	knob_box.shadow_color = Color(0.1, 0.0, 0.3, 0.25)
	knob_box.shadow_size = 4
	knob.add_theme_stylebox_override("panel", knob_box)
	knob.size = Vector2(42, 42)
	knob.position = Vector2(48 if on else 6, 6)
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(knob)
	b.toggled.connect(func(pressed: bool) -> void:
		changed.call(pressed)
		GameData.play_sfx("tap")
		GameData.vibrate(15)
		knob.create_tween().tween_property(knob, "position:x", 48.0 if pressed else 6.0, 0.15).set_trans(Tween.TRANS_CUBIC))
	return b


## The booster shop; the open tab is rebuilt afterwards so coins and stock are fresh.
func _open_shop() -> void:
	GameData.play_sfx("tap")
	ShopPopup.open(self).closed.connect(func() -> void:
		var t := _tab
		_tab = -1
		show_tab(t))


# --- Starting a maze -----------------------------------------------------------------------------

func _current_level() -> int:
	return clampi(GameData.unlocked_level, 1, GameData.MAX_LEVELS)


func _total_stars() -> int:
	var total := 0
	for n in GameData.stars:
		total += int(GameData.stars[n])
	return total


func _seconds_to_next_daily() -> int:
	return 86400 - int(Time.get_unix_time_from_system()) % 86400


## "5h 12m" (short) or "05:12:33".
func _clock(seconds: int, with_seconds: bool) -> String:
	var h := floori(seconds / 3600.0)
	var m := floori((seconds % 3600) / 60.0)
	if with_seconds:
		return "%02d:%02d:%02d" % [h, m, seconds % 60]
	return "%dh %02dm" % [h, m]


## Opens level `n` - unless it costs a quiver arrow and the quiver is empty.
func _start_level(n: int) -> void:
	GameData.play_sfx("tap")
	GameData.refresh_quiver()
	if GameData.level_costs_arrow(n, false) and GameData.quiver <= 0:
		QuiverPopup.show_empty(self).refilled.connect(_open_level.bind(n))
		return
	_open_level(n)


func _open_level(n: int) -> void:
	GameData.daily_day = -1
	GameData.current_level = n
	get_tree().change_scene_to_file(GAME_SCENE)


func _play_daily(day: int) -> void:
	GameData.play_sfx("tap")
	GameData.daily_day = day
	get_tree().change_scene_to_file(GAME_SCENE)


func _check_streak() -> void:
	var info := GameData.check_streak()
	if not info.is_empty():
		StreakPopup.show_broken(self, info).closed.connect(get_tree().reload_current_scene)


# --- Small builders ------------------------------------------------------------------------------

func _font(weight: int) -> SystemFont:
	if not _fonts.has(weight):
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Nunito", "Roboto", "Segoe UI", "Arial", "sans-serif"])
		f.font_weight = weight
		_fonts[weight] = f
	return _fonts[weight]


func _label(text: String, px: int, color: Color, weight: int = 700) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	if weight != 700:
		l.add_theme_font_override("font", _font(weight))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _icon(path: String, px: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(path)
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Archie in his gold portrait frame; he hops when tapped.
func _mascot(px: float) -> Mascot:
	var m := Mascot.new()
	m.custom_minimum_size = Vector2(px, px)
	m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	m.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			m.react("happy")
			GameData.play_sfx("pop"))
	return m


## One top-bar resource: a dark recessed slot (Affinity art, hud_slot.png) with a big icon
## over its left end. The icon is placed at `icon_rect` (chip coordinates, chip is
## w x HUD_ROW tall); `content` is centred in the slot space right of the icon, and
## `right_pad` keeps room for something inside the slot's right end (the plus).
func _hud_slot(icon: Control, icon_rect: Rect2, content: Control, w: float, right_pad: float = 14.0) -> Control:
	var chip := Control.new()
	chip.custom_minimum_size = Vector2(w, HUD_ROW)
	chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var slot := PanelContainer.new()
	slot.anchor_right = 1.0
	slot.offset_left = SLOT_LEFT
	slot.offset_top = (HUD_ROW - SLOT_H) / 2.0
	slot.offset_bottom = (HUD_ROW + SLOT_H) / 2.0
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxEmpty.new()
	box.content_margin_left = icon_rect.end.x - SLOT_LEFT + 4.0
	box.content_margin_right = right_pad
	slot.add_theme_stylebox_override("panel", box)
	# Three slices so the round ends keep their shape at any width. In the 400x120
	# texture the slot body is x 10..390, y 14..98 (84 px tall).
	slot.draw.connect(func() -> void:
		var s := SLOT_H / 84.0
		var y := -14.0 * s
		var th := 120.0 * s
		var sw := slot.size.x
		slot.draw_texture_rect_region(SLOT_TEX, Rect2(-10.0 * s, y, 40.0 * s, th), Rect2(0, 0, 40, 120))
		slot.draw_texture_rect_region(SLOT_TEX, Rect2(30.0 * s, y, sw - 60.0 * s, th), Rect2(40, 0, 320, 120))
		slot.draw_texture_rect_region(SLOT_TEX, Rect2(sw - 30.0 * s, y, 40.0 * s, th), Rect2(360, 0, 40, 120)))
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.add_child(content)
	chip.add_child(slot)
	icon.custom_minimum_size = icon_rect.size
	icon.size = icon_rect.size
	icon.position = icon_rect.position
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(icon)
	_passthrough(content)
	return chip


## Top-bar number: white, heavy, with a soft dark drop shadow instead of a thick outline.
func _hud_text(text: String, px: int) -> Label:
	var l := _label(text, px, Color.WHITE, 900)
	l.add_theme_color_override("font_shadow_color", Color(0.04, 0.01, 0.12, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_outline_size", 4)
	return l


## 1678 -> "1,678"
func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## A panel skinned with Affinity pill art (`top_plate` / `top_chip`); the rounded ends and
## the gold rim stay crisp, only the middle stretches.
func _gem_panel(art: String, left: float, right: float, top: float, bottom: float) -> PanelContainer:
	var p := PanelContainer.new()
	var box := StyleBoxTexture.new()
	box.texture = load("res://icons/fx/%s.png" % art)
	var half := box.texture.get_height() * 0.45
	box.texture_margin_left = half
	box.texture_margin_right = half
	box.texture_margin_top = half * 0.8
	box.texture_margin_bottom = half * 0.8
	box.content_margin_left = left
	box.content_margin_right = right
	box.content_margin_top = top
	box.content_margin_bottom = bottom
	p.add_theme_stylebox_override("panel", box)
	return p


func _glass_panel(radius: int, left: float, right: float, top: float, bottom: float) -> PanelContainer:
	var p := PanelContainer.new()
	var box := _round_box(Color(1, 1, 1, 0.1), radius)
	box.set_border_width_all(2)
	box.border_color = Color(1, 1, 1, 0.14)
	box.content_margin_left = left
	box.content_margin_right = right
	box.content_margin_top = top
	box.content_margin_bottom = bottom
	p.add_theme_stylebox_override("panel", box)
	return p


func _chip(icon_path: String, icon_tint: Color, text: String) -> PanelContainer:
	var chip := _glass_panel(30, 10, 20, 6, 6)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	chip.add_child(h)
	var icon := _icon(icon_path, 42)
	icon.modulate = icon_tint
	h.add_child(icon)
	h.add_child(_label(text, 30, Color.WHITE, 900))
	return chip


func _round_box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	return box


## A chunky button with a darker lip underneath that squashes when pressed (like the
## in-game buttons). `gloss` adds a soft shine across the top.
func _button_3d(face: Color, lip: Color, radius: int, height: float, gloss: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_override("font", _font(900))
	var normal := _round_box(face, radius)
	normal.border_width_bottom = 10
	normal.border_color = lip
	normal.shadow_color = Color(0.05, 0.0, 0.2, 0.3)
	normal.shadow_size = 12
	normal.shadow_offset = Vector2(0, 8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = face.lightened(0.06)
	var down := normal.duplicate() as StyleBoxFlat
	down.border_width_bottom = 3
	down.expand_margin_top = -7.0
	down.shadow_size = 4
	var off := normal.duplicate() as StyleBoxFlat
	off.bg_color = face.lerp(Color("#9ca3af"), 0.6)
	off.border_color = lip.lerp(Color("#6b7280"), 0.6)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("focus", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.8))
	if gloss:
		var shine := Panel.new()
		shine.add_theme_stylebox_override("panel", _round_box(Color(1, 1, 1, 0.22), maxi(radius - 10, 4)))
		shine.set_anchors_preset(Control.PRESET_TOP_WIDE)
		shine.offset_left = 18
		shine.offset_right = -18
		shine.offset_top = 8
		shine.offset_bottom = height * 0.36
		shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(shine)
	return b


## Skins a button with Affinity art (`<name>.png` + `<name>_down.png`), stretched in the
## middle only so the rounded ends keep their shape.
func _art_button(b: Button, art: String) -> void:
	var up := StyleBoxTexture.new()
	up.texture = load("res://icons/fx/%s.png" % art)
	var down := StyleBoxTexture.new()
	down.texture = load("res://icons/fx/%s_down.png" % art)
	for sb: StyleBoxTexture in [up, down]:
		sb.texture_margin_left = 80
		sb.texture_margin_right = 80
		sb.texture_margin_top = 40
		sb.texture_margin_bottom = 50
		# Centre the label on the gold face (the art's bottom 34 px are the lip and shadow).
		sb.content_margin_top = 8
		sb.content_margin_bottom = 34
	# The pressed art's face sits 10 px lower: the label sinks with it.
	down.content_margin_top = 18
	down.content_margin_bottom = 24
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, up)
	b.add_theme_stylebox_override("pressed", down)


func _plain_button() -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, empty)
	return b


## A rounded progress bar; the fill Panel is kept as meta "fill" for later updates.
func _bar(fraction: float, fill_color: Color, track_color: Color, height: float) -> Control:
	var track := Panel.new()
	track.custom_minimum_size = Vector2(0, height)
	track.add_theme_stylebox_override("panel", _round_box(track_color, int(height / 2.0)))
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := Panel.new()
	fill.add_theme_stylebox_override("panel", _round_box(fill_color, int(height / 2.0)))
	fill.anchor_bottom = 1.0
	fill.anchor_right = clampf(fraction, 0.0, 1.0)
	fill.visible = fraction > 0.0
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	track.set_meta("fill", fill)
	return track


## Scrolling column for Daily / Me, padded clear of the camera and the tab bar.
func _scroll_list(root: Control, separation: int) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root.add_child(scroll)
	# Drags on rows scroll the list, and a scroll never counts as a tap (after the rows are added).
	TouchScroll.setup(scroll)
	(func() -> void: TouchScroll.guard(scroll)).call_deferred()
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 24 + int(GameData.safe_insets().x))
	margin.add_theme_constant_override("margin_bottom", int(_bottom_room()) + 8)
	scroll.add_child(margin)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", separation)
	margin.add_child(list)
	return list


func _margin(parent: Control, left: float, top: float, right: float, bottom: float) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", int(left))
	m.add_theme_constant_override("margin_top", int(top))
	m.add_theme_constant_override("margin_right", int(right))
	m.add_theme_constant_override("margin_bottom", int(bottom))
	parent.add_child(m)
	return m


## Lets taps on a button's decoration (labels, icons, rows) reach the button itself.
func _passthrough(node: Node) -> void:
	for c in node.get_children():
		if c is Control and not c is Button:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_passthrough(c)


func _expand() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _gap(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
