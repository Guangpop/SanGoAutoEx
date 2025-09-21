# MainMobile.gd - 移動端主介面控制器
#
# 功能：
# - 管理移動端UI佈局 (414x896)
# - 協調TopBar、MapArea、GameEvent、BottomBar
# - 處理觸控輸入和響應式設計

extends Control

# UI節點引用
@onready var top_bar = $VBoxContainer/TopBar
@onready var map_area = $VBoxContainer/GameMainArea/MapArea
@onready var game_event = $VBoxContainer/GameMainArea/GameEvent
@onready var event_content = $VBoxContainer/GameMainArea/GameEvent/EventContent
@onready var bottom_bar = $VBoxContainer/BottomBar
@onready var tab_container = $VBoxContainer/BottomBar/TabContainer

# TopBar UI 元素引用
@onready var name_level_label = $VBoxContainer/TopBar/TopBarContainer/PlayerInfo/BasicInfo/NameLevel
@onready var turn_year_label = $VBoxContainer/TopBar/TopBarContainer/PlayerInfo/BasicInfo/TurnYear
@onready var wuli_label = $VBoxContainer/TopBar/TopBarContainer/AbilityStats/AbilityRow1/Wuli
@onready var zhili_label = $VBoxContainer/TopBar/TopBarContainer/AbilityStats/AbilityRow1/Zhili
@onready var tongzhi_label = $VBoxContainer/TopBar/TopBarContainer/AbilityStats/AbilityRow1/Tongzhi
@onready var zhengzhi_label = $VBoxContainer/TopBar/TopBarContainer/AbilityStats/AbilityRow2/Zhengzhi
@onready var meili_label = $VBoxContainer/TopBar/TopBarContainer/AbilityStats/AbilityRow2/Meili
@onready var tianming_label = $VBoxContainer/TopBar/TopBarContainer/AbilityStats/AbilityRow2/Tianming
@onready var gold_label = $VBoxContainer/TopBar/TopBarContainer/Resources/Gold
@onready var troops_label = $VBoxContainer/TopBar/TopBarContainer/Resources/Troops
@onready var cities_label = $VBoxContainer/TopBar/TopBarContainer/Resources/Cities

# TopBar 折疊式設計相關
@onready var ability_stats_container = $VBoxContainer/TopBar/TopBarContainer/AbilityStats
var topbar_expanded: bool = false
var topbar_animating: bool = false
var topbar_collapsed_height: float = 90.0
var topbar_expanded_height: float = 180.0
var topbar_animation_duration: float = 0.3

# 觸控優化
var touch_feedback_tween: Tween

func _ready() -> void:
	var main_mobile_start_time = Time.get_unix_time_from_system()

	# 加入到群組以便其他系統找到
	add_to_group("main_mobile")

	LogManager.info("MainMobile", "移動端主介面初始化開始", {
		"screen_size": get_viewport().get_visible_rect().size,
		"scene_tree_ready": true,
		"initialization_timestamp": main_mobile_start_time,
		"autoload_order_check": "MainMobile _ready() called"
	})

	# 驗證UI節點完整性
	LogManager.debug("MainMobile", "開始UI節點驗證")
	_validate_ui_nodes()

	# 檢查核心系統初始化狀態
	var systems_initialized = GameCore.is_systems_initialized()
	LogManager.info("MainMobile", "檢查核心系統狀態", {
		"systems_initialized": systems_initialized,
		"gamecore_available": GameCore != null,
		"eventbus_available": EventBus != null
	})

	# 等待核心系統初始化完成
	if not systems_initialized:
		LogManager.info("MainMobile", "等待核心系統初始化", {
			"waiting_for": "GameCore.game_initialized",
			"wait_start_time": Time.get_unix_time_from_system()
		})
		await EventBus.game_initialized
		var wait_end_time = Time.get_unix_time_from_system()
		LogManager.info("MainMobile", "核心系統初始化完成", {
			"systems_ready": true,
			"wait_duration": wait_end_time - main_mobile_start_time
		})
	else:
		LogManager.info("MainMobile", "核心系統已經初始化，直接繼續", {
			"systems_already_ready": true
		})

	# 連接事件處理器
	LogManager.debug("MainMobile", "開始連接事件處理器")
	connect_event_handlers()

	# 初始化UI
	LogManager.debug("MainMobile", "開始UI初始化")
	initialize_ui()

	var total_init_time = Time.get_unix_time_from_system() - main_mobile_start_time

	LogManager.info("MainMobile", "移動端主介面初始化完成", {
		"initialization_successful": true,
		"ui_nodes_validated": true,
		"total_initialization_time": total_init_time,
		"ready_for_user_interaction": true
	})

	# 添加自動開始遊戲的機制（開發階段用）
	LogManager.info("MainMobile", "檢查是否需要自動開始遊戲", {
		"current_game_state": GameStateManager.get_current_state(),
		"auto_start_available": true
	})

	# 初始化TopBar折疊功能
	setup_topbar_collapsible()

	# 等待一小段時間讓所有系統穩定，然後自動開始新遊戲
	await get_tree().create_timer(1.0).timeout
	if GameStateManager.get_current_state() == GameStateManager.GameState.MENU:
		LogManager.info("MainMobile", "自動觸發新遊戲開始", {
			"trigger_reason": "system_ready_auto_start",
			"current_state": "MENU"
		})
		GameCore.start_new_game()

# 驗證UI節點完整性
func _validate_ui_nodes() -> void:
	var node_validation = {
		"top_bar": top_bar != null,
		"name_level_label": name_level_label != null,
		"map_area": map_area != null,
		"game_event": game_event != null,
		"event_content": event_content != null,
		"bottom_bar": bottom_bar != null,
		"tab_container": tab_container != null
	}

	var missing_nodes = []
	for node_name in node_validation:
		if not node_validation[node_name]:
			missing_nodes.append(node_name)

	if missing_nodes.is_empty():
		LogManager.info("MainMobile", "UI節點驗證通過", node_validation)
	else:
		LogManager.error("MainMobile", "UI節點缺失", {
			"missing_nodes": missing_nodes,
			"validation_result": node_validation
		})

func connect_event_handlers() -> void:
	LogManager.info("MainMobile", "開始連接事件處理器", {
		"handlers_to_connect": ["game_state_changed", "player_level_up", "turn_completed", "resources_changed"]
	})

	var connection_results = {}

	# 連接遊戲狀態變化事件
	var state_connection = EventBus.connect_safe("game_state_changed", _on_game_state_changed)
	connection_results["game_state_changed"] = state_connection

	# 連接玩家升級事件
	var level_connection = EventBus.connect_safe("player_level_up", _on_player_level_up)
	connection_results["player_level_up"] = level_connection

	# 連接回合完成事件
	var turn_connection = EventBus.connect_safe("turn_completed", _on_turn_completed)
	connection_results["turn_completed"] = turn_connection

	# 連接資源變化事件
	var resources_connection = EventBus.connect_safe("resources_changed", _on_resources_changed)
	connection_results["resources_changed"] = resources_connection

	LogManager.info("MainMobile", "事件處理器連接完成", {
		"connection_results": connection_results,
		"connections_successful": connection_results.values().all(func(x): return x)
	})

func initialize_ui() -> void:
	LogManager.info("MainMobile", "開始初始化UI", {
		"viewport_size": get_viewport().get_visible_rect().size,
		"initial_setup": true
	})

	# 設置初始UI狀態
	update_player_info()

	LogManager.info("MainMobile", "UI初始化完成", {
		"player_info_updated": true,
		"ui_ready": true
	})

func update_player_info() -> void:
	LogManager.debug("MainMobile", "更新玩家資訊開始")

	var player_data = GameCore.get_player_data()

	LogManager.debug("MainMobile", "獲取玩家數據", {
		"level": player_data.level,
		"game_turn": player_data.game_turn,
		"game_year": player_data.game_year,
		"attributes": player_data.get("attributes", {}),
		"resources": player_data.get("resources", {}),
		"data_valid": player_data != null
	})

	# 更新基本資訊
	if name_level_label:
		name_level_label.text = "玩家 Lv.%d" % player_data.level

	if turn_year_label:
		turn_year_label.text = "回合 %d | %d年" % [player_data.game_turn, player_data.game_year]

	# 更新能力值 (第一行: 武力/智力/統治)
	var attributes = player_data.get("attributes", {})
	if wuli_label:
		wuli_label.text = "武力: %d" % attributes.get("武力", 0)
	if zhili_label:
		zhili_label.text = "智力: %d" % attributes.get("智力", 0)
	if tongzhi_label:
		tongzhi_label.text = "統治: %d" % attributes.get("統治", 0)

	# 更新能力值 (第二行: 政治/魅力/天命)
	if zhengzhi_label:
		zhengzhi_label.text = "政治: %d" % attributes.get("政治", 0)
	if meili_label:
		meili_label.text = "魅力: %d" % attributes.get("魅力", 0)
	if tianming_label:
		tianming_label.text = "天命: %d" % attributes.get("天命", 0)

	# 更新資源
	var resources = player_data.get("resources", {})
	if gold_label:
		gold_label.text = "金 %d" % resources.get("gold", 0)
	if troops_label:
		troops_label.text = "兵 %d" % resources.get("troops", 0)
	if cities_label:
		cities_label.text = "城 %d" % resources.get("cities", 0)

	LogManager.debug("MainMobile", "TopBar玩家資訊更新完成", {
		"level": player_data.level,
		"turn": player_data.game_turn,
		"year": player_data.game_year,
		"attributes_updated": attributes.size(),
		"resources_updated": resources.size(),
		"ui_elements_valid": true
	})

# === TopBar 折疊式設計功能 ===

# 初始化TopBar折疊功能
func setup_topbar_collapsible() -> void:
	if not top_bar:
		LogManager.warn("MainMobile", "TopBar節點未找到，無法設置折疊功能")
		return

	# 設置初始狀態為折疊
	topbar_expanded = false
	top_bar.custom_minimum_size.y = topbar_collapsed_height

	# 初始隱藏能力值面板
	if ability_stats_container:
		ability_stats_container.visible = false

	# 增加觸控區域 - 讓PlayerInfo區域可點擊
	var player_info_area = top_bar.get_node("TopBarContainer/PlayerInfo")
	if player_info_area:
		# 增大觸控目標到48px (符合UI/UX建議)
		player_info_area.custom_minimum_size.y = 48

		# 創建觸控按鈕來處理點擊
		var touch_button = Button.new()
		touch_button.flat = true
		touch_button.custom_minimum_size = Vector2(0, 48)
		touch_button.anchors_preset = Control.PRESET_FULL_RECT
		touch_button.pressed.connect(toggle_topbar_expanded)
		player_info_area.add_child(touch_button)

	LogManager.info("MainMobile", "TopBar折疊功能初始化完成", {
		"collapsed_height": topbar_collapsed_height,
		"expanded_height": topbar_expanded_height,
		"initial_state": "collapsed"
	})

# 切換TopBar展開/折疊狀態
func toggle_topbar_expanded() -> void:
	if topbar_animating:
		return

	topbar_expanded = !topbar_expanded
	var target_height = topbar_expanded_height if topbar_expanded else topbar_collapsed_height

	LogManager.debug("MainMobile", "TopBar狀態切換", {
		"expanding": topbar_expanded,
		"target_height": target_height,
		"current_height": top_bar.custom_minimum_size.y
	})

	# 添加觸控反饋效果
	add_touch_feedback()
	animate_topbar_height(target_height)

# TopBar高度動畫
func animate_topbar_height(target_height: float) -> void:
	if not top_bar:
		return

	topbar_animating = true
	var start_height = top_bar.custom_minimum_size.y

	# 創建Tween動畫
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# 動畫高度變化
	tween.tween_method(
		func(height: float): top_bar.custom_minimum_size.y = height,
		start_height,
		target_height,
		topbar_animation_duration
	)

	# 同時處理能力值面板顯示/隱藏
	if topbar_expanded:
		# 展開時：先顯示，再淡入
		if ability_stats_container:
			ability_stats_container.visible = true
			ability_stats_container.modulate.a = 0.0
			tween.parallel().tween_property(ability_stats_container, "modulate:a", 1.0, topbar_animation_duration * 0.8)
	else:
		# 折疊時：先淡出，再隱藏
		if ability_stats_container:
			tween.parallel().tween_property(ability_stats_container, "modulate:a", 0.0, topbar_animation_duration * 0.6)
			tween.tween_callback(func(): ability_stats_container.visible = false)

	# 動畫完成回調
	await tween.finished
	topbar_animating = false

	LogManager.debug("MainMobile", "TopBar動畫完成", {
		"final_height": top_bar.custom_minimum_size.y,
		"expanded": topbar_expanded,
		"ability_visible": ability_stats_container.visible if ability_stats_container else false
	})

# 添加觸控反饋效果
func add_touch_feedback() -> void:
	# 簡單的縮放反饋效果
	if touch_feedback_tween:
		touch_feedback_tween.kill()

	touch_feedback_tween = create_tween()
	var player_info_area = top_bar.get_node("TopBarContainer/PlayerInfo")
	if player_info_area:
		# 快速縮放反饋
		touch_feedback_tween.tween_property(player_info_area, "scale", Vector2(0.95, 0.95), 0.1)
		touch_feedback_tween.tween_property(player_info_area, "scale", Vector2(1.0, 1.0), 0.1)

func _on_game_state_changed(new_state: int, old_state: int) -> void:
	var state_names = {
		GameStateManager.GameState.MENU: "主選單",
		GameStateManager.GameState.SKILL_SELECTION: "技能選擇",
		GameStateManager.GameState.GAME_RUNNING: "主遊戲",
		GameStateManager.GameState.BATTLE: "戰鬥",
		GameStateManager.GameState.PAUSED: "暫停",
		GameStateManager.GameState.GAME_OVER: "遊戲結束"
	}

	var transition_start_time = Time.get_unix_time_from_system()

	LogManager.info("MainMobile", "遊戲狀態轉換開始", {
		"from_state": state_names.get(old_state, "未知狀態"),
		"to_state": state_names.get(new_state, "未知狀態"),
		"from_state_id": old_state,
		"to_state_id": new_state,
		"transition_timestamp": transition_start_time
	})

	# 根據遊戲狀態更新UI顯示
	match new_state:
		GameStateManager.GameState.MENU:
			show_main_menu()
		GameStateManager.GameState.SKILL_SELECTION:
			show_skill_selection()
		GameStateManager.GameState.GAME_RUNNING:
			show_main_game()
		_:
			LogManager.warn("MainMobile", "未處理的遊戲狀態", {
				"state_id": new_state,
				"state_name": state_names.get(new_state, "未知狀態")
			})

	var transition_end_time = Time.get_unix_time_from_system()
	LogManager.info("MainMobile", "遊戲狀態轉換完成", {
		"to_state": state_names.get(new_state, "未知狀態"),
		"transition_duration": transition_end_time - transition_start_time,
		"success": true
	})

func show_main_menu() -> void:
	LogManager.info("MainMobile", "顯示主選單開始", {
		"current_children": get_children().size(),
		"action": "show_main_menu"
	})

	# 隱藏其他UI，顯示主選單
	# TODO: 實現主選單UI邏輯

	LogManager.info("MainMobile", "主選單顯示完成", {
		"menu_visible": true,
		"ui_state": "main_menu"
	})

func show_skill_selection() -> void:
	LogManager.info("MainMobile", "技能選擇界面切換開始", {
		"has_existing_ui": has_node("SkillSelectionUI"),
		"action": "show_skill_selection"
	})

	# 如果技能選擇UI不存在，創建它
	if not has_node("SkillSelectionUI"):
		LogManager.info("MainMobile", "創建技能選擇UI", {
			"scene_path": "res://scenes/ui/SkillSelectionUI.tscn",
			"creating_new_instance": true
		})

		var skill_ui_scene = preload("res://scenes/ui/SkillSelectionUI.tscn")
		if skill_ui_scene:
			var skill_ui = skill_ui_scene.instantiate()
			skill_ui.name = "SkillSelectionUI"
			add_child(skill_ui)

			LogManager.info("MainMobile", "技能選擇UI創建成功", {
				"ui_node_name": skill_ui.name,
				"ui_parent": skill_ui.get_parent().name,
				"children_count": get_children().size()
			})
		else:
			LogManager.error("MainMobile", "技能選擇場景載入失敗", {
				"scene_path": "res://scenes/ui/SkillSelectionUI.tscn",
				"scene_resource": null
			})
	else:
		LogManager.info("MainMobile", "技能選擇UI已存在", {
			"existing_ui": true,
			"ui_node_path": "SkillSelectionUI"
		})

	# 確保 SkillSelectionUI 顯示
	if has_node("SkillSelectionUI"):
		var skill_ui = get_node("SkillSelectionUI")
		LogManager.info("MainMobile", "調用SkillSelectionUI顯示方法", {
			"skill_ui_valid": skill_ui != null,
			"skill_ui_has_show_method": skill_ui.has_method("show_skill_selection")
		})

		if skill_ui.has_method("show_skill_selection"):
			skill_ui.show_skill_selection()
		else:
			LogManager.error("MainMobile", "SkillSelectionUI缺少show_skill_selection方法")
	else:
		LogManager.error("MainMobile", "SkillSelectionUI節點不存在", {
			"ui_creation_failed": true
		})

	LogManager.info("MainMobile", "技能選擇界面切換完成", {
		"ui_state": "skill_selection",
		"ui_active": has_node("SkillSelectionUI"),
		"ui_visible": has_node("SkillSelectionUI") and get_node("SkillSelectionUI").visible if has_node("SkillSelectionUI") else false
	})

func show_main_game() -> void:
	LogManager.info("MainMobile", "主遊戲界面切換開始", {
		"has_skill_ui": has_node("SkillSelectionUI"),
		"action": "show_main_game"
	})

	# 移除技能選擇UI
	if has_node("SkillSelectionUI"):
		LogManager.info("MainMobile", "移除技能選擇UI", {
			"removing_ui": "SkillSelectionUI",
			"cleanup_action": "queue_free"
		})

		var skill_ui = get_node("SkillSelectionUI")
		skill_ui.queue_free()

		LogManager.info("MainMobile", "技能選擇UI已排隊移除", {
			"ui_queued_for_removal": true,
			"remaining_children": get_children().size()
		})

	LogManager.info("MainMobile", "主遊戲界面切換完成", {
		"ui_state": "main_game",
		"skill_ui_removed": not has_node("SkillSelectionUI")
	})

func _on_player_level_up(new_level: int, attribute_gains: Dictionary) -> void:
	LogManager.info("MainMobile", "玩家升級事件處理", {
		"new_level": new_level,
		"attribute_gains": attribute_gains,
		"gains_count": attribute_gains.size()
	})

	# 更新玩家資訊顯示
	update_player_info()

	LogManager.info("MainMobile", "升級處理完成", {
		"level": new_level,
		"ui_updated": true,
		"animation_pending": true
	})

	# TODO: 顯示升級動畫

# 回合完成事件處理器
func _on_turn_completed(turn_data: Dictionary) -> void:
	LogManager.debug("MainMobile", "收到回合完成事件", {
		"turn": turn_data.get("turn", 0),
		"year": turn_data.get("year", 184),
		"resources": turn_data.get("resources", {}),
		"duration": turn_data.get("duration", 0.0)
	})

	# 更新UI顯示
	update_player_info()

	# 顯示回合進度動畫
	_animate_turn_progress(turn_data)

	# 添加回合事件到遊戲日誌
	var turn_message = "⏰ 第 %d 回合完成 | %d年" % [turn_data.get("turn", 0), turn_data.get("year", 184)]
	if GameEventManager:
		GameEventManager.add_game_event(turn_message)

# 資源變化事件處理器
func _on_resources_changed(resource_type: String, amount: int) -> void:
	LogManager.debug("MainMobile", "收到資源變化事件", {
		"resource_type": resource_type,
		"amount": amount
	})

	# 更新資源顯示
	update_player_info()

	# 顯示資源變化動畫
	_animate_resource_change(resource_type, amount)

# 回合進度動畫
func _animate_turn_progress(turn_data: Dictionary) -> void:
	# 輕微的回合進度脈衝動畫
	if turn_year_label:
		var original_scale = turn_year_label.scale
		var tween = create_tween()

		tween.tween_property(turn_year_label, "scale", original_scale * 1.1, 0.2)
		tween.tween_property(turn_year_label, "scale", original_scale, 0.2)

	LogManager.debug("MainMobile", "回合進度動畫已觸發", {
		"turn": turn_data.get("turn", 0)
	})

# 資源變化動畫
func _animate_resource_change(resource_type: String, amount: int) -> void:
	var target_label: Label = null

	match resource_type:
		"gold":
			target_label = gold_label
		"troops":
			target_label = troops_label
		"cities":
			target_label = cities_label

	if target_label:
		var original_color = target_label.get_theme_color("font_color")
		var change_color = Color.GREEN if amount > 0 else Color.RED

		var tween = create_tween()
		tween.set_parallel(true)

		# 顏色變化動畫
		tween.tween_method(_set_label_color.bind(target_label), original_color, change_color, 0.3)
		tween.tween_method(_set_label_color.bind(target_label), change_color, original_color, 0.3).set_delay(0.3)

		# 縮放動畫
		var original_scale = target_label.scale
		tween.tween_property(target_label, "scale", original_scale * 1.15, 0.2)
		tween.tween_property(target_label, "scale", original_scale, 0.2).set_delay(0.2)

	LogManager.debug("MainMobile", "資源變化動畫已觸發", {
		"resource": resource_type,
		"amount": amount
	})

# 設置標籤顏色的輔助函數
func _set_label_color(label: Label, color: Color) -> void:
	if label:
		label.add_theme_color_override("font_color", color)