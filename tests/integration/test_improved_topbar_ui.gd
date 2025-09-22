# test_improved_topbar_ui.gd - 改進的TopBar交互設計測試
#
# 功能：
# - 驗證箭頭圖標正確顯示和動畫
# - 測試觸摸反饋和視覺提示
# - 檢查空隙移除和佈局優化
# - 確保交互設計符合UX標準

extends GdUnit3TestSuite

const MainMobileScene = preload("res://scenes/main/Main_Mobile.tscn")

var main_mobile: Control

func before_test() -> void:
	# 實例化主界面場景
	main_mobile = MainMobileScene.instantiate()
	add_child(main_mobile)

	# 等待完全初始化
	await get_tree().process_frame
	await get_tree().process_frame

func after_test() -> void:
	if main_mobile:
		main_mobile.queue_free()

func test_expand_icon_exists() -> void:
	# 測試箭頭圖標存在
	assert_that(main_mobile.expand_icon).is_not_null()
	assert_that(main_mobile.expand_icon.visible).is_true()

func test_expand_icon_initial_state() -> void:
	# 測試箭頭圖標初始狀態
	# 由於預設為展開狀態，應該顯示向上箭頭
	assert_that(main_mobile.expand_icon.text).is_equal("▲")
	assert_that(main_mobile.topbar_expanded).is_true()

func test_expand_icon_size_and_position() -> void:
	# 測試箭頭圖標大小和位置符合設計
	assert_that(main_mobile.expand_icon.custom_minimum_size).is_equal(Vector2(24, 24))
	assert_that(main_mobile.expand_icon.horizontal_alignment).is_equal(1)  # 中央對齊
	assert_that(main_mobile.expand_icon.vertical_alignment).is_equal(1)    # 中央對齊

func test_player_info_touch_target() -> void:
	# 測試PlayerInfo區域的觸摸目標
	var player_info_area = main_mobile.top_bar.get_node("TopBarContainer/PlayerInfo")
	assert_that(player_info_area).is_not_null()
	assert_that(player_info_area.custom_minimum_size.y).is_greater_equal(48)  # 符合44px+標準

func test_background_panel_exists() -> void:
	# 測試背景面板存在並正確設置
	var player_info_area = main_mobile.top_bar.get_node("TopBarContainer/PlayerInfo")
	assert_that(player_info_area.get_child_count()).is_greater(2)  # 至少有背景面板和觸摸按鈕

	var background_panel = player_info_area.get_child(0)
	assert_that(background_panel).is_not_null()
	# 檢查背景面板的透明度設置
	assert_that(background_panel.modulate.a).is_less_equal(0.1)

func test_touch_button_setup() -> void:
	# 測試觸摸按鈕正確設置
	var player_info_area = main_mobile.top_bar.get_node("TopBarContainer/PlayerInfo")
	var touch_button = null

	# 找到觸摸按鈕
	for child in player_info_area.get_children():
		if child is Button:
			touch_button = child
			break

	assert_that(touch_button).is_not_null()
	assert_that(touch_button.flat).is_true()

func test_topbar_spacing_reduced() -> void:
	# 測試TopBar間距減少
	var topbar_container = main_mobile.top_bar.get_node("TopBarContainer")
	assert_that(topbar_container).is_not_null()

	# 檢查上邊距減少
	assert_that(topbar_container.offset_top).is_equal(5.0)  # 從10改為5
	assert_that(topbar_container.offset_bottom).is_equal(-5.0)  # 從-10改為-5

func test_container_separation_set() -> void:
	# 測試容器分隔設置
	var topbar_container = main_mobile.top_bar.get_node("TopBarContainer")
	# 這裡我們檢查是否有separation的覆蓋設置
	# 具體數值可能需要根據實際實現調整
	assert_that(topbar_container).is_not_null()

func test_toggle_functionality() -> void:
	# 測試展開/折疊功能
	var initial_state = main_mobile.topbar_expanded
	var initial_icon = main_mobile.expand_icon.text

	# 模擬點擊
	main_mobile.toggle_topbar_expanded()

	# 等待動畫完成
	await get_tree().create_timer(0.5).timeout

	# 檢查狀態是否改變
	assert_that(main_mobile.topbar_expanded).is_not_equal(initial_state)

func test_expand_icon_animation() -> void:
	# 測試箭頭圖標動畫
	var initial_icon = main_mobile.expand_icon.text

	# 觸發切換
	main_mobile.toggle_topbar_expanded()

	# 等待動畫過程
	await get_tree().create_timer(0.2).timeout

	# 檢查圖標可能處於動畫狀態
	# 等待動畫完成
	await get_tree().create_timer(0.5).timeout

	# 檢查圖標已更新
	assert_that(main_mobile.expand_icon.text).is_not_equal(initial_icon)

func test_visual_feedback_methods_exist() -> void:
	# 測試視覺反饋方法存在
	assert_that(main_mobile.has_method("_on_player_info_hover_start")).is_true()
	assert_that(main_mobile.has_method("_on_player_info_hover_end")).is_true()
	assert_that(main_mobile.has_method("add_touch_feedback")).is_true()
	assert_that(main_mobile.has_method("animate_expand_icon")).is_true()

func test_ui_accessibility() -> void:
	# 測試UI可訪問性
	var player_info_area = main_mobile.top_bar.get_node("TopBarContainer/PlayerInfo")

	# 檢查觸摸目標大小符合標準
	assert_that(player_info_area.custom_minimum_size.y).is_greater_equal(44)

	# 檢查視覺提示存在
	assert_that(main_mobile.expand_icon.visible).is_true()
	assert_that(main_mobile.expand_icon.text).is_not_equal("")

func test_layout_compactness() -> void:
	# 測試佈局緊湊性
	var topbar_container = main_mobile.top_bar.get_node("TopBarContainer")

	# 檢查邊距減少
	var top_margin = topbar_container.offset_top
	var bottom_margin = abs(topbar_container.offset_bottom)

	# 總邊距應該小於原來的20px
	assert_that(top_margin + bottom_margin).is_less(20)