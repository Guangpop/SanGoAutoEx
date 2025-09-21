# IdleTimer.gd - 閒置時間追蹤器
#
# 功能：
# - 追蹤玩家離線時間
# - 計算背景進度累積
# - 管理閒置獎勵發放
# - 處理時間同步和驗證

extends Node
class_name IdleTimer

signal idle_time_detected(offline_hours: float)
signal background_progress_ready(progress: Dictionary)
signal idle_rewards_calculated(rewards: Dictionary)

# 時間追蹤
var last_save_time: float = 0.0
var current_session_start: float = 0.0
var total_idle_time: float = 0.0

# 配置
var max_idle_time: float = 86400.0 # 24小時（秒）
var min_idle_time: float = 300.0 # 5分鐘最小閒置時間
var check_interval: float = 60.0 # 1分鐘檢查間隔

# 進度計算
var idle_timer: Timer
var is_tracking: bool = false

func _ready() -> void:
	name = "IdleTimer"
	LogManager.info("IdleTimer", "閒置時間追蹤器初始化")

	# 創建定時器
	idle_timer = Timer.new()
	idle_timer.wait_time = check_interval
	idle_timer.timeout.connect(_on_idle_check)
	add_child(idle_timer)

	# 記錄當前會話開始時間
	current_session_start = Time.get_unix_time_from_system()

# 開始追蹤
func start_tracking() -> void:
	if not is_tracking:
		is_tracking = true
		idle_timer.start()
		current_session_start = Time.get_unix_time_from_system()
		LogManager.debug("IdleTimer", "開始追蹤閒置時間")

# 停止追蹤
func stop_tracking() -> void:
	if is_tracking:
		is_tracking = false
		idle_timer.stop()
		LogManager.debug("IdleTimer", "停止追蹤閒置時間")

# 檢查離線時間
func check_offline_time(last_played_time: float) -> float:
	var current_time = Time.get_unix_time_from_system()
	var offline_seconds = current_time - last_played_time

	# 驗證時間合理性
	if offline_seconds < 0:
		LogManager.warning("IdleTimer", "檢測到時間異常", {
			"offline_seconds": offline_seconds,
			"last_played": last_played_time,
			"current": current_time
		})
		return 0.0

	# 限制最大閒置時間
	offline_seconds = min(offline_seconds, max_idle_time)

	var offline_hours = offline_seconds / 3600.0

	if offline_hours >= min_idle_time / 3600.0:
		LogManager.info("IdleTimer", "檢測到離線時間", {
			"offline_hours": offline_hours,
			"offline_seconds": offline_seconds
		})
		idle_time_detected.emit(offline_hours)

	return offline_hours

# 更新最後保存時間
func update_last_save_time() -> void:
	last_save_time = Time.get_unix_time_from_system()

# 獲取當前會話時間
func get_current_session_time() -> float:
	if not is_tracking:
		return 0.0

	var current_time = Time.get_unix_time_from_system()
	return current_time - current_session_start

# 私有方法
func _on_idle_check() -> void:
	# 定期檢查和更新時間
	if is_tracking:
		var session_time = get_current_session_time()
		LogManager.debug("IdleTimer", "會話時間檢查", {
			"session_hours": session_time / 3600.0
		})