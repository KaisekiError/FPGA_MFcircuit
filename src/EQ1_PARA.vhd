library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.para.all;


entity der_uc1 is
  port(
    clk   : in  std_logic;
    rst   : in  std_logic;
    start : in  std_logic;
    done  : out std_logic;     
    uC1_in    : in std_logic_vector(31 downto 0);
    iL1_in    : in std_logic_vector(31 downto 0);
    iL2_in    : in std_logic_vector(31 downto 0);
    uC1_out   : out std_logic_vector(31 downto 0);
  );
end entity;

architecture rtl of der_uc1 is


  --------------------------------------------------------------------
  -- register signal
  --------------------------------------------------------------------
  signal t0, t1    : std_logic_vector(31 downto 0) := (others => '0');

  --------------------------------------------------------------------
  -- FPU, SIGN signal
  --------------------------------------------------------------------
signal opa_1, opb_1, y_1 : std_logic_vector(31 downto 0);
signal op_1          : std_logic_vector(2 downto 0);
signal start_1     : std_logic := '0';
signal ready_1       : std_logic;

signal opa_2, opb_2, y_2 : std_logic_vector(31 downto 0);
signal op_2          : std_logic_vector(2 downto 0);
signal start_2     : std_logic := '0';
signal ready_2       : std_logic;

signal ready     : std_logic;   
signal done_2     : std_logic;
signal done_1     : std_logic;    
--------------------------------------------------------------------
-- FSM states

type state_t_1 is (
  IDLE,
  --FPU1
  EQ1_SUB1_WAIT_1,
  EQ1_MUL2_WAIT_1,
  --整体计算
  EQ1_SUB3_WAIT_1,
  EQ1_ADD4_WAIT_1,
  DONE
);
signal st_1 : state_t_1 := IDLE;


type state_t_2 is (
  IDLE,
  --FPU2
  EQ1_ADD1_WAIT_2,
  EQ1_MUL2_WAIT_2,  
  
  DONE
);
signal st_2 : state_t_2 := IDLE;


begin

-- FPU1 实例化
ufpu1: entity work.fpu
  port map(
    clk_i    => clk,
    opa_i    => opa_1,      -- 连接到FPU1专用的opa_1信号
    opb_i    => opb_1,      -- 连接到FPU1专用的opb_1信号  
    fpu_op_i => op_1,       -- 连接到FPU1专用的op_1信号
    rmode_i  => "00",
    start_i  => start_1,  -- 连接到FPU1专用的start_i_1信号
    output_o => y_1,        -- 连接到FPU1专用的输出y_1信号
    ready_o  => ready_1     -- 连接到FPU1专用的ready_1信号
  );

-- FPU2 实例化  
ufpu2: entity work.fpu
  port map(
    clk_i    => clk,
    opa_i    => opa_2,      -- 连接到FPU2专用的opa_2信号
    opb_i    => opb_2,      -- 连接到FPU2专用的opb_2信号
    fpu_op_i => op_2,       -- 连接到FPU2专用的op_2信号
    rmode_i  => "00",
    start_i  => start_2,  -- 连接到FPU2专用的start_i_2信号
    output_o => y_2,        -- 连接到FPU2专用的输出y_2信号
    ready_o  => ready_2     -- 连接到FPU2专用的ready_2信号
  );

  -------------------------------------------------------------------
  -- FSM 主进程

  process(clk, rst)
  begin
    if rst = '1' then
      st_1      <= IDLE;
      st_2      <= IDLE;
      start_1  <= '0';
      start_2  <= '0';
      t0 <= (others => '0');
      t1 <= (others => '0');
      done_1 <= '0';
      done_2 <= '0';
    elsif rising_edge(clk) then
      start_1  <= '0';   -- 默认 0
      done_1 <= '0';   -- 同上
      start_2 <= '0';   

      done <= '0';
      case st_1 is

        when IDLE =>
          if start = '1' then
            st_1 <= EQ1_SUB1_WAIT_1;
            st_2 <=EQ1_ADD1_WAIT_2; 
            end if;
        when EQ1_SUB1_WAIT_1 =>        -
            opa_1 <= VS;
            opb_1 <= uC1_in;
            op_1 <= "001";--SUB
            start_1 <= '1';
            st_1 <= EQ1_MUL2_WAIT_1;
       when EQ1_MUL2_WAIT_1 =>        
           if ready_1 ='1' then 
               opa_1 <= y_1;
               opb_1 <= K_RC1;
               op_1 <="010";--MUL
               start_1 <='1';
               st_1 <= EQ1_SUB3_WAIT_1 ;
           end if;          
      
      when EQ1_SUB3_WAIT_1 =>                  
           if ready_1 AND done_2 ='1'then
               opa_1 <= y_1;
               opb_1 <= y_2;
               op <="001";--sub
               start_1 <= '1';
               st_1 <= EQ1_ADD4_WAIT_1;          
           end if;
      when EQ1_ADD4_WAIT_1 =>                  
           if ready_1 ='1'then
               opa_1 <= uC1_in;
               opb_1 <= y_1;
               op <="000";--add
               start_1 <= '1';
               st_1 <= DONE;          
           end if;

      when DONE =>
           if ready_1 ='1'then
                uC1_out <= y_1;
                st_1 <= IDLE;
                st_2 <= IDLE;
                done <= '1';
           end if;
                      
      when others => 
           st_1 <= IDLE;
          
      end case;




      case st_2 is


      when IDLE =>
    
      when EQ1_ADD1_WAIT_2 =>    
                done_2 = '0';
                opa_2 <= iL1_in;
                opb_2 <= iL2_in;
                op_2 <="000";--ADD
                start_2 <='1';
                st_2 <= EQ1_MUL2_WAIT_2;
           end if; 
      when EQ1_MUL2_WAIT_2 =>          
           if ready_2 ='1'then
                opa_2 <= y_2;
                opb_2 <= K_C1;
                op_2 <="010";--MUL
                start_2 <= '1';
                st_2 <= DONE;         
           end if;
      when DONE =>          
           if ready_2 ='1'then
               done_2 = '1';
               st_2 <= IDLE
           end if;

                      
      when others => 
           st_2 <= IDLE;
          
      end case;
    end if;
  end process;
end architecture;