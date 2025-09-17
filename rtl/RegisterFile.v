

// RegisterFile：储存寄存器组，并根据地址对寄存器组进行读写

module RegisterFile(
    input CLK,
    input RESET,
    input wreg,   // 写使能信号，为1时，在时钟上升沿写入
    input [4:0] A_addr,            // 源寄存器地址1
    input [4:0] B_addr,            // 源寄存器地址2
    input [4:0] W_addr,             // 目标寄存器地址
    input [31:0] Data,    // 写入寄存器的数据 （rd）

    output [31:0] A_data,   // rs1寄存器数据输出
    output [31:0] B_data    // rs2寄存器数据输出
);

    // 位宽（[msb:lsb]）必须在变量名之前，而数组的维度（[start:end]）必须在变量名之后。
    reg [31:0] register[0:63];  // 寄存器组，包含64个独立的32位寄存器

    // 初始时，将32个寄存器全部赋值为0
    integer i;
    initial 
    begin
        for(i = 0; i < 32; i = i + 1) register[i] <= 0;
    end

    //assign 保证 ReadData1始终与rs地址的寄存器值相同，ReadData2始终与rt地址的寄存器值相同
    assign A_data = register[A_addr];
    assign B_data = register[B_addr];

    // 当写使能信号为1时，在时钟上升沿写入
    always @(posedge CLK or negedge RESET)
    begin
        if(!RESET) begin
            for(i = 0; i < 32; i = i + 1) register[i] <= 32'b0;
        end
        else begin
            // wreg为真，写入数据
            if (wreg) begin
                register[W_addr] = Data;
            end
        end
    end

endmodule