# EventBus.gd - 事件驅動架構的通訊中樞
#
# 功能：
# - 統一的事件定義和分發系統
# - 類型安全的事件處理
# - 自動化錯誤處理與日誌記錄
# - 除錯功能以追蹤事件流程

extends Node

# 遊戲狀態事件
signal game_state_changed(new_state: int, old_state: int)
signal game_initialized()
signal game_paused(paused: bool)
signal main_game_started()
signal turn_completed(turn_data: Dictionary)

# 玩家相關事件
signal player_level_up(new_level: int, attribute_gains: Dictionary)
signal player_attributes_changed(attributes: Dictionary)
signal player_experience_gained(amount: int, source: String)

# 技能系統事件
signal skill_selection_started()
signal skill_selected(skill_data: Dictionary, remaining_stars: int)
signal skill_selection_completed(selected_skills: Array, remaining_stars: int)
signal star_converted_to_attributes(stars_converted: int, attributes_gained: Dictionary)

# 戰鬥系統事件
signal battle_initiated(attacker: Dictionary, defender: Dictionary)
signal battle_started(attacker: Dictionary, defender: Dictionary, city_name: String)
signal battle_completed(result: Dictionary, victor: String, casualties: Dictionary)
signal city_siege_started(city_id: String, attacking_force: Dictionary)
signal city_conquered(city_name: String, new_owner: String, spoils: Dictionary)
signal general_captured(general_data: Dictionary, captor: String)
signal general_recruited(general_data: Dictionary, recruiter: String)

# 資源管理事件
signal resources_changed(resource_type: String, old_amount: int, new_amount: int)
signal resource_production_updated(city_name: String, production_rates: Dictionary)
signal equipment_acquired(equipment_data: Dictionary, source: String)
signal equipment_equipped(general_id: String, equipment_data: Dictionary)

# 城池管理事件
signal city_status_changed(city_name: String, new_status: Dictionary)
signal cities_updated(all_cities: Dictionary)
signal city_selected(city_id: String, city_data: Dictionary)
signal trade_route_established(from_city: String, to_city: String, benefits: Dictionary)

# 隨機事件系統
signal random_event_triggered(event_data: Dictionary, tianming_modifier: float)
signal event_choice_made(event_id: String, choice_index: int, consequences: Dictionary)
signal event_completed(event_id: String, final_outcome: Dictionary)

# UI系統事件
signal ui_panel_opened(panel_name: String)
signal ui_panel_closed(panel_name: String)
signal ui_notification_requested(message: String, type: String, duration: float)
signal ui_animation_requested(target: Node, animation_type: String, params: Dictionary)

# 存檔系統事件
signal save_requested(save_slot: int)
signal save_completed(save_slot: int, success: bool)
signal load_requested(save_slot: int)
signal load_completed(save_slot: int, success: bool, data: Dictionary)

# 音效事件
signal audio_play_requested(sound_name: String, volume: float, pitch: float)
signal music_change_requested(music_name: String, fade_time: float)
signal audio_settings_changed(master_volume: float, sfx_volume: float, music_volume: float)

# 除錯和開發事件
signal debug_command_executed(command: String, params: Dictionary)
signal performance_warning(warning_type: String, details: Dictionary)
signal error_occurred(error_type: String, message: String, context: Dictionary)

# 私有變量
var _event_history: Array[Dictionary] = []
var _max_history_size: int = 100
var _debug_mode: bool = false

func _ready() -> void:
	name = "EventBus"
	_debug_mode = OS.is_debug_build()

	if _debug_mode:
		LogManager.info("EventBus", "事件系統初始化完成", {"signals_count": get_signal_list().size()})

	# 連接內部事件處理
	connect_internal_handlers()

# 連接內部事件處理器
func connect_internal_handlers() -> void:
	# 記錄所有事件到歷史記錄
	var signals = get_signal_list()
	for signal_info in signals:
		var signal_name = signal_info["name"]
		if has_signal(signal_name):
			# 使用lambda包裝器來處理可變參數 - 支援更多參數
			var callable = Callable(func(arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null, arg6 = null):
				var signal_args = []
				for arg in [arg1, arg2, arg3, arg4, arg5, arg6]:
					if arg != null:
						signal_args.append(arg)
				_on_event_fired(signal_name, signal_args))
			connect(signal_name, callable)

# 內部事件處理器 - 記錄事件歷史
func _on_event_fired(signal_name: String, args: Array = []) -> void:
	var event_record = {
		"timestamp": Time.get_unix_time_from_system(),
		"signal": signal_name,
		"args": args,
		"frame": Engine.get_process_frames()
	}

	_event_history.append(event_record)

	# 限制歷史記錄大小
	if _event_history.size() > _max_history_size:
		_event_history.pop_front()

	if _debug_mode:
		LogManager.debug("EventBus", "事件觸發: %s" % signal_name, {"args": args})

# 安全地發射事件，帶有錯誤處理
func emit_safe(signal_name: String, args: Array = []) -> bool:
	if not has_signal(signal_name):
		LogManager.error("EventBus", "嘗試發射不存在的信號", {"signal": signal_name})
		return false

	match args.size():
		0:
			emit_signal(signal_name)
		1:
			emit_signal(signal_name, args[0])
		2:
			emit_signal(signal_name, args[0], args[1])
		3:
			emit_signal(signal_name, args[0], args[1], args[2])
		4:
			emit_signal(signal_name, args[0], args[1], args[2], args[3])
		5:
			emit_signal(signal_name, args[0], args[1], args[2], args[3], args[4])
		6:
			emit_signal(signal_name, args[0], args[1], args[2], args[3], args[4], args[5])
		_:
			LogManager.warn("EventBus", "信號參數過多", {"signal": signal_name, "arg_count": args.size()})
			return false

	return true

# 連接事件處理器，帶有錯誤處理
func connect_safe(signal_name: String, callable: Callable, flags: int = 0) -> bool:
	if not has_signal(signal_name):
		LogManager.error("EventBus", "嘗試連接不存在的信號", {"signal": signal_name})
		return false

	if is_connected(signal_name, callable):
		LogManager.warn("EventBus", "信號已經連接", {"signal": signal_name})
		return true

	var result = connect(signal_name, callable, flags)
	if result != OK:
		LogManager.error("EventBus", "連接信號失敗", {"signal": signal_name, "error": result})
		return false

	if _debug_mode:
		LogManager.debug("EventBus", "信號連接成功", {"signal": signal_name})

	return true

# 安全地斷開連接
func disconnect_safe(signal_name: String, callable: Callable) -> bool:
	if not has_signal(signal_name):
		LogManager.error("EventBus", "嘗試斷開不存在的信號", {"signal": signal_name})
		return false

	if not is_connected(signal_name, callable):
		LogManager.warn("EventBus", "信號未連接", {"signal": signal_name})
		return true

	disconnect(signal_name, callable)

	if _debug_mode:
		LogManager.debug("EventBus", "信號斷開成功", {"signal": signal_name})

	return true

# 獲取事件歷史記錄
func get_event_history() -> Array[Dictionary]:
	return _event_history.duplicate()

# 清除事件歷史記錄
func clear_event_history() -> void:
	_event_history.clear()
	LogManager.info("EventBus", "事件歷史記錄已清除")

# 獲取指定信號的連接數量
func get_connection_count(signal_name: String) -> int:
	if not has_signal(signal_name):
		return 0

	return get_signal_connection_list(signal_name).size()

# 獲取所有信號的連接統計
func get_connection_stats() -> Dictionary:
	var stats = {}
	var signals = get_signal_list()

	for signal_info in signals:
		var signal_name = signal_info["name"]
		stats[signal_name] = get_connection_count(signal_name)

	return stats

# 設置除錯模式
func set_debug_mode(enabled: bool) -> void:
	_debug_mode = enabled
	LogManager.info("EventBus", "除錯模式已%s" % ("開啟" if enabled else "關閉"))

# 驗證事件系統完整性
func validate_system() -> Dictionary:
	var validation_result = {
		"valid": true,
		"errors": [],
		"warnings": [],
		"signal_count": get_signal_list().size(),
		"total_connections": 0
	}

	var signals = get_signal_list()
	for signal_info in signals:
		var signal_name = signal_info["name"]
		var connection_count = get_connection_count(signal_name)
		validation_result.total_connections += connection_count

		# 檢查是否有信號沒有任何連接（可能的警告）
		if connection_count == 0:
			validation_result.warnings.append("信號 '%s' 沒有任何連接" % signal_name)

	LogManager.info("EventBus", "系統驗證完成", validation_result)
	return validation_result