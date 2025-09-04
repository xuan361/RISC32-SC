// 选择写回寄存器的数据
// 0：把ALU的运算结果传回
// 1：把数据存储器的数据传回 
// 2:把currentAddress_2传回 
// 3：把立即数左移八位后的数据传回
module Multiplexer41 (
    input [1:0] control,
    input [15:0] in0,
    input [15:0] in1,
    input [15:0] in2,
    input [15:0] in3,

    output reg[15:0] out
);
    always @(*)begin
        case(control)
            0:  out = in0;
            1:  out = in1;
            2:  out = in2;
            3:  out = in3;
        endcase
    end

endmodule