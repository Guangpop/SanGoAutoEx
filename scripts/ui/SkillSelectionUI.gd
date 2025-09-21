# SkillSelectionUI.gd - 技能選擇介面控制器
#
# 功能：
# - 顯示技能選擇界面 (移動端優化)
# - 處理觸控輸入和技能選擇
# - 實時更新選擇狀態和進度
# - 響應式設計適配不同螢幕

extends Control

# UI節點引用
@onready var title_label = $VBoxContainer/HeaderContainer/TitleLabel
@onready var subtitle_label = $VBoxContainer/HeaderContainer/SubtitleLabel
@onready var round_label = $VBoxContainer/HeaderContainer/ProgressContainer/RoundLabel
@onready var stars_label = $VBoxContainer/HeaderContainer/ProgressContainer/StarsLabel
@onready var selected_skills_label = $VBoxContainer/BottomContainer/SelectedSkillsLabel

@onready var skill_cards = [
	$VBoxContainer/SkillsContainer/SkillCardContainer/SkillCard1,
	$VBoxContainer/SkillsContainer/SkillCardContainer/SkillCard2,
	$VBoxContainer/SkillsContainer/SkillCardContainer/SkillCard3
]

@onready var skill_buttons = [
	$VBoxContainer/SkillsContainer/SkillCardContainer/SkillCard1/SkillCard1Button,
	$VBoxContainer/SkillsContainer/SkillCardContainer/SkillCard2/SkillCard2Button,
	$VBoxContainer/SkillsContainer/SkillCardContainer/SkillCard3/SkillCard3Button
]

@onready var skip_button = $VBoxContainer/BottomContainer/SkipButton
@onready var continue_button = $VBoxContainer/BottomContainer/ContinueButton

# 當前顯示的技能數據
var current_skills: Array = []
var is_selection_completed: bool = false

func _ready() -> void:
	var ui_init_start_time = Time.get_unix_time_from_system()

	LogManager.info("SkillSelectionUI", "技能選擇界面初始化開始", {
		"initialization_timestamp": ui_init_start_time,
		"scene_loaded": true,
		"ui_nodes_count": get_children(true).size()
	})

	# 連接事件處理器
	LogManager.debug("SkillSelectionUI", "開始連接事件處理器")
	connect_event_handlers()

	# 連接UI事件
	LogManager.debug("SkillSelectionUI", "開始連接UI事件")
	connect_ui_events()

	# 初始化界面
	LogManager.debug("SkillSelectionUI", "開始初始化界面")
	initialize_ui()

	var ui_init_duration = Time.get_unix_time_from_system() - ui_init_start_time

	LogManager.info("SkillSelectionUI", "技能選擇界面初始化完成", {
		"initialization_duration": ui_init_duration,
		"ui_ready": true,
		"initial_visibility": visible
	})

# 連接事件處理器
func connect_event_handlers() -> void:
	var events_to_connect = [
		"skill_selection_started",
		"skill_selected",
		"skill_selection_completed",
		"game_state_changed"
	]

	LogManager.debug("SkillSelectionUI", "開始連接系統事件", {
		"events_count": events_to_connect.size(),
		"events_list": events_to_connect
	})

	var connection_results = {}
	connection_results["skill_selection_started"] = EventBus.connect_safe("skill_selection_started", _on_skill_selection_started)
	connection_results["skill_selected"] = EventBus.connect_safe("skill_selected", _on_skill_selected)
	connection_results["skill_selection_completed"] = EventBus.connect_safe("skill_selection_completed", _on_skill_selection_completed)
	connection_results["game_state_changed"] = EventBus.connect_safe("game_state_changed", _on_game_state_changed)

	var all_connected = true
	for event_name in connection_results:
		if not connection_results[event_name]:
			all_connected = false

	LogManager.info("SkillSelectionUI", "事件處理器連接完成", {
		"connection_results": connection_results,
		"all_connected": all_connected
	})

# 連接UI事件
func connect_ui_events() -> void:
	# 連接技能卡片按鈕
	for i in range(skill_buttons.size()):
		skill_buttons[i].pressed.connect(_on_skill_button_pressed.bind(i))

	# 連接底部按鈕
	skip_button.pressed.connect(_on_skip_button_pressed)
	continue_button.pressed.connect(_on_continue_button_pressed)

# 初始化界面
func initialize_ui() -> void:
	# 設置初始狀態
	visible = false
	update_ui_state()

# 顯示技能選擇界面
func show_skill_selection() -> void:
	var show_start_time = Time.get_unix_time_from_system()

	LogManager.info("SkillSelectionUI", "開始顯示技能選擇界面", {
		"show_timestamp": show_start_time,
		"previous_visibility": visible,
		"manager_active": SkillSelectionManager.is_active()
	})

	visible = true

	# 更新界面狀態
	LogManager.debug("SkillSelectionUI", "更新界面狀態")
	update_ui_state()

	# 播放顯示動畫
	LogManager.debug("SkillSelectionUI", "播放顯示動畫")
	_play_show_animation()

	LogManager.info("SkillSelectionUI", "技能選擇界面顯示完成", {
		"show_duration": Time.get_unix_time_from_system() - show_start_time,
		"current_visibility": visible,
		"ui_state_updated": true
	})

# 隱藏技能選擇界面
func hide_skill_selection() -> void:
	# 播放隱藏動畫
	_play_hide_animation()

	await get_tree().create_timer(0.3).timeout
	visible = false

	LogManager.debug("SkillSelectionUI", "隱藏技能選擇界面")

# 更新界面狀態
func update_ui_state() -> void:
	if not SkillSelectionManager.is_active():
		return

	var state = SkillSelectionManager.get_selection_state()

	# 更新進度信息
	round_label.text = "第 %d/%d 回合" % [state.current_round + 1, state.max_rounds]
	stars_label.text = "⭐ %d" % state.remaining_stars
	selected_skills_label.text = "已選技能：%d" % state.selected_skills.size()

	# 更新技能卡片
	current_skills = state.available_skills
	update_skill_cards()

	# 更新按鈕狀態
	continue_button.disabled = not SkillSelectionManager.is_completed()

# 更新技能卡片顯示
func update_skill_cards() -> void:
	for i in range(skill_cards.size()):
		var card = skill_cards[i]
		var button = skill_buttons[i]

		if i < current_skills.size():
			var skill = current_skills[i]
			_setup_skill_card(card, skill, i)
			card.visible = true
			button.disabled = false

			# 檢查是否可以選擇
			var can_select = _can_select_skill(skill)
			button.disabled = not can_select
			_update_card_visual_state(card, can_select)
		else:
			card.visible = false

# 設置技能卡片內容
func _setup_skill_card(card: Panel, skill: Dictionary, index: int) -> void:
	var content_container = card.get_child(0) # SkillCard*Content

	# 更新技能名稱
	var name_label = content_container.get_child(0).get_child(0) # Header -> Name
	name_label.text = skill.get("name", "未知技能")

	# 更新星級消耗
	var cost_label = content_container.get_child(0).get_child(1) # Header -> Cost
	var star_cost = skill.get("star_cost", 1)
	cost_label.text = "⭐ %d" % star_cost

	# 更新描述
	var description_label = content_container.get_child(1) # Description
	description_label.text = skill.get("description", "無描述")

	# 更新效果
	var effects_label = content_container.get_child(2) # Effects
	var effects_text = _format_skill_effects(skill.get("effects", {}))
	effects_label.text = "效果：" + effects_text

# 格式化技能效果文本
func _format_skill_effects(effects: Dictionary) -> String:
	if effects.is_empty():
		return "無"

	var effect_strings: Array[String] = []
	for attribute_name in effects:
		var value = effects[attribute_name]
		if value > 0:
			effect_strings.append("%s +%d" % [attribute_name, value])
		elif value < 0:
			effect_strings.append("%s %d" % [attribute_name, value])

	return ", ".join(effect_strings)

# 檢查是否可以選擇技能
func _can_select_skill(skill: Dictionary) -> bool:
	var star_cost = skill.get("star_cost", 1)
	var remaining_stars = SkillSelectionManager.get_remaining_stars()
	return star_cost <= remaining_stars

# 更新卡片視覺狀態
func _update_card_visual_state(card: Panel, can_select: bool) -> void:
	if can_select:
		card.modulate = Color.WHITE
	else:
		card.modulate = Color(0.7, 0.7, 0.7, 1.0) # 暗化不可選擇的卡片

# 播放顯示動畫
func _play_show_animation() -> void:
	# 初始狀態
	modulate = Color(1, 1, 1, 0)
	scale = Vector2(0.8, 0.8)

	# 淡入和縮放動畫
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3)

	# 卡片依序顯示動畫
	for i in range(skill_cards.size()):
		var card = skill_cards[i]
		if card.visible:
			card.modulate = Color(1, 1, 1, 0)
			card.position.y += 50

			await get_tree().create_timer(0.1).timeout

			var card_tween = create_tween()
			card_tween.set_parallel(true)
			card_tween.tween_property(card, "modulate", Color.WHITE, 0.2)
			card_tween.tween_property(card, "position:y", card.position.y - 50, 0.2)

# 播放隱藏動畫
func _play_hide_animation() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.3)

# 播放技能選擇動畫
func _play_skill_selection_animation(skill_index: int) -> void:
	if skill_index < 0 or skill_index >= skill_cards.size():
		return

	var card = skill_cards[skill_index]

	# 選擇反饋動畫
	var tween = create_tween()
	tween.set_parallel(true)

	# 縮放效果
	tween.tween_property(card, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(card, "scale", Vector2.ONE, 0.1).set_delay(0.1)

	# 顏色效果
	tween.tween_property(card, "modulate", Color.GREEN, 0.1)
	tween.tween_property(card, "modulate", Color.WHITE, 0.1).set_delay(0.1)

# === 事件處理器 ===

func _on_skill_selection_started() -> void:
	LogManager.info("SkillSelectionUI", "收到技能選擇開始事件", {
		"event": "skill_selection_started",
		"current_visibility": visible,
		"manager_active": SkillSelectionManager.is_active()
	})
	show_skill_selection()

func _on_skill_selected(skill_data: Dictionary, remaining_stars: int) -> void:
	# 找到被選擇的技能卡片
	var skill_index = -1
	for i in range(current_skills.size()):
		if current_skills[i].get("id", "") == skill_data.get("id", ""):
			skill_index = i
			break

	if skill_index >= 0:
		_play_skill_selection_animation(skill_index)

	# 更新界面狀態
	update_ui_state()

	LogManager.info("SkillSelectionUI", "技能選擇反饋", {
		"skill": skill_data.name,
		"remaining_stars": remaining_stars
	})

func _on_skill_selection_completed(selected_skills: Array, remaining_stars: int) -> void:
	is_selection_completed = true
	update_ui_state()

	LogManager.info("SkillSelectionUI", "技能選擇完成", {
		"selected_count": selected_skills.size(),
		"remaining_stars": remaining_stars
	})

	# 縮短延遲隱藏界面時間，提升響應感
	await get_tree().create_timer(0.3).timeout
	hide_skill_selection()

func _on_game_state_changed(new_state: int, old_state: int) -> void:
	var state_names = {
		GameStateManager.GameState.MENU: "主選單",
		GameStateManager.GameState.SKILL_SELECTION: "技能選擇",
		GameStateManager.GameState.GAME_RUNNING: "主遊戲",
		GameStateManager.GameState.BATTLE: "戰鬥",
		GameStateManager.GameState.PAUSED: "暫停",
		GameStateManager.GameState.GAME_OVER: "遊戲結束"
	}

	LogManager.info("SkillSelectionUI", "遊戲狀態變化響應", {
		"from_state": state_names.get(old_state, "未知狀態"),
		"to_state": state_names.get(new_state, "未知狀態"),
		"current_visibility": visible,
		"manager_active": SkillSelectionManager.is_active()
	})

	if new_state == GameStateManager.GameState.SKILL_SELECTION:
		if not visible:
			LogManager.info("SkillSelectionUI", "進入技能選擇狀態，顯示界面", {
				"state_change_trigger": "SKILL_SELECTION",
				"was_hidden": true
			})
			show_skill_selection()
		else:
			LogManager.debug("SkillSelectionUI", "已在技能選擇狀態，界面已可見")
	elif old_state == GameStateManager.GameState.SKILL_SELECTION:
		if visible:
			LogManager.info("SkillSelectionUI", "離開技能選擇狀態，隱藏界面", {
				"state_change_trigger": "LEAVING_SKILL_SELECTION",
				"was_visible": true
			})
			hide_skill_selection()
		else:
			LogManager.debug("SkillSelectionUI", "離開技能選擇狀態，界面已隱藏")

# === UI事件處理器 ===

func _on_skill_button_pressed(skill_index: int) -> void:
	if skill_index < 0 or skill_index >= current_skills.size():
		LogManager.warn("SkillSelectionUI", "無效的技能索引", {"index": skill_index})
		return

	var skill = current_skills[skill_index]
	var skill_id = skill.get("id", "")

	LogManager.debug("SkillSelectionUI", "技能按鈕點擊", {
		"skill": skill.name,
		"index": skill_index
	})

	# 嘗試選擇技能
	var success = SkillSelectionManager.select_skill(skill_id)
	if success:
		# 選擇成功，播放確認動畫並自動推進
		_execute_immediate_selection(skill_index)
	else:
		_play_selection_failed_animation(skill_index)

# 執行立即選擇 - 選擇成功後自動推進流程
func _execute_immediate_selection(skill_index: int) -> void:
	LogManager.info("SkillSelectionUI", "執行立即選擇流程", {
		"skill_index": skill_index,
		"skill_name": current_skills[skill_index].get("name", "unknown")
	})

	# 播放選擇確認動畫（縮短時間到0.3秒）
	_play_skill_selection_animation(skill_index)

	# 等待動畫完成後自動推進
	await get_tree().create_timer(0.3).timeout

	# 使用共用的自動推進邏輯
	_execute_auto_advance()

func _on_skip_button_pressed() -> void:
	LogManager.debug("SkillSelectionUI", "跳過按鈕點擊")

	# 跳過當前回合
	SkillSelectionManager.skip_current_round()

	# 跳過後也自動推進流程
	_execute_auto_advance()

# 執行自動推進邏輯（共用方法）
func _execute_auto_advance() -> void:
	# 防止重複推進檢查
	var current_round = SkillSelectionManager.get_current_round()
	var max_rounds = SkillSelectionManager.get_max_rounds()

	LogManager.debug("SkillSelectionUI", "檢查推進條件", {
		"current_round": current_round,
		"max_rounds": max_rounds,
		"can_advance": current_round < max_rounds
	})

	# 檢查是否需要推進到下一輪
	if current_round < max_rounds:
		# 還有回合，推進到下一輪
		var advance_result = SkillSelectionManager.advance_to_next_round()

		if advance_result.get("success", false):
			LogManager.info("SkillSelectionUI", "自動推進成功", {
				"current_round": advance_result.get("current_round", 0),
				"completed": advance_result.get("completed", false)
			})

			# 只有在未完成時才觸發事件更新UI
			if not advance_result.get("completed", false):
				EventBus.skill_selection_started.emit()
				LogManager.debug("SkillSelectionUI", "觸發技能選擇開始事件")
		else:
			LogManager.warn("SkillSelectionUI", "推進失敗", {
				"reason": advance_result.get("reason", "unknown")
			})
	else:
		# 已完成所有回合，結束技能選擇
		SkillSelectionManager.finish_skill_selection()
		LogManager.info("SkillSelectionUI", "所有回合完成，結束技能選擇")

func _on_continue_button_pressed() -> void:
	LogManager.debug("SkillSelectionUI", "完成按鈕點擊")

	if SkillSelectionManager.is_completed():
		# 完成技能選擇
		SkillSelectionManager.finish_skill_selection()
	else:
		LogManager.warn("SkillSelectionUI", "技能選擇未完成，無法繼續")

# 播放選擇失敗動畫
func _play_selection_failed_animation(skill_index: int) -> void:
	if skill_index < 0 or skill_index >= skill_cards.size():
		return

	var card = skill_cards[skill_index]

	# 搖晃效果
	var original_position = card.position
	var tween = create_tween()

	for i in range(3):
		tween.tween_property(card, "position:x", original_position.x + 10, 0.05)
		tween.tween_property(card, "position:x", original_position.x - 10, 0.05)

	tween.tween_property(card, "position", original_position, 0.05)

	# 紅色閃爍效果
	var color_tween = create_tween()
	color_tween.tween_property(card, "modulate", Color.RED, 0.1)
	color_tween.tween_property(card, "modulate", Color.WHITE, 0.1)

# === 輔助方法 ===

# 獲取技能預覽信息
func get_skill_preview(skill_index: int) -> Dictionary:
	if skill_index < 0 or skill_index >= current_skills.size():
		return {}

	var skill = current_skills[skill_index]
	return SkillSelectionManager.preview_skill_effects(skill.get("id", ""))

# 重置界面狀態
func reset_ui() -> void:
	current_skills.clear()
	is_selection_completed = false
	update_ui_state()

# 獲取界面是否可見
func is_ui_visible() -> bool:
	return visible