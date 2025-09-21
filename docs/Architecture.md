# 架構文件

## 🏗️ Architecture Design

### Design Principles

架構遵循遊戲開發的業界標準模式：
  1. **事件驅動架構** - 系統間解耦的通訊方式
  2. **分層架構模式** - 清晰的職責分離
  3. **單一職責原則** - 每個類別只有一個明確用途
  4. **依賴反轉原則** - 依賴抽象，而非具體實作
  5. **觀察者模式** - 透過事件通知實現鬆散耦合

### Architecture Layers

```
┌────────────────────────────────────────────────────────────┐
│                        UI Layer                            │
│  SkillSelectionUI │ GameMainUI │ CityInfoUI │ BattleUI     │
└────────────────────────────────────────────────────────────┘
                               │
                          Event Bus
                               │
┌────────────────────────────────────────────────────────────┐
│                     Manager Layer                          │
│    DataManager │ UIManager │ SaveManager │ AudioManager.   │
└────────────────────────────────────────────────────────────┘
                               │
                          Event Bus
                               │
┌──────────────────────────────────────────────────────────────┐
│                     Systems Layer                            │
│ SkillSystem │ BattleSystem │ CitySystem │ TurnSystem │ AI    │
└──────────────────────────────────────────────────────────────┘
                               │
                          Event Bus
                               │
┌───────────────────────────────────────────────────────────┐
│                      Core Layer                           │
│       EventBus │ GameStateManager │ GameCore | LogManager │
└───────────────────────────────────────────────────────────┘
```

## 🎯 Core Components

### EventBus.gd - Communication Hub

**目的**：作為所有系統間通訊的中樞神經系統

**主要功能**：
- 為所有遊戲系統提供類型安全的事件定義
- 自動化錯誤處理與日誌紀錄
- 訊號連線管理
- 提供除錯功能以追蹤事件流程

### GameStateManager.gd - State Machine
**Purpose**: Unified game state management with validation and history

**State Definitions**:
```gdscript
enum GameState {
    MENU,            # 主選單
    SKILL_SELECTION, # 技能選擇階段
    GAME_RUNNING,    # 主遊戲循環
    BATTLE,          # 戰鬥階段
    PAUSED,          # 遊戲暫停
    GAME_OVER        # 遊戲結束
}

```

### GameCore.gd - Main Controller

**目的**：專注於遊戲流程控制

**職責**：
- 初始化並協調所有遊戲系統
- 管理玩家資料與遊戲進度
- 處理高階遊戲流程（開始遊戲、技能選擇、主循環）
- 協調系統的啟動與關閉

### SkillSystem.gd - 技能管理

**目的**：完整的技能選擇與管理系統

**功能**：
- 自包含的技能選擇狀態機
- 星數經濟系統管理
- 技能效果應用
- 基於回合的選擇邏輯
- 剩餘星數轉換為屬性

### LogManager.gd - Logger管理

**功能**：
- 專業完整的Log格式
- 能夠清楚的指出錯誤檔案與地點 (例如檔案:行數)
- 可讀性佳 人類可讀
- 儲存Log檔案在/logs