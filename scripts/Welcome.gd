extends Control
## Opening splash on every launch: the game title (TitleLogo) - ARROW drops in letter by
## letter, CRUSH slams down, an arrow flies through and sticks quivering (tap to skip).
## On first launch only, the consent card follows on the same purple background:
## "Welcome!", Terms / Privacy Policy / privacy options rows and one big Accept button.

const GAME_SCENE := "res://scenes/GameScene.tscn"
const HOME_SCENE := "res://scenes/Home.tscn"
const GOLD := Color("#fcd34d")
const PINK := Color("#fb7185")
const SPLASH_SECONDS := 3.4
const LOGO_Y := 0.4  # logo centre, as a share of the screen height

var _skip := false
var _bg: Backdrop


## Purple gradient with slow light rays behind the logo and soft dots drifting up.
class Backdrop extends Control:
	const TOP := Color("#1e1b4b")
	const BOTTOM := Color("#4338ca")
	var focus := Vector2.ZERO
	var rays := 0.0  # 0..1 strength of the light rays
	var _clock := 0.0
	var _dots: Array[Vector3] = []  # x, y, radius

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 26:
			_dots.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(3.0, 9.0)))

	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()

	func _draw() -> void:
		# Vertical gradient in bands (cheap and smooth enough at this size).
		var bands := 48
		for i in bands:
			var y0 := size.y * i / bands
			draw_rect(Rect2(0, y0, size.x, size.y / bands + 1.0),
				TOP.lerp(BOTTOM, float(i) / (bands - 1)))
		if rays > 0.0:
			var reach := size.length()
			for i in 12:
				var ang := _clock * 0.12 + i * TAU / 12.0
				var poly := PackedVector2Array([focus, focus + Vector2.from_angle(ang - 0.11) * reach,
					focus + Vector2.from_angle(ang + 0.11) * reach])
				draw_colored_polygon(poly, Color(0.75, 0.7, 1.0, 0.05 * rays))
			for j in 18:
				draw_circle(focus, 300.0 - j * 15.0, Color(0.7, 0.6, 1.0, 0.012 * rays), true, -1.0, true)
		for d in _dots:
			var y := fposmod(d.y - _clock * 0.02 * (d.z / 6.0), 1.0) * size.y
			var x := d.x * size.x + sin(_clock + d.y * 10.0) * 10.0
			draw_circle(Vector2(x, y), d.z, Color(1, 1, 1, 0.07 + d.z * 0.006), true, -1.0, true)


func _ready() -> void:
	_bg = Backdrop.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	# Going straight on: keep the splash up until Home replaces it (fading it out first
	# would flash the white clear colour).
	await _splash(not GameData.terms_accepted)
	if GameData.terms_accepted:
		get_tree().change_scene_to_file(HOME_SCENE)
		return
	_build_consent()


static func _heavy() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Nunito", "Roboto", "Segoe UI", "Arial", "sans-serif"])
	font.font_weight = 900
	return font


func _splash(fade_out: bool) -> void:
	var view := get_viewport_rect().size
	var centre := Vector2(view.x / 2.0, view.y * LOGO_Y)
	_bg.focus = centre
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			_skip = true)
	add_child(layer)

	# The game title: ARROW drops in, CRUSH slams down, an arrow flies through and sticks.
	var logo := TitleLogo.new()
	logo.position = centre
	logo.scale = Vector2.ONE * 1.22
	layer.add_child(logo)

	var tagline := Label.new()
	tagline.text = "TAP  •  CRUSH  •  ESCAPE"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_override("font", _heavy())
	tagline.add_theme_font_size_override("font_size", 28)
	tagline.add_theme_color_override("font_color", Color("#c7d2fe"))
	tagline.position = Vector2(0, centre.y + 250)
	tagline.size = Vector2(view.x, 40)
	tagline.modulate.a = 0.0
	tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tagline)

	await get_tree().process_frame
	create_tween().tween_property(_bg, "rays", 1.0, 1.2)
	logo.landed.connect(func() -> void:
		_sparks(layer, logo.position + logo.arrow_tip() * logo.scale)
		var tt := create_tween()
		tt.tween_property(tagline, "modulate:a", 1.0, 0.4).set_delay(0.45)
		tt.parallel().tween_property(tagline, "position:y", tagline.position.y, 0.4).from(tagline.position.y + 20).set_delay(0.45)
		# Then the whole logo floats gently.
		var bob := create_tween().set_loops()
		bob.tween_property(logo, "position:y", centre.y - 8.0, 1.2).set_trans(Tween.TRANS_SINE)
		bob.tween_property(logo, "position:y", centre.y, 1.2).set_trans(Tween.TRANS_SINE))
	logo.play(func(strength: float) -> void: _shake(layer, strength))

	var waited := 0.0
	while waited < SPLASH_SECONDS and not _skip:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if not fade_out:
		return
	# Only the splash content fades; the purple background stays for the consent card.
	var out := create_tween()
	out.tween_property(layer, "modulate:a", 0.0, 0.3)
	out.parallel().tween_property(_bg, "rays", 0.35, 0.3)
	await out.finished
	layer.queue_free()


func _shake(node: Control, strength: float = 14.0) -> void:
	var t := create_tween()
	for i in 6:
		var amp := strength * (1.0 - i / 6.0)
		t.tween_property(node, "position", Vector2(randf_range(-amp, amp), randf_range(-amp, amp)), 0.035)
	t.tween_property(node, "position", Vector2.ZERO, 0.05)


func _sparks(parent: Control, at: Vector2) -> void:
	for big in [true, false]:
		var p := CPUParticles2D.new()
		parent.add_child(p)
		p.position = at
		p.one_shot = true
		p.explosiveness = 1.0
		p.amount = 36 if big else 60
		p.lifetime = 1.0 if big else 0.6
		p.spread = 180.0
		p.gravity = Vector2(0, 500) if big else Vector2.ZERO
		p.initial_velocity_min = 300.0 if big else 500.0
		p.initial_velocity_max = 750.0 if big else 900.0
		p.damping_min = 0.0 if big else 600.0
		p.damping_max = 0.0 if big else 900.0
		p.scale_amount_min = 7.0 if big else 3.0
		p.scale_amount_max = 14.0 if big else 6.0
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([GOLD, PINK, Color.WHITE]) if big else PackedColorArray([Color.WHITE, Color("#fde68a")])
		p.color_initial_ramp = ramp
		var fade := Gradient.new()
		fade.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
		p.color_ramp = fade
		p.finished.connect(p.queue_free)
		p.emitting = true


# --- Consent card (first launch) -------------------------------------------------------

func _build_consent() -> void:
	var font := _heavy()
	var inset := GameData.safe_insets()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	margin.add_theme_constant_override("margin_top", 50 + int(inset.x))
	margin.add_theme_constant_override("margin_bottom", 56 + int(inset.y))
	root.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	margin.add_child(col)
	col.add_child(_spacer(0, true))

	# The app icon bobbing above the card.
	var logo_box := Control.new()
	logo_box.custom_minimum_size = Vector2(0, 200)
	col.add_child(logo_box)
	var logo := TextureRect.new()
	logo.texture = load("res://icon.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size = Vector2(180, 180)
	logo.pivot_offset = logo.size / 2.0
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_box.add_child(logo)
	logo_box.resized.connect(func() -> void:
		logo.position = Vector2(logo_box.size.x / 2.0 - 90.0, 12))
	col.add_child(_spacer(26))

	# The white card.
	var card := PanelContainer.new()
	var card_box := GameSkin.box(Color.WHITE, GameSkin.CARD_LIP, 44, 12)
	card_box.content_margin_left = 34
	card_box.content_margin_right = 34
	card_box.content_margin_top = 34
	card_box.content_margin_bottom = 34
	card_box.shadow_color = Color(0.05, 0.0, 0.2, 0.45)
	card_box.shadow_size = 26
	card_box.shadow_offset = Vector2(0, 12)
	card.add_theme_stylebox_override("panel", card_box)
	col.add_child(card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 16)
	card.add_child(inner)

	var title := Label.new()
	title.text = "Welcome!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 68)
	title.add_theme_color_override("font_color", GameSkin.VIOLET_DARK)
	inner.add_child(title)

	var sub := Label.new()
	sub.text = "Before you start, please take a look at:"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 28)
	sub.add_theme_color_override("font_color", Color("#6b6a8a"))
	inner.add_child(sub)
	inner.add_child(_spacer(4))

	var rows: Array[Control] = []
	rows.append(_link_row("Terms of Use", "res://icons/opt_terms.svg", Color("#f59e0b"), "terms", font))
	rows.append(_link_row("Privacy Policy", "res://icons/opt_policy.svg", Color("#0ea5e9"), "privacy", font))
	rows.append(_link_row("Privacy Options", "res://icons/opt_prefs.svg", Color("#8b5cf6"), "options", font))
	for r in rows:
		inner.add_child(r)
	inner.add_child(_spacer(4))

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.add_theme_font_size_override("normal_font_size", 25)
	body.add_theme_color_override("default_color", Color("#64748b"))
	body.meta_underlined = false
	body.text = ("[center]By tapping Accept, you agree to our [color=#7c3aed][url=terms]Terms[/url][/color] and "
		+ "[color=#7c3aed][url=privacy]Privacy Policy[/url][/color]. They explain how we collect, use and "
		+ "process your information, the privacy rights available to you and how to exercise them. "
		+ "You can also [color=#7c3aed][url=options]see your options[/url][/color].\n"
		+ "[color=#94a3b8]Arrow Crush is made for players aged %d and up.[/color][/center]") % LegalText.MIN_AGE
	body.meta_clicked.connect(_on_link)
	inner.add_child(body)

	col.add_child(_spacer(34))
	var accept := Button.new()
	accept.text = "Accept & Play"
	accept.custom_minimum_size = Vector2(0, 116)
	accept.focus_mode = Control.FOCUS_NONE
	accept.add_theme_font_size_override("font_size", 44)
	GameSkin.button_3d(accept, Color("#22c55e"), Color("#15803d"), Color.WHITE, font)
	accept.pressed.connect(_on_accept)
	col.add_child(accept)
	col.add_child(_spacer(0, true))

	# Entrance: the logo drops in, the card rises, rows slide in one by one, the button pops.
	await get_tree().process_frame
	await get_tree().process_frame  # containers have placed everything
	logo.scale = Vector2.ZERO
	var lt := create_tween()
	lt.tween_property(logo, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lt.tween_callback(func() -> void:
		var bob := create_tween().set_loops()
		bob.tween_property(logo, "position:y", 4.0, 1.1).set_trans(Tween.TRANS_SINE)
		bob.tween_property(logo, "position:y", 12.0, 1.1).set_trans(Tween.TRANS_SINE))

	var card_y := card.position.y
	card.modulate.a = 0.0
	card.position.y = card_y + 260.0
	var ct := create_tween()
	ct.tween_interval(0.08)
	ct.tween_property(card, "modulate:a", 1.0, 0.25)
	ct.parallel().tween_property(card, "position:y", card_y, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in rows.size():
		var r := rows[i]
		var rx := r.position.x
		r.modulate.a = 0.0
		r.position.x = rx + 120.0
		var rt := create_tween()
		rt.tween_interval(0.35 + 0.08 * i)
		rt.tween_property(r, "modulate:a", 1.0, 0.2)
		rt.parallel().tween_property(r, "position:x", rx, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	accept.pivot_offset = accept.size / 2.0
	accept.scale = Vector2.ZERO
	var at := create_tween()
	at.tween_interval(0.6)
	at.tween_callback(GameData.play_sfx.bind("pop"))
	at.tween_property(accept, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	at.tween_callback(func() -> void:
		# A soft "tap me" pulse, paused while the finger is on it.
		var pulse := create_tween().set_loops()
		pulse.tween_property(accept, "scale", Vector2.ONE * 1.04, 0.6).set_trans(Tween.TRANS_SINE).set_delay(0.8)
		pulse.tween_property(accept, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
		accept.button_down.connect(func() -> void:
			pulse.pause()
			accept.scale = Vector2.ONE * 0.95)
		accept.button_up.connect(func() -> void:
			accept.scale = Vector2.ONE
			pulse.play()))


func _spacer(h: float, expand: bool = false) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


## A tappable lilac row: coloured round icon, label, chevron.
func _link_row(text: String, icon_path: String, tint: Color, meta: String, font: Font) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 96)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", GameSkin.box(Color("#f5f3ff"), Color("#ddd6fe"), 28, 6))
	b.add_theme_stylebox_override("hover", GameSkin.box(Color("#f3f0ff"), Color("#ddd6fe"), 28, 6))
	var down := GameSkin.box(Color("#ede9fe"), Color("#ddd6fe"), 28, 2)
	down.expand_margin_top = -4.0
	b.add_theme_stylebox_override("pressed", down)
	b.pressed.connect(_on_link.bind(meta))

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18
	row.offset_right = -22
	row.offset_bottom = -6
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)

	var badge := Panel.new()
	var badge_box := StyleBoxFlat.new()
	badge_box.bg_color = tint
	badge_box.set_corner_radius_all(30)
	badge_box.anti_aliasing = true
	badge.add_theme_stylebox_override("panel", badge_box)
	badge.custom_minimum_size = Vector2(60, 60)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(badge)
	var icon := TextureRect.new()
	icon.texture = load(icon_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 12
	icon.offset_top = 12
	icon.offset_right = -12
	icon.offset_bottom = -12
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(icon)

	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color("#3b2a6b"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	var chevron := Label.new()
	chevron.text = "›"
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chevron.add_theme_font_override("font", font)
	chevron.add_theme_font_size_override("font_size", 52)
	chevron.add_theme_color_override("font_color", Color("#a78bfa"))
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chevron)
	return b


func _on_link(meta: Variant) -> void:
	GameData.play_sfx("tap")
	match str(meta):
		"terms":
			LegalText.open_page("terms")
		"privacy":
			LegalText.open_page("privacy_policy")
		"options":
			OptionsScreen.open(self, false, "privacy_prefs")


func _on_accept() -> void:
	GameData.terms_accepted = true
	GameData.save_game()
	GameData.play_sfx("tap")
	get_tree().change_scene_to_file(GAME_SCENE)
