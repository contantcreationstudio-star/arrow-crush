class_name TouchScroll
extends RefCounted
## Makes a ScrollContainer full of buttons and text behave on a phone:
##  - a finger drag that starts on a row, a card or text scrolls the list
##    (Godot's default "stop" mouse filter would swallow the touch), and
##  - lifting the finger after a scroll is not a tap, so no row opens and no
##    switch flips by accident.
## Call setup() once per ScrollContainer and guard() after its content is built
## (guard() is safe to call again when more content is added).


static func setup(scroll: ScrollContainer) -> void:
	scroll.set_meta("dragged", false)
	scroll.scroll_deadzone = 12  # a shaky tap still counts as a tap
	scroll.scroll_started.connect(func() -> void: scroll.set_meta("dragged", true))
	# Every new touch starts clean. Children pass their events up, so this sees them all.
	scroll.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			scroll.set_meta("dragged", false))


static func guard(scroll: ScrollContainer) -> void:
	for c: Control in scroll.find_children("*", "Control", true, false):
		if c.mouse_filter == Control.MOUSE_FILTER_STOP:
			c.mouse_filter = Control.MOUSE_FILTER_PASS
	for b: BaseButton in scroll.find_children("*", "BaseButton", true, false):
		if b.has_meta("tap_guard"):
			continue
		b.set_meta("tap_guard", true)
		for conn: Dictionary in b.pressed.get_connections():
			var cb: Callable = conn.callable
			b.pressed.disconnect(cb)
			b.pressed.connect(func() -> void:
				if not bool(scroll.get_meta("dragged", false)):
					cb.call())
		for conn: Dictionary in b.toggled.get_connections():
			var cb: Callable = conn.callable
			b.toggled.disconnect(cb)
			b.toggled.connect(func(on: bool) -> void:
				if bool(scroll.get_meta("dragged", false)):
					b.set_pressed_no_signal(not on)  # the scroll flipped it: put it back
					return
				cb.call(on))
