function [T_eng, T_mot, eng_on] = ecms_strategy(eng, mot, bat, SOC, T_demand, eng_speed, eng_on_prev)
% 等效燃油消耗最小策略（ECMS）
% Equivalent Consumption Minimization Strategy
%
% 原理：将电能消耗等效折算为燃油消耗，找到使总等效燃油消耗最小的功率分配点
%
% 等效燃油消耗：H_eq = H_fuel + s * H_elec
%   H_fuel - 发动机即时燃油消耗 [g/s]
%   H_elec - 电池电能消耗折算为等效燃油 [g/s]
%   s      - 等效因子（penalization factor）
%
% 输入:
%   eng        - 发动机参数
%   mot        - 电机参数
%   bat        - 电池参数
%   SOC        - 当前SOC [-]
%   T_demand   - 折算到发动机轴的需求扭矩 [N·m]
%   eng_speed  - 发动机/电机转速 [rpm]
%   eng_on_prev- 上一步发动机状态
%
% 输出:
%   T_eng  - 发动机扭矩指令 [N·m]
%   T_mot  - 电机扭矩指令 [N·m]
%   eng_on - 发动机工作状态

%% 制动处理
if T_demand < 0
    eng_on = 0;
    T_eng  = 0;
    T_mot  = max(-mot.regen_T_max, T_demand);
    return;
end

%% SOC自适应等效因子
% s随SOC变化自适应调整：SOC低时增大s（减少用电），SOC高时减小s（鼓励用电）
s_base = bat.s_factor;           % 基准等效因子（默认2.8）
s = s_base + 1.5 * (bat.SOC_ref - SOC);   % SOC偏差修正
s = max(1.5, min(4.5, s));       % 限制在合理范围

%% ECMS折算效率参数（将电能等效为燃油消耗）
eta_bat_charge  = 0.95;          % 电池充放电综合效率（能量循环效率）
eta_eng_avg     = 0.33;          % 发动机平均热效率，用于电能→燃油折算
% 等效公式：放电时 H_elec = s * P_elec / (eta_bat * eta_eng * LHV)
%           充电时 H_elec = s * P_elec * eta_bat * eta_eng / LHV

%% 计算角速度
omega = max(eng_speed, 100) * pi / 30;   % [rad/s]

%% 搜索最优分配点
% 候选发动机扭矩范围（离散搜索）
T_mot_max = mot.T_max * mot.power_ratio;
T_eng_candidates = 0 : 5 : eng.T_max;    % 5 N·m步长
n_cand = length(T_eng_candidates);

H_eq_min  = inf;
T_eng_best = 0;
T_mot_best = min(T_demand, T_mot_max);

for k = 1:n_cand
    T_e = T_eng_candidates(k);
    T_m = T_demand - T_e;
    
    % 约束检查：电机扭矩不超限
    if T_m > T_mot_max || T_m < -T_mot_max
        continue;
    end
    
    % 1. 计算发动机即时燃油消耗 [g/s]
    if T_e > 0
        [h_fuel, ~, T_e_actual] = engine_model(eng, eng_speed, T_e);
        T_e = T_e_actual;   % 使用实际限幅后的扭矩
        T_m = T_demand - T_e;
    else
        h_fuel = 0;
    end
    
    % 2. 计算电机电功率 [W]
    [P_elec, ~, ~] = motor_model(mot, eng_speed, T_m);
    
    % 3. 将电功率折算为等效燃油消耗 [g/s]（使用上方已定义的折算参数）
    LHV = eng.fuel_lhv;       % 燃油低热值 [J/kg] = 44e6 J/kg
    
    % 等效燃油消耗率 [g/s]
    % 放电时：电能来自之前存储，折算消耗 = P_elec / (eta_bat * eta_eng * LHV)
    % 充电时：发电存储，折算收益 = P_elec * eta_bat * eta_eng / LHV
    if P_elec >= 0
        % 耗电（驱动）
        h_elec_equiv = s * P_elec / (eta_bat_charge * eta_eng_avg * LHV) * 1000;  % g/s
    else
        % 发电/回收（充电，P_elec为负值）
        h_elec_equiv = s * P_elec * eta_bat_charge * eta_eng_avg / LHV * 1000;    % g/s（负值=节省）
    end
    
    % 4. 总等效燃油消耗
    H_eq = h_fuel + h_elec_equiv;
    
    % 5. 找最小值
    if H_eq < H_eq_min
        H_eq_min   = H_eq;
        T_eng_best = T_e;
        T_mot_best = T_m;
    end
end

%% 输出最优控制量
T_eng = max(0, T_eng_best);
T_mot = max(-T_mot_max, min(T_mot_max, T_mot_best));
eng_on = (T_eng > 1);

%% 极低速或停车时纯电动
if eng_speed < 800
    eng_on = 0;
    T_eng  = 0;
    T_mot  = min(T_demand, T_mot_max);
end

end
