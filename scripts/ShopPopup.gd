class_name ShopPopup
extends CanvasLayer
## The booster shop: spend coins on Super Drill, Mega Bomb, Cross Laser, Color Wipe and
## Hints, or watch a rewarded video for free coins. Opened from Home (coin chip / Me tab)
## or in a level when a booster runs out (`focus` highlights that booster).
## Emits `closed` when dismissed.

signal closed

const ORDER: Array[String] = ["drill", "bomb", "laser", "rainbow", "hint"]
const ICONS := {"drill": "res://icons/bolt.svg", "bomb": "res://icons/bomb.svg", "laser": "res://icons/laser.svg",
	"rainbow": "res://icons/rainbow.svg", "hint": "res://icons/hint.svg"}
const TEXT := Color("#1e1b4b")
const MUTED := Color("#6b6a8a")
const VIOLET := Color("#7c3aed")
const CORAL := Color("#e11d48")

var _font: SystemFont
var _card: PanelContainer
var _coin_chip: Control
var _coin_label: Label
var _note: Label
var _counts := {}               # kind -> Label
var _buys := {}                 # kind -> Button
var _done := false


static func open(parent: Node, focus: String = "") -> ShopPopup:
	var shop := ShopPopup.new()
	parent.add_child(shop)
	shop._build(focus)
	return shop


func _build(focus: String) -> void:
	layer = 60
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Nunito", "Roboto", "Segoe UI", "Arial", "sans-serif"])
	_font.font_weight = 900

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.07, 0.03, 0.2, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close())
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(650, 0)
	var box := GameSkin.box(Color.WHITE, Color("#c4b5fd"), 44, 12)
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 28
	box.content_margin_bottom = 30
	_card.add_theme_stylebox_override("panel", box)
	center.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_card.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title := _label("Power Shop", 50, Color("#4c1d95"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var chip := PanelContainer.new()
	var chip_box := GameSkin.box(Color("#fef3c7"), Color("#fbbf24"), 30, 4)
	chip_box.shadow_size = 0
	chip_box.content_margin_left = 10
	chip_box.content_margin_right = 20
	chip.add_theme_stylebox_override("panel", chip_box)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 6)
	chip.add_child(ch)
	ch.add_child(_icon("res://icons/fx/hud_coin.png", 50))
	_coin_label = _label("", 34, Color("#92400e"))
	ch.add_child(_coin_label)
	head.add_child(chip)
	_coin_chip = chip

	_note = _label("Win levels and pop balloons to earn coins!", 22, MUTED)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_note)

	for kind in ORDER:
		col.add_child(_row(kind, kind == focus))

	col.add_child(_gap(4))
	var watch := Button.new()
	watch.custom_minimum_size = Vector2(0, 96)
	watch.focus_mode = Control.FOCUS_NONE
	watch.add_theme_font_size_override("font_size", 32)
	GameSkin.button_3d(watch, Color("#22c55e"), Color("#15803d"), Color.WHITE, _font)
	# Free coins: a few videos a day (GameData.COIN_VIDEOS_PER_DAY), counted under the button.
	var left_label := _label("", 20, MUTED, 700)
	left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var show_left := func() -> void:
		var left := GameData.coin_videos_left()
		if left > 0:
			GameSkin.dress(watch, "Free coins", GameSkin.VIDEO_TEX, GameData.AD_COINS)
			left_label.text = "%d of %d free videos left today" % [left, GameData.COIN_VIDEOS_PER_DAY]
			watch.modulate.a = 1.0
		else:
			GameSkin.dress(watch, "Back tomorrow")
			left_label.text = "New free coin videos at midnight"
			watch.modulate.a = 0.55
	show_left.call()
	watch.pressed.connect(func() -> void:
		if GameData.coin_videos_left() <= 0:
			GameData.play_sfx("thud")
			_bump(watch)
			return
		AdManager.show_rewarded("+%d coins" % GameData.AD_COINS, func() -> void:
			GameData.count_coin_video()
			GameData.add_coins(GameData.AD_COINS)
			GameData.play_sfx("charge")
			_note.text = "+%d coins!" % GameData.AD_COINS
			_note.add_theme_color_override("font_color", Color("#15803d"))
			_bump(_coin_chip)
			show_left.call()
			_refresh()))
	col.add_child(watch)
	col.add_child(left_label)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 84)
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 32)
	GameSkin.button_3d(close, Color("#ede9fe"), Color("#c4b5fd"), VIOLET, _font)
	close.pressed.connect(_close)
	col.add_child(close)

	_refresh()
	_card.resized.connect(func() -> void: _card.pivot_offset = _card.size / 2.0)
	_card.scale = Vector2(0.7, 0.7)
	root.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(root, "modulate:a", 1.0, 0.18)
	t.parallel().tween_property(_card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## [icon] Name / what it does   x2   [coin 200]
func _row(kind: String, highlight: bool) -> Control:
	var row := PanelContainer.new()
	var box := GameSkin.box(Color("#f5f3ff"), Color("#e4e0f5"), 26, 6)
	box.shadow_size = 0
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 12
	if highlight:
		box.bg_color = Color("#fffbeb")
		box.set_border_width_all(4)
		box.border_width_bottom = 8
		box.border_color = Color("#fbbf24")
	row.add_theme_stylebox_override("panel", box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	row.add_child(h)
	var disc := PanelContainer.new()
	var disc_box := GameSkin.box(Color.WHITE, Color("#ddd6fe"), 36, 4)
	disc_box.shadow_size = 0
	disc.add_theme_stylebox_override("panel", disc_box)
	disc.custom_minimum_size = Vector2(76, 76)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tex := _icon(ICONS[kind], 50)
	tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	disc.add_child(tex)
	h.add_child(disc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	v.add_child(_label(GameData.BOOSTER_NAMES[kind], 30, TEXT))
	var info := _label(GameData.BOOSTER_INFO[kind], 20, MUTED, 700)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)
	var count := _label("", 28, VIOLET)
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(count)
	_counts[kind] = count
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(148, 78)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.focus_mode = Control.FOCUS_NONE
	buy.add_theme_font_size_override("font_size", 30)
	GameSkin.button_3d(buy, Color("#fbbf24"), Color("#b45309"), Color("#7c2d12"), _font)
	# Coin and price centred together on the gold key.
	GameSkin.dress(buy, str(GameData.PRICES[kind]), GameSkin.COIN_TEX)
	buy.pressed.connect(_buy.bind(kind, row))
	if not GameData.booster_unlocked(kind):
		GameSkin.dress(buy, "Lv %d" % int(GameData.BOOSTER_UNLOCK[kind]))
		count.text = ""
	h.add_child(buy)
	_buys[kind] = buy
	return row


func _buy(kind: String, row: Control) -> void:
	if not GameData.booster_unlocked(kind):
		GameData.play_sfx("thud")
		_note.text = "%s unlocks at level %d - keep going!" % [GameData.BOOSTER_NAMES[kind], int(GameData.BOOSTER_UNLOCK[kind])]
		_note.add_theme_color_override("font_color", MUTED)
		_bump(row)
		return
	var price := int(GameData.PRICES[kind])
	if GameData.coins < price:
		GameData.play_sfx("thud")
		GameData.vibrate(30)
		_note.text = "Not enough coins - watch a video for +%d!" % GameData.AD_COINS \
			if GameData.coin_videos_left() > 0 else "Not enough coins - win levels to earn more!"
		_note.add_theme_color_override("font_color", CORAL)
		_shake(_coin_chip)
		return
	if not GameData.buy_booster(kind):
		_note.text = "You can't carry any more of that one."
		_note.add_theme_color_override("font_color", MUTED)
		return
	GameData.play_sfx("charge")
	_note.text = "%s +1!" % GameData.BOOSTER_NAMES[kind]
	_note.add_theme_color_override("font_color", VIOLET)
	_bump(row)
	_refresh()


func _refresh() -> void:
	_coin_label.text = str(GameData.coins)
	for kind in ORDER:
		if kind != "hint" and not GameData.booster_unlocked(kind):
			(_counts[kind] as Label).text = ""
			(_buys[kind] as Button).modulate.a = 0.45
			continue
		(_counts[kind] as Label).text = "x%d" % GameData.booster_count(kind)
		(_buys[kind] as Button).modulate.a = 1.0 if GameData.coins >= int(GameData.PRICES[kind]) else 0.55


func _close() -> void:
	if _done:
		return
	_done = true
	GameData.play_sfx("tap")
	closed.emit()
	queue_free()


func _bump(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	var t := c.create_tween()
	t.tween_property(c, "scale", Vector2(1.08, 1.08), 0.08)
	t.tween_property(c, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _shake(c: Control) -> void:
	var x := c.position.x
	var t := c.create_tween()
	for dx in [-10.0, 10.0, -6.0, 6.0, 0.0]:
		t.tween_property(c, "position:x", x + dx, 0.05)


func _label(text: String, px: int, color: Color, weight: int = 900) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	if weight == 900:
		l.add_theme_font_override("font", _font)
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


func _gap(px: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, px)
	return c
