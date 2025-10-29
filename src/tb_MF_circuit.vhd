library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.para.all;

entity tb_euler_old is
end entity tb_euler_old;

architecture behavior of tb_euler_old is

    -- Component Declaration for the Unit Under Test (UUT)
    component euler_old
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        start  : in  std_logic;
        f1_in  : in  std_logic_vector(31 downto 0);
        f2_in  : in  std_logic_vector(31 downto 0);
        f3_in  : in  std_logic_vector(31 downto 0);
        f4_in  : in  std_logic_vector(31 downto 0);
        f1_out : out std_logic_vector(31 downto 0);
        f2_out : out std_logic_vector(31 downto 0);
        f3_out : out std_logic_vector(31 downto 0);
        f4_out : out std_logic_vector(31 downto 0);
        ready  : out std_logic
    );
    end component;

    -- Inputs
    signal clk   : std_logic := '0';
    signal rst   : std_logic := '1';
    signal start : std_logic := '0';
    signal f1_in : std_logic_vector(31 downto 0) := (others => '0');
    signal f2_in : std_logic_vector(31 downto 0) := (others => '0');
    signal f3_in : std_logic_vector(31 downto 0) := (others => '0');
    signal f4_in : std_logic_vector(31 downto 0) := (others => '0');

    -- Outputs
    signal f1_out : std_logic_vector(31 downto 0);
    signal f2_out : std_logic_vector(31 downto 0);
    signal f3_out : std_logic_vector(31 downto 0);
    signal f4_out : std_logic_vector(31 downto 0);
    signal ready  : std_logic;

    -- Clock period definitions
    constant clk_period : time := 5 ns;

    -- Test data
    constant TEST_F1 : std_logic_vector(31 downto 0) := x"3F19999A";
    constant TEST_F2 : std_logic_vector(31 downto 0) := x"3F19999A";
    constant TEST_F3 : std_logic_vector(31 downto 0) := x"3A1D4952";
    constant TEST_F4 : std_logic_vector(31 downto 0) := x"3A1D4952";
    constant NUM_ITERATIONS : integer := 10;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: euler_old
    port map (
        clk    => clk,
        rst    => rst,
        start  => start,
        f1_in  => f1_in,
        f2_in  => f2_in,
        f3_in  => f3_in,
        f4_in  => f4_in,
        f1_out => f1_out,
        f2_out => f2_out,
        f3_out => f3_out,
        f4_out => f4_out,
        ready  => ready
    );

    -- Clock process
    clk_process : process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- Stimulus process
    stim_proc: process
        variable iteration_count : integer := 0;
    begin
        -- Initialize
        report "Starting testbench simulation";
        
        -- Hold reset state for 2 clock cycles
        rst <= '1';
        wait for clk_period * 2;
        
        -- Release reset
        rst <= '0';
        wait for clk_period * 2;
        
        -- Apply test inputs
        f1_in <= TEST_F1;
        f2_in <= TEST_F2;
        f3_in <= TEST_F3;
        f4_in <= TEST_F4;
        
        -- Start the computation
        start <= '1';
        wait for clk_period;
        
        -- Wait for completion
        wait until ready = '1';
        wait for clk_period;

        while iteration_count < NUM_ITERATIONS loop
            if iteration_count < NUM_ITERATIONS - 1 then
                f1_in <= f1_out;
                f2_in <= f2_out;
                f3_in <= f3_out;
                f4_in <= f4_out;
            end if;

            wait until ready = '1';
            iteration_count := iteration_count + 1;
            wait for clk_period * 2;
        end loop;
        
        wait for clk_period * 5;

        -- End simulation
        report "Testbench completed" severity failure;
        
    end process;

end architecture behavior;