# BattleOverlay.gd - 移動端優化戰鬥覆蓋層
#
# 功能：
# - 414x896 移動端優化的戰鬥UI
# - 實時戰鬥進度顯示與動畫
# - 觸控優化的速度控制
# - 傷害數字和技能效果動畫

extends Control

# UI 節點引用
@onready var battle_background: ColorRect = $BattleBackground
@onready var attacker_name: Label = $BattleMainContainer/BattleHeader/BattleTitle/AttackerInfo/AttackerName
@onready var attacker_power: Label = $BattleMainContainer/BattleHeader/BattleTitle/AttackerInfo/AttackerPower
@onready var defender_name: Label = $BattleMainContainer/BattleHeader/BattleTitle/DefenderInfo/DefenderName
@onready var defender_power: Label = $BattleMainContainer/BattleHeader/BattleTitle/DefenderInfo/DefenderPower
@onready var battle_progress: ProgressBar = $BattleMainContainer/BattleHeader/BattleProgress
@onready var progress_label: Label = $BattleMainContainer/BattleHeader/ProgressLabel

# 戰鬥區域
@onready var attacker_avatar: Label = $BattleMainContainer/BattleCombatArea/GeneralsDisplay/AttackerGeneral/AttackerAvatar
@onready var attacker_hp: ProgressBar = $BattleMainContainer/BattleCombatArea/GeneralsDisplay/AttackerGeneral/AttackerHP
@onready var attacker_hp_label: Label = $BattleMainContainer/BattleCombatArea/GeneralsDisplay/AttackerGeneral/AttackerHPLabel
@onready var defender_avatar: Label = $BattleMainContainer/BattleCombatArea/GeneralsDisplay/DefenderGeneral/DefenderAvatar
@onready var defender_hp: ProgressBar = $BattleMainContainer/BattleCombatArea/GeneralsDisplay/DefenderGeneral/DefenderHP
@onready var defender_hp_label: Label = $BattleMainContainer/BattleCombatArea/GeneralsDisplay/DefenderGeneral/DefenderHPLabel
@onready var effect_label: Label = $BattleMainContainer/BattleCombatArea/GeneralsDisplay/CombatEffects/EffectLabel

# 戰鬥記錄
@onready var log_content: VBoxContainer = $BattleMainContainer/BattleLog/LogScrollContainer/LogContent

# 控制按鈕
@onready var speed_1x: Button = $BattleMainContainer/BattleControls/SpeedControls/Speed1x
@onready var speed_2x: Button = $BattleMainContainer/BattleControls/SpeedControls/Speed2x
@onready var speed_4x: Button = $BattleMainContainer/BattleControls/SpeedControls/Speed4x
@onready var speed_max: Button = $BattleMainContainer/BattleControls/SpeedControls/SpeedMax
@onready var skip_button: Button = $BattleMainContainer/BattleControls/ActionButtons/SkipButton
@onready var close_button: Button = $BattleMainContainer/BattleControls/ActionButtons/CloseButton

# 戰鬥狀態
var current_battle_data: Dictionary = {}
var battle_speed: float = 1.0
var is_battle_active: bool = false
var battle_start_time: float = 0.0
var battle_duration: float = 3.0

# 血量動畫
var attacker_current_hp: float = 100.0
var attacker_max_hp: float = 100.0
var defender_current_hp: float = 100.0
var defender_max_hp: float = 100.0

# 動畫效果
var damage_number_scene: PackedScene
var active_animations: Array = []

func _ready() -> void:
	name = "BattleOverlay"
	visible = false

	# 連接按鈕事件
	speed_1x.pressed.connect(_on_speed_button_pressed.bind(1.0))
	speed_2x.pressed.connect(_on_speed_button_pressed.bind(2.0))
	speed_4x.pressed.connect(_on_speed_button_pressed.bind(4.0))
	speed_max.pressed.connect(_on_speed_button_pressed.bind(10.0))
	skip_button.pressed.connect(_on_skip_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)

	# 連接事件總線
	EventBus.connect_safe("battle_started", _on_battle_started)
	EventBus.connect_safe("battle_completed", _on_battle_completed)
	EventBus.connect_safe("battle_damage_dealt", _on_damage_dealt)
	EventBus.connect_safe("battle_skill_activated", _on_skill_activated)

	# 設置默認按鈕狀態
	_update_speed_button_states()

	LogManager.info("BattleOverlay", "移動端戰鬥覆蓋層初始化完成")

# === 戰鬥顯示控制 ===

func show_battle(attacker_data: Dictionary, defender_data: Dictionary, city_name: String) -> void:
	if is_battle_active:
		LogManager.warn("BattleOverlay", "戰鬥已在進行中")
		return

	current_battle_data = {
		"attacker": attacker_data,
		"defender": defender_data,
		"city_name": city_name,
		"start_time": Time.get_unix_time_from_system()
	}

	_setup_battle_display()
	_start_battle_animation()

	visible = true
	is_battle_active = true
	battle_start_time = Time.get_unix_time_from_system()

	# 移動端觸控反饋
	_trigger_haptic_feedback("light")

	LogManager.info("BattleOverlay", "戰鬥顯示開始", {
		"city": city_name,
		"attacker": attacker_data.get("general_name", "主公"),
		"defender": defender_data.get("general_name", "守將")
	})

func _setup_battle_display() -> void:
	var attacker = current_battle_data.attacker
	var defender = current_battle_data.defender
	var city_name = current_battle_data.city_name

	# 設置戰鬥信息
	attacker_name.text = attacker.get("general_name", "主公")
	attacker_power.text = "戰力: %d" % attacker.get("power_rating", 1000)

	defender_name.text = defender.get("general_name", "守將")
	defender_power.text = "戰力: %d" % defender.get("power_rating", 800)

	# 初始化血量
	attacker_max_hp = float(attacker.get("troops", 1000))
	attacker_current_hp = attacker_max_hp
	defender_max_hp = float(defender.get("troops", 800))
	defender_current_hp = defender_max_hp

	_update_hp_displays()

	# 重置進度條
	battle_progress.value = 0
	progress_label.text = "戰鬥即將開始..."

	# 設置戰鬥精靈
	_setup_battle_avatars()

	# 清空戰鬥記錄
	_clear_battle_log()

	_add_battle_log_entry("🏰 攻打城池: %s" % city_name)

func _setup_battle_avatars() -> void:
	var attacker = current_battle_data.attacker
	var defender = current_battle_data.defender

	# 根據將領類型設置頭像
	var attacker_icon = _get_general_icon(attacker.get("general_name", "主公"))
	var defender_icon = _get_general_icon(defender.get("general_name", "守將"))

	attacker_avatar.text = attacker_icon
	defender_avatar.text = defender_icon

	# 重置特效
	effect_label.modulate.a = 0.0
	effect_label.scale = Vector2.ONE

func _get_general_icon(general_name: String) -> String:
	# 根據武將名稱返回對應圖標
	var icons = {
		"主公": "👤",
		"劉備": "👑",
		"關羽": "⚔️",
		"張飛": "🗡️",
		"諸葛亮": "📜",
		"曹操": "👑",
		"孫權": "👑",
		"守將": "🛡️",
		"守城將領": "🏰"
	}

	return icons.get(general_name, "⚔️")

# === 戰鬥動畫系統 ===

func _start_battle_animation() -> void:
	battle_duration = 3.0 / battle_speed

	# 開始進度動畫
	var progress_tween = create_tween()
	progress_tween.tween_method(_update_battle_progress, 0.0, 100.0, battle_duration)
	progress_tween.finished.connect(_on_battle_animation_complete)

	# 開始戰鬥特效循環
	_start_combat_effects_loop()

	# 開始血量變化動畫
	_start_hp_animation()

func _update_battle_progress(value: float) -> void:
	battle_progress.value = value

	# 更新進度文字
	if value < 25:
		progress_label.text = "戰鬥準備階段 (%.0f%%)" % value
	elif value < 50:
		progress_label.text = "激烈交戰中 (%.0f%%)" % value
	elif value < 75:
		progress_label.text = "決勝關鍵時刻 (%.0f%%)" % value
	else:
		progress_label.text = "戰鬥即將結束 (%.0f%%)" % value

	# 階段性戰鬥記錄
	if int(value) % 25 == 0 and int(value) > 0:
		_add_stage_log_entry(value)

func _start_combat_effects_loop() -> void:
	var effects_timer = Timer.new()
	effects_timer.wait_time = 0.8 / battle_speed
	effects_timer.timeout.connect(_trigger_combat_effect)
	effects_timer.autostart = true
	add_child(effects_timer)

	# 清理定時器
	create_tween().tween_delay(battle_duration + 1.0).tween_callback(effects_timer.queue_free)

func _trigger_combat_effect() -> void:
	if not is_battle_active:
		return

	# 隨機戰鬥特效
	var effects = ["💥", "⚡", "🔥", "💫", "⭐", "🌟", "💢", "🎯"]
	effect_label.text = effects[randi() % effects.size()]

	# 特效動畫
	var effect_tween = create_tween()
	effect_tween.parallel().tween_property(effect_label, "modulate:a", 1.0, 0.1)
	effect_tween.parallel().tween_property(effect_label, "scale", Vector2(1.3, 1.3), 0.1)
	effect_tween.tween_delay(0.3 / battle_speed)
	effect_tween.parallel().tween_property(effect_label, "modulate:a", 0.0, 0.2)
	effect_tween.parallel().tween_property(effect_label, "scale", Vector2.ONE, 0.2)

	# 觸發輕微震動
	_trigger_screen_shake(2.0)

func _start_hp_animation() -> void:
	# 攻擊方和防守方交替受傷
	var hp_timer = Timer.new()
	hp_timer.wait_time = 1.2 / battle_speed
	hp_timer.timeout.connect(_simulate_damage_exchange)
	hp_timer.autostart = true
	add_child(hp_timer)

	# 清理定時器
	create_tween().tween_delay(battle_duration + 1.0).tween_callback(hp_timer.queue_free)

func _simulate_damage_exchange() -> void:
	if not is_battle_active:
		return

	# 隨機傷害交換
	var attacker_damage = randf_range(50, 150)
	var defender_damage = randf_range(30, 120)

	# 應用傷害
	defender_current_hp = max(0, defender_current_hp - attacker_damage)
	attacker_current_hp = max(0, attacker_current_hp - defender_damage)

	# 更新血量顯示
	_update_hp_displays()

	# 顯示傷害數字
	_show_damage_number(attacker_damage, false)  # 對防守方造成傷害
	_show_damage_number(defender_damage, true)   # 對攻擊方造成傷害

func _update_hp_displays() -> void:
	# 更新攻擊方血量
	var attacker_hp_percent = (attacker_current_hp / attacker_max_hp) * 100.0
	attacker_hp.value = attacker_hp_percent
	attacker_hp_label.text = "HP: %.0f/%.0f" % [attacker_current_hp, attacker_max_hp]

	# 血量顏色變化
	if attacker_hp_percent > 60:
		attacker_hp.modulate = Color.GREEN
	elif attacker_hp_percent > 30:
		attacker_hp.modulate = Color.YELLOW
	else:
		attacker_hp.modulate = Color.RED

	# 更新防守方血量
	var defender_hp_percent = (defender_current_hp / defender_max_hp) * 100.0
	defender_hp.value = defender_hp_percent
	defender_hp_label.text = "HP: %.0f/%.0f" % [defender_current_hp, defender_max_hp]

	# 血量顏色變化
	if defender_hp_percent > 60:
		defender_hp.modulate = Color.GREEN
	elif defender_hp_percent > 30:
		defender_hp.modulate = Color.YELLOW
	else:
		defender_hp.modulate = Color.RED

# === 傷害數字動畫 ===

func _show_damage_number(damage: float, is_attacker_damaged: bool) -> void:
	var damage_label = Label.new()
	damage_label.text = "-%.0f" % damage
	damage_label.theme_override_font_sizes.font_size = 24
	damage_label.modulate = Color.RED if damage > 100 else Color.ORANGE

	# 設置起始位置
	var start_pos: Vector2
	if is_attacker_damaged:
		start_pos = attacker_avatar.global_position + Vector2(40, 20)
	else:
		start_pos = defender_avatar.global_position + Vector2(-40, 20)

	damage_label.position = start_pos
	add_child(damage_label)

	# 傷害數字動畫
	var damage_tween = create_tween()
	damage_tween.parallel().tween_property(damage_label, "position:y", start_pos.y - 60, 1.0)
	damage_tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 1.0)
	damage_tween.tween_callback(damage_label.queue_free)

# === 戰鬥記錄系統 ===

func _add_battle_log_entry(message: String) -> void:
	var log_label = Label.new()
	log_label.text = message
	log_label.theme_override_font_sizes.font_size = 16
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	log_content.add_child(log_label)

	# 限制記錄數量
	if log_content.get_child_count() > 8:
		var oldest = log_content.get_child(0)
		oldest.queue_free()

	# 自動滾動到底部
	await get_tree().process_frame
	var scroll_container = log_content.get_parent()
	if scroll_container is ScrollContainer:
		scroll_container.ensure_control_visible(log_label)

func _add_stage_log_entry(progress: float) -> void:
	var messages = []

	if progress <= 25:
		messages = ["⚔️ 攻方發起衝鋒", "🛡️ 守方嚴陣以待", "🏹 弓箭手開始射擊"]
	elif progress <= 50:
		messages = ["💥 雙方激烈交戰", "⚡ 戰況十分激烈", "🩸 開始出現傷亡"]
	elif progress <= 75:
		messages = ["🔥 戰況白熱化", "🌪️ 將領親自上陣", "⭐ 戰局開始明朗"]
	else:
		messages = ["🏆 勝負即將分曉", "🎯 最後的決戰時刻", "🏁 戰鬥即將結束"]

	var message = messages[randi() % messages.size()]
	_add_battle_log_entry(message)

func _clear_battle_log() -> void:
	for child in log_content.get_children():
		child.queue_free()

# === 戰鬥結果處理 ===

func _on_battle_animation_complete() -> void:
	progress_label.text = "戰鬥結束，計算結果中..."
	battle_progress.value = 100

	_add_battle_log_entry("🏁 戰鬥結束，等待結果...")

func hide_battle() -> void:
	if not is_battle_active:
		return

	# 清理動畫
	_cleanup_animations()

	visible = false
	is_battle_active = false
	current_battle_data.clear()

	LogManager.info("BattleOverlay", "戰鬥覆蓋層已隱藏")

func _cleanup_animations() -> void:
	# 停止所有Tween
	for child in get_children():
		if child is Tween:
			child.kill()

	# 清理臨時節點
	for child in get_children():
		if child is Timer or child is Label:
			if child != effect_label and not child.get_parent() == log_content:
				child.queue_free()

# === 控制按鈕事件 ===

func _on_speed_button_pressed(speed: float) -> void:
	battle_speed = speed
	_update_speed_button_states()

	LogManager.info("BattleOverlay", "戰鬥速度調整", {"new_speed": battle_speed})
	_trigger_haptic_feedback("light")

func _update_speed_button_states() -> void:
	# 重置所有按鈕
	speed_1x.modulate = Color.WHITE
	speed_2x.modulate = Color.WHITE
	speed_4x.modulate = Color.WHITE
	speed_max.modulate = Color.WHITE

	# 高亮當前速度
	match battle_speed:
		1.0:
			speed_1x.modulate = Color.CYAN
		2.0:
			speed_2x.modulate = Color.CYAN
		4.0:
			speed_4x.modulate = Color.CYAN
		10.0:
			speed_max.modulate = Color.CYAN

func _on_skip_button_pressed() -> void:
	if not is_battle_active:
		return

	# 跳過動畫，直接完成戰鬥
	_cleanup_animations()
	battle_progress.value = 100
	progress_label.text = "動畫已跳過，等待結果..."

	_add_battle_log_entry("⏭️ 戰鬥動畫已跳過")

	LogManager.info("BattleOverlay", "戰鬥動畫已跳過")
	_trigger_haptic_feedback("medium")

func _on_close_button_pressed() -> void:
	hide_battle()
	_trigger_haptic_feedback("light")

# === 移動端優化功能 ===

func _trigger_haptic_feedback(strength: String) -> void:
	# 移動端觸覺反饋
	if OS.has_feature("mobile"):
		match strength:
			"light":
				Input.vibrate_handheld(50)
			"medium":
				Input.vibrate_handheld(100)
			"heavy":
				Input.vibrate_handheld(200)

func _trigger_screen_shake(intensity: float = 1.0) -> void:
	var shake_tween = create_tween()
	var original_pos = position

	for i in range(int(intensity * 2)):
		var shake_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		shake_tween.tween_property(self, "position", original_pos + shake_offset, 0.05)
		shake_tween.tween_property(self, "position", original_pos, 0.05)

# === EventBus 事件處理器 ===

func _on_battle_started(attacker: Dictionary, defender: Dictionary, city_name: String) -> void:
	show_battle(attacker, defender, city_name)

func _on_battle_completed(result: Dictionary, victor: String, casualties: Dictionary) -> void:
	if not is_battle_active:
		return

	_show_battle_result(result, victor, casualties)

	# 延遲隱藏
	await get_tree().create_timer(3.0).timeout
	hide_battle()

func _show_battle_result(result: Dictionary, victor: String, casualties: Dictionary) -> void:
	# 更新UI顯示結果
	if victor == "player":
		progress_label.text = "🏆 勝利！城池已佔領"
		_add_battle_log_entry("🎉 攻城成功！")
		_trigger_haptic_feedback("heavy")
	else:
		progress_label.text = "💔 敗北！攻城失敗"
		_add_battle_log_entry("😞 攻城失敗，撤退")
		_trigger_haptic_feedback("medium")

	# 顯示戰利品
	if result.has("spoils"):
		var spoils = result.spoils
		if spoils.get("gold", 0) > 0:
			_add_battle_log_entry("💰 獲得金錢: %d" % spoils.gold)
		if spoils.get("equipment", []).size() > 0:
			_add_battle_log_entry("⚔️ 獲得裝備: %d件" % spoils.equipment.size())

func _on_damage_dealt(damage_data: Dictionary) -> void:
	if not is_battle_active:
		return

	var damage = damage_data.get("damage", 0)
	var target = damage_data.get("target", "")
	var is_critical = damage_data.get("critical", false)

	# 顯示傷害
	if target == "attacker":
		_show_damage_number(damage, true)
	else:
		_show_damage_number(damage, false)

	# 暴擊特效
	if is_critical:
		_trigger_combat_effect()
		_trigger_screen_shake(3.0)

func _on_skill_activated(skill_data: Dictionary) -> void:
	if not is_battle_active:
		return

	var skill_name = skill_data.get("skill_name", "未知技能")
	var caster = skill_data.get("caster", "")

	_add_battle_log_entry("✨ %s 發動技能: %s" % [caster, skill_name])

	# 技能特效
	effect_label.text = "✨"
	var skill_tween = create_tween()
	skill_tween.parallel().tween_property(effect_label, "modulate:a", 1.0, 0.2)
	skill_tween.parallel().tween_property(effect_label, "scale", Vector2(2.0, 2.0), 0.2)
	skill_tween.tween_delay(0.5)
	skill_tween.parallel().tween_property(effect_label, "modulate:a", 0.0, 0.3)
	skill_tween.parallel().tween_property(effect_label, "scale", Vector2.ONE, 0.3)

	_trigger_screen_shake(4.0)
	_trigger_haptic_feedback("heavy")