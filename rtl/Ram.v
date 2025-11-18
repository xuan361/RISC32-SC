// RamL 接收32位地址输入，接收32位数据输入，返回32位数据；
module Ram(
    input CLK,
    // input RESET,
    // input cs,   // 片选信号
    input wmem,           //读写信号，1为写，0为读
    input[2:0] memc,             //控制写入字节数，memc=0为1字节，memc=1为两个字节, memc=2为4个字节
    // 输入数据
    input [31:0] A_Ram,     //地址 (Core传来的地址)
    input [31:0] Di_Ram,    //输入数据 (B_data)

    // 输出数据
    output reg [31:0] Do_Ram  //输出数据
);

    // 内存区RAM, 256字节
    reg [7:0] RAM[0:255];  // 以字节为单位
    integer i;
    initial begin
        for(i = 0; i < 256; i = i + 1) begin
            RAM[i] <= 8'd2;
        end
    end

    wire[31:0] A_byte = A_Ram;
    wire[31:0] A_halfWord = (A_Ram >> 1) << 1;
    wire[31:0] A_word = (A_Ram >> 2) << 2;

    always @(posedge CLK) begin
        // 写入内存
        // 小端模式：传入的数据低位要放在索引值小的存储单元里
        // 选中且写
        if(wmem) begin
            case(memc)   // 控制写入字节数
                3'b000: begin
                    RAM[A_byte] <= Di_Ram[7:0];
                end
                3'b001: begin
                    RAM[A_halfWord] <= Di_Ram[7:0];
                    RAM[A_halfWord + 1] <= Di_Ram[15:8];
                end
                3'b010: begin
                    RAM[A_word] <= Di_Ram[7:0];
                    RAM[A_word + 1] <= Di_Ram[15:8];
                    RAM[A_word + 2] <= Di_Ram[23:16];
                    RAM[A_word + 3] <= Di_Ram[31:24];
                end
            endcase
        end
    end


    // 读取内存
    always @(*) begin
        // 选中
        case(memc)   // 控制写入字节数
            3'b000: begin
                Do_Ram = {24'b0, RAM[A_byte]};
            end
            3'b001: begin
                Do_Ram = {16'b0, RAM[A_halfWord + 1], RAM[A_halfWord]};
            end
            3'b010: begin
                Do_Ram = {RAM[A_word + 3], RAM[A_word + 2], RAM[A_word + 1], RAM[A_word]};
            end
            3'b011: begin
                Do_Ram = $signed(RAM[A_byte]);
            end
            3'b100: begin
                Do_Ram = $signed({RAM[A_halfWord + 1], RAM[A_halfWord]});
            end
            default: Do_Ram = 32'h0;
        endcase
    end

endmodule