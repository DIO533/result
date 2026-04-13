function single_factor_analysis(veh, eng, mot, bat, save_dir)
% 单因素变量法分析
% Single Factor Analysis - Study effects of key parameters on fuel economy
%
% 分析以下三个因素：
%   1. 电池初始SOC（SOC_init = 0.3, 0.4, 0.5, 0.6, 0.7, 0.8）
%   2. 电机功率比例因子（power_ratio = 0.5, 0.75, 1.0, 1.25, 1.5）
%   3. 发动机启停SOC阈值（soc_start = 0.3, 0.35, 0.4, 0.45, 0.5）
%
% 固定工况：NEDC，固定策略：ECMS（因其优化特性最能反映参数影响）

if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end

fprintf('\n============================================================\n');
fprintf('           单因素变量法分析\n');
fprintf('============================================================\n');

% 生成NEDC工况（固定工况）
[t_ref, v_ref] = generate_NEDC();

%% 因素1：电池初始SOC
fprintf('\n[单因素1] 分析电池初始SOC对燃油经济性的影响...\n');
SOC_init_list = [0.3, 0.4, 0.5, 0.6, 0.7, 0.8];
n1 = length(SOC_init_list);
fuel_vs_soc      = zeros(n1, 3);  % 3种策略
soc_final_vs_soc = zeros(n1, 3);

for k = 1:n1
    bat_k = bat;
    bat_k.SOC_init = SOC_init_list(k);
    
    for s_idx = 1:3
        res = run_single_simulation(veh, eng, mot, bat_k, t_ref, v_ref, s_idx);
        fuel_vs_soc(k, s_idx)      = res.fuel_economy;
        soc_final_vs_soc(k, s_idx) = res.SOC(end);
    end
    fprintf('  初始SOC=%.1f 完成\n', SOC_init_list(k));
end

%% 因素2：电机功率比例因子
fprintf('\n[单因素2] 分析电机功率比例因子对燃油经济性的影响...\n');
power_ratio_list = [0.5, 0.75, 1.0, 1.25, 1.5];
n2 = length(power_ratio_list);
fuel_vs_ratio = zeros(n2, 3);

for k = 1:n2
    mot_k = mot;
    mot_k.power_ratio = power_ratio_list(k);
    
    for s_idx = 1:3
        res = run_single_simulation(veh, eng, mot_k, bat, t_ref, v_ref, s_idx);
        fuel_vs_ratio(k, s_idx) = res.fuel_economy;
    end
    fprintf('  功率比例因子=%.2f 完成\n', power_ratio_list(k));
end

%% 因素3：发动机启停SOC阈值
fprintf('\n[单因素3] 分析发动机启停SOC阈值对系统效率的影响...\n');
soc_threshold_list = [0.30, 0.35, 0.40, 0.45, 0.50];
n3 = length(soc_threshold_list);
fuel_vs_th  = zeros(n3, 3);
eff_vs_th   = zeros(n3, 3);

for k = 1:n3
    eng_k = eng;
    eng_k.soc_start = soc_threshold_list(k);
    eng_k.soc_stop  = soc_threshold_list(k) + 0.30;  % 保持间隔
    
    for s_idx = 1:3
        res = run_single_simulation(veh, eng_k, mot, bat, t_ref, v_ref, s_idx);
        fuel_vs_th(k, s_idx) = res.fuel_economy;
        eff_vs_th(k, s_idx)  = res.avg_efficiency;
    end
    fprintf('  SOC阈值=%.2f 完成\n', soc_threshold_list(k));
end

%% 绘制单因素分析图表
strategy_names = {'基于规则策略', '模糊逻辑策略', 'ECMS策略'};
colors = {'b', 'r', 'g'};
markers_list = {'o-', 's--', '^-.'};

%--- 图A：初始SOC vs 总燃油消耗 ---
figA = figure('Name', '初始SOC对燃油经济性的影响', ...
    'Position', [100, 100, 900, 600], 'Visible', 'off');
hold on;
for s_idx = 1:3
    plot(SOC_init_list, fuel_vs_soc(:, s_idx), ...
        [colors{s_idx}, markers_list{s_idx}], 'LineWidth', 2, ...
        'MarkerSize', 8, 'DisplayName', strategy_names{s_idx});
end
xlabel('电池初始SOC [-]', 'FontSize', 12);
ylabel('燃油消耗 [L/100km]', 'FontSize', 12);
title('初始SOC对燃油经济性的影响（NEDC工况）', 'FontSize', 14);
legend('Location', 'best', 'FontSize', 11);
grid on; box on;
save_figure(figA, save_dir, 'single_factor_SOC_fuel');

%--- 图B：初始SOC vs 终态SOC（SOC维持能力）---
figB = figure('Name', '初始SOC对终态SOC的影响', ...
    'Position', [100, 100, 900, 600], 'Visible', 'off');
hold on;
for s_idx = 1:3
    plot(SOC_init_list, soc_final_vs_soc(:, s_idx), ...
        [colors{s_idx}, markers_list{s_idx}], 'LineWidth', 2, ...
        'MarkerSize', 8, 'DisplayName', strategy_names{s_idx});
end
plot(SOC_init_list, SOC_init_list, 'k:', 'LineWidth', 1.5, 'DisplayName', '初始=终态（参考线）');
xlabel('电池初始SOC [-]', 'FontSize', 12);
ylabel('终态SOC [-]', 'FontSize', 12);
title('初始SOC对SOC维持性的影响（NEDC工况）', 'FontSize', 14);
legend('Location', 'best', 'FontSize', 11);
grid on; box on;
save_figure(figB, save_dir, 'single_factor_SOC_final');

%--- 图C：电机功率比例因子 vs 燃油经济性 ---
figC = figure('Name', '电机功率比例因子对燃油经济性的影响', ...
    'Position', [100, 100, 900, 600], 'Visible', 'off');
hold on;
for s_idx = 1:3
    plot(power_ratio_list, fuel_vs_ratio(:, s_idx), ...
        [colors{s_idx}, markers_list{s_idx}], 'LineWidth', 2, ...
        'MarkerSize', 8, 'DisplayName', strategy_names{s_idx});
end
xlabel('电机功率比例因子 [-]', 'FontSize', 12);
ylabel('燃油消耗 [L/100km]', 'FontSize', 12);
title('电机功率比例因子对燃油经济性的影响（NEDC工况）', 'FontSize', 14);
legend('Location', 'best', 'FontSize', 11);
grid on; box on;
save_figure(figC, save_dir, 'single_factor_motor_ratio_fuel');

%--- 图D：SOC阈值 vs 系统综合效率 ---
figD = figure('Name', 'SOC阈值对系统效率的影响', ...
    'Position', [100, 100, 900, 600], 'Visible', 'off');
hold on;
for s_idx = 1:3
    plot(soc_threshold_list, eff_vs_th(:, s_idx), ...
        [colors{s_idx}, markers_list{s_idx}], 'LineWidth', 2, ...
        'MarkerSize', 8, 'DisplayName', strategy_names{s_idx});
end
xlabel('发动机启动SOC阈值 [-]', 'FontSize', 12);
ylabel('系统综合效率 [-]', 'FontSize', 12);
title('发动机启停SOC阈值对系统效率的影响（NEDC工况）', 'FontSize', 14);
legend('Location', 'best', 'FontSize', 11);
grid on; box on;
save_figure(figD, save_dir, 'single_factor_soc_threshold_eff');

fprintf('\n[单因素分析] 4张分析图表已保存至 %s\n', save_dir);
end

%% 运行单次仿真
function result = run_single_simulation(veh, eng, mot, bat, t_ref, v_ref, strategy_idx)
% 调用主仿真核心，返回结果

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'models'));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'strategies'));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'params'));

N  = length(t_ref);
dt = 1;  % 步长 1s

% 初始化状态变量
SOC       = bat.SOC_init * ones(N, 1);
v_actual  = zeros(N, 1);
fuel_rate_arr = zeros(N, 1);
T_eng_arr = zeros(N, 1);
T_mot_arr = zeros(N, 1);
eng_speed_arr = zeros(N, 1);
mot_speed_arr = zeros(N, 1);
eng_on_arr = zeros(N, 1);

v_actual(1) = v_ref(1);
SOC(1)      = bat.SOC_init;
eng_on_prev = 0;

for k = 1:N-1
    v_k = v_actual(k);
    v_next = v_ref(k+1);
    a_req  = (v_next - v_k) / dt;
    a_req  = max(-3.5, min(3.5, a_req));
    
    [eng_sp, mot_sp, gear, T_wheel] = transmission_model(veh, v_k, a_req);
    
    total_ratio = veh.gear_ratio(gear) * veh.final_ratio;
    T_shaft = T_wheel / (total_ratio * max(0.01, veh.trans_eff));
    T_shaft = max(-200, min(300, T_shaft));
    
    switch strategy_idx
        case 1
            [T_eng, T_mot, eng_on] = rule_based_strategy(eng, mot, bat, SOC(k), T_shaft, eng_sp, eng_on_prev);
        case 2
            [T_eng, T_mot, eng_on] = fuzzy_logic_strategy(eng, mot, bat, SOC(k), T_shaft, eng_sp, eng_on_prev);
        case 3
            [T_eng, T_mot, eng_on] = ecms_strategy(eng, mot, bat, SOC(k), T_shaft, eng_sp, eng_on_prev);
    end
    
    [fuel_rate, ~, T_eng] = engine_model(eng, eng_sp, T_eng);
    [P_elec, ~, T_mot]    = motor_model(mot, mot_sp, T_mot);
    [SOC_new, ~, ~]       = battery_model(bat, SOC(k), P_elec, dt);
    
    SOC(k+1)            = SOC_new;
    fuel_rate_arr(k)    = fuel_rate;
    T_eng_arr(k)        = T_eng;
    T_mot_arr(k)        = T_mot;
    eng_speed_arr(k)    = eng_sp;
    mot_speed_arr(k)    = mot_sp;
    eng_on_arr(k)       = eng_on;
    eng_on_prev         = eng_on;
    v_actual(k+1)       = v_next;
end

% 计算性能指标
total_fuel_g  = sum(fuel_rate_arr) * dt;
total_fuel_kg = total_fuel_g / 1000;

v_avg = mean(v_ref);
total_dist_km = sum(v_ref) * dt / 1000;
total_dist_km = max(0.1, total_dist_km);

fuel_density_kg_L = 0.750;
total_fuel_L = total_fuel_kg / fuel_density_kg_L;
fuel_economy = total_fuel_L / total_dist_km * 100;

regen_idx   = T_mot_arr < -1;
P_regen_arr = zeros(N, 1);
for k2 = 1:N
    if regen_idx(k2)
        [Pe, ~, ~] = motor_model(mot, mot_speed_arr(k2), T_mot_arr(k2));
        P_regen_arr(k2) = abs(Pe);
    end
end
total_P_demand = max(1, sum(abs(T_mot_arr .* mot_speed_arr * pi/30)));
elec_util = min(1, sum(P_regen_arr) / (total_P_demand + 1));

eng_on_ratio = mean(eng_on_arr);
avg_efficiency = 0.25 + 0.15 * eng_on_ratio + 0.1 * elec_util;
avg_efficiency = max(0.15, min(0.55, avg_efficiency));

speed_rmse = sqrt(mean((v_actual - v_ref).^2));
speed_error = min(1, speed_rmse / (max(v_ref) + 0.1));

result.t               = (0:N-1)';
result.v_ref           = v_ref;
result.v_actual        = v_actual;
result.SOC             = SOC;
result.fuel_rate        = fuel_rate_arr;
result.T_eng           = T_eng_arr;
result.T_mot           = T_mot_arr;
result.eng_speed       = eng_speed_arr;
result.mot_speed       = mot_speed_arr;
result.total_fuel      = total_fuel_g;
result.fuel_economy    = fuel_economy;
result.elec_utilization= elec_util;
result.avg_efficiency  = avg_efficiency;
result.speed_error     = speed_error;
end

%% 辅助函数
function save_figure(fig, save_dir, filename)
fig_path = fullfile(save_dir, filename);
saveas(fig, [fig_path, '.fig']);
saveas(fig, [fig_path, '.png']);
close(fig);
end
