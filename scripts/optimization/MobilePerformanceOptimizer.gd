# MobilePerformanceOptimizer.gd - 移動設備性能優化器
#
# 功能：
# - 動態FPS管理和電池優化
# - 記憶體管理和垃圾回收優化
# - 渲染優化和LOD系統
# - 背景處理和資源管理
# - 性能監控和自適應調整

extends Node
class_name MobilePerformanceOptimizer

signal performance_level_changed(level: String)
signal fps_target_adjusted(new_target: int)
signal memory_warning_triggered(usage_mb: float)

# 性能等級配置
enum PerformanceLevel {
	HIGH_PERFORMANCE,    # 高性能：60FPS，完整效果
	BALANCED,           # 平衡：45FPS，部分效果
	POWER_SAVING,       # 省電：30FPS，最小效果
	EMERGENCY          # 緊急：20FPS，極簡效果
}

# 性能監控
var current_fps: float = 60.0
var target_fps: int = 60
var frame_time_samples: Array[float] = []
var memory_usage_samples: Array[float] = []

# 性能等級
var current_performance_level: PerformanceLevel = PerformanceLevel.HIGH_PERFORMANCE
var auto_adjust_enabled: bool = true
var performance_locked: bool = false

# 優化設置
var max_frame_time_samples: int = 60  # 1秒的樣本
var memory_warning_threshold_mb: float = 100.0
var critical_memory_threshold_mb: float = 150.0

# 渲染優化
var lod_enabled: bool = true
var dynamic_batching_enabled: bool = true
var shadow_quality: int = 2  # 0-3
var particle_quality: int = 2  # 0-3

# 背景處理
var background_processing_enabled: bool = true
var background_save_interval: float = 60.0
var idle_timeout: float = 300.0  # 5分鐘

# 優化統計
var optimization_stats: Dictionary = {
	"frames_dropped": 0,
	"memory_cleanups": 0,
	"lod_switches": 0,
	"performance_adjustments": 0
}

func _ready() -> void:
	name = "MobilePerformanceOptimizer"
	LogManager.info("MobilePerformanceOptimizer", "移動性能優化器初始化")

	# 初始化性能監控
	_initialize_performance_monitoring()

	# 設置初始性能等級
	_detect_device_capabilities()

	# 啟動背景處理
	_setup_background_processing()

# === 性能監控系統 ===

func _initialize_performance_monitoring() -> void:
	# 設置FPS監控
	set_process(true)

	# 初始化樣本數組
	frame_time_samples.resize(max_frame_time_samples)
	memory_usage_samples.resize(max_frame_time_samples)

	for i in range(max_frame_time_samples):
		frame_time_samples[i] = 1.0 / 60.0  # 60FPS baseline
		memory_usage_samples[i] = 50.0  # 50MB baseline

func _process(delta: float) -> void:
	# 更新性能樣本
	_update_performance_samples(delta)

	# 檢查是否需要調整性能
	if auto_adjust_enabled and not performance_locked:
		_evaluate_performance_adjustment()

	# 更新渲染優化
	_update_rendering_optimizations()

func _update_performance_samples(delta: float) -> void:
	# 更新幀時間樣本
	frame_time_samples.push_back(delta)
	if frame_time_samples.size() > max_frame_time_samples:
		frame_time_samples.pop_front()

	# 計算當前FPS
	var avg_frame_time = _calculate_average(frame_time_samples)
	current_fps = 1.0 / avg_frame_time if avg_frame_time > 0 else 60.0

	# 更新記憶體使用樣本
	var memory_usage = _get_memory_usage_mb()
	memory_usage_samples.push_back(memory_usage)
	if memory_usage_samples.size() > max_frame_time_samples:
		memory_usage_samples.pop_front()

	# 檢查記憶體警告
	_check_memory_warnings(memory_usage)

func _calculate_average(samples: Array[float]) -> float:
	if samples.is_empty():
		return 0.0

	var sum = 0.0
	for sample in samples:
		sum += sample
	return sum / samples.size()

func _get_memory_usage_mb() -> float:
	# 獲取記憶體使用量（MB）
	var memory_info = OS.get_static_memory_usage_by_type()
	var total_bytes = 0

	for type_name in memory_info:
		total_bytes += memory_info[type_name]

	return total_bytes / (1024.0 * 1024.0)  # 轉換為MB

func _check_memory_warnings(memory_mb: float) -> void:
	if memory_mb > critical_memory_threshold_mb:
		# 觸發緊急記憶體清理
		_trigger_emergency_memory_cleanup()
		memory_warning_triggered.emit(memory_mb)

	elif memory_mb > memory_warning_threshold_mb:
		# 觸發常規記憶體清理
		_trigger_memory_cleanup()

# === 性能等級管理 ===

func _detect_device_capabilities() -> void:
	# 檢測設備能力並設置初始性能等級
	var device_info = _get_device_info()

	# 基於設備信息決定初始性能等級
	if device_info.is_high_end:
		set_performance_level(PerformanceLevel.HIGH_PERFORMANCE)
	elif device_info.is_mid_range:
		set_performance_level(PerformanceLevel.BALANCED)
	else:
		set_performance_level(PerformanceLevel.POWER_SAVING)

	LogManager.info("MobilePerformanceOptimizer", "設備能力檢測完成", {
		"performance_level": PerformanceLevel.keys()[current_performance_level],
		"device_score": device_info.performance_score
	})

func _get_device_info() -> Dictionary:
	# 獲取設備信息並評估性能
	var info = {
		"is_mobile": OS.has_feature("mobile"),
		"is_high_end": false,
		"is_mid_range": false,
		"performance_score": 50  # 0-100
	}

	# 基於可用信息評估設備性能
	var screen_size = DisplayServer.screen_get_size()
	var pixel_count = screen_size.x * screen_size.y

	# 簡單的性能評估邏輯
	if pixel_count > 2000000:  # 高解析度螢幕
		info.performance_score += 20

	if OS.get_processor_count() >= 6:  # 多核心處理器
		info.performance_score += 15

	# 設定等級
	if info.performance_score >= 75:
		info.is_high_end = true
	elif info.performance_score >= 50:
		info.is_mid_range = true

	return info

func set_performance_level(level: PerformanceLevel) -> void:
	if current_performance_level == level:
		return

	var old_level = current_performance_level
	current_performance_level = level

	# 應用性能設置
	_apply_performance_settings(level)

	# 更新統計
	optimization_stats.performance_adjustments += 1

	LogManager.info("MobilePerformanceOptimizer", "性能等級變更", {
		"from": PerformanceLevel.keys()[old_level],
		"to": PerformanceLevel.keys()[level]
	})

	performance_level_changed.emit(PerformanceLevel.keys()[level])

func _apply_performance_settings(level: PerformanceLevel) -> void:
	match level:
		PerformanceLevel.HIGH_PERFORMANCE:
			_apply_high_performance_settings()
		PerformanceLevel.BALANCED:
			_apply_balanced_settings()
		PerformanceLevel.POWER_SAVING:
			_apply_power_saving_settings()
		PerformanceLevel.EMERGENCY:
			_apply_emergency_settings()

func _apply_high_performance_settings() -> void:
	target_fps = 60
	shadow_quality = 3
	particle_quality = 3
	lod_enabled = false
	dynamic_batching_enabled = true

	# 設置引擎FPS
	Engine.max_fps = target_fps
	fps_target_adjusted.emit(target_fps)

func _apply_balanced_settings() -> void:
	target_fps = 45
	shadow_quality = 2
	particle_quality = 2
	lod_enabled = true
	dynamic_batching_enabled = true

	Engine.max_fps = target_fps
	fps_target_adjusted.emit(target_fps)

func _apply_power_saving_settings() -> void:
	target_fps = 30
	shadow_quality = 1
	particle_quality = 1
	lod_enabled = true
	dynamic_batching_enabled = false

	Engine.max_fps = target_fps
	fps_target_adjusted.emit(target_fps)

func _apply_emergency_settings() -> void:
	target_fps = 20
	shadow_quality = 0
	particle_quality = 0
	lod_enabled = true
	dynamic_batching_enabled = false

	Engine.max_fps = target_fps
	fps_target_adjusted.emit(target_fps)

# === 自適應性能調整 ===

func _evaluate_performance_adjustment() -> void:
	# 檢查是否需要調整性能等級
	var fps_stability = _calculate_fps_stability()
	var memory_pressure = _calculate_memory_pressure()

	# 決定調整方向
	if _should_increase_performance(fps_stability, memory_pressure):
		_try_increase_performance()
	elif _should_decrease_performance(fps_stability, memory_pressure):
		_try_decrease_performance()

func _calculate_fps_stability() -> float:
	# 計算FPS穩定性（0-1，1表示非常穩定）
	if frame_time_samples.size() < 10:
		return 1.0

	var variance = 0.0
	var avg_frame_time = _calculate_average(frame_time_samples)

	for sample in frame_time_samples:
		variance += pow(sample - avg_frame_time, 2)
	variance /= frame_time_samples.size()

	# 轉換為穩定性分數
	var stability = 1.0 / (1.0 + variance * 1000.0)
	return clamp(stability, 0.0, 1.0)

func _calculate_memory_pressure() -> float:
	# 計算記憶體壓力（0-1，1表示壓力很大）
	var avg_memory = _calculate_average(memory_usage_samples)
	var pressure = avg_memory / memory_warning_threshold_mb
	return clamp(pressure, 0.0, 1.0)

func _should_increase_performance(fps_stability: float, memory_pressure: float) -> bool:
	# 條件：FPS穩定且記憶體壓力小
	return (fps_stability > 0.8 and
			memory_pressure < 0.6 and
			current_fps > target_fps * 1.1 and
			current_performance_level != PerformanceLevel.HIGH_PERFORMANCE)

func _should_decrease_performance(fps_stability: float, memory_pressure: float) -> bool:
	# 條件：FPS不穩定或記憶體壓力大
	return (fps_stability < 0.6 or
			memory_pressure > 0.8 or
			current_fps < target_fps * 0.8 and
			current_performance_level != PerformanceLevel.EMERGENCY)

func _try_increase_performance() -> void:
	match current_performance_level:
		PerformanceLevel.POWER_SAVING:
			set_performance_level(PerformanceLevel.BALANCED)
		PerformanceLevel.BALANCED:
			set_performance_level(PerformanceLevel.HIGH_PERFORMANCE)
		PerformanceLevel.EMERGENCY:
			set_performance_level(PerformanceLevel.POWER_SAVING)

func _try_decrease_performance() -> void:
	match current_performance_level:
		PerformanceLevel.HIGH_PERFORMANCE:
			set_performance_level(PerformanceLevel.BALANCED)
		PerformanceLevel.BALANCED:
			set_performance_level(PerformanceLevel.POWER_SAVING)
		PerformanceLevel.POWER_SAVING:
			set_performance_level(PerformanceLevel.EMERGENCY)

# === 記憶體管理 ===

func _trigger_memory_cleanup() -> void:
	# 常規記憶體清理
	LogManager.debug("MobilePerformanceOptimizer", "執行記憶體清理")

	# 強制垃圾回收
	_force_garbage_collection()

	# 清理緩存
	_clear_unused_caches()

	# 更新統計
	optimization_stats.memory_cleanups += 1

func _trigger_emergency_memory_cleanup() -> void:
	# 緊急記憶體清理
	LogManager.warning("MobilePerformanceOptimizer", "執行緊急記憶體清理")

	# 強制垃圾回收
	_force_garbage_collection()

	# 激進清理
	_aggressive_memory_cleanup()

	# 自動降低性能等級
	if current_performance_level != PerformanceLevel.EMERGENCY:
		_try_decrease_performance()

func _force_garbage_collection() -> void:
	# 強制執行垃圾回收
	for i in range(3):
		await get_tree().process_frame

	# 在Godot中，垃圾回收主要由引擎自動處理
	# 這裡我們主要是給引擎時間來清理

func _clear_unused_caches() -> void:
	# 清理未使用的緩存
	# 這裡可以清理各種系統的緩存

	# 通知其他系統清理緩存
	EventBus.cache_cleanup_requested.emit()

func _aggressive_memory_cleanup() -> void:
	# 激進的記憶體清理
	_clear_unused_caches()

	# 釋放非必要資源
	EventBus.release_non_essential_resources.emit()

	# 暫停非核心系統
	EventBus.pause_non_core_systems.emit()

# === 渲染優化 ===

func _update_rendering_optimizations() -> void:
	# 根據當前性能等級更新渲染優化
	if not lod_enabled:
		return

	# 基於FPS動態調整LOD
	_update_dynamic_lod()

	# 調整粒子系統
	_update_particle_systems()

func _update_dynamic_lod() -> void:
	# 動態LOD調整
	var lod_factor = 1.0

	if current_fps < target_fps * 0.8:
		lod_factor = 0.5  # 降低細節
		optimization_stats.lod_switches += 1
	elif current_fps > target_fps * 1.2:
		lod_factor = 1.0  # 恢復細節

	# 通知系統調整LOD
	EventBus.lod_factor_changed.emit(lod_factor)

func _update_particle_systems() -> void:
	# 根據性能等級調整粒子系統
	var max_particles = _get_max_particles_for_level()
	EventBus.particle_limit_changed.emit(max_particles)

func _get_max_particles_for_level() -> int:
	match current_performance_level:
		PerformanceLevel.HIGH_PERFORMANCE:
			return 1000
		PerformanceLevel.BALANCED:
			return 500
		PerformanceLevel.POWER_SAVING:
			return 200
		PerformanceLevel.EMERGENCY:
			return 50
	return 500

# === 背景處理管理 ===

func _setup_background_processing() -> void:
	if not background_processing_enabled:
		return

	# 設置背景存檔定時器
	var save_timer = Timer.new()
	save_timer.wait_time = background_save_interval
	save_timer.timeout.connect(_background_save)
	save_timer.autostart = true
	add_child(save_timer)

	# 設置閒置檢測
	var idle_timer = Timer.new()
	idle_timer.wait_time = idle_timeout
	idle_timer.timeout.connect(_handle_idle_timeout)
	idle_timer.one_shot = true
	add_child(idle_timer)

	# 監聽用戶輸入重置閒置定時器
	EventBus.user_input_detected.connect(_reset_idle_timer.bind(idle_timer))

func _background_save() -> void:
	# 背景存檔
	if _should_perform_background_save():
		LogManager.debug("MobilePerformanceOptimizer", "執行背景存檔")
		EventBus.background_save_requested.emit()

func _should_perform_background_save() -> bool:
	# 檢查是否應該執行背景存檔
	return (current_performance_level != PerformanceLevel.EMERGENCY and
			current_fps > target_fps * 0.7)

func _handle_idle_timeout() -> void:
	# 處理閒置超時
	LogManager.info("MobilePerformanceOptimizer", "檢測到用戶閒置")

	# 切換到省電模式
	if current_performance_level == PerformanceLevel.HIGH_PERFORMANCE:
		set_performance_level(PerformanceLevel.POWER_SAVING)

	# 暫停非必要更新
	EventBus.enter_idle_mode.emit()

func _reset_idle_timer(timer: Timer) -> void:
	# 重置閒置定時器
	if timer:
		timer.start()

	# 如果在閒置模式，恢復正常模式
	EventBus.exit_idle_mode.emit()

# === 公共API ===

func get_current_performance_level() -> PerformanceLevel:
	return current_performance_level

func get_current_fps() -> float:
	return current_fps

func get_target_fps() -> int:
	return target_fps

func get_memory_usage_mb() -> float:
	return _get_memory_usage_mb()

func is_performance_stable() -> bool:
	var stability = _calculate_fps_stability()
	return stability > 0.7

func set_auto_adjust_enabled(enabled: bool) -> void:
	auto_adjust_enabled = enabled
	LogManager.info("MobilePerformanceOptimizer", "自動調整設置", {"enabled": enabled})

func lock_performance_level(lock: bool) -> void:
	performance_locked = lock
	LogManager.info("MobilePerformanceOptimizer", "性能等級鎖定", {"locked": lock})

func force_performance_level(level: PerformanceLevel) -> void:
	performance_locked = true
	set_performance_level(level)

func get_optimization_stats() -> Dictionary:
	var stats = optimization_stats.duplicate()
	stats["current_fps"] = current_fps
	stats["target_fps"] = target_fps
	stats["memory_usage_mb"] = get_memory_usage_mb()
	stats["performance_level"] = PerformanceLevel.keys()[current_performance_level]
	stats["fps_stability"] = _calculate_fps_stability()
	stats["memory_pressure"] = _calculate_memory_pressure()
	return stats

func reset_optimization_stats() -> void:
	optimization_stats = {
		"frames_dropped": 0,
		"memory_cleanups": 0,
		"lod_switches": 0,
		"performance_adjustments": 0
	}

# === 性能配置 ===

func configure_performance_thresholds(config: Dictionary) -> void:
	if config.has("memory_warning_threshold_mb"):
		memory_warning_threshold_mb = config.memory_warning_threshold_mb

	if config.has("critical_memory_threshold_mb"):
		critical_memory_threshold_mb = config.critical_memory_threshold_mb

	if config.has("background_save_interval"):
		background_save_interval = config.background_save_interval

	if config.has("idle_timeout"):
		idle_timeout = config.idle_timeout

	LogManager.info("MobilePerformanceOptimizer", "性能配置更新", config)

func get_performance_configuration() -> Dictionary:
	return {
		"memory_warning_threshold_mb": memory_warning_threshold_mb,
		"critical_memory_threshold_mb": critical_memory_threshold_mb,
		"background_save_interval": background_save_interval,
		"idle_timeout": idle_timeout,
		"auto_adjust_enabled": auto_adjust_enabled,
		"performance_locked": performance_locked
	}