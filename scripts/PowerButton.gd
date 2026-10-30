class_name PowerButton
extends Button
## Round power button that draws a ring around itself: the ring fills up with the
## player's no-mistake streak, and a full ring earns one more power charge.

const TRACK_COLOR := Color("#fde68a")
const FILL_COLOR := Color("#f59e0b")

## 0..1 share of the streak needed for the next charge.
var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 + 7.0
	draw_arc(center, radius, 0.0, TAU, 64, TRACK_COLOR, 7.0, true)
	if progress > 0.0:
		draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + TAU * progress, 64, FILL_COLOR, 7.0, true)
