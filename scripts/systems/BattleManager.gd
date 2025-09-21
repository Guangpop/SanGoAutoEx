# BattleManager.gd - 戰鬥系統管理器
#
# 功能：
# - 處理戰鬥流程與邏輯
# - 協調戰鬥計算器與戰鬥結果
# - 管理戰鬥狀態和事件觸發
# - 處理戰利品和經驗值分配

extends Node

signal battle_started(attacker: Dictionary, defender: Dictionary)
signal battle_completed(result: Dictionary)
signal experience_gained(amount: int, reason: String)

var current_battle: Dictionary = {}
var battle_history: Array[Dictionary] = []
var combat_calculator: CombatCalculator

func _ready() -> void:
	name = "BattleManager"
	LogManager.info("BattleManager", "戰鬥管理器初始化")

	# 初始化戰鬥計算器
	combat_calculator = CombatCalculator.new()
	add_child(combat_calculator)

	# 連接事件處理器
	connect_event_handlers()

func connect_event_handlers() -> void:
	EventBus.connect_safe("battle_initiated", _on_battle_initiated)
	LogManager.debug("BattleManager", "事件處理器連接完成")

# === 戰鬥流程控制 ===

# 發起戰鬥
func initiate_battle(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	LogManager.info("BattleManager", "發起戰鬥", {
		"attacker": attacker.get("name", "未知"),
		"defender": defender.get("name", "未知")
	})

	# 驗證戰鬥參與者數據
	if not _validate_character_data(attacker) or not _validate_character_data(defender):
		LogManager.error("BattleManager", "戰鬥參與者數據無效")
		return {"error": "invalid_character_data"}

	# 設置當前戰鬥
	current_battle = {
		"attacker": attacker.duplicate(),
		"defender": defender.duplicate(),
		"start_time": Time.get_unix_time_from_system(),
		"battle_id": generate_battle_id()
	}

	# 發送戰鬥開始事件
	battle_started.emit(attacker, defender)
	EventBus.battle_initiated.emit(attacker, defender)

	# 執行戰鬥計算
	var battle_result = combat_calculator.calculate_battle_result(attacker, defender)

	# 處理戰鬥結果
	_process_battle_result(battle_result)

	return battle_result

# 處理戰鬥結果
func _process_battle_result(result: Dictionary) -> void:
	var attacker = current_battle.attacker
	var defender = current_battle.defender

	LogManager.game_event("Battle", "戰鬥結束", {
		"victor": result.victor,
		"attacker_casualties": result.attacker_casualties,
		"defender_casualties": result.defender_casualties
	})

	# 計算經驗值獎勵
	var experience_reward = _calculate_experience_reward(result)
	if experience_reward > 0:
		experience_gained.emit(experience_reward, "battle_victory")

	# 記錄戰鬥歷史
	_record_battle_history(result)

	# 發送戰鬥完成事件
	battle_completed.emit(result)
	EventBus.battle_completed.emit(result, result.victor, {
		"attacker_casualties": result.attacker_casualties,
		"defender_casualties": result.defender_casualties
	})

	# 清理當前戰鬥狀態
	current_battle.clear()

# 計算經驗值獎勵
func _calculate_experience_reward(battle_result: Dictionary) -> int:
	var base_experience = 100
	var victory_bonus = 50 if battle_result.victor == "attacker" else 0

	# 根據等級差異調整經驗值
	var attacker = current_battle.attacker
	var defender = current_battle.defender
	var level_diff = attacker.get("level", 1) - defender.get("level", 1)

	var level_modifier = 0
	if level_diff < 0: # 攻擊更高等級敵人
		level_modifier = abs(level_diff) * 20

	return base_experience + victory_bonus + level_modifier

# 記錄戰鬥歷史
func _record_battle_history(result: Dictionary) -> void:
	var history_entry = {
		"battle_id": current_battle.battle_id,
		"timestamp": current_battle.start_time,
		"attacker": current_battle.attacker.get("name", "未知"),
		"defender": current_battle.defender.get("name", "未知"),
		"victor": result.victor,
		"duration": Time.get_unix_time_from_system() - current_battle.start_time,
		"casualties": {
			"attacker": result.attacker_casualties,
			"defender": result.defender_casualties
		},
		"experience_gained": result.get("experience_gained", 0)
	}

	battle_history.append(history_entry)

	# 限制歷史記錄數量
	if battle_history.size() > 100:
		battle_history = battle_history.slice(-100)

# === 戰鬥查詢和統計 ===

# 獲取戰鬥歷史
func get_battle_history(limit: int = 10) -> Array[Dictionary]:
	var history_size = battle_history.size()
	var start_index = max(0, history_size - limit)
	return battle_history.slice(start_index)

# 獲取戰鬥統計
func get_battle_statistics() -> Dictionary:
	var total_battles = battle_history.size()
	var victories = 0
	var defeats = 0

	for battle in battle_history:
		if battle.victor == "attacker":
			victories += 1
		else:
			defeats += 1

	return {
		"total_battles": total_battles,
		"victories": victories,
		"defeats": defeats,
		"win_rate": float(victories) / total_battles if total_battles > 0 else 0.0
	}

# 檢查是否正在戰鬥
func is_battle_active() -> bool:
	return not current_battle.is_empty()

# 獲取當前戰鬥信息
func get_current_battle() -> Dictionary:
	return current_battle.duplicate()

# === 輔助方法 ===

# 驗證角色數據
func _validate_character_data(character: Dictionary) -> bool:
	var required_fields = ["attributes", "level", "troops"]
	for field in required_fields:
		if not character.has(field):
			LogManager.error("BattleManager", "角色數據缺少必要字段", {"field": field})
			return false

	var required_attributes = ["武力", "智力", "統治", "政治", "魅力", "天命"]
	var attributes = character.get("attributes", {})
	for attr in required_attributes:
		if not attributes.has(attr):
			LogManager.error("BattleManager", "角色屬性不完整", {"missing_attribute": attr})
			return false

	return true

# 生成戰鬥ID
func generate_battle_id() -> String:
	var timestamp = Time.get_unix_time_from_system()
	var random_suffix = randi() % 10000
	return "battle_%d_%04d" % [timestamp, random_suffix]

# === 事件處理器 ===

func _on_battle_initiated(attacker: Dictionary, defender: Dictionary) -> void:
	LogManager.debug("BattleManager", "收到戰鬥發起事件", {
		"attacker": attacker.get("name", "未知"),
		"defender": defender.get("name", "未知")
	})