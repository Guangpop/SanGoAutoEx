# CombatCalculator.gd - 戰鬥計算核心
#
# 功能：
# - 實現所有戰鬥相關的數學計算
# - 處理傷害、防禦、暴擊計算
# - 計算戰鬥勝率和結果判定
# - 處理裝備和技能加成

extends Node
class_name CombatCalculator

# 戰鬥計算配置
var balance_config: Dictionary = {}

func _ready() -> void:
	name = "CombatCalculator"
	LogManager.info("CombatCalculator", "戰鬥計算器初始化")

	# 載入平衡配置
	load_balance_config()

# 載入平衡配置
func load_balance_config() -> void:
	if DataManager:
		balance_config = DataManager.get_balance_config("damage_calculation")
		if balance_config.is_empty():
			LogManager.warning("CombatCalculator", "未找到平衡配置，使用默認值")
			_set_default_config()
	else:
		_set_default_config()

# 設置默認配置
func _set_default_config() -> void:
	balance_config = {
		"base_damage_formula": "(武力 * 2) + (智力 * 1.5) + equipment_bonus",
		"defense_formula": "(統治 * 1.8) + (政治 * 0.5) + equipment_bonus",
		"skill_damage_modifier": 1.3,
		"critical_hit_chance": 0.05,
		"critical_damage_multiplier": 1.5
	}

# === 核心戰鬥計算方法 ===

# 計算完整戰鬥結果
func calculate_battle_result(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	# 檢查零兵力情況
	if attacker.get("troops", 0) <= 0:
		return {
			"victor": "defender",
			"attacker_casualties": 0,
			"defender_casualties": 0,
			"experience_gained": 0
		}

	if defender.get("troops", 0) <= 0:
		return {
			"victor": "attacker",
			"attacker_casualties": 0,
			"defender_casualties": 0,
			"experience_gained": calculate_experience_gain(attacker.get("level", 1) - defender.get("level", 1), true)
		}

	# 計算戰力評估
	var attacker_power = calculate_power_rating(attacker)
	var defender_power = calculate_power_rating(defender)
	var power_difference = attacker_power - defender_power

	# 計算戰鬥勝率
	var success_rate = calculate_battle_success_rate(power_difference)
	var is_victory = randf() < success_rate

	# 計算傷亡
	var victor = "attacker" if is_victory else "defender"
	var victory_loss_rate = 0.1
	var defeat_loss_rate = 0.3

	var attacker_losses = calculate_troop_losses(attacker.troops, victory_loss_rate if is_victory else defeat_loss_rate)
	var defender_losses = calculate_troop_losses(defender.troops, defeat_loss_rate if is_victory else victory_loss_rate)

	# 計算經驗值
	var experience_gained = calculate_experience_gain(attacker.get("level", 1) - defender.get("level", 1), is_victory)

	return {
		"victor": victor,
		"attacker_casualties": attacker.troops - attacker_losses,
		"defender_casualties": defender.troops - defender_losses,
		"experience_gained": experience_gained
	}

# 計算基礎傷害
func calculate_base_damage(character: Dictionary) -> float:
	var martial = character.attributes.get("武力", 0)
	var intelligence = character.attributes.get("智力", 0)
	var equipment_bonus = calculate_equipment_bonus(character.get("equipment", []), "damage")

	return (martial * 2.0) + (intelligence * 1.5) + equipment_bonus

# 計算防禦值
func calculate_defense(character: Dictionary) -> float:
	var leadership = character.attributes.get("統治", 0)
	var politics = character.attributes.get("政治", 0)
	var equipment_bonus = calculate_equipment_bonus(character.get("equipment", []), "defense")

	return (leadership * 1.8) + (politics * 0.5) + equipment_bonus

# 計算綜合戰力評估
func calculate_power_rating(character: Dictionary) -> float:
	var attrs = character.attributes
	return (attrs.get("武力", 0) * 3) + \
		   (attrs.get("智力", 0) * 2.5) + \
		   (attrs.get("統治", 0) * 2) + \
		   (attrs.get("政治", 0) * 1.5) + \
		   (attrs.get("魅力", 0) * 1.5) + \
		   (attrs.get("天命", 0) * 2)

# 計算戰鬥勝率
func calculate_battle_success_rate(power_difference: float) -> float:
	var base_rate = 0.5
	var advantage_bonus = power_difference * 0.01
	var success_rate = base_rate + advantage_bonus
	return clamp(success_rate, 0.05, 0.95)

# === 傷害和效果計算 ===

# 應用暴擊傷害
func apply_critical_hit(damage: float, multiplier: float = 1.5) -> float:
	return damage * multiplier

# 應用技能傷害修正
func apply_skill_modifier(damage: float, modifier: float = 1.3) -> float:
	return damage * modifier

# 檢查是否觸發暴擊
func is_critical_hit(base_chance: float = 0.05) -> bool:
	return randf() < base_chance

# === 兵力和資源計算 ===

# 計算兵力損失
func calculate_troop_losses(initial_troops: int, loss_rate: float) -> int:
	return int(initial_troops * (1.0 - loss_rate))

# 計算經驗值獲得
func calculate_experience_gain(level_difference: int, is_victory: bool) -> int:
	var base_exp = 100
	if is_victory:
		base_exp += 50

	# 等級差異影響
	if level_difference < 0: # 對抗更高等級
		base_exp += abs(level_difference) * 20

	return max(base_exp, 10)

# === 裝備和加成計算 ===

# 計算裝備加成
func calculate_equipment_bonus(equipment: Array, bonus_type: String) -> float:
	var total_bonus = 0.0
	for item in equipment:
		if item is Dictionary:
			var effects = item.get("special_effects", {})
			var bonus_key = bonus_type + "_bonus"
			total_bonus += effects.get(bonus_key, 0)
	return total_bonus

# 計算屬性加成
func calculate_attribute_bonus(character: Dictionary, attribute_name: String) -> int:
	var base_value = character.attributes.get(attribute_name, 0)
	var equipment_bonus = 0

	# 計算裝備屬性加成
	var equipment = character.get("equipment", [])
	for item in equipment:
		if item is Dictionary:
			var item_attributes = item.get("attributes", {})
			equipment_bonus += item_attributes.get(attribute_name, 0)

	return base_value + equipment_bonus

# === 特殊戰鬥情況處理 ===

# 處理圍城戰加成
func apply_siege_bonus(attacker_power: float, is_siege: bool = false) -> float:
	if is_siege:
		return attacker_power * 0.8 # 圍城方劣勢
	return attacker_power

# 處理地形影響
func apply_terrain_modifier(power: float, terrain_type: String) -> float:
	var terrain_modifiers = {
		"mountain": 0.9,    # 山地不利進攻
		"river": 0.85,      # 河流阻礙
		"plain": 1.0,       # 平原無影響
		"forest": 0.95,     # 森林稍有阻礙
		"city": 1.1         # 城池防禦優勢
	}

	var modifier = terrain_modifiers.get(terrain_type, 1.0)
	return power * modifier

# === 戰鬥模擬和測試方法 ===

# 模擬單次戰鬥（用於測試）
func simulate_single_battle(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	return calculate_battle_result(attacker, defender)

# 批量戰鬥模擬（用於平衡測試）
func simulate_battles(attacker: Dictionary, defender: Dictionary, count: int = 1000) -> Dictionary:
	var results = {
		"attacker_wins": 0,
		"defender_wins": 0,
		"total_battles": count,
		"win_rate": 0.0
	}

	for i in range(count):
		var result = calculate_battle_result(attacker, defender)
		if result.victor == "attacker":
			results.attacker_wins += 1
		else:
			results.defender_wins += 1

	results.win_rate = float(results.attacker_wins) / count
	return results

# === 調試和驗證方法 ===

# 驗證角色數據完整性
func validate_character_for_battle(character: Dictionary) -> bool:
	var required_fields = ["attributes", "level", "troops"]
	for field in required_fields:
		if not character.has(field):
			return false

	var required_attributes = ["武力", "智力", "統治", "政治", "魅力", "天命"]
	var attributes = character.get("attributes", {})
	for attr in required_attributes:
		if not attributes.has(attr):
			return false

	return true

# 獲取戰鬥計算詳情（用於調試）
func get_battle_calculation_details(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	return {
		"attacker_power": calculate_power_rating(attacker),
		"defender_power": calculate_power_rating(defender),
		"attacker_damage": calculate_base_damage(attacker),
		"attacker_defense": calculate_defense(attacker),
		"defender_damage": calculate_base_damage(defender),
		"defender_defense": calculate_defense(defender),
		"success_rate": calculate_battle_success_rate(calculate_power_rating(attacker) - calculate_power_rating(defender))
	}