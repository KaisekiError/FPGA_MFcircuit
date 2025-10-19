library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.para.all;

entity tanh_unit is
  port(
    clk_i       : in  std_logic;
    rst        : in  std_logic;
    start_tanh : in  std_logic;
    z_in       : in  std_logic_vector(31 downto 0);  -- 输入 z
    ready_tanh : out std_logic;                      -- 输出 ready
    tanh_out   : out std_logic_vector(31 downto 0)   -- 输出 tanh(z)
  );
end entity;

architecture rtl of tanh_unit is


  --------------------------------------------------------------------
  -- FPU 接口信号
  --------------------------------------------------------------------
  signal opa, opb, y : std_logic_vector(31 downto 0);
  signal op          : std_logic_vector(2 downto 0);
  signal start_i     : std_logic := '0';
  signal fpu_ready   : std_logic;

  --------------------------------------------------------------------
  -- 内部寄存器
  --------------------------------------------------------------------
  signal z, z2, num, den, r : std_logic_vector(31 downto 0) := (others => '0');

  --------------------------------------------------------------------
  -- 状态定义
  --------------------------------------------------------------------
  type state_t is (
    IDLE,
    -- TANH 1: z2 = z*z
     S_MUL1_WAIT,
    -- TANH 2: num = 27 + z2
     S_ADD2_WAIT,
    -- TANH 3: t0 = 9*z2
    S_MUL3_WAIT,
    -- TANH4: den = 27 + t0
     S_ADD4_WAIT,
    -- TANH 5: r = num/den
     S_DIV5_WAIT,
    -- TANH6: tanh = z*r
    S_MUL6, S_MUL6_WAIT,
    DONE
  );
  signal st : state_t := IDLE;

begin

  --------------------------------------------------------------------
  -- FPU 实例化
  --------------------------------------------------------------------
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

  --------------------------------------------------------------------
  -- FSM 主体
  --------------------------------------------------------------------
  process(clk_i, rst)
  begin
    if rst = '1' then
      st         <= IDLE;
      start_i    <= '0';
      ready_tanh <= '0';
      tanh_out   <= (others => '0');
    elsif rising_edge(clk_i) then
      start_i    <= '0';  -- 默认保持低
      ready_tanh <= '0';  -- 默认保持低

      case st is

        when IDLE =>
          if start_tanh = '1' then
            z  <= z_in;
            -- Step1: z2 = z*z
            opa     <= z_in;
            opb     <= z_in;
            op      <= "010"; -- MUL
            start_i <= '1';
            st      <= S_MUL1_WAIT;
          end if;

        when S_MUL1_WAIT =>
          if fpu_ready = '1' then
            z2 <= y;
            -- Stepout num = 27 + z2
            opa     <= CONST27;
            opb     <= z2;
            op      <= "000"; -- ADD
            start_i <= '1';
            st      <= S_ADD2_WAIT;
          end if;

        when S_ADD2_WAIT =>
          if fpu_ready = '1' then
            num <= y;
            -- Step3: t0 = 9*z2
            opa     <= CONST9;
            opb     <= z2;
            op      <= "010"; -- MUL
            start_i <= '1';
            st      <= S_MUL3_WAIT;
          end if;

        when S_MUL3_WAIT =>
          if fpu_ready = '1' then
            -- Step4: den = 27 + t0
            opa     <= CONST27;
            opb     <= y;     -- t0
            op      <= "000"; -- ADD
            start_i <= '1';
            st      <= S_ADD4_WAIT;
          end if;

        when S_ADD4_WAIT =>
          if fpu_ready = '1' then
            den <= y;
            -- Step5: r = num/den
            opa     <= num;
            opb     <= den;
            op      <= "011"; -- DIV
            start_i <= '1';
            st      <= S_DIV5_WAIT;
          end if;

        when S_DIV5_WAIT =>
          if fpu_ready = '1' then
            r <= y;
            -- Step6: tanh = z*r
            opa     <= z;
            opb     <= r;
            op      <= "010"; -- MUL
            start_i <= '1';
            st      <= S_MUL6_WAIT;
          end if;

        when S_MUL6_WAIT =>
          if fpu_ready = '1' then
            tanh_out   <= y;
            ready_tanh <= '1';  -- 模块输出 ready
            st         <= DONE;
          end if;
        
        when DONE =>
          st <= IDLE;

        when others =>
          st <= IDLE;

      end case;
    end if;
  end process;

end architecture;
