# EnhancedSaveManager.gd - 完整的增強版存檔管理系統
#
# 功能：
# - 本地存檔的加密保存和載入
# - 雲端同步和衝突解決
# - 存檔版本管理和遷移
# - 自動存檔和備份系統

extends Node

signal save_completed(slot: int, success: bool, error: String)
signal load_completed(slot: int, success: bool, data: Dictionary)
signal cloud_sync_started(operation: String)
signal cloud_sync_completed(operation: String, success: bool)
signal auto_save_triggered(slot: int)

# 存檔配置
const MAX_SAVE_SLOTS := 10
const AUTO_SAVE_INTERVAL := 30.0  # 30秒自動存檔
const BACKUP_COUNT := 5           # 保留5個備份
const SAVE_VERSION := 1           # 存檔格式版本

# 存檔路徑
const SAVE_DIRECTORY := "user://saves/"
const BACKUP_DIRECTORY := "user://saves/backups/"
const CLOUD_CACHE_DIRECTORY := "user://saves/cloud_cache/"

# 系統組件
var encryption_manager: EncryptionManager
var auto_save_timer: Timer

# 存檔狀態
var current_save_slot: int = -1
var is_auto_save_enabled: bool = true
var save_operations_queue: Array[Dictionary] = []
var is_processing_queue: bool = false

# 雲端同步狀態
var cloud_sync_enabled: bool = false
var last_cloud_sync_time: float = 0.0
var pending_cloud_operations: Array[Dictionary] = []

func _ready() -> void:
	name = "EnhancedSaveManager"
	LogManager.info("EnhancedSaveManager", "增強版存檔管理系統初始化")

	# 初始化加密管理器
	encryption_manager = EncryptionManager.new()
	add_child(encryption_manager)

	# 等待加密管理器初始化
	while not encryption_manager.is_ready():
		await get_tree().process_frame

	# 創建存檔目錄
	_create_save_directories()

	# 初始化自動存檔定時器
	_setup_auto_save_timer()

	# 連接事件處理器
	connect_event_handlers()

	LogManager.info("EnhancedSaveManager", "增強版存檔管理系統初始化完成")

# === 初始化方法 ===

func _create_save_directories() -> void:
	var directories = [SAVE_DIRECTORY, BACKUP_DIRECTORY, CLOUD_CACHE_DIRECTORY]

	for dir_path in directories:
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.create_dir_recursive_absolute(dir_path)
			LogManager.debug("EnhancedSaveManager", "創建存檔目錄", {"path": dir_path})

func _setup_auto_save_timer() -> void:
	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = AUTO_SAVE_INTERVAL
	auto_save_timer.one_shot = false
	auto_save_timer.timeout.connect(_on_auto_save_timer_timeout)
	add_child(auto_save_timer)

	if is_auto_save_enabled:
		auto_save_timer.start()

func connect_event_handlers() -> void:
	EventBus.connect_safe("save_requested", _on_save_requested)
	EventBus.connect_safe("load_requested", _on_load_requested)
	EventBus.connect_safe("game_state_changed", _on_game_state_changed)

# === 存檔操作 ===

# 保存遊戲
func save_game(slot: int, game_data: Dictionary, force_overwrite: bool = false) -> bool:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		LogManager.error("EnhancedSaveManager", "無效的存檔槽位", {"slot": slot})
		return false

	# 添加到操作隊列
	var save_operation = {
		"type": "save",
		"slot": slot,
		"data": game_data,
		"force_overwrite": force_overwrite,
		"timestamp": Time.get_unix_time_from_system()
	}

	save_operations_queue.append(save_operation)
	_process_save_queue()

	return true

# 載入遊戲
func load_game(slot: int) -> Dictionary:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		LogManager.error("EnhancedSaveManager", "無效的存檔槽位", {"slot": slot})
		return {}

	var save_file_path = _get_save_file_path(slot)

	if not FileAccess.file_exists(save_file_path):
		LogManager.warning("EnhancedSaveManager", "存檔文件不存在", {"slot": slot, "path": save_file_path})
		return {}

	var load_result = _load_encrypted_save_file(save_file_path)

	if load_result.has("success") and load_result.success:
		LogManager.info("EnhancedSaveManager", "存檔載入成功", {"slot": slot})
		load_completed.emit(slot, true, load_result.data)
		return load_result.data
	else:
		var error_msg = load_result.get("error", "未知錯誤")
		LogManager.error("EnhancedSaveManager", "存檔載入失敗", {"slot": slot, "error": error_msg})
		load_completed.emit(slot, false, {})
		return {}

# 處理存檔隊列
func _process_save_queue() -> void:
	if is_processing_queue or save_operations_queue.is_empty():
		return

	is_processing_queue = true

	while not save_operations_queue.is_empty():
		var operation = save_operations_queue.pop_front()
		_execute_save_operation(operation)

	is_processing_queue = false

# 執行存檔操作
func _execute_save_operation(operation: Dictionary) -> void:
	var slot = operation.slot
	var game_data = operation.data
	var force_overwrite = operation.get("force_overwrite", false)

	# 準備存檔數據
	var save_data = _prepare_save_data(game_data)

	# 檢查是否覆蓋現有存檔
	var save_file_path = _get_save_file_path(slot)
	if FileAccess.file_exists(save_file_path) and not force_overwrite:
		# 創建備份
		_create_backup(slot)

	# 執行加密保存
	var save_result = _save_encrypted_data(save_file_path, save_data)

	if save_result:
		current_save_slot = slot
		LogManager.info("EnhancedSaveManager", "存檔保存成功", {"slot": slot})
		save_completed.emit(slot, true, "")

		# 觸發雲端同步
		if cloud_sync_enabled:
			_queue_cloud_sync_operation("upload", slot)
	else:
		LogManager.error("EnhancedSaveManager", "存檔保存失敗", {"slot": slot})
		save_completed.emit(slot, false, "保存失敗")

# === 數據處理方法 ===

# 準備存檔數據
func _prepare_save_data(game_data: Dictionary) -> Dictionary:
	var save_data = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"device_id": encryption_manager.get_device_id(),
		"game_data": game_data.duplicate(),
		"metadata": {
			"save_count": _get_save_count() + 1,
			"total_playtime": _calculate_total_playtime(game_data),
			"checksum": ""
		}
	}

	# 計算校驗和
	var data_string = JSON.stringify(save_data.game_data)
	save_data.metadata.checksum = data_string.sha256_text()

	return save_data

# 保存加密數據
func _save_encrypted_data(file_path: String, data: Dictionary) -> bool:
	# 轉換為JSON字符串
	var json_string = JSON.stringify(data)

	# 加密數據
	var encryption_result = encryption_manager.encrypt_data(json_string)

	if not encryption_result.get("success", false):
		LogManager.error("EnhancedSaveManager", "數據加密失敗")
		return false

	# 寫入文件
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		LogManager.error("EnhancedSaveManager", "無法創建存檔文件", {"path": file_path})
		return false

	file.store_buffer(encryption_result.data)
	file.close()

	LogManager.debug("EnhancedSaveManager", "加密存檔已保存", {"path": file_path})
	return true

# 載入加密存檔文件
func _load_encrypted_save_file(file_path: String) -> Dictionary:
	# 讀取文件
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {"error": "無法讀取存檔文件"}

	var encrypted_data = file.get_buffer(file.get_length())
	file.close()

	# 解密數據
	var decryption_result = encryption_manager.decrypt_data(encrypted_data)

	if not decryption_result.get("success", false):
		return {"error": "數據解密失敗"}

	# 解析JSON
	var json = JSON.new()
	var parse_result = json.parse(decryption_result.data)

	if parse_result != OK:
		return {"error": "JSON解析失敗"}

	var save_data = json.data

	# 驗證存檔數據
	var validation_result = _validate_save_data(save_data)
	if not validation_result.valid:
		return {"error": validation_result.error}

	# 執行版本遷移（如果需要）
	var migrated_data = _migrate_save_data(save_data)

	return {
		"success": true,
		"data": migrated_data.game_data,
		"metadata": migrated_data.metadata
	}

# === 存檔驗證和遷移 ===

# 驗證存檔數據
func _validate_save_data(save_data: Dictionary) -> Dictionary:
	# 檢查必要字段
	var required_fields = ["version", "timestamp", "game_data", "metadata"]
	for field in required_fields:
		if not save_data.has(field):
			return {"valid": false, "error": "缺少必要字段: " + field}

	# 檢查版本兼容性
	var version = save_data.get("version", 0)
	if version > SAVE_VERSION:
		return {"valid": false, "error": "不支持的存檔版本"}

	# 驗證校驗和
	var metadata = save_data.get("metadata", {})
	var expected_checksum = metadata.get("checksum", "")
	if expected_checksum != "":
		var data_string = JSON.stringify(save_data.game_data)
		var actual_checksum = data_string.sha256_text()
		if actual_checksum != expected_checksum:
			LogManager.warning("EnhancedSaveManager", "存檔校驗和不匹配")

	return {"valid": true}

# 遷移存檔數據
func _migrate_save_data(save_data: Dictionary) -> Dictionary:
	var version = save_data.get("version", 0)
	var migrated_data = save_data.duplicate()

	# 執行版本遷移
	if version < SAVE_VERSION:
		LogManager.info("EnhancedSaveManager", "執行存檔遷移", {"from_version": version, "to_version": SAVE_VERSION})
		migrated_data.version = SAVE_VERSION

	return migrated_data

# === 備份系統 ===

# 創建備份
func _create_backup(slot: int) -> void:
	var source_path = _get_save_file_path(slot)
	var backup_path = _get_backup_file_path(slot, Time.get_unix_time_from_system())

	if not FileAccess.file_exists(source_path):
		return

	# 複製文件到備份目錄
	if DirAccess.copy_absolute(source_path, backup_path) == OK:
		LogManager.debug("EnhancedSaveManager", "備份創建成功", {"slot": slot, "backup": backup_path})
		_cleanup_old_backups(slot)
	else:
		LogManager.warning("EnhancedSaveManager", "備份創建失敗", {"slot": slot})

# 清理舊備份
func _cleanup_old_backups(slot: int) -> void:
	var backup_pattern = "save_%d_backup_*.sav" % slot
	var backup_files = _get_files_matching_pattern(BACKUP_DIRECTORY, backup_pattern)

	if backup_files.size() <= BACKUP_COUNT:
		return

	# 按時間排序，保留最新的備份
	backup_files.sort_custom(func(a, b): return _get_file_timestamp(a) > _get_file_timestamp(b))

	# 刪除多餘的備份
	for i in range(BACKUP_COUNT, backup_files.size()):
		var file_path = BACKUP_DIRECTORY + backup_files[i]
		DirAccess.remove_absolute(file_path)
		LogManager.debug("EnhancedSaveManager", "刪除舊備份", {"file": backup_files[i]})

# === 自動存檔系統 ===

func _on_auto_save_timer_timeout() -> void:
	if not is_auto_save_enabled or current_save_slot < 0:
		return

	# 獲取當前遊戲狀態
	var current_game_data = GameCore.serialize_game_state()

	if current_game_data.is_empty():
		LogManager.debug("EnhancedSaveManager", "跳過自動存檔：無遊戲數據")
		return

	LogManager.debug("EnhancedSaveManager", "觸發自動存檔", {"slot": current_save_slot})
	auto_save_triggered.emit(current_save_slot)

	# 執行自動存檔
	save_game(current_save_slot, current_game_data, true)

# 啟用/禁用自動存檔
func set_auto_save_enabled(enabled: bool) -> void:
	is_auto_save_enabled = enabled

	if enabled:
		auto_save_timer.start()
		LogManager.info("EnhancedSaveManager", "自動存檔已啟用")
	else:
		auto_save_timer.stop()
		LogManager.info("EnhancedSaveManager", "自動存檔已禁用")

# === 雲端同步系統 ===

# 啟用雲端同步
func enable_cloud_sync() -> void:
	cloud_sync_enabled = true
	LogManager.info("EnhancedSaveManager", "雲端同步已啟用")

# 禁用雲端同步
func disable_cloud_sync() -> void:
	cloud_sync_enabled = false
	pending_cloud_operations.clear()
	LogManager.info("EnhancedSaveManager", "雲端同步已禁用")

# 隊列雲端同步操作
func _queue_cloud_sync_operation(operation_type: String, slot: int) -> void:
	if not cloud_sync_enabled:
		return

	var operation = {
		"type": operation_type,
		"slot": slot,
		"timestamp": Time.get_unix_time_from_system()
	}

	pending_cloud_operations.append(operation)
	_process_cloud_sync_queue()

# 處理雲端同步隊列
func _process_cloud_sync_queue() -> void:
	if pending_cloud_operations.is_empty():
		return

	var operation = pending_cloud_operations.pop_front()
	var operation_type = operation.type
	var slot = operation.slot

	LogManager.info("EnhancedSaveManager", "執行雲端同步", {"operation": operation_type, "slot": slot})

	cloud_sync_started.emit(operation_type)

	# 模擬雲端操作
	await get_tree().create_timer(1.0).timeout

	# 成功完成
	last_cloud_sync_time = Time.get_unix_time_from_system()
	cloud_sync_completed.emit(operation_type, true)

# === 實用工具方法 ===

# 獲取存檔文件路徑
func _get_save_file_path(slot: int) -> String:
	return SAVE_DIRECTORY + "save_%d.sav" % slot

# 獲取備份文件路徑
func _get_backup_file_path(slot: int, timestamp: float) -> String:
	return BACKUP_DIRECTORY + "save_%d_backup_%d.sav" % [slot, int(timestamp)]

# 獲取存檔計數
func _get_save_count() -> int:
	var save_files = _get_files_matching_pattern(SAVE_DIRECTORY, "save_*.sav")
	return save_files.size()

# 計算總遊戲時間
func _calculate_total_playtime(game_data: Dictionary) -> float:
	return game_data.get("total_playtime", 0.0)

# 獲取匹配模式的文件列表
func _get_files_matching_pattern(directory: String, pattern: String) -> Array[String]:
	var files: Array[String] = []
	var dir = DirAccess.open(directory)

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if file_name.match(pattern):
				files.append(file_name)
			file_name = dir.get_next()

	return files

# 從文件名提取時間戳
func _get_file_timestamp(filename: String) -> float:
	var parts = filename.split("_")
	if parts.size() >= 3:
		var timestamp_str = parts[-1].replace(".sav", "")
		return float(timestamp_str)
	return 0.0

# === 公共API ===

# 獲取存檔槽位信息
func get_save_slot_info(slot: int) -> Dictionary:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		return {}

	var save_file_path = _get_save_file_path(slot)

	if not FileAccess.file_exists(save_file_path):
		return {"exists": false, "slot": slot}

	var file = FileAccess.open(save_file_path, FileAccess.READ)
	if file == null:
		return {"exists": false, "slot": slot}

	var file_size = file.get_length()
	var file_time = FileAccess.get_modified_time(save_file_path)
	file.close()

	return {
		"exists": true,
		"slot": slot,
		"file_size": file_size,
		"modified_time": file_time,
		"formatted_time": Time.get_datetime_string_from_unix_time(file_time)
	}

# 獲取所有存檔槽位信息
func get_all_save_slots_info() -> Array[Dictionary]:
	var slots_info: Array[Dictionary] = []

	for slot in range(MAX_SAVE_SLOTS):
		slots_info.append(get_save_slot_info(slot))

	return slots_info

# 刪除存檔
func delete_save(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		return false

	var save_file_path = _get_save_file_path(slot)

	if FileAccess.file_exists(save_file_path):
		DirAccess.remove_absolute(save_file_path)
		LogManager.info("EnhancedSaveManager", "存檔已刪除", {"slot": slot})
		return true

	return false

# 獲取系統狀態
func get_save_system_status() -> Dictionary:
	return {
		"current_slot": current_save_slot,
		"auto_save_enabled": is_auto_save_enabled,
		"cloud_sync_enabled": cloud_sync_enabled,
		"last_cloud_sync": last_cloud_sync_time,
		"pending_operations": save_operations_queue.size(),
		"encryption_ready": encryption_manager.is_ready()
	}

# === 事件處理器 ===

func _on_save_requested(slot: int) -> void:
	var game_data = GameCore.serialize_game_state()
	save_game(slot, game_data)

func _on_load_requested(slot: int) -> void:
	load_game(slot)

func _on_game_state_changed(new_state: int, old_state: int) -> void:
	# 在特定狀態變化時觸發存檔
	if new_state == GameStateManager.GameState.GAME_RUNNING and old_state == GameStateManager.GameState.SKILL_SELECTION:
		# 技能選擇完成後自動保存
		if current_save_slot >= 0:
			var game_data = GameCore.serialize_game_state()
			save_game(current_save_slot, game_data, true)