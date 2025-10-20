library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.para.all;



entity circuit is
  port(
    clk   : in  std_logic;
    rst   : in  std_logic;
    start : in  std_logic;
    done_1  : out std_logic;  
    -- 四个状态变量
    uC1   : out std_logic_vector(31 downto 0);
    uC2   : out std_logic_vector(31 downto 0);
    iL1   : out std_logic_vector(31 downto 0);
    iL2   : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of circuit is


  --------------------------------------------------------------------
  -- register signal
  --------------------------------------------------------------------
  signal f1, f2, f3, f4 : std_logic_vector(31 downto 0) := (others => '0');
  signal t0, t1, t2     : std_logic_vector(31 downto 0) := (others => '0');
  signal f, x, z: std_logic_vector(31 downto 0) := (others => '0');
  -- 内部 done 信号
  signal done_int : std_logic := '0';
  signal uC1_r, uC2_r, iL1_r, iL2_r : std_logic_vector(31 downto 0) := (others => '0');

  --------------------------------------------------------------------
  -- FPU, TANH signal
  --------------------------------------------------------------------
  signal opa, opb, y : std_logic_vector(31 downto 0);
  signal op          : std_logic_vector(2 downto 0);
  signal start_i     : std_logic := '0';
  signal ready       : std_logic;
  signal start_t     : std_logic := '0';
  signal ready_t     : std_logic;   
  signal tanh_o      : std_logic_vector(31 downto 0);
 

  signal ready_e    : std_logic;
  signal start_e    : std_logic;
  signal euler_o      : std_logic_vector(31 downto 0); 

  --------------------------------------------------------------------
  -- FSM states
 
  type state_t is (
    IDLE,
    -- Eq1
    EQ1_SUB1_WAIT,
    EQ1_MUL2_WAIT,
    EQ1_ADD3_WAIT,
    EQ1_MUL4_WAIT,
    EQ1_SUB5_WAIT,
    -- Eq2
    EQ3_SUB1_WAIT,
    EQ3_MUL2_WAIT,
    -- Eq4
    EQ4_SUB1_WAIT,
    EQ4_MUL2_WAIT,
    -- Eq2 
    EQ2_MUL1_WAIT,
    EQ2_TANH_WAIT,
    EQ2_MUL2_WAIT,
    EQ2_MUL3_WAIT,
    EQ2_SUB4_WAIT,
    EQ2_MUL5_WAIT,
    -- Euler
    Euler_EQ1_WAIT,
    Euler_EQ2_WAIT,
    Euler_EQ3_WAIT,
    Euler_EQ4_WAIT,
    DONE
);

  signal st : state_t := IDLE;

begin


  -- FPU 实例化

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
 -- tanh实例化

  u_tanh: entity work.tanh_unit
    port map(
      clk_i    => clk,
      z_in    => z,
      start_tanh  => start_t,
      tanh_out => tanh_o,
      ready_tanh  => ready_t,
      rst => rst   

 );

u_euler: entity work.Euler
  port map (
    clk_i       => clk,
    delta_t     => DT,     
    start_euler => start_e,
    xf          => f,     -- 导数
    x0          => x,     --原始变量
    x1          => euler_o,-- 更新结果
    ready_euler => ready_e
  );


  -------------------------------------------------------------------
  --FSM 主进程

  process(clk, rst)
  begin
    if rst = '1' then
      st       <= IDLE;
      start_i  <= '0';
      done_int <= '0';
      start_e <= '0';--同上
      start_t <= '0';
      uC1_r <= (others => '0');
      uC2_r <= (others => '0');
      iL1_r <= (others => '0');
      iL2_r <= (others => '0');   
      f1 <= (others => '0');
      f2 <= (others => '0');
      f3 <= (others => '0');
      f4 <= (others => '0');
      t0 <= (others => '0');
      t1 <= (others => '0');
      t2 <= (others => '0');
      f <= (others => '0');
      x <= (others => '0');
      z <= (others => '0');
    elsif rising_edge(clk) then
      start_i  <= '0';   -- 默认 0
      done_int <= '0';   -- 同上
      start_e <= '0';--同上
      start_t <= '0';   

      case st is

        when IDLE =>
          if start = '1' then
            st <= EQ1_SUB1_WAIT; 
            end if;
            -- TODO: Eq1:VS - uC1
        when EQ1_SUB1_WAIT =>            
            opa <= VS;
            opb <= uC1_r;
            op <= "001";--SUB
            start_i <= '1';
            st <= EQ1_MUL2_WAIT;
            -- TODO: Eq1:(VS - uC1)/(RC1)
       when EQ1_MUL2_WAIT =>
           if ready ='1' then
               t0 <= y;
               opa <= t0;
               opb <= K_RC1;
               op <="010";--MUL
               start_i <='1';
               st <= EQ1_ADD3_WAIT ;
           end if;          
              -- TODO: Eq1:iL1+iL2
      when EQ1_ADD3_WAIT =>
          if ready ='1'then
                t0 <= y;
                opa <= iL1_r;
                opb <= iL2_r;
                op <="000";--ADD
                start_i <='1';
                st <= EQ1_MUL4_WAIT;
           end if; 
 -- TODO: Eq1:(iL1+iL2)/C1
      when EQ1_MUL4_WAIT =>
           if ready ='1'then
                t1 <= y;
                opa <=t1;
                opb <= K_C1;
                OP <="010";--MUL
                start_i <= '1';
                st <= EQ1_SUB5_WAIT;         
           end if;
  -- TODO: Eq1:(VS - uC1)/(RC1)-(iL1+iL2)/C1          
      when EQ1_SUB5_WAIT =>
           if ready ='1'then
               t1 <= y;
               opa <= t0;
               opb <= t1;
               op <="001";--sub
               start_i <= '1';
               st <= EQ3_SUB1_WAIT;          
           end if;
 --TODO: EQ3: uC1-VTH
      when EQ3_SUB1_WAIT =>
           if ready = '1'then 
               f1 <= y;         --把导数存起来
               opa <= uC1_r;
               opb <= VTH;
               op <="001";--sub
               start_i <= '1';
               st <= EQ3_MUL2_WAIT;
           end if;
 --TODO: EQ3: (uC1-VTH)/L1
      when EQ3_MUL2_WAIT =>
           if ready ='1' then
               t0 <= y;
               opa <= t0;
               opb <= K_L1;
               op <= "010";--MUL
               start_i <='1';
               st <= EQ4_SUB1_WAIT;
           end if;
 --TODO: EQ4: uC1-uC2
      when EQ4_SUB1_WAIT =>
           if ready = '1'then 
               f3 <= y;             --把导数存起来
               opa <= uC1_r;
               opb <=uC2_r;
               op <="001";--sub
               start_i <= '1';
               st <= EQ4_MUL2_WAIT;
           end if;
 --TODO: EQ4: (uC1-uC2)/L2
      when EQ4_MUL2_WAIT =>
           if ready ='1' then
                t0 <= y;
                opa <= t0;
                opb <= K_L2;
                op <= "010" ;--MUL
                start_i <='1';
                st <= EQ2_MUL1_WAIT;
           end if;

--TODO :EQ2: uc2/2VTH
      when EQ2_MUL1_WAIT =>
           if ready ='1'then
                f4 <= y;    --把导数存起来
                opa <= uc2_r;
                opb <= K_VTH;
                op <= "010";--MUL 
                start_i <='1'; 
                st <= EQ2_TANH_WAIT;
           end if;
--TODO :EQ2: tanh
      when EQ2_TANH_WAIT =>
           if ready ='1'then
                z <= y;
                start_t <='1';
                st <= EQ2_MUL2_WAIT;
           end if;
--TODO :EQ2: beta*tanh
      when EQ2_MUL2_WAIT =>
           if ready_t ='1'then
                
                opa <= tanh_o;
                opb <= K_BETA;
                op <= "010";--MUL 
                start_i <='1';
                st <= EQ2_MUL3_WAIT;
           end if;
--TODO :EQ2: iL1*beta*tanh
      when EQ2_MUL3_WAIT =>
           if ready ='1'then
                opa <= y;
                if iL1_r(31) = '0' then
               -- iL1 >= 0
                    opb <= iL1_r;
                else
               -- iL1 < 0
                    opb <= (others => '0');
               end if;
                op <= "010" ;
                start_i <='1';
                st <= EQ2_SUB4_WAIT;
            end if;
--TODO :EQ2: il2-一坨结果
      when EQ2_SUB4_WAIT =>
           if ready ='1'then
                opa <= iL2_r;
                opb <= y;
                op <= "001"; 
                start_i <='1';
                st <= EQ2_MUL5_WAIT;
           end if;
--TODO :EQ2: 一坨/L2
      when EQ2_MUL5_WAIT =>
           if ready ='1'then
                opa <= y;
                opb <= K_L2;
                op <= "010"; 
                start_i <='1';
                st <= Euler_EQ1_WAIT;
           end if;
--ToDO :Euler 

        when Euler_EQ1_WAIT =>
          if ready ='1'then
          f2 <= y;
          x <= uC1_r;
          f <= f1;
          start_e <= '1';
          st <= Euler_EQ2_WAIT;
        end if;

        when Euler_EQ2_WAIT =>
          if ready_e ='1'then
          uC1_r <= euler_o;
          x <= uC2_r;
          f <= f2;
          start_e <= '1';
          st <= Euler_EQ3_WAIT;
        end if;

         when Euler_EQ3_WAIT =>
          if ready_e ='1'then
          uC2_r <= euler_o;
          x <= iL1_r;
          f <= f3;
          start_e <= '1';
          st <= Euler_EQ4_WAIT;
        end if;

        when Euler_EQ4_WAIT =>
          if ready_e ='1'then
          iL1_r <= euler_o;
          x <= iL2_r;
          f <= f4;
          start_e <= '1';
          st <= DONE;
        end if;
        when DONE =>
         if ready_e ='1'then
         iL2_r <= euler_o;         
         done_int <= '1';
         st       <= IDLE;
          end if;          
          
                               
        when others => 
          st <= IDLE;
          
      end case;
    end if;
  end process;

  -- 内部信号驱动外部端口
  done_1 <= done_int;

  uC1 <= uC1_r;
  uC2 <= uC2_r;
  iL1 <= iL1_r;
  iL2 <= iL2_r;

end architecture;