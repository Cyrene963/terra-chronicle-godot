# Terra Chronicle — Godot 迁移版

**版本**: v10 (Godot 4.x)  
**迁移日期**: 2026-06-14  
**原版本**: v9 (PixiJS)

---

## 📦 项目结构

```
terra-chronicle-godot/
├── project.godot          # Godot 项目配置
├── scenes/
│   ├── world/             # 主场景 (地图/玩家/灵兽)
│   ├── ui/                # UI 场景 (炼金/战斗/地城)
│   └── battle/            # 战斗场景
├── scripts/
│   ├── autoload/          # 全局单例
│   │   ├── game_state.gd  # 游戏状态管理
│   │   └── time_system.gd # 四季昼夜系统
│   ├── player/            # 玩家脚本
│   ├── beast/             # 灵兽 AI
│   ├── ui/                # UI 逻辑
│   └── battle/            # 战斗系统
├── assets/
│   ├── sprites/           # 37 个精灵贴图
│   ├── tiles/             # 9 个地表瓦片
│   ├── concept/           # 概念美术
│   ├── data/              # JSON 数据
│   ├── fonts/             # 字体文件
│   └── shaders/           # Shader 文件
└── README.md              # 本文档
```

---

## ✅ 已完成

### 阶段 0: 项目初始化 (第 1 天开始)
- ✅ 创建 Godot 项目 (`project.godot`)
- ✅ 配置输入映射 (WASD + 空格交互)
- ✅ 创建完整目录结构
- ✅ 导入所有美术资产 (37 sprites + 9 tiles + concept)
- ✅ 导入 JSON 数据 (炼金配方 + 游戏系统)
- ✅ 创建全局单例
  - ✅ `GameState` (状态管理 + 存档系统)
  - ✅ `TimeSystem` (四季昼夜 30秒/天 7天/季)

---

## 🚧 进行中

### 阶段 1: 核心引擎 (第 1-2 天)
- [ ] 创建 TileMap + TileSet (9 张瓦片)
- [ ] 玩家 CharacterBody2D
  - [ ] WASD 手动移动
  - [ ] NavigationAgent2D 点击移动
  - [ ] 平滑动画
- [ ] Camera2D 平滑跟随
- [ ] YSort 深度排序
- [ ] 56×56 地图程序生成
  - [ ] 河流生成
  - [ ] 树木/岩石/房屋分布
  - [ ] 耕地区域

---

## 📋 待办事项

### 阶段 2: 四季与昼夜 (第 2-3 天)
- [ ] CanvasModulate 四季色调
- [ ] Light2D 昼夜光照
- [ ] CPUParticles2D 季节粒子 (落叶/雪花)
- [ ] 云影飘动 Shader
- [ ] 晕影 + 柔光后处理

### 阶段 3: 炼金工坊 (第 3-4 天) ⭐ 核心
- [ ] 炼金面板 UI (羊皮纸风格)
- [ ] 青铜大釜视觉
- [ ] 材料投入逻辑
- [ ] 6 条配方系统
- [ ] 金色发现动画
- [ ] 卡牌揭示 3D 翻转

### 阶段 4: UI 全套 (第 4-6 天)
- [ ] 标题画面 (KV 图 + 云朵特效)
- [ ] HUD (季节表盘/时钟/体力/背包)
- [ ] 地城地图 UI
- [ ] 升级面板
- [ ] 培育面板
- [ ] 地块详情面板

### 阶段 5: 灵兽 AI (第 6-7 天)
- [ ] 水灵兽 AI (扫描 moisture<30)
- [ ] 火灵兽 AI (蹲守熔炉)
- [ ] 灵兽状态机

### 阶段 6: 战斗系统 (第 7-8 天)
- [ ] 战斗场景
- [ ] 卡牌拖拽
- [ ] 回合制逻辑
- [ ] 战斗转场

### 阶段 7: 细节打磨 (第 8-10 天)
- [ ] 云朵特效 Shader (1:1 复刻)
- [ ] 动画手感调优
- [ ] 性能优化
- [ ] 最终视觉校验

---

## 📖 参考文档

- [PROJECT_VISION.md](../terra-chronicle-game/PROJECT_VISION.md) — 完整项目愿景
- [GODOT_MIGRATION_GUIDE.md](../terra-chronicle-game/terra-godot-assets/docs/GODOT_MIGRATION_GUIDE.md) — 迁移指南
- [ULTRACODE_V9_REPORT.md](../terra-chronicle-game/ULTRACODE_V9_REPORT.md) — v9 实现报告

---

## 🎮 如何使用

### 1. 用 Godot 4.3+ 打开项目
```bash
# 下载 Godot 4.3+
# 打开 Godot Editor
# 导入项目: /root/terra-chronicle-godot/project.godot
```

### 2. 运行测试
```
点击 Godot 编辑器右上角的 "播放" 按钮
或按 F5
```

---

## 🔗 GitHub 仓库

**PixiJS 原版**: https://github.com/Cyrene963/terra-chronicle  
**Godot 迁移版**: (待创建)

---

**制作人**: Cyrene963  
**迁移时间**: 2026-06-14  
**预计完成**: 2026-06-24 (10 天工作量)
