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
const CHAPTER_COUNT := 3

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
var campaign_chapter := 0
var fragments := 0
var survivor_found := false
var survivor_rescued := false
var echo_heard := false
var relay_tuned := false
var campaign_records: Array[String] = []
var result_title := ""
var result_body := ""
var result_icon := "✦"
var journal: Array[String] = []
var rng := RandomNumberGenerator.new()

func _init() -> void:
	reset()

func reset() -> void:
	campaign_chapter = 0
	campaign_records.clear()
	echo_heard = false
	relay_tuned = false
	_reset_expedition()

func retry_expedition() -> void:
	_reset_expedition()

func next_expedition() -> void:
	_reset_expedition()

func _reset_expedition() -> void:
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
	result_title = ""
	result_body = ""
	result_icon = "✦"
	fragments = 0
	survivor_found = false
	survivor_rescued = false
	campfires.clear()
	pending_encounter = ""
	journal.clear()
	grid.clear()
	for y in range(MAP_H):
		for x in range(MAP_W):
			var cell := Vector2i(x, y)
			var kind := _generate_terrain(cell, rng.randf())
			grid.append({"kind": kind, "seen": false, "visited": false, "found": ""})
	_set_tile(CAMP, "camp", "")
	_set_tile(OBSERVATORY, "ruin", "module" if campaign_chapter == 0 else "")
	_place_find("wood", ["forest", "clearing"])
	_place_find("wood", ["forest", "clearing"])
	_place_find("food", ["forest", "clearing", "stream"])
	_place_find("food", ["forest", "clearing", "stream"])
	_place_find("notes", ["ridge", "ruin"])
	_place_find("notes", ["ridge", "ruin"])
	_place_find("event:radio", ["forest", "clearing", "stream"])
	_place_find("event:cabin", ["forest", "ridge", "clearing"])
	if campaign_chapter == 0:
		_place_find("event:echo", ["forest", "clearing", "stream"])
	elif campaign_chapter == 1:
		_place_find("event:relay", ["ridge", "forest", "clearing"])
		for i in range(3):
			_place_find("fragment", ["forest", "clearing", "stream", "ridge"])
	elif campaign_chapter == 2:
		_place_find("event:survivor", ["forest", "clearing", "stream", "ridge"])
	_tile(CAMP)["seen"] = true
	_tile(CAMP)["visited"] = true
	_reveal()
	var chapter_opening := [
		"Утром в лес пришёл сигнал с маяка. Найди пропавший модуль и вернись в лагерь.",
		"Маяк снова горит, но его ритм не совпадает с записями команды. " + ("В эфире уже звучал чей-то голос; теперь ответь на него. " if echo_heard else "В помехах чудится чей-то голос. ") + "Собери три фрагмента сигнала.",
		("Сохранённый ритм маяка ведёт на северный склон. " if relay_tuned else "Маяк молчит; остаются записанные координаты. ") + "По рации отвечает пропавший следопыт. Найди его и возвращайся вместе."
	]
	_add_log(chapter_opening[mini(campaign_chapter, chapter_opening.size() - 1)])
	for record: String in campaign_records:
		journal.append("Память: " + record)
	while journal.size() > 6:
		journal.pop_back()
	changed.emit()

func _index(cell: Vector2i) -> int:
	return cell.y * MAP_W + cell.x

func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < MAP_W and cell.y >= 0 and cell.y < MAP_H

func _tile(cell: Vector2i) -> Dictionary:
	return grid[_index(cell)]

func _set_tile(cell: Vector2i, kind: String, found: String) -> void:
	grid[_index(cell)] = {"kind": kind, "seen": false, "visited": false, "found": found}

func _generate_terrain(cell: Vector2i, roll: float) -> String:
	var northness := 1.0 - float(cell.y) / float(MAP_H - 1)
	if campaign_chapter == 0:
		if roll < 0.17: return "clearing"
		if roll < 0.25: return "stream"
		if roll < 0.36: return "ridge"
		if roll < 0.43: return "bog"
		return "forest"
	if campaign_chapter == 1:
		if northness > 0.48 and roll < 0.58: return "ridge"
		if roll < 0.13: return "stream"
		if roll < 0.21: return "bog"
		if roll < 0.38: return "clearing"
		return "forest"
	if northness > 0.38 and roll < 0.66: return "ridge"
	if roll < 0.25: return "bog"
	if roll < 0.36: return "stream"
	if roll < 0.47: return "clearing"
	return "forest"

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

func objective_text() -> String:
	match campaign_chapter:
		0:
			return "Найти сигнальный модуль" if not has_module else "Вернуться в лагерь с модулем"
		1:
			return "Собрать фрагменты сигнала · %d/3" % fragments if fragments < 3 else "Вернуться в лагерь с записями"
		_:
			if not survivor_found:
				return "Найти пропавшего следопыта"
			return "Вернуться в лагерь с человеком" if survivor_rescued else "Вернуться в лагерь за помощью"

func _objective_complete() -> bool:
	match campaign_chapter:
		0: return has_module
		1: return fragments >= 3
		_: return survivor_found

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
	if campaign_chapter == 1:
		if elapsed > 8: return "Порывы с перевала"
		if elapsed > 4: return "Ветер набирает силу"
		return "Холодный воздух с севера"
	if campaign_chapter >= 2:
		if elapsed > 8: return "Белая мгла"
		if elapsed > 4: return "Снег режет глаза"
		return "Снег идёт стеной"
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
	var terrain: String = _tile(position)["kind"]
	var hazard_chance := 0.0
	if terrain == "bog":
		hazard_chance = 0.28 if campaign_chapter == 0 else 0.38
	elif terrain == "ridge" and campaign_chapter >= 1:
		hazard_chance = 0.20 if campaign_chapter == 1 else 0.30
	if rng.randf() < hazard_chance:
		energy = maxi(0, energy - 1)
		var hazard_lines := {"bog": "Мшистая низина затянула сапог. Потеряна выносливость.", "ridge": "Порыв ветра сбил дыхание на открытом гребне. Потеряна выносливость."}
		_add_log(hazard_lines.get(terrain, "Путь отнял силы."))
	_collect()
	if position == CAMP and _objective_complete():
		_finish(true)
		return
	if energy <= 0:
		if position == CAMP:
			var camp_failure_titles := ["Возвращение без модуля", "Сигнал не восстановлен", "Поисковая группа не найдена"]
			var camp_failure_bodies := ["Ты добрался до лагеря, но маяк пока молчит. Можно подготовиться и отправиться снова.", "Ты вернулся, не собрав нужные фрагменты. Перед следующей попыткой можно подготовить припасы.", "Ты вернулся за помощью, но сил и времени на поиски не хватило. Следопыт всё ещё в горах."]
			_finish(false, camp_failure_titles[campaign_chapter], camp_failure_bodies[campaign_chapter], "◉")
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
	elif item == "fragment" and fragments < 3 and pack_used() < PACK_LIMIT:
		fragments += 1
		discoveries += 1
		_tile(position)["found"] = ""
		_add_log("В мху найден осколок сигнального кристалла.")
		notice.emit("Фрагмент сигнала · %d / 3" % fragments)
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
	match pending_encounter:
		"radio":
			encountered.emit("Голос из старого радио", "Среди помех проступает спокойный голос: «Если слышишь это, северный склон ещё проходим. Ищи огни у воды». Можно задержаться и разобрать координаты или не рисковать зарядом фонаря.", "Настроить частоту · −1 сила", "Идти дальше", "⌁")
		"cabin":
			encountered.emit("Лесной кордон", "Под еловыми лапами прячется старая сторожка. Внутри сухо, но крыша тихо оседает под тяжестью снега. Можно осмотреть ящик с припасами или передохнуть под навесом.", "Обыскать ящик · −1 сила", "Передохнуть · +2 силы", "⌂")
		"echo":
			encountered.emit("Эхо под кронами", "На старом полевом телефоне вдруг щёлкает линия. Женский голос произносит: «Не гаси огонь. Мы увидим его с перевала». Потом шёпот повторяет позывной маяка. Можно записать его или оставить слова лесу.", "Записать позывной · −1 сила", "Не задерживаться", "⌁")
		"relay":
			var relay_text := "На гребне стоит ветровое реле маяка. " + ("Позывной с того старого телефона совпадает с ритмом его искр." if echo_heard else "Внутри корпуса застрял тонкий осколок сигнального стекла.") + " Его можно настроить для поисковой группы или разобрать на детали."
			var tune_choice := "Сохранить ритм · страница" if notes > 0 else "Сохранить ритм · −1 сила"
			var dismantle_choice := "Разобрать корпус · +ветки" if pack_used() < PACK_LIMIT else "Разобрать корпус"
			encountered.emit("Ветровое реле", relay_text, tune_choice, dismantle_choice, "⌁")
		"survivor":
			var survivor_text := "Под скалой сидит следопыт в промокшем плаще. " + ("Услышав ровный позывной, он шепчет: «Это сигнал моей сестры. Она осталась у маяка» — и впервые за дни отвечает на имя." if echo_heard and relay_tuned else "Он знает короткий путь к лагерю, но едва держится на ногах.") + " Можно отдать ему еду или оставить координаты и отправиться за помощью одному."
			encountered.emit("Человек у старого маяка", survivor_text, "Поделиться пайком · спасти его", "Оставить координаты · уйти одному", "⌖")

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
	elif event == "cabin":
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
	elif event == "relay":
		elapsed += 1
		if choice == 0:
			relay_tuned = true
			if notes > 0:
				notes -= 1
			else:
				energy = maxi(0, energy - 1)
			_reveal(3.6)
			_add_log("Ветровое реле настроено на ровный позывной. Его ритм можно будет узнать издалека.")
			notice.emit("Реле настроено · сигнал стал ровнее")
		else:
			relay_tuned = false
			var can_take_scrap := pack_used() < PACK_LIMIT
			if can_take_scrap:
				wood += 1
			if can_take_scrap:
				_add_log("Ты разобрал реле. Ветер унёс позывной, зато в сумке появилась сухая обмотка.")
				notice.emit("Реле разобрано · найден материал для костра")
			else:
				_add_log("Ты разобрал реле, но сумка полна. Ветер унёс позывной.")
				notice.emit("Реле разобрано, но сумка полна")
	elif event == "echo":
		if choice == 0:
			echo_heard = true
			energy = maxi(0, energy - 1)
			elapsed += 1
			_reveal(3.6)
			_add_log("На старом телефоне пойман позывной: «Не гаси огонь». Ты записал его в журнал.")
			notice.emit("Позывной записан · открыта часть карты")
		else:
			_add_log("Ты прошёл мимо телефона. Голос оборвался, не успев назвать позывной.")
			notice.emit("Линия умолкла")
	else:
		survivor_found = true
		elapsed += 1
		_reveal(3.6)
		if choice == 0:
			survivor_rescued = true
			if food > 0:
				food -= 1
			else:
				energy = maxi(0, energy - 1)
			_add_log("Следопыт принял последний паёк. Вы двинулись к лагерю вместе.")
			notice.emit("Следопыт спасён · возвращайтесь к лагерю")
		else:
			survivor_rescued = false
			_add_log("Координаты следопыта записаны. Ты отправился за поисковой группой.")
			notice.emit("Координаты переданы лагерю · возвращайся за помощью")
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
		var completed := campaign_chapter
		var summaries := ["Ты принёс сигнальный модуль. Маяк зажёгся над северным лесом.", "Три фрагмента собраны. В повторяющемся сигнале слышно имя пропавшего следопыта.", "Следопыт спасён и вернулся в лагерь." if survivor_rescued else "Ты вернулся за поисковой группой; координаты следопыта теперь у спасателей."]
		campaign_records.push_front(summaries[mini(completed, summaries.size() - 1)])
		if completed == 0 and echo_heard:
			campaign_records.push_front("Ты сохранил позывной неизвестного голоса.")
		elif completed == 1 and relay_tuned:
			campaign_records.push_front("Ты оставил ветровое реле работать на старой частоте.")
		campaign_chapter = mini(campaign_chapter + 1, CHAPTER_COUNT)
		if campaign_chapter >= CHAPTER_COUNT:
			result_title = "Вместе сквозь туман" if survivor_rescued else "Сигнал найден"
			if survivor_rescued:
				result_body = "Следопыт вернулся домой, а маяк снова ведёт путников через перевал. " + ("На старой частоте он ещё раз слышит тот тихий голос: это была его сестра, звавшая его домой." if echo_heard and relay_tuned else "В рации впервые за много недель слышен смех.")
			else:
				result_body = "Поисковая группа добралась до указанных координат. " + ("Сохранённый позывной помог ей пройти перевал до рассвета." if relay_tuned else "Маяк горит, и теперь никто не потеряется в северном лесу.")
			result_icon = "✦"
		else:
			var chapter_titles := ["Сигнал найден", "Три осколка", "Глава завершена"]
			var chapter_bodies := ["Маяк снова горит. Но из темноты приходит новый сигнал.", "Фрагменты складываются в координаты на северном склоне. Кто-то всё ещё там.", "Ты вернулся в лагерь с новостями. История продолжается."]
			result_title = chapter_titles[completed]
			result_body = chapter_bodies[completed]
			result_icon = "✦"
		finished.emit(true, result_title, result_body, result_icon)
	else:
		result_title = custom_title
		result_body = custom_body
		result_icon = custom_icon
		finished.emit(false, custom_title, custom_body, custom_icon)
	changed.emit()

func _add_log(line: String) -> void:
	journal.push_front(line)
	while journal.size() > 6:
		journal.pop_back()

func to_dict() -> Dictionary:
	return {"grid": grid, "position": [position.x, position.y], "energy": energy, "wood": wood, "food": food, "notes": notes, "has_module": has_module, "elapsed": elapsed, "discoveries": discoveries, "ended": ended, "won": won, "campfires": campfires.map(func(c): return [c.x, c.y]), "pending_encounter": pending_encounter, "campaign_chapter": campaign_chapter, "fragments": fragments, "survivor_found": survivor_found, "survivor_rescued": survivor_rescued, "echo_heard": echo_heard, "relay_tuned": relay_tuned, "campaign_records": campaign_records, "result_title": result_title, "result_body": result_body, "result_icon": result_icon, "journal": journal}

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
	campaign_chapter = clampi(int(data.get("campaign_chapter", 0)), 0, CHAPTER_COUNT)
	fragments = int(data.get("fragments", 0))
	survivor_found = bool(data.get("survivor_found", false))
	survivor_rescued = bool(data.get("survivor_rescued", false))
	echo_heard = bool(data.get("echo_heard", false))
	relay_tuned = bool(data.get("relay_tuned", false))
	campaign_records.clear()
	for record in data.get("campaign_records", []):
		campaign_records.append(str(record))
	result_title = str(data.get("result_title", ""))
	result_body = str(data.get("result_body", ""))
	result_icon = str(data.get("result_icon", "✦"))
	journal.clear()
	for line in data.get("journal", []):
		journal.append(str(line))
	changed.emit()
