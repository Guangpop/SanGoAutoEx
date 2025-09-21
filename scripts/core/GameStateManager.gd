# GameStateManager.gd - 統一的遊戲狀態管理
#
# 功能：
# - 遊戲狀態機管理 (MENU → SKILL_SELECTION → GAME_RUNNING → BATTLE → PAUSED → GAME_OVER)
# - 狀態轉換驗證和歷史記錄
# - 狀態持久化和恢復
# - 狀態變更事件分發

extends Node

# 遊戲狀態枚舉
enum GameState {
	MENU,            # 主選單
	SKILL_SELECTION, # 技能選擇階段
	GAME_RUNNING,    # 主遊戲循環
	BATTLE,          # 戰鬥階段
	PAUSED,          # 遊戲暫停
	GAME_OVER        # 遊戲結束
}

# 狀態轉換規則 - 定義哪些狀態可以轉換到哪些狀態
const STATE_TRANSITIONS = {
	GameState.MENU: [GameState.SKILL_SELECTION, GameState.GAME_RUNNING], # 可以開新遊戲或讀取存檔
	GameState.SKILL_SELECTION: [GameState.GAME_RUNNING, GameState.MENU], # 技能選完進入遊戲或回主選單
	GameState.GAME_RUNNING: [GameState.BATTLE, GameState.PAUSED, GameState.GAME_OVER, GameState.MENU], # 主遊戲循環
	GameState.BATTLE: [GameState.GAME_RUNNING, GameState.GAME_OVER], # 戰鬥結束回到主循環或遊戲結束
	GameState.PAUSED: [GameState.GAME_RUNNING, GameState.MENU], # 從暫停恢復或回主選單
	GameState.GAME_OVER: [GameState.MENU, GameState.SKILL_SELECTION] # 遊戲結束可重新開始
}

# 狀態名稱映射（用於日誌和除錯）
const STATE_NAMES = {
	GameState.MENU: "主選單",
	GameState.SKILL_SELECTION: "技能選擇",
	GameState.GAME_RUNNING: "遊戲進行中",
	GameState.BATTLE: "戰鬥中",
	GameState.PAUSED: "暫停",
	GameState.GAME_OVER: "遊戲結束"
}

# 私有變量
var _current_state: GameState = GameState.MENU
var _previous_state: GameState = GameState.MENU
var _state_history: Array[Dictionary] = []
var _max_history_size: int = 50
var _state_data: Dictionary = {} # 存儲狀態相關的數據

# 狀態持續時間追蹤
var _state_start_time: float = 0.0
var _total_play_time: float = 0.0

func _ready() -> void:
	name = "GameStateManager"
	_state_start_time = Time.get_unix_time_from_system()

	LogManager.info("GameStateManager", "遊戲狀態管理器初始化完成", {
		"initial_state": STATE_NAMES[_current_state]
	})

	# 記錄初始狀態
	_record_state_change(_current_state, _current_state, "系統初始化")

func _exit_tree() -> void:
	# 記錄最終的遊戲統計
	var final_stats = get_session_stats()
	LogManager.info("GameStateManager", "遊戲會話結束", final_stats)

# 狀態轉換主方法
func change_state(new_state: GameState, reason: String = "", force: bool = false) -> bool:
	# 如果狀態相同，則忽略
	if new_state == _current_state:
		LogManager.debug("GameStateManager", "嘗試轉換到相同狀態", {
			"state": STATE_NAMES[new_state],
			"reason": reason
		})
		return true

	# 驗證狀態轉換是否合法
	if not force and not _is_valid_transition(_current_state, new_state):
		LogManager.warn("GameStateManager", "非法狀態轉換", {
			"from": STATE_NAMES[_current_state],
			"to": STATE_NAMES[new_state],
			"reason": reason
		})
		return false

	# 執行狀態轉換
	var old_state = _current_state
	_previous_state = _current_state
	_current_state = new_state

	# 記錄狀態變更
	_record_state_change(old_state, new_state, reason)

	# 計算在前一狀態的持續時間
	var state_duration = Time.get_unix_time_from_system() - _state_start_time
	_state_start_time = Time.get_unix_time_from_system()

	# 如果不是暫停狀態，則計入總遊戲時間
	if old_state != GameState.PAUSED and old_state != GameState.MENU:
		_total_play_time += state_duration

	# 執行狀態退出處理
	_on_state_exit(old_state, new_state)

	# 執行狀態進入處理
	_on_state_enter(new_state, old_state)

	# 發送狀態變更事件
	EventBus.game_state_changed.emit(new_state, old_state)

	LogManager.info("GameStateManager", "狀態轉換成功", {
		"from": STATE_NAMES[old_state],
		"to": STATE_NAMES[new_state],
		"reason": reason,
		"duration": state_duration,
		"total_playtime": _total_play_time
	})

	return true

# 驗證狀態轉換是否合法
func _is_valid_transition(from_state: GameState, to_state: GameState) -> bool:
	return to_state in STATE_TRANSITIONS.get(from_state, [])

# 記錄狀態變更到歷史記錄
func _record_state_change(old_state: GameState, new_state: GameState, reason: String) -> void:
	var record = {
		"timestamp": Time.get_unix_time_from_system(),
		"from_state": old_state,
		"to_state": new_state,
		"reason": reason,
		"frame": Engine.get_process_frames()
	}

	_state_history.append(record)

	# 限制歷史記錄大小
	if _state_history.size() > _max_history_size:
		_state_history.pop_front()

# 狀態退出處理
func _on_state_exit(old_state: GameState, new_state: GameState) -> void:
	match old_state:
		GameState.MENU:
			_on_exit_menu(new_state)
		GameState.SKILL_SELECTION:
			_on_exit_skill_selection(new_state)
		GameState.GAME_RUNNING:
			_on_exit_game_running(new_state)
		GameState.BATTLE:
			_on_exit_battle(new_state)
		GameState.PAUSED:
			_on_exit_paused(new_state)
		GameState.GAME_OVER:
			_on_exit_game_over(new_state)

# 狀態進入處理
func _on_state_enter(new_state: GameState, old_state: GameState) -> void:
	match new_state:
		GameState.MENU:
			_on_enter_menu(old_state)
		GameState.SKILL_SELECTION:
			_on_enter_skill_selection(old_state)
		GameState.GAME_RUNNING:
			_on_enter_game_running(old_state)
		GameState.BATTLE:
			_on_enter_battle(old_state)
		GameState.PAUSED:
			_on_enter_paused(old_state)
		GameState.GAME_OVER:
			_on_enter_game_over(old_state)

# === 狀態進入處理方法 ===

func _on_enter_menu(from_state: GameState) -> void:
	LogManager.debug("GameStateManager", "進入主選單", {"from": STATE_NAMES[from_state]})
	# TODO: 顯示主選單UI，停止背景音樂等

func _on_enter_skill_selection(from_state: GameState) -> void:
	LogManager.debug("GameStateManager", "進入技能選擇", {"from": STATE_NAMES[from_state]})
	# TODO: 初始化技能選擇系統，顯示技能選擇UI

func _on_enter_game_running(from_state: GameState) -> void:
	LogManager.debug("GameStateManager", "進入遊戲主循環", {"from": STATE_NAMES[from_state]})
	# TODO: 啟動遊戲主循環，顯示遊戲UI，開始資源生產

func _on_enter_battle(from_state: GameState) -> void:
	LogManager.debug("GameStateManager", "進入戰鬥", {"from": STATE_NAMES[from_state]})
	# TODO: 初始化戰鬥系統，顯示戰鬥UI

func _on_enter_paused(from_state: GameState) -> void:
	LogManager.debug("GameStateManager", "遊戲暫停", {"from": STATE_NAMES[from_state]})
	# TODO: 暫停遊戲邏輯，顯示暫停選單

func _on_enter_game_over(from_state: GameState) -> void:
	LogManager.debug("GameStateManager", "遊戲結束", {"from": STATE_NAMES[from_state]})
	# TODO: 顯示遊戲結束畫面，統計數據，重開選項

# === 狀態退出處理方法 ===

func _on_exit_menu(to_state: GameState) -> void:
	LogManager.debug("GameStateManager", "離開主選單", {"to": STATE_NAMES[to_state]})

func _on_exit_skill_selection(to_state: GameState) -> void:
	LogManager.debug("GameStateManager", "離開技能選擇", {"to": STATE_NAMES[to_state]})

func _on_exit_game_running(to_state: GameState) -> void:
	LogManager.debug("GameStateManager", "離開遊戲主循環", {"to": STATE_NAMES[to_state]})

func _on_exit_battle(to_state: GameState) -> void:
	LogManager.debug("GameStateManager", "離開戰鬥", {"to": STATE_NAMES[to_state]})

func _on_exit_paused(to_state: GameState) -> void:
	LogManager.debug("GameStateManager", "離開暫停", {"to": STATE_NAMES[to_state]})

func _on_exit_game_over(to_state: GameState) -> void:
	LogManager.debug("GameStateManager", "離開遊戲結束", {"to": STATE_NAMES[to_state]})

# === 公共API方法 ===

# 獲取當前狀態
func get_current_state() -> GameState:
	return _current_state

# 獲取前一狀態
func get_previous_state() -> GameState:
	return _previous_state

# 獲取當前狀態名稱
func get_current_state_name() -> String:
	return STATE_NAMES[_current_state]

# 檢查是否處於指定狀態
func is_in_state(state: GameState) -> bool:
	return _current_state == state

# 檢查是否可以轉換到指定狀態
func can_transition_to(state: GameState) -> bool:
	return _is_valid_transition(_current_state, state)

# 獲取可用的轉換狀態
func get_available_transitions() -> Array[GameState]:
	return STATE_TRANSITIONS.get(_current_state, [])

# 設置狀態數據
func set_state_data(key: String, value) -> void:
	_state_data[key] = value
	LogManager.debug("GameStateManager", "狀態數據已設置", {"key": key, "value": value})

# 獲取狀態數據
func get_state_data(key: String, default_value = null):
	return _state_data.get(key, default_value)

# 清除狀態數據
func clear_state_data() -> void:
	_state_data.clear()
	LogManager.debug("GameStateManager", "狀態數據已清除")

# 獲取狀態歷史記錄
func get_state_history() -> Array[Dictionary]:
	return _state_history.duplicate()

# 清除狀態歷史記錄
func clear_state_history() -> void:
	_state_history.clear()
	LogManager.info("GameStateManager", "狀態歷史記錄已清除")

# 獲取當前狀態持續時間
func get_current_state_duration() -> float:
	return Time.get_unix_time_from_system() - _state_start_time

# 獲取總遊戲時間
func get_total_play_time() -> float:
	var current_duration = get_current_state_duration()
	if _current_state != GameState.PAUSED and _current_state != GameState.MENU:
		return _total_play_time + current_duration
	return _total_play_time

# 獲取會話統計信息
func get_session_stats() -> Dictionary:
	return {
		"current_state": STATE_NAMES[_current_state],
		"session_duration": Time.get_unix_time_from_system() - _state_start_time,
		"total_play_time": get_total_play_time(),
		"state_changes": _state_history.size(),
		"current_state_duration": get_current_state_duration()
	}

# 重置狀態管理器
func reset() -> void:
	var old_state = _current_state
	_current_state = GameState.MENU
	_previous_state = GameState.MENU
	_state_history.clear()
	_state_data.clear()
	_state_start_time = Time.get_unix_time_from_system()
	_total_play_time = 0.0

	LogManager.info("GameStateManager", "狀態管理器已重置", {
		"previous_state": STATE_NAMES[old_state]
	})

	EventBus.game_state_changed.emit(_current_state, old_state)

# 序列化狀態信息（用於存檔）
func serialize() -> Dictionary:
	return {
		"current_state": _current_state,
		"previous_state": _previous_state,
		"state_data": _state_data,
		"total_play_time": _total_play_time,
		"session_start": _state_start_time
	}

# 反序列化狀態信息（用於讀檔）
func deserialize(data: Dictionary) -> bool:
	if not data.has("current_state"):
		LogManager.error("GameStateManager", "無效的狀態數據", {"data": data})
		return false

	_current_state = data.get("current_state", GameState.MENU)
	_previous_state = data.get("previous_state", GameState.MENU)
	_state_data = data.get("state_data", {})
	_total_play_time = data.get("total_play_time", 0.0)
	_state_start_time = Time.get_unix_time_from_system()

	LogManager.info("GameStateManager", "狀態已恢復", {
		"state": STATE_NAMES[_current_state],
		"total_playtime": _total_play_time
	})

	EventBus.game_state_changed.emit(_current_state, _previous_state)
	return true