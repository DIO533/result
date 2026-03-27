function [T_eng, T_mot, eng_on] = rule_based_strategy(P_demand, SOC, v, ep, mp, bp)
% 基于规则的能量管理策略（Rule-Based Strategy）
% 采用功率分界点+SOC门限的逻辑控制
%
% 输入:
%   P_demand - 当前驾驶需求功率 [W]
%   SOC      - 当前电池荷电状态 [-]
%   v        - 当前车速 [m/s]
%   ep, mp, bp - 各子系统参数
%
% 输出:
%   T_eng   - 发动机目标转矩 [N·m]（0 = 停机）
%   T_mot   - 电机目标转矩 [N·m]（正=驱动，负=再生）
%   eng_on  - 发动机是否运行标志

% 车轮角速度
omega_w = max(v / 0.317, 0.1);  % [rad/s]

% ============================
% 规则1：纯电动模式
%   低速 OR 低功率需求 AND SOC 充足
% ============================
P_ev_threshold = ep.P_start;    % 低于此功率优先纯电
soc_ok = SOC > bp.SOC_min + 0.05;

if P_demand <= P_ev_threshold && soc_ok
    % 纯电动
    eng_on = false;
    T_mot  = max(min(P_demand / omega_w, mp.T_max), -mp.T_max);
    T_eng  = 0;
    return;
end

% ============================
% 规则2：SOC 过低，强制发动机驱动+充电
% ============================
if SOC < bp.SOC_min + 0.05
    eng_on = true;
    % 发动机工作在最优效率区
    n_eng_opt = 0.5 * (ep.n_opt_low + ep.n_opt_high);  % ~2500 rpm
    T_eng_opt = 0.5 * (ep.T_opt_low  + ep.T_opt_high); % ~85 N·m
    P_eng_opt = T_eng_opt * n_eng_opt * pi / 30;

    T_eng = T_eng_opt;

    % 多余功率充电（电机作发电机）
    P_motor = P_demand - P_eng_opt;
    T_mot = max(min(P_motor / omega_w, mp.T_max), -mp.T_max);
    return;
end

% ============================
% 规则3：大功率需求，发动机主驱+电机辅助
% ============================
if P_demand > P_ev_threshold
    eng_on = true;
    % 发动机尽量工作在高效区
    T_eng_opt = min(ep.T_opt_high, ep.T_max);
    T_eng = T_eng_opt;
    P_eng = T_eng_opt * omega_w;   % 近似（忽略传动比差异，简化）

    % 电机补足不足部分
    P_motor = P_demand - P_eng;
    T_mot = max(min(P_motor / omega_w, mp.T_max), -mp.T_max);
    return;
end

% ============================
% 默认：并联驱动（SOC 中等，功率中等）
% ============================
eng_on = true;
T_eng  = 0.6 * ep.T_max;
P_eng  = T_eng * omega_w;
P_motor = P_demand - P_eng;
T_mot = max(min(P_motor / omega_w, mp.T_max), -mp.T_max);

end
