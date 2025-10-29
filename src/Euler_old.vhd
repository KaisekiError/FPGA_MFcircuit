library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.para.all;

entity euler_old is
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

architecture rtl of euler_old is
  type st_t is (IDLE, CAL_WAIT, START_WAIT, UPDATE_WAIT, DONE);
  type slv_array is array(0 to 3) of std_logic_vector(31 downto 0);
  type op_array is array(0 to 3) of std_logic_vector(2 downto 0);
  type bool_array is array(0 to 3) of std_logic;

  signal st_rk : st_t := IDLE;

  signal uC1_in, uC2_in, iL1_in, iL2_in : std_logic_vector(31 downto 0);
  signal uC1_out, uC2_out, iL1_out, iL2_out : std_logic_vector(31 downto 0);
  signal done_1 : std_logic;
  signal start_d : std_logic;

  -- 并行化信号(Euler)
  signal start_e        : std_logic;
  signal f, x, euler    : slv_array;
  signal ready_e        : bool_array;

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

    EULER_GEN : for i in 0 to 3 generate
      u_euler: entity work.Euler
        port map (
          clk_i       => clk,
          delta_t     => DT,     
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
      start_e <= '0';
    elsif rising_edge(clk) then
      ready <= '0';
      start_d <= '0';
      start_e <= '0';
      all_euler_ready := (ready_e(0) = '1') and (ready_e(1) = '1') and (ready_e(2) = '1') and (ready_e(3) = '1');

      case st_rk is
        when IDLE =>  -- k
          if start ='1' then
            uC1_in <= f1_in;
            uC2_in <= f2_in;
            iL1_in <= f3_in;
            iL2_in <= f4_in;
            start_d  <= '1';
            st_rk  <= CAL_WAIT;
          end if;
        when CAL_WAIT =>  -- x0+k*DT
          if done_1='1' then               
            x(0) <= f1_in; f(0) <= uC1_out;
            x(1) <= f2_in; f(1) <= uC2_out;
            x(2) <= f3_in; f(2) <= iL1_out;
            x(3) <= f4_in; f(3) <= iL2_out;
            st_rk <= START_WAIT;
          end if;
        when START_WAIT => 
             start_e <= '1';
             st_rk <= UPDATE_WAIT;
        when UPDATE_WAIT =>
          if all_euler_ready then
            f1_out <= euler(0);
            f2_out <= euler(1);
            f3_out <= euler(2);
            f4_out <= euler(3);
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