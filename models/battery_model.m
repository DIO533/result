function [SOC_new, I_bat, V_bat] = battery_model(bat, SOC, P_elec, dt)
% 电池/SOC模型 - 基于等效电路计算SOC变化
% Battery/SOC Model - Calculate SOC change based on equivalent circuit model
%
% 输入:
%   bat    - 电池参数结构体
%   SOC    - 当前荷电状态 [-]（0~1）
%   P_elec - 电机消耗的电功率 [W]（正：放电；负：充电）
%   dt     - 仿真步长 [s]
%
% 输出:
%   SOC_new - 更新后的SOC [-]
%   I_bat   - 电池电流 [A]（正：放电；负：充电）
%   V_bat   - 电池端电压 [V]

% 获取当前开路电压（OCV）
OCV = interp1(bat.SOC_table, bat.OCV_table, SOC, 'linear', 'extrap');
OCV = max(bat.OCV_table(1), min(bat.OCV_table(end), OCV));

% 限制功率在允许范围内
if P_elec > 0
    % 放电
    P_elec = min(P_elec, bat.P_max_discharge);
    R_int  = bat.R_discharge;
else
    % 充电
    P_elec = max(P_elec, -bat.P_max_charge);
    R_int  = bat.R_charge;
end

% 由功率求电流（二次方程求解）：P = V_bat * I = (OCV - R*I) * I
% R*I^2 - OCV*I + P = 0
% 放电时P>0，使用正号解；充电时P<0
a = R_int;
b = -OCV;
c = P_elec;

discriminant = b^2 - 4*a*c;
if discriminant < 0
    % 判别式为负（功率超限），限制功率
    % 最大可用功率 P_max = OCV^2 / (4*R)
    P_max_avail = OCV^2 / (4 * R_int);
    if P_elec > 0
        P_elec = min(P_elec, P_max_avail * 0.95);
    else
        P_elec = max(P_elec, -P_max_avail * 0.95);
    end
    c = P_elec;
    discriminant = b^2 - 4*a*c;
    discriminant = max(0, discriminant);
end

% 取物理上合理的解（放电取小的正根，充电取大的负根）
sqrt_disc = sqrt(discriminant);
I1 = (-b + sqrt_disc) / (2*a);
I2 = (-b - sqrt_disc) / (2*a);

if P_elec >= 0
    % 放电：选较小的正值解（减少损耗）
    if I1 >= 0 && I2 >= 0
        I_bat = min(I1, I2);
    elseif I1 >= 0
        I_bat = I1;
    elseif I2 >= 0
        I_bat = I2;
    else
        I_bat = 0;
    end
else
    % 充电：选负值解（电流流入电池为负）
    if I1 <= 0 && I2 <= 0
        I_bat = max(I1, I2);   % 取绝对值较小的
    elseif I1 <= 0
        I_bat = I1;
    elseif I2 <= 0
        I_bat = I2;
    else
        I_bat = 0;
    end
end

% 计算端电压
V_bat = OCV - R_int * I_bat;
V_bat = max(0, V_bat);

% SOC变化（安时积分法）
% dSOC/dt = -I / (3600 * Q)  [其中Q为容量Ah]
if I_bat >= 0
    % 放电
    dSOC = -I_bat * dt / (3600 * bat.capacity);
else
    % 充电（考虑充电效率）
    dSOC = -I_bat * bat.eta_charge * dt / (3600 * bat.capacity);
end

SOC_new = SOC + dSOC;

% SOC限幅保护
SOC_new = max(bat.SOC_min, min(bat.SOC_max, SOC_new));

end
