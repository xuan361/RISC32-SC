module immGen(
    input [31:0] instruction,   //指令
    output reg[31:0] immExt     //扩展后的32位立即数
);
    // 中间变量
    wire[6:0] opcode = instruction[6:0];    //基本操作码
    wire[2:0] function3 = instruction[14:12];
    wire[6:0] function7 = instruction[31:25];
    wire[4:0] shamt = instruction[31:25];

    always @(*) begin
        case(opcode)
            // R-type  
            7'b0110011:begin
                // 没有立即数
            end

            // I-type
            7'b0010011:begin    //立即数的运算
                if (function3 == 3'b001) begin      // SLLI
                    immExt = {27'b0, shamt};
                end
                else if(function3 == 3'b101) begin
                    if(function7 == 7'b0000000)   immExt = {27'b0, shamt}; // SRLI
                    else if(function7 == 7'b0100000)   immExt = {27'b0, shamt}; // SRAI
                end
                else immExt = {{20{instruction[31]}}, instruction[31:20]};
            end
            7'b0000011:begin    // load指令：lb lh lw lbu lhu
                immExt = {20'b0, instruction[31:20]};
            end
            7'b1100111:begin    // jair 
                immExt = {20'b0, instruction[31:20]};   // 可能需要符号扩展
            end

            // S-type
            7'b0100011:begin
                immExt = {20'b0, instruction[31:25], instruction[11:7]};
            end

            // B-type
            7'b1100011:begin
                immExt = {19'b0, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
            end

            // U-type
            7'b0110111 :begin   // lui imm左移12位
                immExt = {instruction[31:12], 12'b0};
            end
            7'b0010111: begin   // auipc imm左移12位
                immExt = {instruction[31:12], 12'b0};
            end

            // J-type
            7'b1101111:begin
                immExt = {11'b0, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};
            end

            default: begin
                immExt = 32'b0;
            end
        endcase
    end
    

endmodule