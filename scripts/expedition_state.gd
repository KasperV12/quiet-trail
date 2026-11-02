extends RefCounted
class_name ExpeditionState

signal changed
signal notice(text: String)
signal finished(won: bool, title: String, body: String, icon: String)
signal encountered(title: String, body: String, first_choice: String, second_choice: String, icon: String)

const MAP_W := 10
const MAP_H := 8
const CAMP := Vector2i(1, 6)
const OBSERVATORY := Vector2i(8, 1)
const MAX_ENERGY := 9
const PACK_LIMIT := 6

var grid: Array[Dictionary] = []
var position := CAMP
var energy := MAX_ENERGY
var wood := 0
var food := 0
var notes := 0
var has_module := false
var elapsed := 0
var discoveries := 0
var ended := false
var won := false
var campfires: Array[Vector2i] = []
var pending_encounter := ""
var journal: Array[String] = []
var rng := RandomNumberGenerator.new()

func _init() -> void:
	reset()

func reset() -> void:
	rng.randomize()
	position = CAMP
	energy = MAX_ENERGY
	wood = 0
	food = 0
	notes = 0
	has_module = false
	elapsed = 0
	discoveries = 0
	ended = false
	won = false
	campfires.clear()
	pending_encounter = ""
	journal.clear()
	grid.clear()
	for y in range(MAP_H):
		for x in range(MAP_W):
			var roll := rng.randf()
			var kind := "forest"
			if roll < 0.17:
				kind = "clearing"
			elif roll < 0.25:
				kind = "stream"
			elif roll < 0.36:
				kind = "ridge"
			elif roll < 0.43:
				kind = "bog"
			grid.append({"kind": kind, "seen": false, "visited": false, "found": ""})
	_set_tile(CAMP, "camp", "")
	_set_tile(OBSERVATORY, "ruin", "module")
	_place_find("wood", ["forest", "clearing"])
	_place_find("wood", ["forest", "clearing"])
	_place_find("food", ["forest", "clearing", "stream"])
	_place_find("food", ["forest", "clearing", "stream"])
	_place_find("notes", ["ridge", "ruin"])
	_place_find("notes", ["ridge", "ruin"])
	_place_find("event:radio", ["forest", "clearing", "stream"])
	_place_find("event:cabin", ["forest", "ridge", "clearing"])
	_tile(CAMP)["seen"] = true
	_tile(CAMP)["visited"] = true
	_reveal()
	_add_log("Лагерь позади. Лес медленно просыпается.")
	changed.emit()

func _index(cell: Vector2i) -> int:
	return cell.y * MAP_W + cell.x

func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < MAP_W and cell.y >= 0 and cell.y < MAP_H

func _tile(cell: Vector2i) -> Dictionary:
	return grid[_index(cell)]

func _set_tile(cell: Vector2i, kind: String, found: String) -> void:
	grid[_index(cell)] = {"kind": kind, "seen": false, "visited": false, "found": found}

func _place_find(found: String, allowed_kinds: Array) -> void:
	var candidates: Array[Vector2i] = []
	for y in range(MAP_H):
		for x in range(MAP_W):
			var cell := Vector2i(x, y)
			if cell == CAMP or cell == OBSERVATORY or not _tile(cell)["found"].is_empty():
				continue
			if allowed_kinds.has(_tile(cell)["kind"]):
				candidates.append(cell)
	if not candidates.is_empty():
		_tile(candidates[rng.randi_range(0, candidates.size() - 1)])["found"] = found

func _reveal(radius: float = 2.45) -> void:
	for y in range(MAP_H):
		for x in range(MAP_W):
			var cell := Vector2i(x, y)
			if position.distance_to(cell) <= radius:
				_tile(cell)["seen"] = true

func pack_used() -> int:
	return wood + food + notes + (2 if has_module else 0)

func day_number() -> int:
	return 1 + int(elapsed / 13)

func clock_text() -> String:
	var total_minutes := 7 * 60 + 20 + elapsed * 28
	var hour := int(total_minutes / 60) % 24
	var minute := total_minutes % 60
	return "%02d:%02d" % [hour, minute]

func current_region() -> String:
	var kind: String = _tile(position)["kind"]
	var labels := {"forest": "Сосновый бор", "clearing": "Солнечная поляна", "stream": "Старая протока", "ruin": "Обсерватория", "camp": "Тихий лагерь", "ridge": "Каменный гребень", "bog": "Мшистая низина"}
	return labels.get(kind, "Северный лес")

func weather_text() -> String:
	if elapsed > 11:
		return "Сумерки сгущаются"
	if elapsed > 6:
		return "Дымка между сосен"
	return "Туман рассеивается"

func move(delta: Vector2i) -> void:
	if ended or pending_encounter != "":
		return
	if abs(delta.x) + abs(delta.y) != 1:
		return
	var target := position + delta
	if not _inside(target):
		return
	if not bool(_tile(target)["seen"]):
		notice.emit("Лес скрывает этот участок — подойди ближе.")
		return
	if energy <= 0:
		notice.emit("Сил больше нет. Отдохни или возвращайся к лагерю.")
		return
	position = target
	energy -= 1
	elapsed += 1
	_tile(position)["visited"] = true
	_reveal()
	if _tile(position)["kind"] == "bog" and rng.randf() < 0.28:
		energy = maxi(0, energy - 1)
		_add_log("Мшистая низина затянула сапог. Потеряна выносливость.")
	_collect()
	if has_module and position == CAMP:
		_finish(true)
		return
	if energy <= 0:
		if position == CAMP:
			_finish(false, "Возвращение без модуля", "Ты добрался до лагеря, но маяк пока молчит. Можно подготовиться и отправиться снова.", "◉")
		else:
			_finish(false, "Лес погрузился в туман", "Силы закончились прежде, чем удалось вернуться. Лагерь пришлёт поисковую группу на рассвете.", "…")
		return
	changed.emit()

func _collect() -> void:
	var item: String = _tile(position)["found"]
	if item == "":
		return
	if item.begins_with("event:"):
		pending_encounter = item.trim_prefix("event:")
		_tile(position)["found"] = ""
		present_pending_encounter()
	elif item == "module" and not has_module:
		has_module = true
		discoveries += 1
		_add_log("В обсерватории найден сигнальный модуль. Он всё ещё тёплый.")
		notice.emit("Сигнальный модуль найден. Теперь — к лагерю.")
	elif item == "wood" and pack_used() < PACK_LIMIT:
		wood += 1
		discoveries += 1
		_tile(position)["found"] = ""
		_add_log("Собраны сухие ветки для костра.")
		notice.emit("Сухие ветки · +1")
	elif item == "food" and pack_used() < PACK_LIMIT:
		food += 1
		discoveries += 1
		_tile(position)["found"] = ""
		_add_log("Найден съедобный лесной гриб.")
		notice.emit("Лесные грибы · +1")
	elif item == "notes" and notes < 2 and pack_used() < PACK_LIMIT:
		notes += 1
		discoveries += 1
		_tile(position)["found"] = ""
		_add_log("В камнях обнаружена страница старого журнала.")
		notice.emit("Страница журнала найдена")

func present_pending_encounter() -> void:
	if pending_encounter == "radio":
		encountered.emit("Голос из старого радио", "Среди помех проступает спокойный голос: «Если слышишь это, северный склон ещё проходим. Ищи огни у воды». Можно задержаться и разобрать координаты или не рисковать зарядом фонаря.", "Настроить частоту · −1 сила", "Идти дальше", "⌁")
	elif pending_encounter == "cabin":
		encountered.emit("Лесной кордон", "Под еловыми лапами прячется старая сторожка. Внутри сухо, но крыша тихо оседает под тяжестью снега. Можно осмотреть ящик с припасами или передохнуть под навесом.", "Обыскать ящик · −1 сила", "Передохнуть · +2 силы", "⌂")

func resolve_encounter(choice: int) -> void:
	if pending_encounter == "":
		return
	var event := pending_encounter
	pending_encounter = ""
	if event == "radio":
		if choice == 0:
			energy = maxi(0, energy - 1)
			elapsed += 1
			_reveal(3.6)
			if notes < 2 and pack_used() < PACK_LIMIT:
				notes += 1
				discoveries += 1
			_add_log("В эфире пойманы координаты северного склона. На полях журнала появилась пометка.")
			notice.emit("Координаты записаны · открыта часть карты")
		else:
			_add_log("Радио стихло, оставив только шорох помех.")
			notice.emit("Ты оставил радио в покое")
	else:
		if choice == 0:
			energy = maxi(0, energy - 1)
			elapsed += 1
			if pack_used() < PACK_LIMIT:
				if rng.randf() < .5:
					food += 1
					_add_log("В сторожке нашлась жестяная коробка с сухим пайком.")
					notice.emit("Найден сухой паёк · +1 еда")
				else:
					wood += 1
					_add_log("В сторожке нашлись сухие щепки для костра.")
					notice.emit("Сухие щепки · +1 ветки")
			else:
				_add_log("Ящик оказался пуст, но под навесом удалось перевести дух.")
				notice.emit("Ящик пуст · находки некуда положить")
		else:
			energy = mini(MAX_ENERGY, energy + 2)
			elapsed += 1
			_add_log("Крыша сторожки укрыла от ветра. Восстановлено 2 ед. сил.")
			notice.emit("Передышка под навесом · +2 силы")
	if energy <= 0 and position != CAMP:
		_finish(false, "Тишина в эфире", "Последних сил не хватило на обратный путь. Утром в лес отправится поисковая группа.", "…")
	else:
		changed.emit()

func eat_food() -> void:
	if ended:
		return
	if food <= 0:
		notice.emit("В сумке нет еды.")
		return
	if energy >= MAX_ENERGY:
		notice.emit("Ты уже полон сил.")
		return
	food -= 1
	energy = mini(MAX_ENERGY, energy + 4)
	elapsed += 1
	_add_log("Перекус у тропы вернул силы. В сумке стало легче.")
	notice.emit("Перекус · +4 выносливости")
	changed.emit()

func build_campfire() -> void:
	if ended:
		return
	if wood < 2:
		notice.emit("Для костра нужны две охапки веток.")
		return
	if _tile(position)["kind"] == "bog":
		notice.emit("Здесь слишком сыро, чтобы разжечь костёр.")
		return
	if position in campfires:
		notice.emit("На этой стоянке костёр уже горел.")
		return
	wood -= 2
	campfires.append(position)
	energy = mini(MAX_ENERGY, energy + 5)
	elapsed += 1
	_add_log("Разведён небольшой костёр. Его свет прогнал сырой туман.")
	notice.emit("Костёр · +5 выносливости")
	changed.emit()

func rest() -> void:
	if ended:
		return
	if energy >= MAX_ENERGY:
		notice.emit("Ты уже полон сил.")
		return
	energy = mini(MAX_ENERGY, energy + 3)
	elapsed += 1
	_add_log("Передышка у старого дерева. Восстановлено 3 ед. сил.")
	notice.emit("Выносливость восстановлена")
	changed.emit()

func return_to_camp() -> void:
	if ended:
		return
	if position == CAMP:
		notice.emit("Ты уже в лагере.")
		return
	var step := _next_known_step(position, CAMP)
	if step == Vector2i(-1, -1):
		notice.emit("Путь домой пока не виден. Исследуй соседний участок.")
		return
	move(step - position)

func _next_known_step(from: Vector2i, goal: Vector2i) -> Vector2i:
	var queue: Array[Vector2i] = [goal]
	var came_from: Dictionary = {goal: goal}
	var dirs := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		if current == from:
			break
		for dir: Vector2i in dirs:
			var next := current + dir
			if _inside(next) and bool(_tile(next)["seen"]) and not came_from.has(next):
				came_from[next] = current
				queue.append(next)
	if not came_from.has(from):
		return Vector2i(-1, -1)
	return came_from[from]

func _finish(victory: bool, custom_title: String = "", custom_body: String = "", custom_icon: String = "") -> void:
	ended = true
	won = victory
	if victory:
		_add_log("Маяк снова загорелся над северным лесом.")
		finished.emit(true, "Маяк снова горит", "Ты вернулся с сигнальным модулем. Вечерний свет снова находит путь сквозь туман.", "✦")
	else:
		finished.emit(false, custom_title, custom_body, custom_icon)
	changed.emit()

func _add_log(line: String) -> void:
	journal.push_front(line)
	while journal.size() > 6:
		journal.pop_back()

func to_dict() -> Dictionary:
	return {"grid": grid, "position": [position.x, position.y], "energy": energy, "wood": wood, "food": food, "notes": notes, "has_module": has_module, "elapsed": elapsed, "discoveries": discoveries, "ended": ended, "won": won, "campfires": campfires.map(func(c): return [c.x, c.y]), "pending_encounter": pending_encounter, "journal": journal}

func from_dict(data: Dictionary) -> void:
	if not data.has("grid") or not data.has("position"):
		reset()
		return
	grid.clear()
	for tile_data: Dictionary in data["grid"]:
		grid.append(tile_data.duplicate(true))
	var p: Array = data["position"]
	position = Vector2i(int(p[0]), int(p[1]))
	energy = int(data.get("energy", MAX_ENERGY))
	wood = int(data.get("wood", 0))
	food = int(data.get("food", 0))
	notes = int(data.get("notes", 0))
	has_module = bool(data.get("has_module", false))
	elapsed = int(data.get("elapsed", 0))
	discoveries = int(data.get("discoveries", 0))
	ended = bool(data.get("ended", false))
	won = bool(data.get("won", false))
	campfires.clear()
	for cell: Array in data.get("campfires", []):
		if cell.size() >= 2:
			campfires.append(Vector2i(int(cell[0]), int(cell[1])))
	pending_encounter = str(data.get("pending_encounter", ""))
	journal.clear()
	for line in data.get("journal", []):
		journal.append(str(line))
	changed.emit()
