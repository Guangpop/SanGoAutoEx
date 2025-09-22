# test_ability_values_display.gd - 能力值顯示測試
#
# 功能：
# - 驗證玩家能力值正確顯示在界面上
# - 測試TopBar初始狀態為展開
# - 檢查能力值標籤是否可見且包含正確數據

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

func test_topbar_initially_expanded() -> void:
	# 測試TopBar初始狀態為展開
	assert_that(main_mobile.topbar_expanded).is_true()

func test_ability_stats_container_visible() -> void:
	# 測試能力值容器可見
	var ability_stats_container = main_mobile.ability_stats_container
	assert_that(ability_stats_container).is_not_null()
	assert_that(ability_stats_container.visible).is_true()

func test_all_ability_labels_exist() -> void:
	# 測試所有能力值標籤存在
	assert_that(main_mobile.wuli_label).is_not_null()
	assert_that(main_mobile.zhili_label).is_not_null()
	assert_that(main_mobile.tongzhi_label).is_not_null()
	assert_that(main_mobile.zhengzhi_label).is_not_null()
	assert_that(main_mobile.meili_label).is_not_null()
	assert_that(main_mobile.tianming_label).is_not_null()

func test_ability_labels_contain_correct_text() -> void:
	# 測試能力值標籤包含正確文字
	assert_that(main_mobile.wuli_label.text).contains("武力:")
	assert_that(main_mobile.zhili_label.text).contains("智力:")
	assert_that(main_mobile.tongzhi_label.text).contains("統治:")
	assert_that(main_mobile.zhengzhi_label.text).contains("政治:")
	assert_that(main_mobile.meili_label.text).contains("魅力:")
	assert_that(main_mobile.tianming_label.text).contains("天命:")

func test_ability_values_are_numeric() -> void:
	# 測試能力值是數字且大於0 (預設值)
	var wuli_value = _extract_number_from_label(main_mobile.wuli_label.text)
	var zhili_value = _extract_number_from_label(main_mobile.zhili_label.text)
	var tongzhi_value = _extract_number_from_label(main_mobile.tongzhi_label.text)
	var zhengzhi_value = _extract_number_from_label(main_mobile.zhengzhi_label.text)
	var meili_value = _extract_number_from_label(main_mobile.meili_label.text)
	var tianming_value = _extract_number_from_label(main_mobile.tianming_label.text)

	assert_that(wuli_value).is_greater_equal(0)
	assert_that(zhili_value).is_greater_equal(0)
	assert_that(tongzhi_value).is_greater_equal(0)
	assert_that(zhengzhi_value).is_greater_equal(0)
	assert_that(meili_value).is_greater_equal(0)
	assert_that(tianming_value).is_greater_equal(0)

func test_default_ability_values() -> void:
	# 測試預設能力值 (根據GameCore.gd的設定)
	var wuli_value = _extract_number_from_label(main_mobile.wuli_label.text)
	var zhili_value = _extract_number_from_label(main_mobile.zhili_label.text)
	var tongzhi_value = _extract_number_from_label(main_mobile.tongzhi_label.text)
	var zhengzhi_value = _extract_number_from_label(main_mobile.zhengzhi_label.text)
	var meili_value = _extract_number_from_label(main_mobile.meili_label.text)
	var tianming_value = _extract_number_from_label(main_mobile.tianming_label.text)

	# 根據GameCore.gd的預設值檢查
	assert_that(wuli_value).is_equal(20)
	assert_that(zhili_value).is_equal(20)
	assert_that(tongzhi_value).is_equal(20)
	assert_that(zhengzhi_value).is_equal(20)
	assert_that(meili_value).is_equal(20)
	assert_that(tianming_value).is_equal(10)

func test_topbar_height_is_expanded() -> void:
	# 測試TopBar高度為展開狀態
	var top_bar = main_mobile.top_bar
	assert_that(top_bar).is_not_null()
	assert_that(top_bar.custom_minimum_size.y).is_equal(main_mobile.topbar_expanded_height)

func test_ability_labels_visible_in_ui() -> void:
	# 測試所有能力值標籤在UI中可見
	assert_that(main_mobile.wuli_label.visible).is_true()
	assert_that(main_mobile.zhili_label.visible).is_true()
	assert_that(main_mobile.tongzhi_label.visible).is_true()
	assert_that(main_mobile.zhengzhi_label.visible).is_true()
	assert_that(main_mobile.meili_label.visible).is_true()
	assert_that(main_mobile.tianming_label.visible).is_true()

# 輔助方法：從標籤文字中提取數字
func _extract_number_from_label(text: String) -> int:
	var regex = RegEx.new()
	regex.compile("\\d+")
	var result = regex.search(text)
	if result:
		return int(result.get_string())
	return -1