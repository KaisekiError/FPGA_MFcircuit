library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.para.all; 

entity top is
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    start : in  std_logic;

    uC1_in    : in  std_logic_vector(31 downto 0);  -- 初值输入（仅在开始时采样）
    uC2_in    : in  std_logic_vector(31 downto 0);
    iL1_in    : in  std_logic_vector(31 downto 0);
    iL2_in    : in  std_logic_vector(31 downto 0);

    uC1_out   : out std_logic_vector(31 downto 0);  -- 对外可观测的当前状态
    uC2_out   : out std_logic_vector(31 downto 0);
    iL1_out   : out std_logic_vector(31 downto 0);
    iL2_out   : out std_logic_vector(31 downto 0);

    ready     : out std_logic                     -- 每轮完成脉冲
  );
end entity;

architecture rtl of top is
  type st_t is (IDLE, START_ALL, CAL_WAIT, UPDATE, DONE);

  signal st_rk : st_t := IDLE;

  signal done_1, done_2, done_3, done_4 : std_logic;
  signal start_1, start_2, start_3, start_4 : std_logic;
  signal all_done : std_logic;

  -- 顶层状态寄存器（每轮的当前值）
  signal uC1_s, uC2_s, iL1_s, iL2_s : std_logic_vector(31 downto 0);

  -- 子模块计算得到的下一轮值
  signal uC1_next, uC2_next, iL1_next, iL2_next : std_logic_vector(31 downto 0);

begin
  all_done <= done_1 and done_2 and done_3 and done_4;

  -- 对外输出当前状态，便于在波形观察
  uC1_out <= uC1_s;
  uC2_out <= uC2_s;
  iL1_out <= iL1_s;
  iL2_out <= iL2_s;

  -- 子模块实例化：输入接顶层寄存器，输出接 *_next
  u_eq1 : entity work.uC1_circuit
    port map(
      clk        => clk,
      rst        => rst, 
      start      => start_1,
      done_uC1   => done_1,
      uC1_in     => uC1_s,
      iL1_in     => iL1_s,
      iL2_in     => iL2_s,
      uC1_out    => uC1_next
    );

  u_eq2 : entity work.uC2_circuit
    port map(
      clk        => clk,
      rst        => rst, 
      start      => start_2,
      done_uC2   => done_2,
      uC2_in     => uC2_s,
      iL1_in     => iL1_s,
      iL2_in     => iL2_s,
      uC2_out    => uC2_next
    );

  u_eq3 : entity work.il1_circuit
    port map(
      clk        => clk,
      rst        => rst, 
      start      => start_3,
      done_iL1   => done_3,
      uC1_in     => uC1_s,
      iL1_in     => iL1_s,
      iL1_out    => iL1_next
    );

  u_eq4 : entity work.il2_circuit
    port map(
      clk        => clk,
      rst        => rst, 
      start      => start_4,
      done_iL2   => done_4,
      uC1_in     => uC1_s,
      uC2_in     => uC2_s,
      iL2_in     => iL2_s,
      iL2_out    => iL2_next
    );

  process(clk, rst)
  begin
    if rst = '1' then
      st_rk   <= IDLE;
      start_1 <= '0';
      start_2 <= '0';
      start_3 <= '0';
      start_4 <= '0';
      ready   <= '0';

      -- 状态寄存器复位（也可用外部初值）
      uC1_s <= (others => '0');
      uC2_s <= (others => '0');
      iL1_s <= (others => '0');
      iL2_s <= (others => '0');

    elsif rising_edge(clk) then
      -- 默认
      start_1 <= '0';
      start_2 <= '0';
      start_3 <= '0';
      start_4 <= '0';
      ready   <= '0';

      case st_rk is
        when IDLE =>
          -- 在开始时采样外部初值
          if start = '1' then
            uC1_s <= uC1_in;
            uC2_s <= uC2_in;
            iL1_s <= iL1_in;
            iL2_s <= iL2_in;
            st_rk <= START_ALL;
          end if;

        when START_ALL =>
          start_1 <= '1';
          start_2 <= '1';
          start_3 <= '1';
          start_4 <= '1';
          st_rk   <= CAL_WAIT;

        when CAL_WAIT =>
          if all_done = '1' then
            st_rk <= UPDATE;
          end if;

        when UPDATE =>
          -- 同步写入下一轮状态
          uC1_s <= uC1_next;
          uC2_s <= uC2_next;
          iL1_s <= iL1_next;
          iL2_s <= iL2_next;
          st_rk <= DONE;

        when DONE =>
          ready <= '1';      -- 一拍完成指示
          st_rk <= IDLE;     -- 或者改为 START_ALL 继续自动迭代

        when others =>
          st_rk <= IDLE;
      end case;
    end if;
  end process;

end architecture;