library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.para.all;
use std.textio.all;

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
    variable iteration_count : integer := 0;
      -- CSV file variables
      file csv_file : text;
      variable file_line : line;
      variable file_status : file_open_status;
      -- Helper function to write binary string
      procedure write_binary_vector(vec : in std_logic_vector) is
       begin
          for i in vec'range loop
              if vec(i) = '1' then
                  write(file_line, string'("1"));
              else
                   write(file_line, string'("0"));
              end if;
          end loop;
      end procedure;
  begin
    file_open(file_status, csv_file, "euler_output_binary.csv", write_mode);
    if file_status /= open_ok then
        report "Error: Cannot create CSV file!" severity error;
    else
        report "CSV file euler_output_binary.csv created";
    end if;
    
    write(file_line, string'("Iteration,f1_out_bin,f2_out_bin,f3_out_bin,f4_out_bin"));
    writeline(csv_file, file_line);

    report "Starting testbench simulation";

    -- 复位
    rst <= '1';
    wait for 4*CLK_PERIOD;
    rst <= '0';
    wait for 2*CLK_PERIOD;

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
      write(file_line, iteration_count);
      write(file_line, string'(","));
      
      write_binary_vector(uC1_out);
      write(file_line, string'(","));
      
      write_binary_vector(uC2_out);
      write(file_line, string'(","));
      
      write_binary_vector(iL1_out);
      write(file_line, string'(","));
      
      write_binary_vector(iL2_out);
      
      writeline(csv_file, file_line);
      
      report "Iteration " & integer'image(iteration_count) & 
              " - Data written to CSV";

    end loop;

    -- 结束仿真
    report "Simulation finished after " & integer'image(N_STEPS) & " steps" severity note;
    file_close(csv_file);
    report "Binary data exported to euler_output_binary.csv";
    wait for 10*CLK_PERIOD;
    std.env.stop;
    wait;
  end process;

end architecture;