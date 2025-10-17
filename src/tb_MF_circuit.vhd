library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_circuit is
end entity;

architecture sim of tb_circuit is

  -- DUT 端口信号
  signal clk     : std_logic := '0';
  signal rst     : std_logic := '1';
  signal start   : std_logic := '0';
  signal done_1  : std_logic;

  signal uC1, uC2, iL1, iL2 : std_logic_vector(31 downto 0) := (others => '0');

  -- 时钟周期
  constant CLK_PERIOD : time := 10 ns;

begin

  -------------------------------------------------------------------
  -- 时钟生成
  -------------------------------------------------------------------
  clk_process : process
  begin
    while true loop
      clk <= '0';
      wait for CLK_PERIOD/2;
      clk <= '1';
      wait for CLK_PERIOD/2;
    end loop;
  end process;

  -------------------------------------------------------------------
  -- DUT 实例化
  -------------------------------------------------------------------
  uut: entity work.circuit
    port map (
      clk    => clk,
      rst    => rst,
      start  => start,
      done_1 => done_1,
      uC1    => uC1,
      uC2    => uC2,
      iL1    => iL1,
      iL2    => iL2
    );

  -------------------------------------------------------------------
  -- 激励过程
  -------------------------------------------------------------------
  stim_proc : process
  constant TOTAL_CYCLES : integer := 100;  -- 总共计算次数
  variable current_cycle : integer := 0;
  begin
  -- Reset
    rst <= '1';
    wait for 100 ns;
    rst <= '0';
    
   while current_cycle < TOTAL_CYCLES loop
      -- 启动单次计算
      start <= '1';
      wait until rising_edge(clk);  -- 等待下一个时钟上升沿
      start <= '0';
      
      -- 等待计算完成（done_1拉高）
      wait until done_1 = '1';
      
      current_cycle := current_cycle + 1;
      
      -- 每100次计算报告一次进度
      if current_cycle mod 100 = 0 then
        report "qwq";
      end if;
      
    end loop;
  wait for 200 us;
  wait;
  end process;

  -------------------------------------------------------------------
  -- 文件写出过程 (导出 CSV，二进制字符串)
  -------------------------------------------------------------------
  write_proc : process(clk)
    file out_file : text open write_mode is "results.csv";
    variable L : line;

    -- 辅助函数：std_logic_vector → string
    function slv_to_str(slv : std_logic_vector) return string is
      variable result : string(1 to slv'length);
    begin
      for i in slv'range loop
        if slv(i) = '1' then
          result(slv'length - i) := '1';
        else
          result(slv'length - i) := '0';
        end if;
      end loop;
      return result;
    end function;

  begin
    if rising_edge(clk) then
      if done_1 = '1' then
        -- 写 CSV：uC1,uC2,iL1,iL2
        write(L, slv_to_str(uC1));
        write(L, string'(","));
        write(L, slv_to_str(uC2));
        write(L, string'(","));
        write(L, slv_to_str(iL1));
        write(L, string'(","));
        write(L, slv_to_str(iL2));
        writeline(out_file, L);
      end if;
    end if;
  end process;

end architecture sim;
