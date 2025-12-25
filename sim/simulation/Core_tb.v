`timescale 1ns / 1ps

module core_tb;

    // ==========================
    // 1. 参数定义
    // ==========================
    parameter CLK_PERIOD = 20; // 50MHz (20ns)

    // ==========================
    // 2. 信号定义
    // ==========================
    reg CLK;
    reg RESET;
    reg wait_transport;
    reg uart_rx; // 即使不用串口下载，接口也需连接

    // 观察输出
    wire uart_tx;
    wire [6:0] out; // 段选信号
    wire dig1, dig2, dig3, dig4, dig5, dig6; // 位选信号
    wire led1, led2, led3, led4;

    // 辅助调试变量
    integer scan_index;
    reg [7:0] current_seg_val;

    // ==========================
    // 3. 实例化 Core
    // ==========================
    Core u_Core (
        .CLK(CLK),
        .RESET(RESET),
        .wait_transport(wait_transport),
        .dig1(dig1), .dig2(dig2), .dig3(dig3), 
        .dig4(dig4), .dig5(dig5), .dig6(dig6), 
        .out(out), 
        .led1(led1), .led2(led2), .led3(led3), .led4(led4),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx)
    );

    // ==========================
    // 4. 时钟生成
    // ==========================
    initial CLK = 0;
    always #(CLK_PERIOD/2) CLK = ~CLK;

    // ==========================
    // 5. 辅助函数：解码7段数码管用于打印
    // ==========================
    // 注意：这里假设您的 decoder 逻辑 (0:亮, 1:灭 还是反过来)，这里仅作打印参考
    // 假设 out 为 7位段选
    function [7:0] decode_7seg;
        input [6:0] seg_out;
        begin
            // 这里只是简单的映射，具体取决于您的硬件是共阴还是共阳
            // 这里将原始段选值返回，您可以在波形中对照
            decode_7seg = {1'b0, seg_out};
        end
    endfunction

    // ==========================
    // 6. 主测试流程
    // ==========================
    initial begin
        // --- 初始化 ---
        RESET = 1;
        uart_rx = 1;
        wait_transport = 1; // 跳过串口下载，直接从 ROM 运行

        $display("---------------------------------------------------------");
        $display("TEST START: LED & 7-Segment Display Logic Verification");
        $display("---------------------------------------------------------");

        // --- 加载机器码 ---
        // 注意：请确保 test_led_seg.txt 编译出的 output.txt 在仿真目录下
        // 这里尝试直接写入 ROM 数组，覆盖 Rom.v 中的默认文件路径
        // 如果您的仿真器不支持跨层级引用，请确保 Rom.v 读取的是正确的文件
        $readmemb("output.txt", u_Core.rom.ROM); 
        $display("ROM Loaded with 'test_led_seg.txt' machine code.");

        // --- 复位系统 ---
        #100;
        RESET = 0; // 复位有效
        #100;
        RESET = 1; // 释放复位
        $display("[%t] CPU Reset Released.", $time);

        // --- 等待 CPU 执行 GPIO 写入指令 ---
        // 只有几条指令，执行很快
        #2000; 

        // --- 检查 LED 状态 ---
        $display("---------------------------------------------------------");
        $display("[%t] Checking LEDs...", $time);
        $display("LED Register Written value: 0x0F (binary 00001111)");
        $display("Hardware LED Status (1=High, 0=Low):");
        $display("LED1: %b | LED2: %b | LED3: %b | LED4: %b", led1, led2, led3, led4);
        
        // 如果您的 LED 是低电平点亮，且写入了 1 (led_reg[0]=1)，则 led1 应为 1 (灭) 还是 0 (亮)
        // 取决于 Gpio.v 逻辑。此处仅打印物理电平供您核对 XDC。
        $display("Note: Check against your schematic (Active Low/High).");

        // --- 监测数码管扫描 ---
        $display("---------------------------------------------------------");
        $display("[%t] Monitoring 7-Segment Scanning...", $time);
        $display("Waiting for dynamic scan cycles (approx 1ms per digit)...");
        
        // Gpio.v 中 50000 个时钟周期切换一次位选
        // 50000 * 20ns = 1ms
        // 我们监测 7ms 以覆盖所有位
        
    end

    // ==========================
    // 7. 实时监测数码管位选变化并打印
    // ==========================
    // 每当位选信号发生变化时，打印当前选中的数码管和输出的段码
    always @(dig1 or dig2 or dig3 or dig4 or dig5 or dig6) begin
        // 稍微延时等待段选数据稳定
        #5; 
        
        if (RESET == 1) begin
            // 判断哪个数码管被选中
            // 假设低电平有效 (0选中)，如果您的硬件是高电平有效，请看 1
            // 这里打印原始电平，您自己判断
            
            $write("[%t] Scan Update: Segs(654321)=%b%b%b%b%b%b | Data(Out)=%b (Hex:%h) ", 
                   $time, dig6, dig5, dig4, dig3, dig2, dig1, out, out);
            
            // 尝试智能识别哪一位亮了
            if (dig1 == 0 && dig2 && dig3 && dig4 && dig5 && dig6) $write("-> DIG 1 Active (Exp: 1)\n");
            else if (dig2 == 0) $write("-> DIG 2 Active (Exp: 2)\n");
            else if (dig3 == 0) $write("-> DIG 3 Active (Exp: 3)\n");
            else if (dig4 == 0) $write("-> DIG 4 Active (Exp: 4)\n");
            else if (dig5 == 0) $write("-> DIG 5 Active (Exp: 5)\n");
            else if (dig6 == 0) $write("-> DIG 6 Active (Exp: 6)\n");
            else $write("-> (Transition/All Off/Other)\n");
        end
    end

    // 设置仿真超时
    initial begin
        #8000000; // 跑 8ms (足够覆盖一轮 6ms 的扫描)
        $display("---------------------------------------------------------");
        $display("Simulation Finished.");
        $stop;
    end

endmodule