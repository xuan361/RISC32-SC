
// InstructionMemory：储存指令，分割指令
// PC = PC + 4 对应 ROM 是 指令条数+1
// A=4 --> ROM[1]
// 所以，指令地址需要右移两位才能得到对应的内存地址。
module InstructionMemory(
    input CLK,
    input [31:0] A,   //指令地址输入入口
    output reg[16:0] op,    //17位操作码
    output reg[4:0] rs1,    //源操作数1
    output reg[4:0] rs2,    //源操作数2
    output reg[4:0] rd,    //目的操作数
    output reg[31:0] instruction //传递给立即数扩展模块的指令

);
    // 操作码中间变量  
    reg[6:0] opcode;
    reg[2:0] function3;
    reg[6:0] function7;

    reg[31:0] ROM[0:255]; //ROM 用于存储指令数据
    // initial 
    // begin
    //     $readmemb("D:/learn/RISC32-SC/RISC32-SC/sim/test/test1.txt", ROM);  //读取测试文档中的指令
    // end

    always @(*)begin
        // 得到输出的op, rd, rs1, rs2, instruction
        opcode = ROM[A >> 2][6:0];
        rd = ROM[A >> 2][11:7];
        function3 = ROM[A >> 2][14:12];
        rs1 = ROM[A >> 2][19:15];
        rs2 = ROM[A >> 2][24:20];
        function7 = ROM[A >> 2][31:25];

        op = {function7,function3,opcode};
        instruction = ROM[A >> 2];

    end







endmodule






