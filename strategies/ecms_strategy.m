function [T_eng, T_mot, eng_on] = ecms_strategy(P_demand, SOC, v, ep, mp, bp)
% 等效燃油消耗最小策略（ECMS - Equivalent Consumption Minimization Strategy）
% 在每个时刻通过最小化等效燃油消耗来分配发动机/电机功率
%
% 等效燃油消耗：
%   H_eq = m_f(P_eng, n_eng) + s * P_elec / H_fuel
%   其中 s 为等效因子，P_elec 为电机用电功率
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

omega_w = max(v / 0.317, 0.1);   % 车轮角速度 [rad/s]

% ---- 自适应等效因子（根据SOC偏差修正） ----
s_base   = bp.s_ecms;
SOC_err  = SOC - bp.SOC_ref;
s_adapt  = s_base * (1 - 1.5 * SOC_err);   % SOC低 -> 增大s -> 倾向用电机少
s_adapt  = max(min(s_adapt, 6.0), 1.0);

% ---- 制动工况：发动机关，电机再生 ----
if P_demand <= 0
    eng_on = false;
    T_eng  = 0;
    T_mot  = max(P_demand / omega_w, -mp.T_max);
    return;
end

% ---- 驱动工况：离散搜索最优 P_eng 分配 ----
% 候选发动机功率比例：0（纯电）到1（纯发动机），步长0.1
best_cost = inf;
best_alpha = 0;

% 使用粗粒度搜索（11个点），降低计算量
alphas = 0:0.1:1.0;

for alpha = alphas
    P_eng_try = alpha * P_demand;
    P_mot_try = (1 - alpha) * P_demand;

    % === 发动机模型估算油耗 ===
    if P_eng_try < 3000
        % 发动机不工作
        m_f = 0;
        P_eng_try = 0;
        P_mot_try = P_demand;
    else
        % 估算发动机工作点（简化：转速=2500rpm，调整转矩）
        n_eng_est = 2500;  % [rpm]，近似
        T_eng_est = P_eng_try / (n_eng_est * pi / 30);
        T_eng_est = max(min(T_eng_est, ep.T_max), 0);

        [m_f_rate, ~, ~] = engine_model(T_eng_est, n_eng_est, ep);
        m_f = m_f_rate;   % [g/s]
    end

    % === 电机等效油耗 ===
    % 查电机效率（近似：转矩和转速简化）
    n_mot_est = 3000;   % [rpm]，简化
    T_mot_est = P_mot_try / max(n_mot_est * pi / 30, 1);
    T_mot_est = max(min(abs(T_mot_est), mp.T_max), 0);
    [P_elec_est, ~] = motor_model(T_mot_est, n_mot_est, mp);

    % 等效燃油 [g/s]
    H_fuel_Ws = ep.H_fuel * 1000;  % kJ/kg -> J/kg
    m_elec_eq = s_adapt * abs(P_elec_est) / H_fuel_Ws;

    % 若SOC过高，充电是有利的（负等效消耗）
    if P_mot_try < 0 && SOC > bp.SOC_ref
        m_elec_eq = -m_elec_eq * 0.5;
    end

    cost = m_f + m_elec_eq;

    if cost < best_cost
        best_cost  = cost;
        best_alpha = alpha;
    end
end

% ---- 根据最优分配计算最终转矩 ----
P_eng_opt = best_alpha * P_demand;
P_mot_opt = (1 - best_alpha) * P_demand;

if P_eng_opt < 3000 && SOC > bp.SOC_min + 0.05
    eng_on = false;
    T_eng  = 0;
    T_mot  = min(P_demand / omega_w, mp.T_max);
else
    eng_on = true;
    T_eng  = min(P_eng_opt / omega_w, ep.T_max);
    T_eng  = max(T_eng, 0);
    T_mot  = max(min(P_mot_opt / omega_w, mp.T_max), -mp.T_max);
end

end
