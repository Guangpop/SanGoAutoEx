# BattleAutomationController.gd - 戰鬥自動化控制器
#
# 功能：
# - 協調MapArea、CityManager、AutoBattleManager的戰鬥流程
# - 實現閒置遊戲的自動戰鬥循環
# - 管理戰鬥進度顯示和視覺回饋
# - 處理玩家手動戰鬥和自動戰鬥的切換

extends Node

signal battle_automation_started()
signal battle_automation_stopped()
signal battle_progress_updated(battle_info: Dictionary)
signal city_attack_initiated(city_id: String, battle_plan: Dictionary)

# 自動化狀態
var automation_active: bool = false
var manual_battle_mode: bool = false
var current_battles: Dictionary = {}

# 配置
var battle_interval: float = 30.0  # 30秒檢查一次自動戰鬥
var max_concurrent_battles: int = 3
var auto_battle_enabled: bool = true

# 系統引用
var map_area: Node2D = null
var city_manager: Node = null
var auto_battle_manager: Node = null
var battle_manager: Node = null

# 戰鬥計時器
var battle_timer: Timer = null
var battle_check_timer: Timer = null

func _ready() -> void:
	name = "BattleAutomationController"
	LogManager.info("BattleAutomationController", "戰鬥自動化控制器初始化開始")

	# 等待其他系統初始化
	await _wait_for_systems()

	# 獲取系統引用
	_get_system_references()

	# 設置計時器
	_setup_timers()

	# 連接事件處理器
	_connect_event_handlers()

	LogManager.info("BattleAutomationController", "戰鬥自動化控制器初始化完成", {
		"auto_battle_enabled": auto_battle_enabled,
		"battle_interval": battle_interval,
		"max_concurrent_battles": max_concurrent_battles
	})

# 等待核心系統初始化
func _wait_for_systems() -> void:
	var max_wait_time = 5.0
	var wait_start = Time.get_unix_time_from_system()

	while not (CityManager and AutoBattleManager and BattleManager and GameCore.is_systems_initialized()):
		await get_tree().process_frame
		var elapsed = Time.get_unix_time_from_system() - wait_start
		if elapsed > max_wait_time:
			LogManager.warn("BattleAutomationController", "等待系統初始化超時")
			break

# 獲取系統引用
func _get_system_references() -> void:
	city_manager = CityManager
	auto_battle_manager = AutoBattleManager
	battle_manager = BattleManager

	# 查找MapArea
	var main_mobile = get_tree().get_first_node_in_group("main_mobile")
	if main_mobile:
		map_area = main_mobile.get_node_or_null("VBoxContainer/GameMainArea/MapArea/MapRoot")

	LogManager.debug("BattleAutomationController", "系統引用獲取完成", {
		"city_manager": city_manager != null,
		"auto_battle_manager": auto_battle_manager != null,
		"battle_manager": battle_manager != null,
		"map_area": map_area != null
	})

# 設置計時器
func _setup_timers() -> void:
	# 戰鬥執行計時器
	battle_timer = Timer.new()
	battle_timer.name = "BattleTimer"
	battle_timer.wait_time = battle_interval
	battle_timer.autostart = false
	battle_timer.timeout.connect(_on_battle_timer_timeout)
	add_child(battle_timer)

	# 戰鬥檢查計時器（更頻繁的檢查）
	battle_check_timer = Timer.new()
	battle_check_timer.name = "BattleCheckTimer"
	battle_check_timer.wait_time = 5.0  # 5秒檢查一次
	battle_check_timer.autostart = false
	battle_check_timer.timeout.connect(_on_battle_check_timeout)
	add_child(battle_check_timer)

# 連接事件處理器
func _connect_event_handlers() -> void:
	if EventBus:
		EventBus.connect_safe("game_state_changed", _on_game_state_changed)
		EventBus.connect_safe("city_selected", _on_city_selected)
		EventBus.connect_safe("city_conquered", _on_city_conquered)
		EventBus.connect_safe("battle_completed", _on_battle_completed)
		EventBus.connect_safe("main_game_started", _on_main_game_started)

	if city_manager:
		city_manager.connect("city_conquered", _on_city_manager_conquest)

	LogManager.debug("BattleAutomationController", "事件處理器連接完成")

# === 主要控制方法 ===

# 啟動戰鬥自動化
func start_automation() -> void:
	if automation_active:
		return

	LogManager.info("BattleAutomationController", "啟動戰鬥自動化")

	# 初始化AutoBattleManager
	if auto_battle_manager and not auto_battle_manager.is_initialized():
		var player_data = GameCore.get_player_data()
		var config = _get_automation_config()
		auto_battle_manager.initialize(player_data, config)

	automation_active = true
	battle_timer.start()
	battle_check_timer.start()

	battle_automation_started.emit()

	# 立即執行一次檢查
	_check_for_battle_opportunities()

# 停止戰鬥自動化
func stop_automation() -> void:
	if not automation_active:
		return

	LogManager.info("BattleAutomationController", "停止戰鬥自動化")

	automation_active = false
	battle_timer.stop()
	battle_check_timer.stop()

	# 暫停AutoBattleManager
	if auto_battle_manager:
		auto_battle_manager.pause_automation("user_stopped")

	battle_automation_stopped.emit()

# 切換自動化狀態
func toggle_automation() -> void:
	if automation_active:
		stop_automation()
	else:
		start_automation()

# 手動攻擊城池
func initiate_manual_attack(city_id: String) -> Dictionary:
	if not city_manager or not battle_manager:
		return {"success": false, "error": "systems_not_ready"}

	var city_data = city_manager.get_city_data(city_id)
	if city_data.is_empty():
		return {"success": false, "error": "city_not_found"}

	var player_data = GameCore.get_player_data()

	# 檢查是否可以攻擊
	if not _can_attack_city(city_id, player_data):
		return {"success": false, "error": "cannot_attack"}

	# 創建戰鬥計劃
	var battle_plan = _create_manual_battle_plan(city_data, player_data)
	if battle_plan.is_empty():
		return {"success": false, "error": "insufficient_resources"}

	# 發起戰鬥
	var result = _execute_city_siege(city_id, battle_plan)

	LogManager.info("BattleAutomationController", "手動攻擊發起", {
		"city_id": city_id,
		"city_name": city_data.get("name", ""),
		"success": result.get("success", false)
	})

	return result

# === 自動戰鬥邏輯 ===

# 檢查戰鬥機會
func _check_for_battle_opportunities() -> void:
	if not automation_active or not auto_battle_manager:
		return

	if current_battles.size() >= max_concurrent_battles:
		LogManager.debug("BattleAutomationController", "達到最大並發戰鬥數量")
		return

	var player_data = GameCore.get_player_data()

	# 更新AutoBattleManager的城池列表
	_update_available_cities()

	# 創建戰鬥計劃
	var battle_plan = auto_battle_manager.create_battle_plan(player_data)
	if battle_plan.is_empty():
		LogManager.debug("BattleAutomationController", "無可用戰鬥計劃")
		return

	var target_city = battle_plan.get("target_city", {})
	var city_id = target_city.get("id", "")

	if city_id.is_empty():
		return

	# 執行自動戰鬥
	var result = _execute_city_siege(city_id, battle_plan)

	if result.get("success", false):
		LogManager.info("BattleAutomationController", "自動戰鬥發起成功", {
			"city_id": city_id,
			"city_name": target_city.get("name", ""),
			"estimated_duration": battle_plan.get("expected_duration", 0)
		})

		city_attack_initiated.emit(city_id, battle_plan)

# 更新可用城池列表
func _update_available_cities() -> void:
	if not auto_battle_manager or not city_manager:
		return

	auto_battle_manager.available_cities = city_manager.cities_data.duplicate()

# 執行城池圍攻
func _execute_city_siege(city_id: String, battle_plan: Dictionary) -> Dictionary:
	if not city_manager:
		return {"success": false, "error": "city_manager_not_ready"}

	# 構建攻擊力量
	var attacking_force = _build_attacking_force(battle_plan)

	# 發起圍攻
	var siege_result = city_manager.start_city_siege(city_id, attacking_force)

	if siege_result.get("success", false):
		# 記錄當前戰鬥
		current_battles[city_id] = {
			"battle_plan": battle_plan,
			"start_time": Time.get_unix_time_from_system(),
			"siege_duration": siege_result.get("siege_duration", 7),
			"attacking_force": attacking_force
		}

		# 設置戰鬥完成計時器
		_schedule_battle_completion(city_id, siege_result.get("siege_duration", 7))

	return siege_result

# 構建攻擊力量
func _build_attacking_force(battle_plan: Dictionary) -> Dictionary:
	var player_data = GameCore.get_player_data()
	var allocated_troops = battle_plan.get("allocated_troops", 1000)
	var estimated_cost = battle_plan.get("estimated_cost", {})

	return {
		"troops": allocated_troops,
		"gold": estimated_cost.get("gold", 1000),
		"siege_power": allocated_troops + player_data.get("attributes", {}).get("武力", 20) * 10,
		"commander": {
			"name": "玩家",
			"attributes": player_data.get("attributes", {}),
			"level": player_data.get("level", 1)
		}
	}

# 安排戰鬥完成
func _schedule_battle_completion(city_id: String, duration_days: int) -> void:
	# 在閒置遊戲中，我們加速戰鬥過程
	var actual_duration = duration_days * 60.0  # 每天=1分鐘

	await get_tree().create_timer(actual_duration).timeout
	_complete_city_siege(city_id)

# 完成城池圍攻
func _complete_city_siege(city_id: String) -> void:
	if not current_battles.has(city_id):
		return

	var battle_info = current_battles[city_id]
	var city_data = city_manager.get_city_data(city_id)

	# 執行圍攻結果
	var conquest_result = city_manager.execute_city_conquest(city_id)

	if conquest_result.get("success", false):
		# 征服成功
		_handle_conquest_success(city_id, conquest_result, battle_info)
	else:
		# 征服失敗
		_handle_conquest_failure(city_id, conquest_result, battle_info)

	# 從當前戰鬥中移除
	current_battles.erase(city_id)

	# 更新地圖顯示
	_update_map_display()

# 處理征服成功
func _handle_conquest_success(city_id: String, result: Dictionary, battle_info: Dictionary) -> void:
	var spoils = result.get("spoils", {})

	# 更新玩家資源
	GameCore.add_resources(spoils)

	# 發送事件
	var city_data = city_manager.get_city_data(city_id)
	EventBus.city_conquered.emit(city_data.get("name", ""), "player", spoils)

	LogManager.game_event("AutoConquest", "自動征服成功", {
		"city": city_data.get("name", ""),
		"spoils": spoils,
		"duration": Time.get_unix_time_from_system() - battle_info.get("start_time", 0)
	})

# 處理征服失敗
func _handle_conquest_failure(city_id: String, result: Dictionary, battle_info: Dictionary) -> void:
	var losses = result.get("losses", {})

	# 扣除損失
	GameCore.subtract_resources(losses)

	LogManager.game_event("AutoConquest", "自動征服失敗", {
		"city": city_manager.get_city_data(city_id).get("name", ""),
		"losses": losses,
		"duration": Time.get_unix_time_from_system() - battle_info.get("start_time", 0)
	})

# 更新地圖顯示
func _update_map_display() -> void:
	if map_area and map_area.has_method("update_city_states"):
		map_area.update_city_states()

# === 輔助方法 ===

# 檢查是否可以攻擊城池
func _can_attack_city(city_id: String, player_data: Dictionary) -> bool:
	if city_id in current_battles:
		return false

	if not city_manager:
		return false

	var city_state = city_manager.get_city_state(city_id)
	if city_state.get("owner") == "player":
		return false

	if city_state.get("under_siege", false):
		return false

	return true

# 創建手動戰鬥計劃
func _create_manual_battle_plan(city_data: Dictionary, player_data: Dictionary) -> Dictionary:
	if not auto_battle_manager:
		return {}

	# 使用AutoBattleManager的邏輯創建戰鬥計劃
	var plan = {
		"target_city": city_data,
		"allocated_troops": auto_battle_manager.calculate_optimal_troop_allocation(city_data, player_data),
		"estimated_cost": auto_battle_manager.calculate_conquest_cost(city_data, player_data),
		"success_probability": auto_battle_manager.calculate_conquest_success_rate(city_data, player_data),
		"expected_duration": auto_battle_manager.calculate_battle_duration(city_data, player_data),
		"expected_rewards": auto_battle_manager.calculate_expected_rewards(city_data)
	}

	# 檢查資源可用性
	if not auto_battle_manager.check_resource_availability(player_data, plan.estimated_cost):
		return {}

	return plan

# 獲取自動化配置
func _get_automation_config() -> Dictionary:
	return {
		"target_selection": {
			"min_success_rate": 0.4,
			"prefer_efficiency": true,
			"aggression_level": "balanced"
		},
		"resource_management": {
			"min_gold_reserve": 1000,
			"min_troops_reserve": 500,
			"auto_upgrade_threshold": 5000
		},
		"offline_progression": {
			"max_offline_hours": 24,
			"diminishing_returns_start": 8,
			"diminishing_returns_rate": 0.1,
			"max_battle_attempts_per_hour": 6
		}
	}

# === 事件處理器 ===

func _on_battle_timer_timeout() -> void:
	_check_for_battle_opportunities()

func _on_battle_check_timeout() -> void:
	# 更新戰鬥進度
	_update_battle_progress()

func _update_battle_progress() -> void:
	for city_id in current_battles:
		var battle_info = current_battles[city_id]
		var elapsed_time = Time.get_unix_time_from_system() - battle_info.get("start_time", 0)
		var total_duration = battle_info.get("siege_duration", 7) * 60.0  # 轉換為秒
		var progress = min(elapsed_time / total_duration, 1.0)

		battle_progress_updated.emit({
			"city_id": city_id,
			"progress": progress,
			"elapsed_time": elapsed_time,
			"estimated_completion": battle_info.get("start_time", 0) + total_duration
		})

func _on_game_state_changed(new_state: int, old_state: int) -> void:
	match new_state:
		GameStateManager.GameState.GAME_RUNNING:
			if auto_battle_enabled and not automation_active:
				start_automation()
		GameStateManager.GameState.PAUSED:
			if automation_active:
				stop_automation()

func _on_main_game_started() -> void:
	# 主遊戲開始時自動啟動戰鬥自動化
	if auto_battle_enabled:
		start_automation()

func _on_city_selected(city_id: String, city_data: Dictionary) -> void:
	# 城池被選中時的處理邏輯
	LogManager.debug("BattleAutomationController", "城池被選中", {
		"city_id": city_id,
		"city_name": city_data.get("name", "")
	})

func _on_city_conquered(city_name: String, new_owner: String, spoils: Dictionary) -> void:
	LogManager.debug("BattleAutomationController", "收到城池征服事件", {
		"city": city_name,
		"owner": new_owner
	})

func _on_city_manager_conquest(city_id: String, victor: String, spoils: Dictionary) -> void:
	# CityManager征服事件處理
	_update_map_display()

func _on_battle_completed(result: Dictionary, victor: String, casualties: Dictionary) -> void:
	LogManager.debug("BattleAutomationController", "戰鬥完成", {
		"victor": victor
	})

# === 公共查詢方法 ===

# 檢查自動化是否激活
func is_automation_active() -> bool:
	return automation_active

# 獲取當前戰鬥狀態
func get_current_battles() -> Dictionary:
	return current_battles.duplicate()

# 獲取戰鬥統計
func get_battle_statistics() -> Dictionary:
	var stats = {
		"automation_active": automation_active,
		"current_battles": current_battles.size(),
		"max_concurrent": max_concurrent_battles,
		"battle_interval": battle_interval
	}

	if auto_battle_manager:
		var auto_stats = auto_battle_manager.get_automation_statistics()
		stats.merge(auto_stats)

	return stats

# 設置戰鬥間隔
func set_battle_interval(interval: float) -> void:
	battle_interval = interval
	if battle_timer:
		battle_timer.wait_time = interval

# 設置最大並發戰鬥數
func set_max_concurrent_battles(max_battles: int) -> void:
	max_concurrent_battles = max_battles