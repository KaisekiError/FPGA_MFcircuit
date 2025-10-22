library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.para.all;


entity derivative is
  port(
    clk   : in  std_logic;
    rst   : in  std_logic;
    start : in  std_logic;
    done_1  : out std_logic;  
    
    uC1_in    : in std_logic_vector(31 downto 0);
    uC2_in    : in std_logic_vector(31 downto 0);
    iL1_in    : in std_logic_vector(31 downto 0);
    iL2_in    : in std_logic_vector(31 downto 0);
    uC1_out   : out std_logic_vector(31 downto 0);
    uC2_out   : out std_logic_vector(31 downto 0);
    iL1_out   : out std_logic_vector(31 downto 0);
    iL2_out   : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of derivative is


  --------------------------------------------------------------------
  -- register signal
  --------------------------------------------------------------------
  signal t0, t1    : std_logic_vector(31 downto 0) := (others => '0');
  signal z: std_logic_vector(31 downto 0) := (others => '0');
  
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

  -------------------------------------------------------------------
  --FSM 主进程

  process(clk, rst)
  begin
    if rst = '1' then
      st       <= IDLE;
      start_i  <= '0';
      start_t <= '0';
      t0 <= (others => '0');
      t1 <= (others => '0');
      z <= (others => '0');
      done_1 <= '0';
    elsif rising_edge(clk) then
      start_i  <= '0';   -- 默认 0
      done_1 <= '0';   -- 同上
      start_t <= '0';   

      case st is

        when IDLE =>
          if start = '1' then
            st <= EQ1_SUB1_WAIT; 
            end if;
        when EQ1_SUB1_WAIT =>        -- TODO: Eq1:VS - uC1   
            opa <= VS;
            opb <= uC1_in;
            op <= "001";--SUB
            start_i <= '1';
            st <= EQ1_MUL2_WAIT;
       when EQ1_MUL2_WAIT =>         -- TODO: Eq1:(VS - uC1)/(RC1) ->t0
           if ready ='1' then 
               opa <= y;
               opb <= K_RC1;
               op <="010";--MUL
               start_i <='1';
               st <= EQ1_ADD3_WAIT ;
           end if;          
      when EQ1_ADD3_WAIT =>          -- TODO: Eq1:iL1+iL2
          if ready ='1'then
                t0 <= y;
                opa <= iL1_in;
                opb <= iL2_in;
                op <="000";--ADD
                start_i <='1';
                st <= EQ1_MUL4_WAIT;
           end if; 
      when EQ1_MUL4_WAIT =>          -- TODO: Eq1:(iL1+iL2)/C1
           if ready ='1'then
                opa <= y;
                opb <= K_C1;
                op <="010";--MUL
                start_i <= '1';
                st <= EQ1_SUB5_WAIT;         
           end if;
      when EQ1_SUB5_WAIT =>          -- TODO: Eq1:(VS - uC1)/(RC1)-(iL1+iL2)/C1 ->uC1_out         
           if ready ='1'then
               opa <= t0;
               opb <= y;
               op <="001";--sub
               start_i <= '1';
               st <= EQ3_SUB1_WAIT;          
           end if;
      when EQ3_SUB1_WAIT =>          --TODO: EQ3: uC1-VTH
           if ready = '1'then 
               uC1_out <= y; 
               opa <= uC1_in;
               opb <= VTH;
               op <="001";--sub
               start_i <= '1';
               st <= EQ3_MUL2_WAIT;
           end if;
      when EQ3_MUL2_WAIT =>          --TODO: EQ3: (uC1-VTH)/L1
           if ready ='1' then
               opa <= y;
               opb <= K_L1;
               op <= "010";--MUL
               start_i <='1';
               st <= EQ4_SUB1_WAIT;
           end if;
      when EQ4_SUB1_WAIT =>          --TODO: EQ4: uC1-uC2
           if ready = '1'then 
               iL1_out <= y;
               opa <= uC1_in;
               opb <= uC2_in;
               op <= "001";--sub
               start_i <= '1';
               st <= EQ4_MUL2_WAIT;
           end if;
      when EQ4_MUL2_WAIT =>          --TODO: EQ4: (uC1-uC2)/L2
           if ready ='1' then
                opa <= y;
                opb <= K_L2;
                op <= "010" ;--MUL
                start_i <='1';
                st <= EQ2_MUL1_WAIT;
           end if;
      when EQ2_MUL1_WAIT =>          --TODO :EQ2: uc2/2VTH->z
           if ready ='1'then
                iL2_out <= y;
                opa <= uC2_in;
                opb <= K_VTH;
                op <= "010";--MUL 
                start_i <='1'; 
                st <= EQ2_TANH_WAIT;
           end if;
      when EQ2_TANH_WAIT =>          --TODO :EQ2: tanh
           if ready ='1'then
                z <= y;
                start_t <='1';
                st <= EQ2_MUL2_WAIT;
           end if;
      when EQ2_MUL2_WAIT =>          --TODO :EQ2: beta*tanh
           if ready_t ='1'then
                opa <= tanh_o;
                opb <= K_BETA;
                op <= "010";--MUL 
                start_i <='1';
                st <= EQ2_MUL3_WAIT;
           end if;
      when EQ2_MUL3_WAIT =>          --TODO :EQ2: iL1*beta*tanh
           if ready ='1'then
                opa <= y;
                if iL1_in(31) = '0' then
               -- iL1 >= 0
                    opb <= iL1_in;
                else
               -- iL1 < 0
                    opb <= (others => '0');
               end if;
                op <= "010";
                start_i <='1';
                st <= EQ2_SUB4_WAIT;
            end if;
      when EQ2_SUB4_WAIT =>          --TODO :EQ2: il2-一坨结果
           if ready ='1'then
                opa <= iL2_in;
                opb <= y;
                op <= "001";--MUL  
                start_i <='1';
                st <= EQ2_MUL5_WAIT;
           end if;
      when EQ2_MUL5_WAIT =>          --TODO :EQ2: 一坨/L2
           if ready ='1'then
                opa <= y;
                opb <= K_L2;
                op <= "010";--MUL  
                start_i <='1';
                st <= DONE;
           end if;
      when DONE =>
           if ready ='1'then
                uC2_out <= y;
                st <= IDLE;
                done_1 <= '1';
           end if;
                      
      when others => 
           st <= IDLE;
          
      end case;
    end if;
  end process;
end architecture;