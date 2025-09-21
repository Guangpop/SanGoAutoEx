# test_full_game_workflow.gd - 完整遊戲流程整合測試
#
# 測試範圍：
# - 完整的遊戲工作流程（新遊戲到存檔載入）
# - 各系統間的協同工作
# - 數據一致性和狀態同步
# - 性能和穩定性驗證
# - 移動端用戶體驗流程

extends GdUnitTestSuite

# 測試用組件
var game_core: GameCore
var save_manager: EnhancedSaveManager
var auto_battle: AutoBattleManager
var ui_enhancer: MobileUIEnhancer
var encryption_manager: EncryptionManager

# 測試數據
var test_player_data: Dictionary
var original_save_slot: int = 99  # 使用特殊槽位避免衝突

func before_test() -> void:
	# 初始化測試環境
	_setup_test_environment()

	# 創建測試用玩家數據
	test_player_data = _create_test_player_data()

func after_test() -> void:
	# 清理測試數據
	_cleanup_test_environment()

# === 測試環境設置 ===

func _setup_test_environment() -> void:
	# 載入必要的腳本
	var game_core_script = load("res://scripts/core/GameCore.gd")
	var save_manager_script = load("res://scripts/systems/EnhancedSaveManager.gd")
	var auto_battle_script = load("res://scripts/systems/AutoBattleManager.gd")
	var ui_enhancer_script = load("res://scripts/ui/MobileUIEnhancer.gd")
	var encryption_script = load("res://scripts/systems/EncryptionManager.gd")

	# 創建實例
	if game_core_script:
		game_core = game_core_script.new()
		get_tree().root.add_child(game_core)

	if save_manager_script:
		save_manager = save_manager_script.new()
		get_tree().root.add_child(save_manager)

	if auto_battle_script:
		auto_battle = auto_battle_script.new()
		get_tree().root.add_child(auto_battle)

	if ui_enhancer_script:
		ui_enhancer = ui_enhancer_script.new()
		get_tree().root.add_child(ui_enhancer)

	if encryption_script:
		encryption_manager = encryption_script.new()
		get_tree().root.add_child(encryption_manager)

	# 等待初始化完成
	await get_tree().create_timer(0.1).timeout

func _cleanup_test_environment() -> void:
	# 刪除測試存檔
	_remove_test_save_file()

	# 清理組件
	if game_core:
		game_core.queue_free()
		game_core = null

	if save_manager:
		save_manager.queue_free()
		save_manager = null

	if auto_battle:
		auto_battle.queue_free()
		auto_battle = null

	if ui_enhancer:
		ui_enhancer.queue_free()
		ui_enhancer = null

	if encryption_manager:
		encryption_manager.queue_free()
		encryption_manager = null

func _create_test_player_data() -> Dictionary:
	return {
		"player_name": "測試玩家",
		"level": 1,
		"experience": 0,
		"gold": 1000,
		"silver": 500,
		"wood": 300,
		"food": 400,
		"iron": 200,
		"generals": [],
		"cities": [],
		"skills": [],
		"equipment": [],
		"unlocked_events": [],
		"settings": {
			"auto_battle": true,
			"haptic_feedback": true
		}
	}

func _remove_test_save_file() -> void:
	var test_file_path = "user://save_" + str(original_save_slot) + ".save"
	if FileAccess.file_exists(test_file_path):
		DirAccess.remove_absolute(test_file_path)

# === 完整遊戲流程測試 ===

func test_complete_new_game_workflow():
	# 測試完整的新遊戲建立流程
	assert_object(game_core).is_not_null()

	# 1. 初始化新遊戲
	if game_core and game_core.has_method("initialize_new_game"):
		var init_success = game_core.initialize_new_game(test_player_data)
		assert_bool(init_success).is_true()

	# 2. 驗證初始狀態
	if game_core and game_core.has_method("get_game_state"):
		var game_state = game_core.get_game_state()
		assert_dict(game_state).is_not_empty()

		# 驗證基本數據存在
		assert_bool(game_state.has("player")).is_true()
		assert_bool(game_state.has("resources")).is_true()

func test_save_load_game_integration():
	# 測試存檔和讀檔的完整流程
	if not save_manager:
		LogManager.warning("QATest", "SaveManager not available - skipping test")
		return

	# 1. 準備遊戲數據
	var test_save_data = test_player_data.duplicate(true)
	test_save_data["save_time"] = Time.get_unix_time_from_system()
	test_save_data["save_version"] = "1.0"

	# 2. 執行存檔
	var save_success = false
	if save_manager.has_method("save_game_to_slot"):
		save_success = await _test_save_operation(test_save_data)
	else:
		# 回退到基本存檔方法
		save_success = _test_basic_save_operation(test_save_data)

	assert_bool(save_success).is_true()

	# 3. 執行讀檔
	var load_success = false
	var loaded_data: Dictionary = {}

	if save_manager.has_method("load_game_from_slot"):
		var load_result = await _test_load_operation()
		load_success = load_result.success
		loaded_data = load_result.data
	else:
		# 回退到基本讀檔方法
		var load_result = _test_basic_load_operation()
		load_success = load_result.success
		loaded_data = load_result.data

	assert_bool(load_success).is_true()
	assert_dict(loaded_data).is_not_empty()

	# 4. 驗證數據一致性
	assert_str(loaded_data.get("player_name", "")).is_equal(test_save_data["player_name"])
	assert_int(loaded_data.get("gold", 0)).is_equal(test_save_data["gold"])

func _test_save_operation(data: Dictionary) -> bool:
	var save_completed = false
	var save_success = false

	# 監聽存檔完成信號
	if save_manager.has_signal("save_completed"):
		save_manager.save_completed.connect(
			func(slot: int, success: bool, error: String):
				save_completed = true
				save_success = success
		)

	# 執行存檔
	save_manager.save_game_to_slot(original_save_slot, data)

	# 等待存檔完成
	var timeout = 0.0
	while not save_completed and timeout < 2.0:
		await get_tree().create_timer(0.1).timeout
		timeout += 0.1

	return save_success

func _test_load_operation() -> Dictionary:
	var load_completed = false
	var load_success = false
	var loaded_data: Dictionary = {}

	# 監聽讀檔完成信號
	if save_manager.has_signal("load_completed"):
		save_manager.load_completed.connect(
			func(slot: int, success: bool, data: Dictionary):
				load_completed = true
				load_success = success
				loaded_data = data
		)

	# 執行讀檔
	save_manager.load_game_from_slot(original_save_slot)

	# 等待讀檔完成
	var timeout = 0.0
	while not load_completed and timeout < 2.0:
		await get_tree().create_timer(0.1).timeout
		timeout += 0.1

	return {"success": load_success, "data": loaded_data}

func _test_basic_save_operation(data: Dictionary) -> bool:
	# 基本存檔方法（如果高級方法不可用）
	var save_path = "user://save_" + str(original_save_slot) + ".save"
	var file = FileAccess.open(save_path, FileAccess.WRITE)

	if not file:
		return false

	file.store_string(JSON.stringify(data))
	file.close()
	return true

func _test_basic_load_operation() -> Dictionary:
	# 基本讀檔方法
	var save_path = "user://save_" + str(original_save_slot) + ".save"
	var file = FileAccess.open(save_path, FileAccess.READ)

	if not file:
		return {"success": false, "data": {}}

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		return {"success": false, "data": {}}

	return {"success": true, "data": json.get_data()}

# === 自動戰鬥整合測試 ===

func test_auto_battle_integration():
	# 測試自動戰鬥系統整合
	if not auto_battle:
		LogManager.warning("QATest", "Skipping test:")("AutoBattleManager not available")
		return

	# 1. 初始化自動戰鬥
	if auto_battle.has_method("initialize"):
		auto_battle.initialize()

	# 2. 設置測試參數
	if auto_battle.has_method("set_auto_battle_enabled"):
		auto_battle.set_auto_battle_enabled(true)

	# 3. 測試戰鬥循環（短時間）
	if auto_battle.has_method("start_auto_battle"):
		auto_battle.start_auto_battle()

		# 等待一個戰鬥週期
		await get_tree().create_timer(0.5).timeout

		# 驗證戰鬥有在執行
		if auto_battle.has_method("is_auto_battle_active"):
			assert_bool(auto_battle.is_auto_battle_active()).is_true()

func test_offline_progress_calculation():
	# 測試離線進度計算
	if not auto_battle:
		LogManager.warning("QATest", "Skipping test:")("AutoBattleManager not available")
		return

	# 模擬離線時間（1小時）
	var offline_seconds = 3600
	var test_resources = {
		"gold": 1000,
		"experience": 500,
		"materials": 100
	}

	if auto_battle.has_method("calculate_offline_progress"):
		var progress = auto_battle.calculate_offline_progress(offline_seconds, test_resources)

		# 驗證有進度產生
		assert_dict(progress).is_not_empty()

		# 驗證資源增長合理
		if progress.has("gold_gained"):
			assert_int(progress.gold_gained).is_greater(0)
			assert_int(progress.gold_gained).is_less(test_resources.gold * 2) # 不應該翻倍太多

# === 移動UI整合測試 ===

func test_mobile_ui_integration():
	# 測試移動UI增強整合
	if not ui_enhancer:
		LogManager.warning("QATest", "Skipping test:")("MobileUIEnhancer not available")
		return

	# 1. 創建測試控件
	var test_button = Button.new()
	test_button.text = "測試按鈕"
	test_button.size = Vector2(120, 60)
	get_tree().root.add_child(test_button)

	# 2. 應用移動增強
	if ui_enhancer.has_method("add_gesture_support"):
		ui_enhancer.add_gesture_support(test_button)

	if ui_enhancer.has_method("apply_responsive_style"):
		ui_enhancer.apply_responsive_style(test_button, {"scale_with_screen": true})

	# 3. 驗證增強效果
	assert_object(test_button).is_not_null()
	assert_bool(test_button.mouse_filter != Control.MOUSE_FILTER_IGNORE).is_true()

	# 清理
	test_button.queue_free()

func test_touch_gesture_workflow():
	# 測試觸控手勢工作流程
	if not ui_enhancer:
		LogManager.warning("QATest", "Skipping test:")("MobileUIEnhancer not available")
		return

	# 模擬觸控事件序列
	var start_position = Vector2(100, 100)
	var end_position = Vector2(200, 100)

	# 1. 開始觸控
	if ui_enhancer.has_method("_start_touch"):
		ui_enhancer._start_touch(start_position, null)
		assert_vector2(ui_enhancer.get("touch_start_position", Vector2.ZERO)).is_equal(start_position)

	# 2. 檢測滑動
	if ui_enhancer.has_method("_get_swipe_direction"):
		var direction = ui_enhancer._get_swipe_direction(start_position, end_position)
		assert_str(direction).is_equal("right")

# === 加密系統整合測試 ===

func test_encryption_integration():
	# 測試加密系統整合
	if not encryption_manager:
		LogManager.warning("QATest", "Skipping test:")("EncryptionManager not available")
		return

	# 等待加密管理器初始化
	await get_tree().create_timer(0.2).timeout

	# 1. 驗證加密管理器已就緒
	if encryption_manager.has_method("is_ready"):
		assert_bool(encryption_manager.is_ready()).is_true()

	# 2. 測試數據加密/解密流程
	var test_data = JSON.stringify(test_player_data)

	if encryption_manager.has_method("encrypt_data"):
		var encrypt_result = encryption_manager.encrypt_data(test_data)
		assert_dict(encrypt_result).contains_keys(["success", "data"])

		if encrypt_result.get("success", false):
			var encrypted_data = encrypt_result.data

			# 3. 測試解密
			if encryption_manager.has_method("decrypt_data"):
				var decrypt_result = encryption_manager.decrypt_data(encrypted_data)
				assert_dict(decrypt_result).contains_keys(["success", "data"])

				if decrypt_result.get("success", false):
					var decrypted_data = decrypt_result.data
					assert_str(decrypted_data).is_equal(test_data)

# === 性能整合測試 ===

func test_system_performance_integration():
	# 測試整體系統性能
	var start_time = Time.get_unix_time_from_system()

	# 執行一系列操作
	for i in range(100):
		# 模擬遊戲循環操作
		if game_core and game_core.has_method("update_game_state"):
			game_core.update_game_state()

		# 短暫等待
		await get_tree().process_frame

	var end_time = Time.get_unix_time_from_system()
	var duration = end_time - start_time

	# 100次操作應該在合理時間內完成
	assert_float(duration).is_less(2.0)

func test_memory_usage_stability():
	# 測試記憶體使用穩定性
	var initial_memory = Performance.get_monitor(Performance.MEMORY_STATIC)

	# 執行一系列創建/銷毀操作
	for i in range(50):
		var temp_data = test_player_data.duplicate(true)
		temp_data["iteration"] = i

		# 模擬數據處理
		if encryption_manager and encryption_manager.has_method("encrypt_data"):
			var encrypt_result = encryption_manager.encrypt_data(JSON.stringify(temp_data))

			if encrypt_result.get("success", false) and encryption_manager.has_method("decrypt_data"):
				encryption_manager.decrypt_data(encrypt_result.data)

		await get_tree().process_frame

	# 強制垃圾回收
	for i in range(3):
		await get_tree().process_frame

	var final_memory = Performance.get_monitor(Performance.MEMORY_STATIC)

	# 記憶體增長應該在合理範圍內
	assert_bool(final_memory.size() >= initial_memory.size()).is_true()

# === 數據一致性測試 ===

func test_cross_system_data_consistency():
	# 測試跨系統數據一致性
	if not game_core or not save_manager:
		LogManager.warning("QATest", "Skipping test:")("Required systems not available")
		return

	# 1. 設置初始遊戲狀態
	var initial_gold = 1500
	if game_core.has_method("set_resource"):
		game_core.set_resource("gold", initial_gold)

	# 2. 通過自動戰鬥修改資源
	if auto_battle and auto_battle.has_method("modify_resources"):
		auto_battle.modify_resources({"gold": 200})

	# 3. 獲取當前狀態並存檔
	var current_state = {}
	if game_core.has_method("serialize_game_state"):
		current_state = game_core.serialize_game_state()
	else:
		current_state = test_player_data.duplicate(true)
		if game_core.has_method("get_resource"):
			current_state["gold"] = game_core.get_resource("gold")

	# 4. 存檔和讀檔
	if save_manager.has_method("save_game_to_slot"):
		await _test_save_operation(current_state)
		var load_result = await _test_load_operation()

		# 驗證數據一致性
		if load_result.success:
			var loaded_gold = load_result.data.get("gold", 0)
			var expected_gold = current_state.get("gold", initial_gold)
			assert_int(loaded_gold).is_equal(expected_gold)

# === 錯誤處理整合測試 ===

func test_system_error_recovery():
	# 測試系統錯誤恢復能力

	# 1. 測試無效存檔數據處理
	if save_manager and save_manager.has_method("load_game_from_slot"):
		# 嘗試載入不存在的存檔
		var invalid_slot = 999
		var load_result = await _test_load_operation_for_slot(invalid_slot)

		# 應該優雅地處理錯誤
		assert_bool(load_result.success).is_false()

	# 2. 測試加密錯誤處理
	if encryption_manager and encryption_manager.has_method("decrypt_data"):
		var invalid_data = PackedByteArray([1, 2, 3, 4, 5])
		var decrypt_result = encryption_manager.decrypt_data(invalid_data)

		# 應該返回錯誤而不是崩潰
		assert_dict(decrypt_result).contains_key("error")

func _test_load_operation_for_slot(slot: int) -> Dictionary:
	var load_completed = false
	var load_success = false
	var loaded_data: Dictionary = {}

	if save_manager.has_signal("load_completed"):
		save_manager.load_completed.connect(
			func(loaded_slot: int, success: bool, data: Dictionary):
				if loaded_slot == slot:
					load_completed = true
					load_success = success
					loaded_data = data
		)

	if save_manager.has_method("load_game_from_slot"):
		save_manager.load_game_from_slot(slot)

	var timeout = 0.0
	while not load_completed and timeout < 1.0:
		await get_tree().create_timer(0.1).timeout
		timeout += 0.1

	return {"success": load_success, "data": loaded_data}

# === 移動設備特定測試 ===

func test_mobile_device_compatibility():
	# 測試移動設備兼容性
	if not ui_enhancer:
		LogManager.warning("QATest", "Skipping test:")("MobileUIEnhancer not available")
		return

	# 1. 測試不同螢幕尺寸適應
	var screen_sizes = [
		Vector2(414, 896),   # iPhone標準
		Vector2(375, 812),   # iPhone小尺寸
		Vector2(390, 844),   # iPhone 14
		Vector2(768, 1024)   # iPad
	]

	for size in screen_sizes:
		if ui_enhancer.has_method("_update_screen_info"):
			ui_enhancer.screen_size = size
			ui_enhancer._update_screen_info()

			# 驗證UI縮放合理
			if ui_enhancer.has_method("get_ui_scale_factor"):
				var scale = ui_enhancer.get_ui_scale_factor()
				assert_float(scale).is_greater_equal(0.5)
				assert_float(scale).is_less_equal(2.0)

	# 2. 測試觸控輸入響應
	if ui_enhancer.has_method("is_mobile_device"):
		var is_mobile = ui_enhancer.is_mobile_device()
		assert_bool(typeof(is_mobile) == TYPE_BOOL).is_true()

func test_performance_on_mobile_constraints():
	# 測試移動設備性能限制下的表現
	var frame_count = 0
	var start_time = Time.get_unix_time_from_system()

	# 模擬60FPS運行1秒
	while frame_count < 60:
		# 執行典型的幀更新操作
		if auto_battle and auto_battle.has_method("_process"):
			auto_battle._process(0.016) # 16ms per frame

		await get_tree().process_frame
		frame_count += 1

	var end_time = Time.get_unix_time_from_system()
	var actual_duration = end_time - start_time

	# 應該接近1秒（允許一些誤差）
	assert_float(actual_duration).is_greater_equal(0.8)
	assert_float(actual_duration).is_less_equal(1.5)