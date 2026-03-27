function bp = battery_params()
% 电池参数定义
% 基于 NiMH 动力电池组（参考丰田 Prius 级别）

bp.V_oc_nom   = 201.6;     % 额定开路电压 [V]（168节 × 1.2V）
bp.Q_nom      = 6.5;       % 额定容量 [Ah]
bp.R_int      = 0.4;       % 内阻 [Ohm]（等效内阻，含接触电阻）

% SOC 安全范围
bp.SOC_max    = 0.9;       % 最大 SOC
bp.SOC_min    = 0.2;       % 最小 SOC
bp.SOC_init   = 0.6;       % 初始 SOC（默认值，仿真时可覆盖）
bp.SOC_ref    = 0.6;       % 参考 SOC（目标充电保持值）

% 最大充放电电流
bp.I_max_dis  = 100;       % 最大放电电流 [A]
bp.I_max_chg  = 80;        % 最大充电电流 [A]

% 开路电压 vs SOC 查找表（线性近似）
bp.soc_table  = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0];
bp.voc_table  = [180, 185, 190, 194, 197, 200, 202, 205, 208, 212, 216];

% ECMS 等效因子（初始值，可在仿真中自适应）
bp.s_ecms     = 2.5;

end
