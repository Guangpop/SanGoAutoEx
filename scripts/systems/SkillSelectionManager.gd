# SkillSelectionManager.gd - 技能選擇系統管理器
#
# 功能：
# - 管理技能選擇流程 (3輪選擇)
# - 處理星星消耗和轉換
# - 應用技能效果到玩家屬性
# - 提供技能選擇UI所需的數據和接口

extends Node

# 技能選擇狀態
var selection_state: Dictionary = {
	"current_round": 0,
	"max_rounds": 3,
	"remaining_stars": 10,
	"available_skills": [],
	"selected_skills": []
}

# 私有變量
var _is_active: bool = false
var _player_data: Dictionary = {}

# 公開的狀態訪問方法（get_max_rounds 新增）
func get_max_rounds() -> int:
	return selection_state.max_rounds

# 測試模式：自動完成技能選擇 (已移除)
# var _auto_complete_timer: Timer
# var _auto_complete_enabled: bool = false  # 已禁用自動完成
# var _auto_complete_delay: float = 8.0  # 8秒後自動完成

func _ready() -> void:
	name = "SkillSelectionManager"
	var init_start_time = Time.get_unix_time_from_system()

	LogManager.info("SkillSelectionManager", "技能選擇管理器初始化開始", {
		"initialization_timestamp": init_start_time,
		"initial_state": selection_state,
		"manager_name": name
	})

	# 設置自動完成計時器 (測試用) - 已移除
	# if _auto_complete_enabled:
	#		setup_auto_complete_timer()

	# 連接事件處理器
	connect_event_handlers()

	var init_duration = Time.get_unix_time_from_system() - init_start_time

	LogManager.info("SkillSelectionManager", "技能選擇管理器初始化完成", {
		"initialization_duration": init_duration,
		"event_handlers_connected": true,
		"ready_for_selection": true
	})

# 連接事件處理器
func connect_event_handlers() -> void:
	LogManager.debug("SkillSelectionManager", "開始連接事件處理器", {
		"events_to_connect": ["skill_selection_started", "game_state_changed"]
	})

	var skill_start_connection = EventBus.connect_safe("skill_selection_started", _on_skill_selection_started)
	var state_change_connection = EventBus.connect_safe("game_state_changed", _on_game_state_changed)

	LogManager.info("SkillSelectionManager", "事件處理器連接結果", {
		"skill_selection_started_connected": skill_start_connection,
		"game_state_changed_connected": state_change_connection,
		"all_connections_successful": skill_start_connection and state_change_connection
	})

# 設置自動完成計時器 (測試用) - 已移除
# func setup_auto_complete_timer() -> void:
#	_auto_complete_timer = Timer.new()
#	_auto_complete_timer.wait_time = _auto_complete_delay
#	_auto_complete_timer.timeout.connect(_on_auto_complete_timeout)
#	_auto_complete_timer.autostart = false
#	_auto_complete_timer.one_shot = true
#	add_child(_auto_complete_timer)
#
#	LogManager.info("SkillSelectionManager", "自動完成計時器設置完成", {
#		"auto_complete_enabled": _auto_complete_enabled,
#		"delay": _auto_complete_delay,
#		"timer_ready": true
#	})

# 自動完成技能選擇 (測試用) - 已移除
# func _on_auto_complete_timeout() -> void:
#	if not _is_active:
#		return
#
#	LogManager.info("SkillSelectionManager", "自動完成技能選擇觸發", {
#		"current_round": selection_state.current_round,
#		"remaining_stars": selection_state.remaining_stars,
#		"reason": "testing_auto_complete"
#	})
#
#	# 跳過所有剩餘回合，直接結束技能選擇
#	_finish_skill_selection_immediately()

# 立即結束技能選擇 (測試用) - 已移除
# func _finish_skill_selection_immediately() -> void:
#	LogManager.info("SkillSelectionManager", "立即結束技能選擇", {
#		"remaining_stars": selection_state.remaining_stars,
#		"selected_skills_count": selection_state.selected_skills.size(),
#		"auto_complete": true
#	})
#
#	# 將剩餘星星轉換為屬性
#	var star_conversion = _convert_stars_to_attributes(selection_state.remaining_stars)
#	LogManager.info("SkillSelectionManager", "星星轉換為屬性", star_conversion)
#
#	# 結束選擇流程
#	finish_skill_selection()

# === 公共API方法 ===

# 開始技能選擇流程
func start_skill_selection(player_data: Dictionary) -> bool:
	var start_time = Time.get_unix_time_from_system()

	LogManager.info("SkillSelectionManager", "技能選擇流程啟動請求", {
		"start_timestamp": start_time,
		"player_level": player_data.get("level", "unknown"),
		"player_attributes": player_data.get("attributes", {}),
		"current_active_state": _is_active
	})

	if _is_active:
		LogManager.warn("SkillSelectionManager", "技能選擇已在進行中，拒絕重複啟動", {
			"current_round": selection_state.current_round,
			"remaining_stars": selection_state.remaining_stars,
			"request_denied": true
		})
		return false

	LogManager.debug("SkillSelectionManager", "驗證玩家數據")
	if player_data.is_empty() or not player_data.has("level"):
		LogManager.error("SkillSelectionManager", "玩家數據無效", {
			"player_data_empty": player_data.is_empty(),
			"has_level": player_data.has("level"),
			"validation_failed": true
		})
		return false

	_player_data = player_data.duplicate()
	_is_active = true

	LogManager.info("SkillSelectionManager", "玩家數據設置完成", {
		"player_level": _player_data.level,
		"player_attributes_count": _player_data.get("attributes", {}).size(),
		"manager_activated": _is_active
	})

	# 初始化選擇狀態
	LogManager.debug("SkillSelectionManager", "初始化選擇狀態")
	reset_selection_state()

	LogManager.info("SkillSelectionManager", "技能選擇流程開始", {
		"round": selection_state.current_round + 1,
		"max_rounds": selection_state.max_rounds,
		"remaining_stars": selection_state.remaining_stars,
		"selection_active": true
	})

	# 生成第一輪技能選項
	LogManager.debug("SkillSelectionManager", "生成第一輪技能選項")
	generate_skill_options()

	# 啟動自動完成計時器 (測試用) - 已移除
	# if _auto_complete_enabled and _auto_complete_timer:
	#	_auto_complete_timer.start()
	#	LogManager.info("SkillSelectionManager", "自動完成計時器已啟動", {
	#		"delay": _auto_complete_delay,
	#		"will_auto_complete_at": Time.get_unix_time_from_system() + _auto_complete_delay
	#	})

	var total_start_duration = Time.get_unix_time_from_system() - start_time

	LogManager.info("SkillSelectionManager", "技能選擇流程啟動完成", {
		"startup_duration": total_start_duration,
		"selection_ready": true,
		"available_skills_count": selection_state.available_skills.size()
	})

	return true

# 重置選擇狀態
func reset_selection_state() -> void:
	var reset_start_time = Time.get_unix_time_from_system()

	LogManager.debug("SkillSelectionManager", "開始重置選擇狀態", {
		"previous_state": selection_state.duplicate(),
		"reset_timestamp": reset_start_time
	})

	var balance_config = DataManager.get_balance_config("skill_system.selection_rules")

	LogManager.debug("SkillSelectionManager", "載入配置參數", {
		"config_loaded": balance_config != null,
		"selection_rounds": balance_config.get("selection_rounds", 3) if balance_config else 3,
		"total_stars": balance_config.get("total_stars", 10) if balance_config else 10
	})

	var old_state = selection_state.duplicate()

	selection_state = {
		"current_round": 0,
		"max_rounds": balance_config.get("selection_rounds", 3) if balance_config else 3,
		"remaining_stars": balance_config.get("total_stars", 10) if balance_config else 10,
		"available_skills": [],
		"selected_skills": []
	}

	var reset_duration = Time.get_unix_time_from_system() - reset_start_time

	LogManager.info("SkillSelectionManager", "選擇狀態重置完成", {
		"reset_duration": reset_duration,
		"old_round": old_state.get("current_round", 0),
		"new_round": selection_state.current_round,
		"old_stars": old_state.get("remaining_stars", 0),
		"new_stars": selection_state.remaining_stars,
		"max_rounds": selection_state.max_rounds,
		"state_reset_successful": true
	})

# 生成技能選項
func generate_skill_options() -> void:
	var generation_start_time = Time.get_unix_time_from_system()

	LogManager.info("SkillSelectionManager", "開始生成技能選項", {
		"current_round": selection_state.current_round + 1,
		"max_rounds": selection_state.max_rounds,
		"generation_timestamp": generation_start_time
	})

	var config_result = DataManager.get_balance_config("skill_system.selection_rules.skills_per_round")
	var skills_per_round = config_result.get("value", 3) if config_result.has("value") else 3

	LogManager.debug("SkillSelectionManager", "獲取配置參數", {
		"skills_per_round": skills_per_round,
		"config_source": "DataManager.get_balance_config"
	})

	# 獲取隨機技能選項
	LogManager.debug("SkillSelectionManager", "請求隨機技能數據")
	selection_state.available_skills = DataManager.get_random_skills(skills_per_round)

	if selection_state.available_skills.is_empty():
		LogManager.error("SkillSelectionManager", "技能選項生成失敗", {
			"skills_per_round": skills_per_round,
			"data_manager_response": "empty_array",
			"generation_failed": true,
			"current_round": selection_state.current_round + 1
		})
		return

	var generation_duration = Time.get_unix_time_from_system() - generation_start_time

	# 驗證生成的技能數據
	var skill_validation_results = []
	for skill in selection_state.available_skills:
		var is_valid = _validate_skill_data(skill)
		skill_validation_results.append({
			"skill_id": skill.get("id", "unknown"),
			"skill_name": skill.get("name", "unknown"),
			"is_valid": is_valid
		})

	LogManager.info("SkillSelectionManager", "技能選項生成完成", {
		"generation_duration": generation_duration,
		"round": selection_state.current_round + 1,
		"skills_generated": selection_state.available_skills.size(),
		"requested_count": skills_per_round,
		"skill_names": selection_state.available_skills.map(func(s): return s.get("name", "unknown")),
		"skill_validation": skill_validation_results,
		"generation_successful": true
	})

# 選擇技能
func select_skill(skill_id: String) -> bool:
	var selection_start_time = Time.get_unix_time_from_system()

	LogManager.info("SkillSelectionManager", "技能選擇請求", {
		"skill_id": skill_id,
		"selection_timestamp": selection_start_time,
		"current_round": selection_state.current_round + 1,
		"remaining_stars": selection_state.remaining_stars,
		"manager_active": _is_active
	})

	if not _is_active:
		LogManager.error("SkillSelectionManager", "技能選擇未激活，拒絕選擇", {
			"skill_id": skill_id,
			"manager_active": _is_active,
			"selection_blocked": true
		})
		return false

	# 驗證技能是否在可選列表中
	LogManager.debug("SkillSelectionManager", "搜尋可選技能", {
		"skill_id": skill_id,
		"available_count": selection_state.available_skills.size()
	})

	var skill_data = _find_skill_in_available(skill_id)
	if skill_data.is_empty():
		LogManager.error("SkillSelectionManager", "技能不在可選列表中", {
			"skill_id": skill_id,
			"available_skills": selection_state.available_skills.map(func(s): return s.get("id", "unknown")),
			"selection_failed": true
		})
		return false

	LogManager.debug("SkillSelectionManager", "技能找到，驗證數據", {
		"skill_name": skill_data.get("name", "unknown"),
		"skill_star_cost": skill_data.get("star_cost", 1)
	})

	# 驗證技能數據
	if not _validate_skill_data(skill_data):
		LogManager.error("SkillSelectionManager", "技能數據驗證失敗", {
			"skill_id": skill_id,
			"skill_data": skill_data,
			"validation_failed": true
		})
		return false

	# 檢查星星是否足夠
	var star_cost = skill_data.get("star_cost", 1)
	LogManager.debug("SkillSelectionManager", "檢查星星数量", {
		"required_stars": star_cost,
		"available_stars": selection_state.remaining_stars,
		"can_afford": star_cost <= selection_state.remaining_stars
	})

	if star_cost > selection_state.remaining_stars:
		LogManager.warn("SkillSelectionManager", "星星不足，無法選擇技能", {
			"skill_id": skill_id,
			"skill_name": skill_data.get("name", "unknown"),
			"required": star_cost,
			"available": selection_state.remaining_stars,
			"deficit": star_cost - selection_state.remaining_stars
		})
		return false

	# 檢查是否已經選擇過
	LogManager.debug("SkillSelectionManager", "檢查技能重複狀態")
	if _skill_already_selected(skill_id):
		LogManager.warn("SkillSelectionManager", "技能已經選擇，無法重複選擇", {
			"skill_id": skill_id,
			"skill_name": skill_data.get("name", "unknown"),
			"selected_skills_count": selection_state.selected_skills.size(),
			"duplicate_selection": true
		})
		return false

	LogManager.info("SkillSelectionManager", "技能選擇驗證通過，執行選擇", {
		"skill_id": skill_id,
		"skill_name": skill_data.get("name", "unknown"),
		"star_cost": star_cost,
		"validation_passed": true
	})

	# 執行選擇
	_execute_skill_selection(skill_data)

	var selection_duration = Time.get_unix_time_from_system() - selection_start_time

	LogManager.info("SkillSelectionManager", "技能選擇完成", {
		"skill_id": skill_id,
		"selection_duration": selection_duration,
		"selection_successful": true
	})

	return true

# 跳過當前回合
func skip_current_round() -> void:
	if not _is_active:
		LogManager.warn("SkillSelectionManager", "技能選擇未激活，無法跳過")
		return

	LogManager.info("SkillSelectionManager", "跳過技能選擇", {
		"round": selection_state.current_round + 1
	})

	# 進入下一回合
	advance_to_next_round()

# 完成技能選擇
func finish_skill_selection() -> Dictionary:
	var finish_start_time = Time.get_unix_time_from_system()

	LogManager.info("SkillSelectionManager", "開始完成技能選擇流程", {
		"finish_timestamp": finish_start_time,
		"manager_active": _is_active,
		"current_round": selection_state.current_round,
		"selected_skills_count": selection_state.selected_skills.size(),
		"remaining_stars": selection_state.remaining_stars
	})

	if not _is_active:
		LogManager.warn("SkillSelectionManager", "技能選擇未激活，無法完成", {
			"manager_active": _is_active,
			"finish_blocked": true
		})
		return {}

	# 將剩餘星星轉換為屬性點
	var converted_attributes = {}
	if selection_state.remaining_stars > 0:
		LogManager.info("SkillSelectionManager", "開始轉換剩餘星星", {
			"remaining_stars": selection_state.remaining_stars,
			"conversion_needed": true
		})
		converted_attributes = _convert_stars_to_attributes(selection_state.remaining_stars)
	else:
		LogManager.debug("SkillSelectionManager", "無剩餘星星，跳過轉換", {
			"remaining_stars": 0,
			"conversion_skipped": true
		})

	# 生成最終結果
	var final_result = {
		"selected_skills": selection_state.selected_skills.duplicate(),
		"remaining_stars": selection_state.remaining_stars,
		"converted_attributes": converted_attributes,
		"total_rounds_completed": selection_state.current_round
	}

	LogManager.info("SkillSelectionManager", "技能選擇最終結果生成", {
		"total_skills_selected": final_result.selected_skills.size(),
		"skill_names": final_result.selected_skills.map(func(s): return s.get("name", "unknown")),
		"stars_converted": selection_state.remaining_stars,
		"attribute_gains": converted_attributes,
		"rounds_completed": final_result.total_rounds_completed
	})

	# 發送完成事件
	LogManager.debug("SkillSelectionManager", "發送技能選擇完成事件")
	EventBus.skill_selection_completed.emit(
		final_result.selected_skills,
		final_result.remaining_stars
	)

	LogManager.info("SkillSelectionManager", "技能選擇完成事件已發送", {
		"event": "skill_selection_completed",
		"skills_broadcast": final_result.selected_skills.size(),
		"stars_broadcast": final_result.remaining_stars
	})

	# 如果有剩餘星星轉換
	if not converted_attributes.is_empty():
		LogManager.debug("SkillSelectionManager", "發送星星轉換事件")
		EventBus.star_converted_to_attributes.emit(
			selection_state.remaining_stars,
			converted_attributes
		)
		LogManager.info("SkillSelectionManager", "星星轉換事件已發送", {
			"event": "star_converted_to_attributes",
			"stars_converted": selection_state.remaining_stars,
			"attributes_gained": converted_attributes
		})

	# 重置狀態
	LogManager.debug("SkillSelectionManager", "重置管理器狀態")
	_is_active = false

	var finish_duration = Time.get_unix_time_from_system() - finish_start_time

	LogManager.info("SkillSelectionManager", "技能選擇流程完成", {
		"finish_duration": finish_duration,
		"manager_deactivated": not _is_active,
		"final_summary": final_result,
		"process_successful": true
	})

	return final_result

# === 私有方法 ===

# 執行技能選擇
func _execute_skill_selection(skill_data: Dictionary) -> void:
	var execution_start_time = Time.get_unix_time_from_system()
	var star_cost = skill_data.get("star_cost", 1)

	LogManager.info("SkillSelectionManager", "開始執行技能選擇", {
		"skill_name": skill_data.get("name", "unknown"),
		"skill_id": skill_data.get("id", "unknown"),
		"star_cost": star_cost,
		"execution_timestamp": execution_start_time,
		"before_remaining_stars": selection_state.remaining_stars
	})

	# 扣除星星
	var old_stars = selection_state.remaining_stars
	selection_state.remaining_stars -= star_cost

	LogManager.debug("SkillSelectionManager", "星星扣除完成", {
		"old_stars": old_stars,
		"star_cost": star_cost,
		"new_remaining_stars": selection_state.remaining_stars
	})

	# 添加到已選技能
	var old_selected_count = selection_state.selected_skills.size()
	selection_state.selected_skills.append(skill_data.duplicate())

	LogManager.debug("SkillSelectionManager", "技能添加到已選列表", {
		"old_selected_count": old_selected_count,
		"new_selected_count": selection_state.selected_skills.size(),
		"skill_added": skill_data.get("name", "unknown")
	})

	# 應用技能效果到玩家屬性
	LogManager.debug("SkillSelectionManager", "應用技能效果")
	_apply_skill_effects(skill_data)

	var execution_duration = Time.get_unix_time_from_system() - execution_start_time

	LogManager.info("SkillSelectionManager", "技能選擇執行成功", {
		"skill_name": skill_data.get("name", "unknown"),
		"skill_id": skill_data.get("id", "unknown"),
		"star_cost": star_cost,
		"remaining_stars": selection_state.remaining_stars,
		"total_selected_skills": selection_state.selected_skills.size(),
		"execution_duration": execution_duration,
		"effects_applied": skill_data.get("effects", {}).size() > 0
	})

	# 發送技能選擇事件
	LogManager.debug("SkillSelectionManager", "發送技能選擇事件")
	EventBus.skill_selected.emit(skill_data, selection_state.remaining_stars)

	LogManager.info("SkillSelectionManager", "技能選擇事件已發送", {
		"event": "skill_selected",
		"remaining_stars_broadcast": selection_state.remaining_stars,
		"note": "等待UI層控制回合推進"
	})

	# 移除自動推進 - 由UI層統一控制推進時機

# 進入下一回合（返回推進結果）
func advance_to_next_round() -> Dictionary:
	var advance_start_time = Time.get_unix_time_from_system()
	var old_round = selection_state.current_round

	# 狀態檢查：防止重複推進
	if selection_state.current_round >= selection_state.max_rounds:
		LogManager.warn("SkillSelectionManager", "嘗試推進已完成的技能選擇", {
			"current_round": selection_state.current_round,
			"max_rounds": selection_state.max_rounds
		})
		return {"success": false, "reason": "already_completed", "current_round": selection_state.current_round}

	LogManager.info("SkillSelectionManager", "進入下一回合", {
		"from_round": old_round,
		"to_round": old_round + 1,
		"advance_timestamp": advance_start_time,
		"max_rounds": selection_state.max_rounds
	})

	selection_state.current_round += 1

	LogManager.debug("SkillSelectionManager", "回合數更新", {
		"old_round": old_round + 1,
		"new_round": selection_state.current_round + 1,
		"rounds_remaining": selection_state.max_rounds - selection_state.current_round
	})

	# 檢查是否完成所有回合
	var is_complete = selection_state.current_round >= selection_state.max_rounds

	LogManager.info("SkillSelectionManager", "檢查選擇完成狀態", {
		"current_round": selection_state.current_round + 1,
		"max_rounds": selection_state.max_rounds,
		"is_complete": is_complete,
		"selected_skills_count": selection_state.selected_skills.size(),
		"remaining_stars": selection_state.remaining_stars
	})

	if is_complete:
		LogManager.info("SkillSelectionManager", "所有回合完成，結束技能選擇", {
			"final_round": selection_state.current_round,
			"total_skills_selected": selection_state.selected_skills.size()
		})
		finish_skill_selection()
		return {"success": true, "completed": true, "current_round": selection_state.current_round}
	else:
		LogManager.info("SkillSelectionManager", "進入下一輪技能選擇", {
			"current_round": selection_state.current_round,
			"rounds_remaining": selection_state.max_rounds - selection_state.current_round
		})
		# 生成下一輪技能選項
		generate_skill_options()

		# 移除自動事件觸發 - 由UI層控制
		# EventBus.skill_selection_started.emit()
		LogManager.info("SkillSelectionManager", "下一輪準備完成，等待UI層觸發事件", {
			"round": selection_state.current_round,
			"skills_generated": selection_state.available_skills.size(),
			"note": "UI層需要調用 EventBus.skill_selection_started.emit()"
		})

	var advance_duration = Time.get_unix_time_from_system() - advance_start_time

	LogManager.debug("SkillSelectionManager", "回合推進完成", {
		"advance_duration": advance_duration,
		"current_round": selection_state.current_round,
		"success": true
	})

	return {"success": true, "completed": false, "current_round": selection_state.current_round}

# 應用技能效果到玩家屬性
func _apply_skill_effects(skill_data: Dictionary) -> void:
	var effects = skill_data.get("effects", {})

	for attribute_name in effects:
		if _player_data.has("attributes") and _player_data.attributes.has(attribute_name):
			var old_value = _player_data.attributes[attribute_name]
			var bonus = effects[attribute_name]
			_player_data.attributes[attribute_name] += bonus

			LogManager.debug("SkillSelectionManager", "技能效果應用", {
				"skill": skill_data.name,
				"attribute": attribute_name,
				"old_value": old_value,
				"bonus": bonus,
				"new_value": _player_data.attributes[attribute_name]
			})

# 將星星轉換為屬性點
func _convert_stars_to_attributes(stars: int) -> Dictionary:
	if stars <= 0:
		return {}

	var balance_config = DataManager.get_balance_config("player_progression")
	var conversion_rate = balance_config.get("star_conversion_rate.stars_to_attributes", 10)
	var total_points = stars * conversion_rate

	# 可分配的屬性（不包括天命）
	var attributes = ["武力", "智力", "統治", "政治", "魅力"]
	var gained_attributes: Dictionary = {}

	# 隨機分配屬性點
	for i in range(total_points):
		var random_attr = attributes[randi() % attributes.size()]
		gained_attributes[random_attr] = gained_attributes.get(random_attr, 0) + 1

		# 應用到玩家屬性
		if _player_data.has("attributes") and _player_data.attributes.has(random_attr):
			_player_data.attributes[random_attr] += 1

	LogManager.info("SkillSelectionManager", "星星轉換完成", {
		"stars_converted": stars,
		"total_points": total_points,
		"attribute_gains": gained_attributes
	})

	return gained_attributes

# 在可選技能中查找指定技能
func _find_skill_in_available(skill_id: String) -> Dictionary:
	for skill in selection_state.available_skills:
		if skill.get("id", "") == skill_id:
			return skill
	return {}

# 檢查技能是否已經選擇
func _skill_already_selected(skill_id: String) -> bool:
	for skill in selection_state.selected_skills:
		if skill.get("id", "") == skill_id:
			return true
	return false

# 驗證技能數據
func _validate_skill_data(skill: Dictionary) -> bool:
	# 檢查必要欄位
	if not skill.has("id") or skill["id"].is_empty():
		return false

	if not skill.has("name") or skill["name"].is_empty():
		return false

	if not skill.has("star_cost"):
		return false

	var star_cost = skill["star_cost"]
	if not (star_cost is int or star_cost is float) or star_cost < 1 or star_cost > 3:
		return false

	return true

# === 事件處理器 ===

func _on_skill_selection_started() -> void:
	LogManager.info("SkillSelectionManager", "收到技能選擇開始事件", {
		"event": "skill_selection_started",
		"current_active_state": _is_active,
		"current_round": selection_state.current_round + 1,
		"event_timestamp": Time.get_unix_time_from_system()
	})

func _on_game_state_changed(new_state: int, old_state: int) -> void:
	var state_names = {
		GameStateManager.GameState.MENU: "主選單",
		GameStateManager.GameState.SKILL_SELECTION: "技能選擇",
		GameStateManager.GameState.GAME_RUNNING: "主遊戲",
		GameStateManager.GameState.BATTLE: "戰鬥",
		GameStateManager.GameState.PAUSED: "暫停",
		GameStateManager.GameState.GAME_OVER: "遊戲結束"
	}

	LogManager.info("SkillSelectionManager", "遊戲狀態變化事件", {
		"from_state": state_names.get(old_state, "未知狀態"),
		"to_state": state_names.get(new_state, "未知狀態"),
		"from_state_id": old_state,
		"to_state_id": new_state,
		"manager_active": _is_active,
		"transition_timestamp": Time.get_unix_time_from_system()
	})

	# 如果離開技能選擇狀態，確保清理
	if old_state == GameStateManager.GameState.SKILL_SELECTION:
		if _is_active:
			LogManager.warn("SkillSelectionManager", "檢測到離開技能選擇狀態，強制結束選擇", {
				"forced_cleanup": true,
				"current_round": selection_state.current_round + 1,
				"selected_skills": selection_state.selected_skills.size(),
				"remaining_stars": selection_state.remaining_stars,
				"new_state": state_names.get(new_state, "未知狀態")
			})
			_is_active = false
		else:
			LogManager.debug("SkillSelectionManager", "離開技能選擇狀態，管理器已非激活狀態", {
				"manager_was_active": false,
				"no_cleanup_needed": true
			})

# === 查詢API ===

# 獲取當前選擇狀態
func get_selection_state() -> Dictionary:
	return selection_state.duplicate()

# 獲取當前回合
func get_current_round() -> int:
	return selection_state.current_round

# 獲取剩餘星星
func get_remaining_stars() -> int:
	return selection_state.remaining_stars

# 獲取已選技能
func get_selected_skills() -> Array:
	return selection_state.selected_skills.duplicate()

# 獲取可選技能
func get_available_skills() -> Array:
	return selection_state.available_skills.duplicate()

# 檢查是否處於激活狀態
func is_active() -> bool:
	return _is_active

# 檢查是否完成
func is_completed() -> bool:
	return selection_state.current_round >= selection_state.max_rounds

# 獲取進度百分比
func get_progress_percentage() -> float:
	if selection_state.max_rounds <= 0:
		return 0.0
	return float(selection_state.current_round) / float(selection_state.max_rounds)

# 預覽技能效果（不實際應用）
func preview_skill_effects(skill_id: String) -> Dictionary:
	var skill_data = DataManager.get_skill_by_id(skill_id)
	if skill_data.is_empty():
		return {}

	var preview = {
		"skill": skill_data,
		"star_cost": skill_data.get("star_cost", 1),
		"can_afford": skill_data.get("star_cost", 1) <= selection_state.remaining_stars,
		"effects": skill_data.get("effects", {}),
		"already_selected": _skill_already_selected(skill_id)
	}

	return preview

# 獲取統計信息
func get_statistics() -> Dictionary:
	var total_star_cost = 0
	for skill in selection_state.selected_skills:
		total_star_cost += skill.get("star_cost", 0)

	return {
		"total_skills_selected": selection_state.selected_skills.size(),
		"total_stars_spent": total_star_cost,
		"remaining_stars": selection_state.remaining_stars,
		"rounds_completed": selection_state.current_round,
		"rounds_remaining": selection_state.max_rounds - selection_state.current_round,
		"progress_percentage": get_progress_percentage()
	}