function plot_single_factor(sfa_results, results_dir)
% 绘制单因素变量分析图表
%
% 输入:
%   sfa_results - 单因素分析结果（来自 single_factor_analysis）
%   results_dir - 结果保存目录

fprintf('\n正在绘制单因素分析图表...\n');

% =============================================
% 图1：初始SOC vs 总燃油消耗
% =============================================
fig1 = figure('Name', '初始SOC vs 燃油经济性', 'NumberTitle', 'off', ...
    'Position', [100, 100, 750, 500]);

yyaxis left
plot(sfa_results.soc_init_vals, sfa_results.econ_vs_soc, 'b-o', ...
    'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b');
ylabel('燃油经济性 [L/100km]', 'FontSize', 12);

yyaxis right
plot(sfa_results.soc_init_vals, sfa_results.fuel_vs_soc, 'r-s', ...
    'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
ylabel('总燃油消耗 [g]', 'FontSize', 12);

xlabel('初始SOC [-]', 'FontSize', 12);
title('初始SOC 对燃油经济性的影响', 'FontSize', 13, 'FontWeight', 'bold');
legend({'燃油经济性 (L/100km)', '总油耗 (g)'}, 'Location', 'best', 'FontSize', 10);
grid on; box on;
save_figure(fig1, fullfile(results_dir, 'SFA_01_SOC_init_vs_fuel'));

% =============================================
% 图2：电机功率比例因子 vs 等效燃油经济性
% =============================================
fig2 = figure('Name', '电机功率比例因子 vs 燃油经济性', 'NumberTitle', 'off', ...
    'Position', [100, 100, 750, 500]);

yyaxis left
plot(sfa_results.motor_scale_vals, sfa_results.econ_vs_motor, 'b-o', ...
    'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b');
ylabel('燃油经济性 [L/100km]', 'FontSize', 12);

yyaxis right
plot(sfa_results.motor_scale_vals, sfa_results.fuel_vs_motor, 'r-s', ...
    'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
ylabel('总燃油消耗 [g]', 'FontSize', 12);

xlabel('电机功率比例因子 [-]', 'FontSize', 12);
title('电机功率比例因子 对等效燃油经济性的影响', 'FontSize', 13, 'FontWeight', 'bold');
legend({'燃油经济性 (L/100km)', '总油耗 (g)'}, 'Location', 'best', 'FontSize', 10);
grid on; box on;
save_figure(fig2, fullfile(results_dir, 'SFA_02_motor_scale_vs_fuel'));

% =============================================
% 图3：启停SOC阈值 vs 综合效率
% =============================================
fig3 = figure('Name', '启停SOC阈值 vs 燃油经济性', 'NumberTitle', 'off', ...
    'Position', [100, 100, 750, 500]);

yyaxis left
plot(sfa_results.soc_thresh_vals, sfa_results.econ_vs_thresh, 'b-o', ...
    'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b');
ylabel('燃油经济性 [L/100km]', 'FontSize', 12);

yyaxis right
plot(sfa_results.soc_thresh_vals, sfa_results.fuel_vs_thresh, 'r-s', ...
    'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
ylabel('总燃油消耗 [g]', 'FontSize', 12);

xlabel('发动机启停SOC阈值 [-]', 'FontSize', 12);
title('发动机启停SOC阈值 对系统综合效率的影响', 'FontSize', 13, 'FontWeight', 'bold');
legend({'燃油经济性 (L/100km)', '总油耗 (g)'}, 'Location', 'best', 'FontSize', 10);
grid on; box on;
save_figure(fig3, fullfile(results_dir, 'SFA_03_soc_thresh_vs_fuel'));

fprintf('单因素分析图表已保存到: %s\n', results_dir);
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
