//  Uart: UART串口通信模块 (全双工)
// 发送：CPU 向 Uart 模块写入数据后立刻发送
// 接收：Uart 模块检测到uart_rx下降沿后，立刻接收
// (已修正多重驱动 Bug)
module Uart#(
    parameter SYS_CLK_FREQ = 50_000_000, // 定义系统时钟为 50 MHz
    parameter DEFAULT_BAUD = 9600      // 定义默认波特率为 115200
)(
    input           CLK,
    input           RESET,
    input           wUart,       // 片选信号 (来自总线的 wUart)
    input           wmem,       // 写使能信号
    input  [31:0]   A_UART,     // 内部地址 (来自总线的 A_UART)
    input  [31:0]   Di,    // 写入的数据 (来自总线的 Di)
    output reg [31:0]   Do_Uart,    // 读出的数据 (返回给总线的 Do_Uart)

    // --- 物理接口 (实际硬件连接) ---
    output wire uart_tx,
    input wire uart_rx
);
// 5个内部寄存器
    reg [1:0] uart_ctrl;       // 控制寄存器 @ 0x00
    // --- 修正: uart_status 不再是 reg, 而是由两个独立 reg 组成的 wire ---
    // reg [1:0] uart_status; // [原代码, 已删除]
    wire [1:0] uart_status_wire; // [新代码]
    
    reg [31:0] uart_baud;       // 波特率设置寄存器 @ 0x08
    reg [31:0] uart_txdata;     // 发送数据寄存器 @ 0x0c
    reg [31:0] uart_rxdata;     // 接收数据寄存器 @ 0x10
    
    // --- 修正: 使用独立的标志位 (来自您的注释) ---
    reg tx_busy_flag;   // 状态位 0: 发送忙标志
    reg rx_done_flag;   // 状态位 1: 接收完成标志
    
    // --- 修正: 将独立的标志位组合成状态线 ---
    assign uart_status_wire = {rx_done_flag, tx_busy_flag};

    // -- 控制寄存器的组成部分 -- 1为可以发送或接收数据
    wire tx_enable = uart_ctrl[0]; // 控制位 0: 发送使能
    wire rx_enable = uart_ctrl[1]; // 控制位 1: 接收使能

    // -- 波特率时钟分频器计算 --
    reg [31:0] clk_div;
    always @(*) begin
        if (uart_baud != 0)
            clk_div = SYS_CLK_FREQ / uart_baud;
        else
            clk_div = SYS_CLK_FREQ / DEFAULT_BAUD;
    end

// --- 写操作逻辑 ---
    always @(posedge CLK or negedge RESET) begin
        if (!RESET) begin
            uart_ctrl   <= 2'b11;
            // --- 修正: 状态标志位不由本模块驱动 ---
            // uart_status <= 2'b00; // [原代码, 已删除]
            uart_baud   <= DEFAULT_BAUD;
            uart_txdata <= 32'h0;
            uart_rxdata <= 32'h0;
        end else if (wUart && wmem) begin // 当被总线选中且为写操作时
            case(A_UART[4:0]) // 根据地址偏移选择寄存器
                5'h00: uart_ctrl   <= Di;
                5'h08: uart_baud   <= Di;
                // --- 修正: 增加忙判断, 保护 TXDATA ---
                5'h0c: begin   
                        // 仅当发送空闲时才接收新数据
                        if (tx_busy_flag == 1'b0) begin
                            uart_txdata <= Di;
                        end
                    end
                default: ;
            endcase
        end
    end

// --- 读操作逻辑 ---
    always @(*) begin
        if (wUart) begin // 当被总线选中且为读操作时
            case(A_UART[4:0])
                5'h00: Do_Uart = uart_ctrl;
                // --- 修正: 读取组合后的状态线 ---
                5'h04: Do_Uart = {30'b0, uart_status_wire};
                5'h08: Do_Uart = uart_baud;
                5'h10: Do_Uart = uart_rxdata;
                default: Do_Uart = 32'h0;
            endcase
        end else begin
            Do_Uart = 32'h0;
        end
    end

// Uart 发送器 tx
    reg [3:0]  tx_state;
    localparam TX_FREE  = 4'd0, TX_START = 4'd1, TX_DATA  = 4'd2, TX_STOP  = 4'd3;
    reg [17:0] tx_clk_count;
    reg [3:0]  tx_bit_index;
    reg        tx_reg;
    wire [7:0]  tx_data_reg = uart_txdata[7:0];
    assign uart_tx = tx_reg;
    wire tx_start_signal = wmem && (A_UART[4:0] == 5'h0c) && wUart;
    
    // --- 修正: 此 always 块现在只驱动 tx_busy_flag ---
    always @(posedge CLK or negedge RESET) begin
        if (!RESET) begin
            tx_state     <= TX_FREE;
            tx_clk_count <= 0;
            tx_bit_index <= 0;
            tx_busy_flag <= 1'b0; // [修正]
            tx_reg       <= 1'b1;
        end else begin
            case (tx_state)
                TX_FREE: begin
                    if (tx_start_signal && tx_enable) begin
                        tx_busy_flag <= 1'b1; // [修正] (设置发送忙标志)
                        tx_clk_count <= 0;
                        tx_state     <= TX_START;
                    end 
                end
                TX_START: begin
                    tx_reg <= 1'b0;
                    if (tx_clk_count == clk_div - 1) begin
                        tx_clk_count <= 0;
                        tx_bit_index <= 0;
                        tx_state     <= TX_DATA;
                    end else begin
                        tx_clk_count <= tx_clk_count + 1;
                    end
                end
                TX_DATA: begin
                    tx_reg <= tx_data_reg[tx_bit_index];
                    if (tx_clk_count == clk_div - 1) begin
                        tx_clk_count <= 0;
                        if (tx_bit_index == 7) begin
                            tx_state <= TX_STOP;
                        end else begin
                            tx_bit_index <= tx_bit_index + 1;
                        end
                    end else begin
                        tx_clk_count <= tx_clk_count + 1;
                    end
                end
                TX_STOP: begin
                    tx_reg <= 1'b1;
                    if (tx_clk_count == clk_div - 1) begin
                        tx_clk_count <= 0;
                        tx_state     <= TX_FREE;
                        tx_busy_flag <= 1'b0; // [修正] (设置发送空闲标志)
                    end else begin
                        tx_clk_count <= tx_clk_count + 1;
                    end
                end
                default: tx_state <= TX_FREE;
            endcase
        end
    end

// Uart 接收器 rx
    reg [3:0]  rx_state;
    localparam RX_FREE  = 4'd0, RX_START = 4'd1, RX_DATA  = 4'd2, RX_STOP  = 4'd3;
    reg [17:0] rx_clk_count;
    reg [3:0]  rx_bit_index;
    reg [7:0]  rx_data_reg;
    wire rx_start_signal = rx_enable && ~uart_rx;

    // --- 修正: 此 always 块现在只驱动 rx_done_flag ---
    always @(posedge CLK or negedge RESET) begin
        if (!RESET) begin
            rx_state     <= RX_FREE;
            rx_clk_count <= 0;
            rx_bit_index <= 0;
            uart_rxdata  <= 32'b0;
            rx_done_flag <= 1'b0; // [修正] (复位时应为0)
        end else begin
            case (rx_state)
                RX_FREE: begin
                    if (rx_start_signal) begin
                        rx_state     <= RX_START;
                        rx_clk_count <= 0;
                        rx_done_flag <= 1'b0; // [修正] (设置接收忙标志)
                    end
                end
                RX_START: begin
                    if(rx_clk_count == (clk_div >> 1)) begin
                        if(~uart_rx) begin
                           rx_clk_count <= 0;
                           rx_bit_index <= 0;
                           rx_state     <= RX_DATA;
                        end else begin
                           rx_state     <= RX_FREE;
                        end
                    end else begin
                        rx_clk_count <= rx_clk_count + 1;
                    end
                end
                RX_DATA: begin
                    if(rx_clk_count == clk_div - 1) begin
                        rx_clk_count <= 0;
                        rx_data_reg[rx_bit_index] <= uart_rx;
                        if (rx_bit_index == 7) begin
                            rx_state <= RX_STOP;
                        end else begin
                            rx_bit_index <= rx_bit_index + 1;
                        end
                    end else begin
                        rx_clk_count <= rx_clk_count + 1;
                    end
                end
                RX_STOP: begin
                    if(rx_clk_count == clk_div - 1) begin
                        if (uart_rx) begin 
                           uart_rxdata  <= {24'b0, rx_data_reg};
                           rx_done_flag <= 1'b1; // [修正] (设置接收完成标志)
                        end
                        rx_state <= RX_FREE;
                    end else begin
                        rx_clk_count <= rx_clk_count + 1;
                    end
                end
                default: rx_state <= RX_FREE;
            endcase
        end
    end

endmodule