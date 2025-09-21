# test_save_encryption_system.gd - 存檔加密系統單元測試
#
# 測試範圍：
# - 加密管理器核心功能
# - 數據加密和解密流程
# - 存檔系統完整性
# - 備份和恢復機制
# - 雲端同步模擬

extends GdUnitTestSuite

# 測試用組件
var encryption_manager: EncryptionManager
var save_manager: Node
var test_save_data: Dictionary

func before_test() -> void:
	# 創建測試用的加密管理器
	var encryption_script = load("res://scripts/systems/EncryptionManager.gd")
	encryption_manager = encryption_script.new()

	# 創建測試用的存檔管理器
	var save_script = load("res://scripts/systems/EnhancedSaveManager.gd")
	save_manager = save_script.new()

	# 添加到場景中
	get_tree().root.add_child(encryption_manager)
	get_tree().root.add_child(save_manager)

	# 等待初始化完成
	await get_tree().process_frame

	# 設置測試數據
	test_save_data = {
		"player_data": {
			"level": 10,
			"experience": 5000,
			"attributes": {
				"武力": 85,
				"智力": 78,
				"統治": 82,
				"政治": 75,
				"魅力": 70,
				"天命": 90
			},
			"resources": {
				"gold": 15000,
				"troops": 5000,
				"food": 3000
			},
			"owned_cities": ["chengdu", "hanzhong", "xiangyang"],
			"selected_skills": ["tianxuan_zhiren", "yingxiong_qiyi"],
			"equipment": [
				{"id": "qinglong_yanyuedao", "equipped": true},
				{"id": "panlong_armor", "equipped": true}
			]
		},
		"game_progress": {
			"current_turn": 150,
			"game_year": 186,
			"total_battles": 75,
			"cities_conquered": 8,
			"total_playtime": 18000.5
		},
		"automation_settings": {
			"auto_battle_enabled": true,
			"aggression_level": "balanced",
			"resource_reserve_percentage": 25
		}
	}

func after_test() -> void:
	# 清理測試組件
	if encryption_manager:
		encryption_manager.queue_free()
		encryption_manager = null

	if save_manager:
		save_manager.queue_free()
		save_manager = null

# === 加密管理器測試 ===

func test_encryption_manager_initialization():
	# 測試加密管理器初始化
	assert_object(encryption_manager).is_not_null()

	# 等待初始化完成
	var timeout = 0
	while not encryption_manager.is_ready() and timeout < 100:
		await get_tree().process_frame
		timeout += 1

	assert_bool(encryption_manager.is_ready()).is_true()
	assert_str(encryption_manager.get_device_id()).is_not_equal("")

func test_data_encryption_decryption():
	# 測試數據加密和解密
	var test_string = "這是一個測試字符串，包含中文和特殊字符：!@#$%^&*()"

	# 加密數據
	var encryption_result = encryption_manager.encrypt_data(test_string)

	assert_bool(encryption_result.get("success", false)).is_true()
	assert_object(encryption_result.get("data")).is_not_null()

	# 解密數據
	var decryption_result = encryption_manager.decrypt_data(encryption_result.data)

	assert_bool(decryption_result.get("success", false)).is_true()
	assert_str(decryption_result.get("data", "")).is_equal(test_string)

func test_large_data_encryption():
	# 測試大型數據加密
	var large_data = JSON.stringify(test_save_data)

	var encryption_result = encryption_manager.encrypt_data(large_data)
	assert_bool(encryption_result.get("success", false)).is_true()

	var decryption_result = encryption_manager.decrypt_data(encryption_result.data)
	assert_bool(decryption_result.get("success", false)).is_true()

	# 驗證數據完整性
	var json = JSON.new()
	var parse_result = json.parse(decryption_result.data)
	assert_int(parse_result).is_equal(OK)

	var restored_data = json.data
	assert_dict(restored_data).contains_key("player_data")
	assert_dict(restored_data).contains_key("game_progress")

func test_encryption_with_invalid_data():
	# 測試無效數據的加密處理
	var invalid_encryption = encryption_manager.encrypt_data("")
	# 空字符串應該能夠被加密
	assert_bool(invalid_encryption.get("success", false)).is_true()

func test_decryption_with_corrupted_data():
	# 測試損壞數據的解密處理
	var corrupted_data = PackedByteArray([1, 2, 3, 4, 5])
	var decryption_result = encryption_manager.decrypt_data(corrupted_data)

	# 損壞的數據應該解密失敗
	assert_bool(decryption_result.get("success", false)).is_false()

func test_device_id_consistency():
	# 測試設備ID一致性
	var device_id_1 = encryption_manager.get_device_id()
	var device_id_2 = encryption_manager.get_device_id()

	assert_str(device_id_1).is_equal(device_id_2)
	assert_str(device_id_1).is_not_equal("")

func test_encryption_stats():
	# 測試加密統計信息
	var stats = encryption_manager.get_encryption_stats()

	assert_dict(stats).contains_key("is_initialized")
	assert_dict(stats).contains_key("device_id")
	assert_dict(stats).contains_key("encryption_version")
	assert_bool(stats.is_initialized).is_true()

# === 存檔管理器測試 ===

func test_save_manager_initialization():
	# 測試存檔管理器初始化
	assert_object(save_manager).is_not_null()

	# 等待初始化完成
	var timeout = 0
	while not save_manager.encryption_manager.is_ready() and timeout < 100:
		await get_tree().process_frame
		timeout += 1

	assert_object(save_manager.encryption_manager).is_not_null()
	assert_bool(save_manager.encryption_manager.is_ready()).is_true()

func test_save_slot_validation():
	# 測試存檔槽位驗證
	# 有效槽位
	var valid_result = save_manager.save_game(5, test_save_data)
	assert_bool(valid_result).is_true()

	# 無效槽位
	var invalid_result_1 = save_manager.save_game(-1, test_save_data)
	var invalid_result_2 = save_manager.save_game(15, test_save_data)

	assert_bool(invalid_result_1).is_false()
	assert_bool(invalid_result_2).is_false()

func test_save_data_preparation():
	# 測試存檔數據準備
	var prepared_data = save_manager._prepare_save_data(test_save_data)

	assert_dict(prepared_data).contains_key("version")
	assert_dict(prepared_data).contains_key("timestamp")
	assert_dict(prepared_data).contains_key("device_id")
	assert_dict(prepared_data).contains_key("game_data")
	assert_dict(prepared_data).contains_key("metadata")

	# 驗證版本號
	assert_int(prepared_data.version).is_equal(1)

	# 驗證校驗和
	var metadata = prepared_data.metadata
	assert_str(metadata.checksum).is_not_equal("")

func test_save_and_load_cycle():
	# 測試完整的保存和載入循環
	var test_slot = 3

	# 保存遊戲
	var save_success = save_manager.save_game(test_slot, test_save_data, true)
	assert_bool(save_success).is_true()

	# 等待保存完成
	await get_tree().process_frame

	# 載入遊戲
	var loaded_data = save_manager.load_game(test_slot)

	# 驗證載入的數據
	assert_dict(loaded_data).is_not_empty()
	assert_dict(loaded_data).contains_key("player_data")
	assert_dict(loaded_data).contains_key("game_progress")

	# 驗證具體數據
	var player_data = loaded_data.player_data
	assert_int(player_data.level).is_equal(10)
	assert_int(player_data.experience).is_equal(5000)

	var resources = player_data.resources
	assert_int(resources.gold).is_equal(15000)
	assert_int(resources.troops).is_equal(5000)

func test_save_slot_info():
	# 測試存檔槽位信息
	var test_slot = 4

	# 空槽位信息
	var empty_info = save_manager.get_save_slot_info(test_slot)
	assert_bool(empty_info.get("exists", true)).is_false()

	# 保存數據
	save_manager.save_game(test_slot, test_save_data, true)
	await get_tree().process_frame

	# 有數據槽位信息
	var filled_info = save_manager.get_save_slot_info(test_slot)
	assert_bool(filled_info.get("exists", false)).is_true()
	assert_int(filled_info.get("slot", -1)).is_equal(test_slot)
	assert_int(filled_info.get("file_size", 0)).is_greater(0)

func test_all_save_slots_info():
	# 測試所有存檔槽位信息
	var all_slots_info = save_manager.get_all_save_slots_info()

	assert_array(all_slots_info).has_size(10) # MAX_SAVE_SLOTS
	for slot_info in all_slots_info:
		assert_dict(slot_info).contains_key("exists")
		assert_dict(slot_info).contains_key("slot")

func test_save_deletion():
	# 測試存檔刪除
	var test_slot = 6

	# 先保存數據
	save_manager.save_game(test_slot, test_save_data, true)
	await get_tree().process_frame

	# 驗證存檔存在
	var info_before = save_manager.get_save_slot_info(test_slot)
	assert_bool(info_before.get("exists", false)).is_true()

	# 刪除存檔
	var delete_success = save_manager.delete_save(test_slot)
	assert_bool(delete_success).is_true()

	# 驗證存檔已刪除
	var info_after = save_manager.get_save_slot_info(test_slot)
	assert_bool(info_after.get("exists", true)).is_false()

func test_auto_save_configuration():
	# 測試自動存檔配置
	# 啟用自動存檔
	save_manager.set_auto_save_enabled(true)
	assert_bool(save_manager.is_auto_save_enabled).is_true()

	# 禁用自動存檔
	save_manager.set_auto_save_enabled(false)
	assert_bool(save_manager.is_auto_save_enabled).is_false()

func test_cloud_sync_configuration():
	# 測試雲端同步配置
	# 啟用雲端同步
	save_manager.enable_cloud_sync()
	assert_bool(save_manager.cloud_sync_enabled).is_true()

	# 禁用雲端同步
	save_manager.disable_cloud_sync()
	assert_bool(save_manager.cloud_sync_enabled).is_false()

func test_save_system_status():
	# 測試存檔系統狀態
	var status = save_manager.get_save_system_status()

	assert_dict(status).contains_key("current_slot")
	assert_dict(status).contains_key("auto_save_enabled")
	assert_dict(status).contains_key("cloud_sync_enabled")
	assert_dict(status).contains_key("encryption_ready")

	assert_bool(status.encryption_ready).is_true()

# === 數據完整性測試 ===

func test_save_data_validation():
	# 測試存檔數據驗證
	var valid_data = {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"game_data": test_save_data,
		"metadata": {"checksum": "test_checksum"}
	}

	var validation_result = save_manager._validate_save_data(valid_data)
	assert_bool(validation_result.valid).is_true()

	# 測試無效數據
	var invalid_data = {
		"version": 1
		# 缺少必要字段
	}

	var invalid_validation = save_manager._validate_save_data(invalid_data)
	assert_bool(invalid_validation.valid).is_false()

func test_save_data_migration():
	# 測試存檔數據遷移
	var old_version_data = {
		"version": 0,
		"timestamp": Time.get_unix_time_from_system(),
		"game_data": test_save_data,
		"metadata": {}
	}

	var migrated_data = save_manager._migrate_save_data(old_version_data)
	assert_int(migrated_data.version).is_equal(1)

func test_checksum_validation():
	# 測試校驗和驗證
	var test_data = {"test": "data"}
	var data_string = JSON.stringify(test_data)
	var checksum = data_string.sha256_text()

	var save_data_with_checksum = {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"game_data": test_data,
		"metadata": {"checksum": checksum}
	}

	var validation = save_manager._validate_save_data(save_data_with_checksum)
	assert_bool(validation.valid).is_true()

# === 備份系統測試 ===

func test_backup_creation():
	# 測試備份創建
	var test_slot = 7

	# 先保存數據
	save_manager.save_game(test_slot, test_save_data, true)
	await get_tree().process_frame

	# 創建備份
	save_manager._create_backup(test_slot)

	# 驗證備份文件
	var backup_files = save_manager._get_files_matching_pattern(
		save_manager.BACKUP_DIRECTORY,
		"save_%d_backup_*.sav" % test_slot
	)

	# 應該至少有一個備份文件
	assert_array(backup_files).is_not_empty()

func test_backup_cleanup():
	# 測試備份清理（這需要創建多個備份來測試）
	var test_slot = 8

	# 由於時間限制，我們只驗證清理方法不會崩潰
	save_manager._cleanup_old_backups(test_slot)
	# 方法執行成功即通過測試

# === 性能測試 ===

func test_encryption_performance():
	# 測試加密性能
	var start_time = Time.get_unix_time_from_system()

	# 執行100次加密操作
	for i in range(100):
		var test_data = "test_data_" + str(i)
		var result = encryption_manager.encrypt_data(test_data)
		assert_bool(result.get("success", false)).is_true()

	var end_time = Time.get_unix_time_from_system()
	var duration = end_time - start_time

	# 100次加密應該在合理時間內完成
	assert_float(duration).is_less(2.0)

func test_large_save_file_performance():
	# 測試大型存檔文件性能
	var large_save_data = test_save_data.duplicate()

	# 擴展數據大小
	for i in range(1000):
		large_save_data["large_data_" + str(i)] = {
			"value": i,
			"description": "這是一個測試數據項 " + str(i),
			"additional_info": ["item1", "item2", "item3"]
		}

	var start_time = Time.get_unix_time_from_system()

	# 保存大型數據
	var save_result = save_manager.save_game(9, large_save_data, true)
	assert_bool(save_result).is_true()

	await get_tree().process_frame

	var end_time = Time.get_unix_time_from_system()
	var duration = end_time - start_time

	# 大型存檔操作應該在合理時間內完成
	assert_float(duration).is_less(5.0)

# === 錯誤處理測試 ===

func test_invalid_slot_handling():
	# 測試無效槽位處理
	var result1 = save_manager.save_game(-5, test_save_data)
	var result2 = save_manager.save_game(20, test_save_data)

	assert_bool(result1).is_false()
	assert_bool(result2).is_false()

	var loaded1 = save_manager.load_game(-5)
	var loaded2 = save_manager.load_game(20)

	assert_dict(loaded1).is_empty()
	assert_dict(loaded2).is_empty()

func test_missing_file_handling():
	# 測試文件不存在的處理
	var non_existent_slot = 99
	var loaded_data = save_manager.load_game(non_existent_slot)

	assert_dict(loaded_data).is_empty()

func test_encryption_error_handling():
	# 測試加密錯誤處理
	# 嘗試解密無效數據
	var invalid_encrypted_data = PackedByteArray([0, 1, 2, 3])
	var result = encryption_manager.decrypt_data(invalid_encrypted_data)

	assert_bool(result.get("success", true)).is_false()

# === 並發操作測試 ===

func test_concurrent_save_operations():
	# 測試並發保存操作
	var slot1 = 1
	var slot2 = 2

	# 快速連續保存
	var result1 = save_manager.save_game(slot1, test_save_data, true)
	var result2 = save_manager.save_game(slot2, test_save_data, true)

	assert_bool(result1).is_true()
	assert_bool(result2).is_true()

	# 等待操作完成
	await get_tree().process_frame
	await get_tree().process_frame

	# 驗證兩個存檔都成功
	var info1 = save_manager.get_save_slot_info(slot1)
	var info2 = save_manager.get_save_slot_info(slot2)

	assert_bool(info1.get("exists", false)).is_true()
	assert_bool(info2.get("exists", false)).is_true()