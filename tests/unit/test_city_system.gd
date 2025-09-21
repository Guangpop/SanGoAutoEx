# test_city_system.gd - 城池系統單元測試
#
# 測試範圍：
# - 城池數據載入和管理
# - 城池征服邏輯
# - 地區控制系統
# - 收益計算和加成
# - 解鎖條件驗證

extends GdUnitTestSuite

# 測試用數據
var test_player_data: Dictionary
var test_cities_data: Array
var city_manager: Node

func before_test() -> void:
	# 設置測試用玩家數據
	test_player_data = {
		"level": 5,
		"attributes": {
			"武力": 80,
			"智力": 70,
			"統治": 75,
			"政治": 65,
			"魅力": 60,
			"天命": 85
		},
		"resources": {
			"gold": 5000,
			"troops": 2000,
			"food": 1500
		},
		"owned_cities": ["chengdu"]
	}

	# 設置測試用城池數據
	test_cities_data = [
		{
			"id": "test_city_1",
			"name": "測試城池1",
			"region": "測試地區",
			"kingdom": "neutral",
			"position": {"x": 100, "y": 100},
			"tier": "medium",
			"population": 50000,
			"base_stats": {
				"defense": 70,
				"prosperity": 60,
				"loyalty": 50,
				"recruitment": 65
			},
			"resources": {
				"gold_per_turn": 300,
				"troops_per_turn": 50,
				"food_per_turn": 80
			},
			"special_features": ["trade_center"],
			"unlock_conditions": {"level": 3},
			"conquest_difficulty": 70,
			"garrison_strength": 1000
		},
		{
			"id": "test_city_2",
			"name": "測試城池2",
			"region": "測試地區",
			"kingdom": "neutral",
			"tier": "small",
			"population": 30000,
			"base_stats": {
				"defense": 50,
				"prosperity": 45,
				"loyalty": 60,
				"recruitment": 55
			},
			"resources": {
				"gold_per_turn": 200,
				"troops_per_turn": 30,
				"food_per_turn": 60
			},
			"unlock_conditions": {"default": true},
			"conquest_difficulty": 50,
			"garrison_strength": 600
		}
	]

	# 創建城池管理器實例（用於測試）
	var city_manager_script = load("res://scripts/systems/CityManager.gd")
	city_manager = city_manager_script.new()

func after_test() -> void:
	# 清理測試實例
	if city_manager:
		city_manager.queue_free()
		city_manager = null

# === 城池數據管理測試 ===

func test_city_data_loading():
	# 測試城池數據載入
	# 由於這是單元測試，我們模擬數據載入
	city_manager.cities_data = test_cities_data
	city_manager.initialize_city_states()

	# 驗證城池數據是否正確載入
	assert_int(city_manager.cities_data.size()).is_equal(2)

	# 驗證城池狀態是否正確初始化
	assert_dict(city_manager.city_states).contains_key("test_city_1")
	assert_dict(city_manager.city_states).contains_key("test_city_2")

	var city1_state = city_manager.get_city_state("test_city_1")
	assert_str(city1_state.get("owner")).is_equal("neutral")
	assert_int(city1_state.get("level")).is_equal(1)

func test_city_data_retrieval():
	# 測試城池數據獲取
	city_manager.cities_data = test_cities_data
	city_manager.initialize_city_states()

	var city_data = city_manager.get_city_data("test_city_1")
	assert_str(city_data.get("name")).is_equal("測試城池1")
	assert_str(city_data.get("tier")).is_equal("medium")

	# 測試不存在城池的處理
	var empty_data = city_manager.get_city_data("non_existent_city")
	assert_dict(empty_data).is_empty()

func test_player_cities_management():
	# 測試玩家城池管理
	city_manager.cities_data = test_cities_data
	city_manager.initialize_city_states()

	# 初始應該有成都
	var initial_cities = city_manager.get_player_cities()
	assert_array(initial_cities).contains("chengdu")

	# 添加新城池
	city_manager.player_cities.append("test_city_1")
	city_manager.city_states["test_city_1"]["owner"] = "player"

	var updated_cities = city_manager.get_player_cities()
	assert_array(updated_cities).contains("test_city_1")

# === 解鎖條件測試 ===

func test_unlock_conditions_level():
	# 測試等級解鎖條件
	city_manager.cities_data = test_cities_data

	var city_data = test_cities_data[0] # 需要等級3

	# 等級不足
	var low_level_player = test_player_data.duplicate()
	low_level_player.level = 2
	assert_bool(city_manager.check_unlock_conditions(city_data, low_level_player)).is_false()

	# 等級足夠
	assert_bool(city_manager.check_unlock_conditions(city_data, test_player_data)).is_true()

func test_unlock_conditions_default():
	# 測試預設解鎖條件
	city_manager.cities_data = test_cities_data

	var city_data = test_cities_data[1] # 預設解鎖
	assert_bool(city_manager.check_unlock_conditions(city_data, test_player_data)).is_true()

func test_conquerable_cities():
	# 測試可征服城池查詢
	city_manager.cities_data = test_cities_data
	city_manager.initialize_city_states()

	var conquerable = city_manager.get_conquerable_cities(test_player_data)

	# 應該包含滿足條件的城池
	assert_array(conquerable).is_not_empty()

	# 驗證返回的城池確實滿足解鎖條件
	for city in conquerable:
		assert_bool(city_manager.check_unlock_conditions(city, test_player_data)).is_true()

# === 圍攻系統測試 ===

func test_siege_cost_calculation():
	# 測試圍攻成本計算
	city_manager.conquest_config = {
		"base_requirements": {
			"siege_duration_days": 7
		},
		"victory_rewards": {
			"tier_multipliers": {
				"medium": 1.5,
				"small": 1.0
			}
		}
	}

	var city_data = test_cities_data[0]
	var attacking_force = {"troops": 1500, "gold": 3000}

	var siege_cost = city_manager.calculate_siege_cost(city_data, attacking_force)

	assert_dict(siege_cost).contains_key("daily_cost")
	assert_dict(siege_cost).contains_key("troop_attrition")
	assert_dict(siege_cost).contains_key("total_gold_cost")
	assert_int(siege_cost.daily_cost).is_greater(0)

func test_siege_requirements_validation():
	# 測試圍攻條件驗證
	city_manager.conquest_config = {
		"base_requirements": {
			"min_troops": 500,
			"min_gold": 1000
		}
	}

	var valid_force = {"troops": 1000, "gold": 2000}
	var invalid_force_troops = {"troops": 300, "gold": 2000}
	var invalid_force_gold = {"troops": 1000, "gold": 500}

	var siege_cost = {"total_gold_cost": 1500}

	assert_bool(city_manager.validate_siege_requirements(valid_force, siege_cost)).is_true()
	assert_bool(city_manager.validate_siege_requirements(invalid_force_troops, siege_cost)).is_false()
	assert_bool(city_manager.validate_siege_requirements(invalid_force_gold, siege_cost)).is_false()

func test_siege_duration_calculation():
	# 測試圍攻持續時間計算
	city_manager.conquest_config = {
		"base_requirements": {
			"siege_duration_days": 7
		}
	}

	var city_data = test_cities_data[0]
	var strong_force = {"troops": 2000, "siege_power": 2500}
	var weak_force = {"troops": 800, "siege_power": 900}

	var strong_duration = city_manager.calculate_siege_duration(city_data, strong_force)
	var weak_duration = city_manager.calculate_siege_duration(city_data, weak_force)

	# 強力部隊應該需要更短時間
	assert_int(strong_duration).is_less(weak_duration)
	assert_int(strong_duration).is_greater_equal(3) # 最少3天

func test_siege_success_chance():
	# 測試圍攻成功率計算
	var city_data = test_cities_data[0]
	var overwhelming_force = {"troops": 3000, "siege_equipment": 500}
	var weak_force = {"troops": 500, "siege_equipment": 0}

	var high_chance = city_manager.calculate_siege_success_chance(city_data, overwhelming_force)
	var low_chance = city_manager.calculate_siege_success_chance(city_data, weak_force)

	# 強力部隊應該有更高成功率
	assert_float(high_chance).is_greater(low_chance)
	assert_float(high_chance).is_less_equal(0.9)
	assert_float(low_chance).is_greater_equal(0.1)

func test_start_city_siege():
	# 測試開始圍攻
	city_manager.cities_data = test_cities_data
	city_manager.initialize_city_states()
	city_manager.conquest_config = {
		"base_requirements": {
			"min_troops": 500,
			"min_gold": 1000,
			"siege_duration_days": 7
		}
	}

	var attacking_force = {
		"troops": 1500,
		"gold": 3000,
		"siege_power": 1800
	}

	var result = city_manager.start_city_siege("test_city_1", attacking_force)

	if result.get("success", false):
		assert_dict(result).contains_key("siege_duration")
		assert_dict(result).contains_key("daily_cost")
		assert_dict(result).contains_key("success_chance")

		# 驗證城池狀態更新
		var city_state = city_manager.get_city_state("test_city_1")
		assert_bool(city_state.get("under_siege")).is_true()

# === 城池征服測試 ===

func test_conquest_spoils_calculation():
	# 測試征服戰利品計算
	city_manager.conquest_config = {
		"victory_rewards": {
			"base_rewards": {
				"gold": 2000,
				"experience": 500,
				"reputation": 100,
				"equipment_chance": 0.3
			},
			"tier_multipliers": {
				"medium": 1.5,
				"small": 1.0
			}
		}
	}

	var medium_city = test_cities_data[0]
	var small_city = test_cities_data[1]

	var medium_spoils = city_manager.calculate_conquest_spoils(medium_city)
	var small_spoils = city_manager.calculate_conquest_spoils(small_city)

	# 中型城池應該給予更多獎勵
	assert_int(medium_spoils.gold).is_greater(small_spoils.gold)
	assert_int(medium_spoils.experience).is_greater(small_spoils.experience)

func test_conquest_success_handling():
	# 測試征服成功處理
	city_manager.cities_data = test_cities_data
	city_manager.initialize_city_states()
	city_manager.conquest_config = {
		"victory_rewards": {
			"base_rewards": {"gold": 1000, "experience": 200, "reputation": 50},
			"tier_multipliers": {"medium": 1.0}
		}
	}

	var city_data = test_cities_data[0]
	var attacking_force = {"troops": 1500}

	# 設置圍攻狀態
	city_manager.city_states["test_city_1"]["under_siege"] = true
	city_manager.city_states["test_city_1"]["besieging_force"] = attacking_force

	var result = city_manager._handle_conquest_success("test_city_1", city_data, attacking_force)

	assert_bool(result.success).is_true()
	assert_dict(result).contains_key("spoils")

	# 驗證城池所有權變更
	var city_state = city_manager.get_city_state("test_city_1")
	assert_str(city_state.owner).is_equal("player")
	assert_bool(city_state.under_siege).is_false()

# === 收益計算測試 ===

func test_city_income_calculation():
	# 測試城池收益計算
	city_manager.cities_data = test_cities_data
	city_manager.initialize_city_states()

	# 設置測試城池為玩家所有
	city_manager.city_states["test_city_1"]["owner"] = "player"
	city_manager.city_states["test_city_1"]["level"] = 2
	city_manager.city_states["test_city_1"]["loyalty"] = 80

	var income = city_manager.get_city_income("test_city_1")

	assert_dict(income).contains_key("gold")
	assert_dict(income).contains_key("troops")
	assert_dict(income).contains_key("food")
	assert_int(income.gold).is_greater(0)

func test_total_city_income():
	# 測試總城池收益計算
	city_manager.cities_data = test_cities_data
	city_manager.initialize_city_states()

	# 設置玩家擁有多個城池
	city_manager.player_cities = ["chengdu", "test_city_1"]
	city_manager.city_states["test_city_1"]["owner"] = "player"

	var total_income = city_manager.get_total_city_income()

	assert_dict(total_income).contains_key("gold")
	assert_dict(total_income).contains_key("troops")
	assert_dict(total_income).contains_key("food")

func test_city_bonuses():
	# 測試城池加成效果
	var city_with_features = {
		"special_features": ["imperial_palace", "silk_trade", "weapon_forge"]
	}

	city_manager.cities_data = [city_with_features]
	var bonuses = city_manager.get_city_bonuses("test_city")

	# 應該包含特殊設施的加成
	assert_dict(bonuses).contains_key("political_power")
	assert_dict(bonuses).contains_key("trade_income")
	assert_dict(bonuses).contains_key("military_production")

# === 地區控制測試 ===

func test_regional_control_calculation():
	# 測試地區控制計算
	city_manager.cities_data = test_cities_data
	city_manager.initialize_city_states()

	# 設置玩家控制部分城池
	city_manager.player_cities = ["test_city_1"]
	city_manager.city_states["test_city_1"]["owner"] = "player"

	city_manager.update_regional_control()

	var regional_control = city_manager.get_regional_control()
	assert_dict(regional_control).contains_key("測試地區")

	var region_data = regional_control["測試地區"]
	assert_int(region_data.player).is_equal(1)
	assert_int(region_data.total).is_equal(2)
	assert_float(region_data.control_ratio).is_equal(0.5)

func test_regional_control_status():
	# 測試地區控制狀態判定
	city_manager.cities_data = test_cities_data
	city_manager.initialize_city_states()
	city_manager.regional_control = {
		"測試地區": {"player": 2, "total": 2, "controller": "neutral"}
	}

	city_manager.update_regional_control()

	var regional_control = city_manager.get_regional_control()
	var controller = regional_control["測試地區"]["controller"]

	# 控制70%以上應該成為控制者
	# 這裡需要根據實際的控制邏輯調整

func test_controlled_regions():
	# 測試控制地區查詢
	city_manager.regional_control = {
		"地區1": {"controller": "player"},
		"地區2": {"controller": "neutral"},
		"地區3": {"controller": "player"}
	}

	var controlled = city_manager.get_controlled_regions()
	assert_array(controlled).contains("地區1")
	assert_array(controlled).contains("地區3")
	assert_array(controlled).not_contains("地區2")

# === 統計和查詢測試 ===

func test_city_statistics():
	# 測試城池統計
	city_manager.cities_data = test_cities_data
	city_manager.player_cities = ["test_city_1"]

	var stats = city_manager.get_city_statistics()

	assert_dict(stats).contains_key("total_cities")
	assert_dict(stats).contains_key("player_cities")
	assert_dict(stats).contains_key("control_percentage")

	assert_int(stats.total_cities).is_equal(2)
	assert_int(stats.player_cities).is_equal(1)
	assert_float(stats.control_percentage).is_equal(0.5)

func test_cities_by_region():
	# 測試按地區查詢城池
	city_manager.cities_data = test_cities_data

	var region_cities = city_manager.get_cities_by_region("測試地區")
	assert_array(region_cities).has_size(2)

	var empty_region = city_manager.get_cities_by_region("不存在地區")
	assert_array(empty_region).is_empty()

# === 邊界條件測試 ===

func test_invalid_city_operations():
	# 測試無效城池操作
	city_manager.cities_data = test_cities_data
	city_manager.initialize_city_states()

	# 嘗試圍攻不存在的城池
	var result = city_manager.start_city_siege("non_existent_city", {"troops": 1000})
	assert_bool(result.success).is_false()
	assert_str(result.error).is_equal("city_not_found")

	# 嘗試圍攻自己的城池
	city_manager.city_states["test_city_1"]["owner"] = "player"
	var self_attack = city_manager.start_city_siege("test_city_1", {"troops": 1000})
	assert_bool(self_attack.success).is_false()
	assert_str(self_attack.error).is_equal("own_city")

func test_siege_resource_validation():
	# 測試圍攻資源驗證
	city_manager.conquest_config = {
		"base_requirements": {
			"min_troops": 500,
			"min_gold": 1000
		}
	}

	var insufficient_force = {"troops": 300, "gold": 500}
	var siege_cost = {"total_gold_cost": 1500}

	assert_bool(city_manager.validate_siege_requirements(insufficient_force, siege_cost)).is_false()

# === 性能測試 ===

func test_city_management_performance():
	# 測試城池管理性能
	var start_time = Time.get_unix_time_from_system()

	# 執行大量城池操作
	for i in range(1000):
		city_manager.get_total_city_income()
		city_manager.update_regional_control()

	var end_time = Time.get_unix_time_from_system()
	var duration = end_time - start_time

	# 1000次操作應該在合理時間內完成
	assert_float(duration).is_less(2.0)