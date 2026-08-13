extends Control

@onready var time_left_label: Label = $CanvasLayer/Control/VBC/TimeLeftLabel
@onready var time_left_counter_label: Label = $CanvasLayer/Control/VBC/TimeLeftCounterLabel
@onready var activity_line_edit: LineEdit = $CanvasLayer/Control/VBC/ActivityLineEdit
@onready var time_spin_box: SpinBox = $CanvasLayer/Control/VBC/Time/SpinBox
@onready var start_or_stop_button: Button = $CanvasLayer/Control/VBC/StartStop/StartOrStopButton
@onready var pause_button: Button = $CanvasLayer/Control/VBC/StartStop/PauseButton
@onready var older_activities_item_list: Control = $CanvasLayer/Control/VBC/HistoryScroll/OlderActivitiesItemList
@onready var delete_selected_old_activities: Button = $CanvasLayer/Control/VBC/DeleteSelectedOldActivities
@onready var settings_button: Button = $CanvasLayer/Control/SettingsButton
@onready var internal_timer: Timer = $Timer
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var hide_button: Button = $CanvasLayer/Control/HideButton
@onready var main_control: Control = $CanvasLayer/Control

@onready var settings_panel: Control = $Settings/Control
@onready var open_alarm_folder_button: Button = $Settings/Control/VBC/OpenAlarmFolderButton
@onready var exit_settings_button: Button = $Settings/Control/ExitSettingsButton

const NORMAL_WINDOW_SIZE := Vector2i(380, 540)
const SMALL_WINDOW_SIZE := Vector2i(380, 240)
const UI_SIZE := Vector2(380, 540)

var total_seconds: int = 0
var current_seconds: int = 0
var is_paused: bool = false
var current_task_name: String = ""

var is_overtime: bool = false
var overtime_seconds: int = 0

var selected_label_index: int = -1
var is_window_small: bool = false

var default_color := Color.WHITE
var overtime_blue_color := Color(0.45, 0.65, 0.90)


func _ready() -> void:
	var window := get_window()

	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.size = NORMAL_WINDOW_SIZE

	window.set_flag(
		Window.FLAG_RESIZE_DISABLED,
		true
	)

	window.set_flag(
		Window.FLAG_ALWAYS_ON_TOP,
		true
	)

	main_control.position = Vector2.ZERO
	main_control.size = UI_SIZE
	main_control.scale = Vector2.ONE

	_setup_signals()

	settings_panel.visible = false

	internal_timer.wait_time = 1.0
	internal_timer.one_shot = false

	pause_button.disabled = true

	load_custom_mp3_sound()
	load_history_into_list()
	_on_time_spin_box_changed(time_spin_box.value)


func _setup_signals() -> void:
	internal_timer.timeout.connect(_on_timer_timeout)

	hide_button.pressed.connect(_on_hide_button_pressed)
	start_or_stop_button.pressed.connect(_on_start_or_stop_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	delete_selected_old_activities.pressed.connect(_on_delete_selected_pressed)

	settings_button.pressed.connect(_on_settings_button_pressed)
	open_alarm_folder_button.pressed.connect(_on_open_alarm_folder_pressed)
	exit_settings_button.pressed.connect(_on_settings_button_pressed)

	time_spin_box.value_changed.connect(_on_time_spin_box_changed)


func _on_hide_button_pressed() -> void:
	is_window_small = not is_window_small

	if is_window_small:
		get_window().size = SMALL_WINDOW_SIZE
	else:
		get_window().size = NORMAL_WINDOW_SIZE

	main_control.position = Vector2.ZERO
	main_control.size = UI_SIZE
	main_control.scale = Vector2.ONE


func _on_settings_button_pressed() -> void:
	settings_panel.visible = not settings_panel.visible


func _on_open_alarm_folder_pressed() -> void:
	var global_user_path := ProjectSettings.globalize_path("user://")
	OS.shell_open(global_user_path)


func load_custom_mp3_sound() -> void:
	var custom_sound_path := "user://alarm.mp3"

	if not FileAccess.file_exists(custom_sound_path):
		return

	var file := FileAccess.open(custom_sound_path, FileAccess.READ)

	if file == null:
		return

	var buffer := file.get_buffer(file.get_length())
	file.close()

	var mp3_stream := AudioStreamMP3.new()
	mp3_stream.data = buffer
	audio_stream_player.stream = mp3_stream


func _on_time_spin_box_changed(value: float) -> void:
	if not internal_timer.is_stopped():
		return

	if is_paused or is_overtime:
		return

	var seconds := int(round(value * 60.0))

	time_left_counter_label.text = format_time(seconds)
	time_left_label.text = "Осталось"
	time_left_label.modulate = default_color
	time_left_counter_label.modulate = default_color


func format_time(seconds: int) -> String:
	var minutes := seconds / 60
	var remaining_seconds := seconds % 60

	return "%02d:%02d" % [minutes, remaining_seconds]


func _on_start_or_stop_pressed() -> void:
	if internal_timer.is_stopped() and not is_paused and not is_overtime:
		_start_timer()
	else:
		_stop_timer()


func _start_timer() -> void:
	var entered_minutes := float(time_spin_box.value)

	if entered_minutes <= 0.0:
		return

	total_seconds = int(round(entered_minutes * 60.0))
	current_seconds = total_seconds
	overtime_seconds = 0
	is_overtime = false

	current_task_name = activity_line_edit.text.strip_edges()

	if current_task_name.is_empty():
		current_task_name = "Безымянная задача"

	time_left_label.text = "Осталось"
	time_left_label.modulate = default_color
	time_left_counter_label.modulate = default_color

	update_time_label()

	internal_timer.start()

	start_or_stop_button.text = "Стоп"
	pause_button.disabled = false


func _stop_timer() -> void:
	internal_timer.stop()

	if audio_stream_player.is_playing():
		audio_stream_player.stop()

	if current_seconds < total_seconds or is_overtime:
		save_log_entry(
			current_task_name,
			total_seconds,
			overtime_seconds
		)
		load_history_into_list()

	is_paused = false
	is_overtime = false
	current_seconds = 0
	overtime_seconds = 0

	time_left_counter_label.text = "00:00"
	time_left_label.text = "Осталось"
	time_left_label.modulate = default_color
	time_left_counter_label.modulate = default_color

	start_or_stop_button.text = "Начать"
	pause_button.text = "Пауза"
	pause_button.disabled = true

	_on_time_spin_box_changed(time_spin_box.value)


func _on_pause_pressed() -> void:
	if is_overtime:
		return

	if internal_timer.is_stopped() and is_paused:
		internal_timer.start()
		is_paused = false
		pause_button.text = "Пауза"
	elif not internal_timer.is_stopped():
		internal_timer.stop()
		is_paused = true
		pause_button.text = "Продолжить"


func _on_timer_timeout() -> void:
	if not is_overtime:
		if current_seconds > 0:
			current_seconds -= 1
			update_time_label()
		else:
			_start_overtime()
	else:
		overtime_seconds += 1
		update_time_label()


func _start_overtime() -> void:
	is_overtime = true
	pause_button.disabled = true

	time_left_label.text = "Овертайм!"
	time_left_label.modulate = overtime_blue_color
	time_left_counter_label.modulate = overtime_blue_color

	update_time_label()

	get_window().request_attention()

	if audio_stream_player.stream != null:
		audio_stream_player.play()


func update_time_label() -> void:
	if not is_overtime:
		var minutes := current_seconds / 60
		var seconds := current_seconds % 60

		time_left_counter_label.text = "%02d:%02d" % [
			minutes,
			seconds
		]

		if total_seconds > 0:
			var progress := 1.0 - (
				float(current_seconds) / float(total_seconds)
			)

			time_left_counter_label.modulate = default_color.lerp(
				Color.RED,
				progress
			)
	else:
		var minutes := overtime_seconds / 60
		var seconds := overtime_seconds % 60

		time_left_counter_label.text = "+%02d:%02d" % [
			minutes,
			seconds
		]

		if overtime_seconds % 2 == 0:
			time_left_counter_label.modulate = overtime_blue_color
			time_left_counter_label.modulate.a = 0.5
		else:
			time_left_counter_label.modulate = overtime_blue_color


func _on_history_item_clicked(ui_index: int) -> void:
	selected_label_index = ui_index

	var labels := older_activities_item_list.get_children()

	for i in range(labels.size()):
		if i == ui_index:
			labels[i].modulate = overtime_blue_color
		else:
			labels[i].modulate = Color.WHITE


func _on_delete_selected_pressed() -> void:
	if selected_label_index == -1:
		return

	var file_path := "user://time_tracker_logs.json"

	if not FileAccess.file_exists(file_path):
		return

	var file := FileAccess.open(file_path, FileAccess.READ)

	if file == null:
		return

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()

	if json.parse(json_string) != OK:
		return

	var log_data = json.get_data()

	if not log_data is Array:
		return

	var real_json_index: int = (
		log_data.size() - 1 - selected_label_index
	)

	if real_json_index < 0 or real_json_index >= log_data.size():
		return

	log_data.remove_at(real_json_index)

	var write_file := FileAccess.open(
		file_path,
		FileAccess.WRITE
	)

	if write_file == null:
		return

	write_file.store_string(JSON.stringify(log_data, "\t"))
	write_file.close()

	load_history_into_list()


func save_log_entry(
	task_name: String,
	planned_seconds: int,
	total_overtime_sec: int
) -> void:
	var file_path := "user://time_tracker_logs.json"
	var log_data := []

	if FileAccess.file_exists(file_path):
		var file := FileAccess.open(file_path, FileAccess.READ)

		if file != null:
			var json_string := file.get_as_text()
			file.close()

			var json := JSON.new()

			if json.parse(json_string) == OK:
				var parsed_data = json.get_data()

				if parsed_data is Array:
					log_data = parsed_data

	var current_datetime := Time.get_datetime_string_from_system(
		false,
		true
	).replace("T", " ")

	var duration_str := format_duration_for_history(planned_seconds)

	if total_overtime_sec > 0:
		duration_str += " (+ "
		duration_str += format_duration_for_history(total_overtime_sec)
		duration_str += " овертайм)"

	var new_entry := {
		"date": current_datetime,
		"task": task_name,
		"duration": duration_str
	}

	log_data.append(new_entry)

	var file := FileAccess.open(
		file_path,
		FileAccess.WRITE
	)

	if file == null:
		return

	file.store_string(JSON.stringify(log_data, "\t"))
	file.close()


func format_duration_for_history(seconds: int) -> String:
	var minutes := seconds / 60
	var remaining_seconds := seconds % 60

	if minutes > 0 and remaining_seconds > 0:
		return "%d мин. %d сек." % [
			minutes,
			remaining_seconds
		]

	if minutes > 0:
		return "%d мин." % minutes

	return "%d сек." % remaining_seconds


func load_history_into_list() -> void:
	selected_label_index = -1

	for child in older_activities_item_list.get_children():
		child.queue_free()

	var file_path := "user://time_tracker_logs.json"

	if not FileAccess.file_exists(file_path):
		return

	var file := FileAccess.open(file_path, FileAccess.READ)

	if file == null:
		return

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()

	if json.parse(json_string) != OK:
		return

	var log_data = json.get_data()

	if not log_data is Array:
		return

	log_data.reverse()

	for i in range(log_data.size()):
		var entry = log_data[i]

		var new_label := RichTextLabel.new()

		new_label.bbcode_enabled = true
		new_label.fit_content = true
		new_label.scroll_active = false

		new_label.text = (
			"[i][%s][/i] — [b]%s[/b] — %s"
			% [
				str(entry.get("date", "")),
				str(entry.get("task", "")),
				str(entry.get("duration", ""))
			]
		)

		new_label.custom_minimum_size = Vector2(325.0, 0.0)
		new_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		new_label.add_theme_font_size_override(
			"normal_font_size",
			13
		)

		new_label.mouse_filter = Control.MOUSE_FILTER_STOP
		new_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var item_index: int = i

		new_label.gui_input.connect(
			func(event: InputEvent) -> void:
				if not event is InputEventMouseButton:
					return

				if not event.pressed:
					return

				if event.button_index != MOUSE_BUTTON_LEFT:
					return

				_on_history_item_clicked(item_index)
		)

		older_activities_item_list.add_child(new_label)
