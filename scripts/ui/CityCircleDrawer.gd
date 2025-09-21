# CityCircleDrawer.gd - 城池圓圈繪製器
#
# 功能：
# - 繪製城池節點的視覺表現
# - 支援不同狀態的動畫效果
# - 處理城池選中狀態和視覺反饋

class_name CityCircleDrawer
extends Node2D

var city_data: Dictionary
var node_size: float
var base_color: Color
var tier_color: Color
var status_color: Color = Color.WHITE
var is_selected: bool = false

# 動畫狀態
var pulse_intensity: float = 0.0
var glow_alpha: float = 0.0
var rotation_angle: float = 0.0
var animation_type: String = "none"
var animation_tween: Tween

func setup(data: Dictionary, size: float, color: Color, tier: Color) -> void:
	city_data = data
	node_size = size
	base_color = color
	tier_color = tier
	_start_idle_animation()

func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()

func update_colors(new_base: Color, new_tier: Color) -> void:
	base_color = new_base
	tier_color = new_tier
	queue_redraw()

func set_city_status(status: String) -> void:
	match status:
		"prosperous":
			_start_prosperity_animation()
		"besieged":
			_start_siege_animation()
		"reinforcing":
			_start_reinforcement_animation()
		"declining":
			_start_decline_animation()
		_:
			_start_idle_animation()

func _start_prosperity_animation() -> void:
	animation_type = "prosperity"
	status_color = Color.GREEN

	if animation_tween:
		animation_tween.kill()

	animation_tween = create_tween()
	animation_tween.set_loops()

	# 綠色光暈脈衝
	animation_tween.tween_method(_set_glow_alpha, 0.0, 0.7, 1.5)
	animation_tween.tween_method(_set_glow_alpha, 0.7, 0.0, 1.5)

func _start_siege_animation() -> void:
	animation_type = "siege"
	status_color = Color.RED

	if animation_tween:
		animation_tween.kill()

	animation_tween = create_tween()
	animation_tween.set_loops()

	# 紅色快速閃爍
	animation_tween.tween_method(_set_pulse_intensity, 0.0, 1.0, 0.3)
	animation_tween.tween_method(_set_pulse_intensity, 1.0, 0.0, 0.3)

func _start_reinforcement_animation() -> void:
	animation_type = "reinforcement"
	status_color = Color.BLUE

	if animation_tween:
		animation_tween.kill()

	animation_tween = create_tween()
	animation_tween.set_loops()

	# 藍色波紋效果
	animation_tween.tween_method(_set_pulse_intensity, 0.0, 1.2, 1.0)
	animation_tween.tween_method(_set_pulse_intensity, 1.2, 0.0, 1.0)

func _start_decline_animation() -> void:
	animation_type = "decline"
	status_color = Color.ORANGE

	if animation_tween:
		animation_tween.kill()

	animation_tween = create_tween()
	animation_tween.set_loops()

	# 橙色衰落脈衝
	animation_tween.tween_method(_set_glow_alpha, 0.0, 0.4, 2.0)
	animation_tween.tween_method(_set_glow_alpha, 0.4, 0.0, 2.0)

func _start_idle_animation() -> void:
	animation_type = "idle"
	status_color = Color.WHITE

	if animation_tween:
		animation_tween.kill()

	animation_tween = create_tween()
	animation_tween.set_loops()

	# 輕微呼吸效果
	animation_tween.tween_method(_set_pulse_intensity, 0.0, 0.1, 3.0)
	animation_tween.tween_method(_set_pulse_intensity, 0.1, 0.0, 3.0)

func _set_pulse_intensity(intensity: float) -> void:
	pulse_intensity = intensity
	queue_redraw()

func _set_glow_alpha(alpha: float) -> void:
	glow_alpha = alpha
	queue_redraw()

func _set_rotation_angle(angle: float) -> void:
	rotation_angle = angle
	queue_redraw()

func _draw() -> void:
	var radius = node_size / 2

	# 狀態光暈效果
	if glow_alpha > 0:
		var glow_radius = radius + 8 + pulse_intensity * 4
		var glow_color = status_color
		glow_color.a = glow_alpha * 0.6
		draw_circle(Vector2.ZERO, glow_radius, glow_color)

	# 脈衝外圈
	if pulse_intensity > 0:
		var pulse_radius = radius + 4 + pulse_intensity * 6
		var pulse_color = status_color
		pulse_color.a = (1.0 - pulse_intensity) * 0.8
		draw_circle(Vector2.ZERO, pulse_radius, pulse_color, false, 2.0)

	# 選中狀態的外圈
	if is_selected:
		var selection_radius = radius + 4 + sin(Time.get_ticks_msec() * 0.008) * 2
		draw_circle(Vector2.ZERO, selection_radius, Color.YELLOW, false, 3.0)

	# 城池等級外圈
	draw_circle(Vector2.ZERO, radius + 2, tier_color, false, 2.0)

	# 主要城池圓圈（帶脈衝縮放）
	var main_radius = radius * (1.0 + pulse_intensity * 0.1)
	draw_circle(Vector2.ZERO, main_radius, base_color)

	# 內部邊框
	draw_circle(Vector2.ZERO, main_radius, Color.WHITE, false, 1.0)

	# 狀態指示器（小圓點）
	if animation_type != "idle" and animation_type != "none":
		var indicator_pos = Vector2(radius * 0.7, -radius * 0.7)
		var indicator_color = status_color
		indicator_color.a = 0.8 + pulse_intensity * 0.2
		draw_circle(indicator_pos, 3, indicator_color)

func cleanup() -> void:
	if animation_tween:
		animation_tween.kill()
		animation_tween = null