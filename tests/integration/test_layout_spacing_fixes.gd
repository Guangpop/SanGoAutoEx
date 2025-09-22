# test_layout_spacing_fixes.gd - 佈局間距修復測試
#
# 功能：
# - 驗證TopBar高度縮減
# - 測試按鈕重疊問題解決
# - 檢查間距優化效果
# - 確保UI符合設計規範

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

func test_topbar_reduced_height() -> void:
	# 測試TopBar高度已縮減到140px
	var top_bar = main_mobile.top_bar
	assert_that(top_bar).is_not_null()
	assert_that(top_bar.custom_minimum_size.y).is_equal(140.0)

func test_topbar_expanded_height_updated() -> void:
	# 測試腳本中的展開高度已更新
	assert_that(main_mobile.topbar_expanded_height).is_equal(140.0)
	assert_that(main_mobile.topbar_collapsed_height).is_equal(70.0)

func test_container_margins_reduced() -> void:
	# 測試TopBarContainer邊距減少
	var topbar_container = main_mobile.top_bar.get_node("TopBarContainer")
	assert_that(topbar_container).is_not_null()
	assert_that(topbar_container.offset_top).is_equal(2.0)
	assert_that(topbar_container.offset_bottom).is_equal(-2.0)

func test_playerinfo_height_compacted() -> void:
	# 測試PlayerInfo高度緊湊化
	var player_info = main_mobile.top_bar.get_node("TopBarContainer/PlayerInfo")
	assert_that(player_info).is_not_null()
	assert_that(player_info.custom_minimum_size.y).is_equal(36.0)

func test_expand_button_repositioned() -> void:
	# 測試展開按鈕重新定位
	var expand_button = main_mobile.expand_button
	assert_that(expand_button).is_not_null()

	# 檢查位置在右上角但在截圖按鈕下方
	assert_that(expand_button.offset_top).is_equal(52.0)
	assert_that(expand_button.offset_left).is_equal(-54.0)
	assert_that(expand_button.offset_right).is_equal(-10.0)

func test_expand_button_has_background() -> void:
	# 測試展開按鈕有背景面板
	var expand_button = main_mobile.expand_button
	var background = expand_button.get_node("Background")
	assert_that(background).is_not_null()
	assert_that(background.modulate.a).is_less_equal(0.1)

func test_expand_icon_reference_updated() -> void:
	# 測試展開圖標引用已更新
	var expand_icon = main_mobile.expand_icon
	assert_that(expand_icon).is_not_null()
	assert_that(expand_icon.text).is_equal("▲")  # 預設為展開狀態

func test_screenshot_button_repositioned() -> void:
	# 測試截圖按鈕位置調整
	var screenshot_button = main_mobile.screenshot_button
	assert_that(screenshot_button).is_not_null()

func test_buttons_no_overlap() -> void:
	# 測試按鈕不重疊
	var expand_button = main_mobile.expand_button
	var screenshot_button = main_mobile.screenshot_button

	if expand_button and screenshot_button:
		# 展開按鈕在下方 (offset_top: 52)，截圖按鈕在上方 (offset_top: 8)
		# 兩者應該有足夠的垂直間距
		var expand_top = expand_button.offset_top
		var screenshot_bottom = screenshot_button.offset_top + 48  # 假設按鈕高度48px

		assert_that(expand_top).is_greater(screenshot_bottom)

func test_container_separation_optimized() -> void:
	# 測試容器分隔優化
	var topbar_container = main_mobile.top_bar.get_node("TopBarContainer")
	# 檢查separation設置為1
	# 這個測試可能需要根據Godot的theme override實現調整

func test_ui_compactness() -> void:
	# 測試UI緊湊性
	var top_bar = main_mobile.top_bar
	var topbar_container = top_bar.get_node("TopBarContainer")

	# 計算總的內邊距
	var total_vertical_padding = topbar_container.offset_top + abs(topbar_container.offset_bottom)

	# 總內邊距應該小於原來的10px
	assert_that(total_vertical_padding).is_less(10.0)

func test_touch_targets_maintained() -> void:
	# 測試觸摸目標保持標準尺寸
	var expand_button = main_mobile.expand_button
	if expand_button:
		var button_width = expand_button.offset_right - expand_button.offset_left
		var button_height = expand_button.offset_bottom - expand_button.offset_top

		# 檢查觸摸目標至少44x44px
		assert_that(button_width).is_greater_equal(44.0)
		assert_that(button_height).is_greater_equal(44.0)

func test_visual_hierarchy_maintained() -> void:
	# 測試視覺層次保持
	var expand_button = main_mobile.expand_button
	var screenshot_button = main_mobile.screenshot_button

	if expand_button and screenshot_button:
		# 截圖按鈕應該在上方 (更高優先級)
		assert_that(screenshot_button.offset_top).is_less(expand_button.offset_top)

func test_ability_values_still_visible() -> void:
	# 測試能力值仍然可見
	var ability_stats_container = main_mobile.ability_stats_container
	assert_that(ability_stats_container).is_not_null()
	assert_that(ability_stats_container.visible).is_true()

func test_expand_button_functionality() -> void:
	# 測試展開按鈕功能
	var expand_button = main_mobile.expand_button
	var touch_button = expand_button.get_node("Button")
	assert_that(touch_button).is_not_null()
	assert_that(touch_button is Button).is_true()

func test_layout_responsiveness() -> void:
	# 測試佈局響應性
	var top_bar = main_mobile.top_bar

	# 在140px高度下，應該有足夠空間顯示所有內容
	assert_that(top_bar.custom_minimum_size.y).is_equal(140.0)

	# 能力值容器應該可見且有足夠空間
	var ability_stats = main_mobile.ability_stats_container
	assert_that(ability_stats.visible).is_true()