function veh = vehicle_params()
% 整车参数定义 - 基于丰田普锐斯级别的并联混合动力汽车
% Vehicle Parameters - Based on Toyota Prius-class Parallel HEV

%% 基本整车参数
veh.mass        = 1500;     % 整车质量 [kg]
veh.mass_rot    = 50;       % 旋转质量当量 [kg]（车轮、传动系等的旋转惯量折算）
veh.mass_total  = veh.mass + veh.mass_rot;  % 等效总质量 [kg]

%% 空气动力学参数
veh.Cd          = 0.26;     % 风阻系数 [-]
veh.A_front     = 2.33;     % 迎风面积 [m²]
veh.rho_air     = 1.225;    % 空气密度 [kg/m³]

%% 滚动阻力参数
veh.f0          = 0.009;    % 滚动阻力系数（基础值）[-]
veh.f2          = 0.0;      % 滚动阻力速度相关系数 [s/m]（简化处理）

%% 车轮参数
veh.r_wheel     = 0.287;    % 车轮滚动半径 [m]

%% 传动系参数（5档手动/自动变速箱）
veh.gear_ratio  = [4.113, 2.370, 1.556, 1.061, 0.764];  % 各挡速比
veh.final_ratio = 3.905;    % 主减速比
veh.trans_eff   = 0.96;     % 传动效率

%% 挡位切换车速阈值 [m/s]（对应 km/h: 0/20/40/65/90/∞）
veh.gear_up_speed   = [0, 20, 40, 65, 90] / 3.6;    % 升挡车速阈值 [m/s]
veh.gear_down_speed = [0, 15, 30, 55, 75] / 3.6;    % 降挡车速阈值 [m/s]

%% 重力加速度
veh.g           = 9.81;     % 重力加速度 [m/s²]

%% 坡度
veh.road_slope  = 0;        % 道路坡度角 [rad]（仿真默认平路）

end
