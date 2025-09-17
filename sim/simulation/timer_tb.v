`timescale 1ns / 1ps

module timer_tb;
    // 输入信号
    reg CLK;
    reg RESET;
    // 输出信号
    wire [31:0] Do;
    
    // 实例化被测试的Timer模块
    Timer uut (
        .CLK(CLK),
        .RESET(RESET),
        .Do(Do)
    );
    
    // 生成时钟信号 (50MHz)
    initial begin
        CLK = 0;
        forever #10 CLK = ~CLK;  // 10ns周期，频率50MHz
    end
    
    // 测试过程
    initial begin
        // 初始化信号
        RESET = 1;  // 开始时复位
        
        // 等待一段时间后释放复位
        #100;
        RESET = 0;
        
        // 运行足够长的时间来观察计数
        // 由于1ms = 50,000个时钟周期(50MHz)，这里仿真5ms
        #5_000_000;  // 5ms
        
        // 再次复位
        RESET = 1;
        #200;
        RESET = 0;
        
        // 再运行3ms
        #3_000_000;  // 3ms
        
        // 结束仿真
        $finish;
    end
    
    // 监控输出
    initial begin
        $monitor("Time: %0t, RESET: %b, Do: %0d", $time, RESET, Do);
        
        // 生成FST格式波形文件，用于可视化
        $dumpfile("timer_waveform.vcd");
        $dumpvars(0, timer_tb);
    end
endmodule
