
// InstructionMemory：储存指令，分割指令
// PC = PC + 4 对应 ROM 是 指令条数+1
// A=4 --> ROM[1]
// 所以，指令地址需要右移两位才能得到对应的内存地址。
module InstructionMemory(
    input [31:0] instruction,   //指令
    output reg[16:0] op,    //17位操作码
    output reg[4:0] rs1,    //源操作数1
    output reg[4:0] rs2,    //源操作数2
    output reg[4:0] rd,    //目的操作数
    output reg[31:0] instruction_imm //传递给立即数扩展模块的指令

);
    // 操作码中间变量  
    reg[6:0] opcode;
    reg[2:0] function3;
    reg[6:0] function7;



    always @(*)begin
        // 得到输出的op, rd, rs1, rs2, instruction
        opcode = instruction[6:0];
        function3 = instruction[14:12];
        function7 = instruction[31:25];

        rd = instruction[11:7];
        rs1 = instruction[19:15];
        rs2 = instruction[24:20];
        op = {function7,function3,opcode};
        instruction_imm = instruction;

    end







endmodule






