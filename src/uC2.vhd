library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.para.all;

entity uC2_circuit is
  port(
    clk       : in  std_logic;
    rst       : in  std_logic;
    start     : in  std_logic;
    done_uC2  : out std_logic;
    uC2_in    : in  std_logic_vector(31 downto 0);
    iL1_in    : in  std_logic_vector(31 downto 0);
    iL2_in    : in  std_logic_vector(31 downto 0);
    uC2_out   : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of uC2_circuit is

  --------------------------------------------------------------------
  -- intermediate / FPU signals
  --------------------------------------------------------------------
  signal add_a, add_b, add_y : std_logic_vector(31 downto 0);
  signal mul1_a, mul1_b, mul1_y : std_logic_vector(31 downto 0);
  signal mul2_a, mul2_b, mul2_y : std_logic_vector(31 downto 0);
  signal op : std_logic;  -- 0:add, 1:sub
  signal rstn : std_logic;

  --------------------------------------------------------------------
  -- counters / flags
  --------------------------------------------------------------------
  signal cnt1   : integer range 0 to 3 := 0; 
  signal cnt2   : integer range 0 to 3 := 0;
  signal done_1 : std_logic := '0';
  signal done_2 : std_logic := '0'; 
  signal t0     : std_logic_vector(31 downto 0) := (others => '0');

  --------------------------------------------------------------------
  -- FSM states
  --------------------------------------------------------------------
  type state_uC2_1 is (
    IDLE,
    EQ2_MUL1_WAIT_1,
    EQ2_SUB2_WAIT_1,
    EQ2_ADD3_WAIT_1,
    DONE_STATE_1
  );
  signal st_1 : state_uC2_1 := IDLE;

  type state_uC2_2 is (
    IDLE,
    EQ2_MUL1_WAIT_2,
    EQ2_MUL2_WAIT_2,
    DONE_STATE_2
  );
  signal st_2 : state_uC2_2 := IDLE;

begin
  rstn <= not rst;
  --------------------------------------------------------------------
  -- Gowin IP 实例化
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

  --------------------------------------------------------------------
  -- FSM 主进程（极限链式）
  --------------------------------------------------------------------
  process(clk, rst)
  begin
    if rst = '1' then
      st_1    <= IDLE;
      st_2    <= IDLE;
      cnt1    <= 0;
      cnt2    <= 0;
      done_2  <= '0';
      done_uC2 <= '0';
      t0      <= (others => '0');
    elsif rising_edge(clk) then

      case st_2 is
        when IDLE =>
          if start = '1' then
            done_2 <= '0';
            mul2_a <= K_C2;
            if iL1_in(31) = '0' then
              mul2_b <= iL1_in;
            else
              mul2_b <= (others => '0');
            end if;
            cnt2 <= 1;  --
            st_2 <= EQ2_MUL1_WAIT_2;
          end if;

        when EQ2_MUL1_WAIT_2 =>
          cnt2 <= cnt2 + 1;
          if cnt2 = 3 then
            mul2_a <= mul2_y;
            if uC2_in(31) = '1' then  -- uC2 < 0
              mul2_b <= NEG_ONE;
            elsif uC2_in = x"00000000" then
              mul2_b <= (others => '0');
            else
              mul2_b <= ONE;
            end if;
            cnt2 <= 1; --
            st_2 <= EQ2_MUL2_WAIT_2;
          end if;

        when EQ2_MUL2_WAIT_2 =>
          cnt2 <= cnt2 + 1;
          if cnt2 = 3 then
            t0 <= mul2_y;
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
            done_1 <= '0';
            done_uC2 <= '0';
            mul1_a <= iL2_in;
            mul1_b <= K_C2;
            cnt1 <= 1; --
            st_1 <= EQ2_MUL1_WAIT_1;
          end if;

        when EQ2_MUL1_WAIT_1 =>
          cnt1 <= cnt1 + 1;
          if cnt1 = 3 then
            done_1 <= '1';
            cnt1 <= 0;
          end if;
          if (done_1 = '1') and (done_2 = '1') and (cnt1 = 0) then
            add_a <= mul1_y;
            add_b <= t0; 
            op <= '1';
            cnt1 <= 1; --
            st_1 <= EQ2_SUB2_WAIT_1;
          end if;

        when EQ2_SUB2_WAIT_1 =>
          cnt1 <= cnt1 + 1;
          if cnt1 = 3 then
            done_1 <= '0';
            done_2 <= '0';
            add_a <= add_y;
            add_b <= uC2_in;
            op <= '0';
            cnt1 <= 1;  --
            st_1 <= EQ2_ADD3_WAIT_1;
          end if;

        when EQ2_ADD3_WAIT_1 =>
          cnt1 <= cnt1 + 1;
          if cnt1 = 3 then
            uC2_out <= add_y;
            done_uC2 <= '1';
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
