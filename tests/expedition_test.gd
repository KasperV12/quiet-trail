extends SceneTree

const State = preload("res://scripts/expedition_state.gd")
var failures := 0

func _initialize() -> void:
	_test_authored_journal_pages()
	_test_signal_mirror_rescue_branch()
	if failures > 0:
		push_error("%d expedition regression check(s) failed" % failures)
		quit(1)
		return
	print("PASS: expedition journal and signal mirror campaign branches")
	quit(0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _test_authored_journal_pages() -> void:
	var excerpts := {
		"page:0:1": "Из журнала у обсерватории: «Маяк ответил трижды. Ветер дул с юга, а голос шёл с севера»",
		"page:0:2": "На полях старой карты: «Не гаси огонь. На той стороне перевала его примут за наш ответ»",
		"page:1:1": "Запись полевой группы: «Кристалл не разбит — он повторяет голос. Три вспышки складываются в координаты»",
		"page:1:2": "Почерк торопливый: «Оставить реле на старой частоте. Если она услышит позывной, значит, добралась до станции»",
		"page:2:1": "На карте поисков: «Сигнальное зеркало видно с уступа только в просвет. Крепление выше тропы»",
		"page:2:2": "Последняя запись: «Если найдёте следопыта — не спрашивайте, почему он ушёл. Просто скажите: маяк ещё горит»"
	}
	for page_id in excerpts:
		var state = State.new()
		state.campaign_chapter = int(str(page_id).split(":")[1])
		state.next_expedition()
		var page_cell := Vector2i(-1, -1)
		for y in range(state.MAP_H):
			for x in range(state.MAP_W):
				var cell := Vector2i(x, y)
				if state._tile(cell)["found"] == page_id:
					page_cell = cell
		_expect(page_cell != Vector2i(-1, -1), "authored page was not placed: " + str(page_id))
		state.position = page_cell
		state._collect()
		_expect(state.notes == 1, "story page must remain a usable journal resource")
		_expect(state.discoveries == 1, "story page should count as a discovery")
		_expect(state.journal[0] == excerpts[page_id], "incorrect excerpt for " + str(page_id))
		var restored = State.new()
		restored.from_dict(state.to_dict())
		_expect(restored.notes == 1, "journal resource was lost after save/load")
		_expect(restored.journal[0] == state.journal[0], "story excerpt was lost after save/load")
	var state = State.new()
	var restored = State.new()
	restored.from_dict(state.to_dict())
	var legacy_cell := Vector2i(3, 6)
	restored.position = legacy_cell
	restored._tile(legacy_cell)["found"] = "notes"
	restored._collect()
	_expect(restored.notes == 1, "legacy generic journal resource should still collect")
	_expect(restored.journal[0].contains("старого журнала"), "legacy generic page should retain its fallback text")

func _test_signal_mirror_rescue_branch() -> void:
	var state = State.new()
	state.campaign_chapter = 2
	state.next_expedition()
	var flare_cell := Vector2i(-1, -1)
	for y in range(state.MAP_H):
		for x in range(state.MAP_W):
			var cell := Vector2i(x, y)
			if state._tile(cell)["found"] == "event:flare":
				flare_cell = cell
	_expect(flare_cell != Vector2i(-1, -1), "chapter three signal mirror was not placed")
	state.position = flare_cell
	state.energy = 5
	state.pending_encounter = "flare"
	state.resolve_encounter(0)
	_expect(state.flare_lit and state.energy == 4, "lighting the mirror signal should cost one energy")
	var restored = State.new()
	restored.from_dict(state.to_dict())
	_expect(restored.flare_lit, "signal mirror choice must persist in a save")
	var dialogue: Dictionary = {}
	restored.encountered.connect(func(_title: String, body: String, _first: String, _second: String, _icon: String): dialogue["body"] = body)
	restored.pending_encounter = "survivor"
	restored.present_pending_encounter()
	_expect(str(dialogue.get("body", "")).contains("сигнального зеркала"), "survivor dialogue should acknowledge the signal")
	restored.food = 0
	restored.energy = 4
	restored.resolve_encounter(0)
	_expect(restored.survivor_rescued, "signal-assisted rescue choice should save the survivor")
	_expect(restored.food == 0 and restored.energy == 4, "signal-assisted rescue should not consume food or energy")
	restored.position = restored.CAMP
	restored._finish(true)
	_expect(restored.result_body.contains("Сигнальное зеркало помогло"), "finale should acknowledge the chosen signal")
	var old_save: Dictionary = state.to_dict()
	old_save.erase("flare_lit")
	var legacy = State.new()
	legacy.from_dict(old_save)
	_expect(not legacy.flare_lit, "old saves should default to an unlit signal")
	var retry = State.new()
	retry.campaign_chapter = 2
	retry.flare_lit = true
	retry.retry_expedition()
	_expect(not retry.flare_lit, "restarting a chapter should clear its previous signal")
