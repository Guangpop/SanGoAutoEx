# LogManager.gd - 專業完整的日誌管理系統
#
# 功能：
# - 完整的Log格式 (時間戳、級別、來源、訊息、上下文)
# - 清楚指出錯誤檔案與位置 (檔案:行數)
# - 人類可讀的格式
# - 儲存Log檔案在 /logs 目錄
# - 支援不同級別的日誌 (DEBUG, INFO, WARN, ERROR)
# - Emoji 分類標記提高可讀性

extends Node

# 日誌級別枚舉
enum LogLevel {
	DEBUG = 0,
	INFO = 1,
	WARN = 2,
	ERROR = 3
}

# 日誌級別到顏色和emoji的映射
const LOG_CONFIGS = {
	LogLevel.DEBUG: {"emoji": "🔍", "color": "\u001b[37m", "name": "DEBUG"},
	LogLevel.INFO:  {"emoji": "ℹ️", "color": "\u001b[36m", "name": "INFO"},
	LogLevel.WARN:  {"emoji": "⚠️", "color": "\u001b[33m", "name": "WARN"},
	LogLevel.ERROR: {"emoji": "❌", "color": "\u001b[31m", "name": "ERROR"}
}

# 重置顏色
const COLOR_RESET = "\u001b[0m"

# 私有變量
var _log_file: FileAccess
var _current_log_path: String
var _min_log_level: LogLevel = LogLevel.INFO
var _max_log_files: int = 10
var _max_file_size: int = 10 * 1024 * 1024  # 10MB
var _session_start_time: String

func _ready() -> void:
	name = "LogManager"
	_session_start_time = Time.get_datetime_string_from_system()

	# 確保logs目錄存在
	ensure_log_directory()

	# 初始化日誌文件
	initialize_log_file()

	# 記錄系統啟動
	info("LogManager", "日誌系統初始化完成", {
		"session_start": _session_start_time,
		"log_path": _current_log_path,
		"min_level": LogLevel.keys()[_min_log_level]
	})

func _exit_tree() -> void:
	if _log_file:
		info("LogManager", "日誌系統關閉", {"session_end": Time.get_datetime_string_from_system()})
		_log_file.close()

# 確保logs目錄存在
func ensure_log_directory() -> void:
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("logs"):
		dir.make_dir("logs")

# 初始化日誌文件
func initialize_log_file() -> void:
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	_current_log_path = "user://logs/game_%s.log" % timestamp

	_log_file = FileAccess.open(_current_log_path, FileAccess.WRITE)
	if _log_file:
		_log_file.store_line("=== 三國天命放置遊戲 日誌檔案 ===")
		_log_file.store_line("Session Start: %s" % _session_start_time)
		_log_file.store_line("Godot Version: %s" % Engine.get_version_info())
		_log_file.store_line("Platform: %s" % OS.get_name())
		_log_file.store_line("==========================================")
		_log_file.flush()
	else:
		push_error("無法創建日誌檔案: %s" % _current_log_path)

	# 清理舊的日誌文件
	cleanup_old_logs()

# 清理舊的日誌文件
func cleanup_old_logs() -> void:
	var dir = DirAccess.open("user://logs/")
	if not dir:
		return

	var log_files: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".log"):
			log_files.append(file_name)
		file_name = dir.get_next()

	# 按文件名排序 (包含時間戳)，保留最新的文件
	log_files.sort()
	log_files.reverse()

	# 刪除超過限制的舊文件
	for i in range(_max_log_files, log_files.size()):
		dir.remove(log_files[i])

# 獲取調用者信息 (檔案名和行號)
func get_caller_info() -> Dictionary:
	var stack = get_stack()

	# 跳過 LogManager 內部的調用
	for i in range(2, stack.size()):
		var frame = stack[i]
		if not frame.source.ends_with("LogManager.gd"):
			return {
				"file": frame.source.get_file(),
				"line": frame.line,
				"function": frame.function
			}

	return {"file": "unknown", "line": 0, "function": "unknown"}

# 格式化日誌消息
func format_log_message(level: LogLevel, category: String, message: String, context: Dictionary = {}) -> String:
	var config = LOG_CONFIGS[level]
	var caller = get_caller_info()
	var timestamp = Time.get_datetime_string_from_system()

	var formatted_message = "[%s] %s %s [%s] %s:%d | %s" % [
		timestamp,
		config.emoji,
		config.name,
		category,
		caller.file,
		caller.line,
		message
	]

	# 添加上下文信息
	if not context.is_empty():
		var context_str = JSON.stringify(context)
		formatted_message += " | Context: %s" % context_str

	return formatted_message

# 寫入日誌到文件和控制台
func write_log(level: LogLevel, category: String, message: String, context: Dictionary = {}) -> void:
	# 檢查日誌級別
	if level < _min_log_level:
		return

	var formatted_message = format_log_message(level, category, message, context)
	var config = LOG_CONFIGS[level]

	# 輸出到控制台（帶顏色）
	var console_message = "%s%s%s" % [config.color, formatted_message, COLOR_RESET]
	print(console_message)

	# 寫入檔案
	if _log_file:
		_log_file.store_line(formatted_message)
		_log_file.flush()

		# 檢查文件大小，必要時輪轉
		if _log_file.get_position() > _max_file_size:
			rotate_log_file()

# 輪轉日誌文件
func rotate_log_file() -> void:
	if _log_file:
		_log_file.close()

	initialize_log_file()
	info("LogManager", "日誌文件已輪轉", {"new_file": _current_log_path})

# 公共日誌方法
func debug(category: String, message: String, context: Dictionary = {}) -> void:
	write_log(LogLevel.DEBUG, category, message, context)

func info(category: String, message: String, context: Dictionary = {}) -> void:
	write_log(LogLevel.INFO, category, message, context)

func warn(category: String, message: String, context: Dictionary = {}) -> void:
	write_log(LogLevel.WARN, category, message, context)

func warning(category: String, message: String, context: Dictionary = {}) -> void:
	write_log(LogLevel.WARN, category, message, context)

func error(category: String, message: String, context: Dictionary = {}) -> void:
	write_log(LogLevel.ERROR, category, message, context)

# 設置最小日誌級別
func set_min_log_level(level: LogLevel) -> void:
	_min_log_level = level
	info("LogManager", "日誌級別已更改", {"new_level": LogLevel.keys()[level]})

# 獲取當前日誌文件路徑
func get_current_log_path() -> String:
	return _current_log_path

# 獲取日誌統計信息
func get_log_stats() -> Dictionary:
	var stats = {
		"current_file": _current_log_path,
		"session_start": _session_start_time,
		"min_level": LogLevel.keys()[_min_log_level],
		"file_size": 0,
		"total_files": 0
	}

	if _log_file:
		stats.file_size = _log_file.get_position()

	# 計算日誌文件總數
	var dir = DirAccess.open("user://logs/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".log"):
				stats.total_files += 1
			file_name = dir.get_next()

	return stats

# 專用的性能監控日誌
func performance(category: String, operation: String, duration: float, details: Dictionary = {}) -> void:
	var perf_context = details.duplicate()
	perf_context["operation"] = operation
	perf_context["duration_ms"] = duration * 1000

	var level = LogLevel.WARN if duration > 0.1 else LogLevel.INFO
	write_log(level, "PERF/" + category, "操作耗時: %s (%.2fms)" % [operation, duration * 1000], perf_context)

# 專用的遊戲事件日誌
func game_event(category: String, event_type: String, details: Dictionary = {}) -> void:
	var event_context = details.duplicate()
	event_context["event_type"] = event_type
	event_context["game_time"] = Time.get_unix_time_from_system()

	info("GAME/" + category, "遊戲事件: %s" % event_type, event_context)

# 專用的錯誤追蹤日誌
func crash_report(error_message: String, stack_trace: Array, additional_info: Dictionary = {}) -> void:
	var crash_context = additional_info.duplicate()
	crash_context["stack_trace"] = stack_trace
	crash_context["engine_version"] = Engine.get_version_info()
	crash_context["platform"] = OS.get_name()
	crash_context["memory_usage"] = Performance.get_monitor(Performance.MEMORY_STATIC)

	error("CRASH", "嚴重錯誤: %s" % error_message, crash_context)

	# 立即刷新以確保崩潰信息被保存
	if _log_file:
		_log_file.flush()

# 開發者友好的斷言日誌
func assert_log(condition: bool, message: String, context: Dictionary = {}) -> bool:
	if not condition:
		var assert_context = context.duplicate()
		assert_context["assertion_failed"] = true
		error("ASSERT", "斷言失敗: %s" % message, assert_context)

	return condition