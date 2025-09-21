# test_runner.gd - 簡單測試運行器
#
# 用於快速驗證技能選擇系統是否正常工作

extends Node

func _ready() -> void:
	LogManager.info("TestRunner", "測試運行器啟動")

	# 等待系統初始化完成
	if not GameCore.is_systems_initialized():
		await EventBus.game_initialized

	# 運行基本測試
	run_basic_tests()

func run_basic_tests() -> void:
	LogManager.info("TestRunner", "開始運行基本測試")

	# 測試1: 檢查核心系統
	test_core_systems()

	# 測試2: 檢查數據載入
	test_data_loading()

	# 測試3: 測試技能選擇流程
	await test_skill_selection_flow()

	LogManager.info("TestRunner", "基本測試完成")

func test_core_systems() -> void:
	LogManager.info("TestRunner", "測試核心系統")

	# 檢查必要的系統是否存在
	var required_systems = ["EventBus", "GameStateManager", "LogManager", "DataManager", "GameCore", "SkillSelectionManager"]

	for system_name in required_systems:
		var system = get_node("/root/" + system_name)
		if system:
			LogManager.info("TestRunner", "系統檢查通過", {"system": system_name})
		else:
			LogManager.error("TestRunner", "系統缺失", {"system": system_name})

func test_data_loading() -> void:
	LogManager.info("TestRunner", "測試數據載入")

	# 等待數據載入完成
	while DataManager.is_loading():
		await get_tree().process_frame

	# 檢查載入錯誤
	var load_errors = DataManager.get_load_errors()
	if load_errors.is_empty():
		LogManager.info("TestRunner", "數據載入成功")
	else:
		LogManager.error("TestRunner", "數據載入錯誤", {"errors": load_errors})

	# 檢查技能數據
	var random_skills = DataManager.get_random_skills(3)
	if random_skills.size() == 3:
		LogManager.info("TestRunner", "技能數據檢查通過", {"skills": random_skills.map(func(s): return s.name)})
	else:
		LogManager.error("TestRunner", "技能數據不足", {"count": random_skills.size()})

func test_skill_selection_flow() -> void:
	LogManager.info("TestRunner", "測試技能選擇流程")

	# 模擬開始新遊戲
	GameCore.start_new_game()

	# 等待狀態變更
	await get_tree().process_frame

	# 檢查是否進入技能選擇狀態
	var current_state = GameStateManager.get_current_state()
	if current_state == GameStateManager.GameState.SKILL_SELECTION:
		LogManager.info("TestRunner", "技能選擇狀態進入成功")
	else:
		LogManager.error("TestRunner", "技能選擇狀態進入失敗", {"current_state": current_state})

	# 檢查SkillSelectionManager是否激活
	if SkillSelectionManager.is_active():
		LogManager.info("TestRunner", "技能選擇管理器激活成功")

		# 獲取當前可選技能
		var available_skills = SkillSelectionManager.get_available_skills()
		if not available_skills.is_empty():
			LogManager.info("TestRunner", "技能選項生成成功", {"count": available_skills.size()})

			# 嘗試選擇第一個技能
			var skill_to_select = available_skills[0]
			var skill_id = skill_to_select.get("id", "")
			var success = SkillSelectionManager.select_skill(skill_id)

			if success:
				LogManager.info("TestRunner", "技能選擇成功", {"skill": skill_to_select.name})
			else:
				LogManager.error("TestRunner", "技能選擇失敗", {"skill": skill_to_select.name})
		else:
			LogManager.error("TestRunner", "技能選項生成失敗")
	else:
		LogManager.error("TestRunner", "技能選擇管理器未激活")

	LogManager.info("TestRunner", "技能選擇流程測試完成")