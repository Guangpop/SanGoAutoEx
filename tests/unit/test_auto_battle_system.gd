# test_auto_battle_system.gd - 自動戰鬥系統單元測試
#
# 測試範圍：
# - 自動戰鬥管理器核心邏輯
# - 目標選擇和決策引擎
# - 離線進度計算
# - 資源管理和自動化設定
# - 閒置遊戲循環機制

extends GdUnitTestSuite

# 測試用數據
var test_player_data: Dictionary
var test_cities_data: Array
var test_automation_config: Dictionary
var auto_battle_manager: Node

func before_test() -> void:
	# 設置測試用玩家數據
	test_player_data = {
		"level": 8,
		"attributes": {
			"武力": 95,
			"智力": 85,
			"統治": 90,
			"政治": 80,
			"魅力": 75,
			"天命": 88
		},
		"resources": {
			"gold": 8000,
			"troops": 3000,
			"food": 2500
		},
		"owned_cities": ["chengdu", "hanzhong"],
		"automation_settings": {
			"auto_battle_enabled": true,
			"aggression_level": "balanced",
			"resource_reserve_percentage": 20,
			"max_simultaneous_battles": 2
		}
	}

	# 設置測試用城池數據
	test_cities_data = [
		{
			"id": "test_weak_city",
			"name": "弱勢城池",
			"tier": "small",
			"conquest_difficulty": 60,
			"garrison_strength": 800,
			"unlock_conditions": {"level": 5},
			"resources": {"gold_per_turn": 200, "troops_per_turn": 30}
		},
		{
			"id": "test_medium_city",
			"name": "中等城池",
			"tier": "medium",
			"conquest_difficulty": 75,
			"garrison_strength": 1200,
			"unlock_conditions": {"level": 7},
			"resources": {"gold_per_turn": 400, "troops_per_turn": 60}
		},
		{
			"id": "test_strong_city",
			"name": "強勢城池",
			"tier": "major",
			"conquest_difficulty": 90,
			"garrison_strength": 2000,
			"unlock_conditions": {"level": 10},
			"resources": {"gold_per_turn": 800, "troops_per_turn": 120}
		}
	]

	# 自動化配置
	test_automation_config = {
		"target_selection": {
			"preferred_success_rate": 0.7,
			"min_success_rate": 0.4,
			"resource_cost_limit": 0.3,
			"prioritize_efficiency": true
		},
		"resource_management": {
			"min_gold_reserve": 1000,
			"min_troops_reserve": 500,
			"auto_upgrade_threshold": 5000,
			"emergency_reserve_multiplier": 1.5
		},
		"offline_progression": {
			"max_offline_hours": 24,
			"diminishing_returns_start": 8,
			"diminishing_returns_rate": 0.1,
			"max_battle_attempts_per_hour": 6
		}
	}

	# 創建自動戰鬥管理器實例
	var auto_battle_script = load("res://scripts/systems/AutoBattleManager.gd")
	auto_battle_manager = auto_battle_script.new()

func after_test() -> void:
	# 清理測試實例
	if auto_battle_manager:
		auto_battle_manager.queue_free()
		auto_battle_manager = null

# === 自動戰鬥管理器初始化測試 ===

func test_auto_battle_manager_initialization():
	# 測試自動戰鬥管理器初始化
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	assert_bool(auto_battle_manager.is_initialized()).is_true()
	assert_bool(auto_battle_manager.is_auto_battle_enabled()).is_true()

func test_automation_settings_validation():
	# 測試自動化設定驗證
	var valid_settings = test_player_data.automation_settings
	var invalid_settings = {
		"auto_battle_enabled": "invalid_type",
		"aggression_level": "invalid_level",
		"resource_reserve_percentage": 150 # 超過100%
	}

	assert_bool(auto_battle_manager.validate_automation_settings(valid_settings)).is_true()
	assert_bool(auto_battle_manager.validate_automation_settings(invalid_settings)).is_false()

# === 目標選擇系統測試 ===

func test_target_city_evaluation():
	# 測試目標城池評估
	auto_battle_manager.initialize(test_player_data, test_automation_config)
	auto_battle_manager.available_cities = test_cities_data

	var weak_city_score = auto_battle_manager.evaluate_target_city(test_cities_data[0], test_player_data)
	var medium_city_score = auto_battle_manager.evaluate_target_city(test_cities_data[1], test_player_data)
	var strong_city_score = auto_battle_manager.evaluate_target_city(test_cities_data[2], test_player_data)

	# 弱勢城池應該有最高評分（更容易征服）
	assert_float(weak_city_score).is_greater(medium_city_score)
	assert_float(medium_city_score).is_greater(strong_city_score)

func test_optimal_target_selection():
	# 測試最優目標選擇
	auto_battle_manager.initialize(test_player_data, test_automation_config)
	auto_battle_manager.available_cities = test_cities_data

	var selected_target = auto_battle_manager.select_optimal_target(test_player_data)

	# 應該選擇適合的目標（不為空且滿足條件）
	assert_dict(selected_target).is_not_empty()
	assert_str(selected_target.get("id", "")).is_not_equal("")

func test_target_unlock_condition_filtering():
	# 測試目標解鎖條件過濾
	auto_battle_manager.initialize(test_player_data, test_automation_config)
	auto_battle_manager.available_cities = test_cities_data

	var available_targets = auto_battle_manager.get_available_targets(test_player_data)

	# 應該只包含滿足解鎖條件的城池
	for target in available_targets:
		var unlock_level = target.get("unlock_conditions", {}).get("level", 1)
		assert_int(test_player_data.level).is_greater_equal(unlock_level)

func test_aggression_level_impact():
	# 測試侵略性等級對目標選擇的影響
	auto_battle_manager.initialize(test_player_data, test_automation_config)
	auto_battle_manager.available_cities = test_cities_data

	# 保守模式
	auto_battle_manager.automation_config.aggression_level = "conservative"
	var conservative_target = auto_battle_manager.select_optimal_target(test_player_data)

	# 激進模式
	auto_battle_manager.automation_config.aggression_level = "aggressive"
	var aggressive_target = auto_battle_manager.select_optimal_target(test_player_data)

	# 激進模式應該選擇更困難的目標
	if not conservative_target.is_empty() and not aggressive_target.is_empty():
		var conservative_difficulty = conservative_target.get("conquest_difficulty", 0)
		var aggressive_difficulty = aggressive_target.get("conquest_difficulty", 0)
		# 在有選擇的情況下，激進模式可能選擇更困難的目標
		assert_bool(aggressive_difficulty >= conservative_difficulty).is_true()

# === 資源管理測試 ===

func test_resource_availability_check():
	# 測試資源可用性檢查
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	var sufficient_resources = auto_battle_manager.check_resource_availability(
		test_player_data, {"gold": 2000, "troops": 1000}
	)
	var insufficient_resources = auto_battle_manager.check_resource_availability(
		test_player_data, {"gold": 10000, "troops": 5000}
	)

	assert_bool(sufficient_resources).is_true()
	assert_bool(insufficient_resources).is_false()

func test_resource_reserve_calculation():
	# 測試資源保留計算
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	var reserve_amounts = auto_battle_manager.calculate_resource_reserves(test_player_data)

	# 應該保留設定百分比的資源
	var expected_gold_reserve = test_player_data.resources.gold * 0.2 # 20%
	var expected_troops_reserve = test_player_data.resources.troops * 0.2

	assert_int(reserve_amounts.gold).is_equal(int(expected_gold_reserve))
	assert_int(reserve_amounts.troops).is_equal(int(expected_troops_reserve))

func test_auto_upgrade_decision():
	# 測試自動升級決策
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	# 資源充足時應該建議升級
	var wealthy_player = test_player_data.duplicate()
	wealthy_player.resources.gold = 10000

	var should_upgrade_wealthy = auto_battle_manager.should_auto_upgrade_equipment(wealthy_player)
	var should_upgrade_normal = auto_battle_manager.should_auto_upgrade_equipment(test_player_data)

	assert_bool(should_upgrade_wealthy).is_true()
	# 普通資源狀況下可能不需要立即升級

func test_emergency_resource_protection():
	# 測試緊急資源保護
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	var low_resource_player = test_player_data.duplicate()
	low_resource_player.resources.gold = 800
	low_resource_player.resources.troops = 400

	var can_battle = auto_battle_manager.can_initiate_battle(low_resource_player, test_cities_data[0])

	# 資源過低時應該拒絕戰鬥
	assert_bool(can_battle).is_false()

# === 自動戰鬥執行測試 ===

func test_battle_initiation_logic():
	# 測試戰鬥發起邏輯
	auto_battle_manager.initialize(test_player_data, test_automation_config)
	auto_battle_manager.available_cities = test_cities_data

	var battle_plan = auto_battle_manager.create_battle_plan(test_player_data)

	if not battle_plan.is_empty():
		assert_dict(battle_plan).contains_key("target_city")
		assert_dict(battle_plan).contains_key("allocated_troops")
		assert_dict(battle_plan).contains_key("estimated_cost")
		assert_dict(battle_plan).contains_key("success_probability")

func test_simultaneous_battle_limit():
	# 測試同時戰鬥數量限制
	auto_battle_manager.initialize(test_player_data, test_automation_config)
	auto_battle_manager.active_battles = ["battle_1", "battle_2"] # 達到上限

	var can_start_new = auto_battle_manager.can_start_new_battle()
	assert_bool(can_start_new).is_false()

	# 清空活躍戰鬥
	auto_battle_manager.active_battles.clear()
	var can_start_after_clear = auto_battle_manager.can_start_new_battle()
	assert_bool(can_start_after_clear).is_true()

func test_battle_result_processing():
	# 測試戰鬥結果處理
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	var victory_result = {
		"victor": "player",
		"spoils": {"gold": 1500, "experience": 300, "reputation": 50},
		"city_conquered": "test_weak_city"
	}

	var defeat_result = {
		"victor": "defender",
		"losses": {"troops": 200, "gold": 500, "morale": 10}
	}

	# 處理勝利
	auto_battle_manager.process_battle_result(victory_result, test_player_data)
	# 處理失敗
	auto_battle_manager.process_battle_result(defeat_result, test_player_data)

	# 驗證結果記錄
	var battle_history = auto_battle_manager.get_battle_history()
	assert_int(battle_history.size()).is_greater_equal(2)

# === 離線進度系統測試 ===

func test_offline_time_calculation():
	# 測試離線時間計算
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	var current_time = Time.get_unix_time_from_system()
	var offline_start = current_time - 3600 * 6 # 6小時前

	var offline_hours = auto_battle_manager.calculate_offline_hours(offline_start, current_time)
	assert_float(offline_hours).is_equal(6.0)

func test_offline_progress_calculation():
	# 測試離線進度計算
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	var offline_hours = 12.0
	var progress = auto_battle_manager.calculate_offline_progress(test_player_data, offline_hours)

	assert_dict(progress).contains_key("battles_fought")
	assert_dict(progress).contains_key("resources_gained")
	assert_dict(progress).contains_key("cities_conquered")
	assert_dict(progress).contains_key("experience_gained")

	# 12小時應該有合理的進度
	assert_int(progress.battles_fought).is_greater(0)
	assert_int(progress.resources_gained.get("gold", 0)).is_greater(0)

func test_diminishing_returns_application():
	# 測試遞減收益應用
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	var short_offline = auto_battle_manager.calculate_offline_progress(test_player_data, 4.0) # 4小時
	var long_offline = auto_battle_manager.calculate_offline_progress(test_player_data, 16.0) # 16小時

	# 長時間離線的每小時收益應該更低（遞減效應）
	var short_hourly_gold = short_offline.resources_gained.get("gold", 0) / 4.0
	var long_hourly_gold = long_offline.resources_gained.get("gold", 0) / 16.0

	assert_float(short_hourly_gold).is_greater(long_hourly_gold)

func test_max_offline_time_limit():
	# 測試最大離線時間限制
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	var excessive_offline_hours = 48.0 # 超過24小時限制
	var limited_progress = auto_battle_manager.calculate_offline_progress(test_player_data, excessive_offline_hours)

	# 進度應該被限制在24小時內
	var max_hours = test_automation_config.offline_progression.max_offline_hours
	var expected_max_battles = max_hours * test_automation_config.offline_progression.max_battle_attempts_per_hour

	assert_int(limited_progress.battles_fought).is_less_equal(expected_max_battles)

# === 效率和優化測試 ===

func test_target_selection_efficiency():
	# 測試目標選擇效率
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	var efficiency_targets = []
	for i in range(3):
		var target = test_cities_data[i]
		var efficiency = auto_battle_manager.calculate_conquest_efficiency(target, test_player_data)
		efficiency_targets.append({"target": target, "efficiency": efficiency})

	# 效率應該是可比較的數值
	for efficiency_data in efficiency_targets:
		assert_float(efficiency_data.efficiency).is_greater_equal(0.0)

func test_automation_performance():
	# 測試自動化性能
	auto_battle_manager.initialize(test_player_data, test_automation_config)
	auto_battle_manager.available_cities = test_cities_data

	var start_time = Time.get_unix_time_from_system()

	# 執行100次目標選擇
	for i in range(100):
		auto_battle_manager.select_optimal_target(test_player_data)

	var end_time = Time.get_unix_time_from_system()
	var duration = end_time - start_time

	# 100次操作應該在合理時間內完成
	assert_float(duration).is_less(1.0)

# === 配置和設定測試 ===

func test_automation_config_update():
	# 測試自動化配置更新
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	var new_config = {
		"aggression_level": "aggressive",
		"resource_reserve_percentage": 30,
		"auto_battle_enabled": false
	}

	auto_battle_manager.update_automation_config(new_config)

	assert_str(auto_battle_manager.automation_config.aggression_level).is_equal("aggressive")
	assert_int(auto_battle_manager.automation_config.resource_reserve_percentage).is_equal(30)
	assert_bool(auto_battle_manager.automation_config.auto_battle_enabled).is_false()

func test_automation_pause_resume():
	# 測試自動化暫停和恢復
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	# 暫停自動化
	auto_battle_manager.pause_automation()
	assert_bool(auto_battle_manager.is_paused()).is_true()

	# 恢復自動化
	auto_battle_manager.resume_automation()
	assert_bool(auto_battle_manager.is_paused()).is_false()

# === 錯誤處理和邊界條件測試 ===

func test_no_available_targets():
	# 測試無可用目標的處理
	auto_battle_manager.initialize(test_player_data, test_automation_config)
	auto_battle_manager.available_cities = [] # 無可用城池

	var selected_target = auto_battle_manager.select_optimal_target(test_player_data)
	assert_dict(selected_target).is_empty()

func test_insufficient_resources_handling():
	# 測試資源不足的處理
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	var poor_player = test_player_data.duplicate()
	poor_player.resources.gold = 100
	poor_player.resources.troops = 50

	var can_battle = auto_battle_manager.can_initiate_battle(poor_player, test_cities_data[0])
	assert_bool(can_battle).is_false()

func test_invalid_automation_settings():
	# 測試無效自動化設定處理
	var invalid_player_data = test_player_data.duplicate()
	invalid_player_data.automation_settings = null

	# 應該使用默認設定
	auto_battle_manager.initialize(invalid_player_data, test_automation_config)
	assert_bool(auto_battle_manager.is_initialized()).is_true()

# === 新增：難度縮放系統測試 ===

func test_difficulty_scaling_calculation():
	# 測試難度縮放計算
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	# 模擬不同的戰鬥完成數
	auto_battle_manager.battles_completed = 0
	var initial_scaling = auto_battle_manager._calculate_difficulty_scaling()

	auto_battle_manager.battles_completed = 50
	var mid_scaling = auto_battle_manager._calculate_difficulty_scaling()

	auto_battle_manager.battles_completed = 100
	var high_scaling = auto_battle_manager._calculate_difficulty_scaling()

	# 難度應該隨著戰鬥次數增加
	assert_float(initial_scaling).is_less_equal(mid_scaling)
	assert_float(mid_scaling).is_less_equal(high_scaling)

	# 應該在合理範圍內
	assert_float(initial_scaling).is_greater_equal(1.0)
	assert_float(high_scaling).is_less_equal(10.0)

func test_streak_modifier_impact():
	# 測試連勝/連敗修正
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	# 測試連勝
	auto_battle_manager.consecutive_victories = 10
	auto_battle_manager.consecutive_defeats = 0
	var victory_modifier = auto_battle_manager._calculate_streak_modifier()

	# 測試連敗
	auto_battle_manager.consecutive_victories = 0
	auto_battle_manager.consecutive_defeats = 5
	var defeat_modifier = auto_battle_manager._calculate_streak_modifier()

	# 測試平衡狀態
	auto_battle_manager.consecutive_victories = 2
	auto_battle_manager.consecutive_defeats = 1
	var balanced_modifier = auto_battle_manager._calculate_streak_modifier()

	# 連勝應該增加難度，連敗應該降低難度
	assert_float(victory_modifier).is_greater(balanced_modifier)
	assert_float(defeat_modifier).is_less(balanced_modifier)

func test_dynamic_success_rate_balancing():
	# 測試動態成功率平衡
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	# 模擬高勝率情況
	auto_battle_manager.automation_statistics = {
		"total_battles": 100,
		"total_victories": 90  # 90% 勝率
	}

	var base_rate = 0.8
	var adjusted_high_rate = auto_battle_manager._adjust_success_rate_for_balance(base_rate)

	# 模擬低勝率情況
	auto_battle_manager.automation_statistics = {
		"total_battles": 100,
		"total_victories": 50  # 50% 勝率
	}

	var adjusted_low_rate = auto_battle_manager._adjust_success_rate_for_balance(base_rate)

	# 高勝率時應該降低成功率，低勝率時應該提高成功率
	assert_float(adjusted_high_rate).is_less(base_rate)
	assert_float(adjusted_low_rate).is_greater_equal(base_rate)

func test_reward_scaling_calculation():
	# 測試獎勵縮放計算
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	auto_battle_manager.battles_completed = 0
	var initial_rewards = auto_battle_manager._calculate_reward_scaling()

	auto_battle_manager.battles_completed = 50
	var scaled_rewards = auto_battle_manager._calculate_reward_scaling()

	# 獎勵應該隨難度增加
	assert_float(scaled_rewards).is_greater_equal(initial_rewards)

	# 應該在合理範圍內
	assert_float(initial_rewards).is_greater_equal(1.0)
	assert_float(scaled_rewards).is_less_equal(3.0)

func test_enemy_power_scaling():
	# 測試敵方戰力縮放
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	var base_power = 1000.0
	auto_battle_manager.battles_completed = 0
	var initial_power = auto_battle_manager._calculate_enemy_power_scaling(base_power)

	auto_battle_manager.battles_completed = 30
	var scaled_power = auto_battle_manager._calculate_enemy_power_scaling(base_power)

	# 敵方戰力應該隨難度增加
	assert_float(scaled_power).is_greater_equal(initial_power)

# === 新增：增強離線進度測試 ===

func test_enhanced_offline_progression():
	# 測試增強版離線進度
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	# 設置一些戰鬥歷史
	auto_battle_manager.battles_completed = 25
	auto_battle_manager.automation_statistics = {
		"total_battles": 30,
		"total_victories": 22
	}

	var offline_hours = 8.0
	var progress = auto_battle_manager.calculate_offline_progress(test_player_data, offline_hours)

	# 檢查新增的字段
	assert_dict(progress).contains_key("win_rate_achieved")
	assert_dict(progress).contains_key("difficulty_scaling")
	assert_dict(progress).contains_key("progression_events")

	# 勝率應該是合理的
	var win_rate = progress.get("win_rate_achieved", 0.0)
	assert_float(win_rate).is_greater(0.0)
	assert_float(win_rate).is_less_equal(1.0)

func test_offline_battles_per_hour():
	# 測試離線戰鬥頻率計算
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	var battles_per_hour = auto_battle_manager._calculate_offline_battles_per_hour()

	# 應該是合理的數值
	assert_float(battles_per_hour).is_greater(0.0)
	assert_float(battles_per_hour).is_less_equal(10.0)

func test_offline_city_conquest_calculation():
	# 測試離線城池征服計算
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	# 測試不同的勝利數量
	var few_victories = auto_battle_manager._calculate_offline_cities_conquered(20, test_player_data)
	var many_victories = auto_battle_manager._calculate_offline_cities_conquered(100, test_player_data)

	# 更多勝利應該征服更多城池
	assert_int(many_victories).is_greater_equal(few_victories)

	# 不應該超過可征服的城池數量
	var total_cities = 16
	var owned_cities = test_player_data.get("owned_cities", []).size()
	var max_conquerable = total_cities - owned_cities

	assert_int(many_victories).is_less_equal(max_conquerable)

func test_offline_random_events_simulation():
	# 測試離線隨機事件模擬
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	var few_battles_events = auto_battle_manager._simulate_offline_random_events(5)
	var many_battles_events = auto_battle_manager._simulate_offline_random_events(100)

	# 更多戰鬥應該有更多機會觸發事件
	assert_int(many_battles_events.size()).is_greater_equal(few_battles_events.size())

func test_offline_progress_application():
	# 測試離線進度應用
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	var initial_gold = test_player_data.resources.get("gold", 0)
	var initial_troops = test_player_data.resources.get("troops", 0)
	var initial_experience = test_player_data.get("experience", 0)

	var mock_progress = {
		"battles_fought": 50,
		"successful_battles": 35,
		"failed_battles": 15,
		"resources_gained": {
			"gold": 2000,
			"troops": 300,
			"experience": 800
		},
		"resources_lost": {
			"troops": 100
		},
		"cities_conquered": 1,
		"offline_hours": 8.0
	}

	auto_battle_manager.apply_offline_progress(mock_progress, test_player_data)

	# 檢查資源是否正確更新
	assert_int(test_player_data.resources.gold).is_equal(initial_gold + 2000)
	assert_int(test_player_data.resources.troops).is_equal(initial_troops + 300 - 100)
	assert_int(test_player_data.experience).is_equal(initial_experience + 800)

# === 新增：放置遊戲循環測試 ===

func test_idle_game_loop_startup():
	# 測試放置遊戲循環啟動
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	# 模擬技能選擇完成
	auto_battle_manager.start_idle_game_loop()

	# 檢查自動化狀態
	assert_bool(auto_battle_manager.is_auto_battle_enabled()).is_true()
	assert_bool(auto_battle_manager.is_auto_paused()).is_false()

	# 檢查計時器是否啟動
	assert_object(auto_battle_manager.auto_battle_timer).is_not_null()

func test_battle_frequency_update():
	# 測試戰鬥頻率更新
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	var initial_frequency = auto_battle_manager.battle_frequency

	# 模擬多次戰鬥
	for i in range(10):
		auto_battle_manager.update_battle_frequency()
		auto_battle_manager.battles_completed += 1

	var updated_frequency = auto_battle_manager.battle_frequency

	# 頻率應該隨著戰鬥增加而增加（間隔變長）
	assert_float(updated_frequency).is_greater_equal(initial_frequency)

func test_auto_battle_execution_conditions():
	# 測試自動戰鬥執行條件
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	# 正常情況下應該可以執行
	assert_bool(auto_battle_manager.should_auto_battle()).is_true()

	# 暫停時不應該執行
	auto_battle_manager.pause_automation()
	assert_bool(auto_battle_manager.should_auto_battle()).is_false()

	# 恢復後應該可以執行
	auto_battle_manager.resume_automation()
	assert_bool(auto_battle_manager.should_auto_battle()).is_true()

# === 新增：整合測試 ===

func test_complete_battle_workflow():
	# 測試完整戰鬥工作流程
	auto_battle_manager.initialize(test_player_data, test_automation_config)
	auto_battle_manager.available_cities = test_cities_data

	# 選擇目標
	var target = auto_battle_manager.select_optimal_target()
	assert_dict(target).is_not_empty()

	# 創建戰鬥計劃
	var battle_plan = auto_battle_manager.create_battle_plan(target, test_player_data)
	assert_dict(battle_plan).is_not_empty()

	# 檢查可以發起戰鬥
	var can_battle = auto_battle_manager.can_initiate_battle(test_player_data, target)
	assert_bool(can_battle).is_true()

func test_difficulty_progression_over_time():
	# 測試隨時間變化的難度進展
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	var initial_city = test_cities_data[0].duplicate()
	var initial_success_rate = auto_battle_manager.calculate_conquest_success_rate(initial_city, test_player_data)

	# 模擬經過大量戰鬥
	auto_battle_manager.battles_completed = 100
	auto_battle_manager.automation_statistics = {
		"total_battles": 120,
		"total_victories": 90
	}

	var later_success_rate = auto_battle_manager.calculate_conquest_success_rate(initial_city, test_player_data)

	# 由於難度縮放，後期成功率應該更低
	assert_float(later_success_rate).is_less_equal(initial_success_rate)

func test_resource_balance_over_progression():
	# 測試進展過程中的資源平衡
	auto_battle_manager.initialize(test_player_data, test_automation_config)

	# 模擬不同進度階段的獎勵
	auto_battle_manager.battles_completed = 0
	var early_rewards = auto_battle_manager.calculate_expected_rewards(test_cities_data[0])

	auto_battle_manager.battles_completed = 50
	var mid_rewards = auto_battle_manager.calculate_expected_rewards(test_cities_data[0])

	auto_battle_manager.battles_completed = 100
	var late_rewards = auto_battle_manager.calculate_expected_rewards(test_cities_data[0])

	# 獎勵應該隨著進度增加
	assert_int(mid_rewards.gold).is_greater_equal(early_rewards.gold)
	assert_int(late_rewards.gold).is_greater_equal(mid_rewards.gold)