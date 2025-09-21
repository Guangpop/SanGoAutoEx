# test_skill_integration.gd - 技能選擇系統整合測試
#
# 測試範圍：
# - 技能選擇完整流程
# - UI與系統整合
# - 事件系統整合
# - 數據持久化整合

extends GdUnitTestSuite

var skill_selection_ui: Control
var test_skills: Array
var event_received: Dictionary = {}

func before_test() -> void:
	# 重置事件記錄
	event_received.clear()

	# 連接測試事件處理器
	if EventBus:
		EventBus.connect_safe("skill_selected", _on_test_skill_selected)
		EventBus.connect_safe("skill_selection_completed", _on_test_skill_selection_completed)
		EventBus.connect_safe("star_converted_to_attributes", _on_test_star_converted)

	# 設置測試用技能數據
	test_skills = [
		{
			"id": "integration_test_skill_1",
			"name": "整合測試技能1",
			"star_cost": 1,
			"description": "測試用技能",
			"effects": {"武力": 5}
		},
		{
			"id": "integration_test_skill_2",
			"name": "整合測試技能2",
			"star_cost": 2,
			"description": "測試用技能",
			"effects": {"智力": 8}
		},
		{
			"id": "integration_test_skill_3",
			"name": "整合測試技能3",
			"star_cost": 3,
			"description": "測試用技能",
			"effects": {"武力": 10, "智力": 5}
		}
	]

func after_test() -> void:
	# 清理UI節點
	if skill_selection_ui:
		skill_selection_ui.queue_free()
		skill_selection_ui = null

	# 斷開事件連接
	if EventBus:
		if EventBus.is_connected("skill_selected", _on_test_skill_selected):
			EventBus.disconnect("skill_selected", _on_test_skill_selected)
		if EventBus.is_connected("skill_selection_completed", _on_test_skill_selection_completed):
			EventBus.disconnect("skill_selection_completed", _on_test_skill_selection_completed)
		if EventBus.is_connected("star_converted_to_attributes", _on_test_star_converted):
			EventBus.disconnect("star_converted_to_attributes", _on_test_star_converted)

# === 基本整合測試 ===

func test_skill_selection_manager_initialization():
	# 測試SkillSelectionManager是否正確初始化
	assert_object(SkillSelectionManager).is_not_null()
	assert_bool(SkillSelectionManager.is_active()).is_false()

	var initial_state = SkillSelectionManager.get_selection_state()
	assert_int(initial_state.current_round).is_equal(0)
	assert_int(initial_state.remaining_stars).is_equal(10)

func test_data_manager_integration():
	# 測試DataManager與技能選擇系統的整合
	assert_object(DataManager).is_not_null()

	# 等待數據載入完成
	if DataManager.is_loading():
		await GdUnitTools.create_timeout(5000).wait_until(func(): return not DataManager.is_loading())

	# 驗證技能數據是否已載入
	var load_errors = DataManager.get_load_errors()
	assert_array(load_errors).is_empty()

	# 測試獲取隨機技能
	var random_skills = DataManager.get_random_skills(3)
	assert_array(random_skills).is_not_empty()
	assert_array(random_skills).has_size(3)

func test_event_bus_integration():
	# 測試EventBus與技能選擇系統的整合
	assert_object(EventBus).is_not_null()

	# 測試事件發送
	var test_skill = test_skills[0]
	EventBus.skill_selected.emit(test_skill, 9)

	# 等待事件處理
	await get_tree().process_frame

	# 驗證事件是否正確接收
	assert_dict(event_received).contains_key("skill_selected")
	assert_str(event_received.skill_selected.skill.name).is_equal("整合測試技能1")

# === 完整流程測試 ===

func test_complete_skill_selection_flow():
	# 測試完整的技能選擇流程
	var player_data = {
		"attributes": {
			"武力": 20,
			"智力": 20,
			"統治": 20,
			"政治": 20,
			"魅力": 20,
			"天命": 10
		}
	}

	# 開始技能選擇
	var success = SkillSelectionManager.start_skill_selection(player_data)
	assert_bool(success).is_true()
	assert_bool(SkillSelectionManager.is_active()).is_true()

	# 模擬選擇技能流程
	for round in range(3):
		# 獲取當前可選技能
		var available_skills = SkillSelectionManager.get_available_skills()
		assert_array(available_skills).is_not_empty()

		# 選擇第一個技能（如果星星足夠）
		if not available_skills.is_empty():
			var skill_to_select = available_skills[0]
			var skill_id = skill_to_select.get("id", "")
			var star_cost = skill_to_select.get("star_cost", 1)

			var remaining_stars_before = SkillSelectionManager.get_remaining_stars()
			if star_cost <= remaining_stars_before:
				var select_success = SkillSelectionManager.select_skill(skill_id)
				assert_bool(select_success).is_true()

				# 驗證星星消耗
				var remaining_stars_after = SkillSelectionManager.get_remaining_stars()
				assert_int(remaining_stars_after).is_equal(remaining_stars_before - star_cost)
			else:
				# 如果星星不足，跳過
				SkillSelectionManager.skip_current_round()

		# 等待回合處理
		await get_tree().process_frame

	# 驗證選擇完成
	assert_bool(SkillSelectionManager.is_completed()).is_true()

func test_skill_effects_application():
	# 測試技能效果應用
	var player_data = {
		"attributes": {
			"武力": 20,
			"智力": 20,
			"統治": 20,
			"政治": 20,
			"魅力": 20,
			"天命": 10
		}
	}

	SkillSelectionManager.start_skill_selection(player_data)

	# 手動設置可選技能為測試技能
	SkillSelectionManager.selection_state.available_skills = [test_skills[0]] # 武力+5

	# 選擇技能
	var success = SkillSelectionManager.select_skill("integration_test_skill_1")
	assert_bool(success).is_true()

	# 驗證屬性是否正確應用
	assert_int(player_data.attributes["武力"]).is_equal(25) # 20 + 5

func test_star_conversion():
	# 測試星星轉換為屬性點
	var player_data = {
		"attributes": {
			"武力": 20,
			"智力": 20,
			"統治": 20,
			"政治": 20,
			"魅力": 20,
			"天命": 10
		}
	}

	SkillSelectionManager.start_skill_selection(player_data)

	# 設置剩餘星星
	SkillSelectionManager.selection_state.remaining_stars = 5
	SkillSelectionManager.selection_state.current_round = 3 # 模擬最後一輪

	# 完成選擇（觸發星星轉換）
	var result = SkillSelectionManager.finish_skill_selection()

	# 驗證轉換結果
	assert_dict(result).contains_key("converted_attributes")
	assert_int(result.remaining_stars).is_equal(5)

	# 等待轉換事件
	await get_tree().process_frame

	# 驗證轉換事件是否觸發
	assert_dict(event_received).contains_key("star_converted")

# === UI整合測試 ===

func test_ui_integration():
	# 測試UI整合
	var ui_scene = preload("res://scenes/ui/SkillSelectionUI.tscn")
	skill_selection_ui = ui_scene.instantiate()
	get_tree().root.add_child(skill_selection_ui)

	# 等待UI初始化
	await get_tree().process_frame

	# 驗證UI是否正確初始化
	assert_object(skill_selection_ui).is_not_null()
	assert_bool(skill_selection_ui.visible).is_false() # 初始應該隱藏

	# 觸發技能選擇開始事件
	EventBus.skill_selection_started.emit()
	await get_tree().process_frame

	# 驗證UI是否顯示
	assert_bool(skill_selection_ui.visible).is_true()

func test_ui_skill_card_display():
	# 測試技能卡片顯示
	var ui_scene = preload("res://scenes/ui/SkillSelectionUI.tscn")
	skill_selection_ui = ui_scene.instantiate()
	get_tree().root.add_child(skill_selection_ui)

	await get_tree().process_frame

	# 開始技能選擇
	var player_data = {"attributes": {"武力": 20, "智力": 20, "統治": 20, "政治": 20, "魅力": 20, "天命": 10}}
	SkillSelectionManager.start_skill_selection(player_data)

	# 手動設置技能
	SkillSelectionManager.selection_state.available_skills = test_skills

	# 更新UI
	skill_selection_ui.update_ui_state()

	await get_tree().process_frame

	# 驗證技能卡片是否正確顯示
	assert_bool(skill_selection_ui.visible).is_true()

# === 錯誤處理測試 ===

func test_invalid_skill_selection():
	# 測試無效技能選擇的錯誤處理
	var player_data = {"attributes": {"武力": 20, "智力": 20, "統治": 20, "政治": 20, "魅力": 20, "天命": 10}}
	SkillSelectionManager.start_skill_selection(player_data)

	# 嘗試選擇不存在的技能
	var success = SkillSelectionManager.select_skill("non_existent_skill")
	assert_bool(success).is_false()

	# 驗證狀態未改變
	var state = SkillSelectionManager.get_selection_state()
	assert_int(state.remaining_stars).is_equal(10)
	assert_array(state.selected_skills).is_empty()

func test_insufficient_stars():
	# 測試星星不足的情況
	var player_data = {"attributes": {"武力": 20, "智力": 20, "統治": 20, "政治": 20, "魅力": 20, "天命": 10}}
	SkillSelectionManager.start_skill_selection(player_data)

	# 設置剩餘星星為1
	SkillSelectionManager.selection_state.remaining_stars = 1
	SkillSelectionManager.selection_state.available_skills = [test_skills[2]] # 需要3星

	# 嘗試選擇需要3星的技能
	var success = SkillSelectionManager.select_skill("integration_test_skill_3")
	assert_bool(success).is_false()

	# 驗證星星未消耗
	assert_int(SkillSelectionManager.get_remaining_stars()).is_equal(1)

# === 性能測試 ===

func test_performance_multiple_selections():
	# 測試多次技能選擇的性能
	var start_time = Time.get_unix_time_from_system()

	# 執行100次技能選擇操作
	for i in range(100):
		var player_data = {"attributes": {"武力": 20, "智力": 20, "統治": 20, "政治": 20, "魅力": 20, "天命": 10}}
		SkillSelectionManager.start_skill_selection(player_data)
		SkillSelectionManager.selection_state.available_skills = [test_skills[0]]
		SkillSelectionManager.select_skill("integration_test_skill_1")
		SkillSelectionManager.finish_skill_selection()

	var end_time = Time.get_unix_time_from_system()
	var duration = end_time - start_time

	# 性能要求：100次操作應在2秒內完成
	assert_float(duration).is_less(2.0)

# === 持久化測試 ===

func test_state_persistence():
	# 測試狀態持久化
	var player_data = {"attributes": {"武力": 20, "智力": 20, "統治": 20, "政治": 20, "魅力": 20, "天命": 10}}
	SkillSelectionManager.start_skill_selection(player_data)

	# 進行一些選擇
	SkillSelectionManager.selection_state.available_skills = [test_skills[0]]
	SkillSelectionManager.select_skill("integration_test_skill_1")

	# 獲取當前狀態
	var saved_state = SkillSelectionManager.get_selection_state()

	# 驗證狀態數據
	assert_int(saved_state.current_round).is_equal(1)
	assert_int(saved_state.remaining_stars).is_equal(9) # 10 - 1
	assert_array(saved_state.selected_skills).has_size(1)

# === 事件處理器 ===

func _on_test_skill_selected(skill_data: Dictionary, remaining_stars: int) -> void:
	event_received["skill_selected"] = {
		"skill": skill_data,
		"remaining_stars": remaining_stars
	}

func _on_test_skill_selection_completed(selected_skills: Array, remaining_stars: int) -> void:
	event_received["skill_selection_completed"] = {
		"selected_skills": selected_skills,
		"remaining_stars": remaining_stars
	}

func _on_test_star_converted(stars_converted: int, attributes_gained: Dictionary) -> void:
	event_received["star_converted"] = {
		"stars_converted": stars_converted,
		"attributes_gained": attributes_gained
	}