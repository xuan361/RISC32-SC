// (1) jal作为控制信号，选择(pc + 4) 或 三路选择器的输出(immExt | alu_result | Do) 存入rd
// (2) alusrc作为控制信号, 选择 B_data 或者 immExt 作为 B (ALU的输入)
module Multiplexer21 (
    input control,      // jal || alusrc
    input [31:0] in0,   // 三路选择器的输出 || B_data
    input [31:0] in1,   // (pc + 4) || immExt
    output [31:0] out

);
    assign out = control ? in1 : in0;
endmodule