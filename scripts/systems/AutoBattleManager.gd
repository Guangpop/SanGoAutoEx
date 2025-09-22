# AutoBattleManager.gd - 自動戰鬥管理系統
#
# 功能：
# - 管理閒置遊戲的自動戰鬥循環
# - 智能目標選擇和決策引擎
# - 離線進度計算和資源管理
# - 玩家自動化偏好設定

extends Node

signal auto_battle_started(target_city: Dictionary, battle_plan: Dictionary)
signal auto_battle_completed(result: Dictionary, spoils: Dictionary)
signal automation_paused(reason: String)
signal automation_resumed()
signal offline_progress_calculated(progress: Dictionary, offline_hours: float)

# 自動化狀態
var is_auto_enabled: bool = false
var is_paused: bool = false
var is_system_initialized: bool = false

# 放置遊戲核心計時器
var auto_battle_timer: Timer
var battle_frequency: float = 5.0  # 默認5秒一場戰鬥
var battles_completed: int = 0
var consecutive_victories: int = 0
var consecutive_defeats: int = 0

# 配置和數據
var automation_config: Dictionary = {}
var player_data: Dictionary = {}
var available_cities: Array = []
var active_battles: Array = []

# 戰鬥歷史和統計
var battle_history: Array[Dictionary] = []
var automation_statistics: Dictionary = {}

# 離線進度追蹤
var last_active_time: float = 0.0
var offline_progress_cache: Dictionary = {}

func _ready() -> void:
	name = "AutoBattleManager"
	LogManager.info("AutoBattleManager", "自動戰鬥管理器初始化")

	# 初始化自動戰鬥計時器
	setup_auto_battle_timer()

	# 連接事件處理器
	connect_event_handlers()

	# 初始化統計數據
	reset_automation_statistics()

# 設置自動戰鬥計時器
func setup_auto_battle_timer() -> void:
	auto_battle_timer = Timer.new()
	auto_battle_timer.wait_time = battle_frequency
	auto_battle_timer.timeout.connect(_on_auto_battle_timer_timeout)
	auto_battle_timer.one_shot = false
	add_child(auto_battle_timer)
	LogManager.debug("AutoBattleManager", "自動戰鬥計時器已設置", {"frequency": battle_frequency})

func connect_event_handlers() -> void:
	EventBus.connect_safe("battle_completed", _on_battle_completed)
	EventBus.connect_safe("city_conquered", _on_city_conquered)
	EventBus.connect_safe("game_state_changed", _on_game_state_changed)
	EventBus.connect_safe("skill_selection_completed", _on_skill_selection_completed)
	LogManager.debug("AutoBattleManager", "事件處理器連接完成")

# === 初始化和配置 ===

# 初始化自動戰鬥系統
func initialize(player_data_ref: Dictionary, config: Dictionary) -> bool:
	LogManager.info("AutoBattleManager", "初始化自動戰鬥系統")

	self.player_data = player_data_ref
	# 設置默認配置
	if config.is_empty():
		config = {
			"target_selection": {
				"min_success_rate": 0.3,
				"prefer_efficiency": true
			},
			"resource_management": {
				"min_gold_reserve": 1000,
				"min_troops_reserve": 100,
				"auto_upgrade_threshold": 5000
			},
			"idle_progression": {
				"base_battle_frequency": 5.0,
				"max_battle_frequency": 30.0,
				"frequency_scaling_factor": 1.15,
				"difficulty_scaling_factor": 1.15,
				"target_win_rate": 0.75
			},
			"offline_progression": {
				"max_offline_hours": 24,
				"diminishing_returns_start": 8,
				"diminishing_returns_rate": 0.1,
				"max_battle_attempts_per_hour": 6
			}
		}

	self.automation_config = config

	# 驗證玩家自動化設定
	var automation_settings = player_data_ref.get("automation_settings", {})
	if not validate_automation_settings(automation_settings):
		LogManager.warning("AutoBattleManager", "使用默認自動化設定")
		automation_settings = get_default_automation_settings()
		# 默認啟用自動戰鬥（放置遊戲需要）
		automation_settings["auto_battle_enabled"] = true
		player_data_ref["automation_settings"] = automation_settings

	is_auto_enabled = automation_settings.get("auto_battle_enabled", true)
	is_system_initialized = true
	last_active_time = Time.get_unix_time_from_system()

	# 載入城池數據
	if CityManager:
		available_cities = CityManager.cities_data.duplicate()

	LogManager.info("AutoBattleManager", "自動戰鬥系統初始化完成", {
		"auto_enabled": is_auto_enabled,
		"aggression_level": automation_settings.get("aggression_level", "balanced"),
		"available_cities": available_cities.size()
	})

	return true

# 驗證自動化設定
func validate_automation_settings(settings: Dictionary) -> bool:
	if settings == null or settings.is_empty():
		return false

	var required_keys = ["auto_battle_enabled", "aggression_level", "resource_reserve_percentage"]
	for key in required_keys:
		if not settings.has(key):
			return false

	# 驗證數值範圍
	var reserve_percentage = settings.get("resource_reserve_percentage", 0)
	if reserve_percentage < 0 or reserve_percentage > 100:
		return false

	var valid_aggression_levels = ["conservative", "balanced", "aggressive"]
	var aggression = settings.get("aggression_level", "")
	if not aggression in valid_aggression_levels:
		return false

	return true

# 獲取默認自動化設定
func get_default_automation_settings() -> Dictionary:
	return {
		"auto_battle_enabled": true,  # 放置遊戲默認啟用
		"aggression_level": "balanced",
		"resource_reserve_percentage": 20,
		"max_simultaneous_battles": 1,  # 簡化為單線程戰鬥
		"auto_upgrade_equipment": true,
		"prefer_efficiency": true
	}

# === 目標選擇系統 ===

# 選擇最優攻擊目標
func select_optimal_target() -> Dictionary:
	if not CityManager:
		LogManager.error("AutoBattleManager", "CityManager未找到")
		return {}

	var current_player_data = GameCore.get_player_data()
	var available_targets = CityManager.get_conquerable_cities(current_player_data)

	if available_targets.is_empty():
		LogManager.debug("AutoBattleManager", "無可用攻擊目標")
		return {}

	var best_target = {}
	var best_score = -1.0

	for target in available_targets:
		if not can_initiate_battle(current_player_data, target):
			continue

		var score = evaluate_target_city(target, current_player_data)
		if score > best_score:
			best_score = score
			best_target = target

	LogManager.debug("AutoBattleManager", "選擇目標", {
		"target": best_target.get("name", "無"),
		"score": best_score
	})

	return best_target

# 評估目標城池價值
func evaluate_target_city(city: Dictionary, current_player_data: Dictionary) -> float:
	var base_score = 0.0

	# 計算征服成功率
	var success_rate = calculate_conquest_success_rate(city, current_player_data)

	# 計算資源效益
	var resource_value = calculate_resource_value(city)

	# 計算征服成本
	var conquest_cost = calculate_conquest_cost(city, current_player_data)

	# 計算效率比值
	var efficiency = resource_value / max(conquest_cost, 1.0)

	# 基礎評分：成功率 × 效率
	base_score = success_rate * efficiency

	# 根據侵略性等級調整
	var aggression = player_data.get("automation_settings", {}).get("aggression_level", "balanced")
	match aggression:
		"conservative":
			base_score *= (success_rate * 2.0) # 偏好高成功率
		"aggressive":
			base_score *= (efficiency * 1.5) # 偏好高效益
		"balanced":
			base_score *= 1.0 # 平衡考慮

	# 城池等級加成
	var tier_multipliers = {"small": 1.0, "medium": 1.2, "major": 1.5, "capital": 2.0}
	var tier_bonus = tier_multipliers.get(city.get("tier", "small"), 1.0)
	base_score *= tier_bonus

	return base_score

# 獲取可用目標列表
func get_available_targets(current_player_data: Dictionary) -> Array:
	var targets: Array = []

	for city in available_cities:
		if is_target_available(city, current_player_data):
			targets.append(city)

	return targets

# 檢查目標是否可用
func is_target_available(city: Dictionary, current_player_data: Dictionary) -> bool:
	var city_id = city.get("id", "")

	# 檢查是否已被玩家擁有
	var owned_cities = current_player_data.get("owned_cities", [])
	if city_id in owned_cities:
		return false

	# 檢查解鎖條件
	if not check_unlock_conditions(city, current_player_data):
		return false

	# 檢查是否正在被圍攻
	if city_id in active_battles:
		return false

	return true

# 檢查解鎖條件
func check_unlock_conditions(city: Dictionary, current_player_data: Dictionary) -> bool:
	var conditions = city.get("unlock_conditions", {})

	# 預設解鎖
	if conditions.get("default", false):
		return true

	# 等級要求
	if conditions.has("level"):
		var required_level = conditions.level
		if current_player_data.get("level", 1) < required_level:
			return false

	# 城池數量要求
	if conditions.has("cities_conquered"):
		var required_cities = conditions.cities_conquered
		var owned_cities = current_player_data.get("owned_cities", [])
		if owned_cities.size() < required_cities:
			return false

	return true

# === 戰鬥執行系統 ===

# 創建戰鬥計劃
func create_battle_plan(target_city: Dictionary, current_player_data: Dictionary) -> Dictionary:
	if not can_start_new_battle():
		return {}

	if target_city.is_empty():
		target_city = select_optimal_target()
		if target_city.is_empty():
			return {}

	var plan = {
		"target_city": target_city,
		"target_city_name": target_city.get("name", ""),
		"troop_allocation": calculate_optimal_troop_allocation(target_city, current_player_data),
		"estimated_cost": calculate_conquest_cost(target_city, current_player_data),
		"success_probability": calculate_conquest_success_rate(target_city, current_player_data),
		"expected_duration": calculate_battle_duration(target_city, current_player_data),
		"expected_rewards": calculate_expected_rewards(target_city),
		"difficulty_rating": target_city.get("conquest_difficulty", 50) / 100.0
	}

	return plan

# 檢查是否可以發起新戰鬥
func can_start_new_battle() -> bool:
	if not is_auto_enabled or is_paused:
		return false

	var max_battles = player_data.get("automation_settings", {}).get("max_simultaneous_battles", 2)
	return active_battles.size() < max_battles

# 檢查是否可以發起特定戰鬥
func can_initiate_battle(current_player_data: Dictionary, target_city: Dictionary) -> bool:
	# 檢查資源可用性
	var conquest_cost = calculate_conquest_cost(target_city, current_player_data)
	if not check_resource_availability(current_player_data, conquest_cost):
		return false

	# 檢查成功率要求
	var success_rate = calculate_conquest_success_rate(target_city, current_player_data)
	var min_success_rate = automation_config.get("target_selection", {}).get("min_success_rate", 0.4)

	return success_rate >= min_success_rate

# 計算最優兵力分配
func calculate_optimal_troop_allocation(target: Dictionary, current_player_data: Dictionary) -> int:
	var garrison_strength = target.get("garrison_strength", 1000)
	var player_power = calculate_player_power_rating(current_player_data)

	# 基於敵我實力比計算所需兵力
	var recommended_troops = int(garrison_strength * 1.2) # 20%優勢
	var available_troops = get_available_troops(current_player_data)

	return min(recommended_troops, available_troops)

# === 資源管理系統 ===

# 檢查資源可用性
func check_resource_availability(current_player_data: Dictionary, required_resources: Dictionary) -> bool:
	var reserves = calculate_resource_reserves(current_player_data)
	var resources = current_player_data.get("resources", {})

	# 檢查金錢
	var required_gold = required_resources.get("gold", 0)
	var available_gold = resources.get("gold", 0) - reserves.get("gold", 0)
	if required_gold > available_gold:
		return false

	# 檢查兵力
	var required_troops = required_resources.get("troops", 0)
	var available_troops = resources.get("troops", 0) - reserves.get("troops", 0)
	if required_troops > available_troops:
		return false

	return true

# 計算資源保留量
func calculate_resource_reserves(current_player_data: Dictionary) -> Dictionary:
	var settings = current_player_data.get("automation_settings", {})
	var reserve_percentage = settings.get("resource_reserve_percentage", 20) / 100.0
	var resources = current_player_data.get("resources", {})

	var reserves = {
		"gold": int(resources.get("gold", 0) * reserve_percentage),
		"troops": int(resources.get("troops", 0) * reserve_percentage),
		"food": int(resources.get("food", 0) * reserve_percentage)
	}

	# 確保最低保留量
	var min_reserves = automation_config.get("resource_management", {})
	reserves.gold = max(reserves.gold, min_reserves.get("min_gold_reserve", 1000))
	reserves.troops = max(reserves.troops, min_reserves.get("min_troops_reserve", 500))

	return reserves

# 獲取可用兵力
func get_available_troops(current_player_data: Dictionary) -> int:
	var total_troops = current_player_data.get("resources", {}).get("troops", 0)
	var reserved_troops = calculate_resource_reserves(current_player_data).get("troops", 0)
	return max(total_troops - reserved_troops, 0)

# 檢查是否應該自動升級裝備
func should_auto_upgrade_equipment(current_player_data: Dictionary) -> bool:
	var settings = current_player_data.get("automation_settings", {})
	if not settings.get("auto_upgrade_equipment", false):
		return false

	var gold = current_player_data.get("resources", {}).get("gold", 0)
	var upgrade_threshold = automation_config.get("resource_management", {}).get("auto_upgrade_threshold", 5000)

	return gold >= upgrade_threshold

# === 難度縮放系統 ===

# 計算指數難度縮放
func _calculate_difficulty_scaling() -> float:
	var config = automation_config.get("idle_progression", {})
	var scaling_factor = config.get("difficulty_scaling_factor", 1.15)

	# 基於戰鬥次數的指數增長
	var base_scaling = pow(scaling_factor, battles_completed / 10.0)

	# 基於城池數量的額外縮放
	var current_player_data = GameCore.get_player_data()
	var owned_cities = current_player_data.get("owned_cities", [])
	var city_bonus = 1.0 + (owned_cities.size() * 0.1)

	# 基於連續勝負的動態調整
	var streak_modifier = _calculate_streak_modifier()

	var final_scaling = base_scaling * city_bonus * streak_modifier

	# 限制最大難度縮放
	return clamp(final_scaling, 1.0, 10.0)

# 計算連勝/連敗修正
func _calculate_streak_modifier() -> float:
	var config = automation_config.get("idle_progression", {})
	var target_win_rate = config.get("target_win_rate", 0.75)

	# 如果連勝太多，增加難度
	if consecutive_victories > 5:
		return 1.0 + (consecutive_victories - 5) * 0.1

	# 如果連敗太多，降低難度
	if consecutive_defeats > 3:
		return max(0.5, 1.0 - (consecutive_defeats - 3) * 0.15)

	return 1.0

# 動態調整成功率以維持目標勝率
func _adjust_success_rate_for_balance(base_rate: float) -> float:
	var config = automation_config.get("idle_progression", {})
	var target_win_rate = config.get("target_win_rate", 0.75)

	# 計算當前勝率
	var current_win_rate = _calculate_current_win_rate()

	# 如果勝率偏離目標太遠，進行調整
	var win_rate_difference = current_win_rate - target_win_rate

	var adjustment = 0.0
	if abs(win_rate_difference) > 0.1:  # 偏離超過10%才調整
		adjustment = -win_rate_difference * 0.3  # 調整幅度

	var adjusted_rate = base_rate + adjustment

	LogManager.debug("AutoBattleManager", "勝率平衡調整", {
		"current_win_rate": current_win_rate,
		"target_win_rate": target_win_rate,
		"adjustment": adjustment,
		"base_rate": base_rate,
		"adjusted_rate": adjusted_rate
	})

	return clamp(adjusted_rate, 0.1, 0.9)

# 計算當前勝率
func _calculate_current_win_rate() -> float:
	var total_battles = automation_statistics.get("total_battles", 0)
	var total_victories = automation_statistics.get("total_victories", 0)

	if total_battles == 0:
		return 0.75  # 默認假設勝率

	return float(total_victories) / float(total_battles)

# 計算動態獎勵縮放
func _calculate_reward_scaling() -> float:
	var difficulty_scaling = _calculate_difficulty_scaling()

	# 獎勵隨難度增加，但有遞減收益
	var reward_scaling = sqrt(difficulty_scaling)

	return clamp(reward_scaling, 1.0, 3.0)

# 計算敵方戰力縮放（用於戰鬥計算）
func _calculate_enemy_power_scaling(base_power: float) -> float:
	var difficulty_scaling = _calculate_difficulty_scaling()

	# 敵方戰力隨難度指數增長
	var scaled_power = base_power * difficulty_scaling

	# 添加隨機變化避免過於固定
	var random_factor = randf_range(0.9, 1.1)
	scaled_power *= random_factor

	LogManager.debug("AutoBattleManager", "敵方戰力縮放", {
		"base_power": base_power,
		"difficulty_scaling": difficulty_scaling,
		"random_factor": random_factor,
		"final_power": scaled_power
	})

	return scaled_power

# === 計算方法 ===

# 計算征服成功率（加入指數難度調整）
func calculate_conquest_success_rate(target: Dictionary, current_player_data: Dictionary) -> float:
	var player_power = calculate_player_power_rating(current_player_data)
	var base_city_defense = target.get("garrison_strength", 1000) + target.get("conquest_difficulty", 50)

	# 指數難度縮放
	var difficulty_scaling = _calculate_difficulty_scaling()
	var scaled_city_defense = base_city_defense * difficulty_scaling

	var power_ratio = float(player_power) / scaled_city_defense
	var base_rate = 0.3 + (power_ratio - 1.0) * 0.4

	# 確保成功率在合理範圍內
	var final_rate = clamp(base_rate, 0.1, 0.9)

	# 動態調整目標勝率
	final_rate = _adjust_success_rate_for_balance(final_rate)

	LogManager.debug("AutoBattleManager", "成功率計算", {
		"base_defense": base_city_defense,
		"scaled_defense": scaled_city_defense,
		"difficulty_scaling": difficulty_scaling,
		"player_power": player_power,
		"final_rate": final_rate
	})

	return final_rate

# 計算玩家戰力評級
func calculate_player_power_rating(current_player_data: Dictionary) -> float:
	var attributes = current_player_data.get("attributes", {})
	var troops = current_player_data.get("resources", {}).get("troops", 0)

	var attribute_power = (
		attributes.get("武力", 0) * 3.0 +
		attributes.get("智力", 0) * 2.5 +
		attributes.get("統治", 0) * 2.0 +
		attributes.get("政治", 0) * 1.5 +
		attributes.get("魅力", 0) * 1.5 +
		attributes.get("天命", 0) * 2.0
	)

	var troop_power = troops * 0.5

	return attribute_power + troop_power

# 計算資源價值
func calculate_resource_value(city: Dictionary) -> float:
	var resources = city.get("resources", {})
	var gold_value = resources.get("gold_per_turn", 0) * 10 # 10回合價值
	var troop_value = resources.get("troops_per_turn", 0) * 20 # 兵力價值更高
	var food_value = resources.get("food_per_turn", 0) * 5

	return gold_value + troop_value + food_value

# 計算征服成本
func calculate_conquest_cost(target: Dictionary, current_player_data: Dictionary) -> Dictionary:
	var base_cost = target.get("conquest_difficulty", 50) * 20
	var troop_cost = target.get("garrison_strength", 1000) * 0.3

	return {
		"gold": int(base_cost),
		"troops": int(troop_cost),
		"time": calculate_battle_duration(target, current_player_data)
	}

# 計算戰鬥持續時間
func calculate_battle_duration(target: Dictionary, current_player_data: Dictionary) -> float:
	var difficulty = target.get("conquest_difficulty", 50)
	var player_power = calculate_player_power_rating(current_player_data)

	var base_duration = 3600.0 # 1小時基礎時間
	var difficulty_modifier = difficulty / 100.0
	var power_modifier = 2000.0 / max(player_power, 100.0)

	return base_duration * difficulty_modifier * power_modifier

# 計算征服效率
func calculate_conquest_efficiency(target: Dictionary, current_player_data: Dictionary) -> float:
	var value = calculate_resource_value(target)
	var cost = calculate_conquest_cost(target, current_player_data)
	var total_cost = cost.get("gold", 1) + cost.get("troops", 1) * 2

	return value / max(total_cost, 1.0)

# 計算預期獎勵（加入動態縮放）
func calculate_expected_rewards(target: Dictionary) -> Dictionary:
	var tier_multipliers = {"small": 1.0, "medium": 1.5, "major": 2.0, "capital": 3.0}
	var base_multiplier = tier_multipliers.get(target.get("tier", "small"), 1.0)

	# 應用動態獎勵縮放
	var reward_scaling = _calculate_reward_scaling()
	var final_multiplier = base_multiplier * reward_scaling

	var base_rewards = {
		"gold": int(2000 * final_multiplier),
		"experience": int(500 * final_multiplier),
		"reputation": int(100 * final_multiplier)
	}

	LogManager.debug("AutoBattleManager", "預期獎勵計算", {
		"base_multiplier": base_multiplier,
		"reward_scaling": reward_scaling,
		"final_multiplier": final_multiplier,
		"rewards": base_rewards
	})

	return base_rewards

# === 離線進度系統 ===

# 計算離線小時數
func calculate_offline_hours(offline_start_time: float, current_time: float) -> float:
	var offline_seconds = current_time - offline_start_time
	return offline_seconds / 3600.0

# 計算離線進度（增強版，整合難度縮放）
func calculate_offline_progress(current_player_data: Dictionary, offline_hours: float) -> Dictionary:
	var config = automation_config.get("offline_progression", {})
	var max_hours = config.get("max_offline_hours", 24)
	var effective_hours = min(offline_hours, max_hours)

	# 計算遞減收益
	var diminishing_start = config.get("diminishing_returns_start", 8)
	var diminishing_rate = config.get("diminishing_returns_rate", 0.1)

	var full_efficiency_hours = min(effective_hours, diminishing_start)
	var diminished_hours = max(effective_hours - diminishing_start, 0)

	var efficiency_factor = full_efficiency_hours + diminished_hours * (1.0 - diminishing_rate)

	# 計算戰鬥次數（根據當前戰鬥頻率調整）
	var battles_per_hour = _calculate_offline_battles_per_hour()
	var total_battles = int(efficiency_factor * battles_per_hour)

	# 使用當前勝率而非固定值
	var current_win_rate = _calculate_current_win_rate()
	var successful_battles = int(total_battles * current_win_rate)
	var failed_battles = total_battles - successful_battles

	# 計算難度縮放下的獎勵
	var reward_scaling = _calculate_reward_scaling()
	var avg_gold_per_victory = int(800 * reward_scaling)
	var avg_troops_per_victory = int(40 * reward_scaling)
	var avg_experience_per_victory = int(150 * reward_scaling)

	var resources_gained = {
		"gold": successful_battles * avg_gold_per_victory,
		"troops": successful_battles * avg_troops_per_victory,
		"experience": successful_battles * avg_experience_per_victory
	}

	# 計算損失（失敗也有縮放）
	var avg_loss_per_defeat = int(200 * sqrt(reward_scaling))
	var resources_lost = {
		"troops": failed_battles * avg_loss_per_defeat
	}

	# 城池征服計算（考慮難度增加）
	var cities_conquered = _calculate_offline_cities_conquered(successful_battles, current_player_data)

	# 模擬離線期間的進展
	var progression_simulation = _simulate_offline_progression(
		total_battles,
		successful_battles,
		cities_conquered
	)

	LogManager.info("AutoBattleManager", "離線進度計算完成", {
		"offline_hours": offline_hours,
		"effective_hours": effective_hours,
		"battles_fought": total_battles,
		"win_rate": current_win_rate,
		"reward_scaling": reward_scaling,
		"cities_conquered": cities_conquered,
		"progression": progression_simulation
	})

	return {
		"battles_fought": total_battles,
		"successful_battles": successful_battles,
		"failed_battles": failed_battles,
		"resources_gained": resources_gained,
		"resources_lost": resources_lost,
		"cities_conquered": cities_conquered,
		"experience_gained": resources_gained.experience,
		"win_rate_achieved": current_win_rate,
		"difficulty_scaling": _calculate_difficulty_scaling(),
		"progression_events": progression_simulation
	}

# 計算離線期間的戰鬥頻率
func _calculate_offline_battles_per_hour() -> float:
	var config = automation_config.get("offline_progression", {})
	var base_battles_per_hour = config.get("max_battle_attempts_per_hour", 6)

	# 離線效率通常比在線低一些
	var offline_efficiency = 0.7

	return base_battles_per_hour * offline_efficiency

# 計算離線城池征服數量
func _calculate_offline_cities_conquered(successful_battles: int, current_player_data: Dictionary) -> int:
	var owned_cities = current_player_data.get("owned_cities", [])
	var current_city_count = owned_cities.size()

	# 隨著城池增加，征服新城池變難
	var conquest_difficulty_multiplier = 1.0 + (current_city_count * 0.2)
	var battles_per_city = int(10 * conquest_difficulty_multiplier)

	var potential_cities = int(successful_battles / battles_per_city)

	# 限制不能超過總城池數量
	var total_cities = 16  # 總共16座城池
	var max_conquerable = total_cities - current_city_count

	return min(potential_cities, max_conquerable)

# 模擬離線期間的進展事件
func _simulate_offline_progression(total_battles: int, successful_battles: int, cities_conquered: int) -> Array:
	var events = []

	# 重要里程碑事件
	if total_battles >= 100:
		events.append("⭐ 離線期間進行了 %d 場戰鬥！" % total_battles)

	if successful_battles >= 50:
		events.append("🏆 取得了 %d 場勝利！" % successful_battles)

	if cities_conquered > 0:
		events.append("🏰 成功征服了 %d 座城池！" % cities_conquered)

	# 隨機事件模擬
	var random_events = _simulate_offline_random_events(total_battles)
	events.append_array(random_events)

	return events

# 模擬離線期間的隨機事件
func _simulate_offline_random_events(battles_fought: int) -> Array:
	var events = []
	var event_probability = 0.3  # 30%概率每10場戰鬥觸發一個事件

	var potential_events = int(battles_fought / 10)

	for i in range(potential_events):
		if randf() < event_probability:
			var random_events = [
				"💰 發現了藏寶箱！",
				"⚔️ 俘獲了傳說武器！",
				"👥 招募了忠誠武將！",
				"📜 學會了新的戰術！",
				"🌟 觸發了天命事件！"
			]
			events.append(random_events[randi() % random_events.size()])

	return events

# 應用離線進度到玩家數據
func apply_offline_progress(progress: Dictionary, current_player_data: Dictionary) -> void:
	if not current_player_data:
		LogManager.error("AutoBattleManager", "無法應用離線進度：玩家數據無效")
		return

	var resources_gained = progress.get("resources_gained", {})
	var resources_lost = progress.get("resources_lost", {})
	var cities_conquered = progress.get("cities_conquered", 0)

	# 應用資源變化
	if resources_gained.has("gold"):
		current_player_data.resources.gold += resources_gained.gold
		EventBus.emit_safe("resources_changed", ["gold", resources_gained.gold])

	if resources_gained.has("troops"):
		var net_troops = resources_gained.troops - resources_lost.get("troops", 0)
		current_player_data.resources.troops += net_troops
		EventBus.emit_safe("resources_changed", ["troops", net_troops])

	if resources_gained.has("experience"):
		current_player_data.experience += resources_gained.experience
		EventBus.emit_safe("experience_gained", [resources_gained.experience, "offline_battles"])

	# 更新統計
	automation_statistics.total_battles += progress.get("battles_fought", 0)
	automation_statistics.total_victories += progress.get("successful_battles", 0)
	automation_statistics.total_defeats += progress.get("failed_battles", 0)
	automation_statistics.cities_conquered += cities_conquered

	# 征服城池
	if cities_conquered > 0:
		_apply_offline_city_conquests(cities_conquered, current_player_data)

	LogManager.info("AutoBattleManager", "離線進度已應用", {
		"battles": progress.get("battles_fought", 0),
		"cities": cities_conquered,
		"gold_gained": resources_gained.get("gold", 0),
		"experience_gained": resources_gained.get("experience", 0)
	})

	# 觸發離線進度完成事件
	offline_progress_calculated.emit(progress, progress.get("offline_hours", 0.0))

# 應用離線城池征服
func _apply_offline_city_conquests(cities_count: int, current_player_data: Dictionary) -> void:
	if not CityManager:
		LogManager.error("AutoBattleManager", "無法征服城池：CityManager未找到")
		return

	var conquerable_cities = CityManager.get_conquerable_cities(current_player_data)
	var cities_to_conquer = min(cities_count, conquerable_cities.size())

	for i in range(cities_to_conquer):
		if i < conquerable_cities.size():
			var city = conquerable_cities[i]
			var city_id = city.get("id", "")

			if not city_id.is_empty():
				# 執行城池征服
				var conquest_result = CityManager.execute_city_conquest(city_id)

				if conquest_result.get("success", false):
					current_player_data.owned_cities.append(city_id)
					EventBus.emit_safe("city_conquered", [city.get("name", ""), "player", {}])

					LogManager.game_event("OfflineConquest", "離線征服城池", {
						"city": city.get("name", ""),
						"offline": true
					})

# === 戰鬥結果處理 ===

# 處理戰鬥結果
func process_battle_result(battle_result: Dictionary, current_player_data: Dictionary) -> void:
	var result_entry = {
		"timestamp": Time.get_unix_time_from_system(),
		"result": battle_result.duplicate(),
		"auto_generated": true
	}

	battle_history.append(result_entry)

	# 限制歷史記錄數量
	if battle_history.size() > 100:
		battle_history = battle_history.slice(-100)

	# 更新統計
	if battle_result.get("victor") == "player":
		automation_statistics.total_victories += 1
		automation_statistics.total_spoils_gained += battle_result.get("spoils", {}).get("gold", 0)
	else:
		automation_statistics.total_defeats += 1
		automation_statistics.total_losses += battle_result.get("losses", {}).get("gold", 0)

	automation_statistics.total_battles += 1

	# 從活躍戰鬥列表中移除
	var city_id = battle_result.get("city_conquered", "")
	if city_id in active_battles:
		active_battles.erase(city_id)

	LogManager.debug("AutoBattleManager", "戰鬥結果已處理", {
		"victor": battle_result.get("victor"),
		"city": city_id
	})

# === 控制方法 ===

# 暫停自動化
func pause_automation(reason: String = "user_request") -> void:
	is_paused = true
	LogManager.info("AutoBattleManager", "自動化已暫停", {"reason": reason})
	automation_paused.emit(reason)

# 恢復自動化
func resume_automation() -> void:
	is_paused = false
	LogManager.info("AutoBattleManager", "自動化已恢復")
	automation_resumed.emit()

# 更新自動化配置
func update_automation_config(new_settings: Dictionary) -> void:
	for key in new_settings:
		if player_data.has("automation_settings"):
			player_data.automation_settings[key] = new_settings[key]

	# 更新本地標記
	is_auto_enabled = player_data.get("automation_settings", {}).get("auto_battle_enabled", false)

	LogManager.info("AutoBattleManager", "自動化配置已更新", new_settings)

# === 查詢方法 ===

# 檢查是否已初始化
func is_initialized() -> bool:
	return is_system_initialized

# 檢查自動戰鬥是否啟用
func is_auto_battle_enabled() -> bool:
	return is_auto_enabled and not is_paused

# 檢查是否暫停
func is_auto_paused() -> bool:
	return is_paused

# 獲取戰鬥歷史
func get_battle_history(limit: int = 20) -> Array[Dictionary]:
	var history_size = battle_history.size()
	var start_index = max(0, history_size - limit)
	return battle_history.slice(start_index)

# 獲取自動化統計
func get_automation_statistics() -> Dictionary:
	var stats = automation_statistics.duplicate()
	stats["win_rate"] = float(stats.get("total_victories", 0)) / max(stats.get("total_battles", 1), 1)
	stats["efficiency"] = float(stats.get("total_spoils_gained", 0)) / max(stats.get("total_losses", 1), 1)
	return stats

# 重置自動化統計
func reset_automation_statistics() -> void:
	automation_statistics = {
		"total_battles": 0,
		"total_victories": 0,
		"total_defeats": 0,
		"total_spoils_gained": 0,
		"total_losses": 0,
		"cities_conquered": 0,
		"automation_start_time": Time.get_unix_time_from_system()
	}

# === 放置遊戲核心自動戰鬥循環 ===

# 自動戰鬥計時器觸發
func _on_auto_battle_timer_timeout() -> void:
	if not should_auto_battle():
		return

	LogManager.debug("AutoBattleManager", "自動戰鬥觸發")

	# 執行自動戰鬥循環
	execute_idle_battle_cycle()

# 檢查是否應該進行自動戰鬥
func should_auto_battle() -> bool:
	# 基本檢查
	if not is_auto_enabled or is_paused or not is_system_initialized:
		return false

	# 檢查遊戲狀態
	if not GameStateManager:
		return false

	var current_state = GameStateManager.get_current_state()
	if current_state != GameStateManager.GameState.GAME_RUNNING:
		return false

	# 檢查是否有活躍戰鬥
	if active_battles.size() > 0:
		LogManager.debug("AutoBattleManager", "有活躍戰鬥，跳過自動戰鬥")
		return false

	return true

# 執行放置遊戲戰鬥循環
func execute_idle_battle_cycle() -> void:
	var current_player_data = GameCore.get_player_data()
	if not current_player_data:
		LogManager.error("AutoBattleManager", "無法獲取玩家數據")
		return

	# 選擇目標
	var target_city = select_optimal_target()
	if target_city.is_empty():
		LogManager.debug("AutoBattleManager", "沒有可用目標，暫停自動戰鬥")
		_handle_no_targets_available()
		return

	# 執行戰鬥
	execute_auto_battle(target_city)

	# 更新戰鬥頻率（難度遞增）
	update_battle_frequency()

	# 發送難度縮放事件
	var scaling_factor = _calculate_difficulty_scaling()
	EventBus.emit_safe("difficulty_scaling_applied", [scaling_factor, "battle_progression"])

# 處理沒有可用目標的情況
func _handle_no_targets_available() -> void:
	# 檢查是否已征服所有城池
	var current_player_data = GameCore.get_player_data()
	var owned_cities = current_player_data.get("owned_cities", [])

	if owned_cities.size() >= 16:  # 假設總共16座城池
		LogManager.info("AutoBattleManager", "所有城池已征服，遊戲勝利！")
		EventBus.emit_safe("game_victory")
		pause_automation("game_completed")
	else:
		# 可能需要等待解鎖新目標
		LogManager.debug("AutoBattleManager", "等待新目標解鎖")

# 更新戰鬥頻率（實現指數增長難度）
func update_battle_frequency() -> void:
	var config = automation_config.get("idle_progression", {})
	var scaling_factor = config.get("frequency_scaling_factor", 1.15)
	var max_frequency = config.get("max_battle_frequency", 30.0)

	# 根據戰鬥次數增加間隔時間
	var new_frequency = battle_frequency * scaling_factor
	new_frequency = min(new_frequency, max_frequency)

	if new_frequency != battle_frequency:
		battle_frequency = new_frequency
		auto_battle_timer.wait_time = battle_frequency

		LogManager.debug("AutoBattleManager", "戰鬥頻率已更新", {
			"new_frequency": battle_frequency,
			"battles_completed": battles_completed
		})

		# 發送戰鬥頻率更新事件
		EventBus.emit_safe("battle_frequency_updated", [battle_frequency, battles_completed])

# 開始自動戰鬥循環（技能選擇完成後調用）
func start_idle_game_loop() -> void:
	if not is_system_initialized:
		LogManager.error("AutoBattleManager", "系統未初始化，無法開始遊戲循環")
		return

	is_auto_enabled = true
	is_paused = false

	# 重置統計
	battles_completed = 0
	consecutive_victories = 0
	consecutive_defeats = 0

	# 重置戰鬥頻率
	var config = automation_config.get("idle_progression", {})
	battle_frequency = config.get("base_battle_frequency", 5.0)
	auto_battle_timer.wait_time = battle_frequency

	# 開始計時器
	auto_battle_timer.start()

	LogManager.info("AutoBattleManager", "放置遊戲循環已開始", {
		"initial_frequency": battle_frequency
	})

	# 發送放置遊戲循環開始事件
	EventBus.emit_safe("idle_game_loop_started")

	# 立即執行第一次戰鬥
	call_deferred("execute_idle_battle_cycle")

# 停止自動戰鬥循環
func stop_idle_game_loop() -> void:
	is_auto_enabled = false
	auto_battle_timer.stop()
	LogManager.info("AutoBattleManager", "放置遊戲循環已停止")

	# 發送放置遊戲循環停止事件
	EventBus.emit_safe("idle_game_loop_stopped")

# === 事件處理器 ===

func _on_battle_completed(result: Dictionary, victor: String, casualties: Dictionary) -> void:
	if is_auto_enabled:
		process_battle_result(result, player_data)

		# 更新連續勝負統計
		battles_completed += 1
		if victor == "player":
			consecutive_victories += 1
			consecutive_defeats = 0
			LogManager.game_event("AutoBattle", "自動戰鬥勝利", {
				"victories_streak": consecutive_victories,
				"total_battles": battles_completed
			})
		else:
			consecutive_defeats += 1
			consecutive_victories = 0
			LogManager.game_event("AutoBattle", "自動戰鬥失敗", {
				"defeats_streak": consecutive_defeats,
				"total_battles": battles_completed
			})

# 技能選擇完成事件處理器
func _on_skill_selection_completed() -> void:
	LogManager.info("AutoBattleManager", "技能選擇已完成，準備開始自動戰鬥循環")

	# 延遲啟動，給其他系統時間初始化
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.timeout.connect(start_idle_game_loop)
	add_child(timer)
	timer.start()

func _on_city_conquered(city_name: String, new_owner: String, spoils: Dictionary) -> void:
	if new_owner == "player" and is_auto_enabled:
		automation_statistics.cities_conquered += 1
		LogManager.game_event("AutoConquest", "自動征服成功", {
			"city": city_name,
			"spoils": spoils
		})

func _on_game_state_changed(new_state: int, old_state: int) -> void:
	# 根據遊戲狀態調整自動化行為
	match new_state:
		GameStateManager.GameState.GAME_RUNNING:
			if is_auto_enabled and not is_paused:
				LogManager.debug("AutoBattleManager", "遊戲運行中，自動化激活")
		GameStateManager.GameState.BATTLE:
			# 戰鬥進行中，暫時停止新的自動戰鬥
			pass

# === 核心戰鬥執行功能 ===

# 執行自動戰鬥
func execute_auto_battle(target_city: Dictionary) -> void:
	if not can_start_new_battle():
		LogManager.warn("AutoBattleManager", "無法開始新戰鬥", {
			"auto_enabled": is_auto_enabled,
			"paused": is_paused,
			"active_battles": active_battles.size()
		})
		return

	var current_player_data = GameCore.get_player_data()

	# 計算戰鬥計劃
	var battle_plan = create_battle_plan(target_city, current_player_data)
	if battle_plan.is_empty():
		LogManager.warn("AutoBattleManager", "無法創建戰鬥計劃", {
			"target": target_city.get("name", "未知")
		})
		return

	# 開始戰鬥
	initiate_battle(target_city, battle_plan)

# 發起戰鬥
func initiate_battle(target_city: Dictionary, battle_plan: Dictionary) -> void:
	var attacker_data = {
		"troops": battle_plan.get("troop_allocation", 0),
		"general_name": "主公",
		"power_rating": calculate_player_power_rating(GameCore.get_player_data()),
		"morale": 100
	}

	var defender_data = {
		"troops": target_city.get("garrison_strength", 1000),
		"general_name": target_city.get("garrison_general", "守將"),
		"power_rating": target_city.get("defense_rating", 50),
		"morale": target_city.get("morale", 80),
		"city_bonus": target_city.get("defense_bonus", 0.1)
	}

	# 記錄戰鬥開始
	var battle_id = "auto_battle_" + str(Time.get_unix_time_from_system())
	var battle_record = {
		"id": battle_id,
		"target_city": target_city.get("name", ""),
		"start_time": Time.get_unix_time_from_system(),
		"attacker": attacker_data,
		"defender": defender_data,
		"battle_plan": battle_plan,
		"status": "in_progress"
	}

	active_battles.append(battle_record)

	LogManager.info("AutoBattleManager", "自動戰鬥開始", {
		"battle_id": battle_id,
		"target": target_city.get("name", ""),
		"attacker_troops": attacker_data.troops,
		"defender_troops": defender_data.troops
	})

	# 發送戰鬥開始事件
	EventBus.emit_safe("battle_started", [attacker_data, defender_data, target_city.get("name", "")])
	auto_battle_started.emit(target_city, battle_plan)

	# 開始戰鬥計算
	_process_battle_resolution(battle_record)

# 處理戰鬥解決
func _process_battle_resolution(battle_record: Dictionary) -> void:
	var attacker = battle_record.attacker
	var defender = battle_record.defender
	var target_city = battle_record.target_city

	# 計算戰鬥結果
	var battle_result = _calculate_battle_outcome(attacker, defender, battle_record.battle_plan)

	# 應用戰鬥結果
	_apply_battle_result(battle_result, battle_record)

	# 移除戰鬥記錄
	var battle_index = active_battles.find(battle_record)
	if battle_index >= 0:
		active_battles.remove_at(battle_index)

	LogManager.info("AutoBattleManager", "自動戰鬥完成", {
		"target": target_city,
		"result": battle_result.get("victor", "unknown"),
		"duration": Time.get_unix_time_from_system() - battle_record.start_time
	})

# 計算戰鬥結果（加入難度縮放）
func _calculate_battle_outcome(attacker: Dictionary, defender: Dictionary, battle_plan: Dictionary) -> Dictionary:
	var attacker_power = _calculate_total_combat_power(attacker, true)
	var base_defender_power = _calculate_total_combat_power(defender, false)

	# 應用敵方戰力縮放
	var defender_power = _calculate_enemy_power_scaling(base_defender_power)

	# 添加隨機因素
	var random_factor = randf_range(0.8, 1.2)
	attacker_power *= random_factor

	# 計算勝負
	var victor = "defender"
	var victor_remaining_power = defender_power
	var casualties = {}

	if attacker_power > defender_power:
		victor = "player"
		victor_remaining_power = attacker_power - defender_power

		# 計算傷亡（勝利時傷亡較少）
		var attacker_losses = int(attacker.troops * randf_range(0.1, 0.3))
		var defender_losses = defender.troops  # 全軍覆沒

		casualties = {
			"attacker": attacker_losses,
			"defender": defender_losses
		}
	else:
		victor = "defender"
		victor_remaining_power = defender_power - attacker_power

		# 攻方失敗，較大傷亡
		var attacker_losses = int(attacker.troops * randf_range(0.4, 0.7))
		var defender_losses = int(defender.troops * randf_range(0.1, 0.2))

		casualties = {
			"attacker": attacker_losses,
			"defender": defender_losses
		}

	var result = {
		"victor": victor,
		"attacker_power": attacker_power,
		"defender_power": defender_power,
		"base_defender_power": base_defender_power,
		"difficulty_scaling": defender_power / base_defender_power,
		"remaining_power": victor_remaining_power,
		"casualties": casualties,
		"battle_duration": randf_range(2.0, 5.0),
		"city_name": battle_plan.get("target_city_name", "")
	}

	# 如果勝利，計算戰利品（應用縮放獎勵）
	if victor == "player":
		result["spoils"] = _calculate_victory_spoils(defender, battle_plan)
		result["city_conquered"] = true
	else:
		result["spoils"] = {}
		result["city_conquered"] = false

	LogManager.debug("AutoBattleManager", "戰鬥結果計算", {
		"victor": victor,
		"attacker_power": attacker_power,
		"base_defender_power": base_defender_power,
		"scaled_defender_power": defender_power,
		"difficulty_scaling": result.difficulty_scaling
	})

	return result

# 計算總戰鬥力
func _calculate_total_combat_power(unit_data: Dictionary, is_attacker: bool) -> float:
	var base_troops = unit_data.get("troops", 0)
	var power_rating = unit_data.get("power_rating", 50)
	var morale = unit_data.get("morale", 100)

	# 基礎戰力
	var base_power = base_troops * (power_rating / 100.0) * (morale / 100.0)

	# 防守方加成
	if not is_attacker:
		var city_bonus = unit_data.get("city_bonus", 0.1)
		base_power *= (1.0 + city_bonus)

	# 技能加成
	var skill_bonus = _calculate_skill_bonus(is_attacker)
	base_power *= (1.0 + skill_bonus)

	return base_power

# 計算技能加成
func _calculate_skill_bonus(is_attacker: bool) -> float:
	if not is_attacker:
		return 0.0  # 防守方無技能加成

	var player_data = GameCore.get_player_data()
	var selected_skills = player_data.get("selected_skills", [])
	var total_bonus = 0.0

	for skill in selected_skills:
		var skill_effects = skill.get("effects", {})

		# 戰鬥相關技能加成
		total_bonus += skill_effects.get("battle_power_bonus", 0.0)
		total_bonus += skill_effects.get("troop_efficiency", 0.0)
		total_bonus += skill_effects.get("combat_bonus", 0.0)

	return total_bonus

# 計算勝利戰利品
func _calculate_victory_spoils(defeated_defender: Dictionary, battle_plan: Dictionary) -> Dictionary:
	var base_gold = defeated_defender.get("troops", 1000) * randf_range(0.5, 1.0)
	var base_resources = defeated_defender.get("troops", 1000) * 0.1

	var spoils = {
		"gold": int(base_gold),
		"troops": int(base_resources),
		"equipment": [],
		"experience": int(base_gold * 0.1)
	}

	# 根據難度調整戰利品
	var difficulty = battle_plan.get("difficulty_rating", 1.0)
	spoils.gold = int(spoils.gold * difficulty)
	spoils.experience = int(spoils.experience * difficulty)

	# 可能獲得裝備
	if randf() < 0.3:  # 30%概率獲得裝備
		spoils.equipment.append({
			"type": "weapon",
			"tier": "common",
			"name": "戰利品武器"
		})

	return spoils

# 應用戰鬥結果
func _apply_battle_result(battle_result: Dictionary, battle_record: Dictionary) -> void:
	var victor = battle_result.get("victor", "defender")
	var casualties = battle_result.get("casualties", {})
	var spoils = battle_result.get("spoils", {})

	# 更新統計
	automation_statistics.total_battles += 1

	if victor == "player":
		automation_statistics.total_victories += 1
		automation_statistics.total_spoils_gained += spoils.get("gold", 0)

		# 應用戰利品
		_apply_battle_spoils(spoils)

		# 征服城池
		if battle_result.get("city_conquered", false):
			var city_name = battle_result.get("city_name", "")
			_conquer_city(city_name, spoils)

	else:
		automation_statistics.total_defeats += 1
		automation_statistics.total_losses += casualties.get("attacker", 0)

	# 應用傷亡
	_apply_casualties(casualties)

	# 記錄戰鬥歷史
	var history_entry = {
		"timestamp": Time.get_unix_time_from_system(),
		"target": battle_record.get("target_city", ""),
		"result": victor,
		"spoils": spoils,
		"casualties": casualties,
		"duration": battle_result.get("battle_duration", 0.0)
	}
	battle_history.append(history_entry)

	# 發送戰鬥完成事件
	EventBus.emit_safe("battle_completed", [battle_result, victor, casualties])
	auto_battle_completed.emit(battle_result, spoils)

# 應用戰利品
func _apply_battle_spoils(spoils: Dictionary) -> void:
	var player_data = GameCore.get_player_data()

	# 添加金錢
	if spoils.has("gold"):
		player_data.resources.gold += spoils.gold
		EventBus.emit_safe("resources_changed", ["gold", spoils.gold])

	# 添加兵力
	if spoils.has("troops"):
		player_data.resources.troops += spoils.troops
		EventBus.emit_safe("resources_changed", ["troops", spoils.troops])

	# 添加經驗
	if spoils.has("experience"):
		player_data.experience += spoils.experience

	LogManager.debug("AutoBattleManager", "戰利品已應用", spoils)

# 征服城池
func _conquer_city(city_name: String, spoils: Dictionary) -> void:
	if not CityManager:
		LogManager.error("AutoBattleManager", "無法征服城池：CityManager未找到")
		return

	# 通過城池名稱找到城池ID
	var city_id = ""
	for city in CityManager.cities_data:
		if city.get("name", "") == city_name:
			city_id = city.get("id", "")
			break

	if city_id.is_empty():
		LogManager.error("AutoBattleManager", "城池ID未找到", {"city_name": city_name})
		return

	var conquest_result = CityManager.execute_city_conquest(city_id)

	if conquest_result.get("success", false):
		var player_data = GameCore.get_player_data()

		# 更新玩家城池列表
		if not player_data.owned_cities.has(city_id):
			player_data.owned_cities.append(city_id)
			player_data.resources.cities = player_data.owned_cities.size()

		# 發送城池征服事件
		EventBus.emit_safe("city_conquered", [city_name, "player", spoils])
		EventBus.emit_safe("resources_changed", ["cities", 1])

		LogManager.info("AutoBattleManager", "城池征服成功", {
			"city": city_name,
			"city_id": city_id,
			"total_cities": player_data.resources.cities,
			"conquest_spoils": conquest_result.get("spoils", {})
		})

# 應用戰鬥傷亡
func _apply_casualties(casualties: Dictionary) -> void:
	var player_data = GameCore.get_player_data()
	var attacker_losses = casualties.get("attacker", 0)

	if attacker_losses > 0:
		player_data.resources.troops = max(0, player_data.resources.troops - attacker_losses)
		EventBus.emit_safe("resources_changed", ["troops", -attacker_losses])

		LogManager.debug("AutoBattleManager", "戰鬥傷亡已應用", {
			"losses": attacker_losses,
			"remaining_troops": player_data.resources.troops
		})