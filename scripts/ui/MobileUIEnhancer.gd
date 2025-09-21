# MobileUIEnhancer.gd - 移動端UI增強器
#
# 功能：
# - 為現有UI組件添加觸控手勢支持
# - 實現響應式佈局和適應性設計
# - 提供觸覺反饋和動畫效果
# - 優化移動端性能和用戶體驗

extends Node
class_name MobileUIEnhancer

signal gesture_detected(gesture_type: String, data: Dictionary)
signal ui_feedback_requested(feedback_type: String, intensity: float)

# 手勢檢測配置
const SWIPE_THRESHOLD := 100.0 # 滑動閾值（像素）
const SWIPE_VELOCITY_THRESHOLD := 300.0 # 滑動速度閾值
const LONG_PRESS_DURATION := 0.8 # 長按持續時間（秒）
const DOUBLE_TAP_INTERVAL := 0.3 # 雙擊間隔時間

# 觸控狀態追蹤
var touch_start_position: Vector2
var touch_start_time: float
var last_tap_time: float = 0.0
var tap_count: int = 0
var is_dragging: bool = false
var is_long_pressing: bool = false

# 長按定時器
var long_press_timer: Timer

# 響應式設計配置
var screen_size: Vector2
var ui_scale_factor: float = 1.0
var is_landscape: bool = false

# 動畫和反饋
var tween: Tween
var haptic_enabled: bool = true

func _ready() -> void:
	name = "MobileUIEnhancer"

	# 初始化長按定時器
	long_press_timer = Timer.new()
	long_press_timer.wait_time = LONG_PRESS_DURATION
	long_press_timer.one_shot = true
	long_press_timer.timeout.connect(_on_long_press_detected)
	add_child(long_press_timer)

	# 初始化Tween
	tween = Tween.new()
	add_child(tween)

	# 檢測螢幕尺寸變化
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_update_screen_info()

# === 手勢檢測系統 ===

# 為控件添加手勢支持
func add_gesture_support(control: Control) -> void:
	if not control:
		LogManager.warning("MobileUIEnhancer", "嘗試為空控件添加手勢支持")
		return

	# 連接輸入事件
	control.gui_input.connect(_on_control_input.bind(control))

	# 確保控件可以接收輸入
	if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		control.mouse_filter = Control.MOUSE_FILTER_STOP

	LogManager.debug("MobileUIEnhancer", "已為控件添加手勢支持", {"control": control.name})

# 處理控件輸入事件
func _on_control_input(event: InputEvent, control: Control) -> void:
	if event is InputEventScreenTouch:
		_handle_touch_event(event as InputEventScreenTouch, control)
	elif event is InputEventScreenDrag:
		_handle_drag_event(event as InputEventScreenDrag, control)
	elif event is InputEventMouseButton:
		_handle_mouse_event(event as InputEventMouseButton, control)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion, control)

# 處理觸控事件
func _handle_touch_event(event: InputEventScreenTouch, control: Control) -> void:
	if event.pressed:
		_start_touch(event.position, control)
	else:
		_end_touch(event.position, control)

# 處理拖拽事件
func _handle_drag_event(event: InputEventScreenDrag, control: Control) -> void:
	_update_drag(event.position, event.relative, control)

# 處理滑鼠事件（桌面測試用）
func _handle_mouse_event(event: InputEventMouseButton, control: Control) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_touch(event.position, control)
		else:
			_end_touch(event.position, control)

# 處理滑鼠移動
func _handle_mouse_motion(event: InputEventMouseMotion, control: Control) -> void:
	if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_update_drag(event.position, event.relative, control)

# 開始觸控
func _start_touch(position: Vector2, control: Control) -> void:
	touch_start_position = position
	touch_start_time = Time.get_unix_time_from_system()
	is_dragging = false
	is_long_pressing = false

	# 開始長按檢測
	long_press_timer.start()

	# 檢測雙擊
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_tap_time < DOUBLE_TAP_INTERVAL:
		tap_count += 1
		if tap_count == 2:
			_emit_gesture("double_tap", {"position": position, "control": control})
			_provide_haptic_feedback("light")
			tap_count = 0
	else:
		tap_count = 1

	last_tap_time = current_time

# 更新拖拽
func _update_drag(position: Vector2, relative: Vector2, control: Control) -> void:
	if not is_dragging:
		var distance = touch_start_position.distance_to(position)
		if distance > 20.0: # 開始拖拽的最小距離
			is_dragging = true
			long_press_timer.stop() # 取消長按檢測
			_emit_gesture("drag_start", {"position": touch_start_position, "control": control})

	if is_dragging:
		_emit_gesture("drag_update", {
			"position": position,
			"relative": relative,
			"start_position": touch_start_position,
			"control": control
		})

# 結束觸控
func _end_touch(position: Vector2, control: Control) -> void:
	long_press_timer.stop()

	var end_time = Time.get_unix_time_from_system()
	var touch_duration = end_time - touch_start_time
	var distance = touch_start_position.distance_to(position)

	if is_dragging:
		# 檢測滑動手勢
		var velocity = distance / touch_duration
		if distance > SWIPE_THRESHOLD and velocity > SWIPE_VELOCITY_THRESHOLD:
			var direction = _get_swipe_direction(touch_start_position, position)
			_emit_gesture("swipe", {
				"direction": direction,
				"distance": distance,
				"velocity": velocity,
				"start_position": touch_start_position,
				"end_position": position,
				"control": control
			})
			_provide_haptic_feedback("medium")

		_emit_gesture("drag_end", {"position": position, "control": control})
	else:
		# 短按/點擊
		if not is_long_pressing and distance < 20.0:
			_emit_gesture("tap", {"position": position, "control": control})
			_provide_haptic_feedback("light")

	is_dragging = false
	is_long_pressing = false

# 長按檢測
func _on_long_press_detected() -> void:
	if not is_dragging:
		is_long_pressing = true
		_emit_gesture("long_press", {"position": touch_start_position})
		_provide_haptic_feedback("heavy")

# 獲取滑動方向
func _get_swipe_direction(start: Vector2, end: Vector2) -> String:
	var delta = end - start
	var abs_x = abs(delta.x)
	var abs_y = abs(delta.y)

	if abs_x > abs_y:
		return "right" if delta.x > 0 else "left"
	else:
		return "down" if delta.y > 0 else "up"

# 發射手勢事件
func _emit_gesture(gesture_type: String, data: Dictionary) -> void:
	gesture_detected.emit(gesture_type, data)
	LogManager.debug("MobileUIEnhancer", "手勢檢測", {"type": gesture_type, "data": data})

# === 響應式設計系統 ===

# 更新螢幕資訊
func _update_screen_info() -> void:
	screen_size = get_viewport().get_visible_rect().size
	is_landscape = screen_size.x > screen_size.y

	# 計算UI縮放因子（基於414x896標準）
	var base_width = 414.0
	var base_height = 896.0

	if is_landscape:
		ui_scale_factor = min(screen_size.x / base_height, screen_size.y / base_width)
	else:
		ui_scale_factor = min(screen_size.x / base_width, screen_size.y / base_height)

	ui_scale_factor = clamp(ui_scale_factor, 0.5, 2.0)

	LogManager.debug("MobileUIEnhancer", "螢幕資訊更新", {
		"size": screen_size,
		"scale_factor": ui_scale_factor,
		"is_landscape": is_landscape
	})

# 螢幕尺寸變化處理
func _on_viewport_size_changed() -> void:
	_update_screen_info()
	_apply_responsive_layout()

# 應用響應式佈局
func _apply_responsive_layout() -> void:
	# 這個方法會被子類或外部調用來更新特定UI的佈局
	pass

# 為控件應用響應式樣式
func apply_responsive_style(control: Control, style_config: Dictionary) -> void:
	if not control or style_config.is_empty():
		return

	# 應用縮放
	if style_config.has("scale_with_screen"):
		if style_config.scale_with_screen:
			control.scale = Vector2(ui_scale_factor, ui_scale_factor)

	# 應用最小尺寸
	if style_config.has("min_size"):
		var min_size = style_config.min_size as Vector2
		control.custom_minimum_size = min_size * ui_scale_factor

	# 應用邊距
	if style_config.has("margins") and control is MarginContainer:
		var margins = style_config.margins as Dictionary
		var margin_container = control as MarginContainer

		for margin_type in margins:
			var value = margins[margin_type] * ui_scale_factor
			match margin_type:
				"left": margin_container.add_theme_constant_override("margin_left", int(value))
				"right": margin_container.add_theme_constant_override("margin_right", int(value))
				"top": margin_container.add_theme_constant_override("margin_top", int(value))
				"bottom": margin_container.add_theme_constant_override("margin_bottom", int(value))

# === 動畫和反饋系統 ===

# 提供觸覺反饋
func _provide_haptic_feedback(intensity: String) -> void:
	if not haptic_enabled:
		return

	var feedback_intensity = 0.0
	match intensity:
		"light": feedback_intensity = 0.3
		"medium": feedback_intensity = 0.6
		"heavy": feedback_intensity = 1.0

	ui_feedback_requested.emit("haptic", feedback_intensity)

	# 在移動設備上實際觸發震動
	if OS.has_feature("mobile"):
		# Godot 4.x 的觸覺反饋API
		if Input.get_connected_joypads().size() > 0:
			Input.start_joy_vibration(0, feedback_intensity, feedback_intensity, 0.1)

# 播放按鈕點擊動畫
func animate_button_press(button: Control, scale_factor: float = 0.95) -> void:
	if not button or not tween:
		return

	var original_scale = button.scale
	var pressed_scale = original_scale * scale_factor

	# 按下動畫
	tween.tween_property(button, "scale", pressed_scale, 0.1)
	tween.tween_property(button, "scale", original_scale, 0.1)

# 播放滑入動畫
func animate_slide_in(control: Control, direction: String, duration: float = 0.3) -> void:
	if not control or not tween:
		return

	var start_position = control.position
	var offset = Vector2.ZERO

	match direction:
		"left": offset = Vector2(-screen_size.x, 0)
		"right": offset = Vector2(screen_size.x, 0)
		"up": offset = Vector2(0, -screen_size.y)
		"down": offset = Vector2(0, screen_size.y)

	control.position = start_position + offset
	tween.tween_property(control, "position", start_position, duration)

# 播放淡入動畫
func animate_fade_in(control: Control, duration: float = 0.3) -> void:
	if not control or not tween:
		return

	control.modulate.a = 0.0
	control.visible = true
	tween.tween_property(control, "modulate:a", 1.0, duration)

# 播放淡出動畫
func animate_fade_out(control: Control, duration: float = 0.3) -> void:
	if not control or not tween:
		return

	tween.tween_property(control, "modulate:a", 0.0, duration)
	tween.tween_callback(func(): control.visible = false).set_delay(duration)

# === 實用工具方法 ===

# 獲取安全區域尺寸
func get_safe_area() -> Rect2:
	var safe_area = DisplayServer.screen_get_usable_rect()
	return safe_area

# 檢查是否為移動設備
func is_mobile_device() -> bool:
	return OS.has_feature("mobile")

# 獲取觸控點數量
func get_touch_count() -> int:
	return Input.get_current_cursor_shape()

# 檢查是否支援多點觸控
func supports_multitouch() -> bool:
	return OS.has_feature("mobile")

# === 配置方法 ===

# 設置觸覺反饋啟用狀態
func set_haptic_enabled(enabled: bool) -> void:
	haptic_enabled = enabled

# 獲取當前UI縮放因子
func get_ui_scale_factor() -> float:
	return ui_scale_factor

# 獲取螢幕尺寸
func get_screen_size() -> Vector2:
	return screen_size

# 檢查是否為橫屏模式
func is_landscape_mode() -> bool:
	return is_landscape