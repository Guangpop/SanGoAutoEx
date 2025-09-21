# RandomEventSystem.gd - 隨機事件自動觸發系統
#
# 功能：
# - 根據天命值自動觸發隨機事件
# - 事件自動選擇最佳結果（非手動選擇）
# - 基於概率的智能事件分發
# - 事件結果自動應用到遊戲狀態

extends Node

# 事件觸發控制
var events_data: Array = []
var event_cooldown: Dictionary = {}
var base_event_chance: float = 0.15  # 每回合15%基礎概率
var tianming_modifier: float = 0.01   # 每點天命增加1%概率

# 事件類型權重
var event_type_weights = {
	"beneficial": 0.4,    # 有益事件40%
	"neutral": 0.35,      # 中性事件35%
	"challenging": 0.25   # 挑戰事件25%
}

# 天命影響事件結果
var tianming_outcome_bonus: float = 0.02  # 每點天命增加2%好結果機率

func _ready() -> void:
	name = "RandomEventSystem"

	# 等待數據系統初始化
	await _wait_for_data_system()

	# 載入事件數據
	load_events_data()

	# 連接遊戲事件
	connect_event_handlers()

	LogManager.info("RandomEventSystem", "隨機事件系統初始化完成", {
		"events_loaded": events_data.size(),
		"base_chance": base_event_chance
	})

# 等待數據系統初始化
func _wait_for_data_system() -> void:
	var max_wait_time = 5.0
	var wait_start = Time.get_unix_time_from_system()

	while not DataManager or DataManager.events_data.is_empty():
		await get_tree().process_frame
		var elapsed = Time.get_unix_time_from_system() - wait_start
		if elapsed > max_wait_time:
			LogManager.warn("RandomEventSystem", "等待數據系統超時", {"elapsed": elapsed})
			break

# 載入事件數據
func load_events_data() -> void:
	if DataManager and DataManager.events_data.size() > 0:
		var data = DataManager.events_data
		if data is Array:
			events_data = data.duplicate()
		elif data is Dictionary:
			events_data = data.values()
		LogManager.info("RandomEventSystem", "從DataManager載入事件數據", {
			"events_count": events_data.size()
		})
	else:
		LogManager.error("RandomEventSystem", "無法載入事件數據")

# 連接事件處理器
func connect_event_handlers() -> void:
	if EventBus:
		EventBus.connect_safe("turn_completed", _on_turn_completed)
		EventBus.connect_safe("game_state_changed", _on_game_state_changed)

	LogManager.debug("RandomEventSystem", "事件處理器連接完成")

# 每回合檢查是否觸發隨機事件
func _on_turn_completed(turn_data: Dictionary) -> void:
	if not should_trigger_event():
		return

	var current_turn = turn_data.get("turn", 1)
	var player_tianming = _get_player_tianming()

	# 選擇事件
	var selected_event = select_random_event(player_tianming, current_turn)
	if selected_event.is_empty():
		return

	# 自動觸發事件
	trigger_automatic_event(selected_event, player_tianming)

# 判斷是否應該觸發事件
func should_trigger_event() -> bool:
	var player_tianming = _get_player_tianming()
	var total_chance = base_event_chance + (player_tianming * tianming_modifier)

	var roll = randf()
	var triggered = roll < total_chance

	LogManager.debug("RandomEventSystem", "事件觸發檢查", {
		"tianming": player_tianming,
		"total_chance": total_chance,
		"roll": roll,
		"triggered": triggered
	})

	return triggered

# 選擇隨機事件
func select_random_event(tianming: int, current_turn: int) -> Dictionary:
	var available_events = _get_available_events(current_turn)
	if available_events.is_empty():
		return {}

	# 根據天命值調整事件類型權重
	var adjusted_weights = _adjust_weights_by_tianming(tianming)

	# 選擇事件類型
	var selected_type = _select_weighted_type(adjusted_weights)

	# 從該類型中選擇具體事件
	var type_events = available_events.filter(func(event): return event.get("type", "neutral") == selected_type)
	if type_events.is_empty():
		# 回退到所有可用事件
		type_events = available_events

	var selected_event = type_events[randi() % type_events.size()]

	LogManager.info("RandomEventSystem", "事件已選擇", {
		"event_id": selected_event.get("id", ""),
		"event_name": selected_event.get("name", ""),
		"type": selected_event.get("type", "neutral")
	})

	return selected_event

# 獲取可用事件（過濾冷卻時間和條件）
func _get_available_events(current_turn: int) -> Array:
	var available = []

	for event in events_data:
		var event_id = event.get("id", "")

		# 檢查冷卻時間
		if event_cooldown.has(event_id):
			var last_triggered = event_cooldown[event_id]
			var cooldown_period = event.get("cooldown", 10)
			if current_turn - last_triggered < cooldown_period:
				continue

		# 檢查觸發條件（如果有的話）
		if _check_event_conditions(event):
			available.append(event)

	return available

# 檢查事件觸發條件
func _check_event_conditions(event: Dictionary) -> bool:
	var conditions = event.get("conditions", {})
	if conditions.is_empty():
		return true

	# 檢查回合條件
	if conditions.has("min_turn"):
		var current_turn = _get_current_turn()
		if current_turn < conditions.min_turn:
			return false

	# 檢查城池數量條件
	if conditions.has("min_cities"):
		var city_count = _get_player_city_count()
		if city_count < conditions.min_cities:
			return false

	# 檢查武將數量條件
	if conditions.has("min_generals"):
		var general_count = _get_player_general_count()
		if general_count < conditions.min_generals:
			return false

	return true

# 根據天命調整事件類型權重
func _adjust_weights_by_tianming(tianming: int) -> Dictionary:
	var adjusted = event_type_weights.duplicate()

	# 高天命增加有益事件概率，降低挑戰事件概率
	var tianming_factor = tianming / 100.0
	adjusted["beneficial"] += tianming_factor * 0.2
	adjusted["challenging"] -= tianming_factor * 0.15

	# 確保權重為正數且總和為1
	for key in adjusted:
		adjusted[key] = max(adjusted[key], 0.05)

	var total = 0.0
	for weight in adjusted.values():
		total += weight

	for key in adjusted:
		adjusted[key] /= total

	return adjusted

# 加權選擇事件類型
func _select_weighted_type(weights: Dictionary) -> String:
	var roll = randf()
	var cumulative = 0.0

	for type in weights:
		cumulative += weights[type]
		if roll <= cumulative:
			return type

	return "neutral"  # 回退選項

# 自動觸發事件並選擇最佳結果
func trigger_automatic_event(event: Dictionary, tianming: int) -> void:
	var event_id = event.get("id", "")
	var event_name = event.get("name", "未知事件")

	# 自動選擇最佳結果
	var best_outcome = _select_best_outcome(event, tianming)

	# 應用事件結果
	_apply_event_outcome(event, best_outcome)

	# 記錄事件到遊戲日誌
	var event_description = _generate_event_description(event, best_outcome)
	_add_game_event(event_description)

	# 設置冷卻時間
	var current_turn = _get_current_turn()
	event_cooldown[event_id] = current_turn

	# 發送事件完成信號
	EventBus.emit_safe("random_event_completed", [event, best_outcome])

	LogManager.info("RandomEventSystem", "自動事件已處理", {
		"event": event_name,
		"outcome": best_outcome.get("name", ""),
		"tianming_used": tianming
	})

# 智能選擇最佳結果
func _select_best_outcome(event: Dictionary, tianming: int) -> Dictionary:
	var outcomes = event.get("outcomes", [])
	if outcomes.is_empty():
		return {}

	# 如果只有一個結果，直接返回
	if outcomes.size() == 1:
		return outcomes[0]

	# 計算每個結果的價值分數
	var best_outcome = outcomes[0]
	var best_score = _calculate_outcome_score(best_outcome, tianming)

	for outcome in outcomes:
		var score = _calculate_outcome_score(outcome, tianming)
		if score > best_score:
			best_score = score
			best_outcome = outcome

	return best_outcome

# 計算結果價值分數
func _calculate_outcome_score(outcome: Dictionary, tianming: int) -> float:
	var score = 0.0
	var effects = outcome.get("effects", {})

	# 資源效果評分
	score += effects.get("gold", 0) * 0.1
	score += effects.get("troops", 0) * 0.2
	score += effects.get("experience", 0) * 0.15

	# 屬性效果評分
	var attributes = effects.get("attributes", {})
	for attr in attributes:
		score += attributes[attr] * 1.0

	# 天命影響決策品質
	var tianming_bonus = tianming * tianming_outcome_bonus
	if outcome.get("type", "neutral") == "beneficial":
		score *= (1.0 + tianming_bonus)
	elif outcome.get("type", "neutral") == "challenging":
		score *= (1.0 - tianming_bonus * 0.5)

	return score

# 應用事件結果到遊戲狀態
func _apply_event_outcome(event: Dictionary, outcome: Dictionary) -> void:
	var effects = outcome.get("effects", {})

	# 資源變化
	if effects.has("gold"):
		_modify_player_resource("gold", effects.gold)

	if effects.has("troops"):
		_modify_player_resource("troops", effects.troops)

	if effects.has("experience"):
		_modify_player_resource("experience", effects.experience)

	# 屬性變化
	var attributes = effects.get("attributes", {})
	if not attributes.is_empty():
		_modify_player_attributes(attributes)

	# 特殊效果
	var special_effects = effects.get("special", [])
	for effect in special_effects:
		_apply_special_effect(effect)

# 生成事件描述文本
func _generate_event_description(event: Dictionary, outcome: Dictionary) -> String:
	var event_name = event.get("name", "隨機事件")
	var description = event.get("description", "")
	var outcome_text = outcome.get("description", "事件已處理")

	var full_description = "📯 %s\n%s\n✨ %s" % [event_name, description, outcome_text]

	# 添加效果摘要
	var effects = outcome.get("effects", {})
	var effect_summary = _summarize_effects(effects)
	if not effect_summary.is_empty():
		full_description += "\n" + effect_summary

	return full_description

# 總結效果
func _summarize_effects(effects: Dictionary) -> String:
	var summary_parts = []

	if effects.has("gold") and effects.gold != 0:
		var gold_text = "💰 %+d 金錢" % effects.gold
		summary_parts.append(gold_text)

	if effects.has("troops") and effects.troops != 0:
		var troops_text = "⚔️ %+d 兵力" % effects.troops
		summary_parts.append(troops_text)

	if effects.has("experience") and effects.experience != 0:
		var exp_text = "⭐ %+d 經驗" % effects.experience
		summary_parts.append(exp_text)

	var attributes = effects.get("attributes", {})
	for attr in attributes:
		if attributes[attr] != 0:
			var attr_text = "📊 %s %+d" % [attr, attributes[attr]]
			summary_parts.append(attr_text)

	return "▸ " + " | ".join(summary_parts) if not summary_parts.is_empty() else ""

# 輔助函數 - 獲取玩家數據
func _get_player_tianming() -> int:
	if DataManager and DataManager.player_data.has("attributes"):
		return DataManager.player_data.attributes.get("tianming", 10)
	return 10

func _get_current_turn() -> int:
	if DataManager and DataManager.game_state.has("current_turn"):
		return DataManager.game_state.current_turn
	return 1

func _get_player_city_count() -> int:
	if CityManager:
		return CityManager.get_player_city_count()
	return 1

func _get_player_general_count() -> int:
	if GeneralsManager:
		return GeneralsManager.get_player_general_count()
	return 1

# 資源和屬性修改
func _modify_player_resource(resource: String, amount: int) -> void:
	if DataManager:
		DataManager.modify_player_resource(resource, amount)
		EventBus.emit_safe("resources_changed", [resource, amount])

func _modify_player_attributes(attributes: Dictionary) -> void:
	if DataManager:
		DataManager.modify_player_attributes(attributes)
		EventBus.emit_safe("player_attributes_changed", [attributes])

func _apply_special_effect(effect: String) -> void:
	# 處理特殊效果，如解鎖新武將、城池事件等
	LogManager.info("RandomEventSystem", "應用特殊效果", {"effect": effect})

func _add_game_event(description: String) -> void:
	if GameEventManager:
		GameEventManager.add_game_event(description)

# 遊戲狀態變化處理
func _on_game_state_changed(new_state: int, old_state: int) -> void:
	if new_state == GameStateManager.GameState.GAME_RUNNING:
		LogManager.info("RandomEventSystem", "遊戲進入運行狀態，隨機事件系統已激活")

# 獲取事件統計信息
func get_event_statistics() -> Dictionary:
	return {
		"total_events": events_data.size(),
		"triggered_events": event_cooldown.size(),
		"base_chance": base_event_chance,
		"tianming_modifier": tianming_modifier
	}