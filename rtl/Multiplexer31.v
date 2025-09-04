// 选择写回PC的来源
module Multiplexer31 (
    input [1:0] PCsrc,
    input [31:0] currentAddress_4,
    input [31:0] currentAddress_immediate,
    input [31:0] result,

    output reg[31:0] newAddress
);
    always @(*)begin
        case(PCsrc)
            0:  newAddress = currentAddress_4;
            1:  newAddress = currentAddress_immediate;
            2:  newAddress = result;
        endcase

    end


endmodule