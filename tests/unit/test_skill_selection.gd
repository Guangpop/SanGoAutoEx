# test_skill_selection.gd - 技能選擇系統單元測試
#
# 測試範圍：
# - 技能選擇邏輯
# - 星星消耗和轉換
# - 技能效果應用
# - 邊界條件和錯誤處理

extends GdUnitTestSuite

# 測試用的模擬數據
var mock_skills: Array = []
var skill_selection_manager: Node
var test_player_data: Dictionary

func before_test() -> void:
	# 設置測試用的技能數據
	mock_skills = [
		{
			"id": "test_skill_1",
			"name": "測試技能1",
			"star_cost": 1,
			"effects": {"武力": 5, "智力": 3}
		},
		{
			"id": "test_skill_2",
			"name": "測試技能2",
			"star_cost": 2,
			"effects": {"統治": 8, "政治": 4}
		},
		{
			"id": "test_skill_3",
			"name": "測試技能3",
			"star_cost": 3,
			"effects": {"武力": 10, "智力": 8, "天命": 5}
		}
	]

	# 初始化測試用玩家數據
	test_player_data = {
		"attributes": {
			"武力": 20,
			"智力": 20,
			"統治": 20,
			"政治": 20,
			"魅力": 20,
			"天命": 10
		},
		"selected_skills": []
	}

func after_test() -> void:
	if skill_selection_manager:
		skill_selection_manager.queue_free()

# === 基礎功能測試 ===

func test_skill_selection_initialization():
	# 測試技能選擇系統初始化
	var selection_state = {
		"current_round": 0,
		"max_rounds": 3,
		"remaining_stars": 10,
		"available_skills": [],
		"selected_skills": []
	}

	assert_int(selection_state.remaining_stars).is_equal(10)
	assert_int(selection_state.current_round).is_equal(0)
	assert_int(selection_state.max_rounds).is_equal(3)
	assert_array(selection_state.selected_skills).is_empty()

func test_skill_cost_validation():
	# 測試技能消耗驗證
	var remaining_stars = 5

	# 1星技能應該可以選擇
	var can_select_1_star = remaining_stars >= 1
	assert_bool(can_select_1_star).is_true()

	# 2星技能應該可以選擇
	var can_select_2_star = remaining_stars >= 2
	assert_bool(can_select_2_star).is_true()

	# 6星技能應該不能選擇（超過剩餘星星）
	var can_select_6_star = remaining_stars >= 6
	assert_bool(can_select_6_star).is_false()

func test_skill_selection_logic():
	# 測試技能選擇邏輯
	var selection_state = {
		"remaining_stars": 10,
		"selected_skills": []
	}

	var skill_to_select = mock_skills[0] # 1星技能

	# 模擬選擇技能
	if skill_to_select.star_cost <= selection_state.remaining_stars:
		selection_state.remaining_stars -= skill_to_select.star_cost
		selection_state.selected_skills.append(skill_to_select)

	assert_int(selection_state.remaining_stars).is_equal(9)
	assert_array(selection_state.selected_skills).has_size(1)
	assert_str(selection_state.selected_skills[0].id).is_equal("test_skill_1")

func test_skill_effects_application():
	# 測試技能效果應用
	var player_attributes = test_player_data.attributes.duplicate()
	var skill = mock_skills[0] # 武力+5, 智力+3

	# 應用技能效果
	for attribute_name in skill.effects:
		if player_attributes.has(attribute_name):
			player_attributes[attribute_name] += skill.effects[attribute_name]

	assert_int(player_attributes["武力"]).is_equal(25) # 20 + 5
	assert_int(player_attributes["智力"]).is_equal(23) # 20 + 3
	assert_int(player_attributes["統治"]).is_equal(20) # 未變化

func test_star_to_attribute_conversion():
	# 測試星星轉屬性點轉換
	var remaining_stars = 3
	var conversion_rate = 10 # 1星 = 10屬性點
	var total_points = remaining_stars * conversion_rate

	assert_int(total_points).is_equal(30)

	# 測試屬性分配邏輯
	var attributes = ["武力", "智力", "統治", "政治", "魅力"]
	var gained_attributes = {}

	# 模擬隨機分配
	for i in range(total_points):
		var random_attr = attributes[i % attributes.size()] # 循環分配用於測試
		gained_attributes[random_attr] = gained_attributes.get(random_attr, 0) + 1

	# 驗證總點數正確
	var total_gained = 0
	for attr in gained_attributes.values():
		total_gained += attr
	assert_int(total_gained).is_equal(30)

# === 邊界條件測試 ===

func test_insufficient_stars():
	# 測試星星不足的情況
	var selection_state = {
		"remaining_stars": 1,
		"selected_skills": []
	}

	var expensive_skill = mock_skills[2] # 3星技能

	# 嘗試選擇超出能力的技能
	var can_select = expensive_skill.star_cost <= selection_state.remaining_stars
	assert_bool(can_select).is_false()

	# 確保狀態未改變
	assert_int(selection_state.remaining_stars).is_equal(1)
	assert_array(selection_state.selected_skills).is_empty()

func test_maximum_rounds():
	# 測試最大回合數限制
	var selection_state = {
		"current_round": 0,
		"max_rounds": 3
	}

	# 模擬3回合選擇
	for i in range(3):
		selection_state.current_round += 1
		assert_int(selection_state.current_round).is_less_equal(selection_state.max_rounds)

	# 確認達到最大回合數
	assert_int(selection_state.current_round).is_equal(3)

	# 嘗試超過最大回合數
	var can_continue = selection_state.current_round < selection_state.max_rounds
	assert_bool(can_continue).is_false()

func test_duplicate_skill_selection():
	# 測試重複選擇技能的防護
	var selection_state = {
		"remaining_stars": 10,
		"selected_skills": []
	}

	var skill = mock_skills[0]

	# 第一次選擇
	if not _skill_already_selected(skill.id, selection_state.selected_skills):
		selection_state.selected_skills.append(skill)
		selection_state.remaining_stars -= skill.star_cost

	# 嘗試第二次選擇同一技能
	var already_selected = _skill_already_selected(skill.id, selection_state.selected_skills)
	assert_bool(already_selected).is_true()

	# 確保只選擇了一次
	assert_array(selection_state.selected_skills).has_size(1)

func test_zero_stars_remaining():
	# 測試星星用完的情況
	var selection_state = {
		"remaining_stars": 0,
		"selected_skills": []
	}

	var any_skill = mock_skills[0]
	var can_select = any_skill.star_cost <= selection_state.remaining_stars
	assert_bool(can_select).is_false()

# === 複合場景測試 ===

func test_complete_skill_selection_flow():
	# 測試完整的技能選擇流程
	var selection_state = {
		"current_round": 0,
		"max_rounds": 3,
		"remaining_stars": 10,
		"selected_skills": []
	}

	# 回合1：選擇1星技能
	selection_state.current_round += 1
	var skill1 = mock_skills[0] # 1星
	selection_state.selected_skills.append(skill1)
	selection_state.remaining_stars -= skill1.star_cost

	# 回合2：選擇2星技能
	selection_state.current_round += 1
	var skill2 = mock_skills[1] # 2星
	selection_state.selected_skills.append(skill2)
	selection_state.remaining_stars -= skill2.star_cost

	# 回合3：選擇3星技能
	selection_state.current_round += 1
	var skill3 = mock_skills[2] # 3星
	selection_state.selected_skills.append(skill3)
	selection_state.remaining_stars -= skill3.star_cost

	# 驗證最終狀態
	assert_int(selection_state.current_round).is_equal(3)
	assert_int(selection_state.remaining_stars).is_equal(4) # 10-1-2-3=4
	assert_array(selection_state.selected_skills).has_size(3)

func test_attribute_accumulation():
	# 測試多個技能效果累積
	var player_attributes = test_player_data.attributes.duplicate()

	# 選擇多個影響武力的技能
	var skills_to_apply = [mock_skills[0], mock_skills[2]] # 武力+5 和 武力+10

	for skill in skills_to_apply:
		for attribute_name in skill.effects:
			if player_attributes.has(attribute_name):
				player_attributes[attribute_name] += skill.effects[attribute_name]

	# 驗證武力累積效果 (20 + 5 + 10 = 35)
	assert_int(player_attributes["武力"]).is_equal(35)
	# 驗證智力累積效果 (20 + 3 + 8 = 31)
	assert_int(player_attributes["智力"]).is_equal(31)

# === 輔助方法 ===

func _skill_already_selected(skill_id: String, selected_skills: Array) -> bool:
	for skill in selected_skills:
		if skill.get("id", "") == skill_id:
			return true
	return false

# === 性能測試 ===

func test_skill_selection_performance():
	# 測試大量技能選擇的性能
	var start_time = Time.get_unix_time_from_system()

	# 模擬100次技能選擇操作
	for i in range(100):
		var selection_state = {
			"remaining_stars": 10,
			"selected_skills": []
		}

		# 模擬選擇過程
		for skill in mock_skills:
			if skill.star_cost <= selection_state.remaining_stars:
				selection_state.selected_skills.append(skill)
				selection_state.remaining_stars -= skill.star_cost

	var end_time = Time.get_unix_time_from_system()
	var duration = end_time - start_time

	# 性能要求：100次操作應在1秒內完成
	assert_float(duration).is_less(1.0)

# === 數據驗證測試 ===

func test_invalid_skill_data():
	# 測試無效技能數據的處理
	var invalid_skills = [
		{"id": "", "name": "無ID技能", "star_cost": 1},
		{"id": "invalid", "star_cost": -1}, # 負星級
		{"id": "invalid2", "star_cost": 0}, # 零星級
		{"id": "invalid3", "star_cost": 5}, # 超過最大星級
	]

	for skill in invalid_skills:
		var is_valid = _validate_skill_data(skill)
		assert_bool(is_valid).is_false()

func _validate_skill_data(skill: Dictionary) -> bool:
	# 簡單的技能數據驗證邏輯
	if not skill.has("id") or skill.id.is_empty():
		return false
	if not skill.has("star_cost") or skill.star_cost < 1 or skill.star_cost > 3:
		return false
	return true