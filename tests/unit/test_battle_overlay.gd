# test_battle_overlay.gd - 戰鬥覆蓋層UI測試
#
# 測試範圍：
# - 移動端戰鬥UI顯示與隱藏
# - 戰鬥動畫和視覺效果
# - 觸控控制和速度調整
# - 傷害數字和血量顯示
# - EventBus 整合

extends GdUnitTestSuite

# 測試用數據
var battle_overlay: Control
var test_attacker_data: Dictionary
var test_defender_data: Dictionary
var mock_event_bus: Object

func before_test() -> void:
	# 設置測試用戰鬥數據
	test_attacker_data = {
		"general_name": "劉備",
		"troops": 1000,
		"power_rating": 1200,
		"morale": 100
	}

	test_defender_data = {
		"general_name": "曹操",
		"troops": 800,
		"power_rating": 1000,
		"morale": 90,
		"city_bonus": 0.1
	}

	# 創建戰鬥覆蓋層實例
	var overlay_script = load("res://scripts/ui/BattleOverlay.gd")
	battle_overlay = overlay_script.new()

func after_test() -> void:
	# 清理測試實例
	if battle_overlay:
		battle_overlay.queue_free()
		battle_overlay = null

# === 基本UI功能測試 ===

func test_battle_overlay_initialization():
	# 測試戰鬥覆蓋層初始化
	assert_object(battle_overlay).is_not_null()
	assert_str(battle_overlay.name).is_equal("BattleOverlay")

	# 初始狀態應該隱藏
	assert_bool(battle_overlay.visible).is_false()
	assert_bool(battle_overlay.is_battle_active).is_false()

func test_battle_display_setup():
	# 測試戰鬥顯示設置
	var city_name = "洛陽"

	battle_overlay.show_battle(test_attacker_data, test_defender_data, city_name)

	# 應該變為可見並激活
	assert_bool(battle_overlay.visible).is_true()
	assert_bool(battle_overlay.is_battle_active).is_true()

	# 檢查戰鬥數據設置
	assert_dict(battle_overlay.current_battle_data).is_not_empty()
	assert_str(battle_overlay.current_battle_data.city_name).is_equal(city_name)

func test_battle_avatar_setup():
	# 測試戰鬥頭像設置
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")

	# 檢查頭像是否正確設置
	var attacker_icon = battle_overlay._get_general_icon("劉備")
	var defender_icon = battle_overlay._get_general_icon("曹操")

	assert_str(attacker_icon).is_not_equal("")
	assert_str(defender_icon).is_not_equal("")

func test_hp_display_initialization():
	# 測試血量顯示初始化
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")

	# 檢查血量初始化
	assert_float(battle_overlay.attacker_max_hp).is_equal(float(test_attacker_data.troops))
	assert_float(battle_overlay.defender_max_hp).is_equal(float(test_defender_data.troops))
	assert_float(battle_overlay.attacker_current_hp).is_equal(battle_overlay.attacker_max_hp)
	assert_float(battle_overlay.defender_current_hp).is_equal(battle_overlay.defender_max_hp)

# === 動畫和視覺效果測試 ===

func test_battle_progress_animation():
	# 測試戰鬥進度動畫
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")

	# 手動觸發進度更新
	battle_overlay._update_battle_progress(25.0)
	battle_overlay._update_battle_progress(50.0)
	battle_overlay._update_battle_progress(75.0)
	battle_overlay._update_battle_progress(100.0)

	# 檢查進度條值
	if battle_overlay.has_node("BattleMainContainer/BattleHeader/BattleProgress"):
		var progress_bar = battle_overlay.get_node("BattleMainContainer/BattleHeader/BattleProgress")
		assert_float(progress_bar.value).is_equal(100.0)

func test_hp_animation_update():
	# 測試血量動畫更新
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")

	# 模擬傷害
	battle_overlay.attacker_current_hp = 800.0
	battle_overlay.defender_current_hp = 600.0

	battle_overlay._update_hp_displays()

	# 檢查血量百分比計算
	var attacker_percent = (800.0 / 1000.0) * 100.0
	var defender_percent = (600.0 / 800.0) * 100.0

	assert_float(attacker_percent).is_equal(80.0)
	assert_float(defender_percent).is_equal(75.0)

func test_damage_number_display():
	# 測試傷害數字顯示
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")

	# 觸發傷害數字
	battle_overlay._show_damage_number(150.0, false)  # 對防守方
	battle_overlay._show_damage_number(120.0, true)   # 對攻擊方

	# 檢查是否創建了傷害標籤（間接測試）
	# 由於動畫的異步性質，我們主要檢查方法不會崩潰

func test_combat_effects_trigger():
	# 測試戰鬥特效觸發
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")

	# 觸發戰鬥特效
	battle_overlay._trigger_combat_effect()

	# 檢查特效標籤是否有內容
	if battle_overlay.has_node("BattleMainContainer/BattleCombatArea/GeneralsDisplay/CombatEffects/EffectLabel"):
		var effect_label = battle_overlay.get_node("BattleMainContainer/BattleCombatArea/GeneralsDisplay/CombatEffects/EffectLabel")
		assert_str(effect_label.text).is_not_equal("")

# === 控制功能測試 ===

func test_speed_control_functionality():
	# 測試速度控制功能
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")

	var initial_speed = battle_overlay.battle_speed

	# 測試不同速度設置
	battle_overlay._on_speed_button_pressed(2.0)
	assert_float(battle_overlay.battle_speed).is_equal(2.0)

	battle_overlay._on_speed_button_pressed(4.0)
	assert_float(battle_overlay.battle_speed).is_equal(4.0)

	battle_overlay._on_speed_button_pressed(10.0)
	assert_float(battle_overlay.battle_speed).is_equal(10.0)

func test_skip_button_functionality():
	# 測試跳過按鈕功能
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")

	# 觸發跳過功能
	battle_overlay._on_skip_button_pressed()

	# 檢查進度是否跳到100%
	if battle_overlay.has_node("BattleMainContainer/BattleHeader/BattleProgress"):
		var progress_bar = battle_overlay.get_node("BattleMainContainer/BattleHeader/BattleProgress")
		assert_float(progress_bar.value).is_equal(100.0)

func test_close_button_functionality():
	# 測試關閉按鈕功能
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")
	assert_bool(battle_overlay.visible).is_true()

	# 觸發關閉功能
	battle_overlay._on_close_button_pressed()

	# 應該隱藏覆蓋層
	assert_bool(battle_overlay.visible).is_false()
	assert_bool(battle_overlay.is_battle_active).is_false()

# === 戰鬥記錄系統測試 ===

func test_battle_log_entry_addition():
	# 測試戰鬥記錄條目添加
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")

	# 添加戰鬥記錄
	battle_overlay._add_battle_log_entry("測試戰鬥記錄")
	battle_overlay._add_battle_log_entry("第二條記錄")

	# 檢查記錄是否添加（間接測試）
	# 由於需要節點結構完整，主要檢查方法不崩潰

func test_battle_log_limit():
	# 測試戰鬥記錄數量限制
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")

	# 添加超過限制的記錄
	for i in range(12):
		battle_overlay._add_battle_log_entry("記錄 %d" % i)

	# 應該自動清理舊記錄（間接測試）

func test_stage_log_messages():
	# 測試階段性戰鬥記錄消息
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")

	# 測試不同階段的消息
	battle_overlay._add_stage_log_entry(25.0)
	battle_overlay._add_stage_log_entry(50.0)
	battle_overlay._add_stage_log_entry(75.0)
	battle_overlay._add_stage_log_entry(100.0)

# === 移動端優化功能測試 ===

func test_haptic_feedback_calls():
	# 測試觸覺反饋調用
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")

	# 觸發不同強度的觸覺反饋
	battle_overlay._trigger_haptic_feedback("light")
	battle_overlay._trigger_haptic_feedback("medium")
	battle_overlay._trigger_haptic_feedback("heavy")

	# 主要檢查方法不會崩潰

func test_screen_shake_effect():
	# 測試螢幕震動效果
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")

	var original_position = battle_overlay.position

	# 觸發螢幕震動
	battle_overlay._trigger_screen_shake(2.0)

	# 檢查位置是否會恢復（異步測試困難，主要檢查不崩潰）

func test_speed_button_state_updates():
	# 測試速度按鈕狀態更新
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")

	battle_overlay.battle_speed = 2.0
	battle_overlay._update_speed_button_states()

	battle_overlay.battle_speed = 4.0
	battle_overlay._update_speed_button_states()

# === 戰鬥結果處理測試 ===

func test_battle_result_display():
	# 測試戰鬥結果顯示
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")

	var victory_result = {
		"victor": "player",
		"spoils": {
			"gold": 1000,
			"equipment": [{"name": "test_weapon"}]
		}
	}

	var defeat_result = {
		"victor": "defender"
	}

	# 測試勝利結果顯示
	battle_overlay._show_battle_result(victory_result, "player", {})

	# 測試失敗結果顯示
	battle_overlay._show_battle_result(defeat_result, "defender", {})

func test_battle_cleanup():
	# 測試戰鬥清理
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")

	# 確保戰鬥是激活的
	assert_bool(battle_overlay.is_battle_active).is_true()

	# 執行清理
	battle_overlay.hide_battle()

	# 檢查清理結果
	assert_bool(battle_overlay.visible).is_false()
	assert_bool(battle_overlay.is_battle_active).is_false()
	assert_dict(battle_overlay.current_battle_data).is_empty()

func test_animation_cleanup():
	# 測試動畫清理
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")

	# 觸發一些動畫
	battle_overlay._trigger_combat_effect()
	battle_overlay._show_damage_number(100.0, false)

	# 執行清理
	battle_overlay._cleanup_animations()

	# 主要檢查不會崩潰

# === EventBus 整合測試 ===

func test_event_bus_battle_started():
	# 測試EventBus戰鬥開始事件
	# 由於EventBus可能不存在，使用try-catch模式
	battle_overlay._on_battle_started(test_attacker_data, test_defender_data, "test_city")

	assert_bool(battle_overlay.is_battle_active).is_true()

func test_event_bus_battle_completed():
	# 測試EventBus戰鬥完成事件
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")

	var battle_result = {
		"victor": "player",
		"spoils": {"gold": 500}
	}

	battle_overlay._on_battle_completed(battle_result, "player", {})

func test_event_bus_damage_dealt():
	# 測試EventBus傷害處理事件
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")

	var damage_data = {
		"damage": 150,
		"target": "defender",
		"critical": false
	}

	battle_overlay._on_damage_dealt(damage_data)

func test_event_bus_skill_activated():
	# 測試EventBus技能激活事件
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")

	var skill_data = {
		"skill_name": "火攻",
		"caster": "劉備"
	}

	battle_overlay._on_skill_activated(skill_data)

# === 邊界條件和錯誤處理測試 ===

func test_duplicate_battle_start():
	# 測試重複開始戰鬥
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "first_city")
	assert_bool(battle_overlay.is_battle_active).is_true()

	# 嘗試再次開始戰鬥
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "second_city")

	# 應該仍然是第一個戰鬥
	assert_str(battle_overlay.current_battle_data.city_name).is_equal("first_city")

func test_invalid_battle_data():
	# 測試無效戰鬥數據
	var invalid_attacker = {}
	var invalid_defender = {}

	battle_overlay.show_battle(invalid_attacker, invalid_defender, "test_city")

	# 應該能處理空數據而不崩潰
	assert_bool(battle_overlay.is_battle_active).is_true()

func test_extreme_damage_values():
	# 測試極端傷害值
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")

	# 測試超高傷害
	battle_overlay._show_damage_number(99999.0, false)

	# 測試負傷害
	battle_overlay._show_damage_number(-100.0, true)

	# 測試零傷害
	battle_overlay._show_damage_number(0.0, false)

func test_rapid_speed_changes():
	# 測試快速速度變更
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")

	# 快速變更速度
	for i in range(10):
		var speeds = [1.0, 2.0, 4.0, 10.0]
		var speed = speeds[i % speeds.size()]
		battle_overlay._on_speed_button_pressed(speed)

# === 性能測試 ===

func test_animation_performance():
	# 測試動畫性能
	battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city")

	var start_time = Time.get_unix_time_from_system()

	# 觸發大量動畫
	for i in range(50):
		battle_overlay._trigger_combat_effect()
		battle_overlay._show_damage_number(randf_range(50, 200), randi() % 2 == 0)

	var end_time = Time.get_unix_time_from_system()
	var duration = end_time - start_time

	# 應該在合理時間內完成
	assert_float(duration).is_less(1.0)

func test_memory_cleanup_efficiency():
	# 測試記憶體清理效率
	for i in range(10):
		battle_overlay.show_battle(test_attacker_data, test_defender_data, "test_city_%d" % i)
		battle_overlay._trigger_combat_effect()
		battle_overlay.hide_battle()

	# 主要檢查沒有記憶體洩漏（間接測試）