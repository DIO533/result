function [t, v] = generate_NEDC()
% NEDC工况生成 - 新欧洲驾驶循环（New European Driving Cycle）
% NEDC Driving Cycle Generator
%
% 输出:
%   t - 时间序列 [s]，总时长1180s
%   v - 对应车速序列 [m/s]
%
% NEDC由4个城市循环（ECE-15，每个195s）和1个郊区循环（EUDC，400s）组成
% 总距离约11.023 km

%% ECE-15 城市循环（单个，195s）定义
% [时间(s), 速度(km/h)] 关键点
ece_keypoints = [
    0,    0;
    11,   0;    % 怠速
    15,  15;    % 加速
    23,  15;    % 匀速
    28,   0;    % 减速制动
    49,   0;    % 怠速
    54,  32;    % 加速
    61,  32;    % 匀速（简化）
    66,   0;    % 减速
    76,   0;    % 怠速
    81,  32;    % 加速
    87,  32;
    92,  50;    % 加速
    98,  50;    % 匀速
    102, 35;    % 减速
    111, 35;    % 匀速
    116,  0;    % 制动停车
    120,  0;    % 怠速
    125, 50;    % 加速
    133, 50;    % 匀速
    137, 35;
    145, 35;
    150,  0;    % 停车
    167,  0;    % 怠速（等待）
    176,  0;
    195,  0;    % 完成一个ECE循环
];

% 插值生成1Hz的ECE速度曲线 [km/h]
t_ece = (0:195)';
v_ece = interp1(ece_keypoints(:,1), ece_keypoints(:,2), t_ece, 'linear');
v_ece = max(0, v_ece);

%% EUDC 郊区循环（400s）定义
eudc_keypoints = [
    0,    0;
    20,   0;    % 怠速
    41,  70;    % 加速
    65,  70;    % 匀速
    74, 100;    % 加速
    88, 100;    % 匀速  
   101, 120;    % 加速
   150, 120;    % 匀速（高速段）
   163, 80;     % 减速
   176, 80;     % 匀速
   188,  0;     % 制动
   220,  0;     % 怠速
   230,  70;    % 再次加速
   252,  70;    % 匀速
   262, 100;    % 加速
   276, 100;    % 匀速
   288, 120;    % 加速
   320, 120;    % 匀速
   335,  80;    % 减速
   348,  80;    % 匀速
   360,   0;    % 制动
   380,   0;    % 怠速
   400,   0;    % 结束
];

% 插值生成EUDC速度曲线
t_eudc = (0:400)';
v_eudc = interp1(eudc_keypoints(:,1), eudc_keypoints(:,2), t_eudc, 'linear');
v_eudc = max(0, v_eudc);

%% 拼接完整NEDC工况
% 4个ECE循环 + 1个EUDC循环，共 4*195 + 400 = 1180s
t = (0:1179)';
v_kmh = zeros(1180, 1);

% 4个ECE循环
for i = 0:3
    idx_start = i*195 + 1;
    idx_end   = i*195 + 196;
    v_kmh(idx_start:idx_end) = v_ece;
end

% EUDC循环（从780s开始）
v_kmh(781:1181) = v_eudc;

% 截取正确长度
v_kmh = v_kmh(1:1180);
t     = t(1:1180);

% 转换为 [m/s]
v = v_kmh / 3.6;

% 速度平滑处理（避免速度突变导致加速度过大）
v = smooth_velocity(v);

end

function v_smooth = smooth_velocity(v)
% 对速度序列进行轻微平滑，减少数值噪声
% 使用3点移动平均
v_smooth = v;
for i = 2:length(v)-1
    v_smooth(i) = 0.25*v(i-1) + 0.5*v(i) + 0.25*v(i+1);
end
v_smooth = max(0, v_smooth);
end
