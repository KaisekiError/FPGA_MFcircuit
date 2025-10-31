library ieee;
use ieee.std_logic_1164.all;


package para is

  -- use MUL instead of DIV

  constant K_RC1     : std_logic_vector(31 downto 0) := x"38BEA671"; -- h/(R*C1) 
  constant K_C1      : std_logic_vector(31 downto 0) := x"3DBA2E8A"; -- h/C1
  constant K_C2      : std_logic_vector(31 downto 0) := x"40800000"; -- h/C2      
  constant K_C2_B    : std_logic_vector(31 downto 0) := x"40800000"; -- h/C2*β     
  constant K_L1      : std_logic_vector(31 downto 0) := x"35B2F4FD"; -- h/L1     
  constant K_L2      : std_logic_vector(31 downto 0) := x"33C339CC"; -- h/L2     
  constant K_VTH     : std_logic_vector(31 downto 0) := x"3F555555"; -- 1/2VTH  


  constant VS        : std_logic_vector(31 downto 0) := x"40A00000"; -- 5.0
  constant VTH       : std_logic_vector(31 downto 0) := x"3F19999A"; -- 0.6

  constant NEG_ONE   : std_logic_vector(31 downto 0) := x"BF800000"; -- -1.0
  constant ONE       : std_logic_vector(31 downto 0) := x"3F800000"; -- 1.0
  constant TWO       : std_logic_vector(31 downto 0) := x"40000000"; -- 2.0
  constant HALF      : std_logic_vector(31 downto 0) := x"3F000000"; -- 0.5
  constant ONE_SIXTH : std_logic_vector(31 downto 0) := x"3E2AAAAB"; -- 0.16666667
  constant CONST27   : std_logic_vector(31 downto 0) := x"41D80000"; -- 27.0
  constant CONST9    : std_logic_vector(31 downto 0) := x"41100000"; -- 9.0

  constant DT        : std_logic_vector(31 downto 0) := x"2DAFEBFF"; -- 2.0e-11
  constant DT_HALF   : std_logic_vector(31 downto 0) := x"2D2FEBFF"; --1.0e-11
end package para;
