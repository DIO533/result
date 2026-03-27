function [SOC_new, I_batt, V_batt] = battery_model(SOC, P_elec, dt, bp)
% 电池/SOC模型：基于等效电路模型（Rint）计算 SOC 变化
%
% 输入:
%   SOC    - 当前荷电状态 [-]，范围 [0,1]
%   P_elec - 电机需求电功率 [W]（正值放电，负值充电）
%   dt     - 时间步长 [s]
%   bp     - 电池参数结构体（来自 battery_params）
%
% 输出:
%   SOC_new - 更新后的 SOC [-]
%   I_batt  - 电池电流 [A]（放电为正）
%   V_batt  - 电池端电压 [V]

% 查表获取当前 SOC 对应的开路电压
V_oc = interp1(bp.soc_table, bp.voc_table, SOC, 'linear', 'extrap');

% 等效电路求解电流（二次方程）
% P = V_batt * I = (V_oc - R*I)*I => R*I^2 - V_oc*I + P = 0
R = bp.R_int;
discriminant = V_oc^2 - 4 * R * P_elec;

if discriminant < 0
    % 无实数解：限制功率
    discriminant = 0;
end

% 取合理根（较小的电流值，对应较高的端电压）
if P_elec >= 0
    % 放电：取较大根（电流正）
    I_batt = (V_oc - sqrt(discriminant)) / (2 * R);
else
    % 充电：取较小根（电流负）
    I_batt = (V_oc + sqrt(discriminant)) / (2 * R);
end

% 限制电流在安全范围内
I_batt = max(min(I_batt,  bp.I_max_dis), -bp.I_max_chg);

% 端电压
V_batt = V_oc - R * I_batt;
V_batt = max(V_batt, 0.1);

% SOC 更新（库仑计数法）
% dSOC = -I * dt / (Q_nom [A·s])
Q_nom_As = bp.Q_nom * 3600;   % 转换为 A·s
SOC_new  = SOC - I_batt * dt / Q_nom_As;

% SOC 硬限幅（保护电池）
SOC_new = max(min(SOC_new, bp.SOC_max), bp.SOC_min);

end
