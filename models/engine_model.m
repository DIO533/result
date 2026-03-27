function [fuel_rate, bsfc, T_actual] = engine_model(eng, speed_rpm, torque_req)
% 发动机模型 - 基于万有特性曲线计算燃油消耗率
% Engine Model - Calculate fuel consumption based on universal characteristic curve
%
% 输入:
%   eng       - 发动机参数结构体
%   speed_rpm - 发动机转速 [rpm]
%   torque_req- 需求扭矩 [N·m]
%
% 输出:
%   fuel_rate - 瞬时燃油消耗率 [g/s]
%   bsfc      - 制动比油耗 [g/kWh]
%   T_actual  - 实际输出扭矩（限幅后）[N·m]

% 确保输入为标量
speed_rpm  = max(eng.speed_min, min(eng.speed_max, speed_rpm));
torque_req = max(0, torque_req);  % 发动机只输出正扭矩

% 限制在最大扭矩曲线以内（插值得到该转速下最大扭矩）
T_max_at_speed = interp1(eng.speed_map, eng.T_max_curve, speed_rpm, 'linear', 'extrap');
T_max_at_speed = max(0, T_max_at_speed);
T_actual = min(torque_req, T_max_at_speed);

% 如果扭矩需求为0或发动机关闭，无燃油消耗
if T_actual <= 0 || speed_rpm <= eng.speed_idle
    fuel_rate = 0;
    bsfc      = 0;
    T_actual  = 0;
    return;
end

% 用MAP插值计算BSFC [g/kWh]
% 限制在MAP范围内
speed_clamped  = max(eng.speed_map(1),  min(eng.speed_map(end),  speed_rpm));
torque_clamped = max(eng.torque_map(1), min(eng.torque_map(end), T_actual));

bsfc = interp2(eng.torque_map, eng.speed_map, eng.bsfc_map, ...
               torque_clamped, speed_clamped, 'linear');

% 避免无效值
bsfc = max(200, min(500, bsfc));

% 计算实际功率 [W]
power_kW = T_actual * speed_rpm * (pi/30) / 1000;   % kW

% 计算燃油消耗率 [g/s]
% fuel_rate [g/s] = bsfc [g/kWh] * power [kW] / 3600
fuel_rate = bsfc * power_kW / 3600;
fuel_rate = max(0, fuel_rate);

end
