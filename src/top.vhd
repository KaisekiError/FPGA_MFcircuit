library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.para.all;

entity top is
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    start : in  std_logic;
    
    uC1_in    : in std_logic_vector(31 downto 0);
    uC2_in    : in std_logic_vector(31 downto 0);
    iL1_in    : in std_logic_vector(31 downto 0);
    iL2_in    : in std_logic_vector(31 downto 0);
    uC1_out   : out std_logic_vector(31 downto 0);
    uC2_out   : out std_logic_vector(31 downto 0);
    iL1_out   : out std_logic_vector(31 downto 0);
    iL2_out   : out std_logic_vector(31 downto 0)
    ready  : out std_logic


    );
end entity;

architecture rtl of top is
 type st is (IDLE, CAL_WAIT, START_WAIT, UPDATE_WAIT, DONE);
--   type slv_array is array(0 to 3) of std_logic_vector(31 downto 0);
--   type op_array is array(0 to 3) of std_logic_vector(2 downto 0);
--   type bool_array is array(0 to 3) of std_logic;

 signal st_rk : st_t := IDLE;
 signal uC1_in, uC2_in, iL1_in, iL2_in : std_logic_vector(31 downto 0);
 signal uC1_out, uC2_out, iL1_out, iL2_out : std_logic_vector(31 downto 0);
 signal done_1,done_2,done_3,done_4 : std_logic;
 signal start_1 ,start_2,start_3,start_4: std_logic;

--   -- 并行化信号(Euler)
--   signal start_e        : std_logic;
--   signal f, x, euler    : slv_array;
--   signal ready_e        : bool_array;

begin
    u_eq1 : entity work.uC1_circuit
      port map(
        clk        => clk,
        rst        => rst, 
        start      => start_1,
        done     => done_1,
        uC1_in     => uC1_in,
        iL1_in     => iL1_in,
        iL2_in     => iL2_in,
        uC1_out    => uC1_out,


      );
    u_eq2 : entity work.uC2_circuit
      port map(
        clk        => clk,
        rst        => rst, 
        start      => start_2,
        done     => done_2,
        uC2_in     => uC2_in,
        iL1_in     => iL1_in,
        iL2_in     => iL2_in,
        uC2_out    => uC2_out,

      );
    u_eq3 : entity work.il1_circuit
      port map(
        clk        => clk,
        rst        => rst, 
        start      => start_3,
        done     => done_1,
        uC1_in     => uC1_in,
        iL1_in     => iL1_in,
        iL1_out    => iL1_out,
      );
    u_eq4 : entity work.il2_circuit
      port map(
        clk        => clk,
        rst        => rst, 
        start      => start_4,
        done     => done_1,
        uC1_in     => uC1_in,
        uC2_in     => uC2_in,
        iL2_out    => iL2_out
      );

    
  process(clk, rst)



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
      allready := (ready_e(0) = '1') and (ready_e(1) = '1') and (ready_e(2) = '1') and (ready_e(3) = '1');
   
  end process;
end architecture;