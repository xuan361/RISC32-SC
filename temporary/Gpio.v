/*
 * Gpio: 通用输入/输出模块
 * 包含一个8位的LED灯组和6个8位的数码管组。
 * 响应总线传入的片选、写使能、地址和数据信号。
 */
module Gpio(
    input           CLK,
    input           RESET,
    
    // --- 总线接口 ---
    input           cs_i,       // 片选信号 (连接到总线的 wGpio)
    input           we_i,       // 写使能信号
    input  [31:0]   addr_i,     // 内部地址 (连接到总线的 A_GPIO)
    input  [31:0]   wdata_i,    // 写入的数据 (连接到总线的 Di)
    output reg [31:0]   rdata_o,    // 读出的数据 (连接到总线的 Do_Gpio)

    // --- 外部设备物理接口 ---
    output [7:0]    led_out,    // 8位LED灯的输出信号
    output [7:0]    smg1_out,   // 数码管1的段选信号
    output [7:0]    smg2_out,
    output [7:0]    smg3_out,
    output [7:0]    smg4_out,
    output [7:0]    smg5_out,
    output [7:0]    smg6_out
);

    // 内部寄存器
    reg [7:0] led_reg;
    reg [7:0] smg_reg[1:6];

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
        else if (cs_i && we_i) begin
            // 使用地址的低位作为内部偏移地址
            case(addr_i[3:0])
                4'h0: led_reg <= wdata_i[7:0];    // 偏移0x0: 写入LED
                4'h1: smg_reg[1] <= wdata_i[7:0]; // 偏移0x1: 写入数码管1
                4'h2: smg_reg[2] <= wdata_i[7:0];
                4'h3: smg_reg[3] <= wdata_i[7:0];
                4'h4: smg_reg[4] <= wdata_i[7:0];
                4'h5: smg_reg[5] <= wdata_i[7:0];
                4'h6: smg_reg[6] <= wdata_i[7:0];
            endcase
        end
    end

    // 读操作逻辑 (组合逻辑)
    always @(*) begin
        // 只有当被总线选中且是读操作时才输出数据
        if (cs_i && !we_i) begin
            case(addr_i[3:0])
                4'h0: rdata_o = {24'b0, led_reg};
                4'h1: rdata_o = {24'b0, smg_reg[1]};
                4'h2: rdata_o = {24'b0, smg_reg[2]};
                4'h3: rdata_o = {24'b0, smg_reg[3]};
                4'h4: rdata_o = {24'b0, smg_reg[4]};
                4'h5: rdata_o = {24'b0, smg_reg[5]};
                4'h6: rdata_o = {24'b0, smg_reg[6]};
                default: rdata_o = 32'h00000000;
            endcase
        end else begin
            rdata_o = 32'h00000000; // 未选中读操作时，输出0
        end
    end
    
    // 连接寄存器到物理输出端口
    assign led_out  = led_reg;
    assign smg1_out = smg_reg[1];
    assign smg2_out = smg_reg[2];
    assign smg3_out = smg_reg[3];
    assign smg4_out = smg_reg[4];
    assign smg5_out = smg_reg[5];
    assign smg6_out = smg_reg[6];

endmodule