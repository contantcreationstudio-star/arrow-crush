class_name StreakPopup
extends CanvasLayer
## Daily streak popups, built in code:
##   show_reward(info) - first win of the day: "Day 5" + 7-day track + reward,
##                       [Collect] or [Double it] (rewarded video).
##   show_broken(info) - the streak broke: [Save streak] (rewarded video) or let it go.

signal closed

const FLAME := preload("res://icons/flame.svg")
const GIFT := preload("res://icons/gift.svg")
const AD_ICON := preload("res://icons/play_ad.svg")

var _panel: PanelContainer
var _col: VBoxContainer


static func show_reward(parent: Node, info: Dictionary) -> StreakPopup:
	var p := StreakPopup.new()
	parent.add_child(p)
	p._build_reward(info)
	return p


static func show_broken(parent: Node, info: Dictionary) -> StreakPopup:
	var p := StreakPopup.new()
	parent.add_child(p)
	p._build_broken(info)
	return p


func _init() -> void:
	layer = 45
	var dim := ColorRect.new()
	dim.color = Color(0.07, 0.03, 0.2, 0.68)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(580, 0)
	# UI kit v2 card: white face, lilac 3D lip, soft violet shadow.
	var box := GameSkin.box(Color.WHITE, GameSkin.CARD_LIP, 46, 12)
	box.content_margin_left = 40
	box.content_margin_right = 40
	box.content_margin_top = 30
	box.content_margin_bottom = 38
	box.shadow_color = Color(0.05, 0.0, 0.2, 0.5)
	box.shadow_size = 26
	box.shadow_offset = Vector2(0, 10)
	_panel.add_theme_stylebox_override("panel", box)
	center.add_child(_panel)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 20)
	_panel.add_child(_col)


func _build_reward(info: Dictionary) -> void:
	var day: int = info.cycle_day
	_icon(FLAME, 120)
	_label("Day %d!" % info.streak, 56, Color("#ea580c"))
	_label("%d-day streak - keep it going tomorrow!" % info.streak, 26, Color("#64748b"))
	_week_track(day)
	_label("Today's reward: " + _reward_text(info.reward), 30, Color("#1e293b"))
	var double := _button("  Double it (watch video)", true, AD_ICON)
	double.pressed.connect(func() -> void:
		AdManager.show_rewarded("Double reward", func() -> void:
			GameData.give_reward(info.reward, 2)
			GameData.play_sfx("charge")
			_close()))
	var collect := _button("Collect", false)
	collect.pressed.connect(func() -> void:
		GameData.give_reward(info.reward)
		GameData.play_sfx("star")
		_close())
	_pop_in()


func _build_broken(info: Dictionary) -> void:
	_icon(FLAME, 110).modulate = Color(0.6, 0.65, 0.72)
	_label("Streak broken!", 52, Color("#1e3a8a"))
	if info.can_save:
		_label("You missed a day. Watch a short video to keep your %d-day streak." % info.lost, 28, Color("#64748b"))
		var save := _button("  Save my streak", true, AD_ICON)
		save.pressed.connect(func() -> void:
			AdManager.show_rewarded("Streak saved", func() -> void:
				GameData.save_streak()
				GameData.play_sfx("charge")
				_close()))
		var lose := _button("Start over", false)
		lose.pressed.connect(func() -> void:
			GameData.break_streak()
			_close())
	else:
		_label("Your %d-day streak ended. Win a level today to start a new one!" % info.lost, 28, Color("#64748b"))
		GameData.break_streak()
		var ok := _button("OK", true)
		ok.pressed.connect(_close)
	_pop_in()


# --- Parts ----------------------------------------------------------------------------------

## Seven little day badges: done ones filled, today's with a ring, day 7 a gift.
func _week_track(today: int) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for i in range(1, 8):
		var badge := PanelContainer.new()
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(34)
		box.bg_color = Color("#f97316") if i <= today else Color("#e2e8f0")
		if i == today:
			box.border_color = Color("#fde047")
			box.set_border_width_all(4)
		badge.add_theme_stylebox_override("panel", box)
		badge.custom_minimum_size = Vector2(64, 64)
		if i == 7:
			var gift := TextureRect.new()
			gift.texture = GIFT
			gift.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			gift.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			badge.add_child(gift)
		else:
			var l := Label.new()
			l.text = str(i)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.add_theme_color_override("font_color", Color.WHITE if i <= today else Color("#94a3b8"))
			badge.add_child(l)
		row.add_child(badge)
	_col.add_child(row)


func _reward_text(reward: Dictionary) -> String:
	var parts: Array[String] = []
	if reward.get("hints", 0) > 0:
		parts.append("+%d Hint" % reward.hints + ("s" if reward.hints > 1 else ""))
	if reward.get("power", 0) > 0:
		parts.append("+%d Power" % reward.power)
	return ", ".join(parts)


func _icon(tex: Texture2D, size: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_col.add_child(r)
	return r


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(500, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_col.add_child(l)
	return l


func _button(text: String, primary: bool, icon: Texture2D = null) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = icon
	b.custom_minimum_size = Vector2(0, 96 if primary else 84)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 32)
	if icon:
		b.add_theme_constant_override("icon_max_width", 40)
	var heavy := SystemFont.new()
	heavy.font_names = PackedStringArray(["Nunito", "Roboto", "Segoe UI", "Arial", "sans-serif"])
	heavy.font_weight = 900
	# Chunky 3D buttons from the UI kit: green for the main action, lilac for the other.
	if primary:
		GameSkin.button_3d(b, Color("#22c55e"), Color("#15803d"), Color.WHITE, heavy)
	else:
		GameSkin.button_3d(b, Color("#ede9fe"), GameSkin.CARD_LIP, GameSkin.VIOLET, heavy)
	if icon:
		# Video icon and text as one centred group (the icon tells it's a video).
		GameSkin.dress(b, text.replace("(watch video)", "").strip_edges(), icon)
	_col.add_child(b)
	return b


## A banner title drawn in Affinity (OUT OF ARROWS! / LEAVE LEVEL? ...).
func _banner(tex: Texture2D, height: float = 96.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(0, height)
	_col.add_child(r)
	return r


func _pop_in() -> void:
	_panel.pivot_offset = _panel.size / 2
	_panel.resized.connect(func() -> void: _panel.pivot_offset = _panel.size / 2)
	_panel.scale = Vector2.ONE * 0.75
	create_tween().tween_property(_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close() -> void:
	closed.emit()
	queue_free()
