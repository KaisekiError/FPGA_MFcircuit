library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.para.all;

entity rk4 is
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;
    start  : in  std_logic;

    f1_in  : in  std_logic_vector(31 downto 0);
    f2_in  : in  std_logic_vector(31 downto 0);
    f3_in  : in  std_logic_vector(31 downto 0);
    f4_in  : in  std_logic_vector(31 downto 0);

    f1_out : out std_logic_vector(31 downto 0);
    f2_out : out std_logic_vector(31 downto 0);
    f3_out : out std_logic_vector(31 downto 0);
    f4_out : out std_logic_vector(31 downto 0);

    ready  : out std_logic
  );
end entity;

architecture rtl of rk4 is
  type st_t is (IDLE, CAL_K1_WAIT, PREP_K2_WAIT, CAL_K2_WAIT, PREP_K3_WAIT, CAL_K3_WAIT, PREP_K4_WAIT, CAL_K4_WAIT,  
                ACCUM_MUL1_WAIT,  ACCUM_MUL2_WAIT, ACCUM_ADD3_WAIT, ACCUM_ADD4_WAIT, ACCUM_ADD5_WAIT, ACCUM_MUL6_WAIT,
                 ACCUM_MUL7_WAIT, ACCUM_ADD8_WAIT,  ACCUM_ADD9_WAIT, DONE);
  type slv_array is array(0 to 3) of std_logic_vector(31 downto 0);
  type op_array is array(0 to 3) of std_logic_vector(2 downto 0);
  type bool_array is array(0 to 3) of std_logic;

  signal st_rk : st_t := IDLE;

  signal uC1_in, uC2_in, iL1_in, iL2_in : std_logic_vector(31 downto 0);
  signal uC1_out, uC2_out, iL1_out, iL2_out : std_logic_vector(31 downto 0);
  signal done_1 : std_logic;
  signal start_d : std_logic;

  -- k1,k2,k3,k4暂存
  signal k1_1,k1_2,k1_3,k1_4 : std_logic_vector(31 downto 0);
  signal k2_1,k2_2,k2_3,k2_4 : std_logic_vector(31 downto 0);
  signal k3_1,k3_2,k3_3,k3_4 : std_logic_vector(31 downto 0);
  signal k4_1,k4_2,k4_3,k4_4 : std_logic_vector(31 downto 0);

  -- 累加部分暂存
  signal t_2k2_1, t_2k2_2, t_2k2_3, t_2k2_4 : std_logic_vector(31 downto 0);

  -- 并行化信号(FPU)
  signal op             : op_array;
  signal opa, opb, y    : slv_array;
  signal ready_o        : bool_array;
  signal start_i        : bool_array;

  -- 并行化信号(Euler)
  signal start_e        : std_logic;
  signal f, x, euler    : slv_array;
  signal ready_e        : bool_array;
  signal dt             : std_logic_vector(31 downto 0);

begin
    u_derivative : entity work.derivative
      port map(
        clk        => clk,
        rst        => rst, 
        start      => start_d,
        done_1     => done_1,
        uC1_in     => uC1_in,
        uC2_in     => uC2_in,
        iL1_in     => iL1_in,
        iL2_in     => iL2_in,
        uC1_out    => uC1_out,
        uC2_out    => uC2_out,
        iL1_out    => iL1_out,
        iL2_out    => iL2_out
      );

    UUT_GEN : for i in 0 to 3 generate
      uut: entity work.fpu
        port map(
          clk_i    => clk,
          opa_i    => opa(i),
          opb_i    => opb(i),
          fpu_op_i => op(i),
          rmode_i  => "00",
          start_i  => start_i(i),
          output_o => y(i),
          ready_o  => ready_o(i)
        );
    end generate UUT_GEN;

--    u_euler: entity work.Euler
--      port map (
--        clk_i       => clk,
--        delta_t     => DT,     
--        start_euler => start_e,
--        xf          => f,     -- 导数
--        x0          => x,     --原始变量
--        x1          => euler_o,-- 更新结果
--        ready_euler => ready_e
--      );
    EULER_GEN : for i in 0 to 3 generate
      u_euler: entity work.Euler
        port map (
          clk_i       => clk,
          delta_t     => dt,     
          start_euler => start_e,
          xf          => f(i),
          x0          => x(i),
          x1          => euler(i),
          ready_euler => ready_e(i)
        );
    end generate EULER_GEN;

  process(clk, rst)
    variable all_fpu_ready : boolean;
    variable all_euler_ready : boolean;
  begin
    if rst='1' then
      st_rk    <= IDLE;
      ready <= '0';
      start_d <= '0';
      start_i <= (others => '0');
      start_e <= '0';
    elsif rising_edge(clk) then
      ready <= '0';
      start_d <= '0';
      start_i <= (others => '0');
      start_e <= '0';
      all_fpu_ready := (ready_o(0) = '1') and (ready_o(1) = '1') and (ready_o(2) = '1') and (ready_o(3) = '1');
      all_euler_ready := (ready_e(0) = '1') and (ready_e(1) = '1') and (ready_e(2) = '1') and (ready_e(3) = '1');

      case st_rk is
        when IDLE =>  -- k1
          if start ='1' then
            uC1_in <= f1_in;
            uC2_in <= f2_in;
            iL1_in <= f3_in;
            iL2_in <= f4_in;
            start_d  <= '1';
            st_rk  <= CAL_K1_WAIT;
          end if;
        when CAL_K1_WAIT =>  -- x0+k1*DT/2
          if done_1='1' then
            k1_1 <= uC1_out;
            k1_2 <= uC2_out;
            k1_3 <= iL1_out;
            k1_4 <= iL2_out;
            start_e <= '1';                
            x(0) <= f1_in; f(0) <= uC1_out;
            x(1) <= f2_in; f(1) <= uC2_out;
            x(2) <= f3_in; f(2) <= iL1_out;
            x(3) <= f4_in; f(3) <= iL2_out;
            dt <= DT_HALF;
            st_rk <= PREP_K2_WAIT;
          end if;
        when PREP_K2_WAIT => -- k2
          if all_euler_ready then
            uC1_in <= euler(0);
            uC2_in <= euler(1);
            iL1_in <= euler(2);
            iL2_in <= euler(3);
            start_d  <= '1';
            st_rk <= CAL_K2_WAIT;
          end if;
        when CAL_K2_WAIT => -- x0+k2*DT/2
          if done_1='1' then
            k2_1 <= uC1_out;
            k2_2 <= uC2_out;
            k2_3 <= iL1_out;
            k2_4 <= iL2_out;
            start_e <= '1';                
            x(0) <= f1_in; f(0) <= uC1_out;
            x(1) <= f2_in; f(1) <= uC2_out;
            x(2) <= f3_in; f(2) <= iL1_out;
            x(3) <= f4_in; f(3) <= iL2_out;
            dt <= DT_HALF;
            st_rk <= PREP_K3_WAIT;
          end if;
        when PREP_K3_WAIT => -- k3
          if all_euler_ready then
            uC1_in <= euler(0);
            uC2_in <= euler(1);
            iL1_in <= euler(2);
            iL2_in <= euler(3);
            start_d  <= '1';
            st_rk <= CAL_K3_WAIT;
          end if;
        when CAL_K3_WAIT => -- x0+k3*DT
          if done_1='1' then
            k3_1 <= uC1_out;
            k3_2 <= uC2_out;
            k3_3 <= iL1_out;
            k3_4 <= iL2_out;
            start_e <= '1';                
            x(0) <= f1_in; f(0) <= uC1_out;
            x(1) <= f2_in; f(1) <= uC2_out;
            x(2) <= f3_in; f(2) <= iL1_out;
            x(3) <= f4_in; f(3) <= iL2_out;
            dt <= DT;
            st_rk <= PREP_K4_WAIT;
          end if;
        when PREP_K4_WAIT => -- k4
          if all_euler_ready then
            uC1_in <= euler(0);
            uC2_in <= euler(1);
            iL1_in <= euler(2);
            iL2_in <= euler(3);
            start_d  <= '1';
            st_rk <= CAL_K4_WAIT;
          end if;
        when CAL_K4_WAIT => -- x0+k3*DT
          if done_1='1' then
            k4_1 <= uC1_out;
            k4_2 <= uC2_out;
            k4_3 <= iL1_out;
            k4_4 <= iL2_out;
            st_rk <= ACCUM_MUL1_WAIT;
          end if;
        when ACCUM_MUL1_WAIT => -- 2*k2
          opa(0) <= k2_1; opb(0) <= TWO; op(0) <= "010"; start_i(0) <= '1';  -- 2*k2_1
          opa(1) <= k2_2; opb(1) <= TWO; op(1) <= "010"; start_i(1) <= '1';  -- 2*k2_2  
          opa(2) <= k2_3; opb(2) <= TWO; op(2) <= "010"; start_i(2) <= '1';  -- 2*k2_3
          opa(3) <= k2_4; opb(3) <= TWO; op(3) <= "010"; start_i(3) <= '1';  -- 2*k2_4
          st_rk <= ACCUM_MUL2_WAIT;
        when ACCUM_MUL2_WAIT => -- 2*k3
          if all_fpu_ready then
            t_2k2_1 <= y(0); t_2k2_2 <= y(1); t_2k2_3 <= y(2); t_2k2_4 <= y(3);
            opa(0) <= k3_1; opb(0) <= TWO; op(0) <= "010"; start_i(0) <= '1';  -- 2*k3_1
            opa(1) <= k3_2; opb(1) <= TWO; op(1) <= "010"; start_i(1) <= '1';  -- 2*k3_2  
            opa(2) <= k3_3; opb(2) <= TWO; op(2) <= "010"; start_i(2) <= '1';  -- 2*k3_3
            opa(3) <= k3_4; opb(3) <= TWO; op(3) <= "010"; start_i(3) <= '1';  -- 2*k3_4
            st_rk <= ACCUM_ADD3_WAIT;
          end if;
        when ACCUM_ADD3_WAIT => -- 2*k2+2*k3
          if all_fpu_ready then
            opa(0) <= y(0); opb(0) <= t_2k2_1; op(0) <= "000"; start_i(0) <= '1';  -- 2*k2_1+2*k3_1
            opa(1) <= y(1); opb(1) <= t_2k2_2; op(1) <= "000"; start_i(1) <= '1';  -- 2*k2_2+2*k3_2
            opa(2) <= y(2); opb(2) <= t_2k2_3; op(2) <= "000"; start_i(2) <= '1';  -- 2*k2_3+2*k3_3
            opa(3) <= y(3); opb(3) <= t_2k2_4; op(3) <= "000"; start_i(3) <= '1';  -- 2*k2_4+2*k3_4
            st_rk <= ACCUM_ADD4_WAIT;
          end if;
        when ACCUM_ADD4_WAIT => -- k1+2*k2+2*k3
          if all_fpu_ready then
            opa(0) <= y(0); opb(0) <= k1_1; op(0) <= "000"; start_i(0) <= '1';  
            opa(1) <= y(1); opb(1) <= k1_2; op(1) <= "000"; start_i(1) <= '1'; 
            opa(2) <= y(2); opb(2) <= k1_3; op(2) <= "000"; start_i(2) <= '1';  
            opa(3) <= y(3); opb(3) <= k1_4; op(3) <= "000"; start_i(3) <= '1'; 
            st_rk <= ACCUM_ADD5_WAIT;
          end if;
        when ACCUM_ADD5_WAIT => -- k1+2*k2+2*k3+k4
          if all_fpu_ready then
            opa(0) <= y(0); opb(0) <= k4_1; op(0) <= "000"; start_i(0) <= '1';  
            opa(1) <= y(1); opb(1) <= k4_2; op(1) <= "000"; start_i(1) <= '1'; 
            opa(2) <= y(2); opb(2) <= k4_3; op(2) <= "000"; start_i(2) <= '1'; 
            opa(3) <= y(3); opb(3) <= k4_4; op(3) <= "000"; start_i(3) <= '1'; 
            st_rk <= ACCUM_MUL6_WAIT;
          end if;
        when ACCUM_MUL6_WAIT => -- （k1+2*k2+2*k3+k4）*(1/6)
          if all_fpu_ready then
            opa(0) <= y(0); opb(0) <= ONE_SIXTH; op(0) <= "010"; start_i(0) <= '1';  
            opa(1) <= y(1); opb(1) <= ONE_SIXTH; op(1) <= "010"; start_i(1) <= '1';  
            opa(2) <= y(2); opb(2) <= ONE_SIXTH; op(2) <= "010"; start_i(2) <= '1'; 
            opa(3) <= y(3); opb(3) <= ONE_SIXTH; op(3) <= "010"; start_i(3) <= '1'; 
            st_rk <= ACCUM_MUL7_WAIT;
          end if;
        when ACCUM_MUL7_WAIT => -- （k1+2*k2+2*k3+k4）*(1/6)*DT
          if all_fpu_ready then
            opa(0) <= y(0); opb(0) <= DT; op(0) <= "010"; start_i(0) <= '1';  
            opa(1) <= y(1); opb(1) <= DT; op(1) <= "010"; start_i(1) <= '1';  
            opa(2) <= y(2); opb(2) <= DT; op(2) <= "010"; start_i(2) <= '1'; 
            opa(3) <= y(3); opb(3) <= DT; op(3) <= "010"; start_i(3) <= '1'; 
            st_rk <= ACCUM_ADD8_WAIT;
          end if;
        when ACCUM_ADD8_WAIT =>
          if all_fpu_ready then
            opa(0) <= y(0); opb(0) <= f1_in ; op(0) <= "000"; start_i(0) <= '1';  
            opa(1) <= y(1); opb(1) <= f2_in; op(1) <= "000"; start_i(1) <= '1';  
            opa(2) <= y(2); opb(2) <= f3_in; op(2) <= "000"; start_i(2) <= '1'; 
            opa(3) <= y(3); opb(3) <= f4_in; op(3) <= "000"; start_i(3) <= '1'; 
            st_rk <= ACCUM_ADD9_WAIT;
          end if;
        when ACCUM_ADD9_WAIT =>
          if all_fpu_ready then
            f1_out <= y(0);
            f2_out <= y(1);
            f3_out <= y(2);
            f4_out <= y(3);
            st_rk <= DONE;
          end if;
        when DONE =>
          ready <= '1';
          st_rk <= IDLE;

        when others =>
          st_rk <= IDLE;
      end case;
    end if;
  end process;
end architecture;
