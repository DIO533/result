function [F_traction, F_resist, a_actual] = vehicle_dynamics(veh, v, a_req, T_wheel, dt)
% 整车动力学模型 - 纵向动力学计算
% Vehicle Dynamics Model - Longitudinal dynamics calculation
%
% 输入:
%   veh     - 整车参数结构体
%   v       - 当前车速 [m/s]
%   a_req   - 需求加速度 [m/s²]（由工况曲线微分得到）
%   T_wheel - 车轮驱动扭矩 [N·m]（由传动系传来）
%   dt      - 仿真步长 [s]
%
% 输出:
%   F_traction - 驱动力 [N]
%   F_resist   - 总阻力 [N]
%   a_actual   - 实际加速度 [m/s²]

% 1. 计算行驶阻力
%    空气阻力
F_aero = 0.5 * veh.rho_air * veh.Cd * veh.A_front * v^2;

%    滚动阻力
F_roll = veh.mass * veh.g * veh.f0 * cos(veh.road_slope);

%    坡道阻力
F_grade = veh.mass * veh.g * sin(veh.road_slope);

%    总行驶阻力
F_resist = F_aero + F_roll + F_grade;

% 2. 车轮驱动力
F_traction = T_wheel / veh.r_wheel;

% 3. 净力 -> 加速度
F_net    = F_traction - F_resist;
a_actual = F_net / veh.mass_total;

% 4. 注：实际仿真中车速由工况给定（速度跟随控制），
%        此函数主要用于计算驱动力需求
%        需求驱动力 = 加速力 + 行驶阻力
% 需求驱动力（用于后续扭矩分配）
F_demand = veh.mass_total * a_req + F_resist;

% 若仅需计算行驶阻力和驱动力分析，返回上述结果
% 实际加速度由F_net/m计算
end
