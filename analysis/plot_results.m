function plot_results(results, cycle_name, strategy_names, save_dir)
% 图表绘制函数 - 生成所有对比分析图表
% Plot Results - Generate all comparison analysis charts
%
% 输入:
%   results        - 仿真结果结构体数组（每个元素对应一种策略）
%   cycle_name     - 工况名称（'NEDC' 或 'WLTC'）
%   strategy_names - 策略名称元胞数组
%   save_dir       - 图表保存目录

n_strat = length(results);
colors  = {'b', 'r', 'g', 'm', 'k'};
markers = {'-', '--', '-.', ':', '-.'};

if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end

%% 图1：车速跟随曲线对比
fig1 = figure('Name', sprintf('%s - 车速跟随曲线', cycle_name), ...
    'Position', [50, 50, 1200, 500], 'Visible', 'off');
hold on;
% 绘制目标工况（使用第一个结果的参考速度）
plot(results(1).t, results(1).v_ref * 3.6, 'k-', 'LineWidth', 2.5, 'DisplayName', '目标车速');
for i = 1:n_strat
    plot(results(i).t, results(i).v_actual * 3.6, ...
        [colors{i}, markers{i}], 'LineWidth', 1.2, 'DisplayName', strategy_names{i});
end
xlabel('时间 [s]', 'FontSize', 12);
ylabel('车速 [km/h]', 'FontSize', 12);
title(sprintf('%s工况 - 各策略车速跟随曲线对比', cycle_name), 'FontSize', 14);
legend('Location', 'best', 'FontSize', 10);
grid on; box on;
save_figure(fig1, save_dir, sprintf('%s_speed_tracking', cycle_name));

%% 图2：SOC变化轨迹对比
fig2 = figure('Name', sprintf('%s - SOC变化轨迹', cycle_name), ...
    'Position', [50, 50, 1200, 500], 'Visible', 'off');
hold on;
for i = 1:n_strat
    plot(results(i).t, results(i).SOC, ...
        [colors{i}, markers{i}], 'LineWidth', 1.5, 'DisplayName', strategy_names{i});
end
yline(0.2, 'r--', 'SOC下限 0.2', 'LineWidth', 1);
yline(0.9, 'r--', 'SOC上限 0.9', 'LineWidth', 1);
xlabel('时间 [s]', 'FontSize', 12);
ylabel('SOC [-]', 'FontSize', 12);
title(sprintf('%s工况 - 各策略SOC变化轨迹对比', cycle_name), 'FontSize', 14);
legend('Location', 'best', 'FontSize', 10);
ylim([0.15, 0.95]);
grid on; box on;
save_figure(fig2, save_dir, sprintf('%s_SOC_trajectory', cycle_name));

%% 图3：发动机工作点分布图（转速-扭矩图）
fig3 = figure('Name', sprintf('%s - 发动机工作点', cycle_name), ...
    'Position', [50, 50, 1000, 700], 'Visible', 'off');
hold on;
for i = 1:n_strat
    % 只绘制发动机工作时的点
    idx = results(i).T_eng > 2;
    if any(idx)
        scatter(results(i).eng_speed(idx), results(i).T_eng(idx), ...
            8, colors{i}, 'filled', 'DisplayName', strategy_names{i}, ...
            'MarkerFaceAlpha', 0.5);
    end
end
% 绘制最大扭矩曲线
eng = engine_params();
plot(eng.speed_map, eng.T_max_curve, 'k-', 'LineWidth', 2, 'DisplayName', '最大扭矩曲线');
xlabel('发动机转速 [rpm]', 'FontSize', 12);
ylabel('发动机扭矩 [N·m]', 'FontSize', 12);
title(sprintf('%s工况 - 各策略发动机工作点分布', cycle_name), 'FontSize', 14);
legend('Location', 'best', 'FontSize', 10);
xlim([500, 6000]);  ylim([0, 130]);
grid on; box on;
save_figure(fig3, save_dir, sprintf('%s_engine_op_points', cycle_name));

%% 图4：电机工作点分布图
fig4 = figure('Name', sprintf('%s - 电机工作点', cycle_name), ...
    'Position', [50, 50, 1000, 700], 'Visible', 'off');
hold on;
for i = 1:n_strat
    idx = abs(results(i).T_mot) > 1;
    if any(idx)
        scatter(results(i).mot_speed(idx), results(i).T_mot(idx), ...
            8, colors{i}, 'filled', 'DisplayName', strategy_names{i}, ...
            'MarkerFaceAlpha', 0.5);
    end
end
xlabel('电机转速 [rpm]', 'FontSize', 12);
ylabel('电机扭矩 [N·m]', 'FontSize', 12);
title(sprintf('%s工况 - 各策略电机工作点分布', cycle_name), 'FontSize', 14);
legend('Location', 'best', 'FontSize', 10);
yline(0, 'k--', 'LineWidth', 1);
grid on; box on;
save_figure(fig4, save_dir, sprintf('%s_motor_op_points', cycle_name));

%% 图5：瞬时燃油消耗率对比
fig5 = figure('Name', sprintf('%s - 瞬时燃油消耗率', cycle_name), ...
    'Position', [50, 50, 1200, 500], 'Visible', 'off');
hold on;
for i = 1:n_strat
    plot(results(i).t, results(i).fuel_rate * 3600, ...  % 转换为 g/h 显示
        [colors{i}, markers{i}], 'LineWidth', 1.0, 'DisplayName', strategy_names{i});
end
xlabel('时间 [s]', 'FontSize', 12);
ylabel('瞬时燃油消耗率 [g/h]', 'FontSize', 12);
title(sprintf('%s工况 - 各策略瞬时燃油消耗率对比', cycle_name), 'FontSize', 14);
legend('Location', 'best', 'FontSize', 10);
grid on; box on;
save_figure(fig5, save_dir, sprintf('%s_instant_fuel', cycle_name));

%% 图6：总燃油消耗柱状图
fig6 = figure('Name', sprintf('%s - 总燃油消耗对比', cycle_name), ...
    'Position', [50, 50, 800, 600], 'Visible', 'off');
fuel_totals = zeros(n_strat, 1);
for i = 1:n_strat
    fuel_totals(i) = results(i).total_fuel;  % [g]
end
bar_h = bar(fuel_totals / 1000, 0.6);  % 转为 kg
% 设置各柱颜色
color_map_str = {'b', 'r', 'g', 'm', 'k'};
color_map_rgb = {[0.0,0.4,0.8],[0.8,0.1,0.1],[0.0,0.6,0.2],[0.7,0.0,0.7],[0.2,0.2,0.2]};
% 使用循环设置各柱颜色（兼容性做法）
bar_h.FaceColor = 'flat';
for i = 1:n_strat
    bar_h.CData(i,:) = color_map_rgb{min(i, length(color_map_rgb))};
end
set(gca, 'XTickLabel', strategy_names, 'XTickLabelRotation', 15, 'FontSize', 11);
ylabel('总燃油消耗 [kg]', 'FontSize', 12);
title(sprintf('%s工况 - 各策略总燃油消耗对比', cycle_name), 'FontSize', 14);
for i = 1:n_strat
    text(i, fuel_totals(i)/1000 + 0.005, sprintf('%.3f', fuel_totals(i)/1000), ...
        'HorizontalAlignment', 'center', 'FontSize', 10);
end
grid on; box on;
save_figure(fig6, save_dir, sprintf('%s_total_fuel_bar', cycle_name));

%% 图7：等效燃油经济性雷达图
fig7 = figure('Name', sprintf('%s - 综合性能雷达图', cycle_name), ...
    'Position', [50, 50, 800, 700], 'Visible', 'off');
% 评价维度：燃油经济性、SOC维持、速度跟随精度、排放（用燃耗替代）、电能利用率
n_dim = 5;
dim_names = {'燃油经济性', 'SOC维持', '速度跟随', '综合效率', '电能利用率'};
theta = linspace(0, 2*pi, n_dim+1);
theta(end) = [];

radar_data = zeros(n_strat, n_dim);
for i = 1:n_strat
    r = results(i);
    % 燃油经济性归一化（假设合理范围 3~10 L/100km；超出范围将被clip到[0.1, 1]）
    fuel_lo = 3; fuel_hi = 10;
    fe = 1 - (r.fuel_economy - fuel_lo) / (fuel_hi - fuel_lo);
    fe = max(0.1, min(1, fe));
    % SOC维持：与目标值0.6的偏差
    soc_dev = 1 - abs(r.SOC(end) - 0.6) / 0.4;
    soc_dev = max(0.1, min(1, soc_dev));
    % 速度跟随精度
    spd_err = 1 - r.speed_error;
    spd_err = max(0.1, min(1, spd_err));
    % 综合效率（发动机+电机平均效率）
    eff = r.avg_efficiency;
    eff = max(0.1, min(1, eff));
    % 电能利用率
    elec_util = r.elec_utilization;
    elec_util = max(0.1, min(1, elec_util));
    
    radar_data(i,:) = [fe, soc_dev, spd_err, eff, elec_util];
end

ax_radar = axes();
hold on;
% 绘制参考圆
for r_val = 0.2:0.2:1.0
    x_circ = r_val * cos(theta);
    y_circ = r_val * sin(theta);
    plot([x_circ, x_circ(1)], [y_circ, y_circ(1)], 'k:', 'LineWidth', 0.5);
end
% 绘制轴线
for d = 1:n_dim
    plot([0, cos(theta(d))], [0, sin(theta(d))], 'k-', 'LineWidth', 0.5);
    text(1.15*cos(theta(d)), 1.15*sin(theta(d)), dim_names{d}, ...
        'HorizontalAlignment', 'center', 'FontSize', 10);
end
% 绘制各策略数据
for i = 1:n_strat
    x_data = radar_data(i,:) .* cos(theta);
    y_data = radar_data(i,:) .* sin(theta);
    fill([x_data, x_data(1)], [y_data, y_data(1)], colors{i}, ...
        'FaceAlpha', 0.15, 'EdgeColor', colors{i}, 'LineWidth', 2, ...
        'DisplayName', strategy_names{i});
end
legend('Location', 'southoutside', 'Orientation', 'horizontal', 'FontSize', 10);
title(sprintf('%s工况 - 等效燃油经济性雷达图', cycle_name), 'FontSize', 14);
axis equal; axis off;
save_figure(fig7, save_dir, sprintf('%s_radar_chart', cycle_name));

fprintf('[绘图] %s工况 - 7张图表已生成并保存到 %s\n', cycle_name, save_dir);
end

%% 辅助函数：保存图形
function save_figure(fig, save_dir, filename)
% 保存为 .fig 和 .png 格式
fig_path = fullfile(save_dir, filename);
saveas(fig, [fig_path, '.fig']);
saveas(fig, [fig_path, '.png']);
close(fig);
end

%% 辅助函数：颜色名称转RGB
function rgb = hex2rgb(color_char)
switch color_char
    case 'b', rgb = [0.0, 0.4, 0.8];
    case 'r', rgb = [0.8, 0.1, 0.1];
    case 'g', rgb = [0.0, 0.6, 0.2];
    case 'm', rgb = [0.7, 0.0, 0.7];
    case 'k', rgb = [0.2, 0.2, 0.2];
    otherwise, rgb = [0.5, 0.5, 0.5];
end
end
