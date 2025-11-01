library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.para.all;

entity il2_circuit is
  port(
    clk       : in  std_logic;
    rst       : in  std_logic;
    start     : in  std_logic;
    done_iL2  : out std_logic;  
    uC1_in    : in  std_logic_vector(31 downto 0);
    uC2_in    : in  std_logic_vector(31 downto 0);
    iL2_in    : in  std_logic_vector(31 downto 0);
    iL2_out   : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of il2_circuit is

  --------------------------------------------------------------------
  -- FPU signals
  --------------------------------------------------------------------
  signal add_a, add_b, add_y : std_logic_vector(31 downto 0);
  signal mul_a, mul_b, mul_y : std_logic_vector(31 downto 0);
  signal op              : std_logic; -- 0:add, 1:sub
  signal rstn : std_logic;

  --------------------------------------------------------------------
  -- FSM states
  --------------------------------------------------------------------
  type state_il2 is (
    IDLE,
    EQ4_SUB1_WAIT,
    EQ4_MUL2_WAIT,
    EQ4_ADD3_WAIT,
    DONE
  );
  signal st : state_il2 := IDLE;

  signal cnt : integer range 0 to 3 := 0;

begin
  rstn <= not rst;
  --------------------------------------------------------------------
  -- FPU instances
  --------------------------------------------------------------------
  u_addsub: entity work.FP_Add_Sub_Top
    port map(
      clk    => clk,
      rstn   => rstn,
      op     => op,
      data_a => add_a,
      data_b => add_b,
      result => add_y
    );

  u_mul: entity work.FP_Mult_Top
    port map(
      clk    => clk,
      rstn   => rstn,
      data_a => mul_a,
      data_b => mul_b,
      result => mul_y
    );

  --------------------------------------------------------------------
  -- FSM
  --------------------------------------------------------------------
  process(clk, rst)
  begin
    if rst = '1' then
      st        <= IDLE;
      done_iL2  <= '0';
      cnt       <= 0;
      iL2_out   <= (others => '0');
    elsif rising_edge(clk) then
      case st is

        when IDLE =>
          done_iL2 <= '0';
          if start = '1' then
            add_a   <= uC1_in;
            add_b   <= uC2_in;
            op  <= '1';
            cnt     <= 1;
            st      <= EQ4_SUB1_WAIT;
          end if;

        when EQ4_SUB1_WAIT =>
          cnt <= cnt + 1;
          if cnt = 3 then
            mul_a <= add_y;
            mul_b <= K_L2;
            cnt   <= 1;
            st    <= EQ4_MUL2_WAIT;
          end if;

        when EQ4_MUL2_WAIT =>
          cnt <= cnt + 1;
          if cnt = 3 then
            add_a  <= mul_y;
            add_b  <= iL2_in;
            op <= '0';
            cnt    <= 1;
            st     <= EQ4_ADD3_WAIT;
          end if;

        when EQ4_ADD3_WAIT =>
          cnt <= cnt + 1;
          if cnt = 3 then
            iL2_out  <= add_y;
            done_iL2 <= '1';
            cnt      <= 0;
            st       <= DONE;
          end if;

        when DONE =>
          st <= IDLE;

        when others =>
          st <= IDLE;
      end case;
    end if;
  end process;

end architecture;
