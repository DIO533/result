function results = compare_strategies(cycle_name, t, v_ref, params)
% 在指定工况下运行三种能量管理策略，记录仿真数据
%
% 输入:
%   cycle_name - 工况名称字符串（'NEDC' 或 'WLTC'）
%   t          - 时间向量 [s]
%   v_ref      - 参考速度向量 [m/s]
%   params     - 包含 vp/ep/mp/bp 的参数结构体
%
% 输出:
%   results - 包含各策略仿真结果的结构体

vp = params.vp;
ep = params.ep;
mp = params.mp;
bp = params.bp;

strategy_names = {'Rule-Based', 'Fuzzy Logic', 'ECMS'};
N = length(t);
dt = 1;  % 时间步长 1s

results.cycle_name    = cycle_name;
results.t             = t;
results.v_ref         = v_ref;
results.strategy_names = strategy_names;

for s_idx = 1:3
    fprintf('  [%s] 正在运行策略: %s ...\n', cycle_name, strategy_names{s_idx});

    % 初始化状态向量
    v_sim     = zeros(N, 1);    % 实际车速 [m/s]
    SOC       = zeros(N, 1);    % 电池SOC
    fuel_rate = zeros(N, 1);    % 瞬时油耗率 [g/s]
    T_eng_arr = zeros(N, 1);    % 发动机转矩 [N·m]
    T_mot_arr = zeros(N, 1);    % 电机转矩 [N·m]
    n_eng_arr = zeros(N, 1);    % 发动机转速 [rpm]
    n_mot_arr = zeros(N, 1);    % 电机转速 [rpm]
    P_eng_arr = zeros(N, 1);    % 发动机功率 [W]
    P_mot_arr = zeros(N, 1);    % 电机功率 [W]
    eng_on_arr= false(N, 1);    % 发动机启停状态

    % 初始条件
    v_sim(1)  = v_ref(1);
    SOC(1)    = bp.SOC_init;

    for k = 1:N-1
        v_k   = v_sim(k);
        SOC_k = SOC(k);
        v_tgt = v_ref(k+1);

        % 1. 整车动力学：计算需求功率
        [~, P_demand, ~] = vehicle_dynamics(v_k, v_tgt, dt, vp);

        % 2. 能量管理策略：分配功率
        switch s_idx
            case 1
                [T_e, T_m, eng_on] = rule_based_strategy(P_demand, SOC_k, v_k, ep, mp, bp);
            case 2
                [T_e, T_m, eng_on] = fuzzy_logic_strategy(P_demand, SOC_k, v_k, ep, mp, bp);
            case 3
                [T_e, T_m, eng_on] = ecms_strategy(P_demand, SOC_k, v_k, ep, mp, bp);
        end

        % 3. 发动机模型：计算油耗
        if eng_on && T_e > 0
            % 简化发动机转速估算（根据车速和传动比）
            omega_w = v_k / vp.r_wheel + 0.1;
            n_e = omega_w * 30 / pi * vp.i_final * 2.0;  % 约2500rpm区间
            n_e = max(min(n_e, ep.n_max), ep.n_idle);
            [mf, ~, ~] = engine_model(T_e, n_e, ep);
        else
            T_e   = 0;
            n_e   = 0;
            mf    = 0;
            eng_on = false;
        end

        % 4. 电机模型：计算电功率
        omega_w = max(v_k / vp.r_wheel, 0.1);
        n_m = omega_w * 30 / pi;   % 电机直接连接车轮（简化）
        n_m = min(n_m, mp.n_max);
        [P_elec, ~] = motor_model(T_m, n_m, mp);

        % 5. 电池模型：更新SOC
        [SOC_new, ~, ~] = battery_model(SOC_k, P_elec, dt, bp);

        % 6. 更新车速（简化：一阶跟随，考虑实际可用功率）
        v_new = v_k + (v_tgt - v_k) * 0.9;   % 90% 跟随率（简化）
        v_new = max(v_new, 0);

        % 存储
        v_sim(k+1)      = v_new;
        SOC(k+1)        = SOC_new;
        fuel_rate(k+1)  = mf;
        T_eng_arr(k+1)  = T_e;
        T_mot_arr(k+1)  = T_m;
        n_eng_arr(k+1)  = n_e;
        n_mot_arr(k+1)  = n_m;
        P_eng_arr(k+1)  = T_e * n_e * pi / 30;
        P_mot_arr(k+1)  = T_m * n_m * pi / 30;
        eng_on_arr(k+1) = eng_on;
    end

    % 计算总油耗
    total_fuel_g  = sum(fuel_rate) * dt;          % [g]
    total_fuel_L  = total_fuel_g / 750;           % [L]（汽油密度750g/L）
    distance_km   = trapz(t, v_sim) / 1000;       % [km]
    fuel_econ     = total_fuel_L / max(distance_km, 0.1) * 100;  % [L/100km]

    % 保存结果
    results.strategy(s_idx).name        = strategy_names{s_idx};
    results.strategy(s_idx).v_sim       = v_sim;
    results.strategy(s_idx).SOC         = SOC;
    results.strategy(s_idx).fuel_rate   = fuel_rate;
    results.strategy(s_idx).T_eng       = T_eng_arr;
    results.strategy(s_idx).T_mot       = T_mot_arr;
    results.strategy(s_idx).n_eng       = n_eng_arr;
    results.strategy(s_idx).n_mot       = n_mot_arr;
    results.strategy(s_idx).P_eng       = P_eng_arr;
    results.strategy(s_idx).P_mot       = P_mot_arr;
    results.strategy(s_idx).eng_on      = eng_on_arr;
    results.strategy(s_idx).total_fuel_g = total_fuel_g;
    results.strategy(s_idx).total_fuel_L = total_fuel_L;
    results.strategy(s_idx).distance_km  = distance_km;
    results.strategy(s_idx).fuel_econ    = fuel_econ;

    fprintf('    完成！总油耗: %.2f g，行驶里程: %.2f km，油耗率: %.2f L/100km\n', ...
        total_fuel_g, distance_km, fuel_econ);
end

end
