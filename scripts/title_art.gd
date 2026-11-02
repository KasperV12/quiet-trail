extends Control
class_name TitleArt

func _ready() -> void:
	custom_minimum_size = Vector2(450, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	for i in range(18):
		var t := float(i) / 17.0
		var band := Rect2(0, h * t, w, h / 17.0 + 1.0)
		draw_rect(band, Color("#142b36").lerp(Color("#7d7768"), pow(t, 1.55)))
	for i in range(26):
		var star_x := fposmod(float(i * 97 + 23), w)
		var star_y := fposmod(float(i * 47 + 11), h * 0.43)
		var alpha := 0.23 + float(posmod(i * 31, 7)) * 0.055
		draw_circle(Vector2(star_x, star_y), 0.7 + float(i % 3) * 0.25, Color(0.88, 0.91, 0.82, alpha))
	var moon := Vector2(w * 0.23, h * 0.25)
	draw_circle(moon, h * 0.085, Color("#e7d8ad", 0.10))
	draw_circle(moon, h * 0.048, Color("#f0dfb4", 0.85))
	_draw_polygon([
		Vector2(0, h * 0.68), Vector2(w * 0.13, h * 0.43), Vector2(w * 0.28, h * 0.66),
		Vector2(w * 0.44, h * 0.38), Vector2(w * 0.65, h * 0.68), Vector2(w * 0.82, h * 0.45),
		Vector2(w, h * 0.67), Vector2(w, h), Vector2(0, h)
	], Color("#53625b", 0.64))
	_draw_polygon([
		Vector2(0, h * 0.79), Vector2(w * 0.19, h * 0.61), Vector2(w * 0.34, h * 0.78),
		Vector2(w * 0.55, h * 0.54), Vector2(w * 0.70, h * 0.76), Vector2(w * 0.84, h * 0.55),
		Vector2(w, h * 0.75), Vector2(w, h), Vector2(0, h)
	], Color("#344b43", 0.92))
	_draw_polygon([
		Vector2(0, h * 0.88), Vector2(w * 0.20, h * 0.75), Vector2(w * 0.38, h * 0.85),
		Vector2(w * 0.58, h * 0.67), Vector2(w * 0.72, h * 0.86), Vector2(w * 0.87, h * 0.68),
		Vector2(w, h * 0.83), Vector2(w, h), Vector2(0, h)
	], Color("#1b332d"))
	var tower_top := Vector2(w * 0.76, h * 0.32)
	var lamp := tower_top + Vector2(0, h * 0.09)
	_draw_polygon([
		lamp, Vector2(w * 0.30, h * 0.36), Vector2(w * 0.30, h * 0.44),
		Vector2(w * 0.76, h * 0.43)
	], Color("#f5cf86", 0.15))
	draw_line(lamp, Vector2(w * 0.30, h * 0.40), Color("#f8d995", 0.23), 1.0, true)
	draw_rect(Rect2(w * 0.745, h * 0.41, w * 0.03, h * 0.42), Color("#d8c8a5"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.72, h * 0.84), Vector2(w * 0.745, h * 0.44),
		Vector2(w * 0.775, h * 0.44), Vector2(w * 0.80, h * 0.84)
	]), Color("#efe3c5"))
	draw_rect(Rect2(w * 0.733, h * 0.38, w * 0.054, h * 0.07), Color("#45514a"))
	draw_rect(Rect2(w * 0.74, h * 0.39, w * 0.04, h * 0.045), Color("#f0cd82"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.724, h * 0.385), Vector2(w * 0.75, h * 0.335),
		Vector2(w * 0.778, h * 0.385)
	]), Color("#293a36"))
	draw_rect(Rect2(w * 0.727, h * 0.452, w * 0.066, h * 0.012), Color("#735c43"))
	draw_circle(lamp, h * 0.045, Color("#f8d487", 0.18))
	draw_circle(lamp, h * 0.018, Color("#ffe8b0"))
	_draw_polygon([
		Vector2(w * 0.65, h * 0.84), Vector2(w * 0.72, h * 0.76),
		Vector2(w * 0.76, h * 0.80), Vector2(w * 0.80, h * 0.74),
		Vector2(w * 0.86, h * 0.86), Vector2(w * 0.86, h), Vector2(w * 0.65, h)
	], Color("#26352f"))
	_draw_pine(Vector2(w * 0.08, h * 0.73), h * 0.66, Color("#233b32"), Color("#385345"))
	_draw_pine(Vector2(w * 0.93, h * 0.73), h * 0.83, Color("#172d28"), Color("#2a4739"))
	_draw_pine(Vector2(w * 0.99, h * 0.82), h * 0.60, Color("#203a30"), Color("#385545"))
	for i in range(3):
		var y := h * (0.89 + i * 0.035)
		draw_line(Vector2(w * 0.18, y), Vector2(w * 0.70, y - h * 0.018), Color(0.84, 0.87, 0.77, 0.08 - i * 0.015), 2.0, true)
	draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.08, 0.07, 0.12), false, 1.0)

func _draw_polygon(points: Array[Vector2], color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func _draw_pine(base: Vector2, height: float, shadow: Color, light: Color) -> void:
	var width := height * 0.42
	draw_line(base + Vector2(0, -height * 0.10), base + Vector2(0, height * 0.08), Color("#594e3b"), maxf(2.0, height * 0.07), true)
	for layer in range(3):
		var top := base.y - height * (0.47 - layer * 0.18)
		var span := width * (0.56 + layer * 0.22)
		var bottom := top + height * 0.36
		_draw_polygon([
			Vector2(base.x, top), Vector2(base.x + span * 0.22, top + height * 0.17),
			Vector2(base.x + span, bottom), Vector2(base.x, bottom - height * 0.035),
			Vector2(base.x - span * 0.82, bottom)
		], shadow if layer % 2 == 0 else light)
		draw_line(Vector2(base.x, top + height * 0.04), Vector2(base.x - span * 0.47, bottom - height * 0.015), Color(0.78, 0.78, 0.57, 0.12), 1.0, true)
