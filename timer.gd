extends Control

# Ссылки на узлы основного экрана
@onready var time_left_label = $CanvasLayer/Control/VBC/TimeLeftLabel
@onready var time_left_counter_label = $CanvasLayer/Control/VBC/TimeLeftCounterLabel
@onready var activity_line_edit = $CanvasLayer/Control/VBC/ActivityLineEdit
@onready var time_spin_box = $CanvasLayer/Control/VBC/Time/SpinBox
@onready var start_or_stop_button = $CanvasLayer/Control/VBC/StartStop/StartOrStopButton
@onready var pause_button = $CanvasLayer/Control/VBC/StartStop/PauseButton
@onready var older_activities_item_list = $CanvasLayer/Control/VBC/HistoryScroll/OlderActivitiesItemList
@onready var delete_selected_old_activities = $CanvasLayer/Control/VBC/DeleteSelectedOldActivities
@onready var settings_button = $CanvasLayer/Control/SettingsButton
@onready var internal_timer = $Timer
@onready var audio_stream_player = $AudioStreamPlayer

# Ссылки на узлы панели настроек
@onready var settings_panel = $Settings
@onready var open_alarm_folder_button = $Settings/Control/VBC/OpenAlarmFolderButton
@onready var exit_settings_button = $Settings/Control/ExitSettingsButton

# Внутренние переменные логики
var total_seconds: int = 0
var current_seconds: int = 0
var is_paused: bool = false
var current_task_name: String = ""

# Переменные для овертайма
var is_overtime: bool = false
var overtime_seconds: int = 0

# Хранит индекс выбранной записи в UI
var selected_label_index: int = -1

# Цвета
var default_color: Color = Color.WHITE
var overtime_blue_color: Color = Color(0.45, 0.65, 0.90)

func _ready():
	# Настройка окна Windows
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(380, 540))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	
	default_color = Color.WHITE
	settings_panel.visible = false
	
	# Подключение сигналов
	internal_timer.wait_time = 1.0
	internal_timer.one_shot = false
	internal_timer.timeout.connect(_on_timer_timeout)
	start_or_stop_button.pressed.connect(_on_start_or_stop_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	delete_selected_old_activities.pressed.connect(_on_delete_selected_pressed)
	
	settings_button.pressed.connect(_on_settings_button_pressed)
	open_alarm_folder_button.pressed.connect(_on_open_alarm_folder_pressed)
	exit_settings_button.pressed.connect(_on_settings_button_pressed)
	
	pause_button.disabled = true
	
	load_custom_mp3_sound()
	load_history_into_list()

func _on_settings_button_pressed():
	settings_panel.visible = not settings_panel.visible

func _on_open_alarm_folder_pressed():
	var global_user_path = ProjectSettings.globalize_path("user://")
	OS.shell_open(global_user_path)

func load_custom_mp3_sound():
	var custom_sound_path = "user://alarm.mp3"
	if FileAccess.file_exists(custom_sound_path):
		var file = FileAccess.open(custom_sound_path, FileAccess.READ)
		var buffer = file.get_buffer(file.get_length())
		file.close()
		
		var mp3_stream = AudioStreamMP3.new()
		mp3_stream.data = buffer
		audio_stream_player.stream = mp3_stream

func _on_start_or_stop_pressed():
	if internal_timer.is_stopped() and not is_paused and not is_overtime:
		var minutes = int(time_spin_box.value)
		if minutes <= 0:
			return 
			
		total_seconds = minutes * 60
		current_seconds = total_seconds
		overtime_seconds = 0
		is_overtime = false
		current_task_name = activity_line_edit.text.strip_edges()
		if current_task_name == "":
			current_task_name = "Безымянная задача"
			
		time_left_label.text = "Осталось"
		time_left_label.modulate = default_color
		time_left_counter_label.modulate = default_color
		update_time_label()
		internal_timer.start()
		start_or_stop_button.text = "Стоп"
		pause_button.disabled = false
	else:
		internal_timer.stop()
		if audio_stream_player.is_playing():
			audio_stream_player.stop()
		
		if current_seconds < total_seconds or is_overtime:
			# Считаем сколько планировали и сколько реально отсидели в овертайме
			var planned_min = int((total_seconds - max(0, current_seconds)) / 60)
			
			save_log_entry(current_task_name, planned_min, overtime_seconds) # Передаем СЕКУНДЫ овертайма
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

func _on_pause_pressed():
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

func _on_timer_timeout():
	if not is_overtime:
		if current_seconds > 0:
			current_seconds -= 1
			update_time_label()
		else:
			is_overtime = true
			pause_button.disabled = true
			time_left_label.text = "Овертайм!"
			time_left_label.modulate = overtime_blue_color
			time_left_counter_label.modulate = overtime_blue_color
			update_time_label()
			
			DisplayServer.window_request_attention()
			
			if audio_stream_player.stream != null:
				audio_stream_player.play()
	else:
		overtime_seconds += 1
		update_time_label()

func update_time_label():
	if not is_overtime:
		var minutes = current_seconds / 60
		var seconds = current_seconds % 60
		time_left_counter_label.text = "%02d:%02d" % [minutes, seconds]
		
		if total_seconds > 0:
			var progress = 1.0 - (float(current_seconds) / float(total_seconds))
			time_left_counter_label.modulate = default_color.lerp(Color.RED, progress)
	else:
		var minutes = overtime_seconds / 60
		var seconds = overtime_seconds % 60
		time_left_counter_label.text = "+%02d:%02d" % [minutes, seconds]
		
		if overtime_seconds % 2 == 0:
			time_left_counter_label.modulate = overtime_blue_color
			time_left_counter_label.modulate.a = 0.5
		else:
			time_left_counter_label.modulate = overtime_blue_color

func _on_history_item_clicked(ui_index: int):
	selected_label_index = ui_index
	var labels = older_activities_item_list.get_children()
	for i in range(labels.size()):
		if i == ui_index:
			labels[i].modulate = overtime_blue_color
		else:
			labels[i].modulate = Color.WHITE

func _on_delete_selected_pressed():
	if selected_label_index == -1:
		return
		
	var file_path = "user://time_tracker_logs.json"
	if not FileAccess.file_exists(file_path):
		return
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		var log_data = json.get_data()
		var real_json_index = log_data.size() - 1 - selected_label_index
		
		if real_json_index >= 0 and real_json_index < log_data.size():
			log_data.remove_at(real_json_index)
			
			var write_file = FileAccess.open(file_path, FileAccess.WRITE)
			write_file.store_string(JSON.stringify(log_data, "\t"))
			write_file.close()
			
			load_history_into_list()

# Сохранение в JSON (теперь честно пишет и минуты, и секунды доп. времени)
func save_log_entry(task_name: String, planned_min: int, total_overtime_sec: int):
	var file_path = "user://time_tracker_logs.json"
	var log_data = []
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		var json = JSON.new()
		if json.parse(json_string) == OK:
			log_data = json.get_data()
			
	var current_datetime = Time.get_datetime_string_from_system(false, true).replace("T", " ")
	var duration_str = str(planned_min) + " мин."
	
	# ФИКС: Красивое и точное форматирование овертайма
	if total_overtime_sec > 0:
		var ov_min = total_overtime_sec / 60
		var ov_sec = total_overtime_sec % 60
		
		duration_str += " (+ "
		if ov_min > 0:
			duration_str += str(ov_min) + " мин. "
		if ov_sec > 0 or ov_min == 0:
			duration_str += str(ov_sec) + " сек."
		duration_str += " овертайм)"
		
	var new_entry = {
		"date": current_datetime,
		"task": task_name,
		"duration": duration_str
	}
	log_data.append(new_entry)
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(log_data, "\t"))
	file.close()

func load_history_into_list():
	selected_label_index = -1
	for child in older_activities_item_list.get_children():
		child.queue_free()
		
	var file_path = "user://time_tracker_logs.json"
	if not FileAccess.file_exists(file_path):
		return
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		var log_data = json.get_data()
		log_data.reverse()
		
		for i in range(log_data.size()):
			var entry = log_data[i]
			
			var new_label = Label.new()
			new_label.text = "[%s] %s — %s" % [entry["date"], entry["task"], entry["duration"]]
			
			new_label.custom_minimum_size = Vector2(325, 0)
			new_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			new_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			
			new_label.label_settings = LabelSettings.new()
			new_label.label_settings.font_size = 13
			
			new_label.mouse_filter = Control.MOUSE_FILTER_STOP
			new_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			
			new_label.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_on_history_item_clicked(i)
			)
			
			older_activities_item_list.add_child(new_label)
