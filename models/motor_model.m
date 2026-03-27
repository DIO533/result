function [P_elec, eta_mot] = motor_model(T_mot, n_mot, mp)
% 电机模型：基于效率MAP计算电功率和效率
%
% 输入:
%   T_mot  - 电机转矩 [N·m]，正值驱动，负值再生制动
%   n_mot  - 电机转速 [rpm]，>=0
%   mp     - 电机参数结构体（来自 motor_params）
%
% 输出:
%   P_elec  - 电机消耗电功率 [W]（正值耗电，负值发电/回馈）
%   eta_mot - 电机效率 [-]

% 机械功率
omega = n_mot * pi / 30;          % 角速度 [rad/s]
P_mech = T_mot * omega;           % 机械功率 [W]

if abs(P_mech) < 1e-6
    P_elec  = 0;
    eta_mot = 0;
    return;
end

% 转矩、转速限幅后查效率MAP
n_clamped = max(min(abs(n_mot), mp.eff_n(end)), mp.eff_n(1));
T_clamped = max(min(abs(T_mot), mp.eff_T(end)), mp.eff_T(1));

eta_mot = interp2(mp.eff_n, mp.eff_T, mp.eff_map, n_clamped, T_clamped, 'linear', 0.80);
eta_mot = max(min(eta_mot, 0.99), 0.50);

if T_mot >= 0
    % 驱动模式：电功率 = 机械功率 / 效率
    P_elec = P_mech / eta_mot;
else
    % 再生制动模式：电功率 = 机械功率（负值）× 效率（回馈电网）
    P_elec = P_mech * eta_mot;
end

end
