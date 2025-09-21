# DataManager.gd - 遊戲數據管理系統
#
# 功能：
# - 載入和驗證所有遊戲數據 (技能、將領、城池、裝備、隨機事件)
# - 數據完整性檢查和錯誤處理
# - 數據快取和版本管理
# - 數據查詢和篩選功能

extends Node

# 數據文件路徑
const DATA_PATHS = {
	"skills": "res://data/skills.json",
	"generals": "res://data/generals.json",
	"events": "res://data/events.json",
	"equipment": "res://data/equipment.json",
	"balance": "res://data/balance.json",
	"cities": "res://data/cities.json" # 將來創建
}

# 數據容器
var skills_data: Dictionary = {}
var generals_data: Dictionary = {}
var events_data: Dictionary = {}
var equipment_data: Dictionary = {}
var balance_data: Dictionary = {}
var cities_data: Dictionary = {}

# 數據索引（用於快速查詢）
var _skills_by_star: Dictionary = {}      # 按星級分組的技能
var _skills_by_category: Dictionary = {}  # 按類別分組的技能
var _generals_by_faction: Dictionary = {} # 按勢力分組的將領
var _equipment_by_tier: Dictionary = {}   # 按品級分組的裝備
var _events_by_category: Dictionary = {}  # 按類別分組的事件

# 加載狀態
var _is_loading: bool = false
var _load_progress: float = 0.0
var _load_errors: Array[String] = []

func _ready() -> void:
	name = "DataManager"
	LogManager.info("DataManager", "數據管理器初始化開始")

	# 開始加載所有數據
	load_all_data()

# 加載所有遊戲數據
func load_all_data() -> void:
	if _is_loading:
		LogManager.warn("DataManager", "數據正在加載中，忽略重複請求")
		return

	_is_loading = true
	_load_progress = 0.0
	_load_errors.clear()

	LogManager.info("DataManager", "開始載入遊戲數據", {"files_count": DATA_PATHS.size()})

	var total_files = DATA_PATHS.size()
	var loaded_files = 0

	# 載入技能數據
	if load_skills_data():
		loaded_files += 1
	_load_progress = float(loaded_files) / total_files

	# 載入將領數據
	if load_generals_data():
		loaded_files += 1
	_load_progress = float(loaded_files) / total_files

	# 載入事件數據
	if load_events_data():
		loaded_files += 1
	_load_progress = float(loaded_files) / total_files

	# 載入裝備數據
	if load_equipment_data():
		loaded_files += 1
	_load_progress = float(loaded_files) / total_files

	# 載入平衡數據
	if load_balance_data():
		loaded_files += 1
	_load_progress = float(loaded_files) / total_files

	# 載入城池數據 (暫時使用預設值)
	if load_cities_data():
		loaded_files += 1
	_load_progress = 1.0

	# 建立數據索引
	build_data_indices()

	# 驗證數據完整性
	validate_all_data()

	_is_loading = false

	if _load_errors.is_empty():
		LogManager.info("DataManager", "所有數據載入完成", {
			"loaded_files": loaded_files,
			"total_files": total_files,
			"skills_count": skills_data.get("skills", []).size(),
			"generals_count": generals_data.get("generals", []).size(),
			"events_count": events_data.get("events", []).size(),
			"equipment_count": equipment_data.get("equipment", []).size()
		})
	else:
		LogManager.error("DataManager", "數據載入完成，但有錯誤", {
			"errors": _load_errors,
			"loaded_files": loaded_files
		})

# 載入JSON文件的通用方法
func load_json_file(file_path: String) -> Dictionary:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		var error_msg = "無法打開文件: %s" % file_path
		_load_errors.append(error_msg)
		LogManager.error("DataManager", error_msg)
		return {}

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		var error_msg = "JSON解析失敗: %s (行 %d)" % [file_path, json.get_error_line()]
		_load_errors.append(error_msg)
		LogManager.error("DataManager", error_msg, {"error_line": json.get_error_line()})
		return {}

	LogManager.debug("DataManager", "JSON文件載入成功", {"file": file_path})
	return json.get_data()

# 載入技能數據
func load_skills_data() -> bool:
	skills_data = load_json_file(DATA_PATHS.skills)
	if skills_data.is_empty():
		return false

	# 驗證技能數據結構
	if not skills_data.has("skills") or not skills_data.skills is Array:
		_load_errors.append("技能數據格式錯誤")
		return false

	LogManager.info("DataManager", "技能數據載入完成", {"count": skills_data.skills.size()})
	return true

# 載入將領數據
func load_generals_data() -> bool:
	generals_data = load_json_file(DATA_PATHS.generals)
	if generals_data.is_empty():
		return false

	if not generals_data.has("generals") or not generals_data.generals is Array:
		_load_errors.append("將領數據格式錯誤")
		return false

	LogManager.info("DataManager", "將領數據載入完成", {"count": generals_data.generals.size()})
	return true

# 載入事件數據
func load_events_data() -> bool:
	events_data = load_json_file(DATA_PATHS.events)
	if events_data.is_empty():
		return false

	if not events_data.has("events") or not events_data.events is Array:
		_load_errors.append("事件數據格式錯誤")
		return false

	LogManager.info("DataManager", "事件數據載入完成", {"count": events_data.events.size()})
	return true

# 載入裝備數據
func load_equipment_data() -> bool:
	equipment_data = load_json_file(DATA_PATHS.equipment)
	if equipment_data.is_empty():
		return false

	if not equipment_data.has("equipment") or not equipment_data.equipment is Array:
		_load_errors.append("裝備數據格式錯誤")
		return false

	LogManager.info("DataManager", "裝備數據載入完成", {"count": equipment_data.equipment.size()})
	return true

# 載入平衡數據
func load_balance_data() -> bool:
	balance_data = load_json_file(DATA_PATHS.balance)
	if balance_data.is_empty():
		return false

	if not balance_data.has("game_balance"):
		_load_errors.append("平衡數據格式錯誤")
		return false

	LogManager.info("DataManager", "平衡數據載入完成")
	return true

# 載入城池數據 (暫時使用預設值)
func load_cities_data() -> bool:
	# TODO: 創建 cities.json 文件
	# 暫時使用PRD中提到的16座城池
	cities_data = {
		"cities": [
			{"id": "luoyang", "name": "洛陽", "faction": "京都", "type": "capital"},
			{"id": "yecheng", "name": "鄴城", "faction": "魏", "type": "major"},
			{"id": "xuchang", "name": "許昌", "faction": "魏", "type": "major"},
			{"id": "jinyang", "name": "晉陽", "faction": "魏", "type": "major"},
			{"id": "jicheng", "name": "薊城", "faction": "魏", "type": "major"},
			{"id": "changan", "name": "長安", "faction": "魏", "type": "major"},
			{"id": "chengdu", "name": "成都", "faction": "蜀", "type": "capital"},
			{"id": "hanzhong", "name": "漢中", "faction": "蜀", "type": "major"},
			{"id": "jieting", "name": "街亭", "faction": "蜀", "type": "major"},
			{"id": "yongan", "name": "永安", "faction": "蜀", "type": "major"},
			{"id": "jianning", "name": "建寧", "faction": "蜀", "type": "major"},
			{"id": "jianye", "name": "建業", "faction": "吳", "type": "capital"},
			{"id": "hefei", "name": "合肥", "faction": "吳", "type": "major"},
			{"id": "chaisang", "name": "柴桑", "faction": "吳", "type": "major"},
			{"id": "kuaiji", "name": "會稽", "faction": "吳", "type": "major"},
			{"id": "changsha", "name": "長沙", "faction": "吳", "type": "major"}
		]
	}

	LogManager.info("DataManager", "城池數據載入完成", {"count": cities_data.cities.size()})
	return true

# 建立數據索引，提升查詢效率
func build_data_indices() -> void:
	LogManager.debug("DataManager", "開始建立數據索引")

	# 建立技能索引
	_skills_by_star.clear()
	_skills_by_category.clear()
	for skill in skills_data.get("skills", []):
		var star_cost = skill.get("star_cost", 1)
		var category = skill.get("category", "unknown")

		if not _skills_by_star.has(star_cost):
			_skills_by_star[star_cost] = []
		_skills_by_star[star_cost].append(skill)

		if not _skills_by_category.has(category):
			_skills_by_category[category] = []
		_skills_by_category[category].append(skill)

	# 建立將領索引
	_generals_by_faction.clear()
	for general in generals_data.get("generals", []):
		var faction = general.get("faction", "無")
		if not _generals_by_faction.has(faction):
			_generals_by_faction[faction] = []
		_generals_by_faction[faction].append(general)

	# 建立裝備索引
	_equipment_by_tier.clear()
	for equipment in equipment_data.get("equipment", []):
		var tier = equipment.get("tier", "common")
		if not _equipment_by_tier.has(tier):
			_equipment_by_tier[tier] = []
		_equipment_by_tier[tier].append(equipment)

	# 建立事件索引
	_events_by_category.clear()
	for event in events_data.get("events", []):
		var category = event.get("category", "neutral")
		if not _events_by_category.has(category):
			_events_by_category[category] = []
		_events_by_category[category].append(event)

	LogManager.info("DataManager", "數據索引建立完成", {
		"skills_categories": _skills_by_category.keys().size(),
		"generals_factions": _generals_by_faction.keys().size(),
		"equipment_tiers": _equipment_by_tier.keys().size(),
		"event_categories": _events_by_category.keys().size()
	})

# 驗證所有數據的完整性
func validate_all_data() -> void:
	LogManager.debug("DataManager", "開始驗證數據完整性")

	var validation_errors: Array[String] = []

	# 驗證技能數據
	validation_errors.append_array(validate_skills_data())

	# 驗證將領數據
	validation_errors.append_array(validate_generals_data())

	# 驗證裝備數據
	validation_errors.append_array(validate_equipment_data())

	# 驗證事件數據
	validation_errors.append_array(validate_events_data())

	if validation_errors.is_empty():
		LogManager.info("DataManager", "數據驗證通過")
	else:
		LogManager.warn("DataManager", "數據驗證發現問題", {"errors": validation_errors})
		_load_errors.append_array(validation_errors)

# 驗證技能數據
func validate_skills_data() -> Array[String]:
	var errors: Array[String] = []
	var skill_ids: Array[String] = []

	for skill in skills_data.get("skills", []):
		var skill_id = skill.get("id", "")
		if skill_id.is_empty():
			errors.append("技能缺少ID")
			continue

		if skill_id in skill_ids:
			errors.append("重複的技能ID: %s" % skill_id)
		skill_ids.append(skill_id)

		# 驗證必需欄位
		if not skill.has("name") or skill.name.is_empty():
			errors.append("技能 %s 缺少名稱" % skill_id)

		if not skill.has("star_cost") or skill.star_cost < 1 or skill.star_cost > 3:
			errors.append("技能 %s 星級成本無效" % skill_id)

	return errors

# 驗證將領數據
func validate_generals_data() -> Array[String]:
	var errors: Array[String] = []
	var general_ids: Array[String] = []

	for general in generals_data.get("generals", []):
		var general_id = general.get("id", "")
		if general_id.is_empty():
			errors.append("將領缺少ID")
			continue

		if general_id in general_ids:
			errors.append("重複的將領ID: %s" % general_id)
		general_ids.append(general_id)

		# 驗證屬性值
		var attributes = general.get("attributes", {})
		var attribute_names = ["武力", "智力", "統治", "政治", "魅力", "天命"]
		for attr_name in attribute_names:
			var attr_value = attributes.get(attr_name, 0)
			if attr_value < 0 or attr_value > 100:
				errors.append("將領 %s 的 %s 屬性值無效: %d" % [general_id, attr_name, attr_value])

	return errors

# 驗證裝備數據
func validate_equipment_data() -> Array[String]:
	var errors: Array[String] = []
	var equipment_ids: Array[String] = []

	for equipment in equipment_data.get("equipment", []):
		var equipment_id = equipment.get("id", "")
		if equipment_id.is_empty():
			errors.append("裝備缺少ID")
			continue

		if equipment_id in equipment_ids:
			errors.append("重複的裝備ID: %s" % equipment_id)
		equipment_ids.append(equipment_id)

		# 驗證品級
		var tier = equipment.get("tier", "")
		if tier not in ["common", "rare", "epic", "legendary"]:
			errors.append("裝備 %s 品級無效: %s" % [equipment_id, tier])

	return errors

# 驗證事件數據
func validate_events_data() -> Array[String]:
	var errors: Array[String] = []
	var event_ids: Array[String] = []

	for event in events_data.get("events", []):
		var event_id = event.get("id", "")
		if event_id.is_empty():
			errors.append("事件缺少ID")
			continue

		if event_id in event_ids:
			errors.append("重複的事件ID: %s" % event_id)
		event_ids.append(event_id)

		# 驗證機率值
		var base_probability = event.get("base_probability", 0)
		if base_probability < 0 or base_probability > 100:
			errors.append("事件 %s 基礎機率無效: %f" % [event_id, base_probability])

	return errors

# === 公共查詢API ===

# 根據ID獲取技能
func get_skill_by_id(skill_id: String) -> Dictionary:
	for skill in skills_data.get("skills", []):
		if skill.get("id", "") == skill_id:
			return skill
	return {}

# 根據星級獲取技能
func get_skills_by_star_cost(star_cost: int) -> Array:
	return _skills_by_star.get(star_cost, [])

# 根據類別獲取技能
func get_skills_by_category(category: String) -> Array:
	return _skills_by_category.get(category, [])

# 隨機獲取技能（用於技能選擇）
func get_random_skills(count: int, star_cost: int = -1) -> Array:
	var available_skills: Array
	if star_cost > 0:
		available_skills = get_skills_by_star_cost(star_cost)
	else:
		available_skills = skills_data.get("skills", [])

	if available_skills.is_empty():
		return []

	var selected_skills: Array = []
	var skill_pool = available_skills.duplicate()

	for i in range(min(count, skill_pool.size())):
		var random_index = randi() % skill_pool.size()
		selected_skills.append(skill_pool[random_index])
		skill_pool.remove_at(random_index)

	return selected_skills

# 根據ID獲取將領
func get_general_by_id(general_id: String) -> Dictionary:
	for general in generals_data.get("generals", []):
		if general.get("id", "") == general_id:
			return general
	return {}

# 根據勢力獲取將領
func get_generals_by_faction(faction: String) -> Array:
	return _generals_by_faction.get(faction, [])

# 根據ID獲取裝備
func get_equipment_by_id(equipment_id: String) -> Dictionary:
	for equipment in equipment_data.get("equipment", []):
		if equipment.get("id", "") == equipment_id:
			return equipment
	return {}

# 根據品級獲取裝備
func get_equipment_by_tier(tier: String) -> Array:
	return _equipment_by_tier.get(tier, [])

# 根據城池數量獲取可購買的裝備
func get_purchasable_equipment(city_count: int) -> Array:
	var purchasable: Array = []
	for equipment in equipment_data.get("equipment", []):
		if equipment.get("acquisition", "") == "purchasable":
			var unlock_req = equipment.get("unlock_requirement", {})
			var min_cities = unlock_req.get("min_cities", 1)
			if city_count >= min_cities:
				purchasable.append(equipment)
	return purchasable

# 根據ID獲取事件
func get_event_by_id(event_id: String) -> Dictionary:
	for event in events_data.get("events", []):
		if event.get("id", "") == event_id:
			return event
	return {}

# 根據類別獲取事件
func get_events_by_category(category: String) -> Array:
	return _events_by_category.get(category, [])

# 獲取平衡數據
func get_balance_config(path: String = "") -> Dictionary:
	if path.is_empty():
		return balance_data.get("game_balance", {})

	var config = balance_data.get("game_balance", {})
	var path_parts = path.split(".")
	for part in path_parts:
		if config.has(part):
			config = config[part]
			# 如果遇到非Dictionary值，包裝成Dictionary返回
			if not config is Dictionary:
				return {"value": config}
		else:
			return {}

	# 確保始終返回Dictionary
	if config is Dictionary:
		return config
	else:
		return {"value": config}

# 獲取載入進度
func get_load_progress() -> float:
	return _load_progress

# 檢查是否正在載入
func is_loading() -> bool:
	return _is_loading

# 獲取載入錯誤
func get_load_errors() -> Array[String]:
	return _load_errors.duplicate()