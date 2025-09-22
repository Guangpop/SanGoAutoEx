# test_screenshot_functionality.gd - 截圖功能集成測試
#
# 功能：
# - 驗證截圖按鈕能正確集成到主界面
# - 測試截圖保存功能
# - 檢查目錄創建和文件權限

extends GdUnit3TestSuite

const MainMobileScene = preload("res://scenes/main/Main_Mobile.tscn")

var main_mobile: Control
var screenshot_button: Control

func before_test() -> void:
	# 實例化主界面場景
	main_mobile = MainMobileScene.instantiate()
	add_child(main_mobile)

	# 等待一幀確保所有節點就緒
	await get_tree().process_frame

	# 獲取截圖按鈕引用
	screenshot_button = main_mobile.get_node("ScreenshotButton")

func after_test() -> void:
	if main_mobile:
		main_mobile.queue_free()

func test_screenshot_button_exists() -> void:
	# 測試截圖按鈕是否存在
	assert_that(screenshot_button).is_not_null()
	assert_that(screenshot_button.visible).is_true()

func test_screenshot_button_integration() -> void:
	# 測試主界面是否正確集成截圖按鈕
	assert_that(main_mobile.screenshot_button).is_not_null()
	assert_that(main_mobile.screenshot_button).is_same(screenshot_button)

func test_debug_tools_setup() -> void:
	# 測試調試工具初始化
	var stats = main_mobile.get_debug_screenshot_stats()
	assert_that(stats).contains_key("total_screenshots")
	assert_that(stats).contains_key("directory")
	assert_that(stats["directory"]).is_equal("screenshots")

func test_screenshot_directory_creation() -> void:
	# 測試截圖目錄是否正確創建
	var dir = DirAccess.open(".")
	assert_that(dir.dir_exists("screenshots")).is_true()

func test_screenshot_visibility_control() -> void:
	# 測試截圖按鈕可見性控制
	main_mobile.set_screenshot_button_visible(false)
	assert_that(screenshot_button.visible).is_false()

	main_mobile.set_screenshot_button_visible(true)
	assert_that(screenshot_button.visible).is_true()

func test_screenshot_capture_trigger() -> void:
	# 測試通過主界面觸發截圖
	var initial_stats = main_mobile.get_debug_screenshot_stats()
	var initial_count = initial_stats["total_screenshots"]

	# 模擬截圖觸發
	main_mobile.capture_debug_screenshot()

	# 等待截圖處理完成
	await get_tree().create_timer(0.5).timeout

	var final_stats = main_mobile.get_debug_screenshot_stats()
	var final_count = final_stats["total_screenshots"]

	# 驗證截圖計數增加
	assert_that(final_count).is_greater(initial_count)

func test_screenshot_file_creation() -> void:
	# 測試截圖文件是否正確創建
	var dir = DirAccess.open("screenshots")
	if dir:
		var files_before = []
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".png"):
				files_before.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

		# 觸發截圖
		main_mobile.capture_debug_screenshot()

		# 等待文件保存
		await get_tree().create_timer(0.5).timeout

		var files_after = []
		dir.list_dir_begin()
		file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".png"):
				files_after.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

		# 驗證新文件被創建
		assert_that(files_after.size()).is_greater(files_before.size())

func test_screenshot_button_animation() -> void:
	# 測試截圖按鈕動畫功能
	var button_node = screenshot_button.get_node("Button")
	var original_scale = button_node.scale

	# 模擬按鈕點擊
	button_node.emit_signal("pressed")

	# 等待動畫開始
	await get_tree().process_frame

	# 動畫期間按鈕應該會改變縮放
	# (這個測試可能需要根據實際動畫實現調整)
	await get_tree().create_timer(0.2).timeout

	# 等待動畫完成
	await get_tree().create_timer(0.3).timeout

	# 動畫完成後應該恢復原始縮放
	assert_that(button_node.scale).is_equal(original_scale)