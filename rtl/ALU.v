module ALU(
    input [3:0] aluc,  // ALU 的操作类型
    input [31:0] A,     //操作数1(A_data)
    input [31:0] B,     //操作数2(B_data 或 immExt)
    output reg [31:0] Result,   //ALU运算结果(要存储到rd的内容)
    output reg zero    // 运算结果result的标志，result为0输出1，否则输出0
);
    // 进行ALU计算
    // 0：add, 1：sub, 2：sll, 3：slt, 4:sltu, 5:xor, 6srl, 7:sra, 8:or, 9:and

    wire shamt = B[4:0];
    always @(*) begin
        case(aluc)
            4'b0000 : Result = A + B;  // ADD
            4'b0001 : Result = A - B;  // SUB
            4'b0010 : Result = A << shamt;  // SLL
            4'b0011 : Result = ($signed(A) < $signed(B)) ? 32'd1 : 32'd0;  // SLT
            4'b0100 : Result = (A < B) ? 32'd1 : 32'd0;  // SLTU
            4'b0101 : Result = A ^ B;  // XOR
            4'b0110 : Result = A >> shamt;  // SRL
            4'b0111 : Result = $signed(A) >>> $sign(shamt);  // SRA
            4'b1000 : Result = A | B;  // OR
            4'b1001 : Result = A & B;  // AND
            4'b1010 : Result =  A == B; //beq
            4'b1011 : Result =  A != B; //bne
            4'b1100 : Result =  $signed(A) < $signed(B); //blt
            4'b1101 : Result =  $signed(A) >= $signed(B); //bge
            4'b1110 : Result =  A < B; //bltu
            4'b1111 : Result =  A >= B; //bgeu
            default : Result = 32'b0;  // 默认输出0
        endcase
        //设置zero
            if (Result) zero = 0;
            else zero = 1;
    end

endmodule