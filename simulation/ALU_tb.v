`timescale 1ns / 1ps

module ALU_tb;
    reg         CLK;
    reg         RESET;
    reg  [4:0]  aluc;
    reg  [31:0] A, B;
    wire [31:0] Result;
    wire        zero;
    wire        divReady;

    // 实例化 ALU
    ALU uut (
        .CLK(CLK),
        .RESET(RESET),
        .aluc(aluc),
        .A(A),
        .B(B),
        .Result(Result),
        .zero(zero),
        .divReady(divReady)
    );

    // 时钟生成
    initial CLK = 0;
    always #5 CLK = ~CLK; // 10ns 时钟周期

    // 测试任务：带 divReady 同步
    task do_div_rem(input [4:0] op, input [31:0] a, input [31:0] b, input [31:0] expected);
    begin
        aluc = op;
        A = a;
        B = b;

        @(posedge CLK);       // 等待时钟采样输入
        wait(divReady == 0);  // 等 ALU 开始处理
        wait(divReady == 1);  // 等 ALU 完成

        if(Result === expected)
            $display("%0t | %s PASS | A=%08h B=%08h | Result=%08h", 
                $time, op_name(op), A, B, Result);
        else
            $display("%0t | %s FAIL | A=%08h B=%08h | Result=%08h | Expected=%08h", 
                $time, op_name(op), A, B, Result, expected);
    end
    endtask

    // 简单函数：把操作码转成字符串
    function [128*8:1] op_name(input [4:0] code);
    begin
        case(code)
            5'd20: op_name = "DIV";
            5'd21: op_name = "DIVU";
            5'd22: op_name = "REM";
            5'd23: op_name = "REMU";
            default: op_name = "UNKNOWN";
        endcase
    end
    endfunction

    // 测试流程
    initial begin
        // 复位
        RESET = 0; aluc = 0; A = 0; B = 0;
        #20;
        RESET = 1;

        // 测试除法
        do_div_rem(5'd20, 32'd100, 32'd3, 32'd33);         // DIV
        do_div_rem(5'd21, 32'd100, 32'd3, 32'd33);         // DIVU
        do_div_rem(5'd22, 32'd100, 32'd3, 32'd1);          // REM
        do_div_rem(5'd23, 32'd100, 32'd3, 32'd1);          // REMU

        // 测试特殊值：最小负数 / -1
        do_div_rem(5'd20, 32'h80000000, 32'hFFFFFFFF, 32'h80000000); // DIV_MIN
        do_div_rem(5'd22, 32'h80000000, 32'hFFFFFFFF, 32'd0);         // REM_MIN

        // 测试除零
        do_div_rem(5'd20, 32'd123, 32'd0, 32'hFFFFFFFF);  // DIV_ZERO
        do_div_rem(5'd22, 32'd123, 32'd0, 32'd123);       // REM_ZERO

        $display("DIV/REM test finished.");
        $stop;
    end
endmodule
