# UIManager.gd - 統一UI管理器
#
# 功能：
# - 集中管理所有UI組件引用
# - 提供穩定的公開接口
# - 內建錯誤處理和容錯機制
# - 避免外部系統直接依賴UI節點路徑

class_name UIManager
extends Node

# UI組件引用 (內部管理，外部不直接存取)
var _main_mobile: Control
var _event_panel: Control
var _map_display: SubViewport
var _battle_panel: Control
var _skill_panel: Control

# 組件狀態追蹤
var _component_health: Dictionary = {}
var _initialization_complete: bool = false

# 信號定義
signal ui_component_ready(component_name: String)
signal ui_component_error(component_name: String, error_message: String)
signal ui_structure_validated()

func _ready() -> void:
	LogManager.info("UIManager", "UIManager 初始化開始")
	name = "UIManager"

# =============================================================================
# 公開接口 - 穩定不變的API
# =============================================================================

## 設定UI引用 (由MainMobile調用)
func setup_ui_references(main_mobile: Control) -> void:
	_main_mobile = main_mobile
	_discover_ui_components()
	_validate_ui_structure()
	_initialization_complete = true
	LogManager.info("UIManager", "UI引用設定完成")

## 獲取事件容器 (替代直接節點存取)
func get_event_container() -> VBoxContainer:
	if _event_panel:
		return _event_panel.get_node_or_null("EventContent")
	LogManager.warning("UIManager", "EventContainer不可用")
	return null

## 獲取地圖視窗 (替代直接節點存取)
func get_map_viewport() -> SubViewport:
	if _map_display:
		return _map_display
	LogManager.warning("UIManager", "MapViewport不可用")
	return null

## 添加遊戲事件 (統一接口)
func add_game_event(event_data: Dictionary) -> bool:
	var event_container = get_event_container()
	if not event_container:
		LogManager.error("UIManager", "無法添加遊戲事件", {"reason": "EventContainer不存在"})
		return false

	# 創建事件UI元素
	var event_label = Label.new()
	event_label.text = event_data.get("message", "未知事件")
	event_label.add_theme_font_size_override("font_size", 14)
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	event_container.add_child(event_label)

	# 自動滾動到底部
	var scroll_container = event_container.get_parent()
	if scroll_container is ScrollContainer:
		scroll_container.call_deferred("ensure_control_visible", event_label)

	LogManager.debug("UIManager", "遊戲事件已添加", {"event": event_data})
	return true

## 更新地圖顯示 (統一接口)
func update_map_display(cities_data: Array) -> bool:
	var map_viewport = get_map_viewport()
	if not map_viewport:
		LogManager.error("UIManager", "無法更新地圖顯示", {"reason": "MapViewport不存在"})
		return false

	# 獲取MapRoot Node2D
	var map_root = map_viewport.get_node_or_null("MapRoot")
	if not map_root:
		LogManager.error("UIManager", "MapRoot節點不存在")
		return false

	# 通知MapRoot更新城市數據
	if map_root.has_method("update_cities_data"):
		map_root.update_cities_data(cities_data)
		LogManager.debug("UIManager", "地圖數據已更新", {"cities_count": cities_data.size()})
		return true
	else:
		LogManager.warning("UIManager", "MapRoot缺少update_cities_data方法")
		return false

## 顯示/隱藏戰鬥UI
func toggle_battle_ui(show: bool) -> bool:
	if _battle_panel:
		_battle_panel.visible = show
		LogManager.debug("UIManager", "戰鬥UI切換", {"visible": show})
		return true
	LogManager.warning("UIManager", "BattleUI不可用")
	return false

## 顯示/隱藏技能選擇UI
func toggle_skill_ui(show: bool) -> bool:
	if _skill_panel:
		_skill_panel.visible = show
		LogManager.debug("UIManager", "技能選擇UI切換", {"visible": show})
		return true
	LogManager.warning("UIManager", "SkillSelectionUI不可用")
	return false

# =============================================================================
# 內部方法 - 私有實現
# =============================================================================

## 自動發現UI組件
func _discover_ui_components() -> void:
	if not _main_mobile:
		LogManager.error("UIManager", "MainMobile引用為空")
		return

	# 尋找事件面板
	_event_panel = _main_mobile.get_node_or_null("SafeAreaContainer/VBoxContainer/GameMainArea/GameEventOverlay/GameEvent")
	_track_component_health("EventPanel", _event_panel != null)

	# 尋找地圖顯示 (SubViewport)
	_map_display = _main_mobile.get_node_or_null("SafeAreaContainer/VBoxContainer/GameMainArea/MapArea")
	_track_component_health("MapDisplay", _map_display != null)

	# 尋找戰鬥UI
	_battle_panel = _main_mobile.get_node_or_null("BattleUI")
	_track_component_health("BattlePanel", _battle_panel != null)

	# 尋找技能選擇UI (假設存在)
	_skill_panel = _main_mobile.get_node_or_null("SkillSelectionUI")
	_track_component_health("SkillPanel", _skill_panel != null)

	LogManager.info("UIManager", "UI組件發現完成", _component_health)

## 驗證UI結構完整性
func _validate_ui_structure() -> bool:
	var validation_results = []

	# 檢查關鍵組件
	validation_results.append(_validate_component("EventPanel", _event_panel, "SafeAreaContainer/VBoxContainer/GameMainArea/GameEventOverlay"))
	validation_results.append(_validate_component("MapDisplay", _map_display, "SafeAreaContainer/VBoxContainer/GameMainArea/MapArea"))

	# 檢查子組件
	if _event_panel:
		var scroll_container = _event_panel.get_node_or_null("GameEvent")
		validation_results.append(scroll_container != null)
		if scroll_container:
			var event_content = scroll_container.get_node_or_null("EventContent")
			validation_results.append(event_content != null)

	if _map_display:
		var map_root = _map_display.get_node_or_null("MapRoot")
		validation_results.append(map_root != null)

	var all_valid = validation_results.all(func(result): return result)

	if all_valid:
		LogManager.info("UIManager", "UI結構驗證通過")
		ui_structure_validated.emit()
	else:
		LogManager.error("UIManager", "UI結構驗證失敗", {"validation_results": validation_results})

	return all_valid

## 驗證單個組件
func _validate_component(name: String, component: Node, expected_path: String) -> bool:
	if component:
		ui_component_ready.emit(name)
		LogManager.debug("UIManager", f"組件 {name} 驗證通過", {"path": expected_path})
		return true
	else:
		ui_component_error.emit(name, f"組件在路徑 {expected_path} 未找到")
		LogManager.error("UIManager", f"組件 {name} 驗證失敗", {"expected_path": expected_path})
		return false

## 追蹤組件健康狀況
func _track_component_health(component_name: String, is_healthy: bool) -> void:
	_component_health[component_name] = {
		"healthy": is_healthy,
		"last_check": Time.get_unix_time_from_system()
	}

# =============================================================================
# 健康監控和診斷
# =============================================================================

## 獲取組件健康狀況
func get_component_health() -> Dictionary:
	return _component_health.duplicate()

## 診斷UI問題
func diagnose_ui_issues() -> Array:
	var issues = []

	if not _initialization_complete:
		issues.append("UIManager尚未完成初始化")

	for component_name in _component_health:
		var health_data = _component_health[component_name]
		if not health_data.healthy:
			issues.append(f"組件 {component_name} 不可用")

	return issues

## 嘗試修復UI問題
func attempt_ui_repair() -> bool:
	LogManager.info("UIManager", "嘗試修復UI問題")

	if _main_mobile:
		_discover_ui_components()
		return _validate_ui_structure()

	LogManager.error("UIManager", "無法修復 - MainMobile引用丟失")
	return false