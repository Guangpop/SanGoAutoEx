# GameCore.gd - 遊戲流程控制核心
#
# 功能：
# - 初始化並協調所有遊戲系統
# - 管理玩家資料與遊戲進度
# - 處理高階遊戲流程（開始遊戲、技能選擇、主循環）
# - 協調系統的啟動與關閉

extends Node

# 玩家數據結構
var player_data: Dictionary = {
	"level": 1,
	"experience": 0,
	"attributes": {
		"武力": 20,
		"智力": 20,
		"統治": 20,
		"政治": 20,
		"魅力": 20,
		"天命": 10
	},
	"resources": {
		"gold": 500,
		"troops": 200,
		"cities": 1
	},
	"selected_skills": [],
	"equipment": [],
	"generals": [],
	"owned_cities": ["chengdu"], # 默認從成都開始
	"game_turn": 1,
	"game_year": 184 # 黃巾起義年份
}

# 遊戲系統狀態
var _systems_initialized: bool = false
var _game_started: bool = false
var _initialization_errors: Array[String] = []

# 主遊戲循環計時器
var _game_timer: Timer
var _turn_duration: float = 5.0  # 5秒一回合 (放置遊戲節奏)

# 技能選擇相關
var _skill_selection_state: Dictionary = {
	"current_round": 0,
	"max_rounds": 3,
	"remaining_stars": 10,
	"available_skills": [],
	"selected_skills": []
}

func _ready() -> void:
	name = "GameCore"
	var startup_time = Time.get_unix_time_from_system()

	LogManager.info("GameCore", "遊戲核心系統啟動開始", {
		"startup_timestamp": startup_time,
		"autoload_order": "GameCore ready",
		"player_data_initialized": player_data != {}
	})

	# 等待其他autoload系統初始化完成
	LogManager.debug("GameCore", "等待其他autoload系統初始化")
	await get_tree().process_frame

	LogManager.debug("GameCore", "autoload系統等待完成", {
		"frame_processed": true,
		"ready_to_initialize": true
	})

	# 初始化遊戲系統
	var init_start_time = Time.get_unix_time_from_system()
	initialize_systems()
	var init_duration = Time.get_unix_time_from_system() - init_start_time

	# 設置主遊戲循環計時器
	setup_game_timer()

	# 連接事件處理器
	connect_event_handlers()

	var total_startup_time = Time.get_unix_time_from_system() - startup_time
	LogManager.info("GameCore", "遊戲核心系統啟動完成", {
		"initialization_duration": init_duration,
		"total_startup_time": total_startup_time,
		"systems_initialized": _systems_initialized,
		"error_count": _initialization_errors.size()
	})

# 初始化所有遊戲系統
func initialize_systems() -> void:
	var init_phase_start = Time.get_unix_time_from_system()

	LogManager.info("GameCore", "遊戲系統初始化序列開始", {
		"phase": "system_initialization",
		"expected_systems": ["EventBus", "GameStateManager", "LogManager", "DataManager"],
		"initialization_timestamp": init_phase_start
	})

	# 檢查必要的系統是否已載入
	LogManager.debug("GameCore", "驗證必要系統")
	var validation_result = _validate_required_systems()

	if not validation_result:
		LogManager.error("GameCore", "系統驗證失敗，終止初始化", {
			"validation_passed": false,
			"critical_error": true,
			"initialization_aborted": true
		})
		_initialization_errors.append("Required systems validation failed")
		return

	LogManager.info("GameCore", "系統驗證通過", {
		"validation_passed": true,
		"all_required_systems_present": true
	})

	# 等待數據管理器載入完成
	LogManager.info("GameCore", "等待數據管理器載入")
	var data_wait_start = Time.get_unix_time_from_system()
	var wait_frames = 0

	while DataManager.is_loading():
		await get_tree().process_frame
		wait_frames += 1

	var data_wait_duration = Time.get_unix_time_from_system() - data_wait_start

	LogManager.info("GameCore", "數據管理器載入等待完成", {
		"wait_duration": data_wait_duration,
		"frames_waited": wait_frames,
		"data_manager_ready": not DataManager.is_loading()
	})

	# 檢查數據載入是否成功
	var load_errors = DataManager.get_load_errors()
	if not load_errors.is_empty():
		LogManager.error("GameCore", "數據載入錯誤檢測", {
			"error_count": load_errors.size(),
			"errors": load_errors,
			"severity": "critical"
		})
		_initialization_errors.append_array(load_errors)
	else:
		LogManager.info("GameCore", "數據載入驗證通過", {
			"no_errors": true,
			"data_integrity": "validated"
		})

	# 初始化遊戲狀態到主選單
	LogManager.info("GameCore", "設置初始遊戲狀態", {
		"target_state": "MENU",
		"state_reason": "系統初始化完成"
	})

	GameStateManager.change_state(GameStateManager.GameState.MENU, "系統初始化完成")

	_systems_initialized = true
	var total_init_duration = Time.get_unix_time_from_system() - init_phase_start

	LogManager.info("GameCore", "遊戲系統初始化序列完成", {
		"initialization_successful": true,
		"total_duration": total_init_duration,
		"has_errors": not _initialization_errors.is_empty(),
		"error_count": _initialization_errors.size(),
		"systems_initialized": _systems_initialized
	})

	# 發送初始化完成事件
	LogManager.debug("GameCore", "發送遊戲初始化完成事件")
	EventBus.game_initialized.emit()

	LogManager.info("GameCore", "初始化事件已發送", {
		"event": "game_initialized",
		"broadcast_complete": true
	})

# 驗證必要系統是否已載入
func _validate_required_systems() -> bool:
	var required_systems = ["EventBus", "GameStateManager", "LogManager", "DataManager"]
	var missing_systems: Array[String] = []
	var present_systems: Array[String] = []

	LogManager.debug("GameCore", "開始系統驗證", {
		"required_systems": required_systems,
		"total_required": required_systems.size()
	})

	for system_name in required_systems:
		var system_path = "/root/" + system_name
		var system_exists = has_node(system_path)

		LogManager.debug("GameCore", "檢查系統", {
			"system_name": system_name,
			"system_path": system_path,
			"exists": system_exists
		})

		if not system_exists:
			missing_systems.append(system_name)
		else:
			present_systems.append(system_name)

	var validation_success = missing_systems.is_empty()

	if not validation_success:
		LogManager.error("GameCore", "系統驗證失敗", {
			"missing_systems": missing_systems,
			"present_systems": present_systems,
			"missing_count": missing_systems.size(),
			"validation_result": false
		})
		return false

	LogManager.info("GameCore", "系統驗證成功", {
		"all_systems_present": present_systems,
		"system_count": present_systems.size(),
		"validation_result": true
	})

	return true

# 設置主遊戲循環計時器
func setup_game_timer() -> void:
	LogManager.info("GameCore", "設置主遊戲循環計時器", {
		"turn_duration": _turn_duration,
		"timer_setup": "initializing"
	})

	_game_timer = Timer.new()
	_game_timer.wait_time = _turn_duration
	_game_timer.timeout.connect(_on_game_timer_timeout)
	_game_timer.autostart = false
	add_child(_game_timer)

	LogManager.info("GameCore", "主遊戲循環計時器設置完成", {
		"timer_ready": true,
		"autostart": false,
		"wait_time": _game_timer.wait_time
	})

# 開始主遊戲循環
func start_main_game_loop() -> void:
	if not _game_started:
		LogManager.warn("GameCore", "遊戲未開始，無法啟動主循環", {
			"game_started": _game_started,
			"loop_start_cancelled": true
		})
		return

	if not _game_timer:
		LogManager.error("GameCore", "遊戲計時器未初始化", {
			"timer_exists": false,
			"loop_start_failed": true
		})
		return

	LogManager.info("GameCore", "啟動主遊戲循環", {
		"turn_duration": _turn_duration,
		"game_timer_starting": true,
		"current_turn": player_data.game_turn
	})

	_game_timer.start()
	EventBus.main_game_started.emit()

	LogManager.info("GameCore", "主遊戲循環已啟動", {
		"timer_running": _game_timer.time_left > 0,
		"loop_active": true,
		"next_turn_in": _game_timer.time_left
	})

# 停止主遊戲循環
func stop_main_game_loop() -> void:
	if _game_timer and not _game_timer.is_stopped():
		_game_timer.stop()
		LogManager.info("GameCore", "主遊戲循環已停止", {
			"timer_stopped": true,
			"current_turn": player_data.game_turn
		})

# 計時器超時處理
func _on_game_timer_timeout() -> void:
	if GameStateManager.get_current_state() == GameStateManager.GameState.GAME_RUNNING:
		LogManager.debug("GameCore", "計時器觸發回合處理", {
			"current_turn": player_data.game_turn,
			"timer_triggered": true
		})
		process_game_turn()
	else:
		LogManager.debug("GameCore", "遊戲非運行狀態，跳過回合處理", {
			"current_state": GameStateManager.get_current_state(),
			"expected_state": GameStateManager.GameState.GAME_RUNNING
		})

# 連接事件處理器
func connect_event_handlers() -> void:
	LogManager.info("GameCore", "開始連接事件處理器", {
		"phase": "event_handler_connection",
		"event_categories": ["game_state", "skill_selection", "battle", "resources"]
	})

	var connection_results = {}
	var total_connections = 0
	var successful_connections = 0

	# 遊戲狀態事件
	LogManager.debug("GameCore", "連接遊戲狀態事件")
	var state_connection = EventBus.connect_safe("game_state_changed", _on_game_state_changed)
	connection_results["game_state_changed"] = state_connection
	total_connections += 1
	if state_connection:
		successful_connections += 1

	# 技能選擇事件
	LogManager.debug("GameCore", "連接技能選擇事件")
	var skill_selected_connection = EventBus.connect_safe("skill_selected", _on_skill_selected)
	connection_results["skill_selected"] = skill_selected_connection
	total_connections += 1
	if skill_selected_connection:
		successful_connections += 1

	var skill_completed_connection = EventBus.connect_safe("skill_selection_completed", _on_skill_selection_completed)
	connection_results["skill_selection_completed"] = skill_completed_connection
	total_connections += 1
	if skill_completed_connection:
		successful_connections += 1

	# 戰鬥事件
	LogManager.debug("GameCore", "連接戰鬥事件")
	var battle_connection = EventBus.connect_safe("battle_completed", _on_battle_completed)
	connection_results["battle_completed"] = battle_connection
	total_connections += 1
	if battle_connection:
		successful_connections += 1

	var city_connection = EventBus.connect_safe("city_conquered", _on_city_conquered)
	connection_results["city_conquered"] = city_connection
	total_connections += 1
	if city_connection:
		successful_connections += 1

	# 資源事件
	LogManager.debug("GameCore", "連接資源事件")
	var resource_connection = EventBus.connect_safe("resources_changed", _on_resources_changed)
	connection_results["resources_changed"] = resource_connection
	total_connections += 1
	if resource_connection:
		successful_connections += 1

	LogManager.info("GameCore", "事件處理器連接完成", {
		"total_connections": total_connections,
		"successful_connections": successful_connections,
		"failed_connections": total_connections - successful_connections,
		"connection_success_rate": float(successful_connections) / float(total_connections),
		"connection_results": connection_results
	})

	LogManager.debug("GameCore", "事件處理器連接完成")

# === 遊戲流程控制方法 ===

# 開始新遊戲
func start_new_game() -> void:
	var game_start_time = Time.get_unix_time_from_system()

	if not _systems_initialized:
		LogManager.error("GameCore", "系統未初始化，無法開始遊戲", {
			"systems_initialized": _systems_initialized,
			"initialization_errors": _initialization_errors,
			"action_blocked": true
		})
		return

	LogManager.info("GameCore", "開始新遊戲流程", {
		"game_start_timestamp": game_start_time,
		"previous_game_started": _game_started,
		"action": "start_new_game"
	})

	# 重置玩家數據
	LogManager.debug("GameCore", "重置玩家數據開始")
	reset_player_data()

	# 轉換到技能選擇階段
	LogManager.info("GameCore", "轉換遊戲狀態到技能選擇", {
		"target_state": "SKILL_SELECTION",
		"reason": "開始新遊戲",
		"state_transition_time": Time.get_unix_time_from_system()
	})

	GameStateManager.change_state(GameStateManager.GameState.SKILL_SELECTION, "開始新遊戲")

	_game_started = true
	var total_start_time = Time.get_unix_time_from_system() - game_start_time

	LogManager.info("GameCore", "新遊戲啟動完成", {
		"game_started": _game_started,
		"startup_duration": total_start_time,
		"player_level": player_data.level,
		"starting_cities": player_data.owned_cities
	})

# 載入遊戲
func load_game(save_data: Dictionary) -> bool:
	var load_start_time = Time.get_unix_time_from_system()

	LogManager.info("GameCore", "開始載入遊戲", {
		"load_timestamp": load_start_time,
		"save_data_size": save_data.size(),
		"save_data_keys": save_data.keys()
	})

	if not _systems_initialized:
		LogManager.error("GameCore", "系統未初始化，無法載入遊戲", {
			"systems_initialized": _systems_initialized,
			"initialization_errors": _initialization_errors,
			"load_blocked": true
		})
		return false

	# 驗證存檔數據
	LogManager.debug("GameCore", "驗證存檔數據開始")
	if not _validate_save_data(save_data):
		LogManager.error("GameCore", "存檔數據驗證失敗", {
			"validation_result": false,
			"save_data_keys": save_data.keys(),
			"load_aborted": true
		})
		return false

	LogManager.info("GameCore", "存檔數據驗證通過", {
		"validation_result": true,
		"save_timestamp": save_data.get("timestamp", "unknown")
	})

	# 載入玩家數據
	LogManager.debug("GameCore", "載入玩家數據")
	var old_player_data = player_data.duplicate()
	player_data = save_data.get("player_data", player_data)

	LogManager.info("GameCore", "玩家數據載入完成", {
		"old_level": old_player_data.level,
		"new_level": player_data.level,
		"old_turn": old_player_data.game_turn,
		"new_turn": player_data.game_turn,
		"cities_loaded": player_data.owned_cities.size()
	})

	# 載入技能選擇狀態
	LogManager.debug("GameCore", "載入技能選擇狀態")
	_skill_selection_state = save_data.get("skill_selection_state", _skill_selection_state)

	# 恢復遊戲狀態
	var saved_state = save_data.get("game_state", GameStateManager.GameState.GAME_RUNNING)
	LogManager.info("GameCore", "恢復遊戲狀態", {
		"saved_state": saved_state,
		"state_name": GameStateManager.GameState.keys()[saved_state] if saved_state < GameStateManager.GameState.size() else "unknown"
	})

	GameStateManager.change_state(saved_state, "載入遊戲")

	_game_started = true
	var load_duration = Time.get_unix_time_from_system() - load_start_time

	LogManager.info("GameCore", "遊戲載入完成", {
		"load_successful": true,
		"load_duration": load_duration,
		"player_level": player_data.level,
		"game_turn": player_data.game_turn,
		"game_year": player_data.game_year,
		"cities_owned": player_data.owned_cities.size(),
		"selected_skills_count": player_data.selected_skills.size()
	})

	return true

# 重置玩家數據到初始狀態
func reset_player_data() -> void:
	var reset_start_time = Time.get_unix_time_from_system()

	LogManager.info("GameCore", "開始重置玩家數據", {
		"reset_timestamp": reset_start_time,
		"current_level": player_data.level,
		"current_turn": player_data.game_turn
	})

	var balance_config = DataManager.get_balance_config("player_progression")
	var starting_resources = DataManager.get_balance_config("resource_economy.starting_resources")

	LogManager.debug("GameCore", "載入初始配置", {
		"balance_config_loaded": balance_config != null,
		"starting_resources_loaded": starting_resources != null
	})

	var old_data = player_data.duplicate()

	player_data = {
		"level": 1,
		"experience": 0,
		"attributes": balance_config.get("base_attributes", {
			"武力": 20,
			"智力": 20,
			"統治": 20,
			"政治": 20,
			"魅力": 20,
			"天命": 10
		}),
		"resources": starting_resources if starting_resources else {
			"gold": 500,
			"troops": 200,
			"cities": 1
		},
		"selected_skills": [],
		"equipment": [],
		"generals": [],
		"owned_cities": ["chengdu"],
		"game_turn": 1,
		"game_year": 184
	}

	# 重置技能選擇狀態
	var old_skill_state = _skill_selection_state.duplicate()
	_skill_selection_state = {
		"current_round": 0,
		"max_rounds": 3,
		"remaining_stars": 10,
		"available_skills": [],
		"selected_skills": []
	}

	var reset_duration = Time.get_unix_time_from_system() - reset_start_time

	LogManager.info("GameCore", "玩家數據重置完成", {
		"reset_duration": reset_duration,
		"old_level": old_data.level,
		"new_level": player_data.level,
		"old_cities_count": old_data.owned_cities.size(),
		"new_cities_count": player_data.owned_cities.size(),
		"old_skills_count": old_data.selected_skills.size(),
		"skill_state_reset": true,
		"initial_resources": player_data.resources
	})

# === 技能選擇系統 ===

# 開始技能選擇流程
func start_skill_selection() -> void:
	var selection_start_time = Time.get_unix_time_from_system()

	LogManager.info("GameCore", "開始技能選擇流程", {
		"selection_timestamp": selection_start_time,
		"player_level": player_data.level,
		"player_attributes": player_data.attributes,
		"action": "start_skill_selection"
	})

	# 使用SkillSelectionManager處理技能選擇
	LogManager.debug("GameCore", "委託給SkillSelectionManager處理", {
		"manager": "SkillSelectionManager",
		"player_data_provided": player_data != null
	})

	var success = SkillSelectionManager.start_skill_selection(player_data)
	if not success:
		LogManager.error("GameCore", "技能選擇啟動失敗", {
			"manager_response": false,
			"skill_selection_blocked": true,
			"player_level": player_data.level
		})
		return

	LogManager.info("GameCore", "SkillSelectionManager啟動成功", {
		"manager_response": true,
		"selection_initiated": true
	})

	# 發送技能選擇開始事件
	LogManager.debug("GameCore", "發送技能選擇開始事件")
	EventBus.skill_selection_started.emit()

	var total_startup_time = Time.get_unix_time_from_system() - selection_start_time

	LogManager.info("GameCore", "技能選擇流程啟動完成", {
		"startup_duration": total_startup_time,
		"event_broadcast": true,
		"flow_status": "skill_selection_active"
	})

# 選擇技能 (現在委託給SkillSelectionManager)
func select_skill(skill_id: String) -> bool:
	return SkillSelectionManager.select_skill(skill_id)

# 跳過技能選擇 (現在委託給SkillSelectionManager)
func skip_skill_selection() -> void:
	SkillSelectionManager.skip_current_round()

# 獲取技能選擇狀態 (從SkillSelectionManager)
func get_skill_selection_state() -> Dictionary:
	return SkillSelectionManager.get_selection_state()

# 應用技能效果到玩家屬性
func _apply_skill_effects(skill_data: Dictionary) -> void:
	var effects = skill_data.get("effects", {})

	for attribute_name in effects:
		if player_data.attributes.has(attribute_name):
			var old_value = player_data.attributes[attribute_name]
			player_data.attributes[attribute_name] += effects[attribute_name]
			LogManager.debug("GameCore", "技能效果應用", {
				"attribute": attribute_name,
				"old_value": old_value,
				"bonus": effects[attribute_name],
				"new_value": player_data.attributes[attribute_name]
			})

# 將星星轉換為屬性點
func _convert_stars_to_attributes(stars: int) -> void:
	var balance_config = DataManager.get_balance_config("player_progression")
	var conversion_rate = balance_config.get("star_conversion_rate.stars_to_attributes", 10)
	var total_points = stars * conversion_rate

	# 隨機分配到各屬性（除了天命）
	var attributes = ["武力", "智力", "統治", "政治", "魅力"]
	var gained_attributes: Dictionary = {}

	for i in range(total_points):
		var random_attr = attributes[randi() % attributes.size()]
		gained_attributes[random_attr] = gained_attributes.get(random_attr, 0) + 1
		player_data.attributes[random_attr] += 1

	LogManager.info("GameCore", "星星轉換完成", {
		"stars_converted": stars,
		"total_points": total_points,
		"attribute_gains": gained_attributes
	})

	# 發送星星轉換事件
	EventBus.star_converted_to_attributes.emit(stars, gained_attributes)

# === 遊戲主循環 ===

# 處理遊戲回合
func process_game_turn() -> void:
	var turn_start_time = Time.get_unix_time_from_system()

	if not _game_started:
		LogManager.warn("GameCore", "遊戲未開始，跳過回合處理", {
			"game_started": _game_started,
			"turn_skipped": true
		})
		return

	var current_turn = player_data.game_turn
	LogManager.info("GameCore", "開始處理遊戲回合", {
		"turn": current_turn,
		"year": player_data.game_year,
		"turn_timestamp": turn_start_time,
		"player_level": player_data.level,
		"owned_cities": player_data.owned_cities.size()
	})

	# 1. 隨機事件階段
	LogManager.debug("GameCore", "階段1: 處理隨機事件")
	var events_start = Time.get_unix_time_from_system()
	process_random_events()
	var events_duration = Time.get_unix_time_from_system() - events_start

	# 2. 資源生產階段
	LogManager.debug("GameCore", "階段2: 處理資源生產")
	var production_start = Time.get_unix_time_from_system()
	process_resource_production()
	var production_duration = Time.get_unix_time_from_system() - production_start

	# 3. 戰鬥階段（自動選擇目標）
	LogManager.debug("GameCore", "階段3: 自動戰鬥邏輯")
	var battle_start = Time.get_unix_time_from_system()
	process_auto_battle()
	var battle_duration = Time.get_unix_time_from_system() - battle_start

	# 4. 回合結束處理
	LogManager.debug("GameCore", "階段4: 回合結束處理")
	var old_turn = player_data.game_turn
	var old_year = player_data.game_year

	player_data.game_turn += 1
	var year_changed = false
	if player_data.game_turn % 12 == 0: # 假設12回合為一年
		player_data.game_year += 1
		year_changed = true

	var total_turn_duration = Time.get_unix_time_from_system() - turn_start_time

	LogManager.info("GameCore", "回合處理完成", {
		"old_turn": old_turn,
		"new_turn": player_data.game_turn,
		"old_year": old_year,
		"new_year": player_data.game_year,
		"year_changed": year_changed,
		"total_duration": total_turn_duration,
		"events_duration": events_duration,
		"production_duration": production_duration,
		"current_resources": player_data.resources
	})

	# 發送回合完成事件
	var turn_data = {
		"turn": player_data.game_turn,
		"year": player_data.game_year,
		"timestamp": Time.get_unix_time_from_system(),
		"resources": player_data.resources,
		"duration": total_turn_duration
	}
	EventBus.turn_completed.emit(turn_data)

# 處理隨機事件
func process_random_events() -> void:
	var events_config = DataManager.get_balance_config("random_events")
	var events_per_turn = events_config.get("event_frequency.events_per_turn", 1.2)

	# 根據事件頻率決定是否觸發事件
	if randf() < events_per_turn:
		var available_events = DataManager.get_events_by_category("positive") + \
							   DataManager.get_events_by_category("negative") + \
							   DataManager.get_events_by_category("neutral")

		if not available_events.is_empty():
			var random_event = available_events[randi() % available_events.size()]
			trigger_random_event(random_event)

# 觸發隨機事件
func trigger_random_event(event_data: Dictionary) -> void:
	var tianming_modifier = calculate_tianming_modifier(event_data)

	LogManager.game_event("RandomEvent", event_data.get("name", "未知事件"), {
		"event_id": event_data.get("id", ""),
		"category": event_data.get("category", ""),
		"tianming_modifier": tianming_modifier
	})

	EventBus.random_event_triggered.emit(event_data, tianming_modifier)

# 計算天命修正值
func calculate_tianming_modifier(event_data: Dictionary) -> float:
	var base_modifier = event_data.get("tianming_modifier", 1.0)
	var player_tianming = player_data.attributes.get("天命", 10)

	# 天命影響事件機率
	var tianming_impact = DataManager.get_balance_config("random_events.tianming_impact")
	var positive_multiplier = tianming_impact.get("positive_event_multiplier", 0.02)

	return base_modifier * (1.0 + player_tianming * positive_multiplier * 0.01)

# 處理資源生產
func process_resource_production() -> void:
	# 優先使用CityManager的城池收益系統
	var total_income = {"gold": 0, "troops": 0, "food": 0}

	if CityManager and CityManager.player_cities.size() > 0:
		total_income = CityManager.get_total_city_income()
		LogManager.debug("GameCore", "使用CityManager計算收益", total_income)
	else:
		# 回退到基礎計算
		var resource_config = DataManager.get_balance_config("resource_economy")
		var base_production = resource_config.get("base_city_production", {})
		var modifiers = resource_config.get("production_modifiers", {})

		var cities_count = player_data.owned_cities.size()
		var politics_bonus = player_data.attributes.get("政治", 20) * modifiers.get("politics_gold_bonus", 0.02)
		var leadership_bonus = player_data.attributes.get("統治", 20) * modifiers.get("leadership_troop_bonus", 0.015)

		total_income.gold = base_production.get("gold_per_turn", 100) * cities_count * (1.0 + politics_bonus)
		total_income.troops = base_production.get("troops_per_turn", 50) * cities_count * (1.0 + leadership_bonus)

	# 應用收益
	player_data.resources.gold += int(total_income.gold)
	player_data.resources.troops += int(total_income.troops)

	LogManager.debug("GameCore", "資源生產完成", {
		"cities": player_data.owned_cities.size(),
		"gold_gained": int(total_income.gold),
		"troops_gained": int(total_income.troops),
		"total_gold": player_data.resources.gold,
		"total_troops": player_data.resources.troops
	})

# 處理自動戰鬥
func process_auto_battle() -> void:
	# 檢查是否有足夠資源進行戰鬥
	if player_data.resources.troops < 100:
		LogManager.debug("GameCore", "兵力不足，跳過自動戰鬥", {
			"current_troops": player_data.resources.troops,
			"min_required": 100
		})
		return

	# 檢查是否還有未征服的城池
	if player_data.owned_cities.size() >= 16:
		LogManager.info("GameCore", "已征服所有城池，跳過自動戰鬥")
		return

	# 確保自動戰鬥系統已初始化
	if AutoBattleManager and not AutoBattleManager.is_initialized():
		AutoBattleManager.initialize(player_data, {})

	# 嘗試選擇目標並發起戰鬥
	if AutoBattleManager and AutoBattleManager.is_auto_battle_enabled():
		var target_city = AutoBattleManager.select_optimal_target()

		if not target_city.is_empty():
			LogManager.info("GameCore", "發起自動戰鬥", {
				"target": target_city.get("name", ""),
				"current_cities": player_data.owned_cities.size(),
				"available_troops": player_data.resources.troops
			})

			AutoBattleManager.execute_auto_battle(target_city)
		else:
			LogManager.debug("GameCore", "未找到合適的攻擊目標")

# === 事件處理器 ===

func _on_game_state_changed(new_state: int, old_state: int) -> void:
	var state_names = {
		GameStateManager.GameState.MENU: "主選單",
		GameStateManager.GameState.SKILL_SELECTION: "技能選擇",
		GameStateManager.GameState.GAME_RUNNING: "主遊戲",
		GameStateManager.GameState.BATTLE: "戰鬥",
		GameStateManager.GameState.PAUSED: "暫停",
		GameStateManager.GameState.GAME_OVER: "遊戲結束"
	}

	LogManager.info("GameCore", "遊戲狀態變化處理", {
		"from_state": state_names.get(old_state, "未知狀態"),
		"to_state": state_names.get(new_state, "未知狀態"),
		"from_state_id": old_state,
		"to_state_id": new_state,
		"transition_timestamp": Time.get_unix_time_from_system()
	})

	match new_state:
		GameStateManager.GameState.SKILL_SELECTION:
			if old_state == GameStateManager.GameState.MENU:
				LogManager.info("GameCore", "從主選單進入技能選擇", {
					"transition": "MENU->SKILL_SELECTION",
					"action_required": "start_skill_selection"
				})
				start_skill_selection()
			else:
				LogManager.warn("GameCore", "非預期的技能選擇狀態轉換", {
					"from_state": state_names.get(old_state, "未知狀態"),
					"unexpected_transition": true
				})
		GameStateManager.GameState.GAME_RUNNING:
			if old_state == GameStateManager.GameState.SKILL_SELECTION:
				LogManager.info("GameCore", "技能選擇完成，進入主遊戲", {
					"transition": "SKILL_SELECTION->GAME_RUNNING",
					"selected_skills": player_data.selected_skills.size(),
					"ready_for_main_loop": true
				})
				# 技能選擇完成，開始主遊戲循環
				start_main_game_loop()
			else:
				LogManager.info("GameCore", "進入主遊戲狀態", {
					"from_state": state_names.get(old_state, "未知狀態"),
					"game_resumed_or_loaded": true
				})
		_:
			LogManager.debug("GameCore", "其他狀態轉換", {
				"from_state": state_names.get(old_state, "未知狀態"),
				"to_state": state_names.get(new_state, "未知狀態"),
				"no_specific_action": true
			})

func _on_skill_selected(skill_data: Dictionary, remaining_stars: int) -> void:
	# 技能選擇處理已在 select_skill 中完成
	pass

func _on_skill_selection_completed(selected_skills: Array, remaining_stars: int) -> void:
	LogManager.info("GameCore", "收到技能選擇完成事件", {
		"selected_skills_count": selected_skills.size(),
		"remaining_stars": remaining_stars,
		"current_state": GameStateManager.get_current_state(),
		"transition_target": "GAME_RUNNING"
	})

	# 技能選擇完成，轉換到主遊戲狀態
	if GameStateManager.get_current_state() == GameStateManager.GameState.SKILL_SELECTION:
		LogManager.info("GameCore", "技能選擇完成，切換到主遊戲狀態", {
			"trigger": "skill_selection_completed_event",
			"state_transition": "SKILL_SELECTION->GAME_RUNNING"
		})
		GameStateManager.change_state(GameStateManager.GameState.GAME_RUNNING, "技能選擇完成")
	else:
		LogManager.warn("GameCore", "技能選擇完成事件在錯誤的狀態下觸發", {
			"current_state": GameStateManager.get_current_state(),
			"expected_state": GameStateManager.GameState.SKILL_SELECTION
		})

func _on_battle_completed(result: Dictionary, victor: String, casualties: Dictionary) -> void:
	LogManager.game_event("Battle", "戰鬥結束", {
		"victor": victor,
		"casualties": casualties
	})

func _on_city_conquered(city_name: String, new_owner: String, spoils: Dictionary) -> void:
	if new_owner == "player":
		player_data.owned_cities.append(city_name)
		LogManager.game_event("Conquest", "城池佔領", {
			"city": city_name,
			"total_cities": player_data.owned_cities.size()
		})

func _on_resources_changed(resource_type: String, old_amount: int, new_amount: int) -> void:
	if player_data.resources.has(resource_type):
		player_data.resources[resource_type] = new_amount

# === 資源管理方法 ===

# 添加資源
func add_resources(resources: Dictionary) -> void:
	for resource_type in resources:
		var amount = resources[resource_type]
		if player_data.resources.has(resource_type):
			var old_amount = player_data.resources[resource_type]
			player_data.resources[resource_type] += amount
			var new_amount = player_data.resources[resource_type]

			LogManager.debug("GameCore", "資源添加", {
				"resource_type": resource_type,
				"amount_added": amount,
				"old_amount": old_amount,
				"new_amount": new_amount
			})

			# 發送資源變化事件
			EventBus.resources_changed.emit(resource_type, old_amount, new_amount)
		else:
			LogManager.warn("GameCore", "嘗試添加未知資源類型", {
				"resource_type": resource_type,
				"amount": amount
			})

# 扣減資源
func subtract_resources(resources: Dictionary) -> bool:
	# 首先檢查是否有足夠的資源
	for resource_type in resources:
		var amount = resources[resource_type]
		if player_data.resources.has(resource_type):
			if player_data.resources[resource_type] < amount:
				LogManager.warn("GameCore", "資源不足，無法扣減", {
					"resource_type": resource_type,
					"required": amount,
					"available": player_data.resources[resource_type]
				})
				return false
		else:
			LogManager.warn("GameCore", "嘗試扣減未知資源類型", {
				"resource_type": resource_type,
				"amount": amount
			})
			return false

	# 如果檢查通過，執行扣減
	for resource_type in resources:
		var amount = resources[resource_type]
		var old_amount = player_data.resources[resource_type]
		player_data.resources[resource_type] -= amount
		var new_amount = player_data.resources[resource_type]

		LogManager.debug("GameCore", "資源扣減", {
			"resource_type": resource_type,
			"amount_subtracted": amount,
			"old_amount": old_amount,
			"new_amount": new_amount
		})

		# 發送資源變化事件
		EventBus.resources_changed.emit(resource_type, old_amount, new_amount)

	return true

# 設置資源數量
func set_resource(resource_type: String, amount: int) -> void:
	if player_data.resources.has(resource_type):
		var old_amount = player_data.resources[resource_type]
		player_data.resources[resource_type] = amount

		LogManager.debug("GameCore", "資源設置", {
			"resource_type": resource_type,
			"old_amount": old_amount,
			"new_amount": amount
		})

		# 發送資源變化事件
		EventBus.resources_changed.emit(resource_type, old_amount, amount)
	else:
		LogManager.warn("GameCore", "嘗試設置未知資源類型", {
			"resource_type": resource_type,
			"amount": amount
		})

# 獲取資源數量
func get_resource(resource_type: String) -> int:
	return player_data.resources.get(resource_type, 0)

# 檢查是否有足夠資源
func has_resources(required_resources: Dictionary) -> bool:
	for resource_type in required_resources:
		var required_amount = required_resources[resource_type]
		var current_amount = player_data.resources.get(resource_type, 0)
		if current_amount < required_amount:
			return false
	return true

# 獲取所有資源
func get_all_resources() -> Dictionary:
	return player_data.resources.duplicate()

# === 公共API ===

# 獲取玩家數據
func get_player_data() -> Dictionary:
	return player_data.duplicate()

# 獲取內部技能選擇狀態
func get_internal_skill_selection_state() -> Dictionary:
	return _skill_selection_state.duplicate()

# 檢查系統是否已初始化
func is_systems_initialized() -> bool:
	return _systems_initialized

# 檢查遊戲是否已開始
func is_game_started() -> bool:
	return _game_started

# 獲取初始化錯誤
func get_initialization_errors() -> Array[String]:
	return _initialization_errors.duplicate()

# 驗證存檔數據
func _validate_save_data(save_data: Dictionary) -> bool:
	var required_keys = ["player_data", "game_state"]
	for key in required_keys:
		if not save_data.has(key):
			LogManager.error("GameCore", "存檔缺少必要數據", {"missing_key": key})
			return false

	return true

# 序列化遊戲狀態（用於存檔）
func serialize_game_state() -> Dictionary:
	return {
		"player_data": player_data,
		"skill_selection_state": _skill_selection_state,
		"game_state": GameStateManager.get_current_state(),
		"timestamp": Time.get_unix_time_from_system()
	}