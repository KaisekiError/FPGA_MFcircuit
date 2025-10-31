library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.para.all;


entity il2_circuit is
  port(
    clk   : in  std_logic;
    rst   : in  std_logic;
    start : in  std_logic;
    done_iL2  : out std_logic;  
    
    uC1_in    : in std_logic_vector(31 downto 0);
    uC2_in    : in std_logic_vector(31 downto 0);
    iL2_in    : in std_logic_vector(31 downto 0);
    iL2_out   : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of il2_circuit is
  
  --------------------------------------------------------------------
  -- FPU signal

  signal opa, opb, y : std_logic_vector(31 downto 0);
  signal op          : std_logic_vector(2 downto 0);
  signal start_i     : std_logic := '0';
  signal ready       : std_logic;

  --------------------------------------------------------------------
  -- FSM states
 
  type state_il2 is (
    IDLE,
    EQ4_SUB1_WAIT,
    EQ4_MUL2_WAIT,
    EQ4_ADD3_WAIT,
    DONE
);
signal st : state_il2 := IDLE;

begin
  --------------------------------------------------------------------
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

  -------------------------------------------------------------------
  -- FSM 主进程

  process(clk, rst)
  begin
    if rst = '1' then
      st       <= IDLE;
      start_i  <= '0';
      done_iL2 <= '0';
    elsif rising_edge(clk) then
      start_i  <= '0';   -- 默认 0
      case st is

        when IDLE =>
          if start = '1' then
            done_iL2 <= '0';   -- 同上
            st <= EQ4_SUB1_WAIT; 
           end if;   
      when EQ4_SUB1_WAIT =>          --TODO: EQ4: uC1-uC2
          opa <= uC1_in;
          opb <= uC2_in;
          op <="001";--sub
          start_i <= '1';
          st <= EQ4_MUL2_WAIT;
      when EQ4_MUL2_WAIT =>          --TODO: EQ4: (uC1-uC2)/L2*h
           if ready ='1' then
               opa <= y;
               opb <= K_L2;
               op <= "010";--MUL
               start_i <='1';
               st <= EQ4_ADD3_WAIT;
           end if;
     when EQ4_ADD3_WAIT =>          --TODO: EQ3: (uC1-uC2)/L2*h+iL2
           if ready ='1' then
               opa <= y;
               opb <= iL2_in;
               op <= "000";--ADD
               start_i <='1';
               st <= DONE;
           end if;
      when DONE =>
           if ready ='1'then
                iL2_out <= y;
                st <= IDLE;
                done_iL2 <= '1';
           end if;
                      
      when others => 
           st <= IDLE;
          
      end case;
    end if;
  end process;
end architecture;