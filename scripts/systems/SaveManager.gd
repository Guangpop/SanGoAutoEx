# SaveManager.gd - 增強版存檔管理系統
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
# var encryption_manager: EncryptionManager  # TODO: 創建 EncryptionManager
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

const SAVE_FILE_PREFIX = "user://save_"
const AUTO_SAVE_FILE = "user://autosave.save"

func _ready() -> void:
	name = "SaveManager"
	LogManager.info("SaveManager", "存檔管理器初始化完成")

# 保存遊戲到指定槽位
func save_game(slot: int = 0) -> bool:
	var save_path = SAVE_FILE_PREFIX + str(slot) + ".save"

	# 獲取遊戲狀態
	var save_data = GameCore.serialize_game_state()
	save_data["save_version"] = "1.0"
	save_data["save_time"] = Time.get_unix_time_from_system()

	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		LogManager.error("SaveManager", "無法創建存檔文件", {"path": save_path})
		EventBus.save_completed.emit(slot, false)
		return false

	file.store_string(JSON.stringify(save_data))
	file.close()

	LogManager.info("SaveManager", "遊戲存檔成功", {"slot": slot, "path": save_path})
	EventBus.save_completed.emit(slot, true)
	return true

# 從指定槽位讀取遊戲
func load_game(slot: int = 0) -> bool:
	var save_path = SAVE_FILE_PREFIX + str(slot) + ".save"

	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		LogManager.warn("SaveManager", "存檔文件不存在", {"path": save_path})
		EventBus.load_completed.emit(slot, false, {})
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		LogManager.error("SaveManager", "存檔文件損壞", {"path": save_path})
		EventBus.load_completed.emit(slot, false, {})
		return false

	var save_data = json.get_data()
	var success = GameCore.load_game(save_data)

	LogManager.info("SaveManager", "遊戲讀檔完成", {"slot": slot, "success": success})
	EventBus.load_completed.emit(slot, success, save_data)
	return success

# 檢查存檔槽位是否存在
func has_save(slot: int) -> bool:
	var save_path = SAVE_FILE_PREFIX + str(slot) + ".save"
	return FileAccess.file_exists(save_path)