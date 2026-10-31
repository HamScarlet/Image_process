create_clock -name {sysclk} -period 10.000 -waveform {0.000 5.000} [get_ports {I_sysclk}]

derive_clocks -instance [get_cells {U_pll/dr1_phy_pll_8c99844ac61f_Inst/u_DR1_PHY_PLL }]
 
#create_clock -name p2f_clk0 -period 5 -waveform {0 2.5} [get_nets {system/w_port__ARM_Processor_System_0__p2f_clk0}]
rename_clock -name {pclkx1} [get_clocks {U_pll/dr1_phy_pll_8c99844ac61f_Inst/u_DR1_PHY_PLL.clkc[0]}]
rename_clock -name {pclkx5} [get_clocks {U_pll/dr1_phy_pll_8c99844ac61f_Inst/u_DR1_PHY_PLL.clkc[1]}]
rename_clock -name {clk70m} [get_clocks {U_pll/dr1_phy_pll_8c99844ac61f_Inst/u_DR1_PHY_PLL.clkc[2]}]
rename_clock -name {clk24m} [get_clocks {U_pll/dr1_phy_pll_8c99844ac61f_Inst/u_DR1_PHY_PLL.clkc[3]}]

set_clock_groups -exclusive -group [get_clocks {pclkx1}] -group [get_clocks {pclkx5}] -group [get_clocks {clk24m}] -group [get_clocks {clk70m}]
