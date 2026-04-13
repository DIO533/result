function [eng_speed, mot_speed, gear, T_wheel_demand] = transmission_model(veh, v, a_req)
% 传动系统模型 - 计算各部件转速和扭矩需求
% Transmission Model - Calculate component speeds and torque demands
%
% 输入:
%   veh   - 整车参数结构体
%   v     - 当前车速 [m/s]
%   a_req - 需求加速度 [m/s²]
%
% 输出:
%   eng_speed     - 发动机转速 [rpm]
%   mot_speed     - 电机转速 [rpm]（并联结构与发动机同轴）
%   gear          - 当前挡位 [-]
%   T_wheel_demand- 车轮需求扭矩 [N·m]

%% 换挡逻辑（基于车速的自动换挡，使用整车参数中定义的升挡阈值）
% 使用 veh.gear_up_speed 阈值判断挡位（从高挡到低挡依次判断）
n_gears = length(veh.gear_ratio);
gear = 1;
for g = n_gears : -1 : 2
    if v >= veh.gear_up_speed(g)
        gear = g;
        break;
    end
end

%% 计算车轮需求扭矩
% 行驶阻力
F_aero  = 0.5 * 1.225 * veh.Cd * veh.A_front * v^2;
F_roll  = veh.mass * veh.g * veh.f0;
F_grade = veh.mass * veh.g * sin(veh.road_slope);

% 加速力
F_accel = veh.mass_total * a_req;

% 总需求驱动力（包括加速力）
F_total = F_accel + F_aero + F_roll + F_grade;

% 车轮需求扭矩 [N·m]
T_wheel_demand = F_total * veh.r_wheel;

%% 计算传动轴转速
% 车轮转速 [rpm]
wheel_speed_rpm = v / veh.r_wheel * (30/pi);  % [rpm]

% 传动轴（输出轴）转速
% n_shaft = n_wheel * i_final
shaft_speed_rpm = wheel_speed_rpm * veh.final_ratio;

% 发动机/电机转速（通过变速箱挡位比）
i_gear = veh.gear_ratio(gear);
eng_speed = shaft_speed_rpm * i_gear;      % [rpm]

% 限制发动机转速在工作范围
eng_speed = max(700, min(5500, eng_speed));

% 并联结构：电机与发动机通过离合器连接，转速相同
mot_speed = eng_speed;    % [rpm]

% 若车速极低（接近停车），转速设为怠速/零
if v < 0.5  % v < 0.5 m/s ≈ 1.8 km/h
    eng_speed = 700;   % 怠速
    mot_speed = 0;     % 电机可以停止
end

end
