# AudioManager.gd - 音效管理系統
#
# 功能：
# - 背景音樂播放和切換
# - 音效播放管理
# - 音量控制
# - 音頻設置保存

extends Node

func _ready() -> void:
	name = "AudioManager"
	LogManager.info("AudioManager", "音效管理器初始化完成")

	# 連接音效事件
	EventBus.connect_safe("audio_play_requested", _on_audio_play_requested)
	EventBus.connect_safe("music_change_requested", _on_music_change_requested)

func _on_audio_play_requested(sound_name: String, volume: float, pitch: float) -> void:
	# TODO: 實現音效播放
	LogManager.debug("AudioManager", "播放音效", {"sound": sound_name})

func _on_music_change_requested(music_name: String, fade_time: float) -> void:
	# TODO: 實現背景音樂切換
	LogManager.debug("AudioManager", "切換背景音樂", {"music": music_name})