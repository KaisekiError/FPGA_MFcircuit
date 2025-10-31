library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.para.all;


entity uC2_circuit is
  port(
    clk   : in  std_logic;
    rst   : in  std_logic;
    start : in  std_logic;
    done_uC2  : out std_logic; 
    uC2_in    : in std_logic_vector(31 downto 0);
    iL1_in    : in std_logic_vector(31 downto 0);
    iL2_in    : in std_logic_vector(31 downto 0);
    uC2_out   : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of uC2_circuit is


  --------------------------------------------------------------------
  -- register signal
  --------------------------------------------------------------------
  signal t0   : std_logic_vector(31 downto 0) := (others => '0');
  
  --------------------------------------------------------------------
  -- FPU  signal
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
 
type state_uC2_1 is (
  IDLE,
  --FPU1
  EQ2_MUL1_WAIT_1,
  EQ2_SUB2_WAIT_1,
  --整体计算
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

  -- FPU 实例化

  ufpu1: entity work.fpu
    port map(
      clk_i    => clk,
      opa_i    => opa_1,
      opb_i    => opb_1,
      fpu_op_i => op_1,
      rmode_i  => "00",
      start_i  => start_1,
      output_o => y_1,
      ready_o  => ready_1
    );

  ufpu2: entity work.fpu
    port map(
      clk_i    => clk,
      opa_i    => opa_2,
      opb_i    => opb_2,
      fpu_op_i => op_2,
      rmode_i  => "00",
      start_i  => start_2,
      output_o => y_2,
      ready_o  => ready_2
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
      done_2 <= '0';
      done_uc2 <= '0';
    elsif rising_edge(clk) then
      start_1  <= '0';   -- 默认 0
      start_2 <= '0';   


     case st_1 is

      when IDLE =>
          if start = '1' then
            st_1 <= EQ2_MUL1_WAIT_1;
            done_uC2 <= '0'; 
            end if;
      when EQ2_MUL1_WAIT_1 =>
                opa_1 <= iL2_in;
                opb_1 <= K_C2;
                op_1 <= "010";--MUL 
                start_1 <='1'; 
                st_1 <= EQ2_SUB2_WAIT_1;
      when EQ2_SUB2_WAIT_1 =>
            if ready_1 = '1' then
            done_1 <= '1';
            end if;          
            if (done_1 = '1') and (done_2 = '1') then
                opa_1 <= y_1;
                opb_1 <= t0;
                op_1 <= "001";--SUB 
                start_1 <='1';
                done_2  <= '0';   
                done_1  <= '0';
                st_1 <= EQ2_ADD3_WAIT_1;
           end if;
      when EQ2_ADD3_WAIT_1 => 
           if ready_1 ='1'then
                opa_1 <= y_1;
                opb_1 <= uC2_in;
                op_1 <= "000";
                start_1 <='1';
                st_1 <= DONE_STATE_1;
            end if;
      when DONE_STATE_1 =>
           if ready_1 ='1'then
                uC2_out <= y_1;
                st_1 <= IDLE;
                done_uC2 <= '1';
           end if;
                      
      when others => 
           st_1 <= IDLE;
          
     end case;

     case st_2 is

      when IDLE =>
          if start = '1' then
            st_2 <= EQ2_MUL1_WAIT_2; 
          end if;
      when EQ2_MUL1_WAIT_2 => 
          done_2 <= '0';
          opa_2 <= K_C2_B;
          if iL1_in(31) = '0' then   -- iL1 >= 0
            opb_2 <= iL1_in;
          else                       -- iL1 < 0
            opb_2 <= (others => '0');
          end if;
          op_2 <= "010";
          start_2 <='1';
          st_2 <= EQ2_MUL2_WAIT_2;
      when EQ2_MUL2_WAIT_2 =>          --TODO :EQ2: sign(uC2)*iL1
           if ready_2 ='1'then
                opa_2 <= y_2;
                 if uC2_in(31) = '1' then   -- uC2 < 0
                   opb_2 <= NEG_ONE;
                 elsif uC2_in = x"00000000" then
                   opb_2 <= (others => '0');
                 else
                   opb_2 <= ONE;
                 end if;
           op_2 <= "010";
           start_2 <='1';
           st_2 <= DONE_STATE_2;
           end if;
      when DONE_STATE_2 =>
           if ready_2 ='1'then
                t0 <= y_2;
                st_2 <= IDLE;
                done_2 <= '1';
           end if;
                      
      when others => 
           st_2 <= IDLE;
          
     end case;

    end if;
  end process;
end architecture;