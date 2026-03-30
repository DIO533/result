# HEV 能量管理策略仿真系统 使用说明

## 项目简介

本仿真系统基于纯 MATLAB `.m` 脚本实现了一个**并联式混合动力汽车（HEV）能量管理策略仿真平台**，无需 Simulink 模型文件（.slx），可在 MATLAB R2018b 及以上版本直接运行。

参考车型参数来自丰田 Prius 级别并联式 HEV。

---

## 快速开始

1. 在 MATLAB 中将工作目录切换到本项目根目录（包含 `main_simulation.m` 的目录）
2. 在命令窗口运行：
   ```matlab
   main_simulation
   ```
3. 程序将自动完成所有仿真，并将图表保存至 `results/` 文件夹

---

## 文件结构

```
main_simulation.m              % 程序入口（运行此文件）
params/
  vehicle_params.m             % 整车参数（质量、阻力系数等）
  engine_params.m              % 发动机参数（BSFC MAP）
  motor_params.m               % 电机参数（效率 MAP）
  battery_params.m             % 电池参数（等效电路）
models/
  engine_model.m               % 发动机模型（BSFC查表）
  motor_model.m                % 电机模型（效率MAP查表）
  battery_model.m              % 电池SOC模型（等效Rint）
  vehicle_dynamics.m           % 整车纵向动力学模型
  transmission_model.m         % 传动系统模型
strategies/
  rule_based_strategy.m        % 基于规则的策略（逻辑门限）
  fuzzy_logic_strategy.m       % 模糊逻辑策略（模糊推理）
  ecms_strategy.m              % ECMS策略（等效油耗最小化）
driving_cycles/
  generate_NEDC.m              % NEDC工况生成（1180s）
  generate_WLTC.m              % WLTC工况生成（1800s）
analysis/
  compare_strategies.m         % 策略对比仿真核心函数
  single_factor_analysis.m     % 单因素变量分析
  plot_results.m               % 策略对比图表绘制（7张图）
  plot_single_factor.m         % 单因素分析图表绘制（3张图）
  sensitivity_analysis.m       % 敏感性分析及柱状图
results/                       % 仿真结果输出目录
README_simulation.md           % 本说明文档
```

---

## 仿真模型说明

### 整车动力学模型
- 纵向动力学：`F = F_aero + F_roll + F_inertia`
- 空气阻力、滚动阻力、惯性力逐项计算

### 发动机模型
- 基于 BSFC（制动比油耗）万有特性曲线二维插值
- 输入：转矩、转速 → 输出：油耗率 [g/s]、热效率

### 电机模型
- 基于效率 MAP 二维插值
- 支持驱动（正转矩）和再生制动（负转矩）两种工作模式

### 电池模型
- 等效内阻模型（Rint 模型）
- 通过库仑计数法更新 SOC
- SOC 安全范围：[0.2, 0.9]

### 传动系统模型
- 5速自动变速器，基于车速自动换挡
- 含主减速比（4.1）

---

## 能量管理策略

### 1. 基于规则的策略（Rule-Based）
- 低功率/充足SOC → 纯电动模式
- SOC过低 → 发动机主驱并充电
- 大功率需求 → 发动机+电机并联驱动

### 2. 模糊逻辑策略（Fuzzy Logic）
- 输入：功率需求归一化值、SOC偏差
- 使用三角隶属度函数 + 重心法解模糊
- 输出：发动机功率分配比例

### 3. ECMS 策略（等效燃油消耗最小化）
- 等效燃油：`H_eq = m_f + s × P_elec / H_fuel`
- 自适应等效因子（根据SOC偏差修正）
- 离散搜索最优功率分配比例

---

## 输出图表说明

### 策略对比图表（NEDC 和 WLTC 各生成一套，共14张）

| 文件名后缀 | 内容 |
|-----------|------|
| `_01_speed_tracking` | 车速跟随曲线对比 |
| `_02_SOC_trajectory` | SOC 变化轨迹对比 |
| `_03_fuel_rate` | 瞬时燃油消耗率对比 |
| `_04_engine_op_points` | 发动机工作点分布图 |
| `_05_motor_op_points` | 电机工作点分布图 |
| `_06_total_fuel_bar` | 总燃油消耗柱状图 |
| `_07_radar_chart` | 等效燃油经济性雷达图 |

### 单因素分析图表（共3张）

| 文件名 | 内容 |
|--------|------|
| `SFA_01_SOC_init_vs_fuel` | 初始SOC vs 燃油经济性 |
| `SFA_02_motor_scale_vs_fuel` | 电机功率比例因子 vs 燃油经济性 |
| `SFA_03_soc_thresh_vs_fuel` | 启停SOC阈值 vs 燃油经济性 |

### 敏感性分析图表（共1张）

| 文件名 | 内容 |
|--------|------|
| `sensitivity_analysis` | 各单因素敏感性柱状图 |

---

## 主要仿真参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 整车质量 | 1500 kg | 含乘员 |
| 发动机最大功率 | 73 kW | 1.8L NA |
| 电机最大功率 | 60 kW | PMSM |
| 电池容量 | 6.5 Ah / 201.6V | NiMH |
| 初始SOC | 0.6 | 默认值 |
| SOC目标值 | 0.6 | 充电保持目标 |
| ECMS等效因子 | 2.5 | 初始值 |

---

## 系统要求

- MATLAB R2018b 或更高版本
- 无需额外工具箱（Fuzzy Logic Toolbox、Simulink 等均不需要）
- 模糊逻辑控制器已内置实现，无需 Fuzzy Logic Toolbox

---

## 注意事项

1. 首次运行时间约 2~5 分钟（视电脑性能而定）
2. 若 `exportgraphics` 函数不可用（R2019b 以下），程序会自动降级使用 `print` 保存图片
3. 所有图表同时保存为 `.fig`（MATLAB 格式）和 `.png`（图片格式）

---

*本仿真系统基于论文《2223865朱晨吉论文优化建议与修改稿》中的需求描述开发。*
