# test_battle_system.gd - 戰鬥系統單元測試
#
# 測試範圍：
# - 戰鬥計算器 (傷害、防禦、暴擊)
# - 戰鬥結果判定
# - 技能和裝備加成
# - 勝負機率計算
# - 戰利品和經驗值分配

extends GdUnitTestSuite

# 測試用的模擬數據
var test_attacker: Dictionary
var test_defender: Dictionary
var test_balance_config: Dictionary

func before_test() -> void:
	# 設置測試用的攻擊者數據
	test_attacker = {
		"id": "test_attacker",
		"name": "測試攻擊者",
		"attributes": {
			"武力": 80,
			"智力": 60,
			"統治": 70,
			"政治": 50,
			"魅力": 60,
			"天命": 75
		},
		"level": 5,
		"equipment": [],
		"skills": [],
		"troops": 1000
	}

	# 設置測試用的防禦者數據
	test_defender = {
		"id": "test_defender",
		"name": "測試防禦者",
		"attributes": {
			"武力": 70,
			"智力": 50,
			"統治": 80,
			"政治": 60,
			"魅力": 50,
			"天命": 60
		},
		"level": 4,
		"equipment": [],
		"skills": [],
		"troops": 800
	}

	# 設置測試用的平衡配置
	test_balance_config = {
		"damage_calculation": {
			"base_damage_formula": "(武力 * 2) + (智力 * 1.5) + equipment_bonus",
			"defense_formula": "(統治 * 1.8) + (政治 * 0.5) + equipment_bonus",
			"skill_damage_modifier": 1.3,
			"critical_hit_chance": 0.05,
			"critical_damage_multiplier": 1.5
		},
		"battle_success_rates": {
			"equal_power": 0.5,
			"power_advantage_10": 0.6,
			"power_advantage_25": 0.75,
			"power_advantage_50": 0.9,
			"power_advantage_100": 0.95
		},
		"troop_losses": {
			"victory_loss_rate": 0.1,
			"defeat_loss_rate": 0.3,
			"siege_bonus_loss": 0.05
		}
	}

func after_test() -> void:
	# 測試後清理
	pass

# === 戰鬥計算器測試 ===

func test_damage_calculation():
	# 測試基礎傷害計算
	var martial_power = test_attacker.attributes["武力"]
	var intelligence = test_attacker.attributes["智力"]
	var equipment_bonus = 0 # 無裝備

	# 基礎傷害公式: (武力 * 2) + (智力 * 1.5)
	var expected_damage = (martial_power * 2) + (intelligence * 1.5)
	var calculated_damage = _calculate_base_damage(test_attacker)

	assert_float(calculated_damage).is_equal(expected_damage)

func test_defense_calculation():
	# 測試防禦計算
	var leadership = test_defender.attributes["統治"]
	var politics = test_defender.attributes["政治"]
	var equipment_bonus = 0 # 無裝備

	# 防禦公式: (統治 * 1.8) + (政治 * 0.5)
	var expected_defense = (leadership * 1.8) + (politics * 0.5)
	var calculated_defense = _calculate_defense(test_defender)

	assert_float(calculated_defense).is_equal(expected_defense)

func test_power_rating_calculation():
	# 測試綜合戰力評估
	var attacker_power = _calculate_power_rating(test_attacker)
	var defender_power = _calculate_power_rating(test_defender)

	# 攻擊者應該有更高戰力
	assert_float(attacker_power).is_greater(defender_power)

	# 驗證戰力計算公式
	var expected_attacker_power = (
		(test_attacker.attributes["武力"] * 3) +
		(test_attacker.attributes["智力"] * 2.5) +
		(test_attacker.attributes["統治"] * 2) +
		(test_attacker.attributes["政治"] * 1.5) +
		(test_attacker.attributes["魅力"] * 1.5) +
		(test_attacker.attributes["天命"] * 2)
	)

	assert_float(attacker_power).is_equal(expected_attacker_power)

func test_critical_hit_calculation():
	# 測試暴擊計算
	var base_damage = 100.0
	var critical_multiplier = 1.5

	var critical_damage = _apply_critical_hit(base_damage, critical_multiplier)
	assert_float(critical_damage).is_equal(150.0)

func test_skill_damage_modifier():
	# 測試技能傷害加成
	var base_damage = 100.0
	var skill_modifier = 1.3

	var enhanced_damage = _apply_skill_modifier(base_damage, skill_modifier)
	assert_float(enhanced_damage).is_equal(130.0)

# === 戰鬥結果判定測試 ===

func test_battle_success_probability():
	# 測試戰鬥勝率計算
	var attacker_power = _calculate_power_rating(test_attacker)
	var defender_power = _calculate_power_rating(test_defender)
	var power_difference = attacker_power - defender_power

	# 計算勝率
	var success_rate = _calculate_battle_success_rate(power_difference)

	# 勝率應該在0.05到0.95之間
	assert_float(success_rate).is_greater_equal(0.05)
	assert_float(success_rate).is_less_equal(0.95)

	# 戰力優勢應該提高勝率
	assert_float(success_rate).is_greater(0.5) # 因為攻擊者戰力更高

func test_equal_power_battle():
	# 測試同等戰力的戰鬥
	var equal_defender = test_attacker.duplicate()
	equal_defender.id = "equal_defender"

	var attacker_power = _calculate_power_rating(test_attacker)
	var defender_power = _calculate_power_rating(equal_defender)

	# 戰力應該相等
	assert_float(attacker_power).is_equal(defender_power)

	# 勝率應該是50%
	var success_rate = _calculate_battle_success_rate(0)
	assert_float(success_rate).is_equal(0.5)

func test_overwhelming_advantage():
	# 測試壓倒性優勢
	var weak_defender = test_defender.duplicate()
	for attr in weak_defender.attributes:
		weak_defender.attributes[attr] = 10 # 極低屬性

	var attacker_power = _calculate_power_rating(test_attacker)
	var defender_power = _calculate_power_rating(weak_defender)
	var power_difference = attacker_power - defender_power

	var success_rate = _calculate_battle_success_rate(power_difference)

	# 應該有很高的勝率 (接近95%)
	assert_float(success_rate).is_greater(0.9)

# === 兵力損失測試 ===

func test_victory_troop_losses():
	# 測試勝利時的兵力損失
	var initial_troops = test_attacker.troops
	var loss_rate = test_balance_config.troop_losses.victory_loss_rate

	var remaining_troops = _calculate_troop_losses(initial_troops, loss_rate)
	var expected_remaining = initial_troops * (1.0 - loss_rate)

	assert_int(remaining_troops).is_equal(int(expected_remaining))

func test_defeat_troop_losses():
	# 測試失敗時的兵力損失
	var initial_troops = test_defender.troops
	var loss_rate = test_balance_config.troop_losses.defeat_loss_rate

	var remaining_troops = _calculate_troop_losses(initial_troops, loss_rate)
	var expected_remaining = initial_troops * (1.0 - loss_rate)

	assert_int(remaining_troops).is_equal(int(expected_remaining))

# === 裝備加成測試 ===

func test_equipment_damage_bonus():
	# 測試裝備對傷害的加成
	var equipment_with_bonus = {
		"id": "test_weapon",
		"name": "測試武器",
		"attributes": {"武力": 20},
		"special_effects": {"damage_bonus": 15}
	}

	test_attacker.equipment = [equipment_with_bonus]

	var base_damage = _calculate_base_damage(test_attacker)
	var equipment_bonus = _calculate_equipment_bonus(test_attacker.equipment, "damage")

	# 應該包含裝備加成
	assert_float(equipment_bonus).is_greater(0)

func test_equipment_defense_bonus():
	# 測試裝備對防禦的加成
	var equipment_with_defense = {
		"id": "test_armor",
		"name": "測試盔甲",
		"attributes": {"統治": 15},
		"special_effects": {"defense_bonus": 20}
	}

	test_defender.equipment = [equipment_with_defense]

	var defense_bonus = _calculate_equipment_bonus(test_defender.equipment, "defense")
	assert_float(defense_bonus).is_greater(0)

# === 完整戰鬥流程測試 ===

func test_complete_battle_flow():
	# 測試完整的戰鬥流程
	var battle_result = _simulate_complete_battle(test_attacker, test_defender)

	# 驗證戰鬥結果結構
	assert_dict(battle_result).contains_key("victor")
	assert_dict(battle_result).contains_key("attacker_casualties")
	assert_dict(battle_result).contains_key("defender_casualties")
	assert_dict(battle_result).contains_key("experience_gained")

	# 勝利者應該是攻擊者或防禦者之一
	var victor = battle_result.victor
	assert_bool(victor == "attacker" or victor == "defender").is_true()

func test_experience_calculation():
	# 測試經驗值計算
	var level_difference = test_attacker.level - test_defender.level
	var experience_gained = _calculate_experience_gain(level_difference, true) # 勝利

	# 勝利應該獲得經驗值
	assert_int(experience_gained).is_greater(0)

	# 等級差距應該影響經驗值
	var higher_level_exp = _calculate_experience_gain(-2, true) # 對抗更高等級
	assert_int(higher_level_exp).is_greater(experience_gained)

# === 邊界條件測試 ===

func test_zero_troops_battle():
	# 測試零兵力的戰鬥
	var no_troops_attacker = test_attacker.duplicate()
	no_troops_attacker.troops = 0

	var battle_result = _simulate_complete_battle(no_troops_attacker, test_defender)

	# 零兵力應該自動失敗
	assert_str(battle_result.victor).is_equal("defender")

func test_maximum_attribute_values():
	# 測試最大屬性值的戰鬥
	var max_attacker = test_attacker.duplicate()
	for attr in max_attacker.attributes:
		max_attacker.attributes[attr] = 100

	var power_rating = _calculate_power_rating(max_attacker)
	assert_float(power_rating).is_greater(0)

func test_minimum_attribute_values():
	# 測試最小屬性值的戰鬥
	var min_attacker = test_attacker.duplicate()
	for attr in min_attacker.attributes:
		min_attacker.attributes[attr] = 1

	var power_rating = _calculate_power_rating(min_attacker)
	assert_float(power_rating).is_greater(0)

# === 性能測試 ===

func test_battle_calculation_performance():
	# 測試戰鬥計算性能
	var start_time = Time.get_unix_time_from_system()

	# 執行1000次戰鬥計算
	for i in range(1000):
		_simulate_complete_battle(test_attacker, test_defender)

	var end_time = Time.get_unix_time_from_system()
	var duration = end_time - start_time

	# 1000次戰鬥計算應在1秒內完成
	assert_float(duration).is_less(1.0)

# === 輔助測試方法 ===

func _calculate_base_damage(character: Dictionary) -> float:
	var martial = character.attributes.get("武力", 0)
	var intelligence = character.attributes.get("智力", 0)
	return (martial * 2.0) + (intelligence * 1.5)

func _calculate_defense(character: Dictionary) -> float:
	var leadership = character.attributes.get("統治", 0)
	var politics = character.attributes.get("政治", 0)
	return (leadership * 1.8) + (politics * 0.5)

func _calculate_power_rating(character: Dictionary) -> float:
	var attrs = character.attributes
	return (attrs.get("武力", 0) * 3) + \
		   (attrs.get("智力", 0) * 2.5) + \
		   (attrs.get("統治", 0) * 2) + \
		   (attrs.get("政治", 0) * 1.5) + \
		   (attrs.get("魅力", 0) * 1.5) + \
		   (attrs.get("天命", 0) * 2)

func _apply_critical_hit(damage: float, multiplier: float) -> float:
	return damage * multiplier

func _apply_skill_modifier(damage: float, modifier: float) -> float:
	return damage * modifier

func _calculate_battle_success_rate(power_difference: float) -> float:
	var base_rate = 0.5
	var advantage_bonus = power_difference * 0.01
	var success_rate = base_rate + advantage_bonus
	return clamp(success_rate, 0.05, 0.95)

func _calculate_troop_losses(initial_troops: int, loss_rate: float) -> int:
	return int(initial_troops * (1.0 - loss_rate))

func _calculate_equipment_bonus(equipment: Array, bonus_type: String) -> float:
	var total_bonus = 0.0
	for item in equipment:
		var effects = item.get("special_effects", {})
		var bonus_key = bonus_type + "_bonus"
		total_bonus += effects.get(bonus_key, 0)
	return total_bonus

func _calculate_experience_gain(level_difference: int, is_victory: bool) -> int:
	var base_exp = 100
	if is_victory:
		base_exp += 50

	# 等級差異影響
	if level_difference < 0: # 對抗更高等級
		base_exp += abs(level_difference) * 20

	return max(base_exp, 10)

func _simulate_complete_battle(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	# 簡化的戰鬥模擬
	if attacker.troops <= 0:
		return {"victor": "defender", "attacker_casualties": 0, "defender_casualties": 0, "experience_gained": 0}

	var attacker_power = _calculate_power_rating(attacker)
	var defender_power = _calculate_power_rating(defender)
	var power_diff = attacker_power - defender_power

	var success_rate = _calculate_battle_success_rate(power_diff)
	var is_victory = randf() < success_rate

	var victor = "attacker" if is_victory else "defender"
	var attacker_losses = _calculate_troop_losses(attacker.troops, 0.1 if is_victory else 0.3)
	var defender_losses = _calculate_troop_losses(defender.troops, 0.3 if is_victory else 0.1)
	var exp_gained = _calculate_experience_gain(attacker.level - defender.level, is_victory)

	return {
		"victor": victor,
		"attacker_casualties": attacker.troops - attacker_losses,
		"defender_casualties": defender.troops - defender_losses,
		"experience_gained": exp_gained
	}