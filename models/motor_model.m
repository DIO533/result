function [P_elec, efficiency, T_actual] = motor_model(mot, speed_rpm, torque_req)
% 电机模型 - 基于效率MAP计算电功率
% Motor Model - Calculate electrical power based on efficiency MAP
%
% 输入:
%   mot       - 电机参数结构体
%   speed_rpm - 电机转速 [rpm]
%   torque_req- 需求扭矩 [N·m]（正：驱动；负：制动/发电）
%
% 输出:
%   P_elec    - 电功率 [W]（正：耗电；负：发电/回收）
%   efficiency- 电机效率 [-]
%   T_actual  - 实际扭矩（限幅后）[N·m]

% 限制转速范围
speed_rpm = max(0, min(mot.speed_max, speed_rpm));

% 恒扭矩区与恒功率区的最大扭矩
if speed_rpm <= mot.speed_base
    T_lim = mot.T_max;
else
    % 恒功率区：T_max随转速增大而减小
    omega_base = mot.speed_base * pi / 30;
    omega      = speed_rpm     * pi / 30;
    T_lim = mot.P_max / omega;
    T_lim = min(T_lim, mot.T_max);
end
T_lim = max(0, T_lim);

% 限幅实际扭矩
T_actual = max(-T_lim, min(T_lim, torque_req));

% 计算机械功率 [W]
omega     = speed_rpm * pi / 30;          % 角速度 [rad/s]
P_mech    = T_actual * omega;             % 机械功率 [W]

% 查找效率MAP（限制在表格范围内）
speed_clamped  = max(mot.speed_map(1),  min(mot.speed_map(end),  speed_rpm));
torque_clamped = max(mot.torque_map(1), min(mot.torque_map(end), T_actual));

efficiency = interp2(mot.torque_map, mot.speed_map, mot.eff_map, ...
                     torque_clamped, speed_clamped, 'linear');
efficiency = max(0.60, min(0.99, efficiency));

% 若扭矩为0则效率设为0（避免除零）
if abs(T_actual) < 0.1
    efficiency = 0;
    P_elec     = 0;
    return;
end

% 计算电功率 [W]
if P_mech >= 0
    % 驱动模式：电功率 = 机械功率 / 效率（耗电，为正值）
    P_elec = P_mech / efficiency;
else
    % 再生制动/发电模式：电功率 = 机械功率 * 效率（发电，为负值）
    P_elec = P_mech * efficiency;
end

end
