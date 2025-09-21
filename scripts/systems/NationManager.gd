# NationManager.gd - 國家管理系統
#
# 功能：
# - 提供帝國級別的資源統計和管理
# - 城池總覽和發展狀況追蹤
# - 國家政策和發展策略設置
# - 與CityManager和GameCore的深度整合
# - 為NationTab提供數據支援

extends Node

signal nation_stats_updated(stats: Dictionary)
signal development_policy_changed(policy_type: String, new_value: float)
signal city_development_completed(city_id: String, development_type: String)
signal resource_threshold_reached(resource_type: String, threshold_type: String)

# 國家統計數據
var nation_stats: Dictionary = {
	"total_cities": 0,
	"controlled_regions": [],
	"total_population": 0,
	"military_strength": 0,
	"economic_power": 0,
	"technology_level": 0,
	"resource_production": {},
	"resource_consumption": {},
	"net_income": {}
}

# 發展政策設置 (0.0-1.0，影響資源分配)
var development_policies: Dictionary = {
	"military_focus": 0.3,      # 軍事重點 (影響兵力生產)
	"economic_focus": 0.4,      # 經濟重點 (影響金錢收入)
	"technology_focus": 0.2,    # 科技重點 (影響技術發展)
	"population_focus": 0.1     # 民生重點 (影響人口增長)
}

# 城池發展狀況追蹤
var cities_development: Dictionary = {}  # city_id -> development_data

# 資源閾值設置
var resource_thresholds: Dictionary = {
	"gold": {"low": 1000, "high": 10000},
	"troops": {"low": 500, "high": 5000},
	"population": {"low": 1000, "high": 50000}
}

func _ready() -> void:
	LogManager.info("NationManager", "國家管理系統初始化開始")

	# 等待其他系統初始化完成
	await wait_for_dependencies()

	# 連接事件處理器
	connect_event_handlers()

	# 初始化國家數據
	initialize_nation_data()

	# 設置定期更新
	setup_periodic_updates()

	LogManager.info("NationManager", "國家管理系統初始化完成", {
		"controlled_cities": nation_stats.total_cities,
		"controlled_regions": nation_stats.controlled_regions.size(),
		"initial_policies": development_policies
	})

# 等待依賴系統
func wait_for_dependencies() -> void:
	var max_wait_time = 10.0
	var wait_start = Time.get_unix_time_from_system()

	while not (CityManager and GameCore and DataManager):
		await get_tree().process_frame
		var elapsed = Time.get_unix_time_from_system() - wait_start
		if elapsed > max_wait_time:
			LogManager.warn("NationManager", "等待依賴系統超時")
			break

# 連接事件處理器
func connect_event_handlers() -> void:
	# 監聽城池相關事件
	if CityManager:
		if CityManager.has_signal("city_captured"):
			CityManager.city_captured.connect(_on_city_captured)
		if CityManager.has_signal("city_lost"):
			CityManager.city_lost.connect(_on_city_lost)
		if CityManager.has_signal("resource_production_changed"):
			CityManager.resource_production_changed.connect(_on_resource_production_changed)

	# 監聽遊戲核心事件
	if GameCore:
		if GameCore.has_signal("resource_updated"):
			GameCore.resource_updated.connect(_on_resource_updated)
		if GameCore.has_signal("turn_advanced"):
			GameCore.turn_advanced.connect(_on_turn_advanced)

	LogManager.debug("NationManager", "事件處理器連接完成")

# 初始化國家數據
func initialize_nation_data() -> void:
	if not CityManager:
		LogManager.warn("NationManager", "CityManager未找到，無法初始化國家數據")
		return

	# 獲取當前控制的城池
	update_controlled_cities()

	# 計算初始統計
	calculate_nation_statistics()

	# 初始化城池發展追蹤
	initialize_cities_development()

	LogManager.info("NationManager", "國家數據初始化完成", {
		"cities_count": nation_stats.total_cities,
		"regions_count": nation_stats.controlled_regions.size()
	})

# === 核心統計計算功能 ===

# 更新控制城池列表
func update_controlled_cities() -> void:
	if not CityManager:
		return

	var controlled_cities = CityManager.get_player_cities()
	nation_stats.total_cities = controlled_cities.size()

	# 計算控制區域
	var controlled_regions = []
	for city_id in controlled_cities:
		var city_data = CityManager.get_city_data(city_id)
		if city_data and city_data.has("region"):
			var region = city_data.region
			if region not in controlled_regions:
				controlled_regions.append(region)

	nation_stats.controlled_regions = controlled_regions

	LogManager.debug("NationManager", "控制區域更新", {
		"cities": controlled_cities.size(),
		"regions": controlled_regions
	})

# 計算國家統計數據
func calculate_nation_statistics() -> void:
	if not CityManager:
		return

	# 重置統計
	nation_stats.total_population = 0
	nation_stats.military_strength = 0
	nation_stats.economic_power = 0
	nation_stats.resource_production = {"gold": 0, "troops": 0, "food": 0}
	nation_stats.resource_consumption = {"gold": 0, "troops": 0, "food": 0}

	var controlled_cities = CityManager.get_player_cities()

	for city_id in controlled_cities:
		var city_data = CityManager.get_city_data(city_id)
		if not city_data:
			continue

		# 累加人口
		nation_stats.total_population += city_data.get("population", 0)

		# 累加軍事力量
		nation_stats.military_strength += city_data.get("garrison", 0)

		# 累加經濟實力 (基於城池等級和發展度)
		var city_level = city_data.get("level", 1)
		var development = city_data.get("development", 1.0)
		nation_stats.economic_power += city_level * development * 100

		# 計算資源產出 (基於城池屬性和政策)
		calculate_city_production(city_id, city_data)

	# 計算淨收入
	for resource in nation_stats.resource_production:
		var production = nation_stats.resource_production[resource]
		var consumption = nation_stats.resource_consumption.get(resource, 0)
		nation_stats.net_income[resource] = production - consumption

	# 廣播統計更新
	nation_stats_updated.emit(nation_stats)

	LogManager.debug("NationManager", "國家統計計算完成", {
		"population": nation_stats.total_population,
		"military": nation_stats.military_strength,
		"economic": nation_stats.economic_power
	})

# 計算城池產出
func calculate_city_production(city_id: String, city_data: Dictionary) -> void:
	var base_production = city_data.get("base_production", {"gold": 100, "troops": 10, "food": 50})
	var city_level = city_data.get("level", 1)
	var development = city_data.get("development", 1.0)

	# 根據發展政策調整產出
	for resource in base_production:
		var base_amount = base_production[resource]
		var policy_modifier = get_policy_modifier_for_resource(resource)
		var final_production = base_amount * city_level * development * policy_modifier

		nation_stats.resource_production[resource] += final_production

# 根據政策獲取資源修正
func get_policy_modifier_for_resource(resource: String) -> float:
	match resource:
		"gold":
			return 1.0 + (development_policies.economic_focus * 0.5)
		"troops":
			return 1.0 + (development_policies.military_focus * 0.5)
		"food":
			return 1.0 + (development_policies.population_focus * 0.3)
		_:
			return 1.0

# === 發展政策管理 ===

# 設置發展政策
func set_development_policy(policy_type: String, value: float) -> bool:
	if not development_policies.has(policy_type):
		LogManager.warn("NationManager", "未知的政策類型", {"policy": policy_type})
		return false

	# 限制數值範圍
	value = clamp(value, 0.0, 1.0)

	var old_value = development_policies[policy_type]
	development_policies[policy_type] = value

	# 重新計算統計
	calculate_nation_statistics()

	# 廣播政策變更
	development_policy_changed.emit(policy_type, value)

	LogManager.info("NationManager", "發展政策更新", {
		"policy": policy_type,
		"old_value": old_value,
		"new_value": value
	})

	return true

# 獲取發展政策
func get_development_policy(policy_type: String) -> float:
	return development_policies.get(policy_type, 0.0)

# 獲取所有政策
func get_all_policies() -> Dictionary:
	return development_policies.duplicate()

# === 城池發展管理 ===

# 初始化城池發展追蹤
func initialize_cities_development() -> void:
	if not CityManager:
		return

	var controlled_cities = CityManager.get_player_cities()

	for city_id in controlled_cities:
		cities_development[city_id] = {
			"infrastructure_level": 1,
			"economy_level": 1,
			"military_level": 1,
			"development_projects": [],
			"last_updated": Time.get_unix_time_from_system()
		}

# 開始城池發展項目
func start_city_development(city_id: String, development_type: String, cost: Dictionary) -> bool:
	if not cities_development.has(city_id):
		LogManager.warn("NationManager", "城池不在控制範圍內", {"city": city_id})
		return false

	# 檢查資源是否足夠
	if not GameCore.has_resources(cost):
		LogManager.warn("NationManager", "資源不足，無法開始發展項目", {
			"city": city_id,
			"type": development_type,
			"cost": cost
		})
		return false

	# 扣除資源
	GameCore.subtract_resources(cost)

	# 添加發展項目
	var project = {
		"type": development_type,
		"start_time": Time.get_unix_time_from_system(),
		"duration": get_development_duration(development_type),
		"cost": cost
	}

	cities_development[city_id].development_projects.append(project)

	LogManager.info("NationManager", "城池發展項目開始", {
		"city": city_id,
		"type": development_type,
		"duration": project.duration
	})

	return true

# 獲取發展項目持續時間
func get_development_duration(development_type: String) -> float:
	match development_type:
		"infrastructure":
			return 300.0  # 5分鐘
		"economy":
			return 240.0  # 4分鐘
		"military":
			return 180.0  # 3分鐘
		_:
			return 120.0  # 2分鐘默認

# === 事件處理器 ===

# 城池被攻占
func _on_city_captured(city_id: String, attacker: String) -> void:
	if attacker == "player":
		update_controlled_cities()
		calculate_nation_statistics()

		# 初始化新城池的發展數據
		cities_development[city_id] = {
			"infrastructure_level": 1,
			"economy_level": 1,
			"military_level": 1,
			"development_projects": [],
			"last_updated": Time.get_unix_time_from_system()
		}

		LogManager.info("NationManager", "新城池納入帝國管理", {"city": city_id})

# 城池丟失
func _on_city_lost(city_id: String, new_owner: String) -> void:
	update_controlled_cities()
	calculate_nation_statistics()

	# 移除發展數據
	if cities_development.has(city_id):
		cities_development.erase(city_id)

	LogManager.info("NationManager", "城池脫離帝國控制", {"city": city_id})

# 資源產出變化
func _on_resource_production_changed(city_id: String, resource_type: String, new_amount: float) -> void:
	# 重新計算國家統計
	calculate_nation_statistics()

# 資源更新
func _on_resource_updated(resource_type: String, amount: float) -> void:
	# 檢查資源閾值
	check_resource_thresholds(resource_type, amount)

# 回合推進
func _on_turn_advanced(turn_number: int) -> void:
	# 處理城池發展項目
	process_development_projects()

	# 重新計算統計
	calculate_nation_statistics()

# === 定期更新和閾值檢查 ===

# 設置定期更新
func setup_periodic_updates() -> void:
	# 每30秒更新一次統計
	var timer = Timer.new()
	timer.wait_time = 30.0
	timer.autostart = true
	timer.timeout.connect(calculate_nation_statistics)
	add_child(timer)

# 處理發展項目
func process_development_projects() -> void:
	var current_time = Time.get_unix_time_from_system()

	for city_id in cities_development:
		var city_dev = cities_development[city_id]
		var completed_projects = []

		for i in range(city_dev.development_projects.size()):
			var project = city_dev.development_projects[i]
			var elapsed = current_time - project.start_time

			if elapsed >= project.duration:
				# 項目完成
				complete_development_project(city_id, project)
				completed_projects.append(i)

		# 移除已完成的項目
		for i in range(completed_projects.size() - 1, -1, -1):
			city_dev.development_projects.remove_at(completed_projects[i])

# 完成發展項目
func complete_development_project(city_id: String, project: Dictionary) -> void:
	var city_dev = cities_development[city_id]

	# 提升對應等級
	match project.type:
		"infrastructure":
			city_dev.infrastructure_level += 1
		"economy":
			city_dev.economy_level += 1
		"military":
			city_dev.military_level += 1

	# 廣播完成事件
	city_development_completed.emit(city_id, project.type)

	LogManager.info("NationManager", "城池發展項目完成", {
		"city": city_id,
		"type": project.type,
		"new_level": city_dev.get(project.type + "_level", 1)
	})

# 檢查資源閾值
func check_resource_thresholds(resource_type: String, amount: float) -> void:
	if not resource_thresholds.has(resource_type):
		return

	var thresholds = resource_thresholds[resource_type]

	if amount <= thresholds.low:
		resource_threshold_reached.emit(resource_type, "low")
	elif amount >= thresholds.high:
		resource_threshold_reached.emit(resource_type, "high")

# === 公共API ===

# 獲取國家統計
func get_nation_stats() -> Dictionary:
	return nation_stats.duplicate()

# 獲取城池發展狀況
func get_city_development(city_id: String) -> Dictionary:
	return cities_development.get(city_id, {})

# 獲取所有城池發展狀況
func get_all_cities_development() -> Dictionary:
	return cities_development.duplicate()

# 計算國家綜合實力
func calculate_nation_power() -> float:
	var military_weight = 0.4
	var economic_weight = 0.4
	var population_weight = 0.2

	var normalized_military = nation_stats.military_strength / 10000.0
	var normalized_economic = nation_stats.economic_power / 100000.0
	var normalized_population = nation_stats.total_population / 100000.0

	return (normalized_military * military_weight +
			normalized_economic * economic_weight +
			normalized_population * population_weight) * 100.0