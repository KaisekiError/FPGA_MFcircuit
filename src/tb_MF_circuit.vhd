library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.para.all;
use std.textio.all;

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

    constant NUM_ITERATIONS : integer := 50000;

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
        -- CSV file variables
        file csv_file : text;
        variable file_line : line;
        variable file_status : file_open_status;
        -- Helper function to write binary string
        procedure write_binary_vector(vec : in std_logic_vector) is
        begin
            for i in vec'range loop
                if vec(i) = '1' then
                    write(file_line, string'("1"));
                else
                    write(file_line, string'("0"));
                end if;
            end loop;
        end procedure;
    begin
        -- Open CSV file
        file_open(file_status, csv_file, "euler_output_binary.csv", write_mode);
        if file_status /= open_ok then
            report "Error: Cannot create CSV file!" severity error;
        else
            report "CSV file euler_output_binary.csv created";
        end if;
        
        -- Write CSV header
        write(file_line, string'("Iteration,f1_out_bin,f2_out_bin,f3_out_bin,f4_out_bin"));
        writeline(csv_file, file_line);

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
        start <= '0';
        
        -- Wait for first completion
        wait until ready = '1';
        wait for clk_period;

        while iteration_count < NUM_ITERATIONS loop
            -- Write current iteration output data to CSV (binary format)
            write(file_line, iteration_count);
            write(file_line, string'(","));
            
            -- Write f1_out as binary string
            write_binary_vector(f1_out);
            write(file_line, string'(","));
            
            -- Write f2_out as binary string
            write_binary_vector(f2_out);
            write(file_line, string'(","));
            
            -- Write f3_out as binary string
            write_binary_vector(f3_out);
            write(file_line, string'(","));
            
            -- Write f4_out as binary string
            write_binary_vector(f4_out);
            
            writeline(csv_file, file_line);
            
            report "Iteration " & integer'image(iteration_count) & 
                   " - Data written to CSV";

            -- Prepare inputs for next iteration (except last iteration)
            if iteration_count < NUM_ITERATIONS - 1 then
                f1_in <= f1_out;
                f2_in <= f2_out;
                f3_in <= f3_out;
                f4_in <= f4_out;
                start <= '1';
                wait for clk_period;
                start <= '0';
            end if;

            wait until ready = '1';
            iteration_count := iteration_count + 1;
            wait for clk_period * 2;
        end loop;
        
        -- Close CSV file
        file_close(csv_file);
        report "Binary data exported to euler_output_binary.csv";
        
        wait for clk_period * 5;

        -- End simulation
        report "Testbench completed" severity failure;
        
    end process;

end architecture behavior;