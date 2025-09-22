# MapArea.gd - 地圖區域城池視覺化系統
#
# 功能：
# - 顯示16座三國城池節點
# - 城池間連線系統
# - 不同所有權的視覺區分
# - 觸控選擇和信息顯示
# - 實時狀態更新

extends Node2D

# 預載入繪製類
const CityCircleDrawer = preload("res://scripts/ui/CityCircleDrawer.gd")
const ConnectionLineDrawer = preload("res://scripts/ui/ConnectionLineDrawer.gd")


# 城池節點配置
const CITY_NODE_SIZE = 24
const CITY_LABEL_OFFSET = Vector2(0, -35)
const CONNECTION_WIDTH = 2.0

# 城池顏色配置 - 基於所有權
var city_colors = {
	"player": Color.CYAN,          # 玩家城池 - 青色
	"enemy": Color.CRIMSON,        # 敵方城池 - 深紅色
	"neutral": Color.GRAY,         # 中立城池 - 灰色
	"ally": Color.LIME_GREEN       # 同盟城池 - 石灰綠
}

# 城池等級顏色 - 基於重要性
var tier_colors = {
	"capital": Color.GOLD,         # 都城 - 金色
	"major": Color.ORANGE,         # 主要城池 - 橙色
	"medium": Color.YELLOW,        # 中等城池 - 黃色
	"small": Color.WHITE           # 小城池 - 白色
}

# 城池狀態顏色 - 基於健康度和活動
var status_colors = {
	"prosperous": Color.GREEN,     # 繁榮 - 綠色光暈
	"normal": Color.WHITE,         # 正常 - 白色
	"declining": Color.ORANGE,     # 衰落 - 橙色
	"besieged": Color.RED,         # 被圍攻 - 紅色閃爍
	"reinforcing": Color.BLUE      # 增援中 - 藍色脈衝
}

# 數據和狀態
var cities_data: Array = []
var city_nodes: Dictionary = {}
var city_connections: Array = []
var selected_city: String = ""

# 城池動畫狀態
var city_animations: Dictionary = {}
var animation_speed: float = 1.0

# UI引用
var viewport_size: Vector2
var map_scale: float = 1.0
var map_offset: Vector2 = Vector2.ZERO
var initial_map_scale: float = 1.0
var initial_map_offset: Vector2 = Vector2.ZERO

# 觸控處理
var touch_threshold: float = 40.0

# 觸控縮放和平移
var min_zoom: float = 0.5
var max_zoom: float = 3.0
var zoom_sensitivity: float = 0.02
var pan_sensitivity: float = 1.0

# 多點觸控狀態
var touch_points: Dictionary = {}
var last_distance: float = 0.0
var last_center: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var drag_start_offset: Vector2 = Vector2.ZERO

# 雙擊重置
var last_tap_time: float = 0.0
var double_tap_threshold: float = 0.3
var tap_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	name = "MapArea"
	LogManager.info("MapArea", "地圖區域初始化開始")

	# 等待父視口配置完成
	await get_tree().process_frame
	await get_tree().process_frame

	# 獲取正確的視窗大小
	var parent_viewport = get_viewport()
	if parent_viewport is SubViewport:
		viewport_size = parent_viewport.size
	else:
		viewport_size = parent_viewport.get_visible_rect().size

	LogManager.debug("MapArea", "視窗尺寸", {
		"size": viewport_size,
		"viewport_type": parent_viewport.get_class()
	})

	# 等待數據系統初始化
	await _wait_for_data_system()

	# 載入城池數據
	load_cities_data()

	# 計算地圖縮放和偏移
	calculate_map_transform()

	# 創建城池節點
	create_city_nodes()

	# 創建城池連線
	create_city_connections()

	# 連接事件處理器
	connect_event_handlers()

	LogManager.info("MapArea", "地圖區域初始化完成", {
		"cities_count": cities_data.size(),
		"nodes_created": city_nodes.size(),
		"connections_count": city_connections.size(),
		"map_scale": map_scale
	})

# 輸入事件處理（觸控縮放和平移）
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch_event(event)
	elif event is InputEventScreenDrag:
		_handle_drag_event(event)

# 處理觸控事件
func _handle_touch_event(event: InputEventScreenTouch) -> void:
	var index = event.index

	if event.pressed:
		# 開始觸控
		touch_points[index] = event.position

		if touch_points.size() == 1:
			# 檢測雙擊
			var current_time = Time.get_unix_time_from_system()
			if current_time - last_tap_time < double_tap_threshold and event.position.distance_to(tap_position) < 50:
				# 雙擊重置縮放
				_reset_zoom()
				touch_points.clear()
				return

			last_tap_time = current_time
			tap_position = event.position

			# 單點觸控 - 準備拖動
			is_dragging = true
			drag_start_pos = event.position
			drag_start_offset = map_offset
		elif touch_points.size() == 2:
			# 雙點觸控 - 開始縮放
			is_dragging = false
			_start_zoom_gesture()
	else:
		# 結束觸控
		touch_points.erase(index)

		if touch_points.size() == 0:
			# 所有觸控結束
			is_dragging = false
		elif touch_points.size() == 1:
			# 回到單點觸控
			var remaining_index = touch_points.keys()[0]
			var remaining_pos = touch_points[remaining_index]
			is_dragging = true
			drag_start_pos = remaining_pos
			drag_start_offset = map_offset

# 處理拖動事件
func _handle_drag_event(event: InputEventScreenDrag) -> void:
	var index = event.index

	if not touch_points.has(index):
		return

	# 更新觸控位置
	touch_points[index] = event.position

	if touch_points.size() == 1 and is_dragging:
		# 單點拖動 - 平移地圖
		_handle_pan(event.position)
	elif touch_points.size() == 2:
		# 雙點拖動 - 縮放和平移
		_handle_zoom_and_pan()

# 處理平移
func _handle_pan(current_pos: Vector2) -> void:
	var delta = current_pos - drag_start_pos
	map_offset = drag_start_offset + delta * pan_sensitivity
	_update_map_transform()

# 開始縮放手勢
func _start_zoom_gesture() -> void:
	var positions = touch_points.values()
	if positions.size() >= 2:
		last_center = (positions[0] + positions[1]) / 2.0
		last_distance = positions[0].distance_to(positions[1])

# 處理縮放和平移
func _handle_zoom_and_pan() -> void:
	var positions = touch_points.values()
	if positions.size() < 2:
		return

	var current_center = (positions[0] + positions[1]) / 2.0
	var current_distance = positions[0].distance_to(positions[1])

	if last_distance > 0:
		# 計算縮放變化
		var zoom_factor = current_distance / last_distance
		var new_scale = map_scale * zoom_factor
		new_scale = clamp(new_scale, min_zoom, max_zoom)

		# 以觸控中心為縮放中心
		var zoom_center = last_center
		var old_world_pos = (zoom_center - map_offset) / map_scale
		var new_world_pos = (zoom_center - map_offset) / new_scale

		map_scale = new_scale
		map_offset += (new_world_pos - old_world_pos) * map_scale

		# 處理中心點移動（平移）
		var center_delta = current_center - last_center
		map_offset += center_delta

	last_center = current_center
	last_distance = current_distance

	_update_map_transform()

# 更新地圖變換
func _update_map_transform() -> void:
	# 限制地圖邊界
	_clamp_map_bounds()

	# 更新所有城池節點位置
	_update_all_city_positions()

	# 更新連線位置
	_update_connection_positions()

# 限制地圖邊界（防止拖動過遠）
func _clamp_map_bounds() -> void:
	# 計算地圖在當前縮放下的尺寸
	var scaled_map_size = viewport_size * map_scale

	# 設定邊界限制
	var max_offset_x = scaled_map_size.x * 0.3
	var min_offset_x = viewport_size.x - scaled_map_size.x - max_offset_x
	var max_offset_y = scaled_map_size.y * 0.3
	var min_offset_y = viewport_size.y - scaled_map_size.y - max_offset_y

	map_offset.x = clamp(map_offset.x, min_offset_x, max_offset_x)
	map_offset.y = clamp(map_offset.y, min_offset_y, max_offset_y)

# 更新所有城池位置
func _update_all_city_positions() -> void:
	for city in cities_data:
		var city_id = city.get("id", "")
		if city_id.is_empty() or not city_nodes.has(city_id):
			continue

		var world_pos = Vector2(
			city.get("position", {}).get("x", 0),
			city.get("position", {}).get("y", 0)
		)
		var screen_pos = world_to_screen(world_pos)

		var city_node = city_nodes[city_id]
		city_node.position = screen_pos

# 更新連線位置
func _update_connection_positions() -> void:
	for connection in city_connections:
		var from_id = connection.get("from", "")
		var to_id = connection.get("to", "")
		var line = connection.get("line")

		if not line or not city_nodes.has(from_id) or not city_nodes.has(to_id):
			continue

		var from_pos = city_nodes[from_id].position
		var to_pos = city_nodes[to_id].position

		line.update_positions(from_pos, to_pos)

# 重置縮放和位置
func _reset_zoom() -> void:
	var tween = create_tween()
	tween.set_parallel(true)

	# 平滑過渡到初始狀態
	tween.tween_method(_set_map_scale, map_scale, initial_map_scale, 0.3)
	tween.tween_method(_set_map_offset, map_offset, initial_map_offset, 0.3)

	LogManager.info("MapArea", "地圖縮放已重置")

# 設置地圖縮放（用於動畫）
func _set_map_scale(scale: float) -> void:
	map_scale = scale
	_update_map_transform()

# 設置地圖偏移（用於動畫）
func _set_map_offset(offset: Vector2) -> void:
	map_offset = offset
	_update_map_transform()

# 獲取當前縮放信息（供調試使用）
func get_zoom_info() -> Dictionary:
	return {
		"current_scale": map_scale,
		"initial_scale": initial_map_scale,
		"min_zoom": min_zoom,
		"max_zoom": max_zoom,
		"current_offset": map_offset,
		"initial_offset": initial_map_offset
	}

# 城池狀態管理
func set_city_status(city_id: String, status: String) -> void:
	if not city_nodes.has(city_id):
		LogManager.warn("MapArea", "嘗試設置不存在城池的狀態", {"city_id": city_id, "status": status})
		return

	var city_node = city_nodes[city_id]
	var circle_drawer = city_node.get_node_or_null("CityCircle/CityCircleDrawer")

	if circle_drawer:
		circle_drawer.set_city_status(status)
		LogManager.debug("MapArea", "城池狀態已更新", {"city_id": city_id, "status": status})

# 批量更新城池狀態
func update_all_city_statuses(status_data: Dictionary) -> void:
	for city_id in status_data:
		var status = status_data[city_id]
		set_city_status(city_id, status)

	LogManager.info("MapArea", "批量更新城池狀態", {"cities_updated": status_data.size()})

# 根據城池數據判斷狀態
func determine_city_status(city_id: String) -> String:
	if not CityManager:
		return "normal"

	var city_state = CityManager.get_city_state(city_id)

	# 檢查是否正在被圍攻
	if city_state.get("under_siege", false):
		return "besieged"

	# 檢查是否正在增援
	if city_state.get("reinforcing", false):
		return "reinforcing"

	# 根據城池健康度和繁榮度判斷
	var prosperity = city_state.get("prosperity", 50)
	var health = city_state.get("health", 100)

	if prosperity >= 80 and health >= 90:
		return "prosperous"
	elif health <= 30 or prosperity <= 20:
		return "declining"
	else:
		return "normal"

# 自動更新所有城池狀態
func auto_update_city_statuses() -> void:
	var status_updates = {}

	for city in cities_data:
		var city_id = city.get("id", "")
		if not city_id.is_empty():
			var status = determine_city_status(city_id)
			status_updates[city_id] = status

	update_all_city_statuses(status_updates)

# 模擬城池事件（用於測試和遊戲事件響應）
func trigger_city_event(city_id: String, event_type: String, duration: float = 5.0) -> void:
	var status = "normal"

	match event_type:
		"siege_start":
			status = "besieged"
		"reinforcement_sent":
			status = "reinforcing"
		"prosperity_boost":
			status = "prosperous"
		"economic_decline":
			status = "declining"

	set_city_status(city_id, status)

	# 定時恢復到正常狀態
	if duration > 0:
		var timer = get_tree().create_timer(duration)
		timer.timeout.connect(_restore_city_status.bind(city_id))

	LogManager.info("MapArea", "城池事件觸發", {
		"city_id": city_id,
		"event": event_type,
		"duration": duration
	})

func _restore_city_status(city_id: String) -> void:
	var normal_status = determine_city_status(city_id)
	set_city_status(city_id, normal_status)
	LogManager.debug("MapArea", "城池狀態已恢復", {"city_id": city_id})

# 等待數據系統初始化
func _wait_for_data_system() -> void:
	var max_wait_time = 5.0
	var wait_start = Time.get_unix_time_from_system()

	while not CityManager or CityManager.cities_data.is_empty():
		await get_tree().process_frame
		var elapsed = Time.get_unix_time_from_system() - wait_start
		if elapsed > max_wait_time:
			LogManager.warn("MapArea", "等待數據系統超時", {"elapsed": elapsed})
			break

# 載入城池數據
func load_cities_data() -> void:
	if CityManager and not CityManager.cities_data.is_empty():
		cities_data = CityManager.cities_data.duplicate()
		LogManager.info("MapArea", "從CityManager載入城池數據", {
			"cities_count": cities_data.size()
		})
	else:
		# 直接從文件載入作為備用
		var file = FileAccess.open("res://data/cities.json", FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()

			var json = JSON.new()
			var parse_result = json.parse(json_string)

			if parse_result == OK:
				var data = json.data
				cities_data = data.get("cities", [])
				LogManager.info("MapArea", "直接從文件載入城池數據", {
					"cities_count": cities_data.size()
				})
			else:
				LogManager.error("MapArea", "城池數據解析失敗")
		else:
			LogManager.error("MapArea", "無法讀取城池數據文件")

# 計算地圖變換
func calculate_map_transform() -> void:
	if cities_data.is_empty():
		return

	# 找出城池坐標範圍
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF

	for city in cities_data:
		var pos = city.get("position", {"x": 0, "y": 0})
		var x = pos.get("x", 0)
		var y = pos.get("y", 0)

		min_x = min(min_x, x)
		max_x = max(max_x, x)
		min_y = min(min_y, y)
		max_y = max(max_y, y)

	# 計算地圖尺寸
	var map_width = max_x - min_x
	var map_height = max_y - min_y

	# 預留邊距
	var margin = 40.0
	var available_width = viewport_size.x - margin * 2
	var available_height = viewport_size.y - margin * 2

	# 計算縮放比例
	var scale_x = available_width / map_width if map_width > 0 else 1.0
	var scale_y = available_height / map_height if map_height > 0 else 1.0
	map_scale = min(scale_x, scale_y, 2.0)  # 限制最大縮放
	initial_map_scale = map_scale

	# 計算偏移以居中顯示
	var scaled_width = map_width * map_scale
	var scaled_height = map_height * map_scale
	map_offset = Vector2(
		(viewport_size.x - scaled_width) / 2 - min_x * map_scale,
		(viewport_size.y - scaled_height) / 2 - min_y * map_scale
	)
	initial_map_offset = map_offset

	LogManager.debug("MapArea", "地圖變換計算完成", {
		"map_bounds": {"min_x": min_x, "max_x": max_x, "min_y": min_y, "max_y": max_y},
		"scale": map_scale,
		"offset": map_offset
	})

# 世界座標轉螢幕座標
func world_to_screen(world_pos: Vector2) -> Vector2:
	return world_pos * map_scale + map_offset

# 創建城池節點
func create_city_nodes() -> void:
	for city in cities_data:
		var city_id = city.get("id", "")
		if city_id.is_empty():
			continue

		var world_pos = Vector2(
			city.get("position", {}).get("x", 0),
			city.get("position", {}).get("y", 0)
		)
		var screen_pos = world_to_screen(world_pos)

		# 創建城池節點
		var city_node = _create_city_node(city, screen_pos)
		add_child(city_node)
		city_nodes[city_id] = city_node

		LogManager.debug("MapArea", "創建城池節點", {
			"city": city.get("name", ""),
			"id": city_id,
			"world_pos": world_pos,
			"screen_pos": screen_pos
		})

# 創建單個城池節點
func _create_city_node(city_data: Dictionary, position: Vector2) -> Node2D:
	var city_node = Node2D.new()
	city_node.name = "City_" + city_data.get("id", "")
	city_node.position = position

	# 創建城池圓圈
	var city_circle = _create_city_circle(city_data)
	city_node.add_child(city_circle)

	# 創建城池標籤
	var city_label = _create_city_label(city_data)
	city_node.add_child(city_label)

	# 添加觸控區域
	var touch_area = _create_touch_area(city_data)
	city_node.add_child(touch_area)

	return city_node

# 創建城池圓圈顯示
func _create_city_circle(city_data: Dictionary) -> Node2D:
	var circle = Node2D.new()
	circle.name = "CityCircle"

	# 使用自定義繪製
	var circle_drawer = CityCircleDrawer.new()
	circle_drawer.name = "CityCircleDrawer"
	circle_drawer.setup(city_data, CITY_NODE_SIZE, get_city_color(city_data), get_tier_color(city_data))
	circle.add_child(circle_drawer)

	return circle

# 創建城池標籤
func _create_city_label(city_data: Dictionary) -> Label:
	var label = Label.new()
	label.name = "CityLabel"
	label.text = city_data.get("name", "")
	label.position = CITY_LABEL_OFFSET
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)

	return label

# 創建觸控區域
func _create_touch_area(city_data: Dictionary) -> Area2D:
	var area = Area2D.new()
	area.name = "TouchArea"

	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = touch_threshold
	collision.shape = shape
	area.add_child(collision)

	# 連接觸控事件
	area.input_event.connect(_on_city_touched.bind(city_data.get("id", "")))

	return area

# 獲取城池顏色（基於所有權）
func get_city_color(city_data: Dictionary) -> Color:
	var city_id = city_data.get("id", "")

	# 檢查城池所有權
	if CityManager:
		var city_state = CityManager.get_city_state(city_id)
		var owner = city_state.get("owner", city_data.get("kingdom", "neutral"))

		if owner == "player":
			return city_colors.player
		elif owner in ["魏", "吳", "蜀"] and owner != get_player_kingdom():
			return city_colors.enemy
		elif owner == get_player_kingdom():
			return city_colors.ally

	return city_colors.neutral

# 獲取城池等級顏色
func get_tier_color(city_data: Dictionary) -> Color:
	var tier = city_data.get("tier", "small")
	return tier_colors.get(tier, tier_colors.small)

# 獲取玩家所屬勢力
func get_player_kingdom() -> String:
	# TODO: 從玩家數據獲取所屬勢力
	return "蜀"

# 創建城池連線
func create_city_connections() -> void:
	# 定義城池間的戰略連線
	var connections = [
		# 益州地區
		["chengdu", "hanzhong"],

		# 司隸-豫州連線
		["luoyang", "xuchang"],

		# 荊州內部連線
		["xiangyang", "jiangling"],
		["jiangling", "xiakou"],
		["xiakou", "wuchang"],

		# 揚州連線
		["jianye", "chaisang"],
		["chaisang", "wuchang"],

		# 跨地區戰略要道
		["hanzhong", "chang_an"],        # 秦巴通道
		["chang_an", "luoyang"],         # 關中-洛陽
		["xiangyang", "xuchang"],        # 荊豫要道
		["hefei", "jianye"],             # 魏吳前線
		["ye", "luoyang"],               # 冀州-司隸
		["jinyang", "ye"],               # 并州-冀州
		["wuwei", "chang_an"],           # 涼州-雍州
		["youbeiping", "ye"],            # 幽州-冀州
	]

	for connection in connections:
		if connection.size() >= 2:
			_create_connection_line(connection[0], connection[1])

	LogManager.info("MapArea", "城池連線創建完成", {
		"connections_count": connections.size()
	})

# 創建連線
func _create_connection_line(city_id_1: String, city_id_2: String) -> void:
	var node1 = city_nodes.get(city_id_1)
	var node2 = city_nodes.get(city_id_2)

	if not node1 or not node2:
		LogManager.warn("MapArea", "無法創建連線，城池節點不存在", {
			"city1": city_id_1,
			"city2": city_id_2
		})
		return

	var line_drawer = ConnectionLineDrawer.new()
	line_drawer.setup(node1.position, node2.position, CONNECTION_WIDTH)
	add_child(line_drawer)

	city_connections.append({
		"from": city_id_1,
		"to": city_id_2,
		"line": line_drawer
	})

# 連接事件處理器
func connect_event_handlers() -> void:
	if EventBus:
		EventBus.connect_safe("city_conquered", _on_city_conquered)
		EventBus.connect_safe("game_state_changed", _on_game_state_changed)
		EventBus.connect_safe("battle_started", _on_battle_started)
		EventBus.connect_safe("battle_completed", _on_battle_completed)
		EventBus.connect_safe("turn_completed", _on_turn_completed)

	if CityManager:
		CityManager.connect("city_conquered", _on_city_manager_conquest)

	LogManager.debug("MapArea", "事件處理器連接完成")

# 觸控事件處理
func _on_city_touched(city_id: String, _viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventScreenTouch and event.pressed:
		select_city(city_id)
		LogManager.debug("MapArea", "城池被觸控", {"city_id": city_id})

# 選擇城池
func select_city(city_id: String) -> void:
	# 取消之前的選擇
	if not selected_city.is_empty() and city_nodes.has(selected_city):
		_update_city_selection(selected_city, false)

	# 選擇新城池
	selected_city = city_id
	if city_nodes.has(city_id):
		_update_city_selection(city_id, true)

		# 發送選擇事件
		var city_data = _get_city_data_by_id(city_id)
		EventBus.city_selected.emit(city_id, city_data)

		LogManager.info("MapArea", "城池已選擇", {
			"city_id": city_id,
			"city_name": city_data.get("name", "")
		})

# 更新城池選擇視覺效果
func _update_city_selection(city_id: String, is_selected: bool) -> void:
	var city_node = city_nodes.get(city_id)
	if city_node:
		var circle = city_node.get_node_or_null("CityCircle/CityCircleDrawer")
		if circle:
			circle.set_selected(is_selected)

# 根據ID獲取城池數據
func _get_city_data_by_id(city_id: String) -> Dictionary:
	for city in cities_data:
		if city.get("id") == city_id:
			return city
	return {}

# 更新城池狀態顯示
func update_city_states() -> void:
	for city_id in city_nodes:
		var city_node = city_nodes[city_id]
		var city_data = _get_city_data_by_id(city_id)

		# 更新顏色
		var circle = city_node.get_node_or_null("CityCircle/CityCircleDrawer")
		if circle:
			circle.update_colors(get_city_color(city_data), get_tier_color(city_data))

# 事件處理器
func _on_city_conquered(city_name: String, victor: String, spoils: Dictionary) -> void:
	LogManager.info("MapArea", "收到城池征服事件", {
		"city": city_name,
		"victor": victor
	})

	# 找到對應的城池ID
	var city_id = _get_city_id_by_name(city_name)
	if not city_id.is_empty():
		# 觸發征服動畫
		trigger_city_event(city_id, "prosperity_boost", 8.0)

	update_city_states()
	auto_update_city_statuses()

func _on_city_manager_conquest(city_id: String, victor: String, spoils: Dictionary) -> void:
	LogManager.info("MapArea", "收到CityManager征服事件", {
		"city_id": city_id,
		"victor": victor
	})

	# 觸發征服慶祝動畫
	trigger_city_event(city_id, "prosperity_boost", 10.0)

	update_city_states()
	auto_update_city_statuses()

func _on_game_state_changed(new_state: int, old_state: int) -> void:
	# 遊戲狀態變化時更新顯示
	if new_state == GameStateManager.GameState.GAME_RUNNING:
		update_city_states()
		auto_update_city_statuses()

# 新增事件處理器
func _on_battle_started(attacker: Dictionary, defender: Dictionary, city_name: String) -> void:
	var city_id = _get_city_id_by_name(city_name)
	if not city_id.is_empty():
		trigger_city_event(city_id, "siege_start", 0.0)  # 持續到戰鬥結束

func _on_battle_completed(result: Dictionary, victor: String, casualties: Dictionary) -> void:
	var city_name = result.get("city_name", "")
	var city_id = _get_city_id_by_name(city_name)

	if not city_id.is_empty():
		if victor == "player":
			trigger_city_event(city_id, "prosperity_boost", 5.0)
		else:
			trigger_city_event(city_id, "economic_decline", 3.0)

func _on_turn_completed(turn_data: Dictionary) -> void:
	# 每回合自動更新城池狀態
	auto_update_city_statuses()

# 輔助函數
func _get_city_id_by_name(city_name: String) -> String:
	for city in cities_data:
		if city.get("name", "") == city_name:
			return city.get("id", "")
	return ""

# =============================================================================
# 調試和視口處理功能
# =============================================================================

## 視口尺寸變化處理（由MainMobile調用）
func _on_viewport_size_changed() -> void:
	# 更新視窗尺寸
	var old_size = viewport_size
	viewport_size = get_viewport().get_visible_rect().size

	LogManager.info("MapArea", "視口尺寸變化", {
		"old_size": old_size,
		"new_size": viewport_size,
		"size_changed": old_size != viewport_size
	})

	# 重新計算地圖變換
	if not cities_data.is_empty():
		calculate_map_transform()
		_update_all_city_positions()
		_update_connection_positions()
		LogManager.debug("MapArea", "地圖佈局已重新計算")

## 添加視覺調試功能
func add_debug_markers() -> void:
	# 創建視口邊界標記
	var debug_container = Node2D.new()
	debug_container.name = "DebugMarkers"
	add_child(debug_container)

	# 添加四個角落的標記點
	var corners = [
		Vector2(0, 0),  # 左上
		Vector2(viewport_size.x, 0),  # 右上
		Vector2(0, viewport_size.y),  # 左下
		Vector2(viewport_size.x, viewport_size.y)  # 右下
	]

	for i in range(corners.size()):
		var marker = Node2D.new()
		marker.name = "Corner_%d" % i
		marker.position = corners[i]
		debug_container.add_child(marker)

	LogManager.info("MapArea", "調試標記已添加", {
		"viewport_size": viewport_size,
		"corner_positions": corners
	})

## 驗證城池位置是否在可見範圍內
func validate_city_positions() -> Dictionary:
	var validation_result = {
		"total_cities": cities_data.size(),
		"visible_cities": 0,
		"outside_cities": [],
		"city_positions": {}
	}

	for city in cities_data:
		var city_id = city.get("id", "")
		var world_pos = Vector2(
			city.get("position", {}).get("x", 0),
			city.get("position", {}).get("y", 0)
		)
		var screen_pos = world_to_screen(world_pos)

		validation_result.city_positions[city_id] = {
			"world": world_pos,
			"screen": screen_pos,
			"name": city.get("name", "")
		}

		# 檢查是否在視窗範圍內（添加邊距）
		var margin = 100
		var is_visible = (
			screen_pos.x >= -margin and screen_pos.x <= viewport_size.x + margin and
			screen_pos.y >= -margin and screen_pos.y <= viewport_size.y + margin
		)

		if is_visible:
			validation_result.visible_cities += 1
		else:
			validation_result.outside_cities.append({
				"id": city_id,
				"name": city.get("name", ""),
				"screen_pos": screen_pos
			})

	LogManager.info("MapArea", "城池位置驗證完成", validation_result)
	return validation_result

## 強制重新繪製所有元素
func force_redraw() -> void:
	LogManager.info("MapArea", "強制重新繪製開始")

	# 隱藏後重新顯示所有城池節點
	for city_id in city_nodes:
		var city_node = city_nodes[city_id]
		if city_node:
			city_node.visible = false
			await get_tree().process_frame
			city_node.visible = true
			city_node.queue_redraw()

	# 強制重新繪製連線
	for connection in city_connections:
		var line = connection.get("line")
		if line:
			line.queue_redraw()

	# 強制整個節點重新繪製
	queue_redraw()

	LogManager.info("MapArea", "強制重新繪製完成")

## 獲取調試信息
func get_debug_info() -> Dictionary:
	return {
		"viewport_size": viewport_size,
		"map_scale": map_scale,
		"map_offset": map_offset,
		"cities_count": cities_data.size(),
		"nodes_count": city_nodes.size(),
		"connections_count": city_connections.size(),
		"selected_city": selected_city,
		"node_position": position,
		"node_visible": visible,
		"node_scale": scale,
		"node_modulate": modulate
	}

# =============================================================================
# 渲染管道調試功能
# =============================================================================

var city_drawer: Node = null
var connection_drawer: Node = null
var world_bounds: Rect2

## 渲染管道完整調試
func debug_rendering_pipeline() -> Dictionary:
	var debug_info = {
		"viewport_info": get_viewport_debug_info(),
		"node2d_info": get_node2d_debug_info(),
		"drawing_info": get_drawing_debug_info(),
		"transform_info": get_transform_debug_info()
	}

	LogManager.debug("MapArea", "Rendering pipeline debug", debug_info)
	return debug_info

## 獲取視口調試信息
func get_viewport_debug_info() -> Dictionary:
	var viewport = get_viewport()
	if not viewport:
		return {"error": "No viewport found"}

	var viewport_info = {
		"viewport_size": viewport.get_visible_rect().size,
		"viewport_type": viewport.get_class(),
		"is_subviewport": viewport is SubViewport
	}

	if viewport is SubViewport:
		var subviewport = viewport as SubViewport
		viewport_info.merge({
			"render_target_update_mode": subviewport.render_target_update_mode,
			"handle_input_locally": subviewport.handle_input_locally,
			"snap_2d_transforms_to_pixel": subviewport.snap_2d_transforms_to_pixel,
			"snap_2d_vertices_to_pixel": subviewport.snap_2d_vertices_to_pixel,
			"size": subviewport.size
		})

	return viewport_info

## 獲取Node2D調試信息
func get_node2d_debug_info() -> Dictionary:
	return {
		"global_position": global_position,
		"local_position": position,
		"scale": scale,
		"rotation": rotation,
		"visible": visible,
		"modulate": modulate,
		"z_index": z_index,
		"child_count": get_child_count(),
		"parent": get_parent().name if get_parent() else "None"
	}

## 獲取繪製元素調試信息
func get_drawing_debug_info() -> Dictionary:
	var city_drawer_count = 0
	var connection_drawer_count = 0

	# 計算實際的繪製組件數量
	for city_id in city_nodes:
		var city_node = city_nodes[city_id]
		var circle_node = city_node.get_node_or_null("CityCircle")
		if circle_node:
			var drawer = circle_node.get_node_or_null("CityCircleDrawer")
			if drawer:
				city_drawer_count += 1

	for connection in city_connections:
		var line = connection.get("line")
		if line:
			connection_drawer_count += 1

	return {
		"cities_count": cities_data.size(),
		"connections_count": city_connections.size(),
		"city_nodes_count": city_nodes.size(),
		"city_drawer_count": city_drawer_count,
		"connection_drawer_count": connection_drawer_count,
		"canvas_layer_exists": get_node_or_null("CanvasLayer") != null
	}

## 獲取變換調試信息
func get_transform_debug_info() -> Dictionary:
	return {
		"map_offset": map_offset,
		"map_scale": map_scale,
		"viewport_size": viewport_size,
		"world_bounds": world_bounds if world_bounds != Rect2() else Rect2(),
		"initial_map_scale": initial_map_scale,
		"initial_map_offset": initial_map_offset
	}

## 強制視口刷新
func force_viewport_refresh() -> void:
	var viewport = get_viewport()
	if viewport and viewport is SubViewport:
		var subviewport = viewport as SubViewport
		# 強制啟用渲染更新
		subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		# 觸發尺寸更新
		var current_size = subviewport.size
		subviewport.size = current_size

	# 強制重新繪製所有繪製組件
	force_redraw()

	# 強制城池節點重新繪製
	for city_id in city_nodes:
		var city_node = city_nodes[city_id]
		if city_node:
			var circle_drawer = city_node.get_node_or_null("CityCircle/CityCircleDrawer")
			if circle_drawer and circle_drawer.has_method("queue_redraw"):
				circle_drawer.queue_redraw()

	# 強制連線重新繪製
	for connection in city_connections:
		var line = connection.get("line")
		if line and line.has_method("queue_redraw"):
			line.queue_redraw()

	LogManager.debug("MapArea", "Forced viewport refresh completed")

## 驗證渲染狀態
func validate_rendering_state() -> Array:
	var issues = []

	# 檢查視口狀態
	var viewport = get_viewport()
	if not viewport:
		issues.append("Viewport not found")
	elif viewport is SubViewport:
		var subviewport = viewport as SubViewport
		if subviewport.render_target_update_mode == SubViewport.UPDATE_DISABLED:
			issues.append("SubViewport render target update disabled")
		if subviewport.size == Vector2.ZERO:
			issues.append("SubViewport has zero size")

	# 檢查Node2D狀態
	if not visible:
		issues.append("MapArea not visible")
	if modulate.a < 0.1:
		issues.append("MapArea nearly transparent")

	# 檢查數據
	if cities_data.is_empty():
		issues.append("No cities data loaded")
	if city_nodes.is_empty():
		issues.append("No city nodes created")

	# 檢查節點是否添加到場景樹
	if not is_inside_tree():
		issues.append("MapArea not in scene tree")

	return issues

## 測試繪製基本形狀
func test_basic_drawing() -> void:
	LogManager.info("MapArea", "開始基本繪製測試")

	# 創建測試矩形 - 直接繪製到 MapArea
	queue_redraw()  # 強制重新繪製

	# 創建測試標籤
	var test_label = Label.new()
	test_label.name = "TestLabel"
	test_label.text = "MAP TEST"
	test_label.position = Vector2(200, 100)
	test_label.add_theme_font_size_override("font_size", 24)
	test_label.add_theme_color_override("font_color", Color.YELLOW)
	add_child(test_label)

	LogManager.info("MapArea", "基本繪製測試完成", {
		"test_label_added": test_label.is_inside_tree(),
		"children_count": get_child_count()
	})

# =============================================================================
# 測試繪製功能
# =============================================================================

func _draw() -> void:
	# 測試基本繪製功能
	draw_circle(Vector2(100, 100), 50, Color.RED)
	draw_circle(Vector2(200, 100), 30, Color.GREEN)
	draw_circle(Vector2(300, 100), 40, Color.BLUE)

# 繪製類已移至獨立文件：
# - CityCircleDrawer.gd
# - ConnectionLineDrawer.gd