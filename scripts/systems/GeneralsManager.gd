# GeneralsManager.gd - 武将管理系统
#
# 功能：
# - 管理玩家的武将招募、分配和状态
# - 处理武将对城池的加成效果
# - 计算武将战力和属性影响
# - 武将升级和经验管理

extends Node

signal general_recruited(general_data: Dictionary)
signal general_assigned(general_id: String, city_id: String)
signal general_unassigned(general_id: String, city_id: String)
signal general_level_up(general_id: String, new_level: int)

# 武将数据
var all_generals_data: Array = []
var player_generals: Dictionary = {}  # general_id -> general_instance
var city_assignments: Dictionary = {}  # city_id -> general_id
var recruitment_pool: Array = []  # 可招募的武将ID列表

# 招募系统配置
var recruitment_config: Dictionary = {
	"base_cost": 1000,
	"rarity_multipliers": {
		"common": 1.0,
		"rare": 2.0,
		"epic": 4.0,
		"legendary": 8.0
	},
	"recruitment_chance": {
		"common": 0.7,
		"rare": 0.5,
		"epic": 0.3,
		"legendary": 0.1
	}
}

func _ready() -> void:
	name = "GeneralsManager"
	LogManager.info("GeneralsManager", "武将管理系统初始化开始")

	# 等待数据管理器初始化
	await _wait_for_data_manager()

	# 加载武将数据
	load_generals_data()

	# 初始化玩家武将
	initialize_player_generals()

	# 生成招募池
	generate_recruitment_pool()

	# 连接事件处理器
	connect_event_handlers()

	LogManager.info("GeneralsManager", "武将管理系统初始化完成", {
		"total_generals": all_generals_data.size(),
		"player_generals": player_generals.size(),
		"recruitment_pool": recruitment_pool.size()
	})

# 等待数据管理器初始化
func _wait_for_data_manager() -> void:
	var max_wait_time = 5.0
	var wait_start = Time.get_unix_time_from_system()

	while not DataManager or DataManager.is_loading():
		await get_tree().process_frame
		var elapsed = Time.get_unix_time_from_system() - wait_start
		if elapsed > max_wait_time:
			LogManager.warn("GeneralsManager", "等待数据管理器超时")
			break

# 加载武将数据
func load_generals_data() -> void:
	if DataManager and DataManager.generals_data:
		all_generals_data = DataManager.generals_data.get("generals", []).duplicate()
		LogManager.info("GeneralsManager", "从DataManager加载武将数据", {
			"generals_count": all_generals_data.size()
		})
	else:
		# 直接从文件加载作为备用
		var file = FileAccess.open("res://data/generals.json", FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()

			var json = JSON.new()
			var parse_result = json.parse(json_string)

			if parse_result == OK:
				var data = json.data
				all_generals_data = data.get("generals", [])
				LogManager.info("GeneralsManager", "直接从文件加载武将数据", {
					"generals_count": all_generals_data.size()
				})
			else:
				LogManager.error("GeneralsManager", "武将数据解析失败")
		else:
			LogManager.error("GeneralsManager", "无法读取武将数据文件")

# 初始化玩家武将
func initialize_player_generals() -> void:
	# 玩家开始时拥有刘备作为主将
	var liu_bei_data = get_general_data_by_id("liubei")
	if not liu_bei_data.is_empty():
		var liu_bei_instance = create_general_instance(liu_bei_data)
		liu_bei_instance["level"] = 1
		liu_bei_instance["experience"] = 0
		liu_bei_instance["is_main_character"] = true
		player_generals["liubei"] = liu_bei_instance

		# 分配刘备到成都
		assign_general_to_city("liubei", "chengdu")

		LogManager.info("GeneralsManager", "初始武将设置完成", {
			"main_general": "刘备",
			"assigned_city": "成都"
		})

# 创建武将实例
func create_general_instance(general_data: Dictionary) -> Dictionary:
	var instance = general_data.duplicate()
	instance["level"] = 1
	instance["experience"] = 0
	instance["loyalty"] = 100
	instance["fatigue"] = 0
	instance["assigned_city"] = ""
	instance["equipment"] = []
	instance["skills_learned"] = []
	instance["recruitment_date"] = Time.get_unix_time_from_system()
	instance["is_main_character"] = false

	return instance

# 生成招募池
func generate_recruitment_pool() -> void:
	recruitment_pool.clear()

	for general in all_generals_data:
		var general_id = general.get("id", "")

		# 跳过已拥有的武将
		if general_id in player_generals:
			continue

		# 跳过主角武将
		if general_id == "liubei":
			continue

		# 根据招募难度决定是否加入池子
		var difficulty = general.get("recruitment_difficulty", "normal")
		if _should_add_to_recruitment_pool(difficulty):
			recruitment_pool.append(general_id)

	LogManager.debug("GeneralsManager", "招募池生成完成", {
		"available_generals": recruitment_pool.size()
	})

# 检查是否应该加入招募池
func _should_add_to_recruitment_pool(difficulty: String) -> bool:
	var chances = {
		"very_easy": 1.0,
		"easy": 0.9,
		"normal": 0.7,
		"hard": 0.4,
		"very_hard": 0.2,
		"legendary": 0.1
	}

	var chance = chances.get(difficulty, 0.7)
	return randf() < chance

# 连接事件处理器
func connect_event_handlers() -> void:
	if EventBus:
		EventBus.connect_safe("city_conquered", _on_city_conquered)
		EventBus.connect_safe("battle_completed", _on_battle_completed)
		EventBus.connect_safe("turn_completed", _on_turn_completed)

	LogManager.debug("GeneralsManager", "事件处理器连接完成")

# === 招募系统 ===

# 获取可招募武将列表
func get_recruiteable_generals() -> Array:
	var recruiteable = []

	for general_id in recruitment_pool:
		var general_data = get_general_data_by_id(general_id)
		if not general_data.is_empty():
			var recruitment_cost = calculate_recruitment_cost(general_data)
			var recruitment_chance = calculate_recruitment_chance(general_data)

			recruiteable.append({
				"general_data": general_data,
				"cost": recruitment_cost,
				"success_chance": recruitment_chance
			})

	return recruiteable

# 自動招募機制 - 戰鬥勝利後自動觸發
func auto_recruit_after_battle(city_name: String, player_charisma: int) -> Dictionary:
	var recruitment_result = {
		"success": false,
		"general": null,
		"recruitment_rate": 0.0,
		"city": city_name,
		"attempted_general": "",
		"failure_reason": ""
	}

	# 計算基礎招募率
	var base_rate = 0.12  # 基礎12% (略微提升)
	var charisma_bonus = (player_charisma / 100.0) * 0.06  # 魅力加成：每100魅力增加6%
	var city_bonus = 0.0
	var tianming_bonus = 0.0

	# 獲取天命加成
	var player_tianming = _get_player_tianming()
	tianming_bonus = (player_tianming / 100.0) * 0.04  # 每100天命增加4%

	# 如果城池有守將，招募率提升
	var city_generals = get_city_generals(city_name)
	if city_generals.size() > 0:
		city_bonus = 0.18  # 有守將時增加18%

	# 計算最終招募率，上限40%
	var final_rate = min(base_rate + charisma_bonus + city_bonus + tianming_bonus, 0.40)
	recruitment_result.recruitment_rate = final_rate

	# 隨機判定是否招募成功
	if randf() < final_rate:
		# 從城池守將中隨機選擇一個招募
		if city_generals.size() > 0:
			var selected_general = city_generals[randi() % city_generals.size()]
			var general_data = get_general_data_by_id(selected_general)
			recruitment_result.attempted_general = general_data.get("name", selected_general)

			if general_data and not general_data.is_empty():
				# 計算忠誠度檢查（基於魅力和武將品質）
				var loyalty_check = _calculate_loyalty_check(general_data, player_charisma)

				if loyalty_check:
					# 自動招募成功
					var general_instance = create_general_instance(general_data)
					player_generals[selected_general] = general_instance

					# 從招募池中移除
					if selected_general in recruitment_pool:
						recruitment_pool.erase(selected_general)

					recruitment_result.success = true
					recruitment_result.general = general_instance

					LogManager.game_event("AutoRecruitment", "戰後自動招募成功", {
						"general": general_data.get("name", ""),
						"city": city_name,
						"recruitment_rate": "%.1f%%" % (final_rate * 100),
						"charisma": player_charisma,
						"tianming": player_tianming
					})

					# 發射事件
					general_recruited.emit(general_data)
					EventBus.general_recruited.emit(general_data, "player")

					# 自動分配武將到征服的城池
					assign_general_to_city(selected_general, _get_city_id_by_name(city_name))
				else:
					recruitment_result.failure_reason = "loyalty_check_failed"
					LogManager.debug("GeneralsManager", "招募失敗：忠誠度檢查未通過", {
						"general": general_data.get("name", ""),
						"city": city_name
					})
			else:
				recruitment_result.failure_reason = "general_data_missing"
		else:
			recruitment_result.failure_reason = "no_available_generals"
	else:
		recruitment_result.failure_reason = "probability_failed"

	return recruitment_result

# 獲取城池可招募的武將列表
func get_city_generals(city_name: String) -> Array:
	var city_generals = []

	# 從generals.json中查找屬於該城池的武將
	for general in all_generals_data:
		var general_id = general.get("id", "")
		if general_id.is_empty():
			continue
		var recruitment_cities = general.get("recruitment_cities", [])

		# 檢查武將是否可在此城池招募，且未被招募
		if city_name in recruitment_cities and not general_id in player_generals:
			city_generals.append(general_id)

	return city_generals

# 尝试招募武将 (保留舊方法以防其他地方調用)
func attempt_recruitment(general_id: String) -> Dictionary:
	if general_id in player_generals:
		return {"success": false, "error": "already_recruited"}

	if not general_id in recruitment_pool:
		return {"success": false, "error": "not_available"}

	var general_data = get_general_data_by_id(general_id)
	if general_data.is_empty():
		return {"success": false, "error": "general_not_found"}

	# 检查招募成本
	var cost = calculate_recruitment_cost(general_data)
	if not GameCore.has_resources(cost):
		return {"success": false, "error": "insufficient_resources", "required": cost}

	# 计算招募成功率
	var success_chance = calculate_recruitment_chance(general_data)
	var is_success = randf() < success_chance

	if is_success:
		# 招募成功
		GameCore.subtract_resources(cost)
		var general_instance = create_general_instance(general_data)
		player_generals[general_id] = general_instance
		recruitment_pool.erase(general_id)

		LogManager.game_event("Recruitment", "武将招募成功", {
			"general": general_data.get("name", ""),
			"cost": cost
		})

		general_recruited.emit(general_data)
		EventBus.general_recruited.emit(general_data, "player")

		return {"success": true, "general": general_instance}
	else:
		# 招募失败，消耗一半成本
		var failed_cost = {}
		for resource in cost:
			failed_cost[resource] = cost[resource] / 2

		GameCore.subtract_resources(failed_cost)

		LogManager.game_event("Recruitment", "武将招募失败", {
			"general": general_data.get("name", ""),
			"cost_lost": failed_cost
		})

		return {"success": false, "error": "recruitment_failed", "cost_lost": failed_cost}

# 计算招募成本
func calculate_recruitment_cost(general_data: Dictionary) -> Dictionary:
	var base_cost = recruitment_config.base_cost
	var rarity = general_data.get("rarity", "common")
	var multiplier = recruitment_config.rarity_multipliers.get(rarity, 1.0)

	var attributes_sum = 0
	var attributes = general_data.get("attributes", {})
	for attr_value in attributes.values():
		attributes_sum += attr_value

	var attribute_modifier = attributes_sum / 300.0  # 平均属性越高成本越高

	return {
		"gold": int(base_cost * multiplier * attribute_modifier),
		"troops": int(100 * multiplier)
	}

# 计算招募成功率
func calculate_recruitment_chance(general_data: Dictionary) -> float:
	var rarity = general_data.get("rarity", "common")
	var base_chance = recruitment_config.recruitment_chance.get(rarity, 0.5)

	# 玩家魅力值影响招募成功率
	var player_data = GameCore.get_player_data()
	var player_charisma = player_data.get("attributes", {}).get("魅力", 20)
	var charisma_modifier = 1.0 + (player_charisma - 20) * 0.01

	# 势力声望影响（城池数量）
	var owned_cities = player_data.get("owned_cities", [])
	var reputation_modifier = 1.0 + owned_cities.size() * 0.05

	var final_chance = base_chance * charisma_modifier * reputation_modifier
	return clamp(final_chance, 0.1, 0.9)

# === 武将分配系统 ===

# 分配武将到城池
func assign_general_to_city(general_id: String, city_id: String) -> bool:
	if not general_id in player_generals:
		LogManager.warn("GeneralsManager", "尝试分配不存在的武将", {
			"general_id": general_id
		})
		return false

	# 检查城池是否被玩家拥有
	var player_data = GameCore.get_player_data()
	var owned_cities = player_data.get("owned_cities", [])
	if not city_id in owned_cities:
		LogManager.warn("GeneralsManager", "尝试分配武将到不拥有的城池", {
			"city_id": city_id
		})
		return false

	# 移除武将的旧分配
	unassign_general(general_id)

	# 分配到新城池
	player_generals[general_id]["assigned_city"] = city_id
	city_assignments[city_id] = general_id

	LogManager.info("GeneralsManager", "武将分配完成", {
		"general": player_generals[general_id].get("name", ""),
		"city": city_id
	})

	general_assigned.emit(general_id, city_id)
	return true

# 取消武将分配
func unassign_general(general_id: String) -> void:
	if not general_id in player_generals:
		return

	var current_city = player_generals[general_id].get("assigned_city", "")
	if not current_city.is_empty():
		player_generals[general_id]["assigned_city"] = ""
		city_assignments.erase(current_city)
		general_unassigned.emit(general_id, current_city)

# 获取城池分配的武将
func get_city_general(city_id: String) -> Dictionary:
	var general_id = city_assignments.get(city_id, "")
	if general_id.is_empty():
		return {}

	return player_generals.get(general_id, {})

# 计算武将对城池的加成
func calculate_general_bonuses(general_id: String) -> Dictionary:
	if not general_id in player_generals:
		return {}

	var general = player_generals[general_id]
	var attributes = general.get("attributes", {})
	var level = general.get("level", 1)

	# 基于属性的加成
	var bonuses = {
		"defense_bonus": attributes.get("武力", 0) * 0.5 * level,
		"production_bonus": attributes.get("統治", 0) * 0.3 * level,
		"loyalty_bonus": attributes.get("魅力", 0) * 0.2 * level,
		"research_bonus": attributes.get("智力", 0) * 0.4 * level,
		"diplomacy_bonus": attributes.get("政治", 0) * 0.3 * level
	}

	# 特殊能力加成
	var special_abilities = general.get("special_abilities", [])
	for ability in special_abilities:
		match ability:
			"奸雄":
				bonuses["political_power"] = bonuses.get("political_power", 0) + 20
			"仁德":
				bonuses["loyalty_bonus"] += 15
			"神机妙算":
				bonuses["research_bonus"] += 25

	return bonuses

# === 查询方法 ===

# 根据ID获取武将数据
func get_general_data_by_id(general_id: String) -> Dictionary:
	for general in all_generals_data:
		if general.get("id") == general_id:
			return general
	return {}

# 获取玩家拥有的武将
func get_player_generals() -> Dictionary:
	return player_generals.duplicate()

# 獲取玩家武將數量
func get_player_general_count() -> int:
	return player_generals.size()

# 获取特定武将实例
func get_player_general(general_id: String) -> Dictionary:
	return player_generals.get(general_id, {}).duplicate()

# 获取未分配的武将
func get_unassigned_generals() -> Array:
	var unassigned = []
	for general_id in player_generals:
		var general = player_generals[general_id]
		if general.get("assigned_city", "").is_empty():
			unassigned.append(general)
	return unassigned

# 获取城池分配状况
func get_city_assignments() -> Dictionary:
	return city_assignments.duplicate()

# 计算武将总战力
func calculate_general_power(general_id: String) -> float:
	if not general_id in player_generals:
		return 0.0

	var general = player_generals[general_id]
	var attributes = general.get("attributes", {})
	var level = general.get("level", 1)

	var power = (
		attributes.get("武力", 0) * 3.0 +
		attributes.get("智力", 0) * 2.5 +
		attributes.get("統治", 0) * 2.0 +
		attributes.get("政治", 0) * 1.5 +
		attributes.get("魅力", 0) * 1.5 +
		attributes.get("天命", 0) * 2.0
	) * level

	return power

# === 事件处理器 ===

func _on_city_conquered(city_name: String, new_owner: String, spoils: Dictionary) -> void:
	if new_owner == "player":
		# 城池征服后有机会招募该城池的武将
		_try_recruit_city_general(city_name)

func _try_recruit_city_general(city_name: String) -> void:
	# 查找该城池的起始武将
	for general in all_generals_data:
		var starting_city = general.get("starting_city", "")
		if starting_city == city_name:
			var general_id = general.get("id", "")
			if not general_id in player_generals and randf() < 0.3:  # 30%机会
				recruitment_pool.append(general_id)
				LogManager.game_event("Recruitment", "发现可招募武将", {
					"general": general.get("name", ""),
					"city": city_name
				})

func _on_battle_completed(result: Dictionary, victor: String, casualties: Dictionary) -> void:
	if victor == "player":
		# 戰鬥勝利後武將獲得經驗
		_award_battle_experience()

		# 自動招募機制：戰鬥勝利後自動嘗試招募城池守將
		var battle_city = result.get("city", "")
		if not battle_city.is_empty():
			# 獲取玩家魅力值 (從GameCore或其他地方)
			var player_charisma = _get_player_charisma()
			var recruitment_result = auto_recruit_after_battle(battle_city, player_charisma)

			if recruitment_result.success:
				# 自動招募成功，顯示慶祝動畫
				_show_recruitment_celebration(recruitment_result.general)
			else:
				# 招募失敗，記錄日誌
				LogManager.debug("GeneralsManager", "自動招募失敗", {
					"city": battle_city,
					"recruitment_rate": "%.1f%%" % (recruitment_result.recruitment_rate * 100)
				})

# 獲取玩家魅力值
func _get_player_charisma() -> int:
	# 從GameCore獲取玩家屬性
	if GameCore and GameCore.has_method("get_player_attribute"):
		return GameCore.get_player_attribute("魅力")
	else:
		# 備用方案：從存檔數據中獲取
		return 50  # 默認值

# 獲取玩家天命值
func _get_player_tianming() -> int:
	if DataManager and DataManager.player_data.has("attributes"):
		return DataManager.player_data.attributes.get("天命", 10)
	elif GameCore and GameCore.has_method("get_player_attribute"):
		return GameCore.get_player_attribute("天命")
	return 10  # 默認值

# 計算忠誠度檢查（武將是否願意加入）
func _calculate_loyalty_check(general_data: Dictionary, player_charisma: int) -> bool:
	var base_loyalty_chance = 0.75  # 基礎75%願意加入

	# 武將品質影響（高品質武將更難招募）
	var rarity = general_data.get("rarity", "common")
	var rarity_modifier = {
		"common": 1.0,
		"rare": 0.85,
		"epic": 0.7,
		"legendary": 0.5
	}.get(rarity, 1.0)

	# 玩家魅力影響
	var charisma_modifier = 1.0 + (player_charisma - 50) * 0.004  # 每點魅力增加0.4%

	# 武將屬性影響（高政治和魅力的武將更容易招募）
	var general_attributes = general_data.get("attributes", {})
	var general_politics = general_attributes.get("政治", 50)
	var general_charisma = general_attributes.get("魅力", 50)
	var attribute_modifier = 1.0 + ((general_politics + general_charisma - 100) * 0.002)

	# 計算最終概率
	var final_chance = base_loyalty_chance * rarity_modifier * charisma_modifier * attribute_modifier
	final_chance = clamp(final_chance, 0.2, 0.95)  # 確保在20%-95%範圍內

	return randf() < final_chance

# 根據城池名稱獲取城池ID
func _get_city_id_by_name(city_name: String) -> String:
	if CityManager and CityManager.cities_data:
		for city_id in CityManager.cities_data:
			var city_data = CityManager.cities_data[city_id]
			if city_data.get("name", "") == city_name:
				return city_id
	return city_name.to_lower()  # 備用方案

# 顯示招募慶祝動畫
func _show_recruitment_celebration(general_data: Dictionary) -> void:
	var general_name = general_data.get("name", "未知武將")

	# 觸發UI動畫事件
	EventBus.ui_notification_requested.emit(
		"🎉 招募成功！%s 加入了你的陣營！" % general_name,
		"special",
		3.0  # 顯示3秒
	)

	# 可以在這裡添加更多視覺效果
	EventBus.ui_animation_requested.emit(
		null,  # target node (UI會處理)
		"recruitment_celebration",
		{"general_name": general_name}
	)

func _award_battle_experience() -> void:
	var base_exp = 50
	for general_id in player_generals:
		var general = player_generals[general_id]
		var assigned_city = general.get("assigned_city", "")

		# 分配到城池的武将获得更多经验
		var exp_gained = base_exp if assigned_city.is_empty() else base_exp * 1.5

		var old_exp = general.get("experience", 0)
		var new_exp = old_exp + exp_gained
		general["experience"] = new_exp

		# 检查是否升级
		_check_general_level_up(general_id)

func _check_general_level_up(general_id: String) -> void:
	var general = player_generals[general_id]
	var current_level = general.get("level", 1)
	var experience = general.get("experience", 0)

	var exp_required = current_level * 100  # 每级需要level*100经验
	if experience >= exp_required:
		general["level"] = current_level + 1
		general["experience"] = experience - exp_required

		LogManager.game_event("GeneralLevelUp", "武将升级", {
			"general": general.get("name", ""),
			"new_level": current_level + 1
		})

		general_level_up.emit(general_id, current_level + 1)

# 回合完成處理器 - 每回合檢查招募機會
func _on_turn_completed(turn_data: Dictionary) -> void:
	var current_turn = turn_data.get("turn", 1)

	# 每3回合進行一次被動招募檢查
	if current_turn % 3 == 0:
		_perform_periodic_recruitment_check()

	# 每5回合重新生成招募池
	if current_turn % 5 == 0:
		_refresh_recruitment_pool()

# 定期招募檢查 - 基於聲望和城池數量的被動招募
func _perform_periodic_recruitment_check() -> void:
	var player_data = GameCore.get_player_data() if GameCore else {}
	var owned_cities = player_data.get("owned_cities", [])

	# 城池數量影響招募機會
	if owned_cities.size() < 3:
		return  # 城池太少，沒有足夠聲望吸引武將

	var recruitment_chance = min(0.15 + (owned_cities.size() * 0.03), 0.35)  # 15%-35%

	if randf() < recruitment_chance:
		_try_passive_recruitment()

# 嘗試被動招募（武將主動投靠）
func _try_passive_recruitment() -> void:
	if recruitment_pool.is_empty():
		return

	# 選擇一個武將嘗試招募
	var candidate_id = recruitment_pool[randi() % recruitment_pool.size()]
	var general_data = get_general_data_by_id(candidate_id)

	if general_data.is_empty():
		return

	var player_charisma = _get_player_charisma()
	var player_tianming = _get_player_tianming()

	# 被動招募成功率較低，但不需要戰鬥
	var success_rate = 0.08 + (player_charisma * 0.002) + (player_tianming * 0.001)
	success_rate = clamp(success_rate, 0.05, 0.25)

	if randf() < success_rate:
		# 被動招募成功
		var general_instance = create_general_instance(general_data)
		player_generals[candidate_id] = general_instance
		recruitment_pool.erase(candidate_id)

		LogManager.game_event("PassiveRecruitment", "武將慕名而來", {
			"general": general_data.get("name", ""),
			"success_rate": "%.1f%%" % (success_rate * 100),
			"reason": "聲望吸引"
		})

		# 發射事件
		general_recruited.emit(general_data)
		EventBus.general_recruited.emit(general_data, "player")

		# 顯示特殊動畫
		EventBus.ui_notification_requested.emit(
			"🌟 %s 慕名投靠！" % general_data.get("name", ""),
			"special",
			4.0
		)

# 刷新招募池
func _refresh_recruitment_pool() -> void:
	var old_size = recruitment_pool.size()
	generate_recruitment_pool()
	var new_size = recruitment_pool.size()

	LogManager.debug("GeneralsManager", "招募池已刷新", {
		"old_size": old_size,
		"new_size": new_size,
		"added": max(0, new_size - old_size)
	})

# 獲取招募統計信息
func get_recruitment_statistics() -> Dictionary:
	var recruited_count = 0
	var recruitment_dates = []

	for general_id in player_generals:
		var general = player_generals[general_id]
		var recruitment_date = general.get("recruitment_date", 0)
		if recruitment_date > 0:
			recruited_count += 1
			recruitment_dates.append(recruitment_date)

	return {
		"total_generals": player_generals.size(),
		"recruited_generals": recruited_count,
		"available_for_recruitment": recruitment_pool.size(),
		"total_generals_in_database": all_generals_data.size(),
		"recruitment_completion_rate": (recruited_count / float(all_generals_data.size())) * 100.0
	}

# 自動最佳化武將分配
func optimize_general_assignments() -> Dictionary:
	var optimization_result = {
		"reassignments": 0,
		"improvements": []
	}

	var owned_cities = []
	if GameCore:
		var player_data = GameCore.get_player_data()
		owned_cities = player_data.get("owned_cities", [])

	# 為每個未分配城池尋找最佳武將
	for city_id in owned_cities:
		if not city_assignments.has(city_id):
			var best_general = _find_best_general_for_city(city_id)
			if not best_general.is_empty():
				var general_id = best_general.get("id", "")
				if assign_general_to_city(general_id, city_id):
					optimization_result.reassignments += 1
					optimization_result.improvements.append({
						"city": city_id,
						"general": best_general.get("name", ""),
						"reason": "optimal_assignment"
					})

	return optimization_result

# 為城池尋找最佳武將
func _find_best_general_for_city(city_id: String) -> Dictionary:
	var best_general = {}
	var best_score = 0.0

	# 尋找未分配的武將
	for general_id in player_generals:
		var general = player_generals[general_id]
		if general.get("assigned_city", "").is_empty():
			var score = _calculate_general_city_compatibility(general, city_id)
			if score > best_score:
				best_score = score
				best_general = general

	return best_general

# 計算武將與城池的適配度
func _calculate_general_city_compatibility(general: Dictionary, city_id: String) -> float:
	var compatibility_score = 0.0
	var attributes = general.get("attributes", {})

	# 基礎屬性評分
	compatibility_score += attributes.get("統治", 0) * 0.3  # 統治力最重要
	compatibility_score += attributes.get("政治", 0) * 0.25
	compatibility_score += attributes.get("武力", 0) * 0.2
	compatibility_score += attributes.get("智力", 0) * 0.15
	compatibility_score += attributes.get("魅力", 0) * 0.1

	# 武將等級加成
	var level = general.get("level", 1)
	compatibility_score *= (1.0 + (level - 1) * 0.1)

	return compatibility_score