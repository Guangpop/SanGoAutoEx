extends Control

@onready var battle_title: Label = $BattleContainer/BattleTitle
@onready var city_info: Label = $BattleContainer/BattleInfo/CityInfo
@onready var attacker_troops: Label = $BattleContainer/BattleInfo/ForcesComparison/AttackerInfo/AttackerTroops
@onready var attacker_general: Label = $BattleContainer/BattleInfo/ForcesComparison/AttackerInfo/AttackerGeneral
@onready var defender_troops: Label = $BattleContainer/BattleInfo/ForcesComparison/DefenderInfo/DefenderTroops
@onready var defender_general: Label = $BattleContainer/BattleInfo/ForcesComparison/DefenderInfo/DefenderGeneral
@onready var progress_bar: ProgressBar = $BattleContainer/BattleProgress/ProgressBar
@onready var progress_label: Label = $BattleContainer/BattleProgress/ProgressLabel
@onready var attacker_sprite: Label = $BattleContainer/BattleProgress/BattleAnimation/AttackerSprite
@onready var defender_sprite: Label = $BattleContainer/BattleProgress/BattleAnimation/DefenderSprite
@onready var battle_effects: Label = $BattleContainer/BattleProgress/BattleAnimation/BattleEffects
@onready var log_content: VBoxContainer = $BattleContainer/BattleLog/LogContent
@onready var speed_button: Button = $BattleContainer/ActionButtons/SpeedButton
@onready var skip_button: Button = $BattleContainer/ActionButtons/SkipButton

var current_battle_data: Dictionary = {}
var battle_speed: float = 1.0
var animation_duration: float = 3.0
var is_battle_active: bool = false

func _ready() -> void:
	name = "BattleUI"
	visible = false

	speed_button.pressed.connect(_on_speed_button_pressed)
	skip_button.pressed.connect(_on_skip_button_pressed)

	EventBus.connect_safe("battle_started", _on_battle_started)
	EventBus.connect_safe("battle_completed", _on_battle_completed)

	LogManager.info("BattleUI", "戰鬥界面初始化完成")

func show_battle(attacker: Dictionary, defender: Dictionary, city_name: String) -> void:
	if is_battle_active:
		LogManager.warn("BattleUI", "戰鬥已在進行中，忽略新戰鬥請求")
		return

	current_battle_data = {
		"attacker": attacker,
		"defender": defender,
		"city_name": city_name,
		"start_time": Time.get_unix_time_from_system()
	}

	_setup_battle_display()
	visible = true
	is_battle_active = true

	_start_battle_animation()

	LogManager.info("BattleUI", "開始戰鬥顯示", {
		"city": city_name,
		"attacker_troops": attacker.get("troops", 0),
		"defender_troops": defender.get("troops", 0)
	})

func _setup_battle_display() -> void:
	var attacker = current_battle_data.attacker
	var defender = current_battle_data.defender
	var city_name = current_battle_data.city_name

	battle_title.text = "⚔️ 戰鬥進行中"
	city_info.text = "攻打城池: %s" % city_name

	attacker_troops.text = "⚔️ %d" % attacker.get("troops", 0)
	attacker_general.text = attacker.get("general_name", "無名將領")

	defender_troops.text = "🛡️ %d" % defender.get("troops", 0)
	defender_general.text = defender.get("general_name", "守城將領")

	progress_bar.value = 0
	progress_label.text = "戰鬥準備中..."

	_clear_battle_log()

func _start_battle_animation() -> void:
	progress_label.text = "戰鬥激烈進行中..."

	# 分階段戰鬥動畫
	_start_battle_phases()

	# 開始戰鬥精靈動畫
	_animate_battle_sprites()

func _start_battle_phases() -> void:
	var phase_tween = create_tween()
	var total_duration = animation_duration / battle_speed

	# 第一階段：準備階段 (0-25%)
	phase_tween.tween_method(_update_battle_progress, 0.0, 25.0, total_duration * 0.2)
	phase_tween.tween_callback(_start_phase_2)

	# 第二階段：激戰階段 (25-75%)
	phase_tween.tween_method(_update_battle_progress, 25.0, 75.0, total_duration * 0.6)
	phase_tween.tween_callback(_start_phase_3)

	# 第三階段：決勝階段 (75-100%)
	phase_tween.tween_method(_update_battle_progress, 75.0, 100.0, total_duration * 0.2)
	phase_tween.tween_callback(_complete_battle_animation)

func _start_phase_2() -> void:
	# 進入激戰階段，增加特效頻率
	_add_battle_log_entry("⚔️ 戰鬥進入白熱化階段")
	_trigger_intensive_effects()

func _start_phase_3() -> void:
	# 進入決勝階段
	_add_battle_log_entry("🏆 勝負即將分曉")
	_trigger_climax_effects()

func _trigger_intensive_effects() -> void:
	# 激戰階段的特效
	var intense_tween = create_tween()
	intense_tween.set_loops(3)

	intense_tween.tween_callback(_trigger_clash_effect)
	intense_tween.tween_interval(0.8 / battle_speed)

func _trigger_climax_effects() -> void:
	# 決勝階段的特效
	var climax_tween = create_tween()

	# 連續特效爆發
	for i in range(5):
		climax_tween.tween_callback(_trigger_enhanced_clash_effect)
		climax_tween.tween_interval(0.3 / battle_speed)

func _trigger_enhanced_clash_effect() -> void:
	# 增強版戰鬥特效
	var effect_tween = create_tween()

	# 更強烈的閃光
	effect_tween.tween_method(_animate_enhanced_effects, 0.0, 1.5, 0.08)
	effect_tween.tween_method(_animate_enhanced_effects, 1.5, 0.0, 0.15)

	# 連續震動
	effect_tween.tween_callback(_trigger_enhanced_screen_shake)

func _animate_enhanced_effects(alpha: float) -> void:
	battle_effects.modulate.a = min(alpha, 1.0)
	battle_effects.scale = Vector2.ONE * (1.0 + alpha * 0.3)

	if alpha > 0.7:
		var enhanced_effects = ["💥💥", "⚡⚡", "🔥🔥", "💫💫", "⭐⭐", "🌟🌟"]
		battle_effects.text = enhanced_effects[randi() % enhanced_effects.size()]

func _trigger_enhanced_screen_shake() -> void:
	var shake_tween = create_tween()

	# 更強烈的震動
	for i in range(6):
		var shake_offset = Vector2(randf_range(-4, 4), randf_range(-4, 4))
		shake_tween.tween_method(_apply_screen_shake, Vector2.ZERO, shake_offset, 0.03)
		shake_tween.tween_method(_apply_screen_shake, shake_offset, Vector2.ZERO, 0.03)

func _update_battle_progress(value: float) -> void:
	progress_bar.value = value

	var stage = ""
	if value < 25:
		stage = "戰鬥準備階段"
	elif value < 50:
		stage = "激烈交戰中"
	elif value < 75:
		stage = "勝負關鍵時刻"
	else:
		stage = "戰鬥即將結束"

	progress_label.text = "%s (%.0f%%)" % [stage, value]

	if int(value) % 20 == 0:
		_add_battle_log_entry(_generate_battle_log_message(value))

func _animate_battle_sprites() -> void:
	_start_continuous_battle_animation()

func _start_continuous_battle_animation() -> void:
	var attack_sequence = create_tween()
	attack_sequence.set_loops()

	var base_duration = 1.5 / battle_speed

	# 攻擊方前進
	attack_sequence.tween_method(_animate_attacker_advance, 20.0, 160.0, base_duration * 0.3)
	attack_sequence.tween_callback(_trigger_clash_effect)

	# 短暫停頓（交戰）
	attack_sequence.tween_interval(base_duration * 0.2)

	# 攻擊方後退
	attack_sequence.tween_method(_animate_attacker_retreat, 160.0, 20.0, base_duration * 0.3)

	# 防守方反擊動畫
	attack_sequence.tween_method(_animate_defender_counterattack, -20.0, -50.0, base_duration * 0.1)
	attack_sequence.tween_method(_animate_defender_counterattack, -50.0, -20.0, base_duration * 0.1)

	# 循環間隔
	attack_sequence.tween_interval(base_duration * 0.2)

func _trigger_clash_effect() -> void:
	# 觸發戰鬥特效
	var effect_tween = create_tween()

	# 閃光效果
	effect_tween.tween_method(_animate_battle_effects, 0.0, 1.0, 0.1)
	effect_tween.tween_method(_animate_battle_effects, 1.0, 0.0, 0.2)

	# 螢幕震動效果（輕微）
	effect_tween.tween_callback(_trigger_screen_shake)

func _animate_attacker_advance(pos_x: float) -> void:
	attacker_sprite.position.x = pos_x

func _animate_attacker_retreat(pos_x: float) -> void:
	attacker_sprite.position.x = pos_x

func _animate_defender_counterattack(offset_x: float) -> void:
	defender_sprite.position.x = defender_sprite.position.x + offset_x

func _animate_battle_effects(alpha: float) -> void:
	battle_effects.modulate.a = alpha
	if alpha > 0.5:
		var effects = ["💥", "⚡", "🔥", "💫", "⭐", "🌟"]
		battle_effects.text = effects[randi() % effects.size()]

func _trigger_screen_shake() -> void:
	var shake_tween = create_tween()
	var original_pos = position

	# 輕微震動效果
	for i in range(4):
		var shake_offset = Vector2(randf_range(-2, 2), randf_range(-2, 2))
		shake_tween.tween_method(_apply_screen_shake, Vector2.ZERO, shake_offset, 0.05)
		shake_tween.tween_method(_apply_screen_shake, shake_offset, Vector2.ZERO, 0.05)

func _apply_screen_shake(offset: Vector2) -> void:
	position = offset

func _generate_battle_log_message(progress: float) -> String:
	var messages = []

	if progress < 25:
		messages = [
			"⚔️ 攻方發起衝鋒",
			"🛡️ 守方嚴陣以待",
			"🏹 弓箭手開始射擊"
		]
	elif progress < 50:
		messages = [
			"⚔️ 雙方激烈交戰",
			"💥 戰況十分激烈",
			"🩸 開始出現傷亡"
		]
	elif progress < 75:
		messages = [
			"🔥 戰況白熱化",
			"⚡ 將領親自上陣",
			"🌪️ 戰局開始明朗"
		]
	else:
		messages = [
			"🏆 勝負即將分曉",
			"⭐ 最後的決戰時刻",
			"🎯 戰鬥即將結束"
		]

	return messages[randi() % messages.size()]

func _add_battle_log_entry(message: String) -> void:
	var log_label = Label.new()
	log_label.text = message
	log_label.theme_override_font_sizes.font_size = 16
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	log_content.add_child(log_label)

	if log_content.get_child_count() > 8:
		var oldest_entry = log_content.get_child(0)
		log_content.remove_child(oldest_entry)
		oldest_entry.queue_free()

func _clear_battle_log() -> void:
	for child in log_content.get_children():
		child.queue_free()

func _complete_battle_animation() -> void:
	progress_bar.value = 100
	progress_label.text = "戰鬥結束，等待結果..."

	_add_battle_log_entry("🏁 戰鬥結束，正在統計戰果...")

func _on_battle_started(attacker: Dictionary, defender: Dictionary, city_name: String) -> void:
	show_battle(attacker, defender, city_name)

func _on_battle_completed(result: Dictionary, victor: String, casualties: Dictionary) -> void:
	if not is_battle_active:
		return

	_show_battle_result(result, victor, casualties)

	await get_tree().create_timer(3.0).timeout

	hide_battle()

func _show_battle_result(result: Dictionary, victor: String, casualties: Dictionary) -> void:
	progress_bar.value = 100

	if victor == "player":
		battle_title.text = "🏆 勝利！"
		progress_label.text = "戰鬥勝利！城池已佔領"
		_add_battle_log_entry("🎉 攻城成功！城池被佔領")
	else:
		battle_title.text = "💔 敗北"
		progress_label.text = "戰鬥失敗，攻城失敗"
		_add_battle_log_entry("😞 攻城失敗，部隊撤退")

	var casualties_text = "傷亡統計："
	for side in casualties:
		casualties_text += " %s: %d" % [side, casualties[side]]
	_add_battle_log_entry(casualties_text)

	if result.has("spoils"):
		var spoils = result.spoils
		if spoils.get("gold", 0) > 0:
			_add_battle_log_entry("💰 獲得金錢: %d" % spoils.gold)
		if spoils.get("equipment", []).size() > 0:
			_add_battle_log_entry("⚔️ 獲得裝備: %d件" % spoils.equipment.size())

	if result.has("recruitment_result"):
		var recruitment = result.recruitment_result
		if recruitment.get("success", false):
			_add_battle_log_entry("🎯 成功招募武將: %s" % recruitment.get("general_name", ""))
		else:
			_add_battle_log_entry("❌ 武將招募失敗")

func hide_battle() -> void:
	visible = false
	is_battle_active = false
	current_battle_data.clear()

	# 清理所有動畫
	_cleanup_animations()

	# 重置UI狀態
	_reset_ui_state()

	LogManager.info("BattleUI", "戰鬥界面已隱藏")

func _cleanup_animations() -> void:
	# 停止所有Tween動畫
	var tweens = get_tree().get_nodes_in_group("tweens")
	for tween in tweens:
		if tween.is_valid():
			tween.kill()

	# 手動清理自創建的tween
	for child in get_children():
		if child.has_method("kill"):
			child.kill()

func _reset_ui_state() -> void:
	# 重置精靈位置
	if attacker_sprite:
		attacker_sprite.position.x = 20.0
		attacker_sprite.scale = Vector2.ONE

	if defender_sprite:
		defender_sprite.position.x = -20.0
		defender_sprite.scale = Vector2.ONE

	# 重置特效
	if battle_effects:
		battle_effects.modulate.a = 0.0
		battle_effects.scale = Vector2.ONE
		battle_effects.text = "💥"

	# 重置容器位置
	position = Vector2.ZERO

	# 重置進度條
	if progress_bar:
		progress_bar.value = 0.0

	if progress_label:
		progress_label.text = "戰鬥準備中..."

func _on_speed_button_pressed() -> void:
	if battle_speed == 1.0:
		battle_speed = 2.0
		speed_button.text = "⏩ 4x速度"
	elif battle_speed == 2.0:
		battle_speed = 4.0
		speed_button.text = "⏩ 1x速度"
	else:
		battle_speed = 1.0
		speed_button.text = "⏩ 2x速度"

	LogManager.info("BattleUI", "戰鬥速度調整", {"new_speed": battle_speed})

func _on_skip_button_pressed() -> void:
	if not is_battle_active:
		return

	get_tree().call_group("tweens", "kill")

	progress_bar.value = 100
	progress_label.text = "動畫已跳過，等待戰鬥結果..."
	_add_battle_log_entry("⏭️ 動畫已跳過")

	LogManager.info("BattleUI", "戰鬥動畫已跳過")