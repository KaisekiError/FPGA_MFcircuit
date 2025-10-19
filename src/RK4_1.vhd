library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.para.all;

entity RK4_1 is 
	port(
			clk_i 			: in std_logic;
			fpu_op_i		: in std_logic;
			fracta_i		: in std_logic_vector(FRAC_WIDTH+4 downto 0); -- carry(1) & hidden(1) & fraction(23) & guard(1) & round(1) & sticky(1)
			fractb_i		: in std_logic_vector(FRAC_WIDTH+4 downto 0);
			signa_i 		: in std_logic;
			signb_i 		: in std_logic;
			fract_o			: out std_logic_vector(FRAC_WIDTH+4 downto 0);
			sign_o 			: out std_logic);
end RK4_1;
