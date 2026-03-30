function sensitivity_analysis(sfa_results, results_dir)
% 敏感性分析：计算各单因素对综合性能指标的相对影响程度
% 使用燃油经济性（L/100km）的相对变化率衡量敏感性
%
% 输入:
%   sfa_results - 单因素分析结果（来自 single_factor_analysis）
%   results_dir - 结果保存目录

fprintf('\n========== 敏感性分析 ==========\n');

% ---- 计算各因素的相对变化率 ----
% 方法：(最大值-最小值)/均值，归一化到[0,1]后对比

% 1. 初始SOC
e1 = sfa_results.econ_vs_soc;
sens_soc = (max(e1) - min(e1)) / mean(e1) * 100;

% 2. 电机功率比例因子
e2 = sfa_results.econ_vs_motor;
sens_motor = (max(e2) - min(e2)) / mean(e2) * 100;

% 3. 启停SOC阈值
e3 = sfa_results.econ_vs_thresh;
sens_thresh = (max(e3) - min(e3)) / mean(e3) * 100;

fprintf('初始SOC敏感性指标:         %.2f%%\n', sens_soc);
fprintf('电机功率比例因子敏感性指标: %.2f%%\n', sens_motor);
fprintf('启停SOC阈值敏感性指标:      %.2f%%\n', sens_thresh);

% ---- 绘制敏感性分析柱状图 ----
fig = figure('Name', '敏感性分析', 'NumberTitle', 'off', ...
    'Position', [100, 100, 800, 500]);

factor_names = {'初始SOC', '电机功率\n比例因子', '启停SOC\n阈值'};
sensitivity  = [sens_soc, sens_motor, sens_thresh];

bar_colors = [0.2157 0.4941 0.7216;
              0.3020 0.6863 0.2902;
              0.8941 0.1020 0.1098];

b = bar(sensitivity, 'FaceColor', 'flat');
b.CData = bar_colors;

% 标注数值
for k = 1:length(sensitivity)
    text(k, sensitivity(k) + 0.2, sprintf('%.2f%%', sensitivity(k)), ...
        'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
end

set(gca, 'XTickLabel', {'初始SOC', '电机功率比例因子', '启停SOC阈值'}, 'FontSize', 12);
xlabel('影响因素', 'FontSize', 13);
ylabel('敏感性指标（燃油经济性相对变化率 %）', 'FontSize', 13);
title('各单因素对综合性能指标的敏感性分析', 'FontSize', 14, 'FontWeight', 'bold');
grid on; box on;

% 保存图表
save_figure(fig, fullfile(results_dir, 'sensitivity_analysis'));

fprintf('敏感性分析图表已保存。\n');
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
