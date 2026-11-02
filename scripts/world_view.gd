extends Control
class_name ExpeditionMap

signal cell_selected(delta: Vector2i)
signal notice(text: String)

const GRASS_TILE: Texture2D = preload("res://assets/kenney_rpg/PNG/rpgTile039.png")
const GRASS_TILE_ALT: Texture2D = preload("res://assets/kenney_rpg/PNG/rpgTile003.png")
const DIRT_TILE: Texture2D = preload("res://assets/kenney_rpg/PNG/rpgTile024.png")
const STONE_TILE: Texture2D = preload("res://assets/kenney_rpg/PNG/rpgTile050.png")
const TREE_SPRITES: Array[Texture2D] = [
	preload("res://assets/kenney_rpg/PNG/rpgTile175.png"),
	preload("res://assets/kenney_rpg/PNG/rpgTile179.png"),
	preload("res://assets/kenney_rpg/PNG/rpgTile195.png"),
	preload("res://assets/kenney_rpg/PNG/rpgTile199.png"),
	preload("res://assets/kenney_rpg/PNG/rpgTile200.png")
]
const UNDERBRUSH: Texture2D = preload("res://assets/kenney_rpg/PNG/rpgTile159.png")

var state: ExpeditionState
var pulse := 0.0
var map_rect := Rect2()
var cell_size := Vector2.ZERO
var map_origin := Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(650, 520)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)

func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()

func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color("#28372f"))
	draw_rect(Rect2(Vector2.ZERO, size * Vector2(1.0, 0.52)), Color("#35453b", .24))
	draw_circle(size * Vector2(.28, .22), size.y * .40, Color("#89916b", .025))
	if state == null:
		return
	var padding := Vector2(26, 26)
	var cell := minf((size.x - padding.x * 2.0) / state.MAP_W, (size.y - padding.y * 2.0) / state.MAP_H)
	cell_size = Vector2(cell, cell)
	map_origin = Vector2((size.x - cell * state.MAP_W) * 0.5, (size.y - cell * state.MAP_H) * 0.5)
	map_rect = Rect2(map_origin, Vector2(cell * state.MAP_W, cell * state.MAP_H))
	for y in range(state.MAP_H):
		for x in range(state.MAP_W):
			var cell_pos := Vector2i(x, y)
			var rect := Rect2(map_origin + Vector2(x, y) * cell, cell_size)
			var data: Dictionary = state.grid[state._index(cell_pos)]
			_draw_ground(rect, cell_pos, str(data["kind"]), bool(data["seen"]))
			if bool(data["seen"]):
				_draw_detail(rect, cell_pos, str(data["kind"]), str(data["found"]), bool(data["visited"]))
	_draw_trail()
	_draw_player()
	_draw_border()

func _draw_ground(rect: Rect2, cell: Vector2i, kind: String, seen: bool) -> void:
	if seen:
		var texture: Texture2D = GRASS_TILE
		var tint := Color.WHITE
		match kind:
			"forest":
				texture = GRASS_TILE if posmod(cell.x * 7 + cell.y * 11, 3) != 0 else GRASS_TILE_ALT
				tint = Color("#d8e5c8")
			"clearing", "camp":
				texture = GRASS_TILE_ALT
				tint = Color("#f0e9c2")
			"stream":
				texture = GRASS_TILE
				tint = Color("#c2d7c5")
			"ridge", "bog":
				texture = DIRT_TILE
				tint = Color("#d8d0ad") if kind == "ridge" else Color("#b4c59a")
			"ruin":
				texture = STONE_TILE
				tint = Color("#e4ddc5")
		draw_texture_rect(texture, rect.grow(-0.8), false, tint)
		draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(rect.size.x - 2, 1.1)), Color(1, 0.95, 0.78, .15))
	else:
		draw_rect(rect.grow(-0.8), Color("#1d2a23"))
		var haze := Color("#66715b")
		var center := rect.get_center()
		for i in range(4):
			var p := center + Vector2(cos(i * 2.1 + cell.x) * rect.size.x * .22, sin(i * 1.7 + cell.y) * rect.size.y * .2)
			draw_circle(p, rect.size.x * (.26 + float(i % 2) * .08), Color(haze, 0.12))
		draw_rect(rect.grow(-1), Color("#26352e", .28))

func _draw_detail(rect: Rect2, cell: Vector2i, kind: String, found: String, visited: bool) -> void:
	var center := rect.get_center()
	var s := rect.size.x
	match kind:
		"forest":
			_draw_forest_canopy(center, s, cell)
		"clearing":
			_draw_grass(center, s, cell)
		"stream":
			_draw_stream(rect, cell)
		"ridge":
			_draw_rock(center + Vector2(-s * .18, s * .08), s * .30)
			_draw_rock(center + Vector2(s * .20, -s * .19), s * .23)
		"bog":
			_draw_moss(center, s, cell)
		"camp":
			_draw_camp(center, s)
		"ruin":
			_draw_ruin(center, s)
	if cell in state.campfires:
		var fire_pos := center + Vector2(s * .28, s * .28)
		draw_circle(fire_pos, s * .12, Color(1, .58, .25, .20))
		draw_colored_polygon(PackedVector2Array([fire_pos + Vector2(-s * .05, s * .04), fire_pos + Vector2(-s * .015, -s * .08), fire_pos + Vector2(s * .01, -s * .015), fire_pos + Vector2(s * .05, -s * .07), fire_pos + Vector2(s * .045, s * .04)]), Color("#f0a252"))
	if found != "" and not (found in ["wood", "food", "notes"] and visited):
		_draw_find(center + Vector2(s * .31, -s * .30), s, found)
	if visited:
		draw_rect(rect.grow(-1.2), Color("#101812", .12))

func _draw_forest_canopy(center: Vector2, s: float, cell: Vector2i) -> void:
	var tree_index := posmod(cell.x * 17 + cell.y * 31, TREE_SPRITES.size())
	var sway := sin(pulse * 0.7 + cell.x * 1.3 + cell.y) * 1.0
	var tree_rect := Rect2(center + Vector2(-s * .48 + sway, -s * .49), Vector2(s * .96, s * .96))
	draw_texture_rect(TREE_SPRITES[tree_index], tree_rect, false)
	if posmod(cell.x * 7 + cell.y * 13, 3) == 0:
		var bush_rect := Rect2(center + Vector2(s * .18, s * .12), Vector2(s * .38, s * .38))
		draw_texture_rect(UNDERBRUSH, bush_rect, false)

func _draw_pine(center: Vector2, s: float, cell: Vector2i, layer: int) -> void:
	var ground := center + Vector2(s * .09, s * .36)
	_draw_ellipse_filled(ground, Vector2(s * .43, s * .15), Color("#1e2b22", .34))
	draw_rect(Rect2(center + Vector2(-s * .055, s * .04), Vector2(s * .11, s * .39)), Color("#654a35"))
	var greens := [Color("#60714d"), Color("#506746"), Color("#3d5941")]
	var shade := Color("#314837")
	for layer_id in range(3):
		var width := s * (0.55 + layer_id * .18)
		var top := center.y - s * (.47 - layer_id * .15)
		var bottom := top + s * .48
		var points := PackedVector2Array([
			Vector2(center.x, top), Vector2(center.x + width * .20, top + s * .23),
			Vector2(center.x + width * .48, bottom), Vector2(center.x + width * .21, bottom - s * .025),
			Vector2(center.x, bottom + s * .025), Vector2(center.x - width * .22, bottom - s * .02),
			Vector2(center.x - width * .48, bottom)
		])
		draw_colored_polygon(points, greens[(layer_id + cell.x + cell.y) % greens.size()])
		var lit := PackedVector2Array([Vector2(center.x, top), Vector2(center.x - width * .28, bottom - s * .04), Vector2(center.x + width * .02, bottom + s * .02)])
		draw_colored_polygon(lit, Color(0.79, 0.77, 0.52, .10))
		var glint := PackedVector2Array([Vector2(center.x, top + s * .07), Vector2(center.x - width * .18, top + s * .25), Vector2(center.x - width * .04, top + s * .22)])
		draw_colored_polygon(glint, Color(0.9, 0.86, 0.62, .13))

func _draw_grass(center: Vector2, s: float, cell: Vector2i) -> void:
	for i in range(8):
		var fx := float(posmod(cell.x * 37 + cell.y * 73 + i * 29, 91)) / 100.0 - .45
		var fy := float(posmod(cell.x * 17 + cell.y * 43 + i * 61, 83)) / 100.0 - .42
		var p := center + Vector2(fx, fy) * s
		var petal: Color = [Color("#e5ca80"), Color("#e9dfb0"), Color("#c9ac73")][i % 3]
		draw_line(p, p + Vector2(0, -s * .045), Color("#a7aa6d"), 1.2, true)
		draw_circle(p + Vector2(0, -s * .048), 1.35, petal)
	for i in range(3):
		var blade := center + Vector2(s * (-.34 + i * .22), s * .25)
		draw_line(blade, blade + Vector2(s * .03, -s * .12), Color("#98a06a", .6), 1.3, true)

func _draw_stream(rect: Rect2, cell: Vector2i) -> void:
	var points := PackedVector2Array()
	var phase := float(posmod(cell.x + cell.y, 3)) * .08
	for i in range(9):
		var t := float(i) / 8.0
		var x := rect.position.x + rect.size.x * t
		var y := rect.position.y + rect.size.y * (.46 + sin(t * PI * 2.0 + phase + pulse * .16) * .17)
		points.append(Vector2(x, y))
	draw_polyline(points, Color("#304f4b"), rect.size.x * .33, true)
	draw_polyline(points, Color("#73958a"), rect.size.x * .23, true)
	draw_polyline(points, Color("#a2b5a0", .74), rect.size.x * .025, true)
	for i in range(3):
		var t := .18 + i * .27
		var p := rect.position + Vector2(rect.size.x * t, rect.size.y * (.46 + sin(t * PI * 2.0 + phase + pulse * .16) * .17))
		draw_line(p + Vector2(-4, -2), p + Vector2(4, -2), Color(0.84, .84, .68, .30), 1, true)

func _draw_rock(center: Vector2, s: float) -> void:
	_draw_ellipse_filled(center + Vector2(0, s * .32), Vector2(s * .68, s * .24), Color("#25312a", .4))
	var p := PackedVector2Array([center + Vector2(-s * .6, s * .2), center + Vector2(-s * .36, -s * .36), center + Vector2(s * .14, -s * .53), center + Vector2(s * .56, -s * .12), center + Vector2(s * .48, s * .22)])
	draw_colored_polygon(p, Color("#8a8c7c"))
	draw_colored_polygon(PackedVector2Array([p[0], p[1], p[2], center + Vector2(-s * .04, s * .1)]), Color("#b2ad91", .60))
	draw_line(center + Vector2(-s * .2, -s * .2), center + Vector2(s * .1, -s * .28), Color("#d2c7a2", .48), 1.5, true)

func _draw_moss(center: Vector2, s: float, cell: Vector2i) -> void:
	for i in range(4):
		var p := center + Vector2(s * (-.28 + i * .18), s * (.06 + sin(i * 8 + cell.x) * .13))
		_draw_ellipse_filled(p, Vector2(s * .13, s * .06), Color("#8b9a6a", .78))
		_draw_ellipse_filled(p + Vector2(-s * .025, -s * .025), Vector2(s * .06, s * .02), Color("#c4c291", .34))
	for i in range(3):
		var p := center + Vector2(s * (-.2 + i * .2), s * .28)
		draw_arc(p, s * .11, PI, TAU, 16, Color("#afb68a", .4), 1.2, true)

func _draw_camp(center: Vector2, s: float) -> void:
	_draw_ellipse_filled(center + Vector2(0, s * .22), Vector2(s * .42, s * .16), Color("#28271f", .48))
	var tent := PackedVector2Array([center + Vector2(-s * .34, s * .2), center + Vector2(0, -s * .36), center + Vector2(s * .35, s * .2)])
	draw_colored_polygon(tent, Color("#9e6845"))
	draw_colored_polygon(PackedVector2Array([tent[1], tent[2], center + Vector2(0, s * .2)]), Color("#d0ac72"))
	draw_line(center + Vector2(-s * .30, s * .17), center + Vector2(0, -s * .29), Color("#e4c58e", .6), 1.4, true)
	draw_rect(Rect2(center + Vector2(-s * .045, s * .02), Vector2(s * .11, s * .18)), Color("#453526"))
	var flame := center + Vector2(-s * .31, s * .37)
	draw_circle(flame, s * (.12 + sin(pulse * 3.2) * .015), Color(0.97, .60, .27, .13))
	draw_circle(flame, s * .065, Color("#efa24f"))
	draw_circle(flame, s * .03, Color("#ffe0a1"))

func _draw_ruin(center: Vector2, s: float) -> void:
	_draw_ellipse_filled(center + Vector2(0, s * .24), Vector2(s * .45, s * .14), Color("#2c3029", .42))
	for side in [-1, 1]:
		var p := center + Vector2(s * .28 * side, 0)
		draw_rect(Rect2(p + Vector2(-s * .065, -s * .17), Vector2(s * .13, s * .39)), Color("#838577"))
		draw_rect(Rect2(p + Vector2(-s * .045, -s * .14), Vector2(s * .03, s * .32)), Color("#c0b99a", .45))
	var roof := PackedVector2Array([center + Vector2(-s * .43, -s * .12), center + Vector2(0, -s * .41), center + Vector2(s * .43, -s * .12), center + Vector2(s * .37, -s * .03), center + Vector2(0, -s * .29), center + Vector2(-s * .37, -s * .03)])
	draw_colored_polygon(roof, Color("#a7a58b"))
	draw_line(roof[0], roof[1], Color("#d0c6a3", .7), 2, true)
	draw_rect(Rect2(center + Vector2(-s * .07, s * .00), Vector2(s * .14, s * .22)), Color("#4a5144"))
	draw_circle(center + Vector2(0, s * .08), s * (.07 + sin(pulse * 2.2) * .008), Color(1, .82, .48, .8))

func _draw_find(pos: Vector2, s: float, kind: String) -> void:
	var color := Color("#edce8f")
	match kind:
		"wood": color = Color("#d9aa72")
		"food": color = Color("#d3d392")
		"notes": color = Color("#c5bd91")
		"module": color = Color("#ffd984")
	draw_circle(pos, s * .16, Color(color, .11))
	draw_circle(pos, s * (.072 + sin(pulse * 2.6) * .006), color)
	draw_circle(pos, s * .028, Color("#fff2c7"))

func _draw_trail() -> void:
	var points := PackedVector2Array()
	for y in range(state.MAP_H):
		for x in range(state.MAP_W):
			var c := Vector2i(x, y)
			if bool(state.grid[state._index(c)]["visited"]):
				points.append(map_origin + (Vector2(c) + Vector2(.5, .5)) * cell_size)
	if points.size() > 1:
		for i in range(points.size() - 1):
			var a := points[i]
			var b := points[i + 1]
			if a.distance_to(b) <= cell_size.x * 1.5:
				draw_line(a, b, Color("#e3ca91", .25), 2.2, true)

func _draw_player() -> void:
	var p := map_origin + (Vector2(state.position) + Vector2(.5, .5)) * cell_size
	var s := cell_size.x
	var bob := sin(pulse * 3.0) * s * .012
	draw_circle(p + Vector2(0, s * .24), s * .25, Color("#101712", .38))
	# folded cloak and pack silhouette
	var cloak := PackedVector2Array([p + Vector2(-s * .19, -s * .06 + bob), p + Vector2(0, -s * .28 + bob), p + Vector2(s * .18, -s * .05 + bob), p + Vector2(s * .13, s * .23), p + Vector2(-s * .14, s * .23)])
	draw_colored_polygon(cloak, Color("#475a49"))
	draw_colored_polygon(PackedVector2Array([cloak[0], cloak[1], p + Vector2(-s * .01, s * .17)]), Color("#708269"))
	draw_rect(Rect2(p + Vector2(s * .10, -s * .08 + bob), Vector2(s * .11, s * .18)), Color("#805d3e"))
	# face, hood and scarf
	draw_circle(p + Vector2(0, -s * .23 + bob), s * .105, Color("#cda174"))
	var hood := PackedVector2Array([p + Vector2(-s * .17, -s * .24 + bob), p + Vector2(-s * .08, -s * .39 + bob), p + Vector2(s * .12, -s * .38 + bob), p + Vector2(s * .20, -s * .22 + bob), p + Vector2(s * .12, -s * .16 + bob), p + Vector2(-s * .13, -s * .17 + bob)])
	draw_colored_polygon(hood, Color("#b77b53"))
	draw_rect(Rect2(p + Vector2(-s * .11, -s * .17 + bob), Vector2(s * .21, s * .045)), Color("#e1c08a"))
	# lantern staff and warm glass
	draw_line(p + Vector2(s * .20, -s * .05), p + Vector2(s * .34, s * .26), Color("#92714b"), 2.1, true)
	draw_circle(p + Vector2(s * .34, s * .25), s * (.11 + sin(pulse * 3) * .008), Color(1, .73, .35, .18))
	draw_circle(p + Vector2(s * .34, s * .25), s * .055, Color("#ffcf7c"))
	draw_circle(p + Vector2(s * .34, s * .25), s * .025, Color("#fff1c4"))
	draw_arc(p, s * .38, 0, TAU, 48, Color("#f1d49c", .72), 1.25, true)

func _draw_border() -> void:
	draw_rect(map_rect, Color(0, 0, 0, 0), false, 1.0)

func _draw_ellipse_filled(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(25):
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not map_rect.has_point(event.position):
			return
		var grid_pos: Vector2 = (event.position - map_origin) / cell_size
		var target := Vector2i(floori(grid_pos.x), floori(grid_pos.y))
		var delta := target - state.position
		if abs(delta.x) + abs(delta.y) == 1:
			cell_selected.emit(delta)
		elif target.x >= 0 and target.x < state.MAP_W and target.y >= 0 and target.y < state.MAP_H:
			if bool(state.grid[state._index(target)]["seen"]):
				notice.emit("Переходи по одному участку за раз.")
			else:
				notice.emit("Этот участок пока скрыт туманом.")
		accept_event()
