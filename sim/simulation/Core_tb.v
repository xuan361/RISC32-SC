`timescale 1ns / 1ps

module tb_Core_RunMode;

    // ==========================
    // 1. 参数定义
    // ==========================
    parameter CLK_PERIOD = 20; // 50MHz时钟 (20ns)
    
    // 【重要设置】波特率参数
    // 请确保这里的周期与你 uart_rx 硬件模块中的分频计数一致
    // 假设 50MHz 时钟，波特率 9600：50000000 / 9600 ≈ 5208 个周期
    // 如果仿真太慢，可以修改此处，但前提是你的硬件 uart_rx 模块也能适应这个速度
    parameter BAUD_BIT_PERIOD = 5208 * 20; 

    // ==========================
    // 2. 信号定义
    // ==========================
    reg CLK;
    reg RESET;
    reg wait_transport; // 传输控制信号
    reg uart_rx;        // 模拟外部PC发送给CPU的数据
    
    // 观察输出
    wire uart_tx;       // CPU发出来的数据
    wire [6:0] out;
    wire dig1, dig2, dig3, dig4, dig5, dig6;
    wire led1, led2, led3, led4;

    // ==========================
    // 3. 实例化待测模块 (Core)
    // ==========================
    Core u_Core (
        .CLK(CLK),
        .RESET(RESET),
        .wait_transport(wait_transport), // 连接传输控制
        
        // 外部设备接口
        .dig1(dig1), .dig2(dig2), .dig3(dig3), 
        .dig4(dig4), .dig5(dig5), .dig6(dig6), 
        .out(out), 
        .led1(led1), .led2(led2), .led3(led3), .led4(led4),
        
        // 串口
        .uart_tx(uart_tx),
        .uart_rx(uart_rx)
    );

    // ==========================
    // 4. 时钟生成
    // ==========================
    initial CLK = 0;
    always #(CLK_PERIOD/2) CLK = ~CLK;

    // ==========================
    // 5. 串口发送任务 (模拟PC -> CPU)
    // ==========================
    task send_uart_byte;
        input [7:0] data;
        integer j;
        begin
            // --- 起始位 (Start Bit = 0) ---
            uart_rx = 0;
            #(BAUD_BIT_PERIOD);
            
            // --- 数据位 (Data Bits, LSB First) ---
            for (j = 0; j < 8; j = j + 1) begin
                uart_rx = data[j];
                #(BAUD_BIT_PERIOD);
            end
            
            // --- 停止位 (Stop Bit = 1) ---
            uart_rx = 1;
            #(BAUD_BIT_PERIOD);
            
            // --- 字节间缓冲时间 ---
            #(BAUD_BIT_PERIOD * 2); 
        end
    endtask

    // ==========================
    // 6. 主测试流程
    // ==========================
    initial begin
        // --- 1. 初始化 ---
        RESET = 1;
        uart_rx = 1;        // 串口空闲状态为高电平
        
        // 【关键】将 wait_transport 置为 1 (高电平)
        // 配合 Core.v 第66行逻辑：如果 wait_transport=1 且 RESET有效，
        // 状态机会直接初始化为 S_RUNNING，跳过下载步骤。
        wait_transport = 1; 
        
        $display("Simulation Start: Loading ROM from file specified in Rom.v...");

        // --- 2. 复位系统 ---
        #100;
        RESET = 0; // 复位有效 (低电平)
        #100;
        RESET = 1; // 释放复位 -> CPU 直接进入 S_RUNNING
        
        $display("Time: %t - CPU Reset Released. Entered RUNNING mode.", $time);

        // --- 3. 等待 CPU 初始化 ---
        // 你的汇编代码(rx_and_tx.txt) 前几行有 lui, sw 等操作初始化 UART 寄存器
        // 需要给一点时间让这些指令执行完成
        #5000; 

        // --- 4. 发送测试数据 ---
        // 根据 rx_and_tx.txt 逻辑：
        // 先接收被除数 (Dividend) [cite: 100]
        // 再接收除数 (Divisor)   [cite: 100]
        
        // -> 发送被除数: 20 (0x14)
        $display("Time: %t - Sending Dividend: 20", $time);
        send_uart_byte(8'd183); 

        // -> 发送除数: 4 (0x04)
        $display("Time: %t - Sending Divisor: 4", $time);
        send_uart_byte(8'd5);

        $display("Time: %t - Data sent. Waiting for CPU calculation and response...", $time);

        // --- 5. 等待结果 ---
        // CPU 此时在做除法 (div, rem)，然后会将结果通过 uart_tx 发送回来
        // 理论输出：商=5, 余数=0
        
        // 等待足够长的时间观察波形中的 uart_tx
        #200000; 
        
        $display("Simulation Finished.");
        $stop;
    end

endmodule