function [T_eng, T_mot, eng_on] = fuzzy_logic_strategy(eng, mot, bat, SOC, T_demand, eng_speed, eng_on_prev)
% 模糊逻辑能量管理策略
% Fuzzy Logic Energy Management Strategy
%
% 模糊输入变量：
%   1. SOC误差 (e_SOC = SOC - SOC_ref)：{NB, NS, ZO, PS, PB}
%   2. 需求功率 (P_demand)：{Low, Medium, High, Very_High}
%
% 模糊输出变量：
%   1. 发动机功率分配比例 (alpha)：[0, 1]
%      alpha=0: 纯电动；alpha=1: 发动机承担全部需求
%
% 输入:
%   eng        - 发动机参数
%   mot        - 电机参数
%   bat        - 电池参数
%   SOC        - 当前SOC [-]
%   T_demand   - 折算到发动机轴的需求扭矩 [N·m]
%   eng_speed  - 发动机转速 [rpm]
%   eng_on_prev- 上一步发动机状态
%
% 输出:
%   T_eng  - 发动机扭矩指令 [N·m]
%   T_mot  - 电机扭矩指令 [N·m]
%   eng_on - 发动机工作状态

%% 制动处理
if T_demand < 0
    eng_on = 0;
    T_eng  = 0;
    T_mot  = max(-mot.regen_T_max, T_demand);
    return;
end

%% 计算模糊输入
% SOC误差：相对于参考值（0.6）的偏差
e_SOC = SOC - bat.SOC_ref;          % 范围约 [-0.4, 0.3]

% 需求功率（归一化到最大功率）
omega_rad = max(100, eng_speed) * pi / 30;
P_demand  = T_demand * omega_rad;   % [W]
P_max_sys = eng.P_max + mot.P_max;
P_norm    = P_demand / P_max_sys;   % 归一化到 [0, 1]
P_norm    = max(0, min(1, P_norm));

%% 模糊化（计算各隶属度）
% --- SOC误差隶属度 ---
% NB（很低）: e_SOC <= -0.2
mu_NB = trimf(e_SOC, -0.40, -0.25, -0.10);
% NS（较低）: e_SOC ~ -0.1
mu_NS = trimf(e_SOC, -0.20, -0.10,  0.00);
% ZO（正常）: e_SOC ~ 0
mu_ZO = trimf(e_SOC, -0.10,  0.00,  0.10);
% PS（较高）: e_SOC ~ +0.1
mu_PS = trimf(e_SOC,  0.00,  0.10,  0.20);
% PB（很高）: e_SOC >= 0.2
mu_PB = trimf(e_SOC,  0.10,  0.25,  0.40);

% --- 需求功率隶属度 ---
mu_low    = trimf(P_norm, 0.00, 0.00, 0.25);
mu_medium = trimf(P_norm, 0.10, 0.30, 0.50);
mu_high   = trimf(P_norm, 0.35, 0.55, 0.75);
mu_vhigh  = trimf(P_norm, 0.60, 1.00, 1.00);

%% 模糊规则推理（Mamdani方法，重心法去模糊）
% 规则表：alpha（发动机功率分配比例）的输出值
% alpha=0→纯电动，alpha=0.5→均分，alpha=1→发动机全负荷
%
% 规则（e_SOC × P_demand → alpha）：
%         Low   Med   High  VHigh
% NB:    1.0   1.0   1.0   1.0    (SOC很低，发动机全力工作并充电)
% NS:    0.4   0.7   0.9   1.0    (SOC较低，优先发动机)
% ZO:    0.0   0.4   0.7   0.9    (SOC正常，按需分配)
% PS:    0.0   0.1   0.5   0.8    (SOC较高，优先电动)
% PB:    0.0   0.0   0.3   0.7    (SOC很高，尽量纯电动)

rule_table = [
    1.0, 1.0, 1.0, 1.0;   % NB
    0.4, 0.7, 0.9, 1.0;   % NS
    0.0, 0.4, 0.7, 0.9;   % ZO
    0.0, 0.1, 0.5, 0.8;   % PS
    0.0, 0.0, 0.3, 0.7;   % PB
];

soc_mf  = [mu_NB; mu_NS; mu_ZO; mu_PS; mu_PB];   % 5×1
pow_mf  = [mu_low, mu_medium, mu_high, mu_vhigh]; % 1×4

% 加权平均去模糊化（简化为直接加权）
numerator   = 0;
denominator = 0;
for i = 1:5
    for j = 1:4
        strength = min(soc_mf(i), pow_mf(j));   % 取小（AND运算）
        alpha_ij = rule_table(i,j);
        numerator   = numerator   + strength * alpha_ij;
        denominator = denominator + strength;
    end
end

if denominator < 1e-6
    alpha = 0.5;   % 默认均分
else
    alpha = numerator / denominator;
end
alpha = max(0, min(1, alpha));

%% 计算发动机和电机扭矩分配
T_eng = alpha * T_demand;
T_eng = max(0, min(eng.T_max, T_eng));

T_mot = T_demand - T_eng;
T_mot_max = mot.T_max * mot.power_ratio;
T_mot = max(-T_mot_max, min(T_mot_max, T_mot));

%% 判断发动机工作状态
eng_on = (T_eng > 2);   % 发动机扭矩大于2N·m则认为开启

% 迟滞防抖：避免频繁启停
if eng_on_prev == 1 && T_eng < 5
    eng_on = 0;
    T_eng  = 0;
    T_mot  = min(T_demand, T_mot_max);
end

end

%% 三角形隶属度函数
function mu = trimf(x, a, b, c)
% 三角形隶属度函数
% a: 左端点, b: 顶点, c: 右端点
if b == a && b == c
    mu = (x == b);
elseif x <= a || x >= c
    mu = 0;
elseif x <= b
    if (b - a) < 1e-10
        mu = 1;
    else
        mu = (x - a) / (b - a);
    end
else
    if (c - b) < 1e-10
        mu = 1;
    else
        mu = (c - x) / (c - b);
    end
end
mu = max(0, min(1, mu));
end
