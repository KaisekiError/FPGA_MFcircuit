library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.para.all;

entity uC1_circuit is
  port(
    clk      : in  std_logic;
    rst      : in  std_logic;
    start    : in  std_logic;
    done_uc1 : out std_logic;
    uC1_in   : in  std_logic_vector(31 downto 0);
    iL1_in   : in  std_logic_vector(31 downto 0);
    iL2_in   : in  std_logic_vector(31 downto 0);
    uC1_out  : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of uC1_circuit is
  --------------------------------------------------------------------
  -- FPU signals
  --------------------------------------------------------------------
  -- FSM1 
  signal add1_a, add1_b, add1_y : std_logic_vector(31 downto 0);
  signal op_1                   : std_logic; -- 0:add, 1:sub
  signal mul1_a, mul1_b, mul1_y : std_logic_vector(31 downto 0);

  -- FSM2 
  signal add2_a, add2_b, add2_y : std_logic_vector(31 downto 0);
  signal op_2                   : std_logic;
  signal mul2_a, mul2_b, mul2_y : std_logic_vector(31 downto 0);

  signal rstn : std_logic;

  --------------------------------------------------------------------
  -- counters & flags
  --------------------------------------------------------------------
  signal cnt1    : integer range 0 to 3 := 0;
  signal cnt2    : integer range 0 to 3 := 0;
  signal done_1  : std_logic := '0';
  signal done_2  : std_logic := '0';

  --------------------------------------------------------------------
  -- FSM states
  --------------------------------------------------------------------
  type state_uC_1 is (
    IDLE,
    --FPU1
    EQ1_SUB1_WAIT_1,
    EQ1_MUL2_WAIT_1,
    --WHOLE
    EQ1_SUB3_WAIT_1,
    EQ1_ADD4_WAIT_1,
    DONE_STATE_1
  );
  signal st_1 : state_uC_1 := IDLE;

  type state_uC_2 is (
    IDLE,
    --FPU2
    EQ1_ADD1_WAIT_2,
    EQ1_MUL2_WAIT_2,
    DONE_STATE_2
  );
  signal st_2 : state_uC_2 := IDLE;

begin
  rstn <= not rst;
  --------------------------------------------------------------------
  -- FPU instances
  --------------------------------------------------------------------
  u_addsub1: entity work.FP_Add_Sub_Top
    port map(
      clk    => clk,
      rstn   => rstn,
      op     => op_1,
      data_a => add1_a,
      data_b => add1_b,
      result => add1_y
    );

  u_addsub2: entity work.FP_Add_Sub_Top
    port map(
      clk    => clk,
      rstn   => rstn,
      op     => op_2,
      data_a => add2_a,
      data_b => add2_b,
      result => add2_y
    );

  u_mul1: entity work.FP_Mult_Top
    port map(
      clk    => clk,
      rstn   => rstn,
      data_a => mul1_a,
      data_b => mul1_b,
      result => mul1_y
    );

  u_mul2: entity work.FP_Mult_Top
    port map(
      clk    => clk,
      rstn   => rstn,
      data_a => mul2_a,
      data_b => mul2_b,
      result => mul2_y
    );

  -------------------------------------------------------------------
  -- Main Process
  -------------------------------------------------------------------
  process(clk, rst)
  begin
    if rst = '1' then
      st_1      <= IDLE;
      st_2      <= IDLE;
      cnt1      <= 0;
      cnt2      <= 0;
      done_1    <= '0';
      done_2    <= '0';
      done_uc1  <= '0';
    elsif rising_edge(clk) then

      case st_2 is
        when IDLE =>
          if start = '1' then
            done_2 <= '0';
            add2_a <= iL1_in;
            add2_b <= iL2_in;
            op_2 <= '0'; 
            cnt2 <= 1;  --
            st_2 <= EQ1_ADD1_WAIT_2;
          end if;

        when EQ1_ADD1_WAIT_2 =>
          cnt2 <= cnt2 + 1;
          if cnt2 = 3 then
            mul2_a <= add2_y;
            mul2_b <= K_C1;
            cnt2 <= 1; --
            st_2 <= EQ1_MUL2_WAIT_2;
          end if;

        when EQ1_MUL2_WAIT_2 =>
          cnt2 <= cnt2 + 1;
          if cnt2 = 3 then
            done_2 <= '1';
            cnt2 <= 0;
            st_2 <= DONE_STATE_2;
          end if;

        when DONE_STATE_2 =>
          st_2 <= IDLE;

        when others =>
          st_2 <= IDLE;
      end case;


      case st_1 is
        when IDLE =>
          if start = '1' then
            done_uc1 <= '0';
            done_1   <= '0';
            add1_a <= VS;
            add1_b <= uC1_in;
            op_1 <= '1';
            cnt1 <= 1;  --
            st_1 <= EQ1_SUB1_WAIT_1;
          end if;

        when EQ1_SUB1_WAIT_1 =>
          cnt1 <= cnt1 + 1;
          if cnt1 = 3 then
            mul1_a <= add1_y;
            mul1_b <= K_RC1;
            cnt1 <= 1;  --
            st_1 <= EQ1_MUL2_WAIT_1;
          end if;

        when EQ1_MUL2_WAIT_1 =>
          cnt1 <= cnt1 + 1;
          if cnt1 = 3 then
            done_1 <= '1';
            cnt1 <= 0;
          end if;
          if (done_1 = '1') and (done_2 = '1') and (cnt1 = 0) then
            add1_a <= mul1_y;
            add1_b <= mul2_y;
            op_1 <= '1';
            cnt1 <= 1;  --
            st_1 <= EQ1_SUB3_WAIT_1;
          end if;

        when EQ1_SUB3_WAIT_1 =>
          done_1 <= '0';
          done_2 <= '0';
          cnt1 <= cnt1 + 1;
          if cnt1 = 3 then
            add1_a <= add1_y;
            add1_b <= uC1_in;
            op_1 <= '0';
            cnt1 <= 1; --
            st_1 <= EQ1_ADD4_WAIT_1;
          end if;

        when EQ1_ADD4_WAIT_1 =>
          cnt1 <= cnt1 + 1;
          if cnt1 = 3 then
            uC1_out <= add1_y;
            done_uc1 <= '1';
            cnt1 <= 0;
            st_1 <= DONE_STATE_1;
          end if;

        when DONE_STATE_1 =>
          st_1 <= IDLE;

        when others =>
          st_1 <= IDLE;
      end case;

    end if;
  end process;

end architecture;
