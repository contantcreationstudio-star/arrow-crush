class_name VictoryScreen
extends CanvasLayer
## Full-screen win card: a glowing violet stage with turning light rays, VICTORY! slamming
## in, the stars landing one by one with a burst, the finished picture, the rewards
## counting up and a big pulsing NEXT button. GameScene owns the game logic; this only
## shows the moment and reports which button was pressed.

signal next_pressed(at: Vector2)
signal replay_pressed(at: Vector2)
signal home_pressed

const STAR_ON := preload("res://icons/star_win.svg")   # big, glossy win star (sharp at 158 px)
const STAR_OFF := preload("res://icons/star_off.svg")
const BANNER := preload("res://icons/fx/banner_victory.png")
const SPARK := preload("res://icons/fx/confetti_star.png")
const RIBBON := preload("res://icons/fx/confetti_ribbon.png")
const GLOW := preload("res://icons/fx/crush_glow.png")
const BACK_UP := preload("res://icons/fx/btn_back.png")
const BACK_DOWN := preload("res://icons/fx/btn_back_down.png")
const CARD := preload("res://icons/fx/vic_card.png")
const SOCKET := preload("res://icons/fx/vic_socket.png")
const RIBBON_BANNER := preload("res://icons/fx/vic_ribbon.png")
const WELCOME := preload("res://scripts/Welcome.gd")
const CONFETTI_COLORS := [Color("#60a5fa"), Color("#f87171"), Color("#fbbf24"), Color("#4ade80"), Color("#c084fc")]
const GOLD := Color("#fbbf24")
const INK := Color("#2e1065")

const BG_SHADER := """
shader_type canvas_item;
uniform vec4 inner : source_color = vec4(0.49, 0.23, 0.93, 1.0);
uniform vec4 outer : source_color = vec4(0.10, 0.04, 0.30, 1.0);
uniform float aspect = 1.78;
void fragment() {
	vec2 p = UV - vec2(0.5, 0.3);
	p.y *= aspect;
	vec3 c = mix(inner.rgb, outer.rgb, smoothstep(0.0, 1.05, length(p)));
	float s = fract((UV.x + UV.y * aspect) * 8.0 - TIME * 0.07);
	c += step(0.5, s) * 0.022;
	COLOR = vec4(c, COLOR.a);
}
"""

# Star slot layout: centre x, centre y, size, tilt (middle star bigger and raised).
const STAR_SLOTS := [[95.0, 112.0, 124.0, -0.18], [240.0, 82.0, 158.0, 0.0], [385.0, 112.0, 124.0, 0.18]]

var _root: Control
var _center: CenterContainer
var _content: VBoxContainer
var _rays: Control
var _glow: TextureRect
var _star_slot: Control
var _next: Button
var _replay: Button
var _home: Button
var _font: SystemFont
var _done := false
var _logo: TitleLogo
var _card: Control
var _backdrop: Control


static func open(parent: Node, info: Dictionary) -> VictoryScreen:
	var v := VictoryScreen.new()
	v.layer = 36  # above the board / fail card, below the level curtain and popups
	parent.add_child(v)
	v._build(info)
	return v


func _build(info: Dictionary) -> void:
	var view := get_viewport().get_visible_rect().size
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Nunito", "Roboto", "Segoe UI", "Arial", "sans-serif"])
	_font.font_weight = 900

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# The same purple stage as the opening splash: gradient, slow light rays, drifting dots.
	_backdrop = WELCOME.Backdrop.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_backdrop)

	_rays = Control.new()
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.draw.connect(_draw_rays)
	_root.add_child(_rays)
	_glow = TextureRect.new()
	_glow.texture = GLOW
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.size = Vector2(560, 560)
	_glow.pivot_offset = _glow.size / 2.0
	_glow.modulate = Color(GOLD, 0.0)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_glow)

	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_center)
	_content = VBoxContainer.new()
	_content.custom_minimum_size.x = 640
	_content.add_theme_constant_override("separation", 10)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.add_child(_content)

	# 1. The title, built and animated exactly like the game's opening logo:
	#    "LEVEL 12" drops in letter by letter, "COMPLETE!" slams down, an arrow flies
	#    through and sticks quivering.
	var title := str(info.get("title", "LEVEL COMPLETE")).to_upper()
	var top_text := title.replace("COMPLETE", "").replace("!", "").strip_edges()
	if top_text == "":
		top_text = "WELL DONE"
	var banner := Control.new()  # the logo's slot in the column
	banner.custom_minimum_size = Vector2(640, 245)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(banner)
	_logo = TitleLogo.new()
	_logo.set_words(top_text, "COMPLETE!", 100, 116,
		[Color("#d9f99d"), Color("#4ade80"), Color("#16a34a")], Color("#166534"))
	_logo.scale = Vector2.ONE * 0.74
	_logo.position = Vector2(320, 132)
	banner.add_child(_logo)
	var pill: Control = null

	# 2. The card: a glossy gold-rimmed panel holding the stars, praise, picture and rewards.
	var card := PanelContainer.new()
	var card_box := StyleBoxTexture.new()
	card_box.texture = CARD
	card_box.texture_margin_left = 96
	card_box.texture_margin_right = 96
	card_box.texture_margin_top = 96
	card_box.texture_margin_bottom = 96
	card_box.content_margin_left = 44
	card_box.content_margin_right = 44
	card_box.content_margin_top = 22
	card_box.content_margin_bottom = 34
	card.add_theme_stylebox_override("panel", card_box)
	card.custom_minimum_size.x = 620
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A plain holder keeps the card's place in the column, so it can rise in from below
	# without the layout snapping it back.
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(holder)
	holder.add_child(card)
	_card = card
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 6)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inside)

	# 3. Stars, each landing in its own gold-rimmed socket.
	_star_slot = Control.new()
	_star_slot.custom_minimum_size = Vector2(480, 190)
	_star_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_star_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.add_child(_star_slot)
	var stars_on: Array[TextureRect] = []
	for s: Array in STAR_SLOTS:
		var socket := _star_rect(SOCKET, [s[0], s[1] + 4.0, float(s[2]) * 1.02, 0.0])
		_star_slot.add_child(socket)
		var off := _star_rect(STAR_OFF, [s[0], s[1], float(s[2]) * 0.72, s[3]])
		off.modulate = Color(0.75, 0.65, 1.0, 0.28)
		_star_slot.add_child(off)
		# Warm light inside the socket, lit when the star lands (below the star).
		var light := _star_rect(GLOW, [s[0], s[1] + 2.0, float(s[2]) * 1.25, 0.0])
		light.modulate = Color(1.0, 0.78, 0.25, 0.0)
		light.name = "Light"
		_star_slot.add_child(light)
		var on := _star_rect(STAR_ON, s)
		on.visible = false
		on.set_meta("socket", socket)
		on.set_meta("light", light)
		_star_slot.add_child(on)
		stars_on.append(on)

	# 4. The finished picture, like a little tilted photo.
	var drawer: Callable = info.get("picture", Callable())
	var photo: PanelContainer = null
	if drawer.is_valid():
		photo = PanelContainer.new()
		var frame := GameSkin.box(Color.WHITE, Color("#ddd6fe"), 20, 7)
		frame.set_content_margin_all(12)
		frame.content_margin_bottom = 18
		frame.shadow_color = Color(0.05, 0.0, 0.2, 0.45)
		frame.shadow_size = 14
		frame.shadow_offset = Vector2(0, 6)
		photo.add_theme_stylebox_override("panel", frame)
		photo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var pic := Control.new()
		pic.custom_minimum_size = Vector2(270, 165)
		pic.draw.connect(func() -> void: drawer.call(pic))
		var pic_name := str(info.get("picture_name", ""))
		if pic_name.is_empty():
			photo.add_child(pic)
		else:
			# Picture levels: the photo gets a caption naming what the arrows drew.
			var stack := VBoxContainer.new()
			stack.add_theme_constant_override("separation", 4)
			stack.add_child(pic)
			var caption := _label(pic_name + "!", 30, Color("#5b21b6"), TitleLogo.FONT)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stack.add_child(caption)
			photo.add_child(stack)

	# 4b. Praise on a ribbon, over the picture.
	var praise := Control.new()
	praise.custom_minimum_size = Vector2(500, 104)
	praise.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	praise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ribbon := TextureRect.new()
	ribbon.texture = RIBBON_BANNER
	ribbon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ribbon.size = Vector2(500, 125)
	ribbon.position = Vector2(0, -8)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	praise.add_child(ribbon)
	# Big cream-white word, thick wine outline and a soft drop shadow, centred on the
	# ribbon's raised band (it stamps in after the ribbon - see _play_timeline).
	var praise_text := _label(str(info.get("message", "")).to_upper(), 48, Color("#fffbeb"), TitleLogo.FONT)
	praise_text.add_theme_color_override("font_outline_color", Color("#7f1d1d"))
	praise_text.add_theme_constant_override("outline_size", 14)
	praise_text.add_theme_color_override("font_shadow_color", Color(0.3, 0.0, 0.08, 0.55))
	praise_text.add_theme_constant_override("shadow_offset_x", 0)
	praise_text.add_theme_constant_override("shadow_offset_y", 5)
	praise_text.add_theme_constant_override("shadow_outline_size", 14)
	praise_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	praise_text.position = Vector2(66, 12)
	praise_text.size = Vector2(368, 66)
	praise_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	praise_text.pivot_offset = praise_text.size / 2.0
	praise_text.name = "Word"
	praise.add_child(praise_text)
	inside.add_child(praise)
	if photo:
		inside.add_child(photo)

	# 5. The small "next level tuned to you" note.
	var note_text := str(info.get("note", ""))
	var note: Label = null
	if note_text != "":
		note = _label(note_text, 24, Color("#6d28d9"), _font)
		note.custom_minimum_size.x = 520  # wraps at the card's width (not at zero width while measuring)
		inside.add_child(note)

	# 6. Rewards.
	var rewards := HBoxContainer.new()
	rewards.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards.add_theme_constant_override("separation", 14)
	rewards.custom_minimum_size.y = 64
	inside.add_child(rewards)

	# 7. Buttons, in a plain holder so they can slide in without the layout pulling them back.
	var btn_slot := Control.new()
	btn_slot.custom_minimum_size = Vector2(640, 116 + 16 + 78 + 10)
	btn_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(btn_slot)
	_next = Button.new()
	_next.text = str(info.get("next_text", "NEXT LEVEL")).to_upper()
	_next.custom_minimum_size = Vector2(440, 116)
	_next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_next.add_theme_font_size_override("font_size", 46)
	GameSkin.button_3d(_next, Color("#22c55e"), Color("#15803d"), Color.WHITE, TitleLogo.FONT)
	_next.visible = bool(info.get("show_next", true))
	_next.pressed.connect(func() -> void: _press(func() -> void: next_pressed.emit(_next.get_global_rect().get_center())))
	_next.size = _next.custom_minimum_size
	_next.position = Vector2((640 - _next.size.x) / 2.0, 10)
	btn_slot.add_child(_next)
	_replay = Button.new()
	_replay.text = "REPLAY"
	_replay.custom_minimum_size = Vector2(260, 78)
	_replay.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_replay.add_theme_font_size_override("font_size", 32)
	# A solid violet 3D key (matches NEXT, one step quieter) instead of the faint ghost.
	GameSkin.button_3d(_replay, Color("#8b5cf6"), Color("#5b21b6"), Color.WHITE, TitleLogo.FONT)
	_replay.pressed.connect(func() -> void: _press(func() -> void: replay_pressed.emit(_replay.get_global_rect().get_center())))
	_replay.size = _replay.custom_minimum_size
	_replay.position = Vector2((640 - _replay.size.x) / 2.0, 10 + 116 + 16)
	if not _next.visible:
		_replay.position.y = 10
	btn_slot.add_child(_replay)

	# Home key, top-left (the HUD's back key is under this screen).
	_home = Button.new()
	_home.custom_minimum_size = Vector2(70, 70)
	var up := StyleBoxTexture.new()
	up.texture = BACK_UP
	var down := StyleBoxTexture.new()
	down.texture = BACK_DOWN
	for st in ["normal", "hover", "focus"]:
		_home.add_theme_stylebox_override(st, up)
	_home.add_theme_stylebox_override("pressed", down)
	_home.position = Vector2(22, 20 + GameData.safe_insets().x)
	_home.size = _home.custom_minimum_size
	_home.pressed.connect(func() -> void: _press(home_pressed.emit))
	_root.add_child(_home)

	for b: Button in [_next, _replay, _home]:
		_squish(b)

	# Everything starts hidden and comes in on the timeline.
	for c: Control in [_star_slot, praise, _next, _replay, _home]:
		c.modulate.a = 0.0
	if photo:
		photo.modulate.a = 0.0
	if note:
		note.modulate.a = 0.0
	_next.disabled = true
	_replay.disabled = true

	var fit_card := func() -> void:
		var ms := _card.get_combined_minimum_size()
		_card.size = ms
		_card.position = Vector2.ZERO
		(_card.get_parent() as Control).custom_minimum_size = ms
	fit_card.call()
	await get_tree().process_frame
	if not is_inside_tree():
		return
	fit_card.call()
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_rays.position = _star_slot.get_global_rect().get_center()
	_rays.visible = false  # the backdrop has its own rays now
	_glow.position = _rays.position - _glow.size / 2.0
	_backdrop.focus = _logo.get_global_transform().origin
	for c in _content.get_children():
		(c as Control).pivot_offset = (c as Control).size / 2.0
	_play_timeline(banner, pill, stars_on, photo, praise, note, rewards, info)


func _play_timeline(banner: Control, pill: Control, stars_on: Array[TextureRect], photo: Control,
		praise: Control, note: Control, rewards: HBoxContainer, info: Dictionary) -> void:
	# Stage fades up, rays start turning.
	_root.modulate.a = 0.0
	var fade := _root.create_tween()
	fade.tween_property(_root, "modulate:a", 1.0, 0.25)
	_rays.modulate.a = 0.0
	var spin := _rays.create_tween().set_loops()
	spin.tween_property(_rays, "rotation", TAU, 26.0).from(0.0)
	_backdrop.set("rays", 0.0)
	_backdrop.create_tween().tween_property(_backdrop, "rays", 1.0, 1.2)
	_confetti_rain()

	# The title comes in like the game's opening logo; confetti bursts when the arrow sticks.
	_logo.landed.connect(func() -> void:
		_sparks(_logo.get_global_transform() * _logo.arrow_tip(), 24)
		_confetti_burst(0.0)
		var bob := _logo.create_tween().set_loops()
		bob.tween_property(_logo, "position:y", 142.0, 1.2).set_trans(Tween.TRANS_SINE)
		bob.tween_property(_logo, "position:y", 150.0, 1.2).set_trans(Tween.TRANS_SINE))
	_at(0.1, func() -> void: _logo.play(_shake))

	# The card rises from below with a bounce while the arrow is flying in.
	var card_y := _card.position.y
	_card.position.y += 1100.0
	_at(0.95, func() -> void:
		var t := _card.create_tween()
		t.tween_property(_card, "position:y", card_y, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		GameData.play_sfx("whoosh", 0.8)
		_star_slot.create_tween().tween_property(_star_slot, "modulate:a", 1.0, 0.25))

	# Stars land one by one in their sockets.
	var first := 1.75
	var earned := clampi(int(info.get("stars", 0)), 0, 3)
	for i in earned:
		_at(first + i * 0.38, _land_star.bind(stars_on[i], i))
	var after_stars := first + earned * 0.38 + 0.1
	if earned > 0:
		_at(first, func() -> void:
			var g := _glow.create_tween()
			g.tween_property(_glow, "modulate:a", 0.55, 0.5)
			var pulse := _glow.create_tween().set_loops()
			pulse.tween_property(_glow, "scale", Vector2.ONE * 1.12, 1.1).set_trans(Tween.TRANS_SINE)
			pulse.tween_property(_glow, "scale", Vector2.ONE * 0.94, 1.1).set_trans(Tween.TRANS_SINE))

	if photo:
		photo.rotation = -0.06
		_at(after_stars, _pop_in.bind(photo, 0.4))
		after_stars += 0.2
	_at(after_stars, _pop_in.bind(praise, 0.4))
	# The praise word stamps onto the ribbon a beat later, with a little wobble.
	var word := praise.get_node("Word") as Control
	word.modulate.a = 0.0
	_at(after_stars + 0.18, func() -> void:
		word.scale = Vector2.ONE * 1.8
		word.rotation = -0.12
		var w := word.create_tween()
		w.tween_property(word, "modulate:a", 1.0, 0.08)
		w.parallel().tween_property(word, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		w.parallel().tween_property(word, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		w.tween_property(word, "scale", Vector2(1.12, 0.9), 0.06)
		w.tween_property(word, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		GameData.play_sfx("thunk", 1.4))
	if note:
		_at(after_stars + 0.15, func() -> void: note.create_tween().tween_property(note, "modulate:a", 1.0, 0.3))
	_at(after_stars + 0.2, _show_rewards.bind(rewards, info))

	# Buttons pop in where they stand, always NEXT first then REPLAY, from one tween
	# (no sliding: before, REPLAY passed under NEXT on the way up and could show first).
	var btn_at := after_stars + 0.45
	_at(btn_at, func() -> void:
		var order: Array[Button] = [_replay]
		if _next.visible:
			order.push_front(_next)
		var t := create_tween()
		for b: Button in order:
			b.pivot_offset = b.size / 2.0
			b.scale = Vector2.ONE * 0.4
			t.tween_callback(func() -> void: GameData.play_sfx("pop", 1.1 if b == _next else 1.25))
			t.tween_property(b, "modulate:a", 1.0, 0.1)
			t.parallel().tween_property(b, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_interval(0.04)
		t.tween_callback(func() -> void:
			_next.disabled = false
			_replay.disabled = false)
		_home.create_tween().tween_property(_home, "modulate:a", 1.0, 0.3))
	_at(btn_at + 0.7, _idle_next)


func _land_star(star: TextureRect, i: int) -> void:
	var tilt: float = STAR_SLOTS[i][3]
	var home := star.position
	var socket := star.get_meta("socket") as Control
	var light := star.get_meta("light") as Control
	# Flies in from above the card, spinning a full turn, big and glowing white-hot...
	star.visible = true
	star.modulate = Color(1.6, 1.6, 1.6, 0.0)
	star.scale = Vector2.ONE * 1.9
	star.rotation = tilt - TAU
	star.position = home + Vector2((i - 1) * 60.0, -320.0)
	var fly := 0.36
	var t := star.create_tween()
	t.tween_property(star, "modulate:a", 1.0, 0.12)
	t.parallel().tween_property(star, "position", home, fly).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(star, "scale", Vector2.ONE * 0.92, fly).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(star, "rotation", tilt, fly).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# ...and slams into its socket: flash, sparks, ring, the socket lights up and bounces.
	t.tween_callback(func() -> void:
		var at := star.get_global_rect().get_center()
		GameData.play_sfx("star", 1.0 + i * 0.18)
		GameData.play_sfx("thunk", 1.2)
		GameData.vibrate(25)
		_sparks(at, 18 + i * 6)
		_ring(at, star.size.x)
		_ring(at, star.size.x * 1.5)
		_shake(6.0 + i * 3.0)
		if socket:
			var sk := socket.create_tween()
			sk.tween_property(socket, "scale", Vector2.ONE * 0.86, 0.06)
			sk.tween_property(socket, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		if light:
			light.scale = Vector2.ONE * 0.5
			var lt := light.create_tween()
			lt.tween_property(light, "modulate:a", 1.0, 0.08)
			lt.parallel().tween_property(light, "scale", Vector2.ONE * 1.25, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			lt.tween_property(light, "modulate:a", 0.4, 0.5)
			lt.parallel().tween_property(light, "scale", Vector2.ONE, 0.5)
			# The socket keeps a warm, breathing glow.
			lt.tween_callback(func() -> void:
				var breathe := light.create_tween().set_loops()
				breathe.tween_property(light, "modulate:a", 0.5, 1.0 + i * 0.15).set_trans(Tween.TRANS_SINE)
				breathe.tween_property(light, "modulate:a", 0.3, 1.0 + i * 0.15).set_trans(Tween.TRANS_SINE)))
	t.tween_property(star, "scale", Vector2(1.3, 0.78), 0.06)
	t.parallel().tween_property(star, "modulate", Color.WHITE, 0.35)
	t.tween_property(star, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# Now and then a twinkle: a quick bright pop and a little wiggle.
	var tw := star.create_tween().set_loops()
	tw.tween_interval(1.8 + i * 0.5)
	tw.tween_property(star, "scale", Vector2.ONE * 1.12, 0.12)
	tw.parallel().tween_property(star, "modulate", Color(1.35, 1.35, 1.35), 0.12)
	tw.parallel().tween_property(star, "rotation", tilt + 0.12, 0.12)
	tw.tween_property(star, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(star, "modulate", Color.WHITE, 0.35)
	tw.parallel().tween_property(star, "rotation", tilt, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_rewards(row: HBoxContainer, info: Dictionary) -> void:
	var items: Array = [["res://icons/coin.svg", int(info.get("coins", 0)), Color("#fef3c7"), Color("#92400e")]]
	if int(info.get("hints", 0)) > 0:
		items.append(["res://icons/hint.svg", int(info.hints), Color("#ecfccb"), Color("#3f6212")])
	if int(info.get("power", 0)) > 0:
		items.append(["res://icons/bolt.svg", int(info.power), Color("#ede9fe"), Color("#5b21b6")])
	for i in items.size():
		var it: Array = items[i]
		var chip := PanelContainer.new()
		var box := GameSkin.box(it[2], (it[2] as Color).darkened(0.2), 32, 6)
		box.content_margin_left = 16
		box.content_margin_right = 24
		box.content_margin_top = 6
		box.content_margin_bottom = 10
		chip.add_theme_stylebox_override("panel", box)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		chip.add_child(hb)
		var icon := TextureRect.new()
		icon.texture = load(it[0])
		icon.custom_minimum_size = Vector2(42, 42)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(icon)
		var label := Label.new()
		label.text = "+0" if i == 0 else "+%d" % int(it[1])
		label.add_theme_font_override("font", TitleLogo.FONT)
		label.add_theme_font_size_override("font_size", 36)
		label.add_theme_color_override("font_color", it[3])
		hb.add_child(label)
		row.add_child(chip)
		chip.modulate.a = 0.0
		var t := chip.create_tween()
		t.tween_interval(i * 0.16)
		t.tween_callback(func() -> void:
			chip.pivot_offset = chip.size / 2.0
			chip.scale = Vector2.ONE * 0.4
			GameData.play_sfx("pop", 1.0 + i * 0.12))
		t.tween_property(chip, "modulate:a", 1.0, 0.1)
		t.parallel().tween_property(chip, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if i == 0:
			var total := int(it[1])
			t.parallel().tween_method(func(v: float) -> void: label.text = "+%d" % int(v), 0.0, float(total), 0.7)
			t.tween_callback(func() -> void:
				GameData.play_sfx("ding")
				_sparks(icon.get_global_rect().get_center(), 8))
			t.tween_property(chip, "scale", Vector2.ONE * 1.15, 0.08)
			t.tween_property(chip, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## NEXT keeps inviting a tap: a slow pulse and a light sweep across its face.
func _idle_next() -> void:
	if not _next.visible:
		return
	_next.pivot_offset = _next.size / 2.0
	var pulse := _next.create_tween().set_loops()
	pulse.tween_property(_next, "scale", Vector2.ONE * 1.06, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(_next, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var shine := Control.new()
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.position = Vector2(18, 8)
	shine.size = _next.size - Vector2(36, 24)  # inside the rounded ends and the lip
	shine.clip_contents = true
	_next.add_child(shine)
	var bar := ColorRect.new()
	bar.color = Color(1, 1, 1, 0.32)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.size = Vector2(30, _next.size.y)
	bar.rotation = 0.35
	shine.add_child(bar)
	var sweep := bar.create_tween().set_loops()
	sweep.tween_property(bar, "position", Vector2(_next.size.x + 40, -20), 0.55).from(Vector2(-80, -20)).set_trans(Tween.TRANS_SINE)
	sweep.tween_interval(1.4)


func _press(then: Callable) -> void:
	if _done:
		return
	_done = true
	GameData.play_sfx("tap")
	then.call()


# --- Effects ---------------------------------------------------------------------------------

func _at(sec: float, f: Callable) -> void:
	var t := _root.create_tween()
	t.tween_interval(sec)
	t.tween_callback(f)


func _pop_in(c: Control, time: float) -> void:
	c.pivot_offset = c.size / 2.0
	var base_rot := c.rotation
	c.scale = Vector2.ONE * 0.3
	c.rotation = base_rot - 0.15
	var t := c.create_tween()
	t.tween_property(c, "modulate:a", 1.0, 0.1)
	t.parallel().tween_property(c, "scale", Vector2.ONE, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(c, "rotation", base_rot, time + 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	GameData.play_sfx("pop", randf_range(0.9, 1.1))


func _shake(amount: float) -> void:
	var t := _center.create_tween()
	for k in 5:
		var f := amount * (1.0 - k / 5.0)
		t.tween_property(_center, "position", Vector2(randf_range(-f, f), randf_range(-f, f)), 0.035)
	t.tween_property(_center, "position", Vector2.ZERO, 0.05)


func _ring(at: Vector2, size: float) -> void:
	var ring := Control.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.position = at
	var r := [size * 0.4]
	ring.draw.connect(func() -> void: ring.draw_arc(Vector2.ZERO, r[0], 0.0, TAU, 48, Color(1, 0.93, 0.6), 7.0, true))
	_root.add_child(ring)
	var t := ring.create_tween()
	t.tween_method(func(v: float) -> void:
		r[0] = v
		ring.queue_redraw(), size * 0.4, size * 1.1, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.parallel().tween_property(ring, "modulate:a", 0.0, 0.4)
	t.tween_callback(ring.queue_free)


func _sparks(at: Vector2, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.texture = SPARK
	p.position = at
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.9
	p.spread = 180.0
	p.direction = Vector2.UP
	p.initial_velocity_min = 260.0
	p.initial_velocity_max = 520.0
	p.gravity = Vector2(0, 700)
	p.damping_min = 120.0
	p.damping_max = 260.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.5
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color("#fff7cc"), Color(GOLD, 0.0)])
	p.color_ramp = fade
	_root.add_child(p)
	p.finished.connect(p.queue_free)
	p.emitting = true


func _confetti_burst(delay: float) -> void:
	_at(delay, func() -> void:
		var view := get_viewport().get_visible_rect().size
		for k in 4:
			var side := -1.0 if k % 2 == 0 else 1.0
			var p := _confetti(CONFETTI_COLORS)
			p.texture = [RIBBON, SPARK][k / 2]
			p.position = Vector2(view.x * (0.5 + side * 0.48), view.y * 0.78)
			p.one_shot = true
			p.explosiveness = 0.9
			p.amount = 50
			p.lifetime = 2.6
			p.direction = Vector2(-side * 0.45, -1.0)
			p.spread = 22.0
			p.initial_velocity_min = 950.0
			p.initial_velocity_max = 1550.0
			p.finished.connect(p.queue_free)
			p.emitting = true)


## Gentle confetti that keeps drifting down while the card is up.
func _confetti_rain() -> void:
	var view := get_viewport().get_visible_rect().size
	var p := _confetti(CONFETTI_COLORS)
	p.texture = RIBBON
	p.position = Vector2(view.x / 2.0, -40)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(view.x / 2.0, 10)
	p.amount = 26
	p.lifetime = 5.0
	p.preprocess = 0.0
	p.direction = Vector2.DOWN
	p.spread = 15.0
	p.gravity = Vector2(0, 90)
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 160.0
	p.damping_min = 0.0
	p.damping_max = 0.0
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.55
	p.emitting = true


func _confetti(colors: Array) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.gravity = Vector2(0, 1300)
	p.damping_min = 40.0
	p.damping_max = 120.0
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = 0.45
	p.scale_amount_max = 0.8
	var ramp := Gradient.new()
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(float(i) / colors.size())
	ramp.offsets = offsets
	ramp.colors = PackedColorArray(colors)
	p.color_initial_ramp = ramp
	# Behind the card content, above the rays.
	_root.add_child(p)
	_root.move_child(p, _center.get_index())
	return p


func _draw_rays() -> void:
	var n := 14
	for i in n:
		var a := TAU * i / n
		var w := TAU / n * 0.32
		var pts := PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a - w) * 900.0, Vector2.from_angle(a + w) * 900.0])
		_rays.draw_colored_polygon(pts, Color(1, 0.95, 0.8, 0.08))
	for k in 6:
		_rays.draw_circle(Vector2.ZERO, 60.0 + k * 34.0, Color(1, 0.85, 0.4, 0.05), true, -1.0, true)


func _star_rect(tex: Texture2D, s: Array) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2.ONE * float(s[2])
	r.position = Vector2(s[0], s[1]) - r.size / 2.0
	r.pivot_offset = r.size / 2.0
	r.rotation = s[3]
	return r


func _label(text: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _squish(b: Button) -> void:
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size / 2.0
		b.create_tween().tween_property(b, "scale", Vector2.ONE * 0.92, 0.06))
	b.button_up.connect(func() -> void:
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
