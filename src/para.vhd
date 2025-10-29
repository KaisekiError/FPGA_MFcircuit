library ieee;
use ieee.std_logic_1164.all;


package para is

  -- use MUL instead of DIV

  constant K_RC1     : std_logic_vector(31 downto 0) := x"4A8AB75D"; -- 1/(R*C1) ≈ 4.545454e6
  constant K_C1      : std_logic_vector(31 downto 0) := x"4F877711"; -- 1/C1     ≈ 4.545454e9
  constant K_C2      : std_logic_vector(31 downto 0) := x"523A43B7"; -- 1/C2     = 2.0e11
  constant K_L1      : std_logic_vector(31 downto 0) := x"47823555"; -- 1/L1     ≈ 6.666667e4
  constant K_L2      : std_logic_vector(31 downto 0) := x"458E0BA3"; -- 1/L2     ≈ 4.545454e3
  constant K_VTH     : std_logic_vector(31 downto 0) := x"3F555555"; -- 1/2VTH  ≈ 0.8333


  constant VS        : std_logic_vector(31 downto 0) := x"40A00000"; -- 5.0
  constant VTH       : std_logic_vector(31 downto 0) := x"3F19999A"; -- 0.6
  constant K_BETA    : std_logic_vector(31 downto 0) := x"43480000"; -- 200.0


  constant ONE       : std_logic_vector(31 downto 0) := x"3F800000"; -- 1.0
  constant TWO       : std_logic_vector(31 downto 0) := x"40000000"; -- 2.0
  constant HALF      : std_logic_vector(31 downto 0) := x"3F000000"; -- 0.5
  constant ONE_SIXTH : std_logic_vector(31 downto 0) := x"3E2AAAAB"; -- 0.16666667
  constant CONST27   : std_logic_vector(31 downto 0) := x"41D80000"; -- 27.0
  constant CONST9    : std_logic_vector(31 downto 0) := x"41100000"; -- 9.0

  constant DT        : std_logic_vector(31 downto 0) := x"2DAFEBFF"; -- 2.0e-11
  constant DT_HALF   : std_logic_vector(31 downto 0) := x"2D2FEBFF"; --1.0e-11
end package para;
