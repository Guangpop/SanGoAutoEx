# ConnectionLineDrawer.gd - 城池連線繪製器
#
# 功能：
# - 繪製城池間的戰略連線
# - 支援動態位置更新
# - 提供視覺化的城池關係

class_name ConnectionLineDrawer
extends Node2D

var start_pos: Vector2
var end_pos: Vector2
var line_width: float

func setup(start: Vector2, end: Vector2, width: float) -> void:
	start_pos = start
	end_pos = end
	line_width = width

func update_positions(new_start: Vector2, new_end: Vector2) -> void:
	start_pos = new_start
	end_pos = new_end
	queue_redraw()

func _draw() -> void:
	# 繪製連線
	draw_line(start_pos, end_pos, Color.WHITE, line_width)
	draw_line(start_pos, end_pos, Color.GRAY, line_width - 0.5)