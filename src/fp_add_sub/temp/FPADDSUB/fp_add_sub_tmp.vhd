--Copyright (C)2014-2025 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--Tool Version: V1.9.12 (64-bit)
--Part Number: GW5AST-LV138PG676AC1/I0
--Device: GW5AST-138
--Device Version: C
--Created Time: Sat Nov  1 19:49:11 2025

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component FP_Add_Sub_Top
	port (
		clk: in std_logic;
		rstn: in std_logic;
		op: in std_logic;
		data_a: in std_logic_vector(31 downto 0);
		data_b: in std_logic_vector(31 downto 0);
		result: out std_logic_vector(31 downto 0)
	);
end component;

your_instance_name: FP_Add_Sub_Top
	port map (
		clk => clk,
		rstn => rstn,
		op => op,
		data_a => data_a,
		data_b => data_b,
		result => result
	);

----------Copy end-------------------
