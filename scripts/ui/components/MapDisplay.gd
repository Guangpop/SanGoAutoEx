# MapDisplay.gd - 地圖顯示組件
#
# 功能：
# - 獨立管理地圖渲染和顯示
# - 城市數據更新和視覺效果
# - 地圖互動和事件處理
# - SubViewport配置和優化

class_name MapDisplay
extends SubViewport

# 組件引用
@onready var map_root: Node2D

# 地圖配置
@export var auto_update_render: bool = true
@export var enable_city_interaction: bool = true
@export var map_scale: float = 1.0

# 城市數據
var cities_data: Array[Dictionary] = []
var city_nodes: Dictionary = {}
var selected_city_id: String = ""

# 渲染配置
var render_update_mode: int = SubViewport.UPDATE_ALWAYS
var initial_size: Vector2 = Vector2.ZERO

# 信號定義
signal city_selected(city_data: Dictionary)
signal city_deselected()
signal map_updated()
signal map_interaction(interaction_type: String, data: Dictionary)

func _ready() -> void:
	name = "MapDisplay"
	_setup_viewport_configuration()
	_setup_map_root()
	LogManager.info("MapDisplay", "地圖顯示組件初始化完成")

# =============================================================================
# 公開接口
# =============================================================================

## 更新城市數據
func update_cities_data(new_cities_data: Array[Dictionary]) -> bool:
	cities_data = new_cities_data.duplicate()

	if not map_root:
		LogManager.error("MapDisplay", "無法更新城市數據", {"reason": "MapRoot不存在"})
		return false

	_refresh_city_display()
	map_updated.emit()

	LogManager.info("MapDisplay", "城市數據已更新", {
		"cities_count": cities_data.size(),
		"map_scale": map_scale
	})
	return true

## 高亮特定城市
func highlight_city(city_id: String) -> bool:
	if city_id in city_nodes:
		_clear_city_highlights()
		var city_node = city_nodes[city_id]
		_apply_city_highlight(city_node, true)

		selected_city_id = city_id
		var city_data = _get_city_data(city_id)
		if city_data:
			city_selected.emit(city_data)

		LogManager.debug("MapDisplay", "城市已高亮", {"city_id": city_id})
		return true

	LogManager.warning("MapDisplay", "城市高亮失敗", {"city_id": city_id, "reason": "城市不存在"})
	return false

## 清除城市選擇
func clear_city_selection() -> void:
	_clear_city_highlights()
	selected_city_id = ""
	city_deselected.emit()
	LogManager.debug("MapDisplay", "城市選擇已清除")

## 設定地圖縮放
func set_map_scale(scale: float) -> void:
	map_scale = clamp(scale, 0.1, 5.0)
	if map_root:
		map_root.scale = Vector2(map_scale, map_scale)
		LogManager.debug("MapDisplay", "地圖縮放已設定", {"scale": map_scale})

## 重置地圖視圖
func reset_map_view() -> void:
	set_map_scale(1.0)
	if map_root:
		map_root.position = Vector2.ZERO
	clear_city_selection()
	LogManager.debug("MapDisplay", "地圖視圖已重置")

## 獲取城市數據
func get_city_data(city_id: String) -> Dictionary:
	return _get_city_data(city_id)

## 獲取所有城市數據
func get_all_cities_data() -> Array[Dictionary]:
	return cities_data.duplicate()

## 獲取選中城市
func get_selected_city() -> Dictionary:
	if selected_city_id:
		return _get_city_data(selected_city_id)
	return {}

# =============================================================================
# ViewPort配置
# =============================================================================

## 設定ViewPort配置
func _setup_viewport_configuration() -> void:
	# 設定渲染模式
	render_target_update_mode = render_update_mode

	# 記錄初始尺寸
	initial_size = size
	if initial_size == Vector2.ZERO:
		initial_size = Vector2(800, 600)  # 預設尺寸

	# 設定渲染配置
	set_update_mode(render_update_mode)

	# 連接尺寸變化信號
	size_changed.connect(_on_viewport_size_changed)

	LogManager.debug("MapDisplay", "ViewPort配置完成", {
		"initial_size": initial_size,
		"render_mode": render_update_mode
	})

## ViewPort尺寸變化回調
func _on_viewport_size_changed() -> void:
	if map_root:
		_adjust_map_layout()

	LogManager.debug("MapDisplay", "ViewPort尺寸變化", {
		"old_size": initial_size,
		"new_size": size
	})
	initial_size = size

# =============================================================================
# MapRoot管理
# =============================================================================

## 設定MapRoot
func _setup_map_root() -> void:
	map_root = get_node_or_null("MapRoot")

	if not map_root:
		# 如果不存在，創建MapRoot
		map_root = Node2D.new()
		map_root.name = "MapRoot"
		add_child(map_root)
		LogManager.info("MapDisplay", "MapRoot已創建")
	else:
		LogManager.info("MapDisplay", "MapRoot已存在")

	# 設定初始縮放
	map_root.scale = Vector2(map_scale, map_scale)

	# 連接MapRoot的腳本（如果存在）
	if map_root.has_method("initialize_map"):
		map_root.initialize_map()

## 刷新城市顯示
func _refresh_city_display() -> void:
	if not map_root:
		return

	# 清除現有城市節點
	_clear_city_nodes()

	# 創建新的城市節點
	for city_data in cities_data:
		_create_city_node(city_data)

	# 調整地圖佈局
	_adjust_map_layout()

## 創建城市節點
func _create_city_node(city_data: Dictionary) -> void:
	var city_id = city_data.get("id", "")
	if city_id.is_empty():
		LogManager.warning("MapDisplay", "城市數據缺少ID", {"city_data": city_data})
		return

	# 創建城市容器
	var city_container = Node2D.new()
	city_container.name = "City_" + city_id

	# 設定城市位置
	var position = city_data.get("position", Vector2.ZERO)
	city_container.position = position

	# 創建城市圓圈
	var city_circle = _create_city_circle(city_data)
	city_container.add_child(city_circle)

	# 創建城市標籤
	var city_label = _create_city_label(city_data)
	city_container.add_child(city_label)

	# 設定互動區域
	if enable_city_interaction:
		_setup_city_interaction(city_container, city_data)

	# 添加到地圖和索引
	map_root.add_child(city_container)
	city_nodes[city_id] = city_container

	LogManager.debug("MapDisplay", "城市節點已創建", {
		"city_id": city_id,
		"position": position,
		"name": city_data.get("name", "未知城市")
	})

## 創建城市圓圈視覺
func _create_city_circle(city_data: Dictionary) -> Node2D:
	# 這裡可以根據需要創建CircleShape2D或使用Sprite2D
	# 暫時創建一個簡單的標記
	var marker = Node2D.new()
	marker.name = "CityMarker"

	# 如果有自定義繪製需求，可以在這裡實現
	# 或者使用預製的城市圖標Sprite

	return marker

## 創建城市標籤
func _create_city_label(city_data: Dictionary) -> Label:
	var label = Label.new()
	label.text = city_data.get("name", "未知城市")
	label.position = Vector2(0, 25)  # 位於城市圓圈下方
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)

	return label

## 設定城市互動
func _setup_city_interaction(city_container: Node2D, city_data: Dictionary) -> void:
	# 添加Area2D用於點擊檢測
	var area = Area2D.new()
	area.name = "InteractionArea"

	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 30.0  # 觸摸範圍
	collision_shape.shape = circle_shape

	area.add_child(collision_shape)
	city_container.add_child(area)

	# 連接信號
	area.input_event.connect(_on_city_input_event.bind(city_data))

## 城市輸入事件處理
func _on_city_input_event(viewport: Node, event: InputEvent, shape_idx: int, city_data: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				highlight_city(city_data.get("id", ""))
				map_interaction.emit("city_selected", city_data)
			MOUSE_BUTTON_RIGHT:
				map_interaction.emit("city_context_menu", city_data)

# =============================================================================
# 內部方法
# =============================================================================

## 清除城市節點
func _clear_city_nodes() -> void:
	for city_id in city_nodes:
		var city_node = city_nodes[city_id]
		if city_node:
			city_node.queue_free()

	city_nodes.clear()

## 調整地圖佈局
func _adjust_map_layout() -> void:
	if not map_root or cities_data.is_empty():
		return

	# 計算地圖邊界
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)

	for city_data in cities_data:
		var pos = city_data.get("position", Vector2.ZERO)
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)

	# 居中顯示
	var map_center = (min_pos + max_pos) / 2
	var viewport_center = size / 2
	map_root.position = viewport_center - map_center * map_scale

## 獲取城市數據
func _get_city_data(city_id: String) -> Dictionary:
	for city_data in cities_data:
		if city_data.get("id", "") == city_id:
			return city_data
	return {}

## 清除城市高亮
func _clear_city_highlights() -> void:
	for city_id in city_nodes:
		var city_node = city_nodes[city_id]
		_apply_city_highlight(city_node, false)

## 應用城市高亮
func _apply_city_highlight(city_node: Node2D, highlighted: bool) -> void:
	if not city_node:
		return

	var marker = city_node.get_node_or_null("CityMarker")
	if marker:
		# 這裡可以改變城市視覺效果
		# 例如改變顏色、大小等
		if highlighted:
			marker.modulate = Color.YELLOW
			marker.scale = Vector2(1.2, 1.2)
		else:
			marker.modulate = Color.WHITE
			marker.scale = Vector2(1.0, 1.0)

# =============================================================================
# 配置方法
# =============================================================================

## 設定渲染更新模式
func set_render_update_mode(mode: int) -> void:
	render_update_mode = mode
	render_target_update_mode = mode

## 啟用/禁用城市互動
func set_city_interaction(enabled: bool) -> void:
	enable_city_interaction = enabled