module ControlUnit(
    input  wire[16:0]  op,   //17位操作码
    input wire zero, // ALU的zero输出,作为条件，zero=0为真，zero=1为假
    input wire divReady,    // 除法模块是否就绪

    // 控制信号
    output reg[1:0]    m2reg, //决定写回寄存器文件来源。 0：把ALU的运算结果传回，1：把数据存储器的数据传回 2:把立即数左移后的数据传回 
    output reg[1:0]    PCsrc,    // 控制程序计数器（PC）的更新来源，通常用于分支或跳转操作。PCsrc=0为不跳转，PCsrc=1为跳转PC=PC+offset, PCsrc=2为跳转PC=result(ALU的运算结果)
    output reg    wmem, //控制存储器的写操作, 0为读，1为写
    output reg[2:0] memc,    //控制写一字节还是两个字节，memc=0为 1字节（无符号），memc=1为 2字节（无符号）, memc=2为1个字(32位，4个字节), memc=3为 1字节（有符号）, memc=4为 2字节（有符号）
    output reg[2:0]  aluc, //控制 ALU 的操作类型，通常用于选择 ALU 的加法、减法、逻辑运算等操作。0：add, 1：sub, 2：and, 3：or 4:beq 5:ble
    output reg    alusrc,  // 控制 ALU 的输入来源，通常用于选择 ALU 的操作数。0为寄存器的数（add),1为立即数（addi)
    output reg    wreg,  // 控制寄存器的写操作  1为写回，0为不写回
    output reg    jal,   // 控制跳转指令的跳转类型，通常用于选择跳转指令的类型。1为跳转，0为不跳转
    output reg PCHold     // 控制PC的更新，0为更新，1为不更新
);
    // 操作码中间变量  
    wire [6:0] opcode;
    wire [2:0] function3;
    wire [6:0] function7;

    assign opcode = op[6:0];
    assign function3 = op[9:7];
    assign function7 = op[16:10];
    


    always @(*) begin
        case(opcode)
            // R型指令: 包括加法、减法、逻辑运算、移位运算 --> rs1 和 rs2的运算 --> aluc 10种
            7'b0110011: begin
                alusrc = 1'b0;
                case(function3)  
                    3'b000: if(function7 == 7'b0000000) aluc = 4'b0000; //add
                    else if (function7 == 7'b0100000) aluc = 4'b0001;   //sub
                    3'b001: aluc = 4'b0010;     //sll
                    3'b010: aluc = 4'b0011;     //slt
                    3'b011: aluc = 4'b0100;     //sltu
                    3'b100: aluc = 4'b0101;     //xor
                    3'b101: if(function7 == 7'b0000000) aluc = 4'b0110; //srl
                    else if (function7 == 7'b0100000) aluc = 4'b0111;   //sra
                    3'b110: aluc = 4'b1000;     //or
                    3'b111: aluc = 4'b1001;     //and
                endcase         
            end 

            // I型指令:立即数的运算 --> alusrc, aluc
            7'b0010011: begin
                alusrc = 1'b1;
                case(function3)
                    3'b000: aluc = 4'b0000; //addi
                    3'b001: aluc = 4'b0010;     //slli
                    3'b010: aluc = 4'b0011;     //slti
                    3'b011: aluc = 4'b0100;     //sltui
                    3'b100: aluc = 4'b0101;     //xori
                    3'b101: if(function7 == 7'b0000000) aluc = 4'b0110; //srli
                    else if (function7 == 7'b0100000) aluc = 4'b0111;   //srai
                    3'b110: aluc = 4'b1000;     //ori
                    3'b111: aluc = 4'b1001;     //andi

                endcase
            end

            // I型指令: load指令 --> wreg, m2reg, memc
            7'b0000011: begin
                wreg = 1'b1;
                m2reg = 1'b1;
                case(function3)
                    3'b000: memc = 3'b011;   // lb 有符号
                    3'b001: memc = 3'b100;   // lh 有符号
                    3'b010: memc = 3'b010;   // lw
                    3'b100: memc = 3'b000;   // lbu 无符号
                    3'b101: memc = 3'b001;   // lhu 无符号
                endcase
            end

            // I型指令: jair --> jal,wreg,alusrc,aluc,PCsrc
            7'b1100111: begin
                jal = 1'b1; //实现返回地址保存到rd
                wreg = 1'b1;
                alusrc = 1'b1;
                aluc = 3'b000;
                PCsrc = 2'b10;  //跳转到rs1 + immExt
            end

            // S型指令: store指令 --> wmem, memc
            7'b0100011: begin
                wmem = 1'b1;
                case(function3)
                    3'b000: memc = 3'b000;   // sb
                    3'b001: memc = 3'b001;   // sh
                    3'b010: memc = 3'b010;   // sw
                endcase
            end


            // B型指令:条件跳转指令 zero--> alusrc, aluc(6种), PCsrc
            7'b1100011: begin
                alusrc = 1'b0;  // rs1 和 rs2 参与比较运算
                case(function3) 
                    3'b000: aluc = 4'b1010;  //beq
                    3'b001: aluc = 4'b1011;  //bne
                    3'b100: aluc = 4'b1100;  //blt
                    3'b101: aluc = 4'b1101;  //bge
                    3'b010: aluc = 4'b1110;  //bltu
                    3'b111: aluc = 4'b1111;  //bgeu
                endcase

                if(!zero) PCsrc = 2'b01;  //跳转
                else  PCsrc = 2'b00;  //不跳转
            end
            
            // U型指令
            7'b0110111: begin   //lui --> m2reg, jal 左移后的立即数写到rd中
                m2reg = 2'b10;
                jal = 1'b0;
            end
            7'b0010111: begin   //auipc --> m2reg, jal 当前PC值与左移后的立即数相加
                m2reg = 2'b10;

            end

            // J型指令：jal --> jal, wreg, alusrc
            7'b1101111: begin   //jal --> jal, wreg, alusrc, aluc
                jal = 1'b1;     //实现返回地址保存到rd
                wreg = 1'b1;
                PCsrc = 2'b01;  //跳转到当前PC值 + immExt
            end


        endcase

    end



endmodule