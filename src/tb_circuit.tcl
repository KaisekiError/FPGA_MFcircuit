# ================================
# ModelSim simulation script
# ================================

# 1. 设置工程路径 (根据你的实际路径修改)
cd D:/devault/gowin-project/fpga_project/src

# 2. 清理旧的编译库
vlib work
vmap work work

# 3. 编译所有 VHDL 文件 (顺序很重要)
vcom para_pack.vhd
vcom fpu.vhd
vcom tanh.vhd
vcom Euler.vhd
vcom circuit.vhd
vcom tb_circuit.vhd

# 4. 启动仿真
vsim work.tb_circuit

# 5. 添加所有信号到日志
log -r /*

# 6. 配置 VCD 输出
vcd file dump.vcd
vcd add -r /*

# 7. 运行 100 微秒
run 100 us

# 8. 刷新并关闭 VCD
vcd flush
