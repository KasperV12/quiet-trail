extends Control

const ExpeditionStateScript = preload("res://scripts/expedition_state.gd")
const ExpeditionMapScript = preload("res://scripts/world_view.gd")
const SAVE_PATH := "user://lantern_trail_save.json"
const SETTINGS_PATH := "user://lantern_trail_settings.json"

var state: ExpeditionState
var map_view
var overlay: ColorRect
var toast_timer: Timer
var notice_label: Label
var time_label: Label
var weather_label: Label
var region_label: Label
var chapter_label: Label
var chapter_hint_label: Label
var objective_label: Label
var energy_value: Label
var energy_bar: ProgressBar
var pack_value: Label
var pack_bar: ProgressBar
var resource_values: Dictionary = {}
var discoveries_label: Label
var fragment_value: Label
var survivor_value: Label
var journal_label: Label
var rest_button: Button
var return_button: Button
var food_button: Button
var fire_button: Button
var sound_button: Button
var ambience_player: AudioStreamPlayer
var audio_enabled := true
var ambience_volume := 0.65
var reduced_motion := false
var closing := false
var card_style: StyleBoxFlat
var main_font: Font

func _ready() -> void:
	state = ExpeditionStateScript.new()
	main_font = ThemeDB.fallback_font
	_build_ui()
	state.changed.connect(_on_state_changed)
	state.notice.connect(_show_notice)
	state.finished.connect(_on_finished)
	state.encountered.connect(_on_encountered)
	_update_ui()
	_load_audio_setting()
	if DisplayServer.get_name() != "headless":
		_start_ambience()
	_show_title_screen()
	get_viewport().size_changed.connect(_on_viewport_resized)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not closing:
		closing = true
		get_tree().set_auto_accept_quit(false)
		if is_instance_valid(ambience_player):
			ambience_player.stop()
		await get_tree().create_timer(0.12).timeout
		get_tree().quit()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var theme := Theme.new()
	theme.default_font = main_font
	theme.default_font_size = 14
	set_theme(theme)
	card_style = StyleBoxFlat.new()
	card_style.bg_color = Color("#1b2621")
	card_style.border_color = Color(1, 1, 1, .085)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(16)
	card_style.content_margin_left = 17
	card_style.content_margin_right = 17
	card_style.content_margin_top = 14
	card_style.content_margin_bottom = 14
	var page := MarginContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("margin_left", 25)
	page.add_theme_constant_override("margin_right", 25)
	page.add_theme_constant_override("margin_top", 18)
	page.add_theme_constant_override("margin_bottom", 16)
	add_child(page)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 15)
	page.add_child(column)
	_build_header(column)
	_build_hero(column)
	_build_body(column)
	_build_footer(column)
	_build_overlay()
	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.wait_time = 2.2
	toast_timer.timeout.connect(func(): notice_label.visible = false)
	add_child(toast_timer)

func _build_header(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 40
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var emblem := Label.new()
	emblem.text = "✦"
	emblem.add_theme_font_size_override("font_size", 25)
	emblem.add_theme_color_override("font_color", Color("#edbd73"))
	row.add_child(emblem)
	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", -3)
	row.add_child(brand)
	var game_name := _label("ТИХАЯ ТРОПА", 13, Color("#ecede4"), true)
	game_name.add_theme_constant_override("outline_size", 0)
	brand.add_child(game_name)
	brand.add_child(_label("ДНЕВНИК МАЛОЙ ЭКСПЕДИЦИИ", 9, Color("#89978a")))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	time_label = _label("День 1 · 07:20", 12, Color("#bec8bb"))
	row.add_child(time_label)
	var pause := _small_button("Ⅱ  ПАУЗА")
	pause.pressed.connect(_show_pause)
	sound_button = _small_button("♫ ЗВУК")
	sound_button.pressed.connect(_toggle_audio)
	row.add_child(sound_button)
	row.add_child(pause)

func _build_hero(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	var title_col := VBoxContainer.new()
	title_col.add_theme_constant_override("separation", 3)
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_col)
	chapter_label = _label("ГЛАВА I  ·  СИГНАЛ", 10, Color("#dfb777"), true)
	title_col.add_child(chapter_label)
	title_col.add_child(_label("Где молчит маяк", 27, Color("#edf0e8"), true))
	chapter_hint_label = _label("", 12, Color("#a7b2a5"))
	title_col.add_child(chapter_hint_label)
	var goal := _panel()
	goal.custom_minimum_size = Vector2(250, 0)
	row.add_child(goal)
	var goal_col := VBoxContainer.new()
	goal_col.add_theme_constant_override("separation", 5)
	goal.add_child(goal_col)
	goal_col.add_child(_label("ЦЕЛЬ ВЫЛАЗКИ", 9, Color("#d1a766"), true))
	objective_label = _label("Найти модуль в старой обсерватории", 12, Color("#e3e8df"), true)
	goal_col.add_child(objective_label)

func _build_body(parent: VBoxContainer) -> void:
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	parent.add_child(body)
	var map_panel := _panel()
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.add_theme_stylebox_override("panel", _panel_style(Color("#26342c"), 18))
	body.add_child(map_panel)
	var map_margin := MarginContainer.new()
	map_margin.add_theme_constant_override("margin_left", 12)
	map_margin.add_theme_constant_override("margin_right", 12)
	map_margin.add_theme_constant_override("margin_top", 12)
	map_margin.add_theme_constant_override("margin_bottom", 12)
	map_panel.add_child(map_margin)
	var map_column := VBoxContainer.new()
	map_column.add_theme_constant_override("separation", 9)
	map_margin.add_child(map_column)
	var map_head := HBoxContainer.new()
	map_column.add_child(map_head)
	weather_label = _label("☁  Туман рассеивается", 11, Color("#e2c987"), true)
	weather_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_head.add_child(weather_label)
	region_label = _label("Лесная кромка", 10, Color("#c3cdbf"))
	map_head.add_child(region_label)
	map_view = ExpeditionMapScript.new()
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.set("state", state)
	map_view.cell_selected.connect(_on_cell_selected)
	map_view.notice.connect(_show_notice)
	map_column.add_child(map_view)
	var map_help := _label("КЛИКНИ ПО СОСЕДНЕМУ УЧАСТКУ   ·   WASD / СТРЕЛКИ — ДВИЖЕНИЕ", 9, Color("#99a694"))
	map_column.add_child(map_help)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 292
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 10)
	body.add_child(side)
	_build_traveler_card(side)
	_build_inventory_card(side)
	_build_actions_card(side)
	_build_journal_card(side)

func _build_traveler_card(parent: VBoxContainer) -> void:
	var panel := _panel()
	parent.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 9)
	panel.add_child(col)
	var title_row := HBoxContainer.new()
	col.add_child(title_row)
	title_row.add_child(_label("ПУТНИК", 10, Color("#a9b5a8"), true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)
	title_row.add_child(_label("●  В ПУТИ", 9, Color("#9ab9a0"), true))
	var portrait := Control.new()
	portrait.custom_minimum_size.y = 63
	portrait.draw.connect(_draw_portrait.bind(portrait))
	col.add_child(portrait)
	var name_row := HBoxContainer.new()
	col.add_child(name_row)
	name_row.add_child(_label("Элиан Вейл", 13, Color("#e9eee4"), true))
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(space)
	name_row.add_child(_label("следопыт · ур. 1", 9, Color("#9faa9d")))
	energy_value = _label("9 / 9", 10, Color("#e0e5dd"), true)
	energy_bar = _progress_bar(Color("#dfad69"))
	_add_meter(col, "ВЫНОСЛИВОСТЬ", energy_value, energy_bar)
	pack_value = _label("0 / 6", 10, Color("#e0e5dd"), true)
	pack_bar = _progress_bar(Color("#94b69b"))
	_add_meter(col, "МЕСТО В СУМКЕ", pack_value, pack_bar)

func _add_meter(parent: VBoxContainer, caption: String, value: Label, bar: ProgressBar) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	row.add_child(_label(caption, 9, Color("#9eaa9d"), true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(value)
	parent.add_child(bar)

func _build_inventory_card(parent: VBoxContainer) -> void:
	var panel := _panel()
	parent.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	head.add_child(_label("СНАРЯЖЕНИЕ", 10, Color("#a9b5a8"), true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	discoveries_label = _label("0 находок", 9, Color("#dfba7c"))
	head.add_child(discoveries_label)
	resource_values["wood"] = _inventory_row(col, "✣", "Сухие ветки")
	resource_values["food"] = _inventory_row(col, "❋", "Лесные грибы")
	resource_values["notes"] = _inventory_row(col, "▤", "Страницы журнала")
	resource_values["module"] = _inventory_row(col, "✦", "Сигнальный модуль")
	fragment_value = _inventory_row(col, "◈", "Осколки сигнала")
	survivor_value = _inventory_row(col, "⌖", "Следопыт")

func _inventory_row(parent: VBoxContainer, icon: String, label_text: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	parent.add_child(row)
	var mark := _label(icon, 13, Color("#dbbf8b"), true)
	mark.custom_minimum_size.x = 22
	row.add_child(mark)
	var name := _label(label_text, 10, Color("#c5cec3"))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	var value := _label("0", 11, Color("#e7eadf"), true)
	row.add_child(value)
	return value

func _build_actions_card(parent: VBoxContainer) -> void:
	var panel := _panel()
	parent.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	panel.add_child(col)
	col.add_child(_label("ДЕЙСТВИЯ", 10, Color("#a9b5a8"), true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	col.add_child(row)
	rest_button = _action_button("Передохнуть", "+3 силы  ·  R")
	rest_button.pressed.connect(func(): state.rest())
	row.add_child(rest_button)
	return_button = _action_button("К лагерю", "короткий путь  ·  B")
	return_button.pressed.connect(func(): state.return_to_camp())
	row.add_child(return_button)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 7)
	col.add_child(row2)
	food_button = _action_button("Перекусить", "+4 силы · F")
	food_button.pressed.connect(func(): state.eat_food())
	row2.add_child(food_button)
	fire_button = _action_button("Развести костёр", "2 ветки · C")
	fire_button.pressed.connect(func(): state.build_campfire())
	row2.add_child(fire_button)

func _build_journal_card(parent: VBoxContainer) -> void:
	var panel := _panel()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	panel.add_child(col)
	var row := HBoxContainer.new()
	col.add_child(row)
	row.add_child(_label("ПОЛЕВЫЕ ЗАПИСИ", 10, Color("#a9b5a8"), true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_label("СЕГОДНЯ", 8, Color("#dfba7c"), true))
	journal_label = _label("", 9, Color("#b6c0b4"))
	journal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	journal_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(journal_label)

func _build_footer(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	row.add_child(_label("ОДИНОЧНАЯ ЭКСПЕДИЦИЯ", 8, Color("#718074")))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_label("КАМПАНИЯ · ТРИ ВЫЛАЗКИ", 8, Color("#718074")))

func _build_overlay() -> void:
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color("#0b120fd6")
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)

func _show_title_screen() -> void:
	var has_save := FileAccess.file_exists(SAVE_PATH)
	_show_dialog("ТИХАЯ ТРОПА", "Где молчит маяк", "Тихая северная экспедиция. Исследуй лес, слушай его и найди путь обратно.", "НАЧАТЬ ВЫЛАЗКУ", func():
		state.reset()
		_start_game(), "ПРОДОЛЖИТЬ", func():
			_load_game()
			_start_game(), has_save, "✦")

func _show_pause() -> void:
	if overlay.visible:
		return
	_save_game()
	_show_pause_dialog()

func _show_pause_dialog() -> void:
	_show_dialog("ПАУЗА", "Лес подождёт", "Прогресс сохранён автоматически.", "ПРОДОЛЖИТЬ", func(): overlay.visible = false, "НАСТРОЙКИ", func(): _show_settings(true), true, "Ⅱ")

func _show_finished(won: bool, title: String, body: String, icon: String) -> void:
	_save_game()
	if won and state.campaign_chapter >= state.CHAPTER_COUNT:
		_show_dialog("ИСТОРИЯ ЗАВЕРШЕНА", title, body, "НОВАЯ ИСТОРИЯ", func():
			state.reset()
			_start_game(), "В ГЛАВНОЕ МЕНЮ", func(): _show_title_screen(), true, icon)
	elif won:
		_show_dialog("ГЛАВА %d / %d" % [state.campaign_chapter, state.CHAPTER_COUNT], title, body, "ПРОДОЛЖИТЬ ИСТОРИЮ", func():
			state.next_expedition()
			_start_game(), "В ГЛАВНОЕ МЕНЮ", func(): _show_title_screen(), true, icon)
	else:
		_show_dialog("ВЫЛАЗКА ПРЕРВАНА", title, body, "ПОВТОРИТЬ ГЛАВУ", func():
			state.retry_expedition()
			_start_game(), "В ГЛАВНОЕ МЕНЮ", func(): _show_title_screen(), true, icon)

func _on_encountered(title: String, body: String, first_choice: String, second_choice: String, icon: String) -> void:
	_show_dialog("СЛУЧАЙ В ЛЕСУ", title, body, first_choice, func():
		overlay.visible = false
		state.resolve_encounter(0), second_choice, func():
		overlay.visible = false
		state.resolve_encounter(1), true, icon)

func _show_dialog(kicker: String, title: String, body_text: String, primary_text: String, primary_action: Callable, secondary_text: String = "", secondary_action: Callable = Callable(), show_secondary: bool = false, icon: String = "✦") -> void:
	for child in overlay.get_children():
		child.queue_free()
	overlay.visible = true
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(490, 0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#1b2821"), 22))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	var sigil := _label(icon, 31, Color("#e8c17f"), true)
	sigil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sigil)
	var kicker_label := _label(kicker, 9, Color("#dbb472"), true)
	kicker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(kicker_label)
	var title_label := _label(title, 25, Color("#f0f1e8"), true)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title_label)
	var desc := _label(body_text, 12, Color("#aab7aa"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(desc)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 9)
	col.add_child(actions)
	var primary := _dialog_button(primary_text, true)
	primary.pressed.connect(primary_action)
	actions.add_child(primary)
	if show_secondary and secondary_text != "":
		var secondary := _dialog_button(secondary_text, false)
		secondary.pressed.connect(secondary_action)
		actions.add_child(secondary)
	if kicker == "ТИХАЯ ТРОПА":
		var options := _small_button("⚙  НАСТРОЙКИ")
		options.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		options.pressed.connect(func(): _show_settings(false))
		col.add_child(options)
		var controls := _label("WASD / СТРЕЛКИ — идти     R — отдых     F — еда     C — костёр     B — лагерь", 9, Color("#89988b"))
		controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(controls)

func _start_game() -> void:
	overlay.visible = false
	_update_ui()
	map_view.grab_focus()
	if state.ended:
		_show_finished(state.won, state.result_title, state.result_body, state.result_icon)
		return
	_save_game()
	if state.pending_encounter != "":
		state.present_pending_encounter()

func _save_game() -> void:
	if state == null:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(state.to_dict()))

func _start_ambience() -> void:
	var stream := load("res://assets/audio/Forest_Ambience.mp3") as AudioStreamMP3
	if stream == null:
		return
	stream.loop = true
	ambience_player = AudioStreamPlayer.new()
	ambience_player.stream = stream
	ambience_player.volume_db = -13.0 if audio_enabled else -80.0
	add_child(ambience_player)
	ambience_player.play()

func _load_audio_setting() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file != null:
			var settings: Variant = JSON.parse_string(file.get_as_text())
			if settings is Dictionary:
				audio_enabled = bool(settings.get("ambience", true))
				ambience_volume = clampf(float(settings.get("ambience_volume", 0.65)), 0.0, 1.0)
				reduced_motion = bool(settings.get("reduced_motion", false))
	if is_instance_valid(map_view):
		map_view.reduced_motion = reduced_motion
	_apply_audio_setting()

func _apply_audio_setting() -> void:
	if is_instance_valid(ambience_player):
		ambience_player.volume_db = linear_to_db(lerpf(0.0, 0.42, ambience_volume)) if audio_enabled and ambience_volume > 0.0 else -80.0
	if is_instance_valid(sound_button):
		sound_button.text = "♫ ЗВУК" if audio_enabled else "♫ ВЫКЛ"

func _toggle_audio() -> void:
	audio_enabled = not audio_enabled
	_save_settings()
	_apply_audio_setting()

func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"ambience": audio_enabled, "ambience_volume": ambience_volume, "reduced_motion": reduced_motion}))

func _show_settings(from_pause: bool) -> void:
	for child in overlay.get_children():
		child.queue_free()
	overlay.visible = true
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#1b2821"), 22))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var icon := _label("⚙", 30, Color("#e8c17f"), true)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(icon)
	var heading := _label("НАСТРОЙКИ", 18, Color("#f0f1e8"), true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(heading)
	col.add_child(_label("ГРОМКОСТЬ ЛЕСА", 9, Color("#d1a766"), true))
	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 10)
	col.add_child(volume_row)
	var volume_slider := HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	volume_slider.value = ambience_volume * 100.0
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_row.add_child(volume_slider)
	var volume_value := _label("%d%%" % roundi(ambience_volume * 100.0), 10, Color("#e0e7dc"), true)
	volume_value.custom_minimum_size.x = 40
	volume_row.add_child(volume_value)
	volume_slider.value_changed.connect(func(value: float):
		ambience_volume = value / 100.0
		volume_value.text = "%d%%" % roundi(value)
		_apply_audio_setting()
		_save_settings())
	var motion := CheckButton.new()
	motion.text = "Снизить движение на карте"
	motion.button_pressed = reduced_motion
	motion.add_theme_font_size_override("font_size", 11)
	motion.add_theme_color_override("font_color", Color("#dce4d8"))
	col.add_child(motion)
	var motion_hint := _label("Убирает покачивание деталей и плавный переход путника.", 10, Color("#9eaa9d"))
	motion_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(motion_hint)
	motion.toggled.connect(func(enabled: bool):
		reduced_motion = enabled
		map_view.reduced_motion = enabled
		_save_settings()
		map_view.queue_redraw())
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 9)
	col.add_child(buttons)
	var back := _dialog_button("НАЗАД", true)
	back.pressed.connect(func(): _show_pause_dialog() if from_pause else _show_title_screen())
	buttons.add_child(back)
	if from_pause:
		var menu := _dialog_button("В ГЛАВНОЕ МЕНЮ", false)
		menu.pressed.connect(func():
			_save_game()
			_show_title_screen())
		buttons.add_child(menu)

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		state.reset()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		state.reset()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		state.from_dict(parsed)
	else:
		state.reset()

func _on_state_changed() -> void:
	_update_ui()
	_save_game()

func _on_cell_selected(delta: Vector2i) -> void:
	state.move(delta)

func _show_notice(text: String) -> void:
	notice_label.text = text
	notice_label.visible = true
	toast_timer.start()

func _on_finished(won_game: bool, title: String, body_text: String, icon: String) -> void:
	_update_ui()
	_show_finished(won_game, title, body_text, icon)

func _update_ui() -> void:
	if not is_instance_valid(time_label):
		return
	time_label.text = "День %d  ·  %s" % [state.day_number(), state.clock_text()]
	var weather_icon := "☁"
	if state.campaign_chapter == 1:
		weather_icon = "↟"
	elif state.campaign_chapter >= 2:
		weather_icon = "❄"
	weather_label.text = weather_icon + "  " + state.weather_text()
	region_label.text = state.current_region()
	var chapter_names := ["СИГНАЛ", "ОСКОЛКИ", "СЛЕДОПЫТ"]
	chapter_hint_label.text = ["Найди модуль в старой обсерватории и вернись в лагерь.", "Собери три осколка сигнала и вернись с записями.", "Найди пропавшего следопыта и доберись с ним до лагеря."][mini(state.campaign_chapter, 2)]
	if state.campaign_chapter == 2 and state.survivor_found:
		chapter_hint_label.text = "Доставь следопыта в лагерь." if state.survivor_rescued else "Вернись за поисковой группой по координатам."
	if state.campaign_chapter < state.CHAPTER_COUNT:
		chapter_label.text = "ГЛАВА %s  ·  %s" % [["I", "II", "III"][state.campaign_chapter], chapter_names[state.campaign_chapter]]
	objective_label.text = state.objective_text()
	energy_value.text = "%d / %d" % [state.energy, state.MAX_ENERGY]
	energy_bar.value = float(state.energy) / state.MAX_ENERGY * 100.0
	pack_value.text = "%d / %d" % [state.pack_used(), state.PACK_LIMIT]
	pack_bar.value = float(state.pack_used()) / state.PACK_LIMIT * 100.0
	resource_values["wood"].text = str(state.wood)
	resource_values["food"].text = str(state.food)
	resource_values["notes"].text = str(state.notes)
	resource_values["module"].text = "НАЙДЕН" if state.has_module else "—"
	fragment_value.text = "%d / 3" % state.fragments
	survivor_value.text = "СПАСЁН" if state.survivor_rescued else ("НАЙДЕН" if state.survivor_found else "—")
	discoveries_label.text = "%d находок" % state.discoveries
	var journal_lines := PackedStringArray()
	for line: String in state.journal:
		journal_lines.append("· " + line)
	journal_label.text = "\n".join(journal_lines)
	rest_button.disabled = state.energy >= state.MAX_ENERGY or state.ended
	return_button.disabled = state.position == state.CAMP or state.ended
	food_button.disabled = state.food <= 0 or state.energy >= state.MAX_ENERGY or state.ended
	fire_button.disabled = state.wood < 2 or state.energy >= state.MAX_ENERGY or state.ended or state.position in state.campfires or str(state.grid[state._index(state.position)]["kind"]) == "bog"
	map_view.queue_redraw()

func _on_viewport_resized() -> void:
	if is_instance_valid(map_view):
		map_view.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if overlay.visible:
		if event.is_action_pressed("ui_cancel") and state.pending_encounter == "":
			overlay.visible = false
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		_show_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		state.move(Vector2i.UP)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		state.move(Vector2i.RIGHT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		state.move(Vector2i.DOWN)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		state.move(Vector2i.LEFT)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			state.rest()
		elif event.keycode == KEY_F:
			state.eat_food()
		elif event.keycode == KEY_C:
			state.build_campfire()
		elif event.keycode == KEY_B:
			state.return_to_camp()

func _label(text_value: String, font_size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .18))
	return label

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", card_style)
	return panel

func _panel_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(1, 1, 1, .09)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 17
	style.content_margin_right = 17
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func _small_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.add_theme_font_size_override("font_size", 9)
	button.add_theme_color_override("font_color", Color("#d9e0d6"))
	button.add_theme_stylebox_override("normal", _button_style(Color("#ffffff", .04), 8, Color("#ffffff", .13)))
	button.add_theme_stylebox_override("hover", _button_style(Color("#ffffff", .09), 8, Color("#ffffff", .21)))
	return button

func _action_button(title: String, subtitle: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(130, 49)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = title + "\n" + subtitle
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", Color("#dce4d8"))
	button.add_theme_color_override("font_disabled_color", Color("#7d897e"))
	button.add_theme_stylebox_override("normal", _button_style(Color("#ffffff", .04), 9, Color("#ffffff", .10)))
	button.add_theme_stylebox_override("hover", _button_style(Color("#ffffff", .09), 9, Color("#ffffff", .2)))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#ffffff", .025), 9, Color("#ffffff", .06)))
	return button

func _dialog_button(text_value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(164, 42)
	button.add_theme_font_size_override("font_size", 10)
	if primary:
		button.add_theme_color_override("font_color", Color("#1b211b"))
		button.add_theme_stylebox_override("normal", _button_style(Color("#e2b36d"), 9, Color("#f2d39e")))
		button.add_theme_stylebox_override("hover", _button_style(Color("#efc984"), 9, Color("#f5dfb1")))
	else:
		button.add_theme_color_override("font_color", Color("#e0e7dc"))
		button.add_theme_stylebox_override("normal", _button_style(Color("#314138"), 9, Color("#596a5d")))
		button.add_theme_stylebox_override("hover", _button_style(Color("#405347"), 9, Color("#718270")))
	return button

func _button_style(color: Color, radius: int, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _progress_bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 5
	bar.max_value = 100
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#111916")
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _draw_portrait(control: Control) -> void:
	var s := control.size
	var rect := Rect2(Vector2.ZERO, s)
	control.draw_style_box(_panel_style(Color("#344238"), 11), rect)
	control.draw_circle(Vector2(s.x * .83, s.y * .18), s.y * .27, Color(0.92, .73, .42, .10))
	var center := Vector2(s.x * .50, s.y * .77)
	# coat shoulders
	control.draw_colored_polygon(PackedVector2Array([center + Vector2(-40, 22), center + Vector2(-29, -7), center + Vector2(0, -17), center + Vector2(28, -7), center + Vector2(42, 22)]), Color("#4d604d"))
	control.draw_circle(center + Vector2(0, -24), 13, Color("#c99a6d"))
	control.draw_colored_polygon(PackedVector2Array([center + Vector2(-17, -22), center + Vector2(-11, -39), center + Vector2(6, -42), center + Vector2(18, -24), center + Vector2(10, -16), center + Vector2(-13, -16)]), Color("#b77b53"))
	control.draw_rect(Rect2(center + Vector2(-11, -17), Vector2(22, 4)), Color("#e3c18d"))
	control.draw_line(center + Vector2(23, -5), center + Vector2(43, 20), Color("#bc9666"), 3, true)
	control.draw_circle(center + Vector2(43, 20), 5, Color("#ffcf7c"))
