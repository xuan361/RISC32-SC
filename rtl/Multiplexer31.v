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
            0:  out = in0;
            1:  out = in1;
            2:  out = in2;
        endcase

    end


endmodule