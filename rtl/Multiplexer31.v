// 选择写回PC的来源
module Multiplexer31 (
    input [1:0] control,
    input [31:0] in0,
    input [31:0] in1,
    input [31:0] in2,

    output reg[31:0] out
);
    always @(*)begin
        case(control)
            2'b00:  out = in0;  // 使用 2'b00 更清晰
            2'b01:  out = in1;
            2'b10:  out = in2;
            // 修复：添加 default 来覆盖 2'b11 的情况
            default: out = 32'h00000000; // 或者 32'hxxxxxxxx (don't care)
        endcase
    end

endmodule