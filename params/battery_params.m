function bat = battery_params()
% 电池参数定义 - 基于镍氢电池组典型数据（类普锐斯电池系统）
% Battery Parameters - Based on NiMH battery pack typical data

%% 基本电池参数
bat.capacity    = 6.5;      % 电池容量 [Ah]
bat.V_nom       = 201.6;    % 标称电压 [V]
bat.R_int       = 0.50;     % 内阻 [Ω]（充放电平均值）
bat.R_charge    = 0.45;     % 充电内阻 [Ω]
bat.R_discharge = 0.55;     % 放电内阻 [Ω]

%% SOC工作范围
bat.SOC_max     = 0.90;     % SOC上限
bat.SOC_min     = 0.20;     % SOC下限
bat.SOC_init    = 0.60;     % 初始SOC（标准工况）
bat.SOC_ref     = 0.60;     % SOC参考值（目标维持值）

%% 开路电压（OCV）与SOC对应关系（线性近似）
% OCV = V_OC_0 + k_OC * SOC
bat.V_OC_0      = 180;      % OCV截距 [V]
bat.k_OC        = 45;       % OCV斜率 [V]（SOC从0到1时电压变化）
% 等效：OCV(SOC) = 180 + 45*SOC

%% 更精确的OCV-SOC查表数据
bat.SOC_table   = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0];
bat.OCV_table   = [170, 177, 183, 188, 193, 198, 202, 207, 212, 218, 225]; % [V]

%% 功率限制
bat.P_max_discharge = 50000;   % 最大放电功率 [W]
bat.P_max_charge    = 40000;   % 最大充电功率 [W]

%% 库仑效率
bat.eta_charge  = 0.98;     % 充电效率
bat.eta_discharge = 1.0;    % 放电效率

%% ECMS策略中的等效因子参数
bat.s_factor    = 2.8;      % 等效燃油消耗最小化策略等效因子（基准值）

%% 电池热模型（简化）
bat.T_ref       = 25;       % 参考温度 [°C]

end
