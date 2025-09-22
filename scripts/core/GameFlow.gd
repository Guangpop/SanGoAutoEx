# GameFlow.gd - 放置遊戲流程控制器
#
# 功能：
# - 協調技能選擇到放置遊戲的轉換
# - 管理放置遊戲的自動化流程
# - 處理遊戲勝利和失敗條件
# - 離線進度恢復

extends Node

# 核心系統引用
var auto_battle_manager: Node
var game_state_manager: Node
var data_manager: Node

# 遊戲流程狀態
var is_idle_game_active: bool = false
var game_start_time: float = 0.0
var last_save_time: float = 0.0

# 自動存檔設置
var auto_save_interval: float = 300.0  # 5分鐘自動存檔
var auto_save_timer: Timer

func _ready() -> void:
	name = "GameFlow"

	# 延遲初始化，等待其他系統加載
	call_deferred("initialize_game_flow")

func initialize_game_flow() -> void:
	# 獲取系統引用
	auto_battle_manager = get_node_or_null("/root/AutoBattleManager")
	game_state_manager = get_node_or_null("/root/GameStateManager")
	data_manager = get_node_or_null("/root/DataManager")

	if not auto_battle_manager:
		LogManager.error("GameFlow", "無法找到 AutoBattleManager")
		return

	if not game_state_manager:
		LogManager.error("GameFlow", "無法找到 GameStateManager")
		return

	# 設置自動存檔計時器
	setup_auto_save_timer()

	# 連接事件處理器
	connect_event_handlers()

	LogManager.info("GameFlow", "遊戲流程控制器初始化完成")

func setup_auto_save_timer() -> void:
	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = auto_save_interval
	auto_save_timer.timeout.connect(_on_auto_save_timer_timeout)
	auto_save_timer.one_shot = false
	add_child(auto_save_timer)

func connect_event_handlers() -> void:
	# 連接EventBus事件
	EventBus.connect_safe("skill_selection_completed", _on_skill_selection_completed)
	EventBus.connect_safe("game_state_changed", _on_game_state_changed)
	EventBus.connect_safe("game_victory", _on_game_victory)
	EventBus.connect_safe("game_over", _on_game_over)
	EventBus.connect_safe("idle_game_loop_started", _on_idle_game_loop_started)
	EventBus.connect_safe("idle_game_loop_stopped", _on_idle_game_loop_stopped)

	LogManager.debug("GameFlow", "事件處理器連接完成")

# === 遊戲流程控制 ===

# 開始新遊戲
func start_new_game() -> void:
	LogManager.info("GameFlow", "開始新遊戲")

	# 重置遊戲狀態
	is_idle_game_active = false
	game_start_time = Time.get_unix_time_from_system()
	last_save_time = game_start_time

	# 轉換到技能選擇狀態
	if game_state_manager:
		game_state_manager.change_state(GameStateManager.GameState.SKILL_SELECTION, "新遊戲開始")

	EventBus.emit_safe("main_game_started")

# 載入已存在的遊戲
func load_existing_game(save_data: Dictionary) -> void:
	LogManager.info("GameFlow", "載入存檔遊戲")

	# 檢查是否需要計算離線進度
	var last_play_time = save_data.get("last_play_time", 0.0)
	var current_time = Time.get_unix_time_from_system()
	var offline_hours = (current_time - last_play_time) / 3600.0

	if offline_hours > 0.1:  # 超過6分鐘視為離線
		LogManager.info("GameFlow", "檢測到離線時間", {"offline_hours": offline_hours})
		calculate_and_apply_offline_progress(save_data, offline_hours)

	# 直接進入遊戲運行狀態
	is_idle_game_active = true
	game_start_time = save_data.get("game_start_time", current_time)
	last_save_time = current_time

	if game_state_manager:
		game_state_manager.change_state(GameStateManager.GameState.GAME_RUNNING, "載入存檔")

	# 啟動放置遊戲循環
	start_idle_game_automation()

# 計算並應用離線進度
func calculate_and_apply_offline_progress(save_data: Dictionary, offline_hours: float) -> void:
	if not auto_battle_manager:
		return

	# 初始化自動戰鬥管理器
	var player_data = save_data.get("player_data", {})
	var automation_config = save_data.get("automation_config", {})

	auto_battle_manager.initialize(player_data, automation_config)

	# 設置戰鬥歷史以便正確計算難度
	auto_battle_manager.battles_completed = save_data.get("battles_completed", 0)
	auto_battle_manager.automation_statistics = save_data.get("automation_statistics", {})

	# 計算離線進度
	var offline_progress = auto_battle_manager.calculate_offline_progress(player_data, offline_hours)

	# 應用離線進度
	auto_battle_manager.apply_offline_progress(offline_progress, player_data)

	# 顯示離線進度給玩家
	show_offline_progress_summary(offline_progress, offline_hours)

	LogManager.info("GameFlow", "離線進度已應用", {
		"offline_hours": offline_hours,
		"battles_fought": offline_progress.get("battles_fought", 0),
		"cities_conquered": offline_progress.get("cities_conquered", 0)
	})

# 顯示離線進度摘要
func show_offline_progress_summary(progress: Dictionary, offline_hours: float) -> void:
	var summary_text = "離線進度摘要:\n"
	summary_text += "離線時間: %.1f 小時\n" % offline_hours
	summary_text += "戰鬥次數: %d 場\n" % progress.get("battles_fought", 0)
	summary_text += "獲得金錢: %d\n" % progress.get("resources_gained", {}).get("gold", 0)
	summary_text += "征服城池: %d 座\n" % progress.get("cities_conquered", 0)

	# 添加特殊事件
	var events = progress.get("progression_events", [])
	if events.size() > 0:
		summary_text += "\n特殊事件:\n"
		for event in events:
			summary_text += "• " + str(event) + "\n"

	# 通過UI系統顯示摘要
	EventBus.emit_safe("ui_notification_requested", [summary_text, "offline_progress", 8.0])

# 啟動放置遊戲自動化
func start_idle_game_automation() -> void:
	if not auto_battle_manager:
		LogManager.error("GameFlow", "無法啟動自動化：AutoBattleManager 未找到")
		return

	if is_idle_game_active:
		LogManager.warn("GameFlow", "放置遊戲已經在運行中")
		return

	LogManager.info("GameFlow", "啟動放置遊戲自動化")

	# 確保AutoBattleManager已初始化
	if not auto_battle_manager.is_initialized():
		var player_data = GameCore.get_player_data() if GameCore else {}
		auto_battle_manager.initialize(player_data, {})

	# 啟動自動戰鬥循環
	auto_battle_manager.start_idle_game_loop()

	is_idle_game_active = true

	# 開始自動存檔
	auto_save_timer.start()

# 停止放置遊戲自動化
func stop_idle_game_automation() -> void:
	if not is_idle_game_active:
		return

	LogManager.info("GameFlow", "停止放置遊戲自動化")

	if auto_battle_manager:
		auto_battle_manager.stop_idle_game_loop()

	is_idle_game_active = false

	# 停止自動存檔
	auto_save_timer.stop()

# 暫停遊戲
func pause_game() -> void:
	if game_state_manager:
		game_state_manager.change_state(GameStateManager.GameState.PAUSED, "用戶暫停")

	if auto_battle_manager:
		auto_battle_manager.pause_automation("user_paused")

	LogManager.info("GameFlow", "遊戲已暫停")

# 恢復遊戲
func resume_game() -> void:
	if game_state_manager:
		game_state_manager.change_state(GameStateManager.GameState.GAME_RUNNING, "用戶恢復")

	if auto_battle_manager:
		auto_battle_manager.resume_automation()

	LogManager.info("GameFlow", "遊戲已恢復")

# === 事件處理器 ===

func _on_skill_selection_completed(selected_skills: Array, remaining_stars: int) -> void:
	LogManager.info("GameFlow", "技能選擇完成，準備進入放置遊戲", {
		"skills_count": selected_skills.size(),
		"remaining_stars": remaining_stars
	})

	# 轉換到遊戲運行狀態
	if game_state_manager:
		game_state_manager.change_state(GameStateManager.GameState.GAME_RUNNING, "技能選擇完成")

	# 延遲啟動自動化，給系統時間準備
	var delay_timer = Timer.new()
	delay_timer.wait_time = 1.0
	delay_timer.one_shot = true
	delay_timer.timeout.connect(start_idle_game_automation)
	add_child(delay_timer)
	delay_timer.start()

func _on_game_state_changed(new_state: int, old_state: int) -> void:
	var new_state_name = GameStateManager.STATE_NAMES.get(new_state, "未知狀態")
	var old_state_name = GameStateManager.STATE_NAMES.get(old_state, "未知狀態")

	LogManager.debug("GameFlow", "遊戲狀態變更", {
		"from": old_state_name,
		"to": new_state_name
	})

	# 根據狀態變更調整自動化
	match new_state:
		GameStateManager.GameState.GAME_RUNNING:
			if old_state == GameStateManager.GameState.PAUSED:
				resume_game()
		GameStateManager.GameState.PAUSED:
			if is_idle_game_active:
				pause_game()
		GameStateManager.GameState.MENU:
			stop_idle_game_automation()

func _on_game_victory() -> void:
	LogManager.info("GameFlow", "遊戲勝利！")

	# 停止自動化
	stop_idle_game_automation()

	# 轉換到遊戲結束狀態
	if game_state_manager:
		game_state_manager.change_state(GameStateManager.GameState.GAME_OVER, "遊戲勝利")

	# 觸發勝利UI
	EventBus.emit_safe("ui_notification_requested", [
		"🏆 恭喜！您已征服了所有城池，統一天下！",
		"victory",
		10.0
	])

	# 保存最終遊戲數據
	save_game("victory_save")

func _on_game_over(reason: String) -> void:
	LogManager.info("GameFlow", "遊戲結束", {"reason": reason})

	# 停止自動化
	stop_idle_game_automation()

	# 轉換到遊戲結束狀態
	if game_state_manager:
		game_state_manager.change_state(GameStateManager.GameState.GAME_OVER, reason)

	# 觸發失敗UI
	var failure_message = "💔 遊戲結束：" + reason
	EventBus.emit_safe("ui_notification_requested", [failure_message, "defeat", 8.0])

func _on_idle_game_loop_started() -> void:
	LogManager.debug("GameFlow", "放置遊戲循環已啟動")

func _on_idle_game_loop_stopped() -> void:
	LogManager.debug("GameFlow", "放置遊戲循環已停止")

# === 存檔系統整合 ===

func _on_auto_save_timer_timeout() -> void:
	if is_idle_game_active:
		save_game("auto_save")

func save_game(save_type: String = "manual") -> void:
	if not GameCore:
		LogManager.error("GameFlow", "無法存檔：GameCore 未找到")
		return

	var save_data = {
		"player_data": GameCore.get_player_data(),
		"game_start_time": game_start_time,
		"last_play_time": Time.get_unix_time_from_system(),
		"battles_completed": auto_battle_manager.battles_completed if auto_battle_manager else 0,
		"automation_statistics": auto_battle_manager.automation_statistics if auto_battle_manager else {},
		"automation_config": auto_battle_manager.automation_config if auto_battle_manager else {},
		"save_type": save_type,
		"game_version": "1.0.0"
	}

	EventBus.emit_safe("save_requested", [0])  # 使用存檔槽位0
	last_save_time = Time.get_unix_time_from_system()

	LogManager.debug("GameFlow", "遊戲已保存", {"save_type": save_type})

# === 查詢方法 ===

func is_game_active() -> bool:
	return is_idle_game_active

func get_game_duration() -> float:
	return Time.get_unix_time_from_system() - game_start_time

func get_time_since_last_save() -> float:
	return Time.get_unix_time_from_system() - last_save_time

func get_game_statistics() -> Dictionary:
	var stats = {
		"game_duration": get_game_duration(),
		"is_active": is_idle_game_active,
		"time_since_save": get_time_since_last_save()
	}

	if auto_battle_manager:
		stats.merge(auto_battle_manager.get_automation_statistics())

	return stats