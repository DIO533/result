function vp = vehicle_params()
% 整车参数定义
% 基于典型并联式混合动力轿车（参考丰田普锐斯级别）参数

vp.m          = 1500;      % 整车质量 [kg]
vp.g          = 9.81;      % 重力加速度 [m/s^2]
vp.rho_air    = 1.2;       % 空气密度 [kg/m^3]
vp.Cd         = 0.30;      % 风阻系数 [-]
vp.A_frontal  = 2.2;       % 迎风面积 [m^2]
vp.Cr         = 0.012;     % 滚动阻力系数 [-]
vp.r_wheel    = 0.317;     % 车轮半径 [m]
vp.J_wheel    = 1.5;       % 车轮转动惯量 [kg·m^2]（两轴总计）
vp.eta_final  = 0.97;      % 主减速器效率 [-]
vp.i_final    = 4.1;       % 主减速比 [-]
vp.grade      = 0;         % 道路坡角 [rad]（平路）

% 制动再生效率
vp.eta_regen  = 0.6;       % 制动能量回收效率 [-]

end
