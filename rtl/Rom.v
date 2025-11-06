// ROM：存储指令
module Rom(
    input CLK,
    input ROM_write_enable,     //读写信号，1为写，0为读
    input [31:0] MachineCodeAddress,    //机器码对应的地址
    input [31:0] MachineCodeData,   //机器码数据

    input [31:0] A,   //指令地址输入入口
    input [31:0] RamDataAddress,  // RAM数据地址入口                
    output reg[31:0] instruction, //传递给InstructionMemory的指令
    output reg[31:0] RamData    // ROM传递给RAM的数据
);
    // ROM存储区
    reg[31:0] ROM[0:255];
    integer i;
    initial begin 
        for( i = 0; i < 256; i = i + 1)begin
            ROM[i] = 32'b0;
        end
        $readmemb("D:/learn/RISC32-SC/RISC32-SC/assembler/data/output.txt", ROM);
    end

    // 动态下载机器码到ROM
    always @(posedge CLK)begin
        if(ROM_write_enable) begin
            ROM[MachineCodeAddress] = MachineCodeData;
        end
    end

    always @(*)begin
        instruction = ROM[A >> 2];  // 指令
        RamData = ROM[RamDataAddress];  // RAM数据
    end

endmodule