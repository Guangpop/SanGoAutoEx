# GameEventPanel.gd - 遊戲事件面板組件
#
# 功能：
# - 獨立管理遊戲事件的顯示
# - 自動滾動和事件清理
# - 事件格式化和樣式管理
# - 與外部系統解耦

class_name GameEventPanel
extends Control

# 組件引用
@onready var scroll_container: ScrollContainer
@onready var event_content: VBoxContainer

# 配置參數
@export var max_events: int = 100
@export var auto_scroll: bool = true
@export var event_font_size: int = 14
@export var event_spacing: int = 4

# 事件歷史
var event_history: Array[Dictionary] = []
var event_id_counter: int = 0

# 信號定義
signal event_added(event_data: Dictionary)
signal event_removed(event_id: String)
signal events_cleared()
signal max_events_reached()

func _ready() -> void:
	name = "GameEventPanel"
	_setup_ui_references()
	_configure_scroll_behavior()
	LogManager.info("GameEventPanel", "遊戲事件面板初始化完成")

# =============================================================================
# 公開接口
# =============================================================================

## 添加新事件
func add_event(event_data: Dictionary) -> String:
	# 生成唯一事件ID
	var event_id = _generate_event_id()

	# 完善事件數據
	var complete_event_data = {
		"id": event_id,
		"message": event_data.get("message", "未知事件"),
		"timestamp": Time.get_unix_time_from_system(),
		"type": event_data.get("type", "info"),
		"metadata": event_data.get("metadata", {})
	}

	# 檢查事件數量限制
	if event_history.size() >= max_events:
		_remove_oldest_event()
		max_events_reached.emit()

	# 創建事件UI元素
	var event_ui = _create_event_ui(complete_event_data)
	if event_ui:
		event_content.add_child(event_ui)
		event_history.append(complete_event_data)

		# 自動滾動
		if auto_scroll:
			_scroll_to_bottom()

		event_added.emit(complete_event_data)
		LogManager.debug("GameEventPanel", "事件已添加", {
			"event_id": event_id,
			"type": complete_event_data.type,
			"message_length": complete_event_data.message.length()
		})

	return event_id

## 移除特定事件
func remove_event(event_id: String) -> bool:
	for i in range(event_history.size()):
		if event_history[i].id == event_id:
			# 移除UI元素
			var event_ui = _find_event_ui(event_id)
			if event_ui:
				event_ui.queue_free()

			# 移除歷史記錄
			var removed_event = event_history[i]
			event_history.remove_at(i)

			event_removed.emit(event_id)
			LogManager.debug("GameEventPanel", "事件已移除", {"event_id": event_id})
			return true

	LogManager.warning("GameEventPanel", "事件移除失敗", {"event_id": event_id, "reason": "事件不存在"})
	return false

## 清空所有事件
func clear_events() -> void:
	# 清除UI元素
	for child in event_content.get_children():
		child.queue_free()

	# 清空歷史記錄
	event_history.clear()
	event_id_counter = 0

	events_cleared.emit()
	LogManager.info("GameEventPanel", "所有事件已清空")

## 獲取事件歷史
func get_event_history() -> Array[Dictionary]:
	return event_history.duplicate()

## 獲取最近的N個事件
func get_recent_events(count: int) -> Array[Dictionary]:
	var recent_count = min(count, event_history.size())
	if recent_count <= 0:
		return []

	return event_history.slice(-recent_count)

## 過濾特定類型的事件
func get_events_by_type(event_type: String) -> Array[Dictionary]:
	return event_history.filter(func(event): return event.type == event_type)

# =============================================================================
# 內部方法
# =============================================================================

## 設定UI引用
func _setup_ui_references() -> void:
	# 自動查找子組件
	scroll_container = get_node_or_null("GameEvent")
	if scroll_container:
		event_content = scroll_container.get_node_or_null("EventContent")

	# 驗證組件完整性
	if not scroll_container or not event_content:
		LogManager.error("GameEventPanel", "UI組件引用設定失敗", {
			"scroll_container": scroll_container != null,
			"event_content": event_content != null
		})
	else:
		LogManager.debug("GameEventPanel", "UI組件引用設定成功")

## 配置滾動行為
func _configure_scroll_behavior() -> void:
	if scroll_container:
		scroll_container.set_deferred("scroll_vertical", scroll_container.get_v_scroll_bar().max_value)
		# 確保滾動條在內容變化時自動調整
		event_content.resized.connect(_on_content_resized)

## 內容尺寸變化回調
func _on_content_resized() -> void:
	if auto_scroll and scroll_container:
		_scroll_to_bottom()

## 生成唯一事件ID
func _generate_event_id() -> String:
	event_id_counter += 1
	return "event_%d_%d" % [Time.get_unix_time_from_system(), event_id_counter]

## 創建事件UI元素
func _create_event_ui(event_data: Dictionary) -> Control:
	var event_container = HBoxContainer.new()
	event_container.name = event_data.id

	# 時間戳標籤
	var timestamp_label = Label.new()
	var time_str = _format_timestamp(event_data.timestamp)
	timestamp_label.text = time_str
	timestamp_label.add_theme_font_size_override("font_size", event_font_size - 2)
	timestamp_label.add_theme_color_override("font_color", Color.GRAY)
	timestamp_label.custom_minimum_size.x = 60

	# 事件類型圖標
	var type_icon = Label.new()
	type_icon.text = _get_type_icon(event_data.type)
	type_icon.add_theme_font_size_override("font_size", event_font_size)
	type_icon.custom_minimum_size.x = 24
	type_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 事件訊息
	var message_label = Label.new()
	message_label.text = event_data.message
	message_label.add_theme_font_size_override("font_size", event_font_size)
	message_label.add_theme_color_override("font_color", _get_type_color(event_data.type))
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 組裝容器
	event_container.add_child(timestamp_label)
	event_container.add_child(type_icon)
	event_container.add_child(message_label)

	# 添加分隔間距
	var spacer = Control.new()
	spacer.custom_minimum_size.y = event_spacing
	event_content.add_child(spacer)

	return event_container

## 格式化時間戳
func _format_timestamp(timestamp: float) -> String:
	var datetime = Time.get_datetime_dict_from_unix_time(int(timestamp))
	return "%02d:%02d" % [datetime.hour, datetime.minute]

## 獲取事件類型圖標
func _get_type_icon(event_type: String) -> String:
	match event_type:
		"info": return "ℹ️"
		"warning": return "⚠️"
		"error": return "❌"
		"success": return "✅"
		"battle": return "⚔️"
		"diplomacy": return "🤝"
		"economy": return "💰"
		"technology": return "🔬"
		_: return "📝"

## 獲取事件類型顏色
func _get_type_color(event_type: String) -> Color:
	match event_type:
		"info": return Color.WHITE
		"warning": return Color.YELLOW
		"error": return Color.RED
		"success": return Color.GREEN
		"battle": return Color.ORANGE_RED
		"diplomacy": return Color.LIGHT_BLUE
		"economy": return Color.GOLD
		"technology": return Color.CYAN
		_: return Color.LIGHT_GRAY

## 滾動到底部
func _scroll_to_bottom() -> void:
	if scroll_container:
		await get_tree().process_frame
		scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

## 移除最舊事件
func _remove_oldest_event() -> void:
	if event_history.size() > 0:
		var oldest_event = event_history[0]
		remove_event(oldest_event.id)

## 查找事件UI元素
func _find_event_ui(event_id: String) -> Control:
	if event_content:
		return event_content.get_node_or_null(event_id)
	return null

# =============================================================================
# 配置方法
# =============================================================================

## 設定最大事件數量
func set_max_events(count: int) -> void:
	max_events = max(1, count)

	# 如果當前事件超過限制，移除舊事件
	while event_history.size() > max_events:
		_remove_oldest_event()

## 設定自動滾動
func set_auto_scroll(enabled: bool) -> void:
	auto_scroll = enabled
	if enabled:
		_scroll_to_bottom()

## 設定事件字體大小
func set_event_font_size(size: int) -> void:
	event_font_size = max(8, size)
	# 注意：已存在的事件不會自動更新字體大小