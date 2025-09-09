// DataMemory：用于内存存储，内存读写
module DataMemory(
    input CLK,
    input RESET,
    // 信号
    input wmem,           //读写信号，1为写，0为读
    input memc,             //控制写入字节数，memc=0为1字节，memc=1为两个字节, memc=2为4个字节
    // 输入数据
    input [31:0] A,     //地址 (ALU的result)
    input [31:0] Di,    //输入数据 (B_data)

    // 输出数据
    output reg [31:0] Do  //输出数据

); 

    // 内存区RAM, 1024字节
    reg [7:0] RAM[0:1023];  // 以字节为单位

    // 初始化内存
    integer i;
    initial begin
        for(i = 0; i < 1024; i = i + 1) begin
            RAM[i] <= 8'b0;
        end
    end

    wire[31:0] A_byte = A;
    wire[31:0] A_halfWord = (A >> 1) << 1;
    wire[31:0] A_word = (A >> 2) << 2;

    always @(posedge CLK or negedge RESET) begin
        if(!RESET) begin
            for(i = 0; i < 1024; i = i + 1) begin
                RAM[i] <= 8'b0;
            end
        end
        // 写入内存
        // 小端模式：传入的数据低位要放在索引值小的存储单元里
        else if(wmem) begin
            case(memc)   // 控制写入字节数
                3'b000: begin
                    RAM[A_byte] <= Di[7:0];
                end
                3'b001: begin
                    RAM[A_halfWord] <= Di[7:0];
                    RAM[A_halfWord + 1] <= Di[15:8];
                end
                3'b010: begin
                    RAM[A_word] <= Di[7:0];
                    RAM[A_word + 1] <= Di[15:8];
                    RAM[A_word + 2] <= Di[23:16];
                    RAM[A_word + 3] <= Di[31:24];
                end
            endcase
        end

    end

    // 读取内存
    always @(*) begin
        case(memc)   // 控制写入字节数
            3'b000: begin
                Do = {24'b0, RAM[A_byte]};
            end
            3'b001: begin
                Do = {16'b0, RAM[A_halfWord + 1], RAM[A_halfWord]};
            end
            3'b010: begin
                Do = {RAM[A_word + 3], RAM[A_word + 2], RAM[A_word + 1], RAM[A_word]};
            end
            3'b011: begin
                Do = $signed(RAM[A_byte]);
            end
            3'b100: begin
                Do = $signed({RAM[A_halfWord + 1], RAM[A_halfWord]});
            end
        endcase
    end


endmodule