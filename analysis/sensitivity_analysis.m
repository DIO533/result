function sensitivity_analysis(veh, eng, mot, bat, save_dir)
% 敏感性分析 - 各单因素对综合性能指标的影响程度对比
% Sensitivity Analysis - Impact degree of each factor on overall performance
%
% 采用单因素敏感性指数（SI）：
%   SI = (ΔOutput/Output_base) / (ΔInput/Input_base)
%   SI > 1: 高敏感；SI ≈ 1: 中敏感；SI < 1: 低敏感

if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end

fprintf('\n============================================================\n');
fprintf('           敏感性分析\n');
fprintf('============================================================\n');

% 生成NEDC工况
[t_ref, v_ref] = generate_NEDC();

% 基准仿真（初始SOC=0.6，功率比=1.0，SOC阈值=0.4）
res_base = run_sim(veh, eng, mot, bat, t_ref, v_ref, 3);  % ECMS策略
fuel_base = res_base.fuel_economy;
eff_base  = res_base.avg_efficiency;
fprintf('基准工况燃油经济性: %.3f L/100km\n', fuel_base);

%% 计算各因素的敏感性指数
% 扰动范围：±20%（相对基准值）
%% 可配置的灵敏度扰动百分比
perturbation_pct = 0.20;   % 20% 相对扰动，可修改此值调整敏感性分析范围

factors = {
    '初始SOC',          'bat.SOC_init',    bat.SOC_init,    perturbation_pct;
    '电机功率比例',      'mot.power_ratio', mot.power_ratio, perturbation_pct;
    '发动机启动阈值',    'eng.soc_start',   eng.soc_start,   perturbation_pct;
    '电池内阻',          'bat.R_int',       bat.R_int,       perturbation_pct;
    '整车质量',          'veh.mass',        veh.mass,        perturbation_pct;
};

n_factors = size(factors, 1);
SI_fuel = zeros(n_factors, 1);   % 燃油经济性敏感性指数
SI_eff  = zeros(n_factors, 1);   % 系统效率敏感性指数

for f = 1:n_factors
    fname     = factors{f, 1};
    fvar      = factors{f, 2};
    fbase_val = factors{f, 3};
    delta_pct = factors{f, 4};
    
    % 正向扰动：+20%
    delta = fbase_val * delta_pct;
    veh_f = veh; eng_f = eng; mot_f = mot; bat_f = bat;
    
    switch fvar
        case 'bat.SOC_init'
            bat_f.SOC_init = fbase_val + delta;
        case 'mot.power_ratio'
            mot_f.power_ratio = fbase_val + delta;
        case 'eng.soc_start'
            eng_f.soc_start = fbase_val + delta;
        case 'bat.R_int'
            bat_f.R_int = fbase_val + delta;
        case 'veh.mass'
            veh_f.mass = fbase_val + delta;
            veh_f.mass_total = veh_f.mass + veh_f.mass_rot;
    end
    
    res_p = run_sim(veh_f, eng_f, mot_f, bat_f, t_ref, v_ref, 3);
    
    % 负向扰动：-20%
    veh_f = veh; eng_f = eng; mot_f = mot; bat_f = bat;
    switch fvar
        case 'bat.SOC_init'
            bat_f.SOC_init = fbase_val - delta;
        case 'mot.power_ratio'
            mot_f.power_ratio = fbase_val - delta;
        case 'eng.soc_start'
            eng_f.soc_start = fbase_val - delta;
        case 'bat.R_int'
            bat_f.R_int = fbase_val - delta;
        case 'veh.mass'
            veh_f.mass = fbase_val - delta;
            veh_f.mass_total = veh_f.mass + veh_f.mass_rot;
    end
    
    res_n = run_sim(veh_f, eng_f, mot_f, bat_f, t_ref, v_ref, 3);
    
    % 计算敏感性指数（中心差分法）
    d_fuel = (res_p.fuel_economy - res_n.fuel_economy) / (2 * delta);
    d_eff  = (res_p.avg_efficiency - res_n.avg_efficiency) / (2 * delta);
    
    SI_fuel(f) = abs(d_fuel * fbase_val / (fuel_base + 1e-9));
    SI_eff(f)  = abs(d_eff  * fbase_val / (eff_base  + 1e-9));
    
    fprintf('  %s: SI_fuel=%.3f, SI_eff=%.3f\n', fname, SI_fuel(f), SI_eff(f));
end

%% 绘制敏感性分析柱状图
factor_labels = factors(:,1);

%--- 图1：各因素对燃油经济性的敏感性 ---
fig1 = figure('Name', '各因素对燃油经济性的敏感性', ...
    'Position', [100, 100, 900, 600], 'Visible', 'off');
[SI_sorted, idx_sort] = sort(SI_fuel, 'descend');
bar_h = barh(SI_sorted, 'FaceColor', 'flat');
for i = 1:n_factors
    if SI_sorted(i) > 1.0
        bar_h.CData(i,:) = [0.8, 0.1, 0.1];  % 红色：高敏感
    elseif SI_sorted(i) > 0.5
        bar_h.CData(i,:) = [0.9, 0.6, 0.1];  % 橙色：中敏感
    else
        bar_h.CData(i,:) = [0.2, 0.6, 0.9];  % 蓝色：低敏感
    end
end
set(gca, 'YTick', 1:n_factors, 'YTickLabel', factor_labels(idx_sort), 'FontSize', 11);
xlabel('敏感性指数 (SI)', 'FontSize', 12);
title('各参数对燃油经济性的敏感性分析', 'FontSize', 14);
xline(1.0, 'r--', '高敏感阈值', 'FontSize', 10);
xline(0.5, 'b--', '低敏感阈值', 'FontSize', 10);
% 添加数值标签
for i = 1:n_factors
    text(SI_sorted(i) + 0.01, i, sprintf('%.3f', SI_sorted(i)), ...
        'VerticalAlignment', 'middle', 'FontSize', 10);
end
grid on; box on;
save_figure(fig1, save_dir, 'sensitivity_fuel_economy');

%--- 图2：各因素对系统效率的敏感性 ---
fig2 = figure('Name', '各因素对系统效率的敏感性', ...
    'Position', [100, 100, 900, 600], 'Visible', 'off');
[SI_eff_sorted, idx_eff] = sort(SI_eff, 'descend');
bar_h2 = barh(SI_eff_sorted, 'FaceColor', 'flat');
for i = 1:n_factors
    if SI_eff_sorted(i) > 1.0
        bar_h2.CData(i,:) = [0.8, 0.1, 0.1];
    elseif SI_eff_sorted(i) > 0.5
        bar_h2.CData(i,:) = [0.9, 0.6, 0.1];
    else
        bar_h2.CData(i,:) = [0.2, 0.6, 0.9];
    end
end
set(gca, 'YTick', 1:n_factors, 'YTickLabel', factor_labels(idx_eff), 'FontSize', 11);
xlabel('敏感性指数 (SI)', 'FontSize', 12);
title('各参数对系统综合效率的敏感性分析', 'FontSize', 14);
xline(1.0, 'r--', '高敏感阈值', 'FontSize', 10);
xline(0.5, 'b--', '低敏感阈值', 'FontSize', 10);
for i = 1:n_factors
    text(SI_eff_sorted(i) + 0.005, i, sprintf('%.3f', SI_eff_sorted(i)), ...
        'VerticalAlignment', 'middle', 'FontSize', 10);
end
grid on; box on;
save_figure(fig2, save_dir, 'sensitivity_system_efficiency');

%--- 图3：综合敏感性对比（双指标水平条图）---
fig3 = figure('Name', '综合敏感性分析', ...
    'Position', [100, 100, 1000, 700], 'Visible', 'off');
x_pos = 1:n_factors;
bar_data = [SI_fuel(:), SI_eff(:)];
b3 = bar(x_pos, bar_data, 'grouped');
b3(1).FaceColor = [0.2, 0.5, 0.9];
b3(2).FaceColor = [0.9, 0.4, 0.2];
set(gca, 'XTick', x_pos, 'XTickLabel', factor_labels, ...
    'XTickLabelRotation', 20, 'FontSize', 11);
ylabel('敏感性指数 (SI)', 'FontSize', 12);
title('各关键参数综合敏感性分析（ECMS策略，NEDC工况）', 'FontSize', 14);
legend({'燃油经济性', '系统效率'}, 'FontSize', 11, 'Location', 'best');
yline(1.0, 'r--', '高敏感阈值', 'LineWidth', 1.2);
grid on; box on;
save_figure(fig3, save_dir, 'sensitivity_combined');

fprintf('\n[敏感性分析] 3张分析图表已保存至 %s\n', save_dir);
end

%% 运行单次仿真（简化版）
function result = run_sim(veh, eng, mot, bat, t_ref, v_ref, strategy_idx)
addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'models'));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'strategies'));

N  = length(t_ref);
dt = 1;

SOC       = bat.SOC_init * ones(N, 1);
v_actual  = v_ref;
fuel_rate_arr = zeros(N, 1);
T_mot_arr = zeros(N, 1);
mot_speed_arr = zeros(N, 1);
eng_on_arr = zeros(N, 1);
eng_on_prev = 0;

for k = 1:N-1
    v_k   = v_actual(k);
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
    
    [fuel_rate, ~, ~] = engine_model(eng, eng_sp, T_eng);
    [P_elec, ~, T_mot] = motor_model(mot, mot_sp, T_mot);
    [SOC_new, ~, ~]    = battery_model(bat, SOC(k), P_elec, dt);
    
    SOC(k+1)          = SOC_new;
    fuel_rate_arr(k)  = fuel_rate;
    T_mot_arr(k)      = T_mot;
    mot_speed_arr(k)  = mot_sp;
    eng_on_arr(k)     = eng_on;
    eng_on_prev       = eng_on;
end

total_fuel_kg = sum(fuel_rate_arr) * dt / 1000;
total_dist_km = max(0.1, sum(v_ref) * dt / 1000);
total_fuel_L  = total_fuel_kg / 0.750;
fuel_economy  = total_fuel_L / total_dist_km * 100;

regen_idx = T_mot_arr < -1;
P_regen = zeros(N, 1);
for k2 = 1:N
    if regen_idx(k2)
        [Pe, ~, ~] = motor_model(mot, mot_speed_arr(k2), T_mot_arr(k2));
        P_regen(k2) = abs(Pe);
    end
end
total_demand = max(1, sum(abs(T_mot_arr .* mot_speed_arr * pi/30)));
elec_util = min(1, sum(P_regen) / (total_demand + 1));
avg_efficiency = max(0.15, min(0.55, 0.25 + 0.15*mean(eng_on_arr) + 0.1*elec_util));

result.SOC           = SOC;
result.fuel_economy  = fuel_economy;
result.avg_efficiency = avg_efficiency;
result.elec_utilization = elec_util;
end

function save_figure(fig, save_dir, filename)
fig_path = fullfile(save_dir, filename);
saveas(fig, [fig_path, '.fig']);
saveas(fig, [fig_path, '.png']);
close(fig);
end
