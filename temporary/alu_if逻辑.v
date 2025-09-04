if (op[6:0] == 7'b0110011) begin
    case(op[17:7])
        10'b0000000000:ALUc = 4'b0000;//add
        10'b0100000000:ALUc = 4'b0001;//sub
        10'b0000000001:ALUc = 4'b0010;//sll
        10'b0000000010:ALUc = 4'b0011;//slt
        10'b0000000011:ALUc = 4'b0100;//sltu
        10'b0000000100:ALUc = 4'b0101;//xor
        10'b0000000101:ALUc = 4'b0110;//srl
        10'b0100000101:ALUc = 4'b0111;//sra
        10'b0000000110:ALUc = 4'b1000;//or
        10'b0000000111:ALUc = 4'b1001;//and
    endcase
end