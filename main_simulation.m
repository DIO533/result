%% =========================================================
%  main_simulation.m - 并联式混合动力汽车能量管理策略仿真主程序
%  Parallel HEV Energy Management Strategy Simulation
%  =========================================================
%
%  论文：2223865 朱晨吉 - 并联式HEV能量管理策略仿真与对比分析
%  运行环境：MATLAB R2018a 及以上（无需Simulink）
%
%  程序功能：
%   1. 在NEDC和WLTC两种工况下仿真3种能量管理策略
%   2. 输出各策略性能对比图表（车速跟随、SOC轨迹、工作点分布等）
%   3. 单因素变量法分析关键参数对性能的影响
%   4. 敏感性分析
%
%  使用方法：直接运行 main_simulation.m 即可
%  =========================================================

clear; clc; close all;

fprintf('=========================================================\n');
fprintf('  并联式HEV能量管理策略仿真程序\n');
fprintf('  Parallel HEV EMS Simulation\n');
fprintf('=========================================================\n\n');

%% 0. 路径设置
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

%% 1. 加载整车参数
fprintf('[1/6] 加载整车参数...\n');
veh = vehicle_params();
eng = engine_params();
mot = motor_params();
bat = battery_params();

fprintf('      整车质量: %d kg，发动机峰值功率: %.0f kW，电机峰值功率: %.0f kW\n', ...
    veh.mass, eng.P_max/1000, mot.P_max/1000);

%% 2. 生成驾驶工况
fprintf('[2/6] 生成驾驶工况...\n');
[t_NEDC, v_NEDC] = generate_NEDC();
[t_WLTC, v_WLTC] = generate_WLTC();

fprintf('      NEDC工况: 时长 %ds，总距离 %.2f km，最高车速 %.1f km/h\n', ...
    length(t_NEDC), sum(v_NEDC)/1000, max(v_NEDC)*3.6);
fprintf('      WLTC工况: 时长 %ds，总距离 %.2f km，最高车速 %.1f km/h\n', ...
    length(t_WLTC), sum(v_WLTC)/1000, max(v_WLTC)*3.6);

%% 3. 定义策略列表
strategy_names = {'基于规则策略', '模糊逻辑策略', 'ECMS策略'};
n_strategies   = length(strategy_names);

%% 4. 主仿真循环（两种工况 × 三种策略）
fprintf('\n[3/6] 开始主仿真循环（共 %d 次仿真）...\n', 2 * n_strategies);

cycles   = {'NEDC', 'WLTC'};
t_cycles = {t_NEDC, t_WLTC};
v_cycles = {v_NEDC, v_WLTC};

all_results = cell(2, n_strategies);   % 存储所有仿真结果

for c = 1:2  % 遍历工况
    cycle_name = cycles{c};
    t_ref      = t_cycles{c};
    v_ref      = v_cycles{c};
    N          = length(t_ref);
    dt         = 1;  % 仿真步长 [s]
    
    fprintf('\n  --- %s工况 ---\n', cycle_name);
    
    for s = 1:n_strategies  % 遍历策略
        strat_name = strategy_names{s};
        fprintf('  运行策略: %-15s ...', strat_name);
        tic;
        
        %% 初始化状态变量
        SOC_arr       = zeros(N, 1);
        v_actual_arr  = zeros(N, 1);
        fuel_rate_arr = zeros(N, 1);
        T_eng_arr     = zeros(N, 1);
        T_mot_arr     = zeros(N, 1);
        eng_speed_arr = zeros(N, 1);
        mot_speed_arr = zeros(N, 1);
        eng_on_arr    = zeros(N, 1);
        P_elec_arr    = zeros(N, 1);
        
        SOC_arr(1)       = bat.SOC_init;
        v_actual_arr(1)  = v_ref(1);
        eng_on_prev      = 0;
        
        %% 仿真主循环（速度跟随仿真）
        for k = 1:N-1
            v_k    = v_actual_arr(k);
            v_next = v_ref(k+1);
            
            % 需求加速度（由工况速度差分得到）
            a_req = (v_next - v_k) / dt;
            a_req = max(-4.0, min(4.0, a_req));  % 限制合理加速度范围
            
            %% 传动系统：计算各部件转速和需求扭矩
            [eng_sp, mot_sp, gear, T_wheel_demand] = transmission_model(veh, v_k, a_req);
            
            % 将车轮扭矩折算到发动机/电机轴（传动比+效率）
            total_ratio = veh.gear_ratio(gear) * veh.final_ratio;
            % 使用最小效率值 0.01 防止除零（实际传动效率不应为0）
            trans_eff_safe = max(0.01, veh.trans_eff);
            if T_wheel_demand >= 0
                T_shaft_demand = T_wheel_demand / (total_ratio * trans_eff_safe);
            else
                % 制动时能量回收方向相反
                T_shaft_demand = T_wheel_demand * trans_eff_safe / (total_ratio + 1e-6);
            end
            T_shaft_demand = max(-250, min(350, T_shaft_demand));
            
            %% 能量管理策略：确定扭矩分配
            switch s
                case 1  % 基于规则的策略
                    [T_eng, T_mot, eng_on] = rule_based_strategy(...
                        eng, mot, bat, SOC_arr(k), T_shaft_demand, eng_sp, eng_on_prev);
                case 2  % 模糊逻辑策略
                    [T_eng, T_mot, eng_on] = fuzzy_logic_strategy(...
                        eng, mot, bat, SOC_arr(k), T_shaft_demand, eng_sp, eng_on_prev);
                case 3  % ECMS策略
                    [T_eng, T_mot, eng_on] = ecms_strategy(...
                        eng, mot, bat, SOC_arr(k), T_shaft_demand, eng_sp, eng_on_prev);
            end
            
            %% 发动机模型：计算实际燃油消耗
            if eng_on
                [fuel_rate, ~, T_eng] = engine_model(eng, eng_sp, T_eng);
            else
                fuel_rate = 0;
                T_eng     = 0;
            end
            
            %% 电机模型：计算电功率
            [P_elec, ~, T_mot] = motor_model(mot, mot_sp, T_mot);
            
            %% 电池模型：更新SOC
            [SOC_new, ~, ~] = battery_model(bat, SOC_arr(k), P_elec, dt);
            
            %% 更新状态
            SOC_arr(k+1)       = SOC_new;
            fuel_rate_arr(k)   = fuel_rate;
            T_eng_arr(k)       = T_eng;
            T_mot_arr(k)       = T_mot;
            eng_speed_arr(k)   = eng_sp;
            mot_speed_arr(k)   = mot_sp;
            eng_on_arr(k)      = eng_on;
            P_elec_arr(k)      = P_elec;
            eng_on_prev        = eng_on;
            
            % 车速跟随（理想跟随，实际中可加控制误差）
            v_actual_arr(k+1) = v_next;
        end
        
        %% 计算性能指标
        total_fuel_g  = sum(fuel_rate_arr) * dt;         % 总燃油消耗 [g]
        total_fuel_kg = total_fuel_g / 1000;              % [kg]
        total_dist_m  = sum(v_ref) * dt;                  % 总行驶距离 [m]
        total_dist_km = max(0.1, total_dist_m / 1000);    % [km]
        
        % 等效燃油经济性 [L/100km]
        fuel_density_kg_L = 0.750;                        % 汽油密度 [kg/L]
        total_fuel_L      = total_fuel_kg / fuel_density_kg_L;
        fuel_economy      = total_fuel_L / total_dist_km * 100;
        
        % 电能利用率（再生制动回收电量/总电机消耗）
        P_regen_arr = max(0, -P_elec_arr);                % 回收功率
        P_drive_arr = max(0,  P_elec_arr);                % 驱动耗电
        total_regen = sum(P_regen_arr) * dt;              % 总回收电能 [J]
        total_drive_elec = max(1, sum(P_drive_arr) * dt); % 总驱动电能 [J]
        elec_utilization = min(1.0, total_regen / total_drive_elec);
        
        % 系统综合效率（简化计算）
        eng_on_ratio  = mean(eng_on_arr);
        avg_efficiency = max(0.15, min(0.55, ...
            0.20 + 0.18 * eng_on_ratio + 0.12 * elec_utilization));
        
        % 速度跟随误差（RMSE归一化）
        v_max = max(v_ref) + 0.1;
        speed_rmse  = sqrt(mean((v_actual_arr - v_ref).^2));
        speed_error = min(1.0, speed_rmse / v_max);
        
        %% 存储结果
        result.t               = t_ref;
        result.v_ref           = v_ref;
        result.v_actual        = v_actual_arr;
        result.SOC             = SOC_arr;
        result.fuel_rate       = fuel_rate_arr;
        result.T_eng           = T_eng_arr;
        result.T_mot           = T_mot_arr;
        result.eng_speed       = eng_speed_arr;
        result.mot_speed       = mot_speed_arr;
        result.eng_on          = eng_on_arr;
        result.P_elec          = P_elec_arr;
        result.total_fuel      = total_fuel_g;
        result.fuel_economy    = fuel_economy;
        result.elec_utilization= elec_utilization;
        result.avg_efficiency  = avg_efficiency;
        result.speed_error     = speed_error;
        result.cycle_name      = cycle_name;
        result.strategy_name   = strat_name;
        
        all_results{c, s} = result;
        
        t_sim = toc;
        fprintf(' 完成！耗时 %.1fs，燃油 %.2f L/100km，终态SOC %.3f\n', ...
            t_sim, fuel_economy, SOC_arr(end));
    end
end

%% 5. 生成图表
fprintf('\n[4/6] 生成对比分析图表...\n');

for c = 1:2
    cycle_name = cycles{c};
    
    % 将结果转换为结构体数组
    res_array = [];
    for s = 1:n_strategies
        res_array = [res_array, all_results{c,s}];
    end
    
    save_subdir = fullfile(results_dir, cycle_name);
    plot_results(res_array, cycle_name, strategy_names, save_subdir);
    fprintf('  %s工况图表保存至: %s\n', cycle_name, save_subdir);
end

%% 6. 跨工况策略对比
fprintf('\n[5/6] 生成跨工况策略对比图表...\n');
res_NEDC_array = [];
res_WLTC_array = [];
for s = 1:n_strategies
    res_NEDC_array = [res_NEDC_array, all_results{1,s}];
    res_WLTC_array = [res_WLTC_array, all_results{2,s}];
end
compare_save_dir = fullfile(results_dir, 'comparison');
compare_strategies(res_NEDC_array, res_WLTC_array, strategy_names, compare_save_dir);
fprintf('  对比图表保存至: %s\n', compare_save_dir);

%% 7. 单因素变量法分析
fprintf('\n[6/6] 运行单因素变量分析和敏感性分析...\n');
single_dir = fullfile(results_dir, 'single_factor');
single_factor_analysis(veh, eng, mot, bat, single_dir);

sensitivity_dir = fullfile(results_dir, 'sensitivity');
sensitivity_analysis(veh, eng, mot, bat, sensitivity_dir);

%% 打印最终汇总
fprintf('\n=========================================================\n');
fprintf('  仿真完成！性能汇总：\n');
fprintf('=========================================================\n');
fprintf('%-12s | %-18s | %-12s | %-12s\n', '策略', '工况', '燃油(L/100km)', '终态SOC');
fprintf('%s\n', repmat('-', 1, 62));
for c = 1:2
    for s = 1:n_strategies
        r = all_results{c,s};
        fprintf('%-12s | %-18s | %12.3f | %12.3f\n', ...
            strategy_names{s}, cycles{c}, r.fuel_economy, r.SOC(end));
    end
    if c == 1
        fprintf('%s\n', repmat('-', 1, 62));
    end
end
fprintf('=========================================================\n');
fprintf('\n结果图表已保存至: %s\n', results_dir);
fprintf('主要输出文件：\n');
fprintf('  results/NEDC/       - NEDC工况各策略对比图\n');
fprintf('  results/WLTC/       - WLTC工况各策略对比图\n');
fprintf('  results/comparison/ - 跨工况策略综合对比图\n');
fprintf('  results/single_factor/ - 单因素分析图\n');
fprintf('  results/sensitivity/   - 敏感性分析图\n');
fprintf('\n仿真程序运行完毕。\n');
