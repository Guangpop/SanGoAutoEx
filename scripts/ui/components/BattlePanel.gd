# BattlePanel.gd - 戰鬥面板組件
#
# 功能：
# - 獨立管理戰鬥UI顯示和互動
# - 戰鬥動畫和效果管理
# - 與外部戰鬥系統解耦
# - 展示穩健UI架構設計的擴展性

class_name BattlePanel
extends Control

# 戰鬥UI元素
@onready var battle_info_label: Label
@onready var player_health_bar: ProgressBar
@onready var enemy_health_bar: ProgressBar
@onready var action_buttons_container: HBoxContainer

# 戰鬥狀態
var current_battle_data: Dictionary = {}
var battle_active: bool = false
var animation_queue: Array[Dictionary] = []

# 信號定義
signal battle_action_selected(action_type: String, target: String)
signal battle_animation_completed(animation_id: String)
signal battle_ui_closed()

func _ready() -> void:
	name = "BattlePanel"
	visible = false  # 默認隱藏
	_setup_ui_components()
	LogManager.info("BattlePanel", "戰鬥面板組件初始化完成")

# =============================================================================
# 公開接口 - 穩定的API
# =============================================================================

## 顯示戰鬥UI
func show_battle(battle_data: Dictionary) -> void:
	current_battle_data = battle_data
	battle_active = true
	_update_battle_display()
	visible = true

	LogManager.info("BattlePanel", "戰鬥UI已顯示", {
		"player": battle_data.get("player_name", "未知"),
		"enemy": battle_data.get("enemy_name", "未知")
	})

## 隱藏戰鬥UI
func hide_battle() -> void:
	battle_active = false
	current_battle_data.clear()
	animation_queue.clear()
	visible = false
	battle_ui_closed.emit()

	LogManager.info("BattlePanel", "戰鬥UI已隱藏")

## 更新戰鬥狀態
func update_battle_state(new_data: Dictionary) -> void:
	if not battle_active:
		LogManager.warning("BattlePanel", "嘗試更新非活動戰鬥狀態")
		return

	current_battle_data.merge(new_data, true)
	_update_battle_display()

## 播放戰鬥動畫
func play_battle_animation(animation_data: Dictionary) -> void:
	if not battle_active:
		return

	var animation_id = animation_data.get("id", "unknown_" + str(Time.get_unix_time_from_system()))
	animation_queue.append(animation_data)

	_execute_next_animation()
	LogManager.debug("BattlePanel", "戰鬥動畫已加入隊列", {"animation_id": animation_id})

## 檢查戰鬥是否活動
func is_battle_active() -> bool:
	return battle_active and visible

# =============================================================================
# 內部實現
# =============================================================================

## 設定UI組件
func _setup_ui_components() -> void:
	# 創建基本UI結構 (如果不存在)
	if not battle_info_label:
		battle_info_label = Label.new()
		battle_info_label.name = "BattleInfoLabel"
		battle_info_label.text = "戰鬥準備中..."
		add_child(battle_info_label)

	if not player_health_bar:
		player_health_bar = ProgressBar.new()
		player_health_bar.name = "PlayerHealthBar"
		player_health_bar.max_value = 100
		player_health_bar.value = 100
		add_child(player_health_bar)

	if not enemy_health_bar:
		enemy_health_bar = ProgressBar.new()
		enemy_health_bar.name = "EnemyHealthBar"
		enemy_health_bar.max_value = 100
		enemy_health_bar.value = 100
		add_child(enemy_health_bar)

	if not action_buttons_container:
		action_buttons_container = HBoxContainer.new()
		action_buttons_container.name = "ActionButtons"
		_create_action_buttons()
		add_child(action_buttons_container)

## 創建行動按鈕
func _create_action_buttons() -> void:
	var actions = ["攻擊", "防禦", "技能", "逃跑"]

	for action in actions:
		var button = Button.new()
		button.text = action
		button.custom_minimum_size = Vector2(80, 40)
		button.pressed.connect(_on_action_button_pressed.bind(action))
		action_buttons_container.add_child(button)

## 行動按鈕回調
func _on_action_button_pressed(action: String) -> void:
	battle_action_selected.emit(action, "enemy")  # 簡化目標選擇
	LogManager.debug("BattlePanel", "戰鬥行動已選擇", {"action": action})

## 更新戰鬥顯示
func _update_battle_display() -> void:
	if not current_battle_data:
		return

	# 更新戰鬥信息
	if battle_info_label:
		var player_name = current_battle_data.get("player_name", "玩家")
		var enemy_name = current_battle_data.get("enemy_name", "敵人")
		battle_info_label.text = "%s VS %s" % [player_name, enemy_name]

	# 更新血量條
	if player_health_bar:
		var player_hp = current_battle_data.get("player_hp", 100)
		var player_max_hp = current_battle_data.get("player_max_hp", 100)
		player_health_bar.max_value = player_max_hp
		player_health_bar.value = player_hp

	if enemy_health_bar:
		var enemy_hp = current_battle_data.get("enemy_hp", 100)
		var enemy_max_hp = current_battle_data.get("enemy_max_hp", 100)
		enemy_health_bar.max_value = enemy_max_hp
		enemy_health_bar.value = enemy_hp

## 執行下一個動畫
func _execute_next_animation() -> void:
	if animation_queue.is_empty():
		return

	var animation_data = animation_queue.pop_front()
	var animation_type = animation_data.get("type", "unknown")
	var animation_id = animation_data.get("id", "unknown")

	match animation_type:
		"damage":
			_play_damage_animation(animation_data)
		"heal":
			_play_heal_animation(animation_data)
		"miss":
			_play_miss_animation(animation_data)
		_:
			LogManager.warning("BattlePanel", "未知動畫類型", {"type": animation_type})
			battle_animation_completed.emit(animation_id)

## 播放傷害動畫
func _play_damage_animation(animation_data: Dictionary) -> void:
	var target = animation_data.get("target", "enemy")
	var damage = animation_data.get("damage", 0)
	var animation_id = animation_data.get("id", "damage")

	# 簡單的血量條動畫
	var target_bar = enemy_health_bar if target == "enemy" else player_health_bar
	if target_bar:
		var tween = create_tween()
		var new_value = max(0, target_bar.value - damage)
		tween.tween_property(target_bar, "value", new_value, 0.5)
		tween.tween_callback(func(): battle_animation_completed.emit(animation_id))
	else:
		battle_animation_completed.emit(animation_id)

## 播放治療動畫
func _play_heal_animation(animation_data: Dictionary) -> void:
	var target = animation_data.get("target", "player")
	var heal_amount = animation_data.get("heal", 0)
	var animation_id = animation_data.get("id", "heal")

	var target_bar = player_health_bar if target == "player" else enemy_health_bar
	if target_bar:
		var tween = create_tween()
		var new_value = min(target_bar.max_value, target_bar.value + heal_amount)
		tween.tween_property(target_bar, "value", new_value, 0.5)
		tween.tween_callback(func(): battle_animation_completed.emit(animation_id))
	else:
		battle_animation_completed.emit(animation_id)

## 播放閃避動畫
func _play_miss_animation(animation_data: Dictionary) -> void:
	var animation_id = animation_data.get("id", "miss")

	# 簡單的閃爍效果
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.5, 0.1)
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	tween.tween_callback(func(): battle_animation_completed.emit(animation_id))

# =============================================================================
# 示例：展示如何與UIManager整合
# =============================================================================

## 這個方法展示了如何讓BattlePanel通過UIManager管理
## 而不是直接被其他系統調用
static func register_to_ui_manager(ui_manager: UIManager, battle_panel: BattlePanel) -> void:
	if not ui_manager or not battle_panel:
		return

	# UIManager可以擴展接口來支持戰鬥面板
	# 例如：ui_manager.register_battle_panel(battle_panel)
	# 然後其他系統可以通過 ui_manager.show_battle(battle_data) 來使用

	LogManager.info("BattlePanel", "BattlePanel已註冊到UIManager")