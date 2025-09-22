# ScreenshotButton.gd - 截圖按鈕控制器
#
# 功能：
# - 提供遊戲截圖功能用於調試
# - 保存截圖到專案的/screenshots目錄
# - 移動端友好的按鈕設計
# - 視覺反饋和錯誤處理

extends Control

# UI節點引用
@onready var button = $Button
@onready var feedback_label = $FeedbackLabel
@onready var background = $Background

# 截圖設置
var screenshot_directory: String = "screenshots"
var screenshot_count: int = 0

func _ready() -> void:
	# 連接按鈕事件
	button.pressed.connect(_on_screenshot_button_pressed)

	# 設置按鈕樣式
	button.theme_override_font_sizes["font_size"] = 24

	# 確保截圖目錄存在
	_ensure_screenshot_directory()

	# 支持快捷鍵
	_setup_input_handling()

	LogManager.info("ScreenshotButton", "截圖按鈕初始化完成", {
		"directory": screenshot_directory,
		"button_ready": true
	})

func _setup_input_handling() -> void:
	# 讓控件可以接收輸入
	set_process_input(true)

func _input(event: InputEvent) -> void:
	# F12快捷鍵觸發截圖
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F12:
			_take_screenshot()

func _on_screenshot_button_pressed() -> void:
	LogManager.debug("ScreenshotButton", "截圖按鈕被點擊")

	# 播放點擊動畫
	_play_button_animation()

	# 執行截圖
	_take_screenshot()

func _take_screenshot() -> void:
	var screenshot_start_time = Time.get_unix_time_from_system()

	LogManager.info("ScreenshotButton", "開始擷取螢幕截圖", {
		"timestamp": screenshot_start_time,
		"screenshot_number": screenshot_count + 1
	})

	# 等待一幀確保UI完全渲染
	await get_tree().process_frame

	# 獲取當前視窗的圖像
	var viewport = get_viewport()
	var image = viewport.get_texture().get_image()

	if image == null:
		_show_error_feedback("截圖失敗：無法獲取視窗圖像")
		return

	# 生成文件名
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var filename = "screenshot_%s.png" % timestamp
	var full_path = screenshot_directory + "/" + filename

	# 保存圖片
	var save_result = image.save_png(full_path)

	var screenshot_duration = Time.get_unix_time_from_system() - screenshot_start_time

	if save_result == OK:
		screenshot_count += 1

		LogManager.info("ScreenshotButton", "截圖保存成功", {
			"filename": filename,
			"full_path": full_path,
			"file_size_bytes": _get_file_size(full_path),
			"screenshot_duration": screenshot_duration,
			"total_screenshots": screenshot_count
		})

		_show_success_feedback("截圖已保存: " + filename)
	else:
		LogManager.error("ScreenshotButton", "截圖保存失敗", {
			"filename": filename,
			"error_code": save_result,
			"full_path": full_path
		})

		_show_error_feedback("截圖保存失敗")

func _ensure_screenshot_directory() -> void:
	var dir = DirAccess.open(".")
	if dir == null:
		LogManager.error("ScreenshotButton", "無法訪問專案目錄")
		return

	if not dir.dir_exists(screenshot_directory):
		var create_result = dir.make_dir(screenshot_directory)
		if create_result == OK:
			LogManager.info("ScreenshotButton", "截圖目錄創建成功", {
				"directory": screenshot_directory
			})
		else:
			LogManager.error("ScreenshotButton", "截圖目錄創建失敗", {
				"directory": screenshot_directory,
				"error_code": create_result
			})

func _get_file_size(file_path: String) -> int:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return -1

	var size = file.get_length()
	file.close()
	return size

func _play_button_animation() -> void:
	# 按鈕縮放動畫
	var tween = create_tween()
	tween.set_parallel(true)

	# 縮放效果
	tween.tween_property(button, "scale", Vector2(0.9, 0.9), 0.1)
	tween.tween_property(button, "scale", Vector2.ONE, 0.1).set_delay(0.1)

	# 背景閃爍效果
	tween.tween_property(background, "modulate:a", 0.6, 0.1)
	tween.tween_property(background, "modulate:a", 0.3, 0.1).set_delay(0.1)

func _show_success_feedback(message: String) -> void:
	feedback_label.text = message
	feedback_label.modulate = Color.GREEN

	var tween = create_tween()
	tween.set_parallel(true)

	# 淡入
	tween.tween_property(feedback_label, "modulate:a", 1.0, 0.2)
	# 停留
	tween.tween_property(feedback_label, "modulate:a", 1.0, 1.5).set_delay(0.2)
	# 淡出
	tween.tween_property(feedback_label, "modulate:a", 0.0, 0.5).set_delay(1.7)

func _show_error_feedback(message: String) -> void:
	feedback_label.text = message
	feedback_label.modulate = Color.RED

	var tween = create_tween()
	tween.set_parallel(true)

	# 淡入
	tween.tween_property(feedback_label, "modulate:a", 1.0, 0.2)
	# 停留
	tween.tween_property(feedback_label, "modulate:a", 1.0, 2.0).set_delay(0.2)
	# 淡出
	tween.tween_property(feedback_label, "modulate:a", 0.0, 0.5).set_delay(2.2)

# 公共方法：外部調用截圖
func capture_screenshot() -> void:
	_take_screenshot()

# 公共方法：獲取截圖統計
func get_screenshot_stats() -> Dictionary:
	return {
		"total_screenshots": screenshot_count,
		"directory": screenshot_directory,
		"directory_exists": DirAccess.open(".").dir_exists(screenshot_directory)
	}