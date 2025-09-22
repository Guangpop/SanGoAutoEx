# GameEventManager.gd - 遊戲事件顯示系統
#
# 功能：
# - 接收並格式化所有遊戲事件
# - 分類顯示事件 (戰鬥/普通/特殊)
# - 自動滾動到最新事件
# - 管理事件歷史和數量限制

extends Node

# 事件類型定義
enum EventType {
	NORMAL,		# 普通事件 (藍色)
	BATTLE,		# 戰鬥事件 (紅色)
	SPECIAL,	# 特殊事件 (金色)
	SYSTEM,		# 系統事件 (灰色)
	WARNING,	# 警告事件 (橙色)
	ERROR,		# 錯誤事件 (深紅色)
	SUCCESS,	# 成功事件 (綠色)
	DIPLOMACY,	# 外交事件 (紫色)
	ECONOMY,	# 經濟事件 (黃色)
	TECHNOLOGY	# 科技事件 (青色)
}

# 事件類型顏色配置
var event_colors = {
	EventType.NORMAL: Color.LIGHT_BLUE,
	EventType.BATTLE: Color.LIGHT_CORAL,
	EventType.SPECIAL: Color.GOLD,
	EventType.SYSTEM: Color.LIGHT_GRAY,
	EventType.WARNING: Color.ORANGE,
	EventType.ERROR: Color.CRIMSON,
	EventType.SUCCESS: Color.LIME_GREEN,
	EventType.DIPLOMACY: Color.VIOLET,
	EventType.ECONOMY: Color.YELLOW,
	EventType.TECHNOLOGY: Color.CYAN
}

# UI引用
var event_container: VBoxContainer = null
var scroll_container: ScrollContainer = null
var main_mobile: Control = null

# 配置
var max_events: int = 100
var auto_scroll: bool = true
var show_timestamps: bool = true

# 私有變量
var event_count: int = 0
var is_initialized: bool = false

func _ready() -> void:
	name = "GameEventManager"
	LogManager.info("GameEventManager", "遊戲事件顯示系統初始化開始")

	# 等待場景準備完成
	await get_tree().process_frame
	await get_tree().process_frame

	# 嘗試連接UI
	_connect_to_ui()

	# 連接EventBus事件
	_connect_event_handlers()

	is_initialized = true
	LogManager.info("GameEventManager", "遊戲事件顯示系統初始化完成", {
		"ui_connected": event_container != null,
		"max_events": max_events,
		"auto_scroll": auto_scroll
	})

	# 添加測試事件以驗證系統工作
	_add_test_events()

# 連接到UI組件
func _connect_to_ui() -> void:
	# 尋找MainMobile場景中的EventContent
	main_mobile = get_tree().get_first_node_in_group("main_mobile")
	if not main_mobile:
		# 嘗試通過路徑查找
		var root = get_tree().current_scene
		if root and root.name == "MainMobile":
			main_mobile = root

	if main_mobile:
		# 使用UIManager接口而不是直接節點路徑
		var ui_manager = main_mobile.get_ui_manager() if main_mobile.has_method("get_ui_manager") else null

		if ui_manager:
			event_container = ui_manager.get_event_container()
			scroll_container = main_mobile.get_node_or_null("SafeAreaContainer/VBoxContainer/GameMainArea/GameEventOverlay/GameEvent")

			if event_container:
				LogManager.info("GameEventManager", "UI連接成功 (通過UIManager)", {
					"event_container_found": true,
					"scroll_container_found": scroll_container != null,
					"ui_manager_available": true
				})

				# 添加初始歡迎訊息
				_add_welcome_message()
			else:
				LogManager.warn("GameEventManager", "UIManager未能提供EventContent容器", {
					"main_mobile_found": true,
					"ui_manager_found": true,
					"event_container_result": null
				})
		else:
			# 降級到舊的直接路徑方式 (臨時相容性)
			event_container = main_mobile.get_node_or_null("SafeAreaContainer/VBoxContainer/GameMainArea/GameEventOverlay/GameEvent/EventContent")
			scroll_container = main_mobile.get_node_or_null("SafeAreaContainer/VBoxContainer/GameMainArea/GameEventOverlay/GameEvent")

			if event_container:
				LogManager.info("GameEventManager", "UI連接成功 (降級模式)", {
					"event_container_found": true,
					"scroll_container_found": scroll_container != null,
					"ui_manager_available": false
				})

				# 添加初始歡迎訊息
				_add_welcome_message()
			else:
				LogManager.warn("GameEventManager", "未找到EventContent容器", {
					"main_mobile_found": true,
					"container_path": "SafeAreaContainer/VBoxContainer/GameMainArea/GameEventOverlay/GameEvent/EventContent"
			})
	else:
		LogManager.warn("GameEventManager", "未找到MainMobile場景")

# 添加歡迎訊息
func _add_welcome_message() -> void:
	# 等待系統完全初始化後再添加訊息
	await get_tree().create_timer(0.1).timeout
	if is_initialized:
		add_event("歡迎進入三國天命放置小遊戲！", EventType.SYSTEM)
		add_event("系統初始化完成，開始你的征程...", EventType.NORMAL)

# 連接EventBus事件處理器
func _connect_event_handlers() -> void:
	LogManager.info("GameEventManager", "開始連接事件處理器")

	var connection_results = {}

	# 遊戲狀態事件
	connection_results["game_state_changed"] = EventBus.connect_safe("game_state_changed", _on_game_state_changed)
	connection_results["game_initialized"] = EventBus.connect_safe("game_initialized", _on_game_initialized)
	connection_results["turn_completed"] = EventBus.connect_safe("turn_completed", _on_turn_completed)

	# 玩家事件
	connection_results["player_level_up"] = EventBus.connect_safe("player_level_up", _on_player_level_up)
	connection_results["player_experience_gained"] = EventBus.connect_safe("player_experience_gained", _on_player_experience_gained)

	# 技能事件
	connection_results["skill_selected"] = EventBus.connect_safe("skill_selected", _on_skill_selected)
	connection_results["skill_selection_completed"] = EventBus.connect_safe("skill_selection_completed", _on_skill_selection_completed)
	connection_results["star_converted_to_attributes"] = EventBus.connect_safe("star_converted_to_attributes", _on_star_converted)

	# 戰鬥事件
	connection_results["battle_started"] = EventBus.connect_safe("battle_started", _on_battle_started)
	connection_results["battle_completed"] = EventBus.connect_safe("battle_completed", _on_battle_completed)
	connection_results["city_conquered"] = EventBus.connect_safe("city_conquered", _on_city_conquered)

	# 資源事件
	connection_results["resources_changed"] = EventBus.connect_safe("resources_changed", _on_resources_changed)
	connection_results["equipment_acquired"] = EventBus.connect_safe("equipment_acquired", _on_equipment_acquired)

	# 隨機事件
	connection_results["random_event_triggered"] = EventBus.connect_safe("random_event_triggered", _on_random_event)
	connection_results["event_choice_made"] = EventBus.connect_safe("event_choice_made", _on_event_choice)

	var successful_connections = 0
	var total_connections = connection_results.size()

	for event_name in connection_results:
		if connection_results[event_name]:
			successful_connections += 1

	LogManager.info("GameEventManager", "事件處理器連接完成", {
		"total_connections": total_connections,
		"successful_connections": successful_connections,
		"connection_success_rate": float(successful_connections) / float(total_connections),
		"connection_results": connection_results
	})

# 公共方法：添加事件
func add_event(message: String, event_type: EventType = EventType.NORMAL, additional_data: Dictionary = {}) -> void:
	if not is_initialized:
		LogManager.warn("GameEventManager", "嘗試添加事件但系統未初始化", {
			"message": message,
			"event_type": event_type
		})
		return

	# 嘗試使用UIManager接口
	var ui_manager = null
	if main_mobile and main_mobile.has_method("get_ui_manager"):
		ui_manager = main_mobile.get_ui_manager()

	if ui_manager and ui_manager.has_method("add_game_event"):
		# 使用UIManager統一接口
		var event_data = {
			"message": message,
			"type": _convert_event_type_to_string(event_type),
			"metadata": additional_data
		}

		var success = ui_manager.add_game_event(event_data)
		if success:
			event_count += 1
			LogManager.debug("GameEventManager", "事件已添加 (通過UIManager)", {
				"message": message,
				"event_type": EventType.keys()[event_type],
				"event_count": event_count
			})
		else:
			LogManager.error("GameEventManager", "UIManager添加事件失敗", {"event_data": event_data})
	else:
		# 降級到舊方式 (直接操作容器)
		_add_event_legacy(message, event_type, additional_data)

## 降級方法 - 舊的直接容器操作
func _add_event_legacy(message: String, event_type: EventType, additional_data: Dictionary) -> void:
	if not event_container:
		LogManager.warn("GameEventManager", "EventContainer不可用，無法添加事件", {
			"message": message
		})
		return

	# 創建事件標籤
	var event_label = Label.new()

	# 設置事件文本
	var timestamp = ""
	if show_timestamps:
		var time = Time.get_datetime_dict_from_system()
		timestamp = "[%02d:%02d:%02d] " % [time.hour, time.minute, time.second]

	event_label.text = timestamp + message

	# 設置樣式
	event_label.modulate = event_colors[event_type]
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_label.custom_minimum_size = Vector2(340, 24)  # 設定最小寬度340px，高度24px
	event_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# 添加到容器
	event_container.add_child(event_label)
	event_count += 1

	# 限制事件數量
	_cleanup_old_events()

	# 自動滾動到底部
	if auto_scroll and scroll_container:
		await get_tree().process_frame
		scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

	LogManager.debug("GameEventManager", "事件已添加 (降級模式)", {
		"message": message,
		"event_type": EventType.keys()[event_type],
		"event_count": event_count
	})

## 轉換事件類型為字串
func _convert_event_type_to_string(event_type: EventType) -> String:
	match event_type:
		EventType.NORMAL: return "info"
		EventType.WARNING: return "warning"
		EventType.ERROR: return "error"
		EventType.SUCCESS: return "success"
		EventType.BATTLE: return "battle"
		EventType.DIPLOMACY: return "diplomacy"
		EventType.ECONOMY: return "economy"
		EventType.TECHNOLOGY: return "technology"
		_: return "info"

# 清理舊事件
func _cleanup_old_events() -> void:
	if event_count > max_events:
		var children = event_container.get_children()
		var excess_count = event_count - max_events

		for i in range(excess_count):
			if i < children.size():
				children[i].queue_free()
				event_count -= 1

# === 事件處理器 ===

func _on_game_state_changed(new_state: int, old_state: int) -> void:
	var state_names = ["主選單", "技能選擇", "主遊戲", "戰鬥", "暫停"]
	var old_name = state_names[old_state] if old_state < state_names.size() else "未知"
	var new_name = state_names[new_state] if new_state < state_names.size() else "未知"

	add_event("遊戲狀態：%s → %s" % [old_name, new_name], EventType.SYSTEM)

func _on_game_initialized() -> void:
	add_event("遊戲系統初始化完成", EventType.SYSTEM)

func _on_turn_completed(turn_data: Dictionary) -> void:
	var turn_num = turn_data.get("turn", 0)
	var resources = turn_data.get("resources", {})

	var resource_text = ""
	if resources.has("gold"):
		resource_text += "金錢+%d " % resources.gold
	if resources.has("troops"):
		resource_text += "部隊+%d" % resources.troops

	add_event("第%d回合完成 %s" % [turn_num, resource_text], EventType.NORMAL)

func _on_player_level_up(new_level: int, attribute_gains: Dictionary) -> void:
	add_event("恭喜！您升級到 Lv.%d" % new_level, EventType.SPECIAL)

	var gain_text = ""
	for attr in attribute_gains:
		if gain_text != "":
			gain_text += ", "
		gain_text += "%s+%d" % [attr, attribute_gains[attr]]

	if gain_text != "":
		add_event("屬性提升：%s" % gain_text, EventType.SPECIAL)

func _on_player_experience_gained(amount: int, source: String) -> void:
	add_event("獲得經驗 +%d (%s)" % [amount, source], EventType.NORMAL)

func _on_skill_selected(skill_data: Dictionary, remaining_stars: int) -> void:
	var skill_name = skill_data.get("name", "未知技能")
	add_event("學習技能：%s (剩餘星星：%d)" % [skill_name, remaining_stars], EventType.SPECIAL)

func _on_skill_selection_completed(selected_skills: Array, remaining_stars: int) -> void:
	if selected_skills.size() > 0:
		add_event("技能選擇完成，共學會 %d 個技能" % selected_skills.size(), EventType.SYSTEM)
	else:
		add_event("技能選擇完成，準備開始主遊戲", EventType.SYSTEM)

func _on_star_converted(stars_converted: int, attributes_gained: Dictionary) -> void:
	var gain_text = ""
	for attr in attributes_gained:
		if gain_text != "":
			gain_text += ", "
		gain_text += "%s+%d" % [attr, attributes_gained[attr]]

	add_event("星星轉換：%d顆星星 → %s" % [stars_converted, gain_text], EventType.SPECIAL)

func _on_battle_started(attacker: Dictionary, defender: Dictionary, city_name: String) -> void:
	var attacker_name = attacker.get("name", "未知")
	var defender_name = defender.get("name", "未知")
	add_event("戰鬥開始：%s vs %s (%s)" % [attacker_name, defender_name, city_name], EventType.BATTLE)

func _on_battle_completed(result: Dictionary, victor: String, casualties: Dictionary) -> void:
	add_event("戰鬥結束：%s 獲勝" % victor, EventType.BATTLE)

func _on_city_conquered(city_name: String, new_owner: String, spoils: Dictionary) -> void:
	add_event("城池攻克：%s 被 %s 占領" % [city_name, new_owner], EventType.BATTLE)

func _on_resources_changed(resource_type: String, old_amount: int, new_amount: int) -> void:
	var change = new_amount - old_amount
	var change_text = "+%d" % change if change > 0 else "%d" % change
	# 只顯示重要的資源變化，避免過於頻繁的事件
	if abs(change) >= 50:  # 只顯示變化較大的資源事件
		add_event("%s %s (總計: %d)" % [resource_type, change_text, new_amount], EventType.NORMAL)

func _on_equipment_acquired(equipment_data: Dictionary, source: String) -> void:
	var equipment_name = equipment_data.get("name", "未知裝備")
	add_event("獲得裝備：%s (%s)" % [equipment_name, source], EventType.SPECIAL)

func _on_random_event(event_data: Dictionary, tianming_modifier: float) -> void:
	var event_name = event_data.get("name", "隨機事件")
	add_event("隨機事件：%s" % event_name, EventType.SPECIAL)

func _on_event_choice(event_id: String, choice_index: int, consequences: Dictionary) -> void:
	add_event("事件選擇完成", EventType.NORMAL)

# 公共方法：清空所有事件
func clear_all_events() -> void:
	if event_container:
		for child in event_container.get_children():
			child.queue_free()
		event_count = 0
		LogManager.info("GameEventManager", "所有事件已清空")

# 公共方法：設置自動滾動
func set_auto_scroll(enabled: bool) -> void:
	auto_scroll = enabled
	LogManager.info("GameEventManager", "自動滾動設置", {"enabled": enabled})

# 公共方法：設置時間戳顯示
func set_show_timestamps(enabled: bool) -> void:
	show_timestamps = enabled
	LogManager.info("GameEventManager", "時間戳顯示設置", {"enabled": enabled})

# 添加測試事件以驗證系統
func _add_test_events() -> void:
	await get_tree().create_timer(0.2).timeout
	add_event("GameEventManager 測試事件：系統運行正常", EventType.SYSTEM)

	await get_tree().create_timer(1.0).timeout
	add_event("測試普通事件：資源生產開始", EventType.NORMAL)

	await get_tree().create_timer(1.0).timeout
	add_event("測試特殊事件：發現寶物", EventType.SPECIAL)

	await get_tree().create_timer(1.0).timeout
	add_event("測試戰鬥事件：敵軍來襲", EventType.BATTLE)