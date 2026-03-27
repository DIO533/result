function compare_strategies(results_NEDC, results_WLTC, strategy_names, save_dir)
% 策略对比分析 - 在两种工况下对比各策略性能
% Compare Strategies - Compare strategy performance under two driving cycles
%
% 输入:
%   results_NEDC   - NEDC工况仿真结果数组
%   results_WLTC   - WLTC工况仿真结果数组
%   strategy_names - 策略名称元胞数组
%   save_dir       - 保存目录

if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end

n_strat = length(strategy_names);
colors  = {'#1f77b4', '#d62728', '#2ca02c', '#9467bd', '#8c564b'};

fprintf('\n');
fprintf('============================================================\n');
fprintf('           策略对比分析结果汇总\n');
fprintf('============================================================\n');

%% 性能指标提取
metrics_nedc = extract_metrics(results_NEDC, n_strat);
metrics_wltc = extract_metrics(results_WLTC, n_strat);

%% 打印性能对比表
fprintf('\n%-20s | %-10s %-10s | %-10s %-10s\n', ...
    '策略', 'NEDC燃耗(L)', 'NEDC终SOC', 'WLTC燃耗(L)', 'WLTC终SOC');
fprintf('%s\n', repmat('-', 1, 70));
for i = 1:n_strat
    fprintf('%-20s | %10.3f %10.3f | %10.3f %10.3f\n', ...
        strategy_names{i}, ...
        metrics_nedc.fuel_L(i), metrics_nedc.soc_final(i), ...
        metrics_wltc.fuel_L(i), metrics_wltc.soc_final(i));
end
fprintf('%s\n\n', repmat('-', 1, 70));

%% 图1：两种工况下燃油消耗对比（分组柱状图）
fig1 = figure('Name', '两种工况燃油消耗对比', 'Position', [100, 100, 900, 600], 'Visible', 'off');
x = 1:n_strat;
bar_data = [metrics_nedc.fuel_L(:), metrics_wltc.fuel_L(:)];
b = bar(x, bar_data, 'grouped');
b(1).FaceColor = [0.2, 0.5, 0.9];
b(2).FaceColor = [0.9, 0.3, 0.2];
set(gca, 'XTick', x, 'XTickLabel', strategy_names, 'FontSize', 11);
ylabel('等效燃油消耗 [L/100km]', 'FontSize', 12);
title('两种工况下各策略等效燃油消耗对比', 'FontSize', 14);
legend({'NEDC工况', 'WLTC工况'}, 'FontSize', 11, 'Location', 'best');
% 添加数据标签
for i = 1:n_strat
    text(i - 0.15, metrics_nedc.fuel_L(i) + 0.02, ...
        sprintf('%.2f', metrics_nedc.fuel_L(i)), 'FontSize', 9, 'HorizontalAlignment', 'center');
    text(i + 0.15, metrics_wltc.fuel_L(i) + 0.02, ...
        sprintf('%.2f', metrics_wltc.fuel_L(i)), 'FontSize', 9, 'HorizontalAlignment', 'center');
end
grid on; box on;
save_figure(fig1, save_dir, 'compare_fuel_both_cycles');

%% 图2：两种工况下终态SOC对比
fig2 = figure('Name', '终态SOC对比', 'Position', [100, 100, 900, 600], 'Visible', 'off');
soc_data = [metrics_nedc.soc_final(:), metrics_wltc.soc_final(:)];
b2 = bar(x, soc_data, 'grouped');
b2(1).FaceColor = [0.2, 0.7, 0.4];
b2(2).FaceColor = [0.9, 0.6, 0.1];
set(gca, 'XTick', x, 'XTickLabel', strategy_names, 'FontSize', 11);
ylabel('终态SOC [-]', 'FontSize', 12);
title('两种工况下各策略终态SOC对比', 'FontSize', 14);
legend({'NEDC工况', 'WLTC工况'}, 'FontSize', 11, 'Location', 'best');
yline(0.6, 'k--', '目标SOC=0.6', 'FontSize', 10);
ylim([0.3, 0.9]);
grid on; box on;
save_figure(fig2, save_dir, 'compare_soc_both_cycles');

%% 图3：综合性能雷达图（两种工况均值）
fig3 = figure('Name', '综合性能对比雷达图', 'Position', [100, 100, 900, 800], 'Visible', 'off');
plot_combined_radar(metrics_nedc, metrics_wltc, strategy_names, n_strat);
save_figure(fig3, save_dir, 'compare_radar_combined');

%% 输出汇总数据到文件
summary_file = fullfile(save_dir, 'strategy_comparison_summary.txt');
fid = fopen(summary_file, 'w');
fprintf(fid, '策略对比分析汇总报告\n');
fprintf(fid, '生成时间: %s\n\n', datestr(now));
fprintf(fid, '%-20s | NEDC燃耗(L/100km) | WLTC燃耗(L/100km) | NEDC终SOC | WLTC终SOC\n', '策略名称');
fprintf(fid, '%s\n', repmat('-', 1, 85));
for i = 1:n_strat
    fprintf(fid, '%-20s | %17.3f | %17.3f | %9.3f | %9.3f\n', ...
        strategy_names{i}, ...
        metrics_nedc.fuel_L(i), metrics_wltc.fuel_L(i), ...
        metrics_nedc.soc_final(i), metrics_wltc.soc_final(i));
end
fclose(fid);
fprintf('[对比分析] 汇总报告已保存至: %s\n', summary_file);
end

%% 提取性能指标
function metrics = extract_metrics(results, n_strat)
metrics.fuel_L      = zeros(n_strat, 1);
metrics.soc_final   = zeros(n_strat, 1);
metrics.soc_dev     = zeros(n_strat, 1);
metrics.speed_err   = zeros(n_strat, 1);
metrics.elec_util   = zeros(n_strat, 1);
metrics.avg_eff     = zeros(n_strat, 1);

for i = 1:n_strat
    r = results(i);
    metrics.fuel_L(i)    = r.fuel_economy;       % L/100km
    metrics.soc_final(i) = r.SOC(end);
    metrics.soc_dev(i)   = abs(r.SOC(end) - 0.6);
    metrics.speed_err(i) = r.speed_error;
    metrics.elec_util(i) = r.elec_utilization;
    metrics.avg_eff(i)   = r.avg_efficiency;
end
end

%% 绘制综合雷达图
function plot_combined_radar(m1, m2, strategy_names, n_strat)
colors_list = {'b', 'r', 'g', 'm', 'k'};
n_dim = 5;
dim_names = {'燃油经济性', 'SOC维持性', '综合效率', '电能利用率', '速度跟随'};
theta = linspace(0, 2*pi, n_dim+1); theta(end) = [];

hold on; axis equal; axis off;
% 绘制参考网格
for rv = 0.2:0.2:1.0
    xc = rv*cos(theta); yc = rv*sin(theta);
    plot([xc, xc(1)], [yc, yc(1)], 'Color', [0.8 0.8 0.8], 'LineWidth', 0.5);
end
for d = 1:n_dim
    plot([0, cos(theta(d))], [0, sin(theta(d))], 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
    text(1.2*cos(theta(d)), 1.2*sin(theta(d)), dim_names{d}, ...
        'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
end

for i = 1:n_strat
    % NEDC和WLTC取均值计算综合得分
    fuel_avg = (m1.fuel_L(i)+m2.fuel_L(i))/2;
    fe_score  = max(0.05, min(0.99, 1 - (fuel_avg - 3) / (10 - 3)));
    soc_avg   = (m1.soc_dev(i)+m2.soc_dev(i))/2;
    soc_score = max(0.05, min(0.99, 1 - soc_avg / 0.3));
    eff_score = (m1.avg_eff(i)+m2.avg_eff(i))/2;
    eu_score  = (m1.elec_util(i)+m2.elec_util(i))/2;
    sp_score  = 1 - (m1.speed_err(i)+m2.speed_err(i))/2;
    sp_score  = max(0.05, min(0.99, sp_score));
    
    data = [fe_score, soc_score, eff_score, eu_score, sp_score];
    xd = data .* cos(theta); yd = data .* sin(theta);
    
    c = colors_list{i};
    fill([xd, xd(1)], [yd, yd(1)], c, 'FaceAlpha', 0.12, ...
        'EdgeColor', c, 'LineWidth', 2, 'DisplayName', strategy_names{i});
    plot([xd, xd(1)], [yd, yd(1)], [c, 'o-'], 'LineWidth', 2, 'MarkerSize', 6);
end
legend('Location', 'southoutside', 'Orientation', 'horizontal', 'FontSize', 11);
title('综合性能对比雷达图（NEDC+WLTC均值）', 'FontSize', 13);
end

%% 辅助函数
function save_figure(fig, save_dir, filename)
fig_path = fullfile(save_dir, filename);
saveas(fig, [fig_path, '.fig']);
saveas(fig, [fig_path, '.png']);
close(fig);
end
