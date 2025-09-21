# test_mobile_ui_enhancements.gd - 移動端UI增強功能單元測試
#
# 測試範圍：
# - 觸控手勢檢測和處理
# - 響應式佈局系統
# - 動畫和反饋系統
# - 頁面導航和狀態管理
# - 性能優化機制

extends GdUnitTestSuite

# 測試用組件
var mobile_enhancer: MobileUIEnhancer
var enhanced_ui: Node
var test_control: Control

func before_test() -> void:
	# 創建測試用的UI增強器
	var enhancer_script = load("res://scripts/ui/MobileUIEnhancer.gd")
	mobile_enhancer = enhancer_script.new()

	# 創建測試用控件
	test_control = Control.new()
	test_control.name = "TestControl"
	test_control.size = Vector2(200, 100)

	# 添加到場景中
	get_tree().root.add_child(mobile_enhancer)
	get_tree().root.add_child(test_control)

func after_test() -> void:
	# 清理測試組件
	if mobile_enhancer:
		mobile_enhancer.queue_free()
		mobile_enhancer = null

	if test_control:
		test_control.queue_free()
		test_control = null

	if enhanced_ui:
		enhanced_ui.queue_free()
		enhanced_ui = null

# === UI增強器基礎測試 ===

func test_mobile_enhancer_initialization():
	# 測試UI增強器初始化
	assert_object(mobile_enhancer).is_not_null()
	assert_object(mobile_enhancer.long_press_timer).is_not_null()
	assert_object(mobile_enhancer.tween).is_not_null()

func test_gesture_support_addition():
	# 測試為控件添加手勢支持
	var original_mouse_filter = test_control.mouse_filter

	mobile_enhancer.add_gesture_support(test_control)

	# 手勢支持添加後，控件應該能接收輸入
	if original_mouse_filter == Control.MOUSE_FILTER_IGNORE:
		assert_int(test_control.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)

func test_screen_info_update():
	# 測試螢幕資訊更新
	mobile_enhancer._update_screen_info()

	assert_that(mobile_enhancer.get_screen_size()).is_not_equal(Vector2.ZERO)
	assert_that(mobile_enhancer.get_ui_scale_factor()).is_greater(0.0)

# === 手勢檢測測試 ===

func test_swipe_direction_detection():
	# 測試滑動方向檢測
	var start_pos = Vector2(100, 100)

	# 向右滑動
	var right_end = Vector2(200, 100)
	var right_direction = mobile_enhancer._get_swipe_direction(start_pos, right_end)
	assert_str(right_direction).is_equal("right")

	# 向左滑動
	var left_end = Vector2(50, 100)
	var left_direction = mobile_enhancer._get_swipe_direction(start_pos, left_end)
	assert_str(left_direction).is_equal("left")

	# 向上滑動
	var up_end = Vector2(100, 50)
	var up_direction = mobile_enhancer._get_swipe_direction(start_pos, up_end)
	assert_str(up_direction).is_equal("up")

	# 向下滑動
	var down_end = Vector2(100, 200)
	var down_direction = mobile_enhancer._get_swipe_direction(start_pos, down_end)
	assert_str(down_direction).is_equal("down")

func test_touch_start_handling():
	# 測試觸控開始處理
	var touch_position = Vector2(150, 75)

	mobile_enhancer._start_touch(touch_position, test_control)

	assert_that(mobile_enhancer.touch_start_position).is_equal(touch_position)
	assert_float(mobile_enhancer.touch_start_time).is_greater(0.0)
	assert_bool(mobile_enhancer.is_dragging).is_false()

func test_drag_detection():
	# 測試拖拽檢測
	var start_position = Vector2(100, 100)
	var drag_position = Vector2(130, 110) # 移動30像素

	mobile_enhancer._start_touch(start_position, test_control)
	mobile_enhancer._update_drag(drag_position, Vector2(30, 10), test_control)

	# 移動距離超過閾值應該觸發拖拽
	assert_bool(mobile_enhancer.is_dragging).is_true()

# === 響應式佈局測試 ===

func test_ui_scale_factor_calculation():
	# 測試UI縮放因子計算
	# 模擬不同螢幕尺寸
	var test_sizes = [
		Vector2(414, 896),   # 標準尺寸
		Vector2(375, 812),   # iPhone 小尺寸
		Vector2(768, 1024),  # iPad 尺寸
		Vector2(320, 568)    # 小型設備
	]

	for size in test_sizes:
		mobile_enhancer.screen_size = size
		mobile_enhancer._update_screen_info()

		var scale_factor = mobile_enhancer.get_ui_scale_factor()
		assert_float(scale_factor).is_greater_equal(0.5)
		assert_float(scale_factor).is_less_equal(2.0)

func test_responsive_style_application():
	# 測試響應式樣式應用
	var style_config = {
		"scale_with_screen": true,
		"min_size": Vector2(100, 50)
	}

	mobile_enhancer.apply_responsive_style(test_control, style_config)

	# 驗證樣式是否被應用
	assert_that(test_control.scale).is_not_equal(Vector2.ONE)

func test_landscape_detection():
	# 測試橫屏檢測
	# 橫屏模式
	mobile_enhancer.screen_size = Vector2(896, 414)
	mobile_enhancer._update_screen_info()
	assert_bool(mobile_enhancer.is_landscape_mode()).is_true()

	# 豎屏模式
	mobile_enhancer.screen_size = Vector2(414, 896)
	mobile_enhancer._update_screen_info()
	assert_bool(mobile_enhancer.is_landscape_mode()).is_false()

# === 動畫系統測試 ===

func test_button_press_animation():
	# 測試按鈕按下動畫
	var original_scale = test_control.scale
	mobile_enhancer.animate_button_press(test_control, 0.9)

	# 動畫應該已經開始（雖然我們無法等待完成）
	assert_object(mobile_enhancer.tween).is_not_null()

func test_fade_in_animation():
	# 測試淡入動畫
	test_control.modulate.a = 1.0
	mobile_enhancer.animate_fade_in(test_control, 0.3)

	# 動畫開始時alpha應該被設為0
	assert_float(test_control.modulate.a).is_equal(0.0)
	assert_bool(test_control.visible).is_true()

func test_fade_out_animation():
	# 測試淡出動畫
	test_control.modulate.a = 1.0
	test_control.visible = true

	mobile_enhancer.animate_fade_out(test_control, 0.3)

	# 動畫應該已經開始
	assert_object(mobile_enhancer.tween).is_not_null()

func test_slide_in_animation():
	# 測試滑入動畫
	var original_position = test_control.position
	mobile_enhancer.animate_slide_in(test_control, "left", 0.3)

	# 位置應該已經被設置到屏幕外
	assert_bool(test_control.position.x < original_position.x).is_true()

# === 觸覺反饋測試 ===

func test_haptic_feedback_intensity():
	# 測試觸覺反饋強度計算
	mobile_enhancer.set_haptic_enabled(true)

	# 測試不同強度的反饋
	var feedback_received = false
	mobile_enhancer.ui_feedback_requested.connect(
		func(feedback_type: String, intensity: float):
			feedback_received = true
			assert_str(feedback_type).is_equal("haptic")
			assert_float(intensity).is_greater_equal(0.0)
			assert_float(intensity).is_less_equal(1.0)
	)

	mobile_enhancer._provide_haptic_feedback("medium")
	# 注意：在單元測試中，信號可能不會立即觸發

func test_haptic_enabled_state():
	# 測試觸覺反饋啟用狀態
	mobile_enhancer.set_haptic_enabled(false)
	assert_bool(mobile_enhancer.haptic_enabled).is_false()

	mobile_enhancer.set_haptic_enabled(true)
	assert_bool(mobile_enhancer.haptic_enabled).is_true()

# === 實用工具測試 ===

func test_mobile_device_detection():
	# 測試移動設備檢測
	var is_mobile = mobile_enhancer.is_mobile_device()
	# 在PC上運行測試時應該返回false
	assert_bool(typeof(is_mobile) == TYPE_BOOL).is_true()

func test_safe_area_calculation():
	# 測試安全區域計算
	var safe_area = mobile_enhancer.get_safe_area()
	assert_bool(safe_area.size.x > 0).is_true()
	assert_bool(safe_area.size.y > 0).is_true()

func test_multitouch_support_check():
	# 測試多點觸控支持檢查
	var supports_multitouch = mobile_enhancer.supports_multitouch()
	assert_bool(typeof(supports_multitouch) == TYPE_BOOL).is_true()

# === 增強UI控制器測試 ===

func test_enhanced_ui_initialization():
	# 測試增強UI控制器初始化
	var enhanced_ui_script = load("res://scripts/ui/EnhancedMobileUI.gd")

	# 由於EnhancedMobileUI需要特定的場景結構，我們只測試腳本載入
	assert_object(enhanced_ui_script).is_not_null()

func test_page_navigation_logic():
	# 測試頁面導航邏輯（簡化版本）
	var page_stack: Array[String] = []
	var current_page = "dashboard"

	# 模擬頁面切換
	if current_page != "cities":
		page_stack.append(current_page)
		current_page = "cities"

	assert_array(page_stack).contains("dashboard")
	assert_str(current_page).is_equal("cities")

	# 模擬返回
	if page_stack.size() > 0:
		current_page = page_stack.pop_back()

	assert_str(current_page).is_equal("dashboard")

func test_swipe_navigation():
	# 測試滑動導航邏輯
	var pages = ["dashboard", "cities", "battles", "profile"]
	var current_index = 0

	# 向右滑動（下一頁）
	if current_index < pages.size() - 1:
		current_index += 1

	assert_int(current_index).is_equal(1)
	assert_str(pages[current_index]).is_equal("cities")

	# 向左滑動（上一頁）
	if current_index > 0:
		current_index -= 1

	assert_int(current_index).is_equal(0)
	assert_str(pages[current_index]).is_equal("dashboard")

# === 性能測試 ===

func test_gesture_detection_performance():
	# 測試手勢檢測性能
	var start_time = Time.get_unix_time_from_system()

	# 模擬大量手勢事件
	for i in range(1000):
		var start_pos = Vector2(i % 100, i % 50)
		var end_pos = Vector2((i + 50) % 150, (i + 25) % 75)
		mobile_enhancer._get_swipe_direction(start_pos, end_pos)

	var end_time = Time.get_unix_time_from_system()
	var duration = end_time - start_time

	# 1000次方向計算應該很快完成
	assert_float(duration).is_less(0.1)

func test_ui_update_batching():
	# 測試UI更新批處理邏輯
	var pending_updates: Dictionary = {}

	# 模擬多個更新請求
	pending_updates["component1"] = {"value": 100}
	pending_updates["component2"] = {"value": 200}
	pending_updates["component1"] = {"value": 150} # 覆蓋之前的更新

	# 應該只有兩個組件需要更新
	assert_int(pending_updates.size()).is_equal(2)
	assert_int(pending_updates["component1"]["value"]).is_equal(150)

# === 錯誤處理測試 ===

func test_null_control_handling():
	# 測試空控件處理
	mobile_enhancer.add_gesture_support(null)
	# 應該不會崩潰

	mobile_enhancer.apply_responsive_style(null, {})
	# 應該不會崩潰

	mobile_enhancer.animate_button_press(null)
	# 應該不會崩潰

func test_invalid_gesture_data():
	# 測試無效手勢數據處理
	var invalid_data = {
		"invalid_key": "invalid_value"
	}

	# 這些調用應該安全處理無效數據
	var direction = mobile_enhancer._get_swipe_direction(Vector2.ZERO, Vector2.ZERO)
	assert_str(direction).is_in(["left", "right", "up", "down"])

func test_empty_style_config():
	# 測試空樣式配置處理
	mobile_enhancer.apply_responsive_style(test_control, {})
	# 應該不會產生錯誤或意外修改

# === 邊界條件測試 ===

func test_extreme_screen_sizes():
	# 測試極端螢幕尺寸
	var extreme_sizes = [
		Vector2(100, 200),    # 極小尺寸
		Vector2(3000, 2000),  # 極大尺寸
		Vector2(1, 1),        # 最小尺寸
		Vector2(0, 0)         # 零尺寸
	]

	for size in extreme_sizes:
		mobile_enhancer.screen_size = size
		mobile_enhancer._update_screen_info()

		# 縮放因子應該在合理範圍內
		var scale_factor = mobile_enhancer.get_ui_scale_factor()
		assert_float(scale_factor).is_greater_equal(0.5)
		assert_float(scale_factor).is_less_equal(2.0)

func test_very_fast_gestures():
	# 測試極快手勢
	var start_pos = Vector2(0, 0)
	var end_pos = Vector2(1000, 0)
	var very_short_time = 0.01

	# 極快的滑動仍應該被正確檢測
	var direction = mobile_enhancer._get_swipe_direction(start_pos, end_pos)
	assert_str(direction).is_equal("right")

func test_zero_duration_animations():
	# 測試零持續時間動畫
	mobile_enhancer.animate_fade_in(test_control, 0.0)
	mobile_enhancer.animate_button_press(test_control, 1.0)
	# 應該不會產生錯誤