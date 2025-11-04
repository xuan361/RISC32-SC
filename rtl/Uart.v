//  Uart: UART串口通信模块 (全双工)
// 发送：CPU 向 Uart 模块写入数据后立刻发送
// 接收：Uart 模块检测到uart_rx下降沿后，立刻接收
// 未完成
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
    reg [1:0] uart_ctrl;       // 控制寄存器 @ 0x00第 0位控制发送使能（1为使能，0为禁止），第1位控制接收使能
    reg [1:0] uart_status;     // 状态寄存器 @ 0x04 ，在写入发送数据前必须检查此位以确保发送器空闲
    // 第0位为发送忙状态（1表示正在发送，0为空闲），第1位为接收完成标志（1表示接收完成，0表示正在接收）
    reg [31:0] uart_baud;       // 波特率设置寄存器 @ 0x08
    reg [31:0] uart_txdata;     // 发送数据寄存器 @ 0x0c
    reg [31:0] uart_rxdata;     // 接收数据寄存器 @ 0x10
/*     // -- 状态寄存器的组成部分 --
    reg tx_busy_flag;   // 状态位 0: 发送忙标志
    reg rx_done_flag;   // 状态位 1: 接收完成标志 */

    // -- 控制寄存器的组成部分 -- 1为可以发送或接收数据
    wire tx_enable = uart_ctrl[0]; // 控制位 0: 发送使能
    wire rx_enable = uart_ctrl[1]; // 控制位 1: 接收使能

    // -- 波特率时钟分频器计算 --
    reg [31:0] clk_div;
    always @(*) begin
        // 根据波特率寄存器的值计算每个比特需要持续的时钟周期数
        if (uart_baud != 0)
            clk_div = SYS_CLK_FREQ / uart_baud;
        else
            clk_div = SYS_CLK_FREQ / DEFAULT_BAUD; // 如果未设置，则使用默认值
    end

// --- 写操作逻辑 ---
    always @(posedge CLK or negedge RESET) begin
        if (!RESET) begin
            uart_ctrl   <= 2'b11;
            uart_status <= 2'b00; // 初始状态：发送空闲，未接收完成
            uart_baud   <= DEFAULT_BAUD;
            uart_txdata <= 32'h0;
            // 状态和接收寄存器由硬件逻辑更新，复位时可初始化
            uart_rxdata <= 32'h0;
        end else if (wUart && wmem) begin // 当被总线选中且为写操作时
            case(A_UART[4:0]) // 根据地址偏移选择寄存器
                5'h00: uart_ctrl   <= Di;
                5'h08: uart_baud   <= Di;
                5'h0c: uart_txdata <= Di;
/*                     begin   
                        // 仅当发送空闲时才接收新数据
                        if (uart_status[0] == 1'b0) begin
                            uart_txdata <= Di;
                        end
                    end */
                // STATUS 和 RXDATA 寄存器通常为只读，或有特定写操作清除标志位
                default: ;
            endcase
        end
    end

// --- 读操作逻辑 ---
    always @(*) begin
        if (wUart) begin // 当被总线选中且为读操作时
            case(A_UART[4:0])
                5'h00: Do_Uart = uart_ctrl;
                5'h04: Do_Uart = {30'b0, uart_status};
                5'h08: Do_Uart = uart_baud;
                5'h10: Do_Uart = uart_rxdata;
                // TXDATA 寄存器通常为只写
                default: Do_Uart = 32'h0;
            endcase
        end else begin
            Do_Uart = 32'h0; // 未选中时输出0
        end
    end

    // // 当CPU读取接收数据寄存器后，清除接收完成标志
    // wire rx_read_signal = !wmem && (A_UART == 5'h10);
    // always @(posedge CLK or negedge RESET) begin
    //     if (!RESET) begin
    //         uart_status[1] <= 1'b0;
    //     end else if (rx_read_signal) begin
    //         uart_status[1] <= 1'b0; // 读操作后清除标志
    //     end
    //     // 注意: 接收完成标志由接收器逻辑设置
    // end


// Uart 发送器 tx
    reg [3:0]  tx_state; // 发送器状态机
    localparam TX_FREE  = 4'd0; // 空闲状态
    localparam TX_START = 4'd1; // 发送起始位
    localparam TX_DATA  = 4'd2; // 发送数据位
    localparam TX_STOP  = 4'd3; // 发送停止位

    reg [17:0] tx_clk_count; // 波特率时钟计数器
    reg [3:0]  tx_bit_index; // 当前发送的数据位索引
    reg        tx_reg;       // 输出到uart_tx引脚的寄存器
    wire [7:0]  tx_data_reg = uart_txdata[7:0]; // 待发送的8位数据

    assign uart_tx = tx_reg; // 连接输出引脚

    // 触发发送的信号：CPU可以向TXDATA寄存器写入数据
    wire tx_start_signal = wmem && (A_UART == 5'h0c) && wUart;

    always @(posedge CLK or negedge RESET) begin
    if (!RESET) begin
            tx_state     <= TX_FREE;
            tx_clk_count <= 0;
            tx_bit_index <= 0;
            uart_status[0] <= 1'b0;
            tx_reg       <= 1'b1; // TX线在空闲时为高电平
        end else begin
            case (tx_state)
                TX_FREE: begin
                    // 如果发送被使能，并且CPU写入了数据，则开始发送
                    if (tx_start_signal && tx_enable) begin
                        uart_status[0] <= 1'b1;                // 设置发送忙标志
                        tx_clk_count <= 0;
                        tx_state     <= TX_START;
                    end 
                end
                TX_START: begin
                    tx_reg <= 1'b0; // 发送起始位 (低电平)
                    if (tx_clk_count == clk_div - 1) begin
                        tx_clk_count <= 0;
                        tx_bit_index <= 0;
                        tx_state     <= TX_DATA;
                    end else begin
                        tx_clk_count <= tx_clk_count + 1;
                    end
                end
                TX_DATA: begin
                    tx_reg <= tx_data_reg[tx_bit_index]; // 依次发送8个数据位
                    if (tx_clk_count == clk_div - 1) begin
                        tx_clk_count <= 0;
                        if (tx_bit_index == 7) begin
                            tx_state <= TX_STOP; // 8位发送完毕，进入停止位状态
                        end else begin
                            tx_bit_index <= tx_bit_index + 1;
                        end
                    end else begin
                        tx_clk_count <= tx_clk_count + 1;
                    end
                end

                TX_STOP: begin
                    tx_reg <= 1'b1; // 发送停止位 (高电平)
                    if (tx_clk_count == clk_div - 1) begin
                        tx_clk_count <= 0;
                        tx_state     <= TX_FREE; // 发送完成，返回空闲状态
                        uart_status[0] <= 1'b0; // 设置发送空闲标志
                    end else begin
                        tx_clk_count <= tx_clk_count + 1;
                    end
                end
                
                default: tx_state <= TX_FREE;

            endcase
        end
    end

// Uart 接收器 rx
    reg [3:0]  rx_state; // 接收器状态机
    localparam RX_FREE  = 4'd0; // 空闲状态
    localparam RX_START = 4'd1; // 检测到起始位
    localparam RX_DATA  = 4'd2; // 接收数据位
    localparam RX_STOP  = 4'd3; // 接收停止位

    reg [17:0] rx_clk_count; // 波特率时钟计数器
    reg [3:0]  rx_bit_index; // 当前接收的数据位索引
    reg [7:0]  rx_data_reg;  // 存放接收到的8位数据
    
    // 触发接收的信号：CPU向RXDATA寄存器写入数据
    wire rx_start_signal = rx_enable && ~uart_rx;   //接收使能，并且检测到RX线上的下降沿（起始位）

    always @(posedge CLK or negedge RESET) begin
        if (!RESET) begin
            rx_state     <= RX_FREE;
            rx_clk_count <= 0;
            rx_bit_index <= 0;
            uart_rxdata  <= 32'b0;
            uart_status[1] <= 1'b1;
        end else begin
            case (rx_state)
                RX_FREE: begin
                    // 如果接收使能，并且检测到RX线上的下降沿（起始位）
                    if (rx_start_signal) begin
                        rx_state     <= RX_START;
                        rx_clk_count <= 0;
                        uart_status[1] <= 1'b0; // 设置接收忙标志

                    end
                end
                
                RX_START: begin
                    // 等待半个比特时间，以便在比特中间进行采样
                    if(rx_clk_count == (clk_div >> 1)) begin
                        if(~uart_rx) begin // 再次确认起始位仍然是低电平，以过滤噪声
                           rx_clk_count <= 0;
                           rx_bit_index <= 0;
                           rx_state     <= RX_DATA;
                        end else begin
                           rx_state     <= RX_FREE; // 如果是毛刺，则返回空闲状态
                        end
                    end else begin
                        rx_clk_count <= rx_clk_count + 1;
                    end
                end

                RX_DATA: begin
                    // 每经过一个比特时间，采样一次数据位
                    if(rx_clk_count == clk_div - 1) begin
                        rx_clk_count <= 0;
                        rx_data_reg[rx_bit_index] <= uart_rx; // 锁存数据位
                        if (rx_bit_index == 7) begin
                            rx_state <= RX_STOP; // 8位数据接收完毕
                        end else begin
                            rx_bit_index <= rx_bit_index + 1;
                        end
                    end else begin
                        rx_clk_count <= rx_clk_count + 1;
                    end
                end

                RX_STOP: begin
                    // 等待一个比特时间，检查停止位
                    if(rx_clk_count == clk_div - 1) begin
                        if (uart_rx) begin // 检查停止位是否为高电平 (有效)
                           uart_rxdata  <= {24'b0, rx_data_reg}; // 将接收到的数据放入接收寄存器
                           uart_status[1] <= 1'b1;                  // 设置接收完成标志
                        end
                        // 如果停止位不是高电平，则发生帧错误 (本设计中忽略)
                        rx_state <= RX_FREE; // 返回空闲状态，准备下一次接收
                    end else begin
                        rx_clk_count <= rx_clk_count + 1;
                    end
                end

                default: rx_state <= RX_FREE;
            endcase
        end
    end

endmodule