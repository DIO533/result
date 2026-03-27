function [T_eng, T_mot, eng_on] = rule_based_strategy(eng, mot, bat, SOC, T_demand, eng_speed, eng_on_prev)
% 基于规则的能量管理策略 - 逻辑门限控制
% Rule-Based Energy Management Strategy - Logic Threshold Control
%
% 控制逻辑：
%   1. SOC < SOC_low  → 发动机工作，并为电池充电
%   2. SOC > SOC_high → 纯电动驱动（如扭矩允许）
%   3. 中间状态       → 根据扭矩需求决定是否启动发动机
%   4. 低速/制动      → 纯电动/再生制动
%
% 输入:
%   eng        - 发动机参数
%   mot        - 电机参数
%   bat        - 电池参数
%   SOC        - 当前SOC [-]
%   T_demand   - 车轮需求扭矩折算到发动机轴的扭矩 [N·m]
%   eng_speed  - 当前发动机/电机转速 [rpm]
%   eng_on_prev- 上一时刻发动机状态（0:关闭，1:开启）
%
% 输出:
%   T_eng  - 发动机扭矩指令 [N·m]
%   T_mot  - 电机扭矩指令 [N·m]（正：驱动；负：发电/再生）
%   eng_on - 发动机工作状态（0/1）

%% 控制参数（从参数文件读取，可修改）
SOC_low   = eng.soc_start;   % 发动机启动SOC阈值（默认0.40）
SOC_high  = eng.soc_stop;    % 发动机停止SOC阈值（默认0.70）
T_eng_opt = 60;              % 发动机最优工作扭矩 [N·m]
T_mot_max = mot.T_max * mot.power_ratio;   % 电机最大扭矩

%% 情况1：制动/减速（需求扭矩为负）
if T_demand < 0
    eng_on = 0;      % 发动机关闭
    T_eng  = 0;
    % 再生制动：限幅
    T_mot = max(-mot.regen_T_max, T_demand);
    return;
end

%% 情况2：SOC过低 → 强制启动发动机，同时充电
if SOC < SOC_low
    T_charge_extra = 10;     % 额外充电扭矩 [N·m]，用于向电池充电
    eng_on = 1;
    % 发动机工作在最优点或需求扭矩，额外分配T_charge_extra用于充电
    T_eng = max(T_demand + T_charge_extra, T_eng_opt);
    T_eng = min(T_eng, eng.T_max);
    T_mot = T_demand - T_eng;               % 电机发电（负值）
    T_mot = max(-mot.T_max, min(T_mot_max, T_mot));
    return;
end

%% 情况3：SOC过高 → 纯电动驱动（电机优先）
if SOC > SOC_high && T_demand <= T_mot_max
    eng_on = 0;
    T_eng  = 0;
    T_mot  = min(T_demand, T_mot_max);
    return;
end

%% 情况4：低扭矩需求 → 纯电动驱动
T_threshold = eng.T_start_th;  % 启动发动机的扭矩阈值（默认30 N·m）
if T_demand <= T_threshold && SOC > SOC_low + 0.05
    eng_on = 0;
    T_eng  = 0;
    T_mot  = min(T_demand, T_mot_max);
    return;
end

%% 情况5：中等/高扭矩需求 → 发动机+电机联合驱动
% 发动机启动迟滞（避免频繁启停）
if eng_on_prev == 0 && T_demand < T_threshold * 1.2
    % 保持发动机关闭（迟滞环节）
    eng_on = 0;
    T_eng  = 0;
    T_mot  = min(T_demand, T_mot_max);
    return;
end

eng_on = 1;
% 发动机尽量工作在最优区间
T_eng = min(T_demand, T_eng_opt);
T_eng = max(0, T_eng);

% 不足部分由电机补充
T_mot = T_demand - T_eng;
T_mot = max(-T_mot_max, min(T_mot_max, T_mot));

% 若电机扭矩超出能力，发动机补充更多
if T_mot > T_mot_max
    T_eng = T_demand - T_mot_max;
    T_eng = min(T_eng, eng.T_max);
    T_mot = T_demand - T_eng;
end

end
