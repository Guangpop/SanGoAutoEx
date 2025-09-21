# EnhancedMobileUI.gd - 增強版移動端主介面
#
# 功能：
# - 實現現代化觸控手勢導航
# - 響應式佈局和動畫系統
# - 性能優化的UI更新機制
# - 無障礙設計和觸覺反饋

extends Control

# UI增強器
var mobile_enhancer: MobileUIEnhancer

# 主要UI面板
@onready var main_container = $MainContainer
@onready var top_bar = $MainContainer/TopBar
@onready var content_area = $MainContainer/ContentArea
@onready var bottom_navigation = $MainContainer/BottomNavigation
@onready var side_panel = $SidePanel

# 內容頁面
@onready var dashboard_page = $MainContainer/ContentArea/Pages/Dashboard
@onready var cities_page = $MainContainer/ContentArea/Pages/Cities
@onready var battles_page = $MainContainer/ContentArea/Pages/Battles
@onready var profile_page = $MainContainer/ContentArea/Pages/Profile

# 導航狀態
var current_page: String = "dashboard"
var is_side_panel_open: bool = false
var page_stack: Array[String] = []

# 動畫控制
var page_transition_duration: float = 0.3
var panel_slide_duration: float = 0.25

# 手勢配置
var swipe_page_threshold: float = 150.0
var pull_refresh_threshold: float = 100.0

func _ready() -> void:
	LogManager.info("EnhancedMobileUI", "增強版移動端UI初始化")

	# 初始化UI增強器
	mobile_enhancer = MobileUIEnhancer.new()
	add_child(mobile_enhancer)

	# 連接手勢事件
	mobile_enhancer.gesture_detected.connect(_on_gesture_detected)
	mobile_enhancer.ui_feedback_requested.connect(_on_ui_feedback_requested)

	# 為主要區域添加手勢支持
	setup_gesture_areas()

	# 初始化響應式佈局
	setup_responsive_layout()

	# 連接導航按鈕
	setup_navigation()

	# 初始化頁面
	show_page("dashboard", false)

# === 手勢設置 ===

func setup_gesture_areas() -> void:
	# 為內容區域添加滑動手勢
	mobile_enhancer.add_gesture_support(content_area)

	# 為頂部欄添加下拉刷新支持
	mobile_enhancer.add_gesture_support(top_bar)

	# 為底部導航添加手勢
	mobile_enhancer.add_gesture_support(bottom_navigation)

	LogManager.debug("EnhancedMobileUI", "手勢區域設置完成")

func _on_gesture_detected(gesture_type: String, data: Dictionary) -> void:
	match gesture_type:
		"swipe":
			_handle_swipe_gesture(data)
		"long_press":
			_handle_long_press(data)
		"double_tap":
			_handle_double_tap(data)
		"pull_down":
			_handle_pull_refresh(data)
		"drag_start":
			_handle_drag_start(data)
		"drag_update":
			_handle_drag_update(data)
		"drag_end":
			_handle_drag_end(data)

# 處理滑動手勢
func _handle_swipe_gesture(data: Dictionary) -> void:
	var direction = data.get("direction", "")
	var control = data.get("control", null)

	if control == content_area:
		# 左右滑動切換頁面
		match direction:
			"left":
				_navigate_to_next_page()
			"right":
				_navigate_to_previous_page()
			"up":
				# 向上滑動可能隱藏底部導航
				_toggle_bottom_navigation(false)
			"down":
				# 向下滑動顯示底部導航
				_toggle_bottom_navigation(true)

	elif control == top_bar and direction == "left":
		# 從頂部左滑打開側邊欄
		toggle_side_panel()

# 處理長按手勢
func _handle_long_press(data: Dictionary) -> void:
	var position = data.get("position", Vector2.ZERO)

	# 長按可能顯示上下文選單或進入編輯模式
	_show_context_menu(position)

# 處理雙擊手勢
func _handle_double_tap(data: Dictionary) -> void:
	var control = data.get("control", null)

	if control == top_bar:
		# 雙擊頂部欄滾動到頂部
		_scroll_to_top()

# 處理下拉刷新
func _handle_pull_refresh(data: Dictionary) -> void:
	var distance = data.get("distance", 0.0)

	if distance > pull_refresh_threshold:
		_trigger_refresh()

# === 頁面導航系統 ===

func show_page(page_name: String, with_animation: bool = true) -> void:
	if current_page == page_name:
		return

	var old_page = _get_page_node(current_page)
	var new_page = _get_page_node(page_name)

	if not new_page:
		LogManager.warning("EnhancedMobileUI", "頁面不存在", {"page": page_name})
		return

	# 添加到頁面堆疊
	if current_page != "" and current_page != page_name:
		page_stack.append(current_page)
		if page_stack.size() > 10: # 限制堆疊大小
			page_stack.pop_front()

	if with_animation:
		_animate_page_transition(old_page, new_page)
	else:
		if old_page:
			old_page.visible = false
		new_page.visible = true

	current_page = page_name
	_update_navigation_state()

	LogManager.debug("EnhancedMobileUI", "頁面切換", {"from": current_page, "to": page_name})

func _get_page_node(page_name: String) -> Control:
	match page_name:
		"dashboard": return dashboard_page
		"cities": return cities_page
		"battles": return battles_page
		"profile": return profile_page
		_: return null

func _animate_page_transition(old_page: Control, new_page: Control) -> void:
	if not mobile_enhancer.tween:
		return

	# 準備新頁面
	new_page.visible = true
	new_page.modulate.a = 0.0

	# 淡出舊頁面，淡入新頁面
	if old_page:
		mobile_enhancer.tween.tween_property(old_page, "modulate:a", 0.0, page_transition_duration)
		mobile_enhancer.tween.tween_callback(func(): old_page.visible = false).set_delay(page_transition_duration)

	mobile_enhancer.tween.tween_property(new_page, "modulate:a", 1.0, page_transition_duration)

func _navigate_to_next_page() -> void:
	var pages = ["dashboard", "cities", "battles", "profile"]
	var current_index = pages.find(current_page)
	if current_index != -1 and current_index < pages.size() - 1:
		show_page(pages[current_index + 1])

func _navigate_to_previous_page() -> void:
	var pages = ["dashboard", "cities", "battles", "profile"]
	var current_index = pages.find(current_page)
	if current_index > 0:
		show_page(pages[current_index - 1])

func go_back() -> bool:
	if page_stack.size() > 0:
		var previous_page = page_stack.pop_back()
		show_page(previous_page)
		return true
	return false

# === 側邊欄控制 ===

func toggle_side_panel() -> void:
	if is_side_panel_open:
		close_side_panel()
	else:
		open_side_panel()

func open_side_panel() -> void:
	if is_side_panel_open:
		return

	is_side_panel_open = true
	side_panel.visible = true

	# 滑入動畫
	var start_pos = Vector2(-side_panel.size.x, 0)
	var end_pos = Vector2.ZERO

	side_panel.position = start_pos
	mobile_enhancer.tween.tween_property(side_panel, "position", end_pos, panel_slide_duration)

	# 主內容區域變暗
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.name = "SidePanelOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(_on_overlay_input)

	main_container.add_child(overlay)
	overlay.move_to_front()
	side_panel.move_to_front()

	mobile_enhancer.animate_fade_in(overlay, panel_slide_duration)

func close_side_panel() -> void:
	if not is_side_panel_open:
		return

	is_side_panel_open = false

	# 滑出動畫
	var end_pos = Vector2(-side_panel.size.x, 0)
	mobile_enhancer.tween.tween_property(side_panel, "position", end_pos, panel_slide_duration)
	mobile_enhancer.tween.tween_callback(func(): side_panel.visible = false).set_delay(panel_slide_duration)

	# 移除覆蓋層
	var overlay = main_container.get_node_or_null("SidePanelOverlay")
	if overlay:
		mobile_enhancer.animate_fade_out(overlay, panel_slide_duration)
		mobile_enhancer.tween.tween_callback(func(): overlay.queue_free()).set_delay(panel_slide_duration)

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed:
		close_side_panel()

# === 響應式佈局 ===

func setup_responsive_layout() -> void:
	# 應用響應式樣式配置
	var style_configs = {
		"top_bar": {
			"scale_with_screen": true,
			"min_size": Vector2(414, 80),
			"margins": {"left": 16, "right": 16, "top": 8}
		},
		"bottom_navigation": {
			"scale_with_screen": true,
			"min_size": Vector2(414, 70),
			"margins": {"left": 8, "right": 8, "bottom": 8}
		},
		"content_area": {
			"scale_with_screen": true,
			"margins": {"left": 16, "right": 16, "top": 8, "bottom": 8}
		}
	}

	for node_name in style_configs:
		var node = get_node_or_null(node_name)
		if node:
			mobile_enhancer.apply_responsive_style(node, style_configs[node_name])

	mobile_enhancer._apply_responsive_layout()

# === 導航設置 ===

func setup_navigation() -> void:
	# 為底部導航按鈕連接事件
	var nav_buttons = bottom_navigation.get_children()
	for button in nav_buttons:
		if button is Button:
			button.pressed.connect(_on_nav_button_pressed.bind(button.name.to_lower()))
			mobile_enhancer.add_gesture_support(button)

func _on_nav_button_pressed(page_name: String) -> void:
	show_page(page_name)
	mobile_enhancer._provide_haptic_feedback("light")

func _update_navigation_state() -> void:
	# 更新底部導航按鈕狀態
	var nav_buttons = bottom_navigation.get_children()
	for button in nav_buttons:
		if button is Button:
			var button_page = button.name.to_lower()
			if button_page == current_page:
				button.modulate = Color(1.0, 1.0, 1.0, 1.0) # 高亮當前頁面
			else:
				button.modulate = Color(0.7, 0.7, 0.7, 1.0) # 未選中狀態

# === 交互功能 ===

func _toggle_bottom_navigation(show: bool) -> void:
	var target_position = bottom_navigation.position
	if show:
		target_position.y = get_viewport().get_visible_rect().size.y - bottom_navigation.size.y
	else:
		target_position.y = get_viewport().get_visible_rect().size.y

	mobile_enhancer.tween.tween_property(bottom_navigation, "position", target_position, 0.3)

func _show_context_menu(position: Vector2) -> void:
	# 創建上下文選單
	var popup_menu = PopupMenu.new()
	popup_menu.add_item("刷新", 0)
	popup_menu.add_item("設置", 1)
	popup_menu.add_item("幫助", 2)

	add_child(popup_menu)
	popup_menu.popup_on_parent(Rect2(position, Vector2.ZERO))
	popup_menu.item_selected.connect(_on_context_menu_selected)

	# 自動清理
	popup_menu.popup_hide.connect(func(): popup_menu.queue_free())

func _on_context_menu_selected(id: int) -> void:
	match id:
		0: _trigger_refresh()
		1: _open_settings()
		2: _show_help()

func _scroll_to_top() -> void:
	# 如果當前頁面有滾動容器，滾動到頂部
	var current_page_node = _get_page_node(current_page)
	if current_page_node:
		var scroll_container = current_page_node.get_node_or_null("ScrollContainer")
		if scroll_container is ScrollContainer:
			mobile_enhancer.tween.tween_property(scroll_container, "scroll_vertical", 0, 0.5)

func _trigger_refresh() -> void:
	LogManager.info("EnhancedMobileUI", "觸發頁面刷新")
	EventBus.emit_safe("ui_refresh_requested", [current_page])

	# 顯示刷新動畫
	_show_refresh_indicator()

func _show_refresh_indicator() -> void:
	# 創建簡單的刷新指示器
	var indicator = Label.new()
	indicator.text = "刷新中..."
	indicator.add_theme_stylebox_override("normal", StyleBoxFlat.new())

	top_bar.add_child(indicator)
	mobile_enhancer.animate_fade_in(indicator, 0.2)

	# 2秒後自動消失
	mobile_enhancer.tween.tween_callback(func(): mobile_enhancer.animate_fade_out(indicator, 0.2)).set_delay(2.0)
	mobile_enhancer.tween.tween_callback(func(): indicator.queue_free()).set_delay(2.5)

func _open_settings() -> void:
	LogManager.info("EnhancedMobileUI", "打開設置頁面")
	# 這裡可以打開設置對話框或頁面

func _show_help() -> void:
	LogManager.info("EnhancedMobileUI", "顯示幫助信息")
	# 這裡可以顯示幫助內容

# === 拖拽處理 ===

var drag_start_position: Vector2
var is_dragging_panel: bool = false

func _handle_drag_start(data: Dictionary) -> void:
	drag_start_position = data.get("position", Vector2.ZERO)
	var control = data.get("control", null)

	if control == side_panel:
		is_dragging_panel = true

func _handle_drag_update(data: Dictionary) -> void:
	if is_dragging_panel:
		var current_position = data.get("position", Vector2.ZERO)
		var delta = current_position - drag_start_position

		# 限制側邊欄拖拽範圍
		var new_x = clamp(side_panel.position.x + delta.x, -side_panel.size.x, 0)
		side_panel.position.x = new_x

func _handle_drag_end(data: Dictionary) -> void:
	if is_dragging_panel:
		# 根據最終位置決定是否關閉側邊欄
		if side_panel.position.x < -side_panel.size.x * 0.5:
			close_side_panel()
		else:
			open_side_panel()

		is_dragging_panel = false

# === 反饋處理 ===

func _on_ui_feedback_requested(feedback_type: String, intensity: float) -> void:
	match feedback_type:
		"haptic":
			# 觸覺反饋已在MobileUIEnhancer中處理
			pass
		"visual":
			_provide_visual_feedback(intensity)
		"audio":
			_provide_audio_feedback(intensity)

func _provide_visual_feedback(intensity: float) -> void:
	# 簡單的視覺反饋：短暫的屏幕閃爍
	var flash_overlay = ColorRect.new()
	flash_overlay.color = Color(1, 1, 1, intensity * 0.3)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(flash_overlay)
	mobile_enhancer.animate_fade_out(flash_overlay, 0.1)
	mobile_enhancer.tween.tween_callback(func(): flash_overlay.queue_free()).set_delay(0.2)

func _provide_audio_feedback(intensity: float) -> void:
	# 音頻反饋可以通過AudioManager處理
	EventBus.emit_safe("audio_feedback_requested", ["ui_click", intensity])

# === 性能優化 ===

# 延遲更新UI以避免過於頻繁的重繪
var update_timer: Timer
var pending_updates: Dictionary = {}

func _init_performance_optimization() -> void:
	update_timer = Timer.new()
	update_timer.wait_time = 0.016 # 約60FPS
	update_timer.one_shot = false
	update_timer.timeout.connect(_process_pending_updates)
	add_child(update_timer)
	update_timer.start()

func schedule_ui_update(component: String, data: Dictionary) -> void:
	pending_updates[component] = data

func _process_pending_updates() -> void:
	for component in pending_updates:
		var data = pending_updates[component]
		_update_ui_component(component, data)

	pending_updates.clear()

func _update_ui_component(component: String, data: Dictionary) -> void:
	match component:
		"player_info":
			_update_player_info(data)
		"resources":
			_update_resource_display(data)
		"battle_status":
			_update_battle_status(data)

func _update_player_info(data: Dictionary) -> void:
	# 更新玩家資訊顯示
	pass

func _update_resource_display(data: Dictionary) -> void:
	# 更新資源顯示
	pass

func _update_battle_status(data: Dictionary) -> void:
	# 更新戰鬥狀態
	pass