class_name QuiverPopup
extends StreakPopup
## Quiver popups, same look as the streak popups:
##   show_empty(parent) - no arrows left: live countdown to the next one,
##                        [+1 Arrow (watch video)] or [Later]. Emits `refilled` once an
##                        arrow is back (video or timer), then `closed`.
##   show_leave(parent) - quitting a level after PLAY costs an arrow: a full-width
##                        "Quit level?" band, [PLAY ON] or [QUIT -1]. Emits `confirmed`
##                        (arrow spent) on quit.

signal refilled
signal confirmed

const QUIVER := preload("res://icons/quiver.svg")

var _timer_label: Label
var _done := false
var _band: Control   # the "Quit level?" band (show_leave)


static func show_empty(parent: Node) -> QuiverPopup:
	var p := QuiverPopup.new()
	parent.add_child(p)
	p._build_empty()
	return p


static func show_leave(parent: Node) -> QuiverPopup:
	var p := QuiverPopup.new()
	parent.add_child(p)
	p._build_leave()
	return p


func _build_empty() -> void:
	_wobble(_icon(preload("res://icons/fx/fail_moves.png"), 170))
	_banner(preload("res://icons/fx/banner_out_arrows.png"))
	var info := _label("Your quiver is empty. A new arrow arrives every 30 minutes.", 26, Color("#6b6a8a"))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 480
	_timer_label = _timer_pill()
	var watch := _button("  +1 Arrow (watch video)", true, AD_ICON)
	watch.pressed.connect(func() -> void:
		AdManager.show_rewarded("+1 Arrow", func() -> void:
			GameData.add_arrows(1)
			GameData.play_sfx("charge")
			_refill()))
	var later := _button("Later", false)
	later.pressed.connect(_close)
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_tick)
	add_child(timer)
	_tick()
	_pop_in()


## "Quit level?" as a full-width band across the screen (striped edges, the quiver peeking
## over the top): a big PLAY ON, and QUIT with a red -1 badge on the quiver.
func _build_leave() -> void:
	var view := get_viewport().get_visible_rect().size
	var dim := get_child(0) as ColorRect
	dim.get_child(0).queue_free()  # not the card: the band below
	var font := TitleLogo.FONT
	var heavy := SystemFont.new()
	heavy.font_names = PackedStringArray(["Nunito", "Roboto", "Segoe UI", "Arial", "sans-serif"])
	heavy.font_weight = 800

	_band = Control.new()
	_band.size = Vector2(view.x, 600)
	_band.position = Vector2(0, view.y * 0.52 - _band.size.y / 2.0)
	_band.pivot_offset = _band.size / 2.0
	dim.add_child(_band)
	var face := Panel.new()
	var fb := StyleBoxFlat.new()
	fb.bg_color = Color("#faf7ff")
	fb.shadow_color = Color(0.05, 0.0, 0.2, 0.5)
	fb.shadow_size = 30
	face.add_theme_stylebox_override("panel", fb)
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.add_child(face)
	for top: bool in [true, false]:
		var edge := _stripe_edge(view.x)
		edge.position = Vector2(-80.0, 0.0 if top else _band.size.y - edge.size.y)
		_band.add_child(edge)
		var crawl := edge.create_tween().set_loops()
		crawl.tween_property(edge, "position:x", -80.0 + (40.0 if top else -40.0), 1.2).from(-80.0)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 70
	col.offset_bottom = -34
	_band.add_child(col)

	var title := Label.new()
	title.text = "QUIT LEVEL?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", GameSkin.VIOLET_DARK)
	title.add_theme_color_override("font_outline_color", Color.WHITE)
	title.add_theme_constant_override("outline_size", 10)
	col.add_child(title)
	var info := Label.new()
	info.text = "You will lose 1 arrow from your quiver\n(%d left) and this level's progress." % GameData.quiver
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_override("font", heavy)
	info.add_theme_font_size_override("font_size", 27)
	info.add_theme_color_override("font_color", Color("#5b4a86"))
	col.add_child(info)
	var gap := Control.new()
	gap.custom_minimum_size.y = 10
	col.add_child(gap)

	var stay := Button.new()
	stay.text = "PLAY ON"
	stay.custom_minimum_size = Vector2(460, 110)
	stay.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stay.focus_mode = Control.FOCUS_NONE
	stay.add_theme_font_size_override("font_size", 48)
	GameSkin.button_3d(stay, Color("#22c55e"), Color("#15803d"), Color.WHITE, font)
	col.add_child(stay)
	stay.pressed.connect(func() -> void:
		GameData.play_sfx("tap")
		_close())

	# QUIT with the quiver badge hanging off its left end.
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(460, 104)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(slot)
	var quit := Button.new()
	quit.text = "   QUIT"
	quit.size = Vector2(360, 86)
	quit.position = Vector2(80, 10)
	quit.focus_mode = Control.FOCUS_NONE
	quit.add_theme_font_size_override("font_size", 40)
	GameSkin.button_3d(quit, Color("#d8b4fe"), Color("#8b5cf6"), Color.WHITE, font)
	quit.add_theme_color_override("font_outline_color", Color("#6d28d9"))
	quit.add_theme_constant_override("outline_size", 8)
	slot.add_child(quit)
	var badge := Control.new()
	badge.size = Vector2(118, 118)
	badge.position = Vector2(14, -6)
	badge.pivot_offset = badge.size / 2.0
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.draw.connect(func() -> void:
		var m := badge.size / 2.0
		badge.draw_circle(m + Vector2(0, 6), 56.0, Color(0.2, 0.0, 0.3, 0.3), true, -1.0, true)
		badge.draw_circle(m, 56.0, Color.WHITE, true, -1.0, true)
		badge.draw_circle(m, 49.0, Color("#be123c"), true, -1.0, true)
		badge.draw_circle(m - Vector2(0, 3), 46.0, Color("#f43f5e"), true, -1.0, true)
		badge.draw_arc(m, 38.0, PI * 1.1, PI * 1.55, 16, Color(1, 1, 1, 0.55), 6.0, true))
	slot.add_child(badge)
	var mini := TextureRect.new()
	mini.texture = preload("res://icons/fx/hud_quiver.png")
	mini.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mini.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mini.size = Vector2(66, 66)
	mini.position = Vector2(10, 12)
	mini.rotation = -0.2
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(mini)
	var minus := Label.new()
	minus.text = "-1"
	minus.add_theme_font_override("font", font)
	minus.add_theme_font_size_override("font_size", 40)
	minus.add_theme_color_override("font_color", Color.WHITE)
	minus.add_theme_color_override("font_outline_color", Color("#881337"))
	minus.add_theme_constant_override("outline_size", 9)
	minus.position = Vector2(52, 48)
	badge.add_child(minus)
	quit.pressed.connect(func() -> void:
		if _done:
			return
		GameData.spend_arrow()
		GameData.play_sfx("thud")
		GameData.vibrate(40)
		# The -1 leaves the badge and floats away before the band folds up.
		var fly := minus.duplicate() as Label
		_band.add_child(fly)
		fly.position = slot.position + col.position + badge.position + minus.position
		var f := fly.create_tween()
		f.tween_property(fly, "position:y", fly.position.y - 120.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		f.parallel().tween_property(fly, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
		var shake := badge.create_tween()
		for r: float in [0.25, -0.25, 0.15, 0.0]:
			shake.tween_property(badge, "rotation", r, 0.06)
		shake.tween_callback(func() -> void:
			confirmed.emit()
			_close()))

	# The quiver peeks over the band's top edge and rattles now and then.
	var quiver := TextureRect.new()
	quiver.texture = preload("res://icons/fx/hud_quiver.png")
	quiver.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	quiver.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	quiver.size = Vector2(170, 170)
	quiver.position = Vector2((view.x - 170.0) / 2.0, -92.0)
	quiver.pivot_offset = Vector2(85, 150)
	quiver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.add_child(quiver)
	_wobble(quiver)

	# The band opens from its centre line, then the parts pop in one by one.
	_band.scale = Vector2(1.0, 0.0)
	_band.create_tween().tween_property(_band, "scale:y", 1.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	dim.modulate.a = 0.0
	dim.create_tween().tween_property(dim, "modulate:a", 1.0, 0.18)
	var parts: Array[Control] = [quiver, title, info, stay, slot]
	for i in parts.size():
		var c := parts[i]
		c.modulate.a = 0.0
		var pt := c.create_tween()
		pt.tween_interval(0.18 + i * 0.07)
		pt.tween_callback(func() -> void:
			if c != quiver:
				c.pivot_offset = c.size / 2.0
			c.scale = Vector2.ONE * 0.5)
		pt.tween_property(c, "modulate:a", 1.0, 0.1)
		pt.parallel().tween_property(c, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var pulse := stay.create_tween().set_loops()
	pulse.tween_interval(0.9)
	pulse.tween_callback(func() -> void: stay.pivot_offset = stay.size / 2.0)
	pulse.tween_property(stay, "scale", Vector2.ONE * 1.05, 0.45).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(stay, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)


## A strip of diagonal violet / lilac stripes for the band's edges (wider than the screen
## so it can crawl sideways).
func _stripe_edge(width: float) -> Control:
	var e := Control.new()
	e.size = Vector2(width + 160.0, 26)
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	e.draw.connect(func() -> void:
		var h := e.size.y
		e.draw_rect(Rect2(Vector2.ZERO, e.size), Color("#ddd6fe"))
		var x := -h
		while x < e.size.x:
			e.draw_colored_polygon(PackedVector2Array([Vector2(x, h), Vector2(x + 20, h), Vector2(x + 20 + h, 0),
				Vector2(x + h, 0)]), Color("#a78bfa"))
			x += 40.0
		e.draw_rect(Rect2(Vector2.ZERO, Vector2(e.size.x, 3)), Color(1, 1, 1, 0.5)))
	return e


func _tick() -> void:
	var wait := GameData.quiver_wait()
	if GameData.quiver > 0:
		_refill()
		return
	_timer_label.text = "Next arrow in  " + GameData.clock_text(wait)


## The countdown in a gold pill with the stopwatch icon. Returns its label.
func _timer_pill() -> Label:
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := GameSkin.box(Color("#fef3c7"), Color("#fcd34d"), 30, 5)
	box.shadow_size = 0
	box.content_margin_left = 18
	box.content_margin_right = 24
	box.content_margin_top = 6
	box.content_margin_bottom = 10
	pill.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	pill.add_child(row)
	var watch := TextureRect.new()
	watch.texture = preload("res://icons/fx/ic_timer.png")
	watch.custom_minimum_size = Vector2(40, 40)
	watch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	watch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(watch)
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Color("#92400e"))
	var heavy := SystemFont.new()
	heavy.font_names = PackedStringArray(["Nunito", "Roboto", "Segoe UI", "Arial", "sans-serif"])
	heavy.font_weight = 900
	l.add_theme_font_override("font", heavy)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	_col.add_child(pill)
	return l


## The art pops in and gives a little shake (an empty quiver rattles).
func _wobble(art: TextureRect) -> void:
	art.resized.connect(func() -> void: art.pivot_offset = art.size / 2.0)
	var t := art.create_tween().set_loops()
	t.tween_interval(1.4)
	t.tween_property(art, "rotation", 0.08, 0.07)
	t.tween_property(art, "rotation", -0.08, 0.1)
	t.tween_property(art, "rotation", 0.0, 0.08)


func _refill() -> void:
	if _done:
		return
	refilled.emit()
	_close()


func _close() -> void:
	if _done:
		return
	_done = true
	if _band == null:
		super._close()
		return
	# The band folds back into its centre line.
	var t := _band.create_tween()
	t.tween_property(_band, "scale:y", 0.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(get_child(0), "modulate:a", 0.0, 0.22)
	t.tween_callback(func() -> void:
		closed.emit()
		queue_free())
