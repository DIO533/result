function sfa_results = single_factor_analysis(t, v_ref, params, results_dir)
% 单因素变量法分析
% 分析三类关键参数对系统性能的影响：
%   1. 初始SOC（0.3~0.8）
%   2. 电机功率比例因子（0.5~1.5）
%   3. 发动机启停SOC阈值（0.35~0.55）
%
% 输入:
%   t, v_ref    - 工况时间和速度（使用NEDC作为基准工况）
%   params      - 参数结构体（含 vp/ep/mp/bp）
%   results_dir - 结果保存目录
%
% 输出:
%   sfa_results - 单因素分析结果结构体

fprintf('\n========== 单因素变量分析 ==========\n');

vp = params.vp;
ep = params.ep;
mp = params.mp;
bp = params.bp;
N  = length(t);
dt = 1;

% =============================================
% 1. 初始SOC对油耗的影响（使用规则策略）
% =============================================
fprintf('分析 1/3：初始SOC 对燃油经济性的影响...\n');
soc_init_vals = [0.3, 0.4, 0.5, 0.6, 0.7, 0.8];
fuel_vs_soc   = zeros(size(soc_init_vals));
econ_vs_soc   = zeros(size(soc_init_vals));

for ii = 1:length(soc_init_vals)
    bp_tmp = bp;
    bp_tmp.SOC_init = soc_init_vals(ii);
    [fuel_g, econ] = run_single_sim(t, v_ref, vp, ep, mp, bp_tmp, 1, dt, N);
    fuel_vs_soc(ii) = fuel_g;
    econ_vs_soc(ii) = econ;
    fprintf('  SOC_init=%.1f -> 总油耗: %.2f g，燃油经济性: %.2f L/100km\n', ...
        soc_init_vals(ii), fuel_g, econ);
end

% =============================================
% 2. 电机功率比例因子对性能的影响
% =============================================
fprintf('分析 2/3：电机功率比例因子 对等效燃油经济性的影响...\n');
motor_scale_vals = [0.5, 0.7, 0.9, 1.0, 1.2, 1.5];
econ_vs_motor    = zeros(size(motor_scale_vals));
fuel_vs_motor    = zeros(size(motor_scale_vals));

for ii = 1:length(motor_scale_vals)
    mp_tmp = mp;
    mp_tmp.P_max  = mp.P_max  * motor_scale_vals(ii);
    mp_tmp.T_max  = mp.T_max  * motor_scale_vals(ii);
    mp_tmp.T_cont = mp.T_cont * motor_scale_vals(ii);
    [fuel_g, econ] = run_single_sim(t, v_ref, vp, ep, mp_tmp, bp, 2, dt, N);
    fuel_vs_motor(ii) = fuel_g;
    econ_vs_motor(ii) = econ;
    fprintf('  motor_scale=%.1f -> 总油耗: %.2f g，燃油经济性: %.2f L/100km\n', ...
        motor_scale_vals(ii), fuel_g, econ);
end

% =============================================
% 3. 发动机启停SOC阈值对效率的影响
% =============================================
fprintf('分析 3/3：发动机启停SOC阈值 对综合效率的影响...\n');
soc_thresh_vals = [0.35, 0.40, 0.45, 0.50, 0.55, 0.60];
fuel_vs_thresh  = zeros(size(soc_thresh_vals));
econ_vs_thresh  = zeros(size(soc_thresh_vals));

for ii = 1:length(soc_thresh_vals)
    ep_tmp = ep;
    ep_tmp.soc_start = soc_thresh_vals(ii);
    [fuel_g, econ] = run_single_sim(t, v_ref, vp, ep_tmp, mp, bp, 1, dt, N);
    fuel_vs_thresh(ii) = fuel_g;
    econ_vs_thresh(ii) = econ;
    fprintf('  soc_thresh=%.2f -> 总油耗: %.2f g，燃油经济性: %.2f L/100km\n', ...
        soc_thresh_vals(ii), fuel_g, econ);
end

% =============================================
% 保存结果
% =============================================
sfa_results.soc_init_vals   = soc_init_vals;
sfa_results.fuel_vs_soc     = fuel_vs_soc;
sfa_results.econ_vs_soc     = econ_vs_soc;

sfa_results.motor_scale_vals = motor_scale_vals;
sfa_results.fuel_vs_motor    = fuel_vs_motor;
sfa_results.econ_vs_motor    = econ_vs_motor;

sfa_results.soc_thresh_vals = soc_thresh_vals;
sfa_results.fuel_vs_thresh  = fuel_vs_thresh;
sfa_results.econ_vs_thresh  = econ_vs_thresh;

fprintf('单因素分析完成！\n');
end

% ========================================================
% 辅助函数：运行单次仿真，返回总油耗和燃油经济性
% ========================================================
function [fuel_g, econ] = run_single_sim(t, v_ref, vp, ep, mp, bp, s_idx, dt, N)
    v_sim     = zeros(N, 1);
    SOC       = zeros(N, 1);
    fuel_rate = zeros(N, 1);

    v_sim(1) = v_ref(1);
    SOC(1)   = bp.SOC_init;

    for k = 1:N-1
        v_k   = v_sim(k);
        SOC_k = SOC(k);
        v_tgt = v_ref(k+1);

        [~, P_demand, ~] = vehicle_dynamics(v_k, v_tgt, dt, vp);

        switch s_idx
            case 1
                [T_e, T_m, eng_on] = rule_based_strategy(P_demand, SOC_k, v_k, ep, mp, bp);
            case 2
                [T_e, T_m, eng_on] = fuzzy_logic_strategy(P_demand, SOC_k, v_k, ep, mp, bp);
            case 3
                [T_e, T_m, eng_on] = ecms_strategy(P_demand, SOC_k, v_k, ep, mp, bp);
        end

        if eng_on && T_e > 0
            omega_w = v_k / vp.r_wheel + 0.1;
            n_e = omega_w * 30 / pi * vp.i_final * 2.0;
            n_e = max(min(n_e, ep.n_max), ep.n_idle);
            [mf, ~, ~] = engine_model(T_e, n_e, ep);
        else
            T_e = 0; n_e = 0; mf = 0; eng_on = false;
        end

        n_m = max(v_k / vp.r_wheel, 0.1) * 30 / pi;
        n_m = min(n_m, mp.n_max);
        [P_elec, ~] = motor_model(T_m, n_m, mp);
        [SOC_new, ~, ~] = battery_model(SOC_k, P_elec, dt, bp);

        v_new = v_k + (v_tgt - v_k) * 0.9;
        v_new = max(v_new, 0);

        v_sim(k+1)     = v_new;
        SOC(k+1)       = SOC_new;
        fuel_rate(k+1) = mf;
    end

    fuel_g     = sum(fuel_rate) * dt;
    distance_km = trapz(t, v_sim) / 1000;
    econ        = (fuel_g / 750) / max(distance_km, 0.1) * 100;
end
