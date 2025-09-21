# CityManager.gd - 城池管理系統
#
# 功能：
# - 管理所有城池數據和狀態
# - 處理城池征服邏輯
# - 計算城池收益和加成
# - 處理地區控制效果

extends Node

signal city_conquered(city_id: String, victor: String, spoils: Dictionary)
signal city_upgraded(city_id: String, new_level: int, bonuses: Dictionary)
signal regional_control_changed(region: String, controller: String, bonus_applied: Dictionary)

# 城池數據
var cities_data: Array = []
var player_cities: Array[String] = []
var city_states: Dictionary = {} # 城池當前狀態
var regional_control: Dictionary = {} # 地區控制狀況

# 征服系統配置
var conquest_config: Dictionary = {}
var regional_bonuses: Dictionary = {}

func _ready() -> void:
	name = "CityManager"
	LogManager.info("CityManager", "城池管理系統初始化")

	# 等待數據管理器初始化完成
	if DataManager:
		while DataManager.is_loading():
			await get_tree().process_frame

		load_cities_data()
	else:
		LogManager.error("CityManager", "DataManager未找到")

	# 連接事件處理器
	connect_event_handlers()

	# 初始化城池狀態
	initialize_city_states()

func connect_event_handlers() -> void:
	EventBus.connect_safe("battle_completed", _on_battle_completed)
	EventBus.connect_safe("city_siege_started", _on_city_siege_started)
	LogManager.debug("CityManager", "事件處理器連接完成")

# 載入城池數據
func load_cities_data() -> void:
	var file_content = FileAccess.open("res://data/cities.json", FileAccess.READ)
	if file_content:
		var json_string = file_content.get_as_text()
		file_content.close()

		var json = JSON.new()
		var parse_result = json.parse(json_string)

		if parse_result == OK:
			var data = json.data
			cities_data = data.get("cities", [])
			conquest_config = data.get("conquest_system", {})
			regional_bonuses = data.get("regional_bonuses", {})

			LogManager.info("CityManager", "城池數據載入完成", {
				"cities_count": cities_data.size(),
				"regions_count": regional_bonuses.size()
			})
		else:
			LogManager.error("CityManager", "城池數據解析失敗", {"error": json.error_string})
	else:
		LogManager.error("CityManager", "無法讀取城池數據文件")

# 初始化城池狀態
func initialize_city_states() -> void:
	for city_data in cities_data:
		var city_id = city_data.get("id", "")
		var base_stats = city_data.get("base_stats", {})
		city_states[city_id] = {
			"owner": city_data.get("kingdom", "neutral"),
			"level": 1,
			"loyalty": base_stats.get("loyalty", 50),
			"prosperity": base_stats.get("prosperity", 50),
			"defense": base_stats.get("defense", 50),
			"garrison": city_data.get("garrison_strength", 1000),
			"under_siege": false,
			"siege_duration": 0,
			"last_battle": 0,
			"development_points": 0,
			"special_status": []
		}

	# 初始化玩家城池（成都）
	player_cities = ["chengdu"]
	if city_states.has("chengdu"):
		city_states["chengdu"]["owner"] = "player"
	else:
		LogManager.warn("CityManager", "成都城池數據未找到，跳過初始化", {
			"available_cities": city_states.keys(),
			"expected_city": "chengdu"
		})

	# 計算初始地區控制
	update_regional_control()

	LogManager.info("CityManager", "城池狀態初始化完成", {
		"total_cities": city_states.size(),
		"player_cities": player_cities.size()
	})

# === 城池查詢方法 ===

# 獲取城池信息
func get_city_data(city_id: String) -> Dictionary:
	for city in cities_data:
		if city.get("id") == city_id:
			return city.duplicate()
	return {}

# 獲取城池狀態
func get_city_state(city_id: String) -> Dictionary:
	return city_states.get(city_id, {}).duplicate()

# 獲取玩家擁有的城池列表
func get_player_cities() -> Array[String]:
	return player_cities.duplicate()

# 獲取特定地區的城池
func get_cities_by_region(region: String) -> Array[Dictionary]:
	var region_cities: Array[Dictionary] = []
	for city in cities_data:
		if city.get("region") == region:
			region_cities.append(city)
	return region_cities

# 獲取可征服的城池（滿足解鎖條件）
func get_conquerable_cities(player_data: Dictionary) -> Array[Dictionary]:
	var conquerable: Array[Dictionary] = []

	# 更新玩家城池列表（從GameCore的數據）
	var player_owned_cities = player_data.get("owned_cities", ["chengdu"])

	for city in cities_data:
		var city_id = city.get("id", "")

		# 跳過已擁有的城池
		if city_id in player_owned_cities:
			continue

		# 檢查解鎖條件
		if check_unlock_conditions(city, player_data):
			conquerable.append(city)

	LogManager.debug("CityManager", "可征服城池檢查", {
		"player_cities": player_owned_cities.size(),
		"conquerable_cities": conquerable.size(),
		"total_cities": cities_data.size()
	})

	return conquerable

# 檢查城池解鎖條件
func check_unlock_conditions(city_data: Dictionary, player_data: Dictionary) -> bool:
	var conditions = city_data.get("unlock_conditions", {})

	# 檢查預設解鎖
	if conditions.get("default", false):
		return true

	# 檢查等級要求
	if conditions.has("level"):
		var required_level = conditions.level
		if player_data.get("level", 1) < required_level:
			return false

	# 檢查征服城池數量要求
	if conditions.has("cities_conquered"):
		var required_cities = conditions.cities_conquered
		if player_cities.size() < required_cities:
			return false

	# 檢查特定城池要求
	if conditions.has("required_cities"):
		var required_cities = conditions.required_cities
		for required_city in required_cities:
			if not required_city in player_cities:
				return false

	return true

# === 城池征服系統 ===

# 開始圍攻城池
func start_city_siege(city_id: String, attacking_force: Dictionary) -> Dictionary:
	var city_data = get_city_data(city_id)
	if city_data.is_empty():
		LogManager.error("CityManager", "城池不存在", {"city_id": city_id})
		return {"success": false, "error": "city_not_found"}

	var city_state = get_city_state(city_id)
	if city_state.get("owner") == "player":
		LogManager.warning("CityManager", "嘗試攻擊自己的城池", {"city_id": city_id})
		return {"success": false, "error": "own_city"}

	if city_state.get("under_siege", false):
		LogManager.warning("CityManager", "城池已被圍攻", {"city_id": city_id})
		return {"success": false, "error": "already_under_siege"}

	# 檢查攻擊條件
	var siege_cost = calculate_siege_cost(city_data, attacking_force)
	if not validate_siege_requirements(attacking_force, siege_cost):
		return {"success": false, "error": "insufficient_resources"}

	# 開始圍攻
	city_states[city_id]["under_siege"] = true
	city_states[city_id]["siege_duration"] = 0
	city_states[city_id]["besieging_force"] = attacking_force.duplicate()

	LogManager.game_event("Siege", "開始圍攻", {
		"city": city_data.name,
		"attacker_troops": attacking_force.get("troops", 0),
		"defender_garrison": city_state.garrison
	})

	EventBus.city_siege_started.emit(city_id, attacking_force)

	return {
		"success": true,
		"siege_duration": calculate_siege_duration(city_data, attacking_force),
		"daily_cost": siege_cost.daily_cost,
		"success_chance": calculate_siege_success_chance(city_data, attacking_force)
	}

# 計算圍攻成本
func calculate_siege_cost(city_data: Dictionary, attacking_force: Dictionary) -> Dictionary:
	var base_cost = conquest_config.get("base_requirements", {})
	var city_tier = city_data.get("tier", "small")
	var tier_multiplier = conquest_config.get("victory_rewards", {}).get("tier_multipliers", {}).get(city_tier, 1.0)

	var daily_supply_cost = base_cost.get("siege_duration_days", 7) * tier_multiplier
	var total_troop_cost = attacking_force.get("troops", 0) * 0.1 # 每日損耗

	return {
		"daily_cost": int(daily_supply_cost),
		"troop_attrition": total_troop_cost,
		"total_gold_cost": int(daily_supply_cost * 7)
	}

# 驗證圍攻要求
func validate_siege_requirements(attacking_force: Dictionary, siege_cost: Dictionary) -> bool:
	var min_troops = conquest_config.get("base_requirements", {}).get("min_troops", 500)
	var min_gold = conquest_config.get("base_requirements", {}).get("min_gold", 1000)

	if attacking_force.get("troops", 0) < min_troops:
		LogManager.warning("CityManager", "兵力不足", {
			"current": attacking_force.get("troops", 0),
			"required": min_troops
		})
		return false

	if attacking_force.get("gold", 0) < siege_cost.total_gold_cost:
		LogManager.warning("CityManager", "金錢不足", {
			"current": attacking_force.get("gold", 0),
			"required": siege_cost.total_gold_cost
		})
		return false

	return true

# 計算圍攻持續時間
func calculate_siege_duration(city_data: Dictionary, attacking_force: Dictionary) -> int:
	var base_duration = conquest_config.get("base_requirements", {}).get("siege_duration_days", 7)
	var city_defense = city_data.get("base_stats", {}).get("defense", 50)
	var attacker_power = attacking_force.get("siege_power", attacking_force.get("troops", 1000))

	var defense_modifier = city_defense / 100.0
	var power_ratio = float(attacker_power) / (city_data.get("garrison_strength", 1000) + city_defense)

	var duration = base_duration * defense_modifier / power_ratio
	return max(int(duration), 3) # 最少3天

# 計算圍攻成功率
func calculate_siege_success_chance(city_data: Dictionary, attacking_force: Dictionary) -> float:
	var attacker_power = attacking_force.get("troops", 0) + attacking_force.get("siege_equipment", 0)
	var defender_power = city_data.get("garrison_strength", 1000) + city_data.get("base_stats", {}).get("defense", 50)

	var power_ratio = float(attacker_power) / defender_power
	var base_chance = 0.3 + (power_ratio - 1.0) * 0.4

	# 城池等級影響
	var city_tier_modifier = {
		"small": 1.2,
		"medium": 1.0,
		"major": 0.8,
		"capital": 0.6
	}
	var tier = city_data.get("tier", "medium")
	base_chance *= city_tier_modifier.get(tier, 1.0)

	return clamp(base_chance, 0.1, 0.9)

# 執行城池征服
func execute_city_conquest(city_id: String) -> Dictionary:
	var city_data = get_city_data(city_id)
	if city_data.is_empty():
		LogManager.error("CityManager", "城池不存在", {"city_id": city_id})
		return {"success": false, "error": "city_not_found"}

	var city_state = get_city_state(city_id)
	if city_state.get("owner") == "player":
		LogManager.warning("CityManager", "城池已被玩家擁有", {"city_id": city_id})
		return {"success": false, "error": "already_owned"}

	# 對於自動戰鬥，直接處理征服（跳過圍攻階段）
	return _handle_conquest_success(city_id, city_data, {})

# 處理征服成功
func _handle_conquest_success(city_id: String, city_data: Dictionary, attacking_force: Dictionary) -> Dictionary:
	# 更新城池狀態
	city_states[city_id]["owner"] = "player"
	city_states[city_id]["under_siege"] = false
	city_states[city_id]["loyalty"] = 30 # 新征服城池忠誠度較低
	player_cities.append(city_id)

	# 計算戰利品
	var spoils = calculate_conquest_spoils(city_data)

	# 更新地區控制
	update_regional_control()

	LogManager.game_event("Conquest", "城池征服成功", {
		"city": city_data.name,
		"spoils": spoils,
		"total_cities": player_cities.size()
	})

	# 發送事件
	city_conquered.emit(city_id, "player", spoils)
	EventBus.city_conquered.emit(city_data.name, "player", spoils)

	return {
		"success": true,
		"spoils": spoils,
		"new_bonuses": get_city_bonuses(city_id)
	}

# 處理征服失敗
func _handle_conquest_failure(city_id: String, city_data: Dictionary, attacking_force: Dictionary) -> Dictionary:
	# 重置圍攻狀態
	city_states[city_id]["under_siege"] = false
	city_states[city_id].erase("besieging_force")

	# 計算損失
	var losses = {
		"troops": int(attacking_force.get("troops", 0) * 0.3),
		"gold": int(attacking_force.get("gold", 0) * 0.2),
		"morale": 10
	}

	LogManager.game_event("Siege", "圍攻失敗", {
		"city": city_data.name,
		"losses": losses
	})

	return {
		"success": false,
		"losses": losses
	}

# 計算征服戰利品
func calculate_conquest_spoils(city_data: Dictionary) -> Dictionary:
	var base_rewards = conquest_config.get("victory_rewards", {}).get("base_rewards", {})
	var tier_multiplier = conquest_config.get("victory_rewards", {}).get("tier_multipliers", {}).get(city_data.get("tier", "medium"), 1.0)

	var spoils = {
		"gold": int(base_rewards.get("gold", 2000) * tier_multiplier),
		"experience": int(base_rewards.get("experience", 500) * tier_multiplier),
		"reputation": int(base_rewards.get("reputation", 100) * tier_multiplier),
		"equipment": []
	}

	# 裝備獲得機率
	var equipment_chance = base_rewards.get("equipment_chance", 0.3) * tier_multiplier
	if randf() < equipment_chance:
		# TODO: 從裝備池中隨機選擇
		spoils.equipment = ["random_equipment_" + city_data.get("id", "")]

	return spoils

# === 城池管理和升級 ===

# 獲取城池總收益
func get_total_city_income() -> Dictionary:
	var total_income = {
		"gold": 0,
		"troops": 0,
		"food": 0
	}

	for city_id in player_cities:
		var city_income = get_city_income(city_id)
		total_income.gold += city_income.get("gold", 0)
		total_income.troops += city_income.get("troops", 0)
		total_income.food += city_income.get("food", 0)

	# 應用地區加成
	total_income = apply_regional_bonuses(total_income)

	return total_income

# 獲取單個城池收益
func get_city_income(city_id: String) -> Dictionary:
	var city_data = get_city_data(city_id)
	var city_state = get_city_state(city_id)

	if city_data.is_empty() or city_state.get("owner") != "player":
		return {"gold": 0, "troops": 0, "food": 0}

	var base_resources = city_data.get("resources", {})
	var level_multiplier = 1.0 + (city_state.get("level", 1) - 1) * 0.2
	var loyalty_multiplier = city_state.get("loyalty", 50) / 100.0

	return {
		"gold": int(base_resources.get("gold_per_turn", 0) * level_multiplier * loyalty_multiplier),
		"troops": int(base_resources.get("troops_per_turn", 0) * level_multiplier * loyalty_multiplier),
		"food": int(base_resources.get("food_per_turn", 0) * level_multiplier * loyalty_multiplier)
	}

# 獲取城池加成效果
func get_city_bonuses(city_id: String) -> Dictionary:
	var city_data = get_city_data(city_id)
	var bonuses = {}

	var special_features = city_data.get("special_features", [])
	for feature in special_features:
		match feature:
			"imperial_palace":
				bonuses["political_power"] = 20
			"silk_trade":
				bonuses["trade_income"] = 15
			"mountain_fortress":
				bonuses["defense"] = 25
			"naval_base":
				bonuses["naval_power"] = 30
			"weapon_forge":
				bonuses["military_production"] = 20
			_:
				bonuses[feature] = 10

	return bonuses

# === 地區控制系統 ===

# 更新地區控制狀況
func update_regional_control() -> void:
	var new_control = {}

	# 統計每個地區的城池控制情況
	for city in cities_data:
		var region = city.get("region", "unknown")
		var city_id = city.get("id", "")
		var owner = city_states.get(city_id, {}).get("owner", "neutral")

		if not new_control.has(region):
			new_control[region] = {"player": 0, "total": 0, "controller": "neutral"}

		new_control[region]["total"] += 1
		if owner == "player":
			new_control[region]["player"] += 1

	# 確定地區控制者
	for region in new_control:
		var region_data = new_control[region]
		var control_ratio = float(region_data.player) / region_data.total

		var old_controller = regional_control.get(region, {}).get("controller", "neutral")
		var new_controller = "neutral"

		if control_ratio >= 0.7:
			new_controller = "player"
		elif control_ratio >= 0.4:
			new_controller = "contested"

		region_data["controller"] = new_controller
		region_data["control_ratio"] = control_ratio

		# 檢查控制權變化
		if old_controller != new_controller:
			_handle_regional_control_change(region, new_controller, old_controller)

	regional_control = new_control

# 處理地區控制權變化
func _handle_regional_control_change(region: String, new_controller: String, old_controller: String) -> void:
	var bonus_applied = {}

	if new_controller == "player":
		bonus_applied = apply_regional_control_bonus(region)
		LogManager.game_event("RegionalControl", "地區控制獲得", {
			"region": region,
			"bonuses": bonus_applied
		})
	elif old_controller == "player":
		bonus_applied = remove_regional_control_bonus(region)
		LogManager.game_event("RegionalControl", "地區控制失去", {
			"region": region,
			"lost_bonuses": bonus_applied
		})

	regional_control_changed.emit(region, new_controller, bonus_applied)

# 應用地區控制加成
func apply_regional_control_bonus(region: String) -> Dictionary:
	return regional_bonuses.get(region, {})

# 移除地區控制加成
func remove_regional_control_bonus(region: String) -> Dictionary:
	return regional_bonuses.get(region, {})

# 應用地區加成到收益
func apply_regional_bonuses(base_income: Dictionary) -> Dictionary:
	var modified_income = base_income.duplicate()

	for region in regional_control:
		var region_data = regional_control[region]
		if region_data.get("controller") == "player":
			var bonuses = regional_bonuses.get(region, {})

			# 應用收益加成
			if bonuses.has("food_production"):
				modified_income.food = int(modified_income.food * bonuses.food_production)
			if bonuses.has("trade_income"):
				modified_income.gold = int(modified_income.gold * bonuses.trade_income)

	return modified_income

# === 公共API ===

# 獲取地區控制狀況
func get_regional_control() -> Dictionary:
	return regional_control.duplicate()

# 獲取城池統計
func get_city_statistics() -> Dictionary:
	return {
		"total_cities": cities_data.size(),
		"player_cities": player_cities.size(),
		"control_percentage": float(player_cities.size()) / cities_data.size(),
		"regions_controlled": get_controlled_regions().size()
	}

# 獲取控制的地區
func get_controlled_regions() -> Array[String]:
	var controlled: Array[String] = []
	for region in regional_control:
		if regional_control[region].get("controller") == "player":
			controlled.append(region)
	return controlled

# 獲取玩家城池數量
func get_player_city_count() -> int:
	return player_cities.size()

# 獲取玩家武將數量（來自GeneralsManager的代理方法）
func get_player_general_count() -> int:
	if GeneralsManager:
		return GeneralsManager.get_player_general_count()
	return 1

# === 事件處理器 ===

func _on_battle_completed(result: Dictionary, victor: String, casualties: Dictionary) -> void:
	# 戰鬥完成後可能觸發城池征服
	pass

func _on_city_siege_started(city_id: String, attacking_force: Dictionary) -> void:
	LogManager.debug("CityManager", "收到圍攻開始事件", {
		"city": city_id,
		"troops": attacking_force.get("troops", 0)
	})