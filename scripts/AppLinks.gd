class_name AppLinks
## Rate the game, share it with friends, and leave the game safely with the phone's Back key.
## On Android these talk to the system through Godot's AndroidRuntime singleton (no plugin);
## on desktop they fall back to the store web page / the clipboard.

const PACKAGE := "com.anantoriginals.arrowcrush"
const STORE_WEB := "https://play.google.com/store/apps/details?id=" + PACKAGE
const SHARE_TEXT := "I'm hooked on Arrow Crush - tap the arrows, crush same colours and set off giant chain reactions! Try it free: " + STORE_WEB


static func _runtime() -> Object:
	if OS.get_name() == "Android" and Engine.has_singleton("AndroidRuntime"):
		return Engine.get_singleton("AndroidRuntime")
	return null


## Opens Arrow Crush's page in the Play Store app (the web page if there is no store app).
static func rate() -> void:
	GameData.rate_state = 2  # they went to rate: never ask again
	GameData.save_game()
	if OS.get_name() == "Android" and OS.shell_open("market://details?id=" + PACKAGE) == OK:
		return
	OS.shell_open(STORE_WEB)


## The phone's share sheet (WhatsApp, Telegram, SMS, mail...) with a short line and the store link.
static func share() -> void:
	var rt := _runtime()
	if rt:
		var activity: Object = rt.getActivity()
		rt.runOnUiThread(func() -> void:
			var intent_class: Object = JavaClassWrapper.wrap("android.content.Intent")
			var send: Object = intent_class.parseUri("intent:#Intent;action=android.intent.action.SEND;type=text/plain;S.android.intent.extra.TEXT="
				+ SHARE_TEXT.uri_encode() + ";end", 0)
			activity.startActivity(intent_class.createChooser(send, "Share Arrow Crush")))
		return
	DisplayServer.clipboard_set(SHARE_TEXT)
	AdManager._toast("Link copied - paste it to a friend!")


## The phone's Back key on a menu screen: the game slips into the background (like pressing
## Home) instead of shutting the engine down. Shutting down from Back crashed on some phones
## (Oppo A78: "pthread_mutex_lock called on a destroyed mutex" while the last frame was drawn).
static func send_to_background() -> void:
	var rt := _runtime()
	if rt:
		var activity: Object = rt.getActivity()
		rt.runOnUiThread(func() -> void: activity.moveTaskToBack(true))
