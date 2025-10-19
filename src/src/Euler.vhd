library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_arith.all;
use work.para.all;

entity Euler is
  port (
    clk_i       : in  std_logic; 
    delta_t     : in  std_logic_vector(31 downto 0);  
    start_euler : in  std_logic;
    x0          : in  std_logic_vector(31 downto 0);
    xf          : in  std_logic_vector(31 downto 0);
    x1          : out std_logic_vector(31 downto 0);
    ready_euler : out std_logic
  );
end entity Euler;

architecture rtl of Euler is

  -- FPU接口信号
  signal opa, opb, y : std_logic_vector(31 downto 0);
  signal op          : std_logic_vector(2 downto 0);
  signal start_i     : std_logic := '0';
  signal fpu_ready   : std_logic;

  -- FSM State
  type state_t is (IDLE, E_MUL1_WAIT, E_ADD2_WAIT, DONE);
  signal st : state_t := IDLE;

begin  

  u_fpu: entity work.fpu
    port map(
      clk_i    => clk_i,
      opa_i    => opa,
      opb_i    => opb,
      fpu_op_i => op,
      rmode_i  => "00",
      start_i  => start_i,
      output_o => y,
      ready_o  => fpu_ready
    );

  -- FSM 主体
  process(clk_i)
  begin

    if rising_edge(clk_i) then
      start_i     <= '0';   -- 默认保持低
      ready_euler <= '0';   -- 默认保持低
      case st is
        when IDLE =>
          if start_euler = '1' then
            opa     <= delta_t;
            opb     <= xf;
            op      <= "010"; -- MUL
            start_i <= '1';
            st      <= E_MUL1_WAIT;
          end if;

        when E_MUL1_WAIT =>
          if fpu_ready = '1' then
            opa     <= y;
            opb     <= x0;
            op      <= "000"; -- ADD
            start_i <= '1';
            st      <= E_ADD2_WAIT;
          end if;

        when E_ADD2_WAIT =>
          if fpu_ready = '1' then
            x1          <= y;
            ready_euler <= '1';
            st          <= DONE;
          end if;

        when DONE =>
          st <= IDLE;

        when others =>
          st <= IDLE;
      end case;
    end if;
  end process;

end architecture rtl;
