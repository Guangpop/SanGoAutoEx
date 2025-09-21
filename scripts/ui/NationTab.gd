# NationTab.gd - 國家標籤頁UI界面
#
# 功能：
# - 城池總覽卡片式顯示
# - 國家資源統計儀表板
# - 發展政策設置面板
# - 與NationManager的實時數據整合
# - 移動端優化的觸控界面 (414x896)

extends Control

# UI節點引用 (程序生成)
var main_container: VBoxContainer
var header_panel: HBoxContainer
var stats_dashboard: Control
var cities_overview: ScrollContainer
var cities_container: VBoxContainer
var policies_panel: Control
var refresh_button: Button

# 數據緩存
var current_nation_stats: Dictionary = {}
var city_cards: Dictionary = {}  # city_id -> card_node

# UI狀態
var ui_initialized: bool = false
var data_refresh_timer: Timer

func _ready() -> void:
	LogManager.info("NationTab", "國家標籤頁初始化開始")

	# 等待NationManager準備就緒
	await wait_for_dependencies()

	# 建立UI界面
	setup_ui()

	# 連接事件處理器
	connect_events()

	# 加載初始數據
	refresh_nation_data()

	# 設置定期更新
	setup_periodic_refresh()

	ui_initialized = true

	LogManager.info("NationTab", "國家標籤頁初始化完成", {
		"ui_components_created": main_container != null,
		"events_connected": true,
		"initial_data_loaded": current_nation_stats.size() > 0
	})

# 等待依賴系統
func wait_for_dependencies() -> void:
	var max_wait_time = 10.0
	var wait_start = Time.get_unix_time_from_system()

	while not NationManager:
		await get_tree().process_frame
		var elapsed = Time.get_unix_time_from_system() - wait_start
		if elapsed > max_wait_time:
			LogManager.warn("NationTab", "等待NationManager超時")
			break

# 設置UI界面
func setup_ui() -> void:
	# 創建主容器
	main_container = VBoxContainer.new()
	add_child(main_container)

	# 創建頂部面板
	create_header_panel()

	# 創建統計儀表板
	create_stats_dashboard()

	# 創建城池總覽區域
	create_cities_overview()

	# 創建政策設置面板
	create_policies_panel()

	LogManager.debug("NationTab", "UI界面創建完成")

# 創建頂部面板
func create_header_panel() -> void:
	header_panel = HBoxContainer.new()
	header_panel.custom_minimum_size = Vector2(0, 50)
	main_container.add_child(header_panel)

	# 標題
	var title_label = Label.new()
	title_label.text = "帝國管理"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_panel.add_child(title_label)

	# 刷新按鈕
	refresh_button = Button.new()
	refresh_button.text = "刷新"
	refresh_button.custom_minimum_size = Vector2(80, 48)  # 48px 觸控標準
	header_panel.add_child(refresh_button)

# 創建統計儀表板
func create_stats_dashboard() -> void:
	# 統計面板容器
	stats_dashboard = Panel.new()
	stats_dashboard.custom_minimum_size = Vector2(0, 120)
	main_container.add_child(stats_dashboard)

	var stats_container = VBoxContainer.new()
	stats_dashboard.add_child(stats_container)

	# 第一行：城池和區域
	var row1 = HBoxContainer.new()
	stats_container.add_child(row1)

	var cities_stat = create_stat_item("城池", "0", "城")
	var regions_stat = create_stat_item("區域", "0", "圖")
	row1.add_child(cities_stat)
	row1.add_child(regions_stat)

	# 第二行：人口和軍力
	var row2 = HBoxContainer.new()
	stats_container.add_child(row2)

	var population_stat = create_stat_item("人口", "0", "民")
	var military_stat = create_stat_item("軍力", "0", "兵")
	row2.add_child(population_stat)
	row2.add_child(military_stat)

	# 第三行：經濟和國力
	var row3 = HBoxContainer.new()
	stats_container.add_child(row3)

	var economic_stat = create_stat_item("經濟", "0", "金")
	var power_stat = create_stat_item("國力", "0", "力")
	row3.add_child(economic_stat)
	row3.add_child(power_stat)

# 創建統計項目
func create_stat_item(label: String, value: String, icon: String) -> Control:
	var item = VBoxContainer.new()
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.custom_minimum_size = Vector2(0, 30)

	# 圖標和數值
	var top_row = HBoxContainer.new()
	item.add_child(top_row)

	var icon_label = Label.new()
	icon_label.text = icon
	icon_label.add_theme_font_size_override("font_size", 18)
	top_row.add_child(icon_label)

	var value_label = Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(value_label)

	# 標籤
	var label_node = Label.new()
	label_node.text = label
	label_node.add_theme_font_size_override("font_size", 14)
	label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.add_child(label_node)

	# 設置名稱以便後續查找
	item.name = label + "_stat"

	return item

# 創建城池總覽
func create_cities_overview() -> void:
	# 區域標題
	var cities_title = Label.new()
	cities_title.text = "城池總覽"
	cities_title.add_theme_font_size_override("font_size", 18)
	cities_title.custom_minimum_size = Vector2(0, 30)
	main_container.add_child(cities_title)

	# 滾動容器
	cities_overview = ScrollContainer.new()
	cities_overview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cities_overview.custom_minimum_size = Vector2(0, 200)
	main_container.add_child(cities_overview)

	# 城池容器
	cities_container = VBoxContainer.new()
	cities_overview.add_child(cities_container)

# 創建政策設置面板
func create_policies_panel() -> void:
	# 政策標題
	var policies_title = Label.new()
	policies_title.text = "發展政策"
	policies_title.add_theme_font_size_override("font_size", 18)
	policies_title.custom_minimum_size = Vector2(0, 30)
	main_container.add_child(policies_title)

	# 政策面板
	policies_panel = Panel.new()
	policies_panel.custom_minimum_size = Vector2(0, 160)
	main_container.add_child(policies_panel)

	var policies_container = VBoxContainer.new()
	policies_panel.add_child(policies_container)

	# 創建政策滑塊
	create_policy_slider("軍事重點", "military_focus", policies_container)
	create_policy_slider("經濟重點", "economic_focus", policies_container)
	create_policy_slider("科技重點", "technology_focus", policies_container)
	create_policy_slider("民生重點", "population_focus", policies_container)

# 創建政策滑塊
func create_policy_slider(label: String, policy_key: String, parent: Control) -> void:
	var slider_row = HBoxContainer.new()
	slider_row.custom_minimum_size = Vector2(0, 36)
	parent.add_child(slider_row)

	# 標籤
	var label_node = Label.new()
	label_node.text = label
	label_node.add_theme_font_size_override("font_size", 16)
	label_node.custom_minimum_size = Vector2(80, 0)
	slider_row.add_child(label_node)

	# 滑塊
	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.1
	slider.value = 0.3  # 默認值
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 48)  # 48px 觸控標準
	slider.name = policy_key + "_slider"
	slider_row.add_child(slider)

	# 數值顯示
	var value_label = Label.new()
	value_label.text = "30%"
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.custom_minimum_size = Vector2(50, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.name = policy_key + "_value"
	slider_row.add_child(value_label)

	# 連接滑塊事件
	slider.value_changed.connect(func(value: float): _on_policy_slider_changed(policy_key, value))

# 連接事件
func connect_events() -> void:
	if refresh_button:
		refresh_button.pressed.connect(refresh_nation_data)

	if NationManager:
		if NationManager.has_signal("nation_stats_updated"):
			NationManager.nation_stats_updated.connect(_on_nation_stats_updated)
		if NationManager.has_signal("development_policy_changed"):
			NationManager.development_policy_changed.connect(_on_policy_changed)

	LogManager.debug("NationTab", "事件連接完成")

# 設置定期刷新
func setup_periodic_refresh() -> void:
	data_refresh_timer = Timer.new()
	data_refresh_timer.wait_time = 10.0  # 每10秒刷新一次
	data_refresh_timer.autostart = true
	data_refresh_timer.timeout.connect(refresh_nation_data)
	add_child(data_refresh_timer)

# === 數據刷新和顯示 ===

# 刷新國家數據
func refresh_nation_data() -> void:
	if not NationManager:
		LogManager.warn("NationTab", "NationManager未找到，無法刷新數據")
		return

	# 獲取最新統計
	current_nation_stats = NationManager.get_nation_stats()

	# 更新統計顯示
	update_stats_display()

	# 更新城池顯示
	update_cities_display()

	# 更新政策顯示
	update_policies_display()

	LogManager.debug("NationTab", "國家數據刷新完成", {
		"cities": current_nation_stats.get("total_cities", 0),
		"regions": current_nation_stats.get("controlled_regions", []).size()
	})

# 更新統計顯示
func update_stats_display() -> void:
	if not stats_dashboard:
		return

	# 更新各項統計
	update_stat_value("城池_stat", str(current_nation_stats.get("total_cities", 0)))
	update_stat_value("區域_stat", str(current_nation_stats.get("controlled_regions", []).size()))
	update_stat_value("人口_stat", format_number(current_nation_stats.get("total_population", 0)))
	update_stat_value("軍力_stat", format_number(current_nation_stats.get("military_strength", 0)))
	update_stat_value("經濟_stat", format_number(current_nation_stats.get("economic_power", 0)))

	# 計算國力
	var nation_power = NationManager.calculate_nation_power() if NationManager else 0.0
	update_stat_value("國力_stat", "%.1f" % nation_power)

# 更新統計數值
func update_stat_value(stat_name: String, value: String) -> void:
	var stat_item = stats_dashboard.find_child(stat_name, true, false)
	if stat_item:
		var value_label = stat_item.get_child(0).get_child(1)
		if value_label:
			value_label.text = value

# 更新城池顯示
func update_cities_display() -> void:
	if not cities_container or not CityManager:
		return

	# 清除舊的城池卡片
	for child in cities_container.get_children():
		child.queue_free()
	city_cards.clear()

	# 獲取玩家控制的城池
	var controlled_cities = CityManager.get_player_cities()

	for city_id in controlled_cities:
		var city_data = CityManager.get_city_data(city_id)
		if city_data:
			var city_card = create_city_card(city_id, city_data)
			cities_container.add_child(city_card)
			city_cards[city_id] = city_card

# 創建城池卡片
func create_city_card(city_id: String, city_data: Dictionary) -> Control:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(0, 80)

	var card_container = HBoxContainer.new()
	card.add_child(card_container)

	# 城池圖標
	var icon = Label.new()
	icon.text = "城"
	icon.add_theme_font_size_override("font_size", 32)
	icon.custom_minimum_size = Vector2(48, 48)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_container.add_child(icon)

	# 城池信息
	var info_container = VBoxContainer.new()
	info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_container.add_child(info_container)

	# 城池名稱和等級
	var name_level = Label.new()
	name_level.text = "%s Lv.%d" % [city_data.get("name", city_id), city_data.get("level", 1)]
	name_level.add_theme_font_size_override("font_size", 18)
	info_container.add_child(name_level)

	# 人口和駐軍
	var stats_row = HBoxContainer.new()
	info_container.add_child(stats_row)

	var population_label = Label.new()
	population_label.text = "人口: %s" % format_number(city_data.get("population", 0))
	population_label.add_theme_font_size_override("font_size", 14)
	stats_row.add_child(population_label)

	var garrison_label = Label.new()
	garrison_label.text = "駐軍: %s" % format_number(city_data.get("garrison", 0))
	garrison_label.add_theme_font_size_override("font_size", 14)
	stats_row.add_child(garrison_label)

	# 發展按鈕
	var develop_button = Button.new()
	develop_button.text = "發展"
	develop_button.custom_minimum_size = Vector2(80, 48)
	develop_button.pressed.connect(_on_city_develop_pressed.bind(city_id))
	card_container.add_child(develop_button)

	return card

# 更新政策顯示
func update_policies_display() -> void:
	if not NationManager or not policies_panel:
		return

	var current_policies = NationManager.get_all_policies()

	for policy_key in current_policies:
		var value = current_policies[policy_key]
		update_policy_slider(policy_key, value)

# 更新政策滑塊
func update_policy_slider(policy_key: String, value: float) -> void:
	var slider = policies_panel.find_child(policy_key + "_slider", true, false)
	var value_label = policies_panel.find_child(policy_key + "_value", true, false)

	if slider:
		slider.value = value
	if value_label:
		value_label.text = "%.0f%%" % (value * 100)

# === 事件處理器 ===

# 國家統計更新
func _on_nation_stats_updated(stats: Dictionary) -> void:
	current_nation_stats = stats
	if ui_initialized:
		update_stats_display()
		update_cities_display()

# 政策變更
func _on_policy_changed(policy_type: String, new_value: float) -> void:
	update_policy_slider(policy_type, new_value)

# 政策滑塊變更
func _on_policy_slider_changed(policy_key: String, value: float) -> void:
	if NationManager:
		NationManager.set_development_policy(policy_key, value)

	# 更新顯示
	update_policy_slider(policy_key, value)

	LogManager.debug("NationTab", "政策設置變更", {
		"policy": policy_key,
		"value": value
	})

# 城池發展按鈕
func _on_city_develop_pressed(city_id: String) -> void:
	# 顯示發展選項對話框
	show_city_development_dialog(city_id)

# 顯示城池發展對話框
func show_city_development_dialog(city_id: String) -> void:
	# 簡單的發展項目選擇
	var dialog = AcceptDialog.new()
	dialog.title = "城池發展 - " + city_id
	dialog.dialog_text = "選擇發展項目:\n\n基礎建設 (成本: 1000金)\n經濟發展 (成本: 800金)\n軍事設施 (成本: 1200金)"

	add_child(dialog)
	dialog.popup_centered()

	# 簡化版：直接開始基礎建設發展
	await dialog.confirmed
	dialog.queue_free()

	if NationManager:
		var cost = {"gold": 1000}
		var success = NationManager.start_city_development(city_id, "infrastructure", cost)

		if success:
			LogManager.info("NationTab", "城池發展項目開始", {"city": city_id, "type": "infrastructure"})
		else:
			LogManager.warn("NationTab", "城池發展項目開始失敗", {"city": city_id})

# === 輔助方法 ===

# 格式化數字顯示
func format_number(number: int) -> String:
	if number >= 10000:
		return "%.1fK" % (number / 1000.0)
	elif number >= 1000:
		return "%.1fK" % (number / 1000.0)
	else:
		return str(number)

# 獲取當前國家統計
func get_current_nation_stats() -> Dictionary:
	return current_nation_stats.duplicate()

# 檢查UI是否已初始化
func is_ui_initialized() -> bool:
	return ui_initialized