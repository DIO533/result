function [T_wheel, n_wheel, gear] = transmission_model(P_demand, v, vp)
% 传动系统模型：计算车轮端转矩和转速，以及挡位
%
% 输入:
%   P_demand - 车轮功率需求 [W]
%   v        - 当前车速 [m/s]
%   vp       - 整车参数结构体（来自 vehicle_params）
%
% 输出:
%   T_wheel  - 车轮转矩 [N·m]（正：驱动，负：制动）
%   n_wheel  - 车轮转速 [rpm]
%   gear     - 当前挡位 [-]（1~5）

% 变速器各挡传动比（5速自动）
gear_ratios = [3.55, 2.04, 1.36, 1.00, 0.76];

% 车轮转速 [rpm]
omega_wheel = v / vp.r_wheel;       % [rad/s]
n_wheel = omega_wheel * 30 / pi;    % [rpm]

% 自动换挡策略（基于车速）
v_kmh = v * 3.6;
if v_kmh < 15
    gear = 1;
elseif v_kmh < 35
    gear = 2;
elseif v_kmh < 60
    gear = 3;
elseif v_kmh < 90
    gear = 4;
else
    gear = 5;
end

% 当前总传动比（含主减速比）
i_total = gear_ratios(gear) * vp.i_final;

% 车轮转矩
if abs(v) > 0.1
    T_wheel = P_demand / max(omega_wheel, 0.1);
else
    T_wheel = 0;
end

end
