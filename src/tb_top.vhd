library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.para.all;

entity tb_top is
end entity;

architecture sim of tb_top is
  -- 时钟周期
  constant CLK_PERIOD : time := 5 ns;

  -- 可配置迭代轮数
  constant N_STEPS : integer := 200;

  -- DUT 端口信号
  signal clk     : std_logic := '0';
  signal rst     : std_logic := '0';
  signal start   : std_logic := '0';

  signal uC1_in  : std_logic_vector(31 downto 0) := (others => '0');
  signal uC2_in  : std_logic_vector(31 downto 0) := (others => '0');
  signal iL1_in  : std_logic_vector(31 downto 0) := (others => '0');
  signal iL2_in  : std_logic_vector(31 downto 0) := (others => '0');

  signal uC1_out : std_logic_vector(31 downto 0);
  signal uC2_out : std_logic_vector(31 downto 0);
  signal iL1_out : std_logic_vector(31 downto 0);
  signal iL2_out : std_logic_vector(31 downto 0);
  signal ready   : std_logic;

  -- 迭代计数
  signal step_cnt : integer := 0;

begin
  -- 时钟
  clk <= not clk after CLK_PERIOD/2;

  -- DUT 实例
  dut: entity work.top
    port map (
      clk      => clk,
      rst      => rst,
      start    => start,
      uC1_in   => uC1_in,
      uC2_in   => uC2_in,
      iL1_in   => iL1_in,
      iL2_in   => iL2_in,
      uC1_out  => uC1_out,
      uC2_out  => uC2_out,
      iL1_out  => iL1_out,
      iL2_out  => iL2_out,
      ready    => ready
    );

  -- 复位与初值
  stim_proc: process
  begin
    -- 复位
    rst <= '1';
    wait for 4*CLK_PERIOD;
    rst <= '0';
    wait for 2*CLK_PERIOD;

    -- 设置初始条件（可替换为你需要的初值）
    uC1_in <= x"3F19999A";
    uC2_in <= x"3F19999A";
    iL1_in <= x"3A1D4952";
    iL2_in <= x"3A1D4952";

    -- 迭代 N 轮
    for k in 1 to N_STEPS loop
      -- 触发一轮：start 拉高一个周期
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';

      -- 等待 ready 拉高，表示本轮完成
      wait until rising_edge(clk) and ready = '1';

      -- 在 ready 的这个时钟沿，把输出回写为下一轮的输入
      uC1_in <= uC1_out;
      uC2_in <= uC2_out;
      iL1_in <= iL1_out;
      iL2_in <= iL2_out;

      step_cnt <= k;

      -- 可选：打印本轮结果
      report "step=" & integer'image(k) &
             " uC1=" & integer'image(to_integer(signed(uC1_out))) &
             " uC2=" & integer'image(to_integer(signed(uC2_out))) &
             " iL1=" & integer'image(to_integer(signed(iL1_out))) &
             " iL2=" & integer'image(to_integer(signed(iL2_out)));
    end loop;

    -- 结束仿真
    report "Simulation finished after " & integer'image(N_STEPS) & " steps" severity note;
    wait for 10*CLK_PERIOD;
    std.env.stop;
    wait;
  end process;

end architecture;