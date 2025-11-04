module immGen(
    input [31:0] instruction,   //指令
    output reg[31:0] immExt     //扩展后的32位立即数
);
    // 中间变量
    wire[6:0] opcode = instruction[6:0];    //基本操作码
    wire[2:0] function3 = instruction[14:12];
    wire[6:0] function7 = instruction[31:25];
    wire[4:0] shamt = instruction[24:20];


    always @(*) begin
        case(opcode)
            // R-type  
            7'b0110011:begin
                // 没有立即数
                immExt = 32'b0; // R-type没有立即数, 默认给0
            end

            // I-type
            7'b0010011:begin    //立即数的运算
                if (function3 == 3'b001) begin      // SLLI
                    immExt = {27'b0, shamt};
                end
                else if(function3 == 3'b101) begin
                    // 仅当是SRLI或SRAI时，才使用shamt
                    if(function7 == 7'b0000000 || function7 == 7'b0100000) begin
                        immExt = {27'b0, shamt};
                    end
                    else begin
                        // (保留) 理论上function3=101时 funct7不会是其他值
                        immExt = 32'hxxxxxxxx; 
                    end
                end
                // 其他所有I-type算术指令 (ADDI, SLTI, ANDI, ORI, XORI)
                else immExt = {{20{instruction[31]}}, instruction[31:20]};
            end
            7'b0000011:begin    // load指令：lb lh lw lbu lhu
                immExt = {{20{instruction[31]}}, instruction[31:20]}; // <-- 修正
            end
            7'b1100111:begin    // jalr 
                immExt = {{20{instruction[31]}}, instruction[31:20]};   // 可能需要符号扩展
            end


            // S-type - 已修正
            7'b0100011:begin
                immExt = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]}; // <-- 修正
            end


            // B-type
            7'b1100011: begin   //beq, bne, blt, bge, bltu, bgeu
                immExt = {{19{instruction[31]}},     // 19 位符号扩展
                        instruction[31],           // imm[12]
                        instruction[7],            // imm[11]
                        instruction[30:25],        // imm[10:5]
                        instruction[11:8],         // imm[4:1]
                        1'b0};                     // imm[0]
            end


            // U-type
            7'b0110111 :begin   // lui imm左移12位
                immExt = {instruction[31:12], 12'b0};
            end
            7'b0010111: begin   // auipc imm左移12位
                immExt = {instruction[31:12], 12'b0};
            end

            // J-type
            7'b1101111: begin  // JAL
                immExt = {{11{instruction[31]}},   // 11 位符号扩展
                        instruction[31],        // imm[20]
                        instruction[19:12],     // imm[19:12]
                        instruction[20],        // imm[11]
                        instruction[30:21],     // imm[10:1]
                        1'b0};                  // imm[0]
            end

            default: begin
                immExt = 32'b0;
            end
        endcase
    end
    

endmodule