library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.para.all;

entity sign is
  port(
    clk_i       : in  std_logic;
    rst        : in  std_logic;
    start_sign : in  std_logic;
    z_in       : in  std_logic_vector(31 downto 0);  -- 输入 z
    ready_sign : out std_logic;                      -- 输出 ready
    sign_out   : out std_logic_vector(31 downto 0)   -- 输出 
  );
end entity;

architecture rtl of sign is
  
  constant POSITIVE_ONE   : std_logic_vector(31 downto 0) := X"3F800000";  -- +1.0
  constant NEGATIVE_ONE   : std_logic_vector(31 downto 0) := X"BF800000";  -- -1.0
  constant ZERO           : std_logic_vector(31 downto 0) := X"00000000";  -- 0.0
  
  type state_type is (IDLE, PROCESSING, DONE);
  signal state : state_type;
  
begin
  
  process(clk_i, rst)
  begin
    if rst = '1' then
      state <= IDLE;
      ready_sign <= '0';
      sign_out <= ZERO;
      
    elsif rising_edge(clk_i) then
      case state is
        when IDLE =>
          ready_sign <= '0';
          if start_sign = '1' then
            state <= PROCESSING;
          end if;
          
        when PROCESSING =>
          if z_in(31) = '0' and z_in(30 downto 0) /= "0000000000000000000000000000000" then
            -- 正数: 返回 +1
            sign_out <= POSITIVE_ONE;
          elsif z_in(31) = '1' then
            -- 负数: 返回 -1
            sign_out <= NEGATIVE_ONE;
          else
            -- 零: 返回 0
            sign_out <= ZERO;
          end if;
          
          state <= DONE;
          
        when DONE =>
          ready_sign <= '1';
          state <= IDLE;
          
      end case;
    end if;
  end process;
  
end architecture rtl;
