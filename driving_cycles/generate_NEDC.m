function [t, v] = generate_NEDC()
% 生成 NEDC（新欧洲驾驶循环）工况
% 总时长：1180 s，包含4个UDC城市工况 + 1个EUDC郊区工况
% 参考标准：ECE 15 + EUDC

% NEDC工况速度-时间序列（按阶段拼接）
% 阶段定义：[持续时间(s), 起始速度(km/h), 终止速度(km/h)]

% === UDC 城市驾驶循环（单次，195s） ===
% 每次重复一次 UDC
udc_phases = [
    % 时长   起始速度  终止速度
    11,     0,       0;    % 怠速
    4,      0,       15;   % 加速
    8,      15,      15;   % 匀速
    5,      15,      10;   % 减速
    21,     10,      10;   % 匀速（低速）
    8,      10,      0;    % 减速停车
    3,      0,       0;    % 怠速
    5,      0,       15;   % 加速
    2,      15,      15;   % 匀速（短）
    1,      15,      15;   % 过渡
    5,      15,      32;   % 加速
    24,     32,      32;   % 匀速（32 km/h）
    11,     32,      10;   % 减速
    14,     10,      10;   % 匀速
    4,      10,      0;    % 减速停车
    4,      0,       0;    % 怠速
    5,      0,       15;   % 加速
    4,      15,      35;   % 加速
    26,     35,      35;   % 匀速（35 km/h）
    5,      35,      50;   % 加速
    12,     50,      50;   % 匀速（50 km/h）
    8,      50,      35;   % 减速
    13,     35,      35;   % 匀速
    7,      35,      0;    % 减速停车
    7,      0,       0;    % 怠速
];

% 重复 4 次 UDC，生成连续速度-时间向量
udc_t = [];
udc_v = [];
for rep = 1:4
    for k = 1:size(udc_phases, 1)
        dur = udc_phases(k, 1);
        v_s = udc_phases(k, 2);
        v_e = udc_phases(k, 3);
        t_seg = linspace(0, dur, dur + 1);
        v_seg = linspace(v_s, v_e, dur + 1);
        if isempty(udc_t)
            udc_t = [udc_t, t_seg];
            udc_v = [udc_v, v_seg];
        else
            udc_t = [udc_t, udc_t(end) + t_seg(2:end)];
            udc_v = [udc_v, v_seg(2:end)];
        end
    end
end

% === EUDC 郊区驾驶循环（400s） ===
eudc_phases = [
    % 时长   起始速度  终止速度
    20,     0,       0;    % 怠速
    41,     0,       70;   % 加速至70
    50,     70,      70;   % 匀速70
    8,      70,      50;   % 减速
    69,     50,      50;   % 匀速50
    13,     50,      70;   % 加速
    50,     70,      70;   % 匀速70
    35,     70,      100;  % 加速至100
    30,     100,     100;  % 匀速100
    20,     100,     120;  % 加速至120
    20,     120,     120;  % 匀速120
    13,     120,     80;   % 减速
    13,     80,      80;   % 匀速80
    18,     80,      0;    % 减速停车
];

eudc_t = [];
eudc_v = [];
for k = 1:size(eudc_phases, 1)
    dur = eudc_phases(k, 1);
    v_s = eudc_phases(k, 2);
    v_e = eudc_phases(k, 3);
    t_seg = linspace(0, dur, dur + 1);
    v_seg = linspace(v_s, v_e, dur + 1);
    if isempty(eudc_t)
        eudc_t = [eudc_t, t_seg];
        eudc_v = [eudc_v, v_seg];
    else
        eudc_t = [eudc_t, eudc_t(end) + t_seg(2:end)];
        eudc_v = [eudc_v, v_seg(2:end)];
    end
end

% 拼接 UDC × 4 + EUDC
t_total = [udc_t, udc_t(end) + eudc_t(2:end)];
v_total = [udc_v, eudc_v(2:end)];

% 重采样为整秒，长度对齐
t_end = floor(t_total(end));
t     = (0:t_end)';
v     = interp1(t_total, v_total, t, 'linear') / 3.6;   % km/h -> m/s
v     = max(v, 0);  % 确保速度非负

end
