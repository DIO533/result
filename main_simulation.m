%% main_simulation.m
% =====================================================================
% 并联式混合动力汽车（HEV）能量管理策略仿真系统
% =====================================================================
% 程序入口：运行本文件即可完成所有仿真并自动生成图表
%
% 仿真内容：
%   1. NEDC 工况下三种策略对比（Rule-Based / Fuzzy Logic / ECMS）
%   2. WLTC 工况下三种策略对比
%   3. 单因素变量法分析（初始SOC / 电机功率因子 / 启停SOC阈值）
%   4. 敏感性分析汇总图表
%
% 所有图表保存在 results/ 文件夹（.fig 和 .png 格式）
%
% 参考车型参数：丰田 Prius 级别并联 HEV
% =====================================================================

clear; clc; close all;
tic;

%% ====== 0. 路径设置 ======
script_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(script_dir, 'params'));
addpath(fullfile(script_dir, 'models'));
addpath(fullfile(script_dir, 'strategies'));
addpath(fullfile(script_dir, 'driving_cycles'));
addpath(fullfile(script_dir, 'analysis'));

results_dir = fullfile(script_dir, 'results');
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end

fprintf('============================================\n');
fprintf('  HEV 能量管理策略仿真系统\n');
fprintf('============================================\n');
fprintf('结果将保存至: %s\n\n', results_dir);

%% ====== 1. 加载仿真参数 ======
fprintf('>> 加载仿真参数...\n');
vp = vehicle_params();
ep = engine_params();
mp = motor_params();
bp = battery_params();

% 打包参数结构体（便于传递）
params.vp = vp;
params.ep = ep;
params.mp = mp;
params.bp = bp;

%% ====== 2. 生成工况数据 ======
fprintf('>> 生成标准工况数据...\n');

fprintf('   [1/2] 生成 NEDC 工况...\n');
[t_NEDC, v_NEDC] = generate_NEDC();
fprintf('   NEDC 工况：时长 %d s，最高车速 %.1f km/h\n', ...
    t_NEDC(end), max(v_NEDC) * 3.6);

fprintf('   [2/2] 生成 WLTC 工况...\n');
[t_WLTC, v_WLTC] = generate_WLTC();
fprintf('   WLTC 工况：时长 %d s，最高车速 %.1f km/h\n', ...
    t_WLTC(end), max(v_WLTC) * 3.6);

%% ====== 3. 策略对比仿真 ======
fprintf('\n>> 开始策略对比仿真...\n');

% --- NEDC 工况 ---
fprintf('\n=== NEDC 工况 ===\n');
results_NEDC = compare_strategies('NEDC', t_NEDC, v_NEDC, params);

% --- WLTC 工况 ---
fprintf('\n=== WLTC 工况 ===\n');
results_WLTC = compare_strategies('WLTC', t_WLTC, v_WLTC, params);

%% ====== 4. 输出性能汇总表 ======
fprintf('\n\n============================================\n');
fprintf('  仿真结果汇总\n');
fprintf('============================================\n');
for c = 1:2
    if c == 1
        res = results_NEDC; cname = 'NEDC';
    else
        res = results_WLTC; cname = 'WLTC';
    end
    fprintf('\n[%s 工况]\n', cname);
    fprintf('  %-20s  %10s  %12s  %12s\n', '策略', '总油耗(g)', '行驶里程(km)', '油耗(L/100km)');
    fprintf('  %s\n', repmat('-', 1, 60));
    for s = 1:3
        fprintf('  %-20s  %10.2f  %12.3f  %12.3f\n', ...
            res.strategy(s).name, ...
            res.strategy(s).total_fuel_g, ...
            res.strategy(s).distance_km, ...
            res.strategy(s).fuel_econ);
    end
end

%% ====== 5. 绘制策略对比图表 ======
fprintf('\n>> 绘制策略对比图表...\n');
plot_results(results_NEDC, results_dir);
plot_results(results_WLTC, results_dir);

%% ====== 6. 单因素变量分析（基于NEDC工况）======
fprintf('\n>> 运行单因素变量分析（工况：NEDC）...\n');
sfa_results = single_factor_analysis(t_NEDC, v_NEDC, params, results_dir);

%% ====== 7. 绘制单因素分析图表 ======
fprintf('\n>> 绘制单因素分析图表...\n');
plot_single_factor(sfa_results, results_dir);

%% ====== 8. 敏感性分析 ======
fprintf('\n>> 执行敏感性分析...\n');
sensitivity_analysis(sfa_results, results_dir);

%% ====== 9. 保存仿真数据 ======
fprintf('\n>> 保存仿真数据...\n');
save(fullfile(results_dir, 'simulation_data.mat'), ...
    'results_NEDC', 'results_WLTC', 'sfa_results', 'params');
fprintf('仿真数据已保存至: %s\n', fullfile(results_dir, 'simulation_data.mat'));

%% ====== 完成 ======
elapsed = toc;
fprintf('\n============================================\n');
fprintf('  仿真完成！总耗时: %.1f 秒\n', elapsed);
fprintf('  图表已保存至: %s\n', results_dir);
fprintf('============================================\n');
