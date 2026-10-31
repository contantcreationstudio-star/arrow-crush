class_name OptionsScreen
extends CanvasLayer
## Full-screen Options page (opened from the gear or the Welcome screen):
##   Settings | How to Play, About Game, Contact Us |
##   Privacy Policy, Terms of Use, Privacy Rights, Privacy Preferences
## Privacy Policy and Terms of Use open on the Anant Originals website (LegalText.gd), the
## master copy for all our games. Privacy Rights and Privacy Preferences stay in-game because
## they hold the controls (delete data, personalised ads) and link to the website for details.
## Each row opens a sub-page inside the same screen. Built in code so it needs no
## scene file. The game is ad-supported, so there is deliberately no "Remove Ads".

signal closed
signal restart_requested

const BG := Color("#e9edf2")
const TEXT := Color("#0f172a")
const MUTED := Color("#64748b")
const LINK := Color("#2563eb")

var show_restart := false   # adds "Restart Level" to Settings when opened in a level

var _title: Label
var _back: Button
var _content: VBoxContainer
var _scroll: ScrollContainer
var _page := ""
var _history: Array[String] = []  # pages Back returns to; empty = Back closes the screen


## Opens the options over `parent`. `page` can jump straight to a sub-page.
static func open(parent: Node, with_restart: bool = false, page: String = "main") -> OptionsScreen:
	var screen := OptionsScreen.new()
	screen.show_restart = with_restart
	parent.add_child(screen)
	screen.show_page(page)
	return screen


func _init() -> void:
	layer = 50
	var root := Panel.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = BG
	root.add_theme_stylebox_override("panel", bg)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 40 + int(GameData.safe_insets().x))
	margin.add_theme_constant_override("margin_bottom", 28 + int(GameData.safe_insets().y))
	root.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 28)
	margin.add_child(col)

	# Top bar: [Back]   Title   [Done]
	var bar := HBoxContainer.new()
	col.add_child(bar)
	_back = _flat_button("‹ Back", LINK)
	_back.custom_minimum_size = Vector2(150, 70)
	_back.pressed.connect(_go_back)
	bar.add_child(_back)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 40)
	_title.add_theme_color_override("font_color", TEXT)
	bar.add_child(_title)
	var done := _flat_button("Done", LINK)
	done.custom_minimum_size = Vector2(150, 70)
	done.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	done.pressed.connect(close)
	bar.add_child(done)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 30)
	_scroll.add_child(_content)
	TouchScroll.setup(_scroll)  # drags on rows / text scroll; a scroll is never a tap


func close() -> void:
	GameData.play_sfx("tap")
	closed.emit()
	queue_free()


## Back: the page this one was opened from, or close when it was opened directly
## (e.g. "Help" from the Me tab).
func _go_back() -> void:
	if _history.is_empty():
		close()
	else:
		show_page(_history.pop_back(), false)


func show_page(page: String, remember: bool = true) -> void:
	if remember and _page != "" and page != _page:
		_history.append(_page)
	_page = page
	for c in _content.get_children():
		c.queue_free()
	_back.visible = page != "main" or not _history.is_empty()
	_scroll.scroll_vertical = 0
	match page:
		"settings":
			_page_settings()
		"help":
			_page_help()
		"about":
			_page_about()
		"licenses":
			_page_licenses()
		"privacy_rights":
			_page_privacy_rights()
		"privacy_prefs":
			_page_privacy_prefs()
		_:
			_page_main()
	_guard_scroll.call_deferred()


func _guard_scroll() -> void:
	TouchScroll.guard(_scroll)


# --- Pages ---------------------------------------------------------------------------------------

func _page_main() -> void:
	_title.text = "Options"
	_card([_row("opt_settings", Color("#3b82f6"), "Settings", show_page.bind("settings"))])
	_card([
		_row("opt_help", Color("#22c55e"), "How to Play", show_page.bind("help")),
		_row("opt_about", Color("#3b82f6"), "About Game", show_page.bind("about")),
		_row("opt_mail", Color("#f59e0b"), "Contact Us", _contact),
	])
	_section("PRIVACY & LEGAL")
	_card([
		_row("opt_policy", Color("#0ea5e9"), "Privacy Policy", LegalText.open_page.bind("privacy_policy")),
		_row("opt_terms", Color("#64748b"), "Terms of Use", LegalText.open_page.bind("terms")),
		_row("opt_rights", Color("#6366f1"), "Privacy Rights", show_page.bind("privacy_rights")),
		_row("opt_prefs", Color("#06b6d4"), "Privacy Preferences", show_page.bind("privacy_prefs")),
	])


func _page_settings() -> void:
	_title.text = "Settings"
	_card([
		_toggle_row("Sound", GameData.sound_on, func(on: bool) -> void:
			if on != GameData.sound_on:
				GameData.toggle_sound()
			GameData.play_sfx("tap")),
		_toggle_row("Music", GameData.music_on, func(on: bool) -> void:
			if on != GameData.music_on:
				GameData.toggle_music()),
		_toggle_row("Vibration", GameData.vibration_on, func(on: bool) -> void:
			if on != GameData.vibration_on:
				GameData.toggle_vibration()
			GameData.vibrate(30)),
	])
	if show_restart:
		_card([_row("", Color("#f59e0b"), "Restart Level", func() -> void:
			restart_requested.emit()
			close())])


## Rules, helpers and rewards, one card per topic.
func _page_help() -> void:
	_title.text = "How to Play"
	_text_card("[b]The goal: CRUSH![/b]\nCrush at least the number of arrows shown by the burst in the goal card. Once every goal is done, flying fish carry off the arrows that are left. Tap an arrow and it flies off the way it points. If the first arrow in its way has the [b]same colour[/b], both get [b]crushed[/b]. Balloons, targets and other pieces in the goal card must be done too.\n\nFlying out is fine for making room, but only crushes add to the crush count.")
	_text_card("[b]Crush chains[/b]\nA [b]different colour[/b] in the way means a bump and you lose a heart.\n\nA crushed arrow passes the hit on to the next same-colour arrow in its path - line them up for big domino chains! And when arrows slide into a gap, a same colour just ahead gets pulled in and crushed too ([b]MAGNET![/b]).")
	_text_card("[b]Special arrows[/b]\nClear several arrows with one tap to earn a special arrow:\n"
		+ "• 3 arrows - [b]Drill[/b]: smashes through its whole path\n"
		+ "• 4 arrows - [b]Bomb[/b]: blows up a 3×3 area\n"
		+ "• 5 arrows - [b]Laser[/b]: clears its row and column\n"
		+ "• 7 arrows - [b]Rainbow[/b]: clears every arrow of one colour\n\n"
		+ "Fly a special arrow into another one for a mega combo. Two Rainbows wipe the whole board!")
	_text_card("[b]Hearts & stars[/b]\nYou have 3 hearts per level. The hearts you still have at the end are your stars (up to 3). Out of hearts? Watch a short video for one more heart, or try the level again.")
	_text_card("[b]Helpers[/b]\n"
		+ "• [b]Hint[/b] - watch a short video for 1 hint. Shows a safe arrow and its lane.\n"
		+ "• [b]Undo[/b] - 2 per level. Takes back your last tap.\n"
		+ "• [b]Power[/b] - tap Power, then any arrow: it smashes straight through. Earn one with 15 correct taps in a row (once per level), from daily rewards, or by watching a short video (you can hold up to 5).\n\n"
		+ "Run out? Watch a short video to get more.")
	_text_card("[b]Daily Challenge & streak[/b]\nA new maze every day - the same one for every player. Win at least one level a day to grow your streak and collect free hints and power. Missed a day? A video can save your streak.")
	_text_card("[b]Tips[/b]\n"
		+ "• Pinch to zoom on big boards, double-tap to fit\n"
		+ "• Look for the arrow at the end of a chain first\n"
		+ "• Levels marked HARD or SUPER HARD feel the best when you crack them!")
	_card([_row("opt_mail", Color("#f59e0b"), "Still stuck? Contact us", _contact)])


func _page_about() -> void:
	_title.text = "About Game"
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var logo := TextureRect.new()
	logo.texture = load("res://icon.png")
	logo.custom_minimum_size = Vector2(200, 200)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.add_child(logo)
	head.add_child(_center_label("Arrow Crush", 50, TEXT))
	head.add_child(_center_label("Version %s" % GameData.GAME_VERSION, 28, MUTED))
	head.add_child(_center_label("by %s" % LegalText.DEVELOPER, 28, MUTED))
	_content.add_child(head)
	_text_card("Plan your taps, crush same-colour arrows and set off huge chain reactions. Arrow Crush is a calm-but-crunchy puzzle that starts easy and grows into real brain-burners.")
	_text_card("[b]What's inside[/b]\n"
		+ "• 500 levels across 25 worlds, with wavy snake arrows and prism chains\n"
		+ "• Drill, Bomb, Laser and Rainbow special arrows\n"
		+ "• A new Daily Challenge every day, with streak rewards\n"
		+ "• Difficulty that adapts to how you play\n"
		+ "• Plays offline - your progress stays on your phone")
	_text_card("[b]Free to play[/b]\nArrow Crush is free and supported by ads. Watching a video is always your choice and gives you a bonus like a hint, power or an extra heart.\n\nMade for players aged %d and up." % LegalText.MIN_AGE)
	_card([
		_row("opt_mail", Color("#f59e0b"), "Contact Us", _contact),
		_row("opt_about", Color("#7c3aed"), LegalText.DEVELOPER, LegalText.open_page.bind("game")),
		_row("opt_policy", Color("#0ea5e9"), "Privacy & Legal", LegalText.open_page.bind("legal")),
		_row("opt_code", Color("#475569"), "Open-source licences", show_page.bind("licenses")),
	])
	_content.add_child(_center_label("Made with the Godot Engine", 24, MUTED))
	_content.add_child(_center_label("© 2026 %s" % LegalText.DEVELOPER, 24, MUTED))


## Everything third-party that ships in the game, with the notice its licence asks for.
## Kept in-game (works offline) so the notices always travel with the game, as the Godot
## licence asks. The website has the same list, linked at the top.
func _page_licenses() -> void:
	_title.text = "Licences"
	_card([_row("opt_code", Color("#475569"), "View on our website", LegalText.open_page.bind("licenses"))])
	_text_card("[b]Godot Engine[/b]\nThis game uses the Godot Engine, available under the following licence:\n\n"
		+ _escape(Engine.get_license_text()))
	_text_card("[b]Luckiest Guy font[/b]\nCopyright (c) 2010 by Brian J. Bonislawsky DBA Astigmatic (AOETI). "
		+ "Used under the Apache License 2.0:\n\n" + _licence_file("res://theme/fonts/LuckiestGuy-LICENSE.txt"))
	_text_card("[b]Music and sounds[/b]\nThe background music and the tap / arrow sounds were made for "
		+ "Arrow Crush by its developer with licensed AI audio tools (commercial-use subscription).")
	_text_card("[b]Sound effects[/b]\nImpact Sounds and Interface Sounds by Kenney (www.kenney.nl), "
		+ "released under Creative Commons Zero (CC0 1.0) - public domain. Thank you, Kenney!")
	_text_card("[b]Picture shapes[/b]\nThe level pictures (animals, flowers, home things...) are "
		+ "silhouettes made from these icon sets:\n"
		+ "• Material Design Icons (Pictogrammers) - Apache License 2.0\n"
		+ "• Material Symbols (Google) - Apache License 2.0\n"
		+ "• Phosphor Icons (Phosphor Icons) - MIT License\n"
		+ "• Font Awesome Free (Fonticons, Inc.) - CC BY 4.0, https://fontawesome.com/license/free\n"
		+ "• IconPark (ByteDance) - Apache License 2.0\n"
		+ "• Fluent Emoji (Microsoft) - MIT License\n"
		+ "The shapes were simplified to solid outlines for the game.")
	_text_card("[b]AdMob plugin[/b]\nGodot AdMob plugin by Poing Studios, used under the MIT License:\n\n"
		+ _licence_file("res://addons/admob/LICENSE")
		+ "\n\nAds are served by the Google Mobile Ads SDK, under Google's own terms.")
	# Libraries built into the Godot Engine (FreeType and others): who made them, which licence.
	var parts := PackedStringArray()
	for info: Dictionary in Engine.get_copyright_info():
		if info.name == "Godot Engine":
			continue
		var lines := PackedStringArray()
		for part: Dictionary in info.parts:
			lines.append("%s - %s" % [", ".join(part.copyright), part.license])
		parts.append("[b]%s[/b]\n%s" % [_escape(info.name), _escape("\n".join(lines))])
	_text_card("[b]Components inside the Godot Engine[/b]\n\n" + "\n\n".join(parts))
	# The full texts are long (slow to lay out on a phone), so they load on request.
	var more := Button.new()
	more.text = "Show full licence texts"
	more.custom_minimum_size = Vector2(0, 88)
	more.focus_mode = Control.FOCUS_NONE
	_content.add_child(more)
	more.pressed.connect(func() -> void:
		more.queue_free()
		var full := PackedStringArray()
		var texts: Dictionary = Engine.get_license_info()
		for licence: String in texts:
			full.append("[b]%s[/b]\n%s" % [_escape(licence), _escape(str(texts[licence]))])
		_text_card("[b]Licence texts[/b]\n\n" + "\n\n".join(full))
		_guard_scroll.call_deferred())


func _licence_file(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return "https://www.apache.org/licenses/LICENSE-2.0"
	return _escape(text.strip_edges())


## Plain text inside BBCode: "[" would start a tag, so it is written as [lb].
func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


func _page_privacy_rights() -> void:
	_title.text = "Privacy Rights"
	_text_card("[b]Your data, your choice[/b]\nYour progress, stars and settings are saved only on this phone. We have no accounts or servers, so we never receive them.\n\n"
		+ "Read all your rights and how to use them on the %s website." % LegalText.DEVELOPER)
	_card([
		_row("opt_rights", Color("#6366f1"), "Read your privacy rights", LegalText.open_page.bind("privacy_rights")),
		_row("opt_policy", Color("#0ea5e9"), "Privacy Policy", LegalText.open_page.bind("privacy_policy")),
		_row("opt_prefs", Color("#06b6d4"), "Privacy Preferences", show_page.bind("privacy_prefs")),
		_row("opt_mail", Color("#f59e0b"), "Contact Us", _contact),
		_row("", Color("#ef4444"), "Delete my game data", _confirm_delete),
	])


func _page_privacy_prefs() -> void:
	_title.text = "Privacy Preferences"
	_card([
		_toggle_row("Personalised ads", GameData.personalized_ads, func(on: bool) -> void:
			GameData.personalized_ads = on
			GameData.save_game()),
	])
	if AdManager.privacy_options_required():
		_card([_row("opt_prefs", Color("#06b6d4"), "Ad consent choices", AdManager.show_privacy_options)])
	_text_card("[b]What does this do?[/b]\n[b]ON[/b] - ads may match your interests, based on your advertising ID and app activity.\n[b]OFF[/b] - you still see ads, but they are general and not based on you.\n\nEither way the game plays exactly the same, and your choice is saved on this phone.")
	_card([_row("opt_prefs", Color("#06b6d4"), "Learn more on our website", LegalText.open_page.bind("privacy_prefs"))])


## Opens the Contact Us page on the Anant Originals website.
func _contact() -> void:
	LegalText.open_page("contact")


func _confirm_delete() -> void:
	_title.text = "Delete data?"
	for c in _content.get_children():
		c.queue_free()
	_add_text("This removes all your levels, stars, power and settings from this device. It cannot be undone.")
	_card([
		_row("", Color("#ef4444"), "Yes, delete everything", func() -> void:
			GameData.reset_all_data()
			get_tree().change_scene_to_file("res://scenes/Welcome.tscn")),
		_row("", LINK, "Cancel", show_page.bind("privacy_rights")),
	])


# --- Building blocks ------------------------------------------------------------------------------

## A white rounded card holding rows separated by thin lines.
func _card(rows: Array) -> void:
	var card := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color.WHITE
	box.set_corner_radius_all(26)
	card.add_theme_stylebox_override("panel", box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	card.add_child(v)
	for i in rows.size():
		if i > 0:
			var sep := ColorRect.new()
			sep.color = Color("#e2e8f0")
			sep.custom_minimum_size = Vector2(0, 2)
			v.add_child(sep)
		v.add_child(rows[i])
	_content.add_child(card)


## One tappable row: [coloured icon]  Title  ›
func _row(icon: String, color: Color, text: String, action: Callable) -> Button:
	var b := _flat_button("", TEXT)
	b.custom_minimum_size = Vector2(0, 108)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 26)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(4, 0)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(pad)
	if icon != "":
		var tile := PanelContainer.new()
		var tile_box := StyleBoxFlat.new()
		tile_box.bg_color = color
		tile_box.set_corner_radius_all(16)
		tile.add_theme_stylebox_override("panel", tile_box)
		tile.custom_minimum_size = Vector2(72, 72)
		tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex := TextureRect.new()
		tex.texture = load("res://icons/%s.svg" % icon)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(48, 48)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(tex)
		h.add_child(tile)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", color if icon == "" else TEXT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(label)
	var chevron := Label.new()
	chevron.text = "›"
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chevron.add_theme_font_size_override("font_size", 48)
	chevron.add_theme_color_override("font_color", Color("#94a3b8"))
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(chevron)
	var pad2 := pad.duplicate()
	h.add_child(pad2)
	b.pressed.connect(func() -> void:
		GameData.play_sfx("tap")
		action.call())
	return b


## A row with an on/off switch.
func _toggle_row(text: String, value: bool, on_change: Callable) -> Control:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, 108)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(24, 0)
	h.add_child(pad)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", TEXT)
	h.add_child(label)
	# Big pill switch: green "ON" / grey "OFF".
	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = value
	toggle.custom_minimum_size = Vector2(130, 64)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var off := StyleBoxFlat.new()
	off.bg_color = Color("#cbd5e1")
	off.set_corner_radius_all(32)
	var on := off.duplicate()
	on.bg_color = Color("#22c55e")
	for s in ["normal", "hover", "focus"]:
		toggle.add_theme_stylebox_override(s, off)
	toggle.add_theme_stylebox_override("pressed", on)
	toggle.add_theme_stylebox_override("hover_pressed", on)
	for c in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		toggle.add_theme_color_override(c, Color.WHITE)
	toggle.add_theme_font_size_override("font_size", 28)
	toggle.text = "ON" if value else "OFF"
	toggle.toggled.connect(func(pressed: bool) -> void:
		toggle.text = "ON" if pressed else "OFF"
		on_change.call(pressed))
	h.add_child(toggle)
	var pad2 := Control.new()
	pad2.custom_minimum_size = Vector2(40, 0)
	h.add_child(pad2)
	return h


## Text inside a white rounded card.
func _text_card(bbcode: String) -> void:
	var card := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color.WHITE
	box.set_corner_radius_all(26)
	box.set_content_margin_all(30)
	card.add_theme_stylebox_override("panel", box)
	_content.add_child(card)
	_add_text(bbcode)
	_content.get_child(-1).reparent(card)


## Small grey heading above a card.
func _section(text: String) -> void:
	var label := Label.new()
	label.text = "   " + text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", MUTED)
	_content.add_child(label)


func _center_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _add_text(bbcode: String) -> void:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = bbcode
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override("normal_font_size", 30)
	r.add_theme_font_size_override("bold_font_size", 32)
	r.add_theme_color_override("default_color", Color("#334155"))
	var bold := SystemFont.new()
	bold.font_names = PackedStringArray(["Nunito", "Roboto", "Segoe UI", "Arial", "sans-serif"])
	bold.font_weight = 800
	r.add_theme_font_override("bold_font", bold)
	_content.add_child(r)


func _flat_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, empty)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", color)
	b.add_theme_color_override("font_pressed_color", color.darkened(0.2))
	b.add_theme_font_size_override("font_size", 34)
	return b
