local T_1 = { };
local T_2 = { };
local T_3 = { [T_2] = T_1 };
T_1[1] = T_3;
T_2[1] = T_3;
return T_3;
