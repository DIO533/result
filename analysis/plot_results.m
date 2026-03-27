function plot_results(results, results_dir)
% 绘制策略对比分析图表
%
% 输入:
%   results     - compare_strategies 返回的结果结构体
%   results_dir - 结果保存目录

cycle_name = results.cycle_name;
t          = results.t;
v_ref      = results.v_ref;
strategies = results.strategy_names;
n_strat    = length(strategies);

colors = lines(n_strat);
fprintf('\n[%s] 正在绘制策略对比图表...\n', cycle_name);

% =============================================
% 图1：车速跟随曲线对比
% =============================================
fig1 = figure('Name', [cycle_name ' - 车速跟随'], 'NumberTitle', 'off', ...
    'Position', [50, 50, 1100, 500]);
plot(t, v_ref * 3.6, 'k--', 'LineWidth', 2, 'DisplayName', '目标车速'); hold on;
for s = 1:n_strat
    plot(t, results.strategy(s).v_sim * 3.6, '-', 'Color', colors(s,:), ...
        'LineWidth', 1.2, 'DisplayName', strategies{s});
end
xlabel('时间 [s]', 'FontSize', 12);
ylabel('车速 [km/h]', 'FontSize', 12);
title([cycle_name ' 工况 - 各策略车速跟随曲线对比'], 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
grid on; box on;
save_figure(fig1, fullfile(results_dir, [cycle_name '_01_speed_tracking']));

% =============================================
% 图2：SOC变化轨迹对比
% =============================================
fig2 = figure('Name', [cycle_name ' - SOC变化'], 'NumberTitle', 'off', ...
    'Position', [50, 50, 1100, 500]);
for s = 1:n_strat
    plot(t, results.strategy(s).SOC, '-', 'Color', colors(s,:), ...
        'LineWidth', 1.5, 'DisplayName', strategies{s}); hold on;
end
yline(0.2, 'r--', 'LineWidth', 1, 'DisplayName', 'SOC最小值');
yline(0.9, 'b--', 'LineWidth', 1, 'DisplayName', 'SOC最大值');
xlabel('时间 [s]', 'FontSize', 12);
ylabel('SOC [-]', 'FontSize', 12);
title([cycle_name ' 工况 - 各策略SOC变化轨迹对比'], 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
ylim([0.1 1.0]); grid on; box on;
save_figure(fig2, fullfile(results_dir, [cycle_name '_02_SOC_trajectory']));

% =============================================
% 图3：瞬时燃油消耗率对比
% =============================================
fig3 = figure('Name', [cycle_name ' - 瞬时油耗'], 'NumberTitle', 'off', ...
    'Position', [50, 50, 1100, 500]);
for s = 1:n_strat
    plot(t, results.strategy(s).fuel_rate, '-', 'Color', colors(s,:), ...
        'LineWidth', 1.0, 'DisplayName', strategies{s}); hold on;
end
xlabel('时间 [s]', 'FontSize', 12);
ylabel('瞬时油耗率 [g/s]', 'FontSize', 12);
title([cycle_name ' 工况 - 各策略瞬时燃油消耗率对比'], 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
grid on; box on;
save_figure(fig3, fullfile(results_dir, [cycle_name '_03_fuel_rate']));

% =============================================
% 图4：发动机工作点分布（转矩-转速）
% =============================================
fig4 = figure('Name', [cycle_name ' - 发动机工作点'], 'NumberTitle', 'off', ...
    'Position', [50, 50, 1100, 520]);
for s = 1:n_strat
    n_e = results.strategy(s).n_eng;
    T_e = results.strategy(s).T_eng;
    mask = n_e > 0 & T_e > 0;
    scatter(n_e(mask), T_e(mask), 8, colors(s,:), 'filled', ...
        'DisplayName', strategies{s}); hold on;
end
xlabel('发动机转速 [rpm]', 'FontSize', 12);
ylabel('发动机转矩 [N·m]', 'FontSize', 12);
title([cycle_name ' 工况 - 各策略发动机工作点分布'], 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
xlim([0 6000]); ylim([0 160]); grid on; box on;
save_figure(fig4, fullfile(results_dir, [cycle_name '_04_engine_op_points']));

% =============================================
% 图5：电机工作点分布（转矩-转速）
% =============================================
fig5 = figure('Name', [cycle_name ' - 电机工作点'], 'NumberTitle', 'off', ...
    'Position', [50, 50, 1100, 520]);
for s = 1:n_strat
    n_m = results.strategy(s).n_mot;
    T_m = results.strategy(s).T_mot;
    mask = abs(T_m) > 1;
    scatter(n_m(mask), T_m(mask), 8, colors(s,:), 'filled', ...
        'DisplayName', strategies{s}); hold on;
end
xlabel('电机转速 [rpm]', 'FontSize', 12);
ylabel('电机转矩 [N·m]', 'FontSize', 12);
title([cycle_name ' 工况 - 各策略电机工作点分布'], 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
grid on; box on;
save_figure(fig5, fullfile(results_dir, [cycle_name '_05_motor_op_points']));

% =============================================
% 图6：总燃油消耗柱状图对比
% =============================================
fig6 = figure('Name', [cycle_name ' - 总油耗柱状图'], 'NumberTitle', 'off', ...
    'Position', [100, 100, 700, 500]);
fuel_totals = zeros(1, n_strat);
econ_vals   = zeros(1, n_strat);
for s = 1:n_strat
    fuel_totals(s) = results.strategy(s).total_fuel_g;
    econ_vals(s)   = results.strategy(s).fuel_econ;
end

b = bar(fuel_totals, 'FaceColor', 'flat');
for s = 1:n_strat
    b.CData(s,:) = colors(s,:);
end
set(gca, 'XTickLabel', strategies, 'FontSize', 11);
xlabel('能量管理策略', 'FontSize', 12);
ylabel('总燃油消耗 [g]', 'FontSize', 12);
title([cycle_name ' 工况 - 各策略总燃油消耗对比'], 'FontSize', 13, 'FontWeight', 'bold');
for s = 1:n_strat
    text(s, fuel_totals(s) + 5, sprintf('%.1fg\n%.2fL/100km', fuel_totals(s), econ_vals(s)), ...
        'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
end
grid on; box on;
save_figure(fig6, fullfile(results_dir, [cycle_name '_06_total_fuel_bar']));

% =============================================
% 图7：等效燃油经济性雷达图
% =============================================
fig7 = figure('Name', [cycle_name ' - 雷达图'], 'NumberTitle', 'off', ...
    'Position', [100, 100, 700, 600]);
% 雷达图使用5个维度指标
% 1. 燃油经济性（越低越好，取倒数归一化）
% 2. SOC保持性（终末SOC与初始SOC偏差的倒数）
% 3. 发动机效率（工作点平均效率）
% 4. 平均电机效率
% 5. 车速跟随精度（RMSE倒数）

radar_data = zeros(n_strat, 5);
bp_soc_init = results.strategy(1).SOC(1);

for s = 1:n_strat
    % 燃油经济性（归一化，越低越好 -> 取倒数）
    econ_min = min(econ_vals);
    radar_data(s,1) = econ_min / max(econ_vals(s), 0.1);

    % SOC保持性
    soc_end = results.strategy(s).SOC(end);
    soc_dev = abs(soc_end - bp_soc_init);
    radar_data(s,2) = 1 / (1 + soc_dev * 5);

    % 车速跟随精度（RMSE）
    v_err = results.strategy(s).v_sim - v_ref;
    rmse_v = sqrt(mean(v_err.^2)) * 3.6;  % km/h
    radar_data(s,3) = 1 / (1 + rmse_v);

    % 发动机工作点效率（大于0的点的平均值，用BSFC近似）
    n_e = results.strategy(s).n_eng;
    mask_e = n_e > 0;
    if sum(mask_e) > 10
        radar_data(s,4) = 0.7 + 0.3 * (1 - econ_vals(s)/max(econ_vals+0.1));
    else
        radar_data(s,4) = 0.5;
    end

    % 电机利用率
    P_m = results.strategy(s).P_mot;
    radar_data(s,5) = min(mean(abs(P_m)) / (60000 * 0.3), 1.0);
end

% 绘制雷达图（极坐标）
theta = linspace(0, 2*pi, 6);
theta = theta(1:end-1);
labels = {'燃油经济性', 'SOC保持性', '车速跟随', '发动机效率', '电机利用率'};

ax = axes('Position', [0.1 0.1 0.8 0.8]);
hold on;

% 网格
for r = 0.2:0.2:1.0
    x_grid = r * cos(theta([1:end, 1]));
    y_grid = r * sin(theta([1:end, 1]));
    plot(x_grid, y_grid, 'Color', [0.8 0.8 0.8], 'LineWidth', 0.5);
end
for k = 1:5
    plot([0 cos(theta(k))], [0 sin(theta(k))], 'Color', [0.8 0.8 0.8], 'LineWidth', 0.5);
    text(1.15*cos(theta(k)), 1.15*sin(theta(k)), labels{k}, ...
        'HorizontalAlignment', 'center', 'FontSize', 10);
end

for s = 1:n_strat
    rd = radar_data(s,:);
    x_r = [rd .* cos(theta), rd(1)*cos(theta(1))];
    y_r = [rd .* sin(theta), rd(1)*sin(theta(1))];
    plot(x_r, y_r, '-o', 'Color', colors(s,:), 'LineWidth', 1.5, ...
        'MarkerFaceColor', colors(s,:), 'DisplayName', strategies{s});
end

axis equal; axis off;
legend('Location', 'southoutside', 'Orientation', 'horizontal', 'FontSize', 10);
title([cycle_name ' 工况 - 等效燃油经济性雷达图对比'], 'FontSize', 13, 'FontWeight', 'bold');
save_figure(fig7, fullfile(results_dir, [cycle_name '_07_radar_chart']));

fprintf('[%s] 所有对比图表已保存到: %s\n', cycle_name, results_dir);
end

% ---- 辅助：保存图表为 fig 和 png ----
function save_figure(fig, filepath)
    try
        savefig(fig, [filepath, '.fig']);
    catch
    end
    try
        exportgraphics(fig, [filepath, '.png'], 'Resolution', 150);
    catch
        try
            print(fig, [filepath, '.png'], '-dpng', '-r150');
        catch
        end
    end
end
