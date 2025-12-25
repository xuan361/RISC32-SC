/*
 * UART 接收 -> 除法运算 -> UART 发送
 * * 流程:
 * 1. 初始化 UART
 * 2. 接收 被除数 (Dividend) -> 存入 RAM 0x10000000
 * 3. 接收 除数 (Divisor)   -> 存入 RAM 0x10000004
 * 4. 计算 商 (Quotient) 和 余数 (Remainder)
 * 5. 结果 存入 RAM 0x10000008 (商) 和 0x1000000C (余数)
 * 6. 发送 商
 * 7. 发送 余数
 */



// UART (基地址 0x30000000)
#define UART_BASE 0x30000000
#define UART_CTRL   (*(volatile unsigned int*)(UART_BASE + 0x00))
#define UART_STATUS (*(volatile unsigned int*)(UART_BASE + 0x04))
#define UART_TXDATA (*(volatile unsigned int*)(UART_BASE + 0x0c))
#define UART_RXDATA (*(volatile unsigned int*)(UART_BASE + 0x10))

// RAM 基地址 0x10000000
// 使用指针数组形式方便访问偏移量 0, 4, 8, 12
#define RAM_PTR     ((volatile unsigned int *)0x10000000)

// 状态位掩码
#define TX_BUSY_BIT (1 << 0) // Bit 0: 发送忙碌
#define RX_DONE_BIT (1 << 1) // Bit 1: 接收完成


/*
 * 接收 (对应汇编 rx_loop)
 */
unsigned int uart_rx() {
    // 对应 wait_rx 标签下的循环
    // 检查 STATUS 的第1位 (RX_DONE)
    while (!(UART_STATUS & RX_DONE_BIT)) {
        // 等待接收完成...
    }

    // sw zero, 4(t0)
    // 汇编中先清除了状态位 (虽然后读数据，但在C中通常读完清除，这里严格复刻逻辑顺序或保持功能?)
    // 为了数据安全，这里采用：读数据 -> 清状态
    // 如果严格复刻汇编顺序： UART_STATUS = 0; unsigned int data = UART_RXDATA;

    // 对应汇编: lw a0, 16(t0)
    unsigned int data = UART_RXDATA;

    // 清除状态位 (对应 sw zero, 4(t0))
    UART_STATUS = 0;

    return data;
}

/*
 * 发送 (对应汇编 tx_loop)
 */
void uart_tx(unsigned int data) {
    // 对应 wait_tx 标签下的循环
    // 检查 STATUS 的第0位 (TX_BUSY)
    // 汇编逻辑: bne t1, zero, wait_tx (如果为1则等待)
    while (UART_STATUS & TX_BUSY_BIT) {
        // 等待发送空闲...
    }

    // 对应 sw a0, 12(t0)
    UART_TXDATA = data;

    // 对应 ori t1, t1, 1; sw t1, 4(t0)
    // 手动将状态位 Bit 0 置为 1 (表示忙/正在发送)
    UART_STATUS |= TX_BUSY_BIT;
}

// 主程序

void start_kernel() {
    // 1. 初始化
    // 对应汇编: addi t1, zero, 3; sw t1, 0(t0)
    UART_CTRL = 3; // ....0011,使能 TX 和 RX

    // 用于循环的变量 (虽然汇编用了循环展开，这里用 while(1) 保持持续运行)
    while (1) {
        // 接收

        // 接收第1个数 (被除数)
        unsigned int dividend = uart_rx();
        // 存入 RAM 偏移 0 (0x10000000)
        RAM_PTR[0] = dividend;

        // 接收第2个数 (除数)
        unsigned int divisor = uart_rx();
        // 存入 RAM 偏移 4 (0x10000004)
        RAM_PTR[1] = divisor;

        // 计算

        unsigned int quotient = 0;
        unsigned int remainder = 0;

        // 避免除以 0 导致硬件异常
        if (divisor != 0) {
            // 对应汇编: div a3, a1, a2
            quotient = dividend / divisor;
            // 对应汇编: rem a4, a1, a2
            remainder = dividend % divisor;
        }

        // 存储

        // 存入 RAM 偏移 8 (0x10000008)
        RAM_PTR[2] = quotient;

        // 存入 RAM 偏移 12 (0x1000000C)
        RAM_PTR[3] = remainder;

        // 发送阶段
        // 先发商，再发余数

        // 发送商 (从 RAM 读取)
        uart_tx(RAM_PTR[2]);

        // 发送余数 (从 RAM 读取)
        uart_tx(RAM_PTR[3]);
    }
}