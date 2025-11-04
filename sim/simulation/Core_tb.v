`timescale 1ns / 1ps

module Core_tb;

    // -------------------------------------------------------------------------
    // 1. 顶层模块的信号声明 (与 Core.v 的端口保持一致)
    // -------------------------------------------------------------------------
    reg CLK;
    reg RESET; 
    reg uart_rx;

    // 外部设备物理接口 (仅作为输出观察)
    wire dig1;
    wire dig2;
    wire dig3;
    wire dig4; 
    wire dig5; 
    wire dig6; 
    wire [6:0] out; 
    wire led1;
    wire led2;
    wire led3;
    wire led4;
    wire led5;
    wire led6;
    wire led7;
    wire led8;
    wire uart_tx;
    
    // -------------------------------------------------------------------------
    // 2. ROM 文件模拟 (重要: 创建一个模拟的 output.txt)
    // -------------------------------------------------------------------------
    // 注意: $readmemb 需要一个真实的文件。为了能运行，你需要在
    // 仿真目录中创建一个 output.txt 文件，并填入指令数据。
    // 示例 output.txt (假设这是几条 RISC-V 指令):
    // 00100293  // ADDI x5, x0, 32  (x5 = 32)
    // 00300313  // ADDI x6, x0, 3   (x6 = 3)
    // 00630333  // ADD x6, x6, x5   (x6 = 35)
    // 00000000  // NOP
    // -------------------------------------------------------------------------


    // -------------------------------------------------------------------------
    // 3. 例化顶层模块 (DUT: Device Under Test)
    // -------------------------------------------------------------------------
    Core DUT (
        .CLK(CLK),
        .RESET(RESET),
        
        // 外部设备接口连接
        .dig1(dig1),
        .dig2(dig2),
        .dig3(dig3),
        .dig4(dig4), 
        .dig5(dig5), 
        .dig6(dig6), 
        .out(out), 
        .led1(led1),
        .led2(led2),
        .led3(led3),
        .led4(led4),
        // .led5(led5),
        // .led6(led6),
        // .led7(led7),
        // .led8(led8),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx)

    );

    // -------------------------------------------------------------------------
    // 4. 时钟和复位信号生成
    // -------------------------------------------------------------------------

    // 时钟生成 (周期 20ns, 频率 50MHz)
    parameter CLK_PERIOD = 20;
    initial begin
        CLK = 1'b0;
        forever #(CLK_PERIOD / 2) CLK = ~CLK;
    end

    // 复位和激励序列
    initial begin
        // 1. 初始复位
        RESET = 1'b0; // 低电平有效复位 [cite: 1]
        #100;
        RESET = 1'b1; // 撤销复位，CPU开始执行

        // 2. 运行指令
        #100; // 等待几条指令执行 (具体时间取决于流水线深度和指令周期)
        
        // 3. 观察 ALU 结果或寄存器变化 (需要访问子模块内部信号)
        // 注意: 在实际的 Testbench 中，你需要使用 $display 或波形工具
        // (如 ModelSim, Vivado Simulator) 来观察 DUT.currentAddress,
        // DUT.instruction, DUT.Result, DUT.registerFile.register[x] 等内部信号。
        
        $display("------------------- Simulation Start -------------------");
        $display("Time | PC Address | Instruction | ALU Result | R5 Value (Example)");
        
        #100;
        
        // 4. 结束仿真
        #500; 
        $display("-------------------- Simulation End --------------------");
        $finish; 
    end

    // -------------------------------------------------------------------------
    // 5. 调试输出 (可选，用于仿真时打印关键信息)
    // -------------------------------------------------------------------------
    /*
    // 使用 $monitor 持续打印 PC 地址和指令 (需要时钟和复位信号)
    always @(posedge CLK) begin
        if (RESET) begin
            $display("%t | %h | %h | %h", $time, DUT.currentAddress, DUT.instruction, DUT.alu.Result);
        end
    end
    */

endmodule