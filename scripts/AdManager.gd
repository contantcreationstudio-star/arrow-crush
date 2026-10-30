extends Node
## Global autoload ("AdManager"): the one place the game asks for ads.
##
## The game is ad-supported (no "Remove Ads"): players watch a short rewarded video
## to get a hint, power, undo or extra heart, and see an occasional interstitial
## between levels.
##
## On an Android phone the ads come from Google AdMob through the Poing Studios plugin
## (res://addons/admob). Everywhere else (the Godot editor, a desktop run) a DEMO overlay
## stands in for the ad, so the whole flow can still be played and tested.
##
## Player-friendly rules (learned from 1-star reviews of rival arrow games):
##   - NO ad when the app opens or comes back from the background (no app-open ads).
##   - Interstitials only between won levels, every INTERSTITIAL_EVERY levels, never
##     before INTERSTITIAL_FROM_LEVEL, never after a loss, never twice within
##     INTERSTITIAL_GAP_SEC. Rewarded videos only when the player taps a button.
##   - One video = the full reward it promised. Never two videos for one reward.
##   - An ad that hangs or never closes is cut off after AD_TIMEOUT_SEC and the player
##     still gets the reward - a stuck ad must never cost them the level.
##   - If a rewarded video can't load (offline, no fill), say so kindly; don't loop.
##   - "Personalised ads" OFF in Privacy Preferences = non-personalised ads (npa=1).
##   - In the AdMob dashboard (see ADS_SAFETY.md): max content rating G, block sensitive
##     categories, check the Ad review center, no unknown mediation networks.

signal ad_started
signal ad_finished

## Google's DEMO ad units: they always show test ads and are safe to tap.
## Before publishing, replace them with your own ad unit IDs from the AdMob dashboard,
## and the App ID in Project Settings > AdMob > Android.
const REWARDED_UNIT_ID := "ca-app-pub-3940256099942544/5224354917"
const INTERSTITIAL_UNIT_ID := "ca-app-pub-3940256099942544/1033173712"

# Light interstitials. The limits are by time and per day, not by level number, so they
# stay the same however many levels the game grows to.
const INTERSTITIAL_EVERY := 5       # levels between interstitials
const INTERSTITIAL_FROM_LEVEL := 15 # the first 14 levels are always ad-free
const INTERSTITIAL_GAP_SEC := 240.0 # at least this long since the last ad of any kind
const AD_TIMEOUT_SEC := 75.0       # a stuck ad is let go after this; the reward is still given
const RETRY_SEC := 30.0            # wait before loading again after a failed load
# Invalid-traffic safety (AdMob limits ad serving when traffic looks odd):
const INTERSTITIALS_PER_DAY := 5   # most interstitials one player sees in a day
const REWARDED_PER_DAY := 25       # most rewarded videos one player can watch in a day
const SHOW_DELAY_SEC := 0.6        # input is held this long before an ad opens, so the tap
                                   # that pressed "Next" can never land on the ad as a click
## Your own phones: they get test ads even in the real build, so your own taps never
## count as clicks. Get the ID from `adb logcat | findstr "test device"` on first launch
## of a real-ads build (AdMob prints it), then add it here.
const TEST_DEVICE_IDS: Array[String] = []
const CAPS_PATH := "user://ad_caps.cfg"

var _levels_since_interstitial := 0
var _showing := false
var _last_ad_msec := -1000000  # when the last ad (rewarded or not) ended
var _ad_id := 0                # counts ads, so a late close / timeout of an old ad is ignored
var _ad_layer: CanvasLayer     # the demo overlay on screen

# Real AdMob (Android with the plugin)
var _real := false
var _ready_for_ads := false
var _rewarded_ad: RewardedAd
var _interstitial_ad: InterstitialAd
var _loading_rewarded := false
var _loading_interstitial := false
var _earned := false           # the player finished the current rewarded video
var _caps_day := ""            # date the counts below belong to (local, YYYY-MM-DD)
var _shown_today := {"interstitial": 0, "rewarded": 0}


func _ready() -> void:
	_load_caps()
	_real = Engine.has_singleton("PoingGodotAdMob")
	if _real:
		_ask_consent_then_start()


func is_showing() -> bool:
	return _showing


## True where the law gives players a Google consent form (EEA, UK, Switzerland).
## Then they must be able to open it again and change their choice at any time.
func privacy_options_required() -> bool:
	return _real and UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() \
			== ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED


## Opens Google's consent form again so the player can change their choice.
func show_privacy_options() -> void:
	if _real:
		UserMessagingPlatform.show_privacy_options_form(func(_error: FormError) -> void: pass)


## Shows a rewarded video. `on_reward` runs only if the player watched it to the end.
## `ad_finished` is always emitted afterwards, even when no video was available.
func show_rewarded(reward_label: String, on_reward: Callable) -> void:
	if _showing:
		return
	if not _under_cap("rewarded", REWARDED_PER_DAY):
		_toast("That's all the videos for today. Come back tomorrow!")
		ad_started.emit()
		ad_finished.emit()
		return
	if not _real:
		_count("rewarded")
		_demo_ad("Rewarded video", "Reward: " + reward_label, 3, true, on_reward)
		return
	if _rewarded_ad == null:
		# Nothing to show yet: tell the player kindly, try loading again, release the board.
		_toast("No video right now. Please try again in a moment.")
		_load_rewarded()
		ad_started.emit()
		ad_finished.emit()
		return

	var id := _begin_ad()
	_count("rewarded")
	_earned = false
	var ad := _rewarded_ad
	_rewarded_ad = null
	var callbacks := FullScreenContentCallback.new()
	callbacks.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		_finish_ad(id, on_reward if _earned else Callable())
		_load_rewarded()
	callbacks.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void:
		ad.destroy()
		_toast("The video couldn't play. Please try again.")
		_finish_ad(id, Callable())
		_load_rewarded()
	ad.full_screen_content_callback = callbacks
	# Watchdog: a video that never closes still pays out and gives the game back.
	_start_watchdog(id, on_reward)
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item: RewardedItem) -> void:
		_earned = true
	await _hold_input()
	ad.show(listener)


## Call after each won level; shows an interstitial every few levels (never after a loss,
## never within INTERSTITIAL_GAP_SEC of another ad), then `then`.
func level_finished(level: int, then: Callable) -> void:
	_levels_since_interstitial += 1
	var since_last := (Time.get_ticks_msec() - _last_ad_msec) / 1000.0
	if level < INTERSTITIAL_FROM_LEVEL or _levels_since_interstitial < INTERSTITIAL_EVERY or _showing \
			or since_last < INTERSTITIAL_GAP_SEC or not _under_cap("interstitial", INTERSTITIALS_PER_DAY):
		then.call()
		return
	if not _real:
		_levels_since_interstitial = 0
		_count("interstitial")
		_demo_ad("Advertisement", "Thanks for supporting the game!", 2, false, then)
		return
	if _interstitial_ad == null:
		# Not loaded: simply carry on (try again after the next level).
		_load_interstitial()
		then.call()
		return

	_levels_since_interstitial = 0
	var id := _begin_ad()
	_count("interstitial")
	var ad := _interstitial_ad
	_interstitial_ad = null
	var callbacks := FullScreenContentCallback.new()
	callbacks.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		_finish_ad(id, then)
		_load_interstitial()
	callbacks.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void:
		ad.destroy()
		_finish_ad(id, then)
		_load_interstitial()
	ad.full_screen_content_callback = callbacks
	_start_watchdog(id, then)
	await _hold_input()
	ad.show()


# --- Real AdMob ----------------------------------------------------------------------------------

## Google's consent form (UMP) is only shown where the law asks for it (EEA, UK,
## Switzerland). Ads start once consent is settled, or straight away if it isn't needed.
func _ask_consent_then_start() -> void:
	UserMessagingPlatform.consent_information.update(
		ConsentRequestParameters.new(), _on_consent_info_updated, _on_consent_error)


func _on_consent_info_updated() -> void:
	var consent := UserMessagingPlatform.consent_information
	if consent.get_is_consent_form_available() \
			and consent.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
		UserMessagingPlatform.load_consent_form(_on_consent_form_loaded, _on_consent_error)
	else:
		_start_ads()


func _on_consent_form_loaded(form: ConsentForm) -> void:
	form.show(_on_consent_error)  # called when the form closes (error or not)


## Any consent outcome (error, dismissed form) ends in starting ads; the SDK itself
## respects whatever the player chose.
func _on_consent_error(_error: FormError) -> void:
	_start_ads()


func _start_ads() -> void:
	if _ready_for_ads:
		return
	# Family-friendly ads only, and test ads on our own phones (see TEST_DEVICE_IDS).
	var config := RequestConfiguration.new()
	config.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_G
	config.test_device_ids = TEST_DEVICE_IDS.duplicate()
	MobileAds.set_request_configuration(config)
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		_ready_for_ads = true
		_load_rewarded()
		_load_interstitial()
	MobileAds.initialize(listener)


func _request() -> AdRequest:
	var request := AdRequest.new()
	if not GameData.personalized_ads:
		request.extras = {"npa": "1"}  # Google's flag for non-personalised ads
	return request


func _load_rewarded() -> void:
	if not _ready_for_ads or _loading_rewarded or _rewarded_ad != null:
		return
	_loading_rewarded = true
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: RewardedAd) -> void:
		_loading_rewarded = false
		_rewarded_ad = ad
	callback.on_ad_failed_to_load = func(_error: LoadAdError) -> void:
		_loading_rewarded = false
		get_tree().create_timer(RETRY_SEC, true, false, true).timeout.connect(_load_rewarded)
	RewardedAdLoader.new().load(REWARDED_UNIT_ID, _request(), callback)


func _load_interstitial() -> void:
	if not _ready_for_ads or _loading_interstitial or _interstitial_ad != null:
		return
	_loading_interstitial = true
	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_loading_interstitial = false
		_interstitial_ad = ad
	callback.on_ad_failed_to_load = func(_error: LoadAdError) -> void:
		_loading_interstitial = false
		get_tree().create_timer(RETRY_SEC, true, false, true).timeout.connect(_load_interstitial)
	InterstitialAdLoader.new().load(INTERSTITIAL_UNIT_ID, _request(), callback)


# --- Shared ad bookkeeping -----------------------------------------------------------------------

## Marks a new ad as on screen and returns its number.
## The game is already blocked (ad_started); wait a moment so a finger still on the
## screen lifts before the ad appears.
func _hold_input() -> void:
	await get_tree().create_timer(SHOW_DELAY_SEC, true, false, true).timeout


# --- Daily caps (saved on this phone only) -------------------------------------------------------

func _today() -> String:
	return Time.get_date_string_from_system()


func _load_caps() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CAPS_PATH) == OK and str(cfg.get_value("caps", "day", "")) == _today():
		_caps_day = _today()
		_shown_today.interstitial = int(cfg.get_value("caps", "interstitial", 0))
		_shown_today.rewarded = int(cfg.get_value("caps", "rewarded", 0))


func _under_cap(kind: String, limit: int) -> bool:
	if _caps_day != _today():
		_caps_day = _today()
		_shown_today = {"interstitial": 0, "rewarded": 0}
	return int(_shown_today[kind]) < limit


func _count(kind: String) -> void:
	_under_cap(kind, 0)  # rolls the counts over at midnight
	_shown_today[kind] = int(_shown_today[kind]) + 1
	var cfg := ConfigFile.new()
	cfg.set_value("caps", "day", _caps_day)
	cfg.set_value("caps", "interstitial", _shown_today.interstitial)
	cfg.set_value("caps", "rewarded", _shown_today.rewarded)
	cfg.save(CAPS_PATH)


func _begin_ad() -> int:
	_showing = true
	_ad_id += 1
	ad_started.emit()
	return _ad_id


## If ad number `id` never reports back (hung video, broken close button), let it go
## after AD_TIMEOUT_SEC and still pay out, so the player never loses a level to an ad.
func _start_watchdog(id: int, done: Callable) -> void:
	get_tree().create_timer(AD_TIMEOUT_SEC, true, false, true).timeout.connect(
		func() -> void: _finish_ad(id, done))


## Ends ad number `id` once (normal close or watchdog, whichever comes first).
## `done` may be empty (e.g. a rewarded video closed before the end).
func _finish_ad(id: int, done: Callable) -> void:
	if id != _ad_id or not _showing:
		return
	if is_instance_valid(_ad_layer):
		_ad_layer.queue_free()
	_ad_layer = null
	_showing = false
	_last_ad_msec = Time.get_ticks_msec()
	ad_finished.emit()
	if done.is_valid():
		done.call()


# --- Demo overlay (editor / desktop) -------------------------------------------------------------

func _demo_ad(title: String, subtitle: String, seconds: int, rewarded: bool, done: Callable) -> void:
	var id := _begin_ad()
	_start_watchdog(id, done)
	var layer := CanvasLayer.new()
	layer.layer = 100
	_ad_layer = layer
	get_tree().root.add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.1, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)  # also swallows every tap while the "ad" runs

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 22)
	bg.add_child(box)

	var tag := _label("AD  •  DEMO", 24, Color("#fbbf24"))
	var head := _label(title, 52, Color.WHITE)
	var sub := _label(subtitle, 28, Color("#cbd5e1"))
	var count := _label("", 34, Color.WHITE)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(460, 14)
	bar.show_percentage = false
	bar.max_value = seconds
	for c in [tag, head, sub, bar, count]:
		box.add_child(c)

	var t := create_tween()
	t.tween_property(bar, "value", float(seconds), float(seconds))
	for i in seconds:
		var left := seconds - i
		t.parallel().tween_callback(func() -> void:
			count.text = ("Reward in %d" if rewarded else "Closing in %d") % left).set_delay(float(i))
	t.tween_callback(func() -> void:
		count.text = "Reward unlocked!" if rewarded else "")
	t.tween_interval(0.5 if rewarded else 0.1)
	t.tween_callback(func() -> void: _finish_ad(id, done))


## A short message at the bottom of the screen that fades away.
func _toast(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 101
	get_tree().root.add_child(layer)
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.07, 0.12, 0.92)
	box.set_corner_radius_all(28)
	box.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", box)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.position.y -= 180
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := _label(text, 28, Color.WHITE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(520, 0)
	panel.add_child(label)
	layer.add_child(panel)
	var t := create_tween()
	t.tween_interval(2.4)
	t.tween_property(panel, "modulate:a", 0.0, 0.4)
	t.tween_callback(layer.queue_free)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
