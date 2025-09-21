# GeneralsTab.gd - 武将标签页界面
#
# 功能：
# - 显示玩家拥有的武将列表
# - 武将详细信息面板
# - 武将分配到城池管理
# - 武将招募界面

extends Control

# UI节点引用 (程序生成)
var generals_scroll: ScrollContainer
var generals_container: VBoxContainer
var detail_panel: Control
var general_name_label: Label
var general_portrait: Label
var attributes_container: VBoxContainer
var actions_container: HBoxContainer
# 移除手動招募按鈕，改為顯示招募統計信息
var stats_label: Label

# 当前选中的武将
var selected_general_id: String = ""
var general_cards: Dictionary = {}

# 预制件资源
var general_card_scene: PackedScene

func _ready() -> void:
	name = "GeneralsTab"
	LogManager.info("GeneralsTab", "武将标签页初始化开始")

	# 等待GeneralsManager初始化
	await _wait_for_generals_manager()

	# 创建预制件
	_create_prefabs()

	# 设置UI
	setup_ui()

	# 连接事件
	connect_events()

	# 刷新显示
	refresh_generals_display()

	LogManager.info("GeneralsTab", "武将标签页初始化完成")

# 等待GeneralsManager初始化
func _wait_for_generals_manager() -> void:
	var max_wait_time = 3.0
	var wait_start = Time.get_unix_time_from_system()

	while not GeneralsManager:
		await get_tree().process_frame
		var elapsed = Time.get_unix_time_from_system() - wait_start
		if elapsed > max_wait_time:
			LogManager.warn("GeneralsTab", "等待GeneralsManager超时")
			break

# 创建预制件
func _create_prefabs() -> void:
	# 武将卡片使用程序生成
	general_card_scene = null
	LogManager.info("GeneralsTab", "使用程序生成武将卡片")

# 设置UI
func setup_ui() -> void:
	# 创建主容器
	var main_container = VBoxContainer.new()
	add_child(main_container)

	# 创建顶部区域
	var header_panel = HBoxContainer.new()
	header_panel.custom_minimum_size = Vector2(0, 50)
	main_container.add_child(header_panel)

	# 創建招募統計顯示（只讀模式）
	stats_label = Label.new()
	stats_label.text = "🎯 自動招募模式 | 戰鬥勝利後自動嘗試招募"
	stats_label.add_theme_font_size_override("font_size", 16)
	stats_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	stats_label.custom_minimum_size = Vector2(300, 44)
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_panel.add_child(stats_label)

	# 创建武将区域
	var generals_area = VBoxContainer.new()
	generals_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(generals_area)

	# 创建滚动容器
	generals_scroll = ScrollContainer.new()
	generals_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	generals_scroll.custom_minimum_size = Vector2(0, 200)
	generals_area.add_child(generals_scroll)

	# 创建武将列表容器
	generals_container = VBoxContainer.new()
	generals_container.custom_minimum_size = Vector2(0, 0)
	generals_scroll.add_child(generals_container)

	# 创建详情面板
	detail_panel = Panel.new()
	detail_panel.visible = false
	detail_panel.custom_minimum_size = Vector2(0, 100)
	main_container.add_child(detail_panel)

	# 创建详情面板内容
	var detail_container = VBoxContainer.new()
	detail_panel.add_child(detail_container)

	# 武将信息区域
	var general_info = HBoxContainer.new()
	detail_container.add_child(general_info)

	general_portrait = Label.new()
	general_portrait.text = "將"
	general_portrait.add_theme_font_size_override("font_size", 32)
	general_info.add_child(general_portrait)

	general_name_label = Label.new()
	general_name_label.text = "武将名称"
	general_name_label.add_theme_font_size_override("font_size", 18)
	general_info.add_child(general_name_label)

	# 属性容器
	attributes_container = VBoxContainer.new()
	detail_container.add_child(attributes_container)

	# 操作按钮容器
	actions_container = HBoxContainer.new()
	detail_container.add_child(actions_container)

# 连接事件
func connect_events() -> void:
	# 移除手動招募按鈕相關事件

	if GeneralsManager:
		GeneralsManager.connect("general_recruited", _on_general_recruited)
		GeneralsManager.connect("general_assigned", _on_general_assigned)
		GeneralsManager.connect("general_level_up", _on_general_level_up)

	LogManager.debug("GeneralsTab", "事件连接完成")

# 刷新武将显示
func refresh_generals_display() -> void:
	if not GeneralsManager or not generals_container:
		return

	# 清空现有卡片
	for child in generals_container.get_children():
		child.queue_free()
	general_cards.clear()

	# 获取玩家武将
	var player_generals = GeneralsManager.get_player_generals()

	if player_generals.is_empty():
		_show_empty_state()
		return

	# 创建武将卡片
	for general_id in player_generals:
		var general_data = player_generals[general_id]
		var card = _create_general_card(general_id, general_data)
		if card:
			generals_container.add_child(card)
			general_cards[general_id] = card

	LogManager.debug("GeneralsTab", "武将显示刷新完成", {
		"generals_count": player_generals.size()
	})

# 显示空状态
func _show_empty_state() -> void:
	var empty_label = Label.new()
	empty_label.text = "暂无武将\n征服城池後有機會自動招募武將"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.add_theme_font_size_override("font_size", 16)
	empty_label.custom_minimum_size = Vector2(0, 200)
	generals_container.add_child(empty_label)

# 创建武将卡片
func _create_general_card(general_id: String, general_data: Dictionary) -> Control:
	var card: Control

	# 尝试使用预制件
	if general_card_scene:
		card = general_card_scene.instantiate()
		card.setup_general_data(general_id, general_data)
	else:
		# 程序生成卡片
		card = _create_programmatic_card(general_id, general_data)

	# 连接点击事件
	if card and card.has_signal("general_selected"):
		card.connect("general_selected", _on_general_card_selected)
	elif card:
		# 为程序生成的卡片添加点击检测
		var button = card.get_node_or_null("CardButton")
		if button:
			button.pressed.connect(_on_general_card_selected.bind(general_id))

	return card

# 程序生成武将卡片
func _create_programmatic_card(general_id: String, general_data: Dictionary) -> Control:
	var card = Panel.new()
	card.name = "GeneralCard_" + general_id
	card.custom_minimum_size = Vector2(0, 80)

	# 卡片按钮
	var button = Button.new()
	button.name = "CardButton"
	button.flat = true
	button.custom_minimum_size = Vector2(0, 80)
	card.add_child(button)

	# 设置按钮布局
	button.anchors_preset = Control.PRESET_FULL_RECT

	# 卡片内容容器
	var content = HBoxContainer.new()
	content.name = "Content"
	button.add_child(content)
	content.anchors_preset = Control.PRESET_FULL_RECT
	content.add_theme_constant_override("separation", 10)

	# 武将头像
	var portrait = Label.new()
	portrait.text = "將"  # 使用中文字作为头像占位符
	portrait.add_theme_font_size_override("font_size", 32)
	portrait.custom_minimum_size = Vector2(60, 60)
	portrait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(portrait)

	# 武将信息
	var info_container = VBoxContainer.new()
	info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(info_container)

	# 武将姓名和等级
	var name_level = Label.new()
	var level = general_data.get("level", 1)
	var name = general_data.get("name", "未知武将")
	var title = general_data.get("title", "")
	name_level.text = "%s Lv.%d" % [name, level]
	if not title.is_empty():
		name_level.text += " (%s)" % title
	name_level.add_theme_font_size_override("font_size", 16)
	info_container.add_child(name_level)

	# 武将属性
	var attributes = general_data.get("attributes", {})
	var attr_text = "武力:%d 智力:%d 统治:%d" % [
		attributes.get("武力", 0),
		attributes.get("智力", 0),
		attributes.get("统治", 0)
	]
	var attr_label = Label.new()
	attr_label.text = attr_text
	attr_label.add_theme_font_size_override("font_size", 14)
	info_container.add_child(attr_label)

	# 分配状态
	var assignment = general_data.get("assigned_city", "")
	var status_label = Label.new()
	if assignment.is_empty():
		status_label.text = "状态: 待分配"
		status_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		status_label.text = "驻守: %s" % assignment
		status_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	status_label.add_theme_font_size_override("font_size", 12)
	info_container.add_child(status_label)

	# 战力显示
	var power = GeneralsManager.calculate_general_power(general_id)
	var power_container = VBoxContainer.new()
	power_container.custom_minimum_size = Vector2(80, 0)
	content.add_child(power_container)

	var power_label = Label.new()
	power_label.text = "战力"
	power_label.add_theme_font_size_override("font_size", 12)
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_container.add_child(power_label)

	var power_value = Label.new()
	power_value.text = str(int(power))
	power_value.add_theme_font_size_override("font_size", 18)
	power_value.add_theme_color_override("font_color", Color.GOLD)
	power_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_container.add_child(power_value)

	return card

# 显示武将详情
func show_general_details(general_id: String) -> void:
	selected_general_id = general_id

	if not GeneralsManager or not detail_panel:
		return

	var general_data = GeneralsManager.get_player_general(general_id)
	if general_data.is_empty():
		return

	# 显示详情面板
	detail_panel.visible = true

	# 更新武将信息
	if general_name_label:
		var name = general_data.get("name", "")
		var title = general_data.get("title", "")
		var level = general_data.get("level", 1)
		general_name_label.text = "%s Lv.%d" % [name, level]
		if not title.is_empty():
			general_name_label.text += "\n(%s)" % title

	# 更新属性显示
	_update_attributes_display(general_data)

	# 更新操作按钮
	_update_actions_display(general_id, general_data)

	LogManager.debug("GeneralsTab", "显示武将详情", {
		"general": general_data.get("name", ""),
		"general_id": general_id
	})

# 更新属性显示
func _update_attributes_display(general_data: Dictionary) -> void:
	if not attributes_container:
		return

	# 清空现有属性
	for child in attributes_container.get_children():
		child.queue_free()

	var attributes = general_data.get("attributes", {})

	# 创建属性网格
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 5)
	attributes_container.add_child(grid)

	# 显示六项属性
	var attr_names = ["武力", "智力", "统治", "政治", "魅力", "天命"]
	for attr_name in attr_names:
		var value = attributes.get(attr_name, 0)

		var name_label = Label.new()
		name_label.text = attr_name + ":"
		name_label.add_theme_font_size_override("font_size", 14)
		grid.add_child(name_label)

		var value_label = Label.new()
		value_label.text = str(value)
		value_label.add_theme_font_size_override("font_size", 14)
		value_label.add_theme_color_override("font_color", Color.CYAN)
		grid.add_child(value_label)

	# 显示特殊技能
	var special_abilities = general_data.get("special_abilities", [])
	if not special_abilities.is_empty():
		var abilities_label = Label.new()
		abilities_label.text = "特殊技能: " + ", ".join(special_abilities)
		abilities_label.add_theme_font_size_override("font_size", 12)
		abilities_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		attributes_container.add_child(abilities_label)

# 更新操作按钮
func _update_actions_display(general_id: String, general_data: Dictionary) -> void:
	if not actions_container:
		return

	# 清空现有按钮
	for child in actions_container.get_children():
		child.queue_free()

	var button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 10)
	actions_container.add_child(button_container)

	# 分配/取消分配按钮
	var assigned_city = general_data.get("assigned_city", "")
	if assigned_city.is_empty():
		var assign_button = Button.new()
		assign_button.text = "分配到城池"
		assign_button.custom_minimum_size = Vector2(100, 44)
		assign_button.pressed.connect(_on_assign_button_pressed.bind(general_id))
		button_container.add_child(assign_button)
	else:
		var unassign_button = Button.new()
		unassign_button.text = "取消分配"
		unassign_button.custom_minimum_size = Vector2(100, 44)
		unassign_button.pressed.connect(_on_unassign_button_pressed.bind(general_id))
		button_container.add_child(unassign_button)

		var reassign_button = Button.new()
		reassign_button.text = "重新分配"
		reassign_button.custom_minimum_size = Vector2(100, 44)
		reassign_button.pressed.connect(_on_assign_button_pressed.bind(general_id))
		button_container.add_child(reassign_button)

# 隐藏详情面板
func hide_general_details() -> void:
	if detail_panel:
		detail_panel.visible = false
	selected_general_id = ""

# === 事件处理器 ===

func _on_general_card_selected(general_id: String) -> void:
	show_general_details(general_id)

# 移除手動招募相關方法 - 現在為完全自動化

func _on_assign_button_pressed(general_id: String) -> void:
	_show_city_assignment_dialog(general_id)

func _on_unassign_button_pressed(general_id: String) -> void:
	if GeneralsManager:
		GeneralsManager.unassign_general(general_id)
		refresh_generals_display()
		show_general_details(general_id)  # 刷新详情显示

# 移除手動招募對話框 - 現在為自動化招募

# 移除手動招募面板 - 現在為自動化招募

# 移除手動招募嘗試方法 - 現在為自動化招募

# 显示城池分配对话框
func _show_city_assignment_dialog(general_id: String) -> void:
	if not CityManager or not GeneralsManager:
		return

	var player_data = GameCore.get_player_data()
	var owned_cities = player_data.get("owned_cities", [])

	if owned_cities.is_empty():
		_show_simple_dialog("无法分配", "你还没有拥有任何城池")
		return

	# 创建分配对话框
	var dialog = AcceptDialog.new()
	dialog.title = "选择城池"
	dialog.size = Vector2(300, 250)
	add_child(dialog)

	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 10)
	dialog.add_child(container)

	for city_id in owned_cities:
		var city_data = CityManager.get_city_data(city_id)
		var city_name = city_data.get("name", city_id)

		var city_button = Button.new()
		city_button.text = city_name
		city_button.custom_minimum_size = Vector2(0, 44)

		# 检查是否已有武将分配
		var assigned_general = GeneralsManager.get_city_general(city_id)
		if not assigned_general.is_empty():
			city_button.text += " (已有: %s)" % assigned_general.get("name", "")

		city_button.pressed.connect(_assign_general_to_city.bind(general_id, city_id))
		container.add_child(city_button)

	dialog.popup_centered()

# 分配武将到城池
func _assign_general_to_city(general_id: String, city_id: String) -> void:
	if GeneralsManager:
		var success = GeneralsManager.assign_general_to_city(general_id, city_id)
		if success:
			var city_data = CityManager.get_city_data(city_id)
			var city_name = city_data.get("name", city_id)
			_show_simple_dialog("分配成功", "武将已分配到 " + city_name)
			refresh_generals_display()
			show_general_details(general_id)

# 显示简单对话框
func _show_simple_dialog(title: String, message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.size = Vector2(250, 150)
	add_child(dialog)
	dialog.popup_centered()

# GeneralsManager事件处理器
func _on_general_recruited(general_data: Dictionary) -> void:
	refresh_generals_display()

func _on_general_assigned(general_id: String, city_id: String) -> void:
	if general_id == selected_general_id:
		show_general_details(general_id)

func _on_general_level_up(general_id: String, new_level: int) -> void:
	refresh_generals_display()
	if general_id == selected_general_id:
		show_general_details(general_id)