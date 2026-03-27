function [fuel_rate, bsfc, eta_eng] = engine_model(T_eng, n_eng, ep)
% 发动机模型：基于BSFC万有特性曲线计算油耗率和效率
%
% 输入:
%   T_eng  - 发动机转矩 [N·m]，>=0
%   n_eng  - 发动机转速 [rpm]，>=0
%   ep     - 发动机参数结构体（来自 engine_params）
%
% 输出:
%   fuel_rate - 瞬时油耗率 [g/s]
%   bsfc      - 制动比油耗 [g/kWh]
%   eta_eng   - 发动机热效率 [-]

% 默认输出
fuel_rate = 0;
bsfc      = 0;
eta_eng   = 0;

% 发动机熄火或空转工况
if n_eng < ep.n_idle || T_eng <= 0
    return;
end

% 限制在MAP范围内
n_clamped = max(min(n_eng, ep.bsfc_n(end)), ep.bsfc_n(1));
T_clamped = max(min(T_eng, ep.bsfc_T(end)), ep.bsfc_T(1));

% 双线性插值查 BSFC MAP
bsfc = interp2(ep.bsfc_n, ep.bsfc_T, ep.bsfc_map, n_clamped, T_clamped, 'linear', 400);

% 防止插值异常
bsfc = max(bsfc, 180);

% 计算功率 [W]
P_eng = T_eng * n_eng * pi / 30;

% 瞬时油耗率 [g/s]  = BSFC[g/kWh] * P[kW] / 3600
fuel_rate = bsfc * (P_eng / 1000) / 3600;
fuel_rate = max(fuel_rate, 0);

% 热效率 = 3600 / (BSFC * H_fuel_kJ/kWh)
%         H_fuel [kJ/kg] -> [kJ/g] = H_fuel/1000
%         eta = 3600 / (bsfc [g/kWh] * (ep.H_fuel/1000) [kJ/g])
%             = 3600 / (bsfc * H/1000)
eta_eng = 3600 / (bsfc * ep.H_fuel / 1000);
eta_eng = max(min(eta_eng, 1.0), 0);

end
