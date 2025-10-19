library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.para.all;

entity circuit is
  port(
    clk    : in  std_logic;
    rst    : in  std_logic;
    start  : in  std_logic;
    done_1 : out std_logic;
    -- 四个状态变量（对外只读）
    uC1    : out std_logic_vector(31 downto 0);
    uC2    : out std_logic_vector(31 downto 0);
    iL1    : out std_logic_vector(31 downto 0);
    iL2    : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of circuit is

  --------------------------------------------------------------------
  -- 状态量寄存器 & 中间量
  --------------------------------------------------------------------
  signal uC1_r, uC2_r, iL1_r, iL2_r : std_logic_vector(31 downto 0) := (others => '0');

  -- 四个导数：duC1/dt, duC2/dt, diL1/dt, diL2/dt
  signal f1, f2, f3, f4 : std_logic_vector(31 downto 0) := (others => '0');

  -- Euler 输入
  signal x, f          : std_logic_vector(31 downto 0) := (others => '0');

  -- tanh 输入
  signal z             : std_logic_vector(31 downto 0) := (others => '0');

  -- Eq1 左半项暂存： (VS-uC1)/RC1
  signal eq1_left      : std_logic_vector(31 downto 0) := (others => '0');
 
  -- 方便在波形里确认 para 是否正确（可选）
  signal K_RC1_s, K_C1_s, K_C2_s, K_L1_s, K_L2_s, VTH_s, K_VTH_s, VS_s, K_BETA_s, DT_s
    : std_logic_vector(31 downto 0);

  --------------------------------------------------------------------
  -- FPU / TANH / EULER 接口
  --------------------------------------------------------------------
  signal opa, opb, y : std_logic_vector(31 downto 0);
  signal op          : std_logic_vector(2 downto 0);
  signal start_i     : std_logic := '0';
  signal ready       : std_logic;

  signal start_t     : std_logic := '0';
  signal ready_t     : std_logic;
  signal tanh_o      : std_logic_vector(31 downto 0);

  signal start_e     : std_logic := '0';
  signal ready_e     : std_logic;
  signal euler_o     : std_logic_vector(31 downto 0);

  signal done_int    : std_logic := '0';

  --------------------------------------------------------------------
  -- 一次性初始化 & start 上升沿检测
  --------------------------------------------------------------------
  signal init_done : std_logic := '0';
  signal start_d1, start_d2, start_p : std_logic := '0';

  --------------------------------------------------------------------
  -- FSM
  --------------------------------------------------------------------
  type state_t is (
    IDLE,
    -- Eq1: duC1/dt = (VS-uC1)/RC1 - (iL1+iL2)/C1
    EQ1_SUB1_WAIT,   -- VS - uC1
    EQ1_MUL2_WAIT,   -- * (1/RC1) => eq1_left
    EQ1_ADD3_WAIT,   -- iL1 + iL2
    EQ1_MUL4_WAIT,   -- * (1/C1)
    EQ1_SUB5_WAIT,   -- f1 = eq1_left - 上一步
    -- Eq3: diL1/dt = (uC1 - VTH)/L1
    EQ3_SUB1_WAIT,   -- uC1 - VTH
    EQ3_MUL2_WAIT,   -- * (1/L1) => f3
    -- Eq4: diL2/dt = (uC1 - uC2)/L2
    EQ4_SUB1_WAIT,   -- uC1 - uC2
    EQ4_MUL2_WAIT,   -- * (1/L2) => f4
    -- Eq2: duC2/dt = (iL2 - β·Γ(iL1)·tanh(uC2/(2Vth)))/C2
    EQ2_MUL1_WAIT,   -- uC2 * (1/(2Vth))
    EQ2_TANH_WAIT,   -- tanh(...)
    EQ2_MUL2_WAIT,   -- β * tanh(...)
    EQ2_MUL3_WAIT,   -- Γ(iL1) * 上一步
    EQ2_SUB4_WAIT,   -- iL2 - 上一步
    EQ2_MUL5_WAIT,   -- * (1/C2) => f2
    -- Euler 串行 4 次
    EULER_EQ1_WAIT,  -- uC1 <- uC1 + dt*f1
    EULER_EQ2_WAIT,  -- uC2 <- uC2 + dt*f2
    EULER_EQ3_WAIT,  -- iL1 <- iL1 + dt*f3
    EULER_EQ4_WAIT,  -- iL2 <- iL2 + dt*f4
    DONE
  );
  signal st : state_t := IDLE;

begin
  --------------------------------------------------------------------
  -- 常量镜像（便于波形检查）
  --------------------------------------------------------------------
  K_RC1_s  <= K_RC1;  K_C1_s <= K_C1;  K_C2_s <= K_C2;
  K_L1_s   <= K_L1;   K_L2_s <= K_L2;  VTH_s  <= VTH;
  K_VTH_s  <= K_VTH;  VS_s   <= VS;    K_BETA_s <= K_BETA;
  DT_s     <= DT;

  --------------------------------------------------------------------
  -- 实例化
  --------------------------------------------------------------------
  uut: entity work.fpu
    port map(
      clk_i    => clk,
      opa_i    => opa,
      opb_i    => opb,
      fpu_op_i => op,
      rmode_i  => "00",
      start_i  => start_i,
      output_o => y,
      ready_o  => ready
    );

  u_tanh: entity work.tanh_unit
    port map(
      clk_i      => clk,
      z_in       => z,
      start_tanh => start_t,
      tanh_out   => tanh_o,
      ready_tanh => ready_t,
      rst        => rst
    );

  u_euler: entity work.Euler
    port map(
      clk_i       => clk,
      delta_t     => DT,
      start_euler => start_e,
      xf          => f,
      x0          => x,
      x1          => euler_o,
      ready_euler => ready_e
    );

  --------------------------------------------------------------------
  -- 主时序（同步复位 + 一次性初始化 + start 上升沿触发）
  --------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      -- 默认 1clk 脉冲风格
      start_i  <= '0';
      start_t  <= '0';
      start_e  <= '0';
      done_int <= '0';

      -- 同步复位：清零 & 准备重新初始化
      if rst = '1' then
        st        <= IDLE;
        init_done <= '0';
        uC1_r <= (others=>'0'); uC2_r <= (others=>'0');
        iL1_r <= (others=>'0'); iL2_r <= (others=>'0');
        f1 <= (others=>'0'); f2 <= (others=>'0'); f3 <= (others=>'0'); f4 <= (others=>'0');
        eq1_left <= (others=>'0');
        x  <= (others=>'0');  f  <= (others=>'0');  z  <= (others=>'0');
        opa <= (others=>'0'); opb <= (others=>'0'); op <= (others=>'0');
      else
        -- start 上升沿检测
        start_d1 <= start;
        start_d2 <= start_d1;
        start_p  <= start_d1 and not start_d2;

        case st is
          ----------------------------------------------------------------
          when IDLE =>
            if init_done = '0' then
              -- 只在上电/复位后来一次
              uC1_r    <= x"3F19999A"; -- 0.6
              uC2_r    <= x"3F19999A"; -- 0.6
              iL1_r    <= x"38D1B717"; -- 0.0006
              iL2_r    <= x"38D1B717"; -- 0.0006
              f1 <= (others=>'0'); f2 <= (others=>'0'); f3 <= (others=>'0'); f4 <= (others=>'0');
              eq1_left <= (others=>'0');
              x  <= (others=>'0');  f  <= (others=>'0');  z  <= (others=>'0');
              opa <= (others=>'0'); opb <= (others=>'0'); op <= (others=>'0');
              init_done <= '1';
             
            elsif start_p = '1' then
              st <= EQ1_SUB1_WAIT;
            end if;

          ----------------------------------------------------------------
          -- Eq1: VS - uC1
          when EQ1_SUB1_WAIT =>
            opa     <= VS;
            opb     <= uC1_r;
            op      <= "001";   -- SUB
            start_i <= '1';
            st      <= EQ1_MUL2_WAIT;

          -- * (1/RC1) => eq1_left
          when EQ1_MUL2_WAIT =>
            if ready='1' then
                    
              opa      <= y;   
              opb      <= K_RC1;
              op       <= "010";     -- MUL
              start_i  <= '1';
              st       <= EQ1_ADD3_WAIT;  
            end if;

          -- (iL1 + iL2) 
          when EQ1_ADD3_WAIT =>
            if ready='1' then
              eq1_left     <= y;          
              opb     <= iL1_r;       -- 1/C1
              opa     <= iL2_r;
              op      <= "000";      -- ADD
              start_i <= '1';
              st      <= EQ1_MUL4_WAIT;
            end if;
--(iL1 + iL2) * (1/C1)
          when  EQ1_MUL4_WAIT =>
            if ready='1' then
            opa      <= y;
            opb      <= K_C1;
            op       <= "010";--MIL
            start_i <= '1';
            st      <= EQ1_SUB5_WAIT;
            end if;
        -- f1 = eq1_left - 上一步
          when EQ1_SUB5_WAIT =>
            if ready='1' then
              opa     <= eq1_left;
              opb     <= y;          -- (iL1+iL2)/C1
              op      <= "001";      -- SUB
              start_i <= '1';
              st      <= EQ3_SUB1_WAIT;
            end if;

          ----------------------------------------------------------------
          -- Eq3: (uC1 - VTH) * (1/L1) => f3
          when EQ3_SUB1_WAIT =>
            if ready='1' then
              f1      <= y;       
              opa     <= uC1_r;
              opb     <= VTH;
              op      <= "001";      -- uC1 - VTH
              start_i <= '1';
              st      <= EQ3_MUL2_WAIT;
            end if;

          when EQ3_MUL2_WAIT =>
            if ready='1' then
              opa     <= y;          -- y = uC1 - VTH
              opb     <= K_L1;       -- 1/L1
              op      <= "010";      -- MUL
              start_i <= '1';
              st      <= EQ4_SUB1_WAIT;
            end if;

          ----------------------------------------------------------------
          -- Eq4: (uC1 - uC2) * (1/L2) => f4
          when EQ4_SUB1_WAIT =>
            if ready='1' then
              f3      <= y;          -- y = (uC1 - VTH)/L1
              opa     <= uC1_r;
              opb     <= uC2_r;
              op      <= "001";      -- uC1 - uC2
              start_i <= '1';
              st      <= EQ4_MUL2_WAIT;
            end if;

          when EQ4_MUL2_WAIT =>
            if ready='1' then
              opa     <= y;          -- y = uC1 - uC2
              opb     <= K_L2;       -- 1/L2
              op      <= "010";
              start_i <= '1';
              st      <= EQ2_MUL1_WAIT;
            end if;

          ----------------------------------------------------------------
          -- Eq2: uC2/(2Vth) -> tanh -> β*… -> Γ(iL1)*… -> iL2 - … -> * 1/C2 => f2
          when EQ2_MUL1_WAIT =>
            if ready='1' then
              f4      <= y;          -- y = (uC1 - uC2)/L2
              opa     <= uC2_r;
              opb     <= K_VTH;      -- 1/(2*Vth)
              op      <= "010";      -- MUL
              start_i <= '1';
              st      <= EQ2_TANH_WAIT;
            end if;

          when EQ2_TANH_WAIT =>
            if ready='1' then
              z       <= y;          -- tanh 输入
              start_t <= '1';
              st      <= EQ2_MUL2_WAIT;
            end if;

          when EQ2_MUL2_WAIT =>
            if ready_t='1' then
              opa     <= tanh_o;
              opb     <= K_BETA;
              op      <= "010";      -- β * tanh(...)
              start_i <= '1';
              st      <= EQ2_MUL3_WAIT;
            end if;

          when EQ2_MUL3_WAIT =>
            if ready='1' then
              -- Γ(iL1): iL1>=0 ? iL1 : 0
              opa     <= y;          -- 现在是 β*tanh(...)
              if iL1_r(31)='0' then
                opb   <= iL1_r;
              else
                opb   <= (others=>'0');
              end if;
              op      <= "010";      -- Γ(iL1) * (β*tanh)
              start_i <= '1';
              st      <= EQ2_SUB4_WAIT;
            end if;

          when EQ2_SUB4_WAIT =>
            if ready='1' then
              opa     <= iL2_r;
              opb     <= y;          -- Γ(iL1)*(β*tanh)
              op      <= "001";      -- iL2 - …
              start_i <= '1';
              st      <= EQ2_MUL5_WAIT;
            end if;

          when EQ2_MUL5_WAIT =>
            if ready='1' then
              opa     <= y;          -- 上一步结果
              opb     <= K_C2;       -- 1/C2
              op      <= "010";      -- => f2
              start_i <= '1';
              st      <= EULER_EQ1_WAIT;
            end if;

          ----------------------------------------------------------------
          -- Euler 串行四步
          when EULER_EQ1_WAIT =>
            if ready='1' then
              f2      <= y;          -- duC2/dt
              x       <= uC1_r;  
              f       <= f1;
              start_e <= '1';
              st      <= EULER_EQ2_WAIT;
            end if;

          when EULER_EQ2_WAIT =>
            if ready_e='1' then
              uC1_r   <= euler_o;
              x       <= uC2_r;  
              f       <= f2;
              start_e <= '1';
              st      <= EULER_EQ3_WAIT;
            end if;

          when EULER_EQ3_WAIT =>
            if ready_e='1' then
              uC2_r   <= euler_o;
              x       <= iL1_r; 
              f       <= f3;
              start_e <= '1';
              st      <= EULER_EQ4_WAIT;
            end if;

          when EULER_EQ4_WAIT =>
            if ready_e='1' then
              iL1_r   <= euler_o;
              x       <= iL2_r; 
              f       <= f4;
              start_e <= '1';
              st      <= DONE;
            end if;

          when DONE =>
            if ready_e='1' then
              iL2_r   <= euler_o;
              done_int <= '1';       -- 1clk 脉冲
              st      <= IDLE;
            end if;

          when others =>
            st <= IDLE;
        end case;
      end if; -- rst
    end if; -- rising_edge
  end process;

  --------------------------------------------------------------------
  -- 端口映射
  --------------------------------------------------------------------
  done_1 <= done_int;
  uC1 <= uC1_r;  uC2 <= uC2_r;  iL1 <= iL1_r;  iL2 <= iL2_r;

end architecture;

