function [T_eng, T_mot, eng_on] = fuzzy_logic_strategy(P_demand, SOC, v, ep, mp, bp)
% 模糊逻辑能量管理策略（Fuzzy Logic Strategy）
% 基于功率需求和SOC两个输入，通过模糊推理决策功率分配
%
% 输入:
%   P_demand - 当前驾驶需求功率 [W]
%   SOC      - 当前电池荷电状态 [-]
%   v        - 当前车速 [m/s]
%   ep, mp, bp - 各子系统参数
%
% 输出:
%   T_eng   - 发动机目标转矩 [N·m]
%   T_mot   - 电机目标转矩 [N·m]
%   eng_on  - 发动机是否运行

% ---- 模糊化：功率需求 (P_norm，归一化到 [-1,1])
%   负值表示制动，正值表示驱动
P_max_ref = ep.P_max + mp.P_max;    % 系统最大驱动功率
P_norm = P_demand / P_max_ref;      % 归一化功率
P_norm = max(min(P_norm, 1.0), -0.5);

% ---- 模糊化：SOC 偏差 (SOC_err，相对于参考值)
SOC_ref  = bp.SOC_ref;
SOC_err  = SOC - SOC_ref;           % 正值：SOC 偏高；负值：SOC 偏低
SOC_err  = max(min(SOC_err, 0.4), -0.4);

% ========================
% 模糊隶属度函数（三角型）
% ========================
% P_norm 论域：负大(NB)，零(ZE)，正小(PS)，正大(PB)
mu_P_NB = trimf(P_norm, [-0.5, -0.3, 0.0]);
mu_P_ZE = trimf(P_norm, [-0.1,  0.0, 0.2]);
mu_P_PS = trimf(P_norm, [ 0.0,  0.25, 0.5]);
mu_P_PB = trimf(P_norm, [ 0.35, 0.7, 1.0]);

% SOC_err 论域：负大(NB)，零(ZE)，正大(PB)
mu_S_NB = trimf(SOC_err, [-0.4, -0.2, 0.0]);
mu_S_ZE = trimf(SOC_err, [-0.1,  0.0, 0.1]);
mu_S_PB = trimf(SOC_err, [ 0.0,  0.2, 0.4]);

% ========================
% 模糊规则库（9条核心规则）
% 输出变量：alpha（发动机功率占比，范围[0,1]）
% ========================
% 规则表（行=P_norm 模糊集；列=SOC_err 模糊集）：
%             SOC_NB  SOC_ZE  SOC_PB
% P_NB:        0.0     0.0     0.0    （制动：发动机关，再生）
% P_ZE:        0.8     0.5     0.1    （需求为零：SOC低则充电）
% P_PS:        1.0     0.7     0.3    （小功率需求）
% P_PB:        1.0     0.9     0.6    （大功率需求）

alpha_table = [
    0.0,  0.0,  0.0;   % P_NB
    0.8,  0.5,  0.1;   % P_ZE
    1.0,  0.7,  0.3;   % P_PS
    1.0,  0.9,  0.6;   % P_PB
];

mu_P = [mu_P_NB; mu_P_ZE; mu_P_PS; mu_P_PB];
mu_S = [mu_S_NB; mu_S_ZE; mu_S_PB];

% 重心法解模糊
num = 0;
den = 0;
for i = 1:4
    for j = 1:3
        mu_rule = min(mu_P(i), mu_S(j));
        num = num + mu_rule * alpha_table(i, j);
        den = den + mu_rule;
    end
end

if den < 1e-6
    alpha = 0.5;
else
    alpha = num / den;
end

alpha = max(min(alpha, 1.0), 0.0);

% ========================
% 去模糊化：计算转矩分配
% ========================
omega_w = max(v / 0.317, 0.1);    % 车轮角速度 [rad/s]

if P_demand < 0
    % 制动再生：发动机关，电机回馈
    eng_on = false;
    T_eng  = 0;
    T_mot  = max(P_demand / omega_w, -mp.T_max);
else
    % 驱动：按 alpha 分配功率
    P_eng_cmd = alpha * P_demand;
    P_mot_cmd = (1 - alpha) * P_demand;

    % 判断发动机是否启动（最小功率门限）
    P_eng_min = 5000;   % 低于5kW不值得开发动机
    if P_eng_cmd < P_eng_min && SOC > bp.SOC_min + 0.05
        eng_on = false;
        T_eng  = 0;
        T_mot  = min(P_demand / omega_w, mp.T_max);
    else
        eng_on = true;
        T_eng  = min(P_eng_cmd / omega_w, ep.T_max);
        T_mot  = max(min(P_mot_cmd / omega_w, mp.T_max), -mp.T_max);
    end
end

end

% ---- 辅助：三角隶属度函数 ----
function mu = trimf(x, params)
    a = params(1); b = params(2); c = params(3);
    if x <= a || x >= c
        mu = 0;
    elseif x <= b
        mu = (x - a) / max(b - a, 1e-9);
    else
        mu = (c - x) / max(c - b, 1e-9);
    end
    mu = max(min(mu, 1), 0);
end
