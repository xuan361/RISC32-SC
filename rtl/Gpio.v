module Gpio(
    input           CLK,
    input           RESET,
    input           wGpio,       // 片选信号 (连接到总线的 wGpio)
    input           wmem,       // 写使能信号
    input  [31:0]   A_GPIO,     // 内部地址 (连接到总线的 A_GPIO)
    input  [31:0]   Di,    // 写入的数据 (连接到总线的 Di)
    output reg [31:0]   Do_Gpio,    // 读出的数据 (连接到总线的 Do_Gpio)

// --- 外部设备物理接口 ---
    output reg dig1,    //数码管从左到右为1-6
    output reg dig2,
    output reg dig3,
    output reg dig4, 
    output reg dig5, 
    output reg dig6, 
    output reg[6:0] out, // 数码管的公共I/O接口

    output reg led1,     //led灯显示
    output reg led2,
    output reg led3,
    output reg led4


/*     output [7:0]    led_out,    // 8位LED灯的输出信号
    output [7:0]    smg1_out,   // 数码管1的段选信号
    output [7:0]    smg2_out,
    output [7:0]    smg3_out,
    output [7:0]    smg4_out,
    output [7:0]    smg5_out,
    output [7:0]    smg6_out */
);
    reg led5;
    reg led6;
    reg led7;
    reg led8;

    // 内部寄存器
    reg [7:0] led_reg;
    reg [7:0] smg_reg[1:6]; //存的是6个数码管各自的值 --> 对应数码管各自显示的内容
    // 七段数码管,它由7个条状的LED灯（发光二极管）组成，分别命名为 a, b, c, d, e, f, g。
    // 此外，通常还有一个用于显示小数点的LED，称为dp。

// 写操作逻辑 (时序逻辑)
    always @(posedge CLK or negedge RESET) begin
        if (!RESET) begin
            led_reg <= 8'h00;
            smg_reg[1] <= 8'h00;
            smg_reg[2] <= 8'h00;
            smg_reg[3] <= 8'h00;
            smg_reg[4] <= 8'h00;
            smg_reg[5] <= 8'h00;
            smg_reg[6] <= 8'h00;
        end
        // 只有当被总线选中且是写操作时才执行
        else if(wGpio && wmem) begin 
            // 使用地址的低位作为内部偏移地址
            case(A_GPIO[3:0])
                4'h0: led_reg <= Di[7:0];    // 偏移0x0: 写入LED
                4'h1: smg_reg[1] <= Di[7:0]; // 偏移0x1: 写入数码管1
                4'h2: smg_reg[2] <= Di[7:0];
                4'h3: smg_reg[3] <= Di[7:0];
                4'h4: smg_reg[4] <= Di[7:0];
                4'h5: smg_reg[5] <= Di[7:0];
                4'h6: smg_reg[6] <= Di[7:0];
            endcase
        end 
    end

// 读操作逻辑 (组合逻辑)
    always @(*) begin
        // 只有当被总线选中且是读操作时才输出数据
        if (wGpio) begin
            case(A_GPIO[3:0])
                4'h0: Do_Gpio = {24'b0, led_reg};
                4'h1: Do_Gpio = {24'b0, smg_reg[1]};
                4'h2: Do_Gpio = {24'b0, smg_reg[2]};
                4'h3: Do_Gpio = {24'b0, smg_reg[3]};
                4'h4: Do_Gpio = {24'b0, smg_reg[4]};
                4'h5: Do_Gpio = {24'b0, smg_reg[5]};
                4'h6: Do_Gpio = {24'b0, smg_reg[6]};
                default: Do_Gpio = 32'h00000000;
            endcase
        end 
        else begin
            Do_Gpio = 32'h00000000; // 未选中读操作时，输出0
        end
    end


// 连接寄存器到物理输出端口
/*     assign led_out  = led_reg;
    assign smg1_out = smg_reg[1];
    assign smg2_out = smg_reg[2];
    assign smg3_out = smg_reg[3];
    assign smg4_out = smg_reg[4];
    assign smg5_out = smg_reg[5];
    assign smg6_out = smg_reg[6]; */


// 数码管显示逻辑
    reg[2:0] digit_select; // 用于选择当前显示的数码管
    reg[15:0] dig_counter; // 用于计数 50000 个时钟周期

    // 动态扫描的核心思想：
    // 利用人眼的视觉暂留效应，在极短的时间内轮流点亮每一个数码管，让它们看起来像是同时点亮的。
    always @(posedge CLK or negedge RESET) begin
        if(!RESET) begin
            digit_select <= 2'b00;
            dig_counter <= 0;
        end
        else begin
            if (dig_counter < 50000) begin      //数码管的更新周期为50000ns
                dig_counter = dig_counter + 1;
            end
            else begin      //完成一个周期后，进行下一个数码管的更新
                dig_counter <= 0;
                if (digit_select == 3'b101) begin
                    digit_select <= 3'b000;
                end
                else begin
                    digit_select <= digit_select + 1;
                end
            end 
        end
    end

    // 定义一个函数，输入4位数据，输出7位段码
    function [6:0] decoder (input [3:0] data_in);
        case(data_in)
            4'b0000: decoder = 7'b1000000; // 0
            4'b0001: decoder = 7'b1111001; // 1
            4'b0010: decoder = 7'b0100100; // 2
            4'b0011: decoder = 7'b0110000; // 3
            4'b0100: decoder = 7'b0011001; // 4
            4'b0101: decoder = 7'b0010010; // 5
            4'b0110: decoder = 7'b0000010; // 6
            4'b0111: decoder = 7'b1111000; // 7
            4'b1000: decoder = 7'b0000000; // 8
            4'b1001: decoder = 7'b0010000; // 9
            4'b1010: decoder = 7'b0001000; // A
            4'b1011: decoder = 7'b0000011; // b
            4'b1100: decoder = 7'b1000110; // C
            4'b1101: decoder = 7'b0100001; // d
            4'b1110: decoder = 7'b0000110; // E
            4'b1111: decoder = 7'b0001110; // F
            default: decoder = 7'b1111111; // 可选：默认全灭
        endcase
    endfunction


    // 时序逻辑部分
    always @(posedge CLK) begin
        case(digit_select)
            3'b000: begin
                {dig6, dig5, dig4, dig3, dig2, dig1} <= 6'b000001;
                out <= decoder(smg_reg[1][3:0]); //直接调用函数进行译码和输出
            end
            3'b001: begin
                {dig6, dig5, dig4, dig3, dig2, dig1} <= 6'b000010;
                out <= decoder(smg_reg[2][3:0]);
            end
            3'b010: begin
                {dig6, dig5, dig4, dig3, dig2, dig1} <= 6'b000100;
                out <= decoder(smg_reg[3][3:0]);
            end
            3'b011: begin
                {dig6, dig5, dig4, dig3, dig2, dig1} <= 6'b001000;
                out <= decoder(smg_reg[4][3:0]);
            end
            3'b100: begin
                {dig6, dig5, dig4, dig3, dig2, dig1} <= 6'b010000;
                out <= decoder(smg_reg[5][3:0]);
            end
            3'b101: begin
                {dig6, dig5, dig4, dig3, dig2, dig1} <= 6'b100000;
                out <= decoder(smg_reg[6][3:0]);
            end
            default: begin // 避免生成锁存器
                {dig6, dig5, dig4, dig3, dig2, dig1} <= 6'b000000;
                out <= 7'b1111111;
            end
        endcase
    end


// led灯显示逻辑
    always @(posedge CLK or negedge RESET) begin
        if(!RESET)begin
            {led8, led7, led6, led5, led4, led3, led2, led1} = 8'b00000000;
        end
        else begin 
            {led8, led7, led6, led5, led4, led3, led2, led1} <= led_reg;
        end
    end

endmodule