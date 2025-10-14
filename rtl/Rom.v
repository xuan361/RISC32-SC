// ROM：存储指令
module Rom(
    input [31:0] A,   //指令地址输入入口
    input [31:0] RamDataAddress,  // RAM数据地址入口                
    output reg[31:0] instruction, //传递给InstructionMemory的指令
    output reg[31:0] RamData    // ROM传递给RAM的数据
);
    // ROM存储区
    reg[31:0] ROM[0:255];
    initial begin 
        $readmemb("..\assembler\data\output.txt", ROM);
    end
    always @(*)begin
        instruction = ROM[A >> 2];  // 指令
        RamData = ROM[RamDataAddress];  // RAM数据
    end

endmodule