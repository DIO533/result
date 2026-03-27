function [F_traction, P_demand, a_actual] = vehicle_dynamics(v, v_target, dt, vp)
% 整车纵向动力学模型
% 计算所需牵引力和需求功率
%
% 输入:
%   v        - 当前车速 [m/s]
%   v_target - 目标车速 [m/s]（来自工况）
%   dt       - 时间步长 [s]
%   vp       - 整车参数结构体（来自 vehicle_params）
%
% 输出:
%   F_traction - 所需牵引力 [N]（正：驱动，负：制动）
%   P_demand   - 所需功率 [W]
%   a_actual   - 实际加速度 [m/s^2]

% 加速度需求（采用一阶跟踪控制，限幅避免过大加减速）
a_demand = (v_target - v) / dt;
a_limit  = 3.0;    % 最大加减速度 [m/s^2]（舒适性限制）
a_actual = max(min(a_demand, a_limit), -a_limit);

% 各阻力计算（以速度 v 为基准）
v_safe = max(v, 0);    % 车速不为负

% 1. 空气阻力
F_aero = 0.5 * vp.rho_air * vp.Cd * vp.A_frontal * v_safe^2;

% 2. 滚动阻力（含坡道辅助）
F_roll = vp.m * vp.g * (vp.Cr * cos(vp.grade) + sin(vp.grade));

% 3. 惯性力（含等效旋转质量，系数1.05）
F_inertia = 1.05 * vp.m * a_actual;

% 总牵引力需求
F_traction = F_aero + F_roll + F_inertia;

% 功率需求（在当前车速下）
P_demand = F_traction * v_safe;

end
