/*
 * UART 接收 - 数码管显示
 *
 * 接收 被除数 显示在 SEG 1-3
 * 接收 除数 显示在 SEG 4-6
 */

// UART (基地址 0x30000000)
#define UART_BASE 0x30000000
#define UART_CTRL   (*(volatile unsigned int*)(UART_BASE + 0x00))
#define UART_STATUS (*(volatile unsigned int*)(UART_BASE + 0x04))
#define UART_RXDATA (*(volatile unsigned int*)(UART_BASE + 0x10))

// 接受状态位: 选择第一位   ....0000010
#define RX_DONE_BIT (1 << 1)

// 数码管 (基地址 0x40000000, 偏移 1-6)
#define SEG_1 (*(volatile unsigned char*)0x40000001) // 左1
#define SEG_2 (*(volatile unsigned char*)0x40000002) // 左2
#define SEG_3 (*(volatile unsigned char*)0x40000003) // 左3

#define SEG_4 (*(volatile unsigned char*)0x40000004) // 右1
#define SEG_5 (*(volatile unsigned char*)0x40000005) // 右2
#define SEG_6 (*(volatile unsigned char*)0x40000006) // 右3

// 数码管 0-9 编码表
// const unsigned char seg_codes[] = {
//     0x3F, 0x06, 0x5B, 0x4F, 0x66, 
//     0x6D, 0x7D, 0x07, 0x7F, 0x6F
// };

// 阻塞等待并接收一个数据
unsigned int uart_rx() {
    // 对应
    // wait_rx:
    //   lw t1, 4(t0)
    //   andi t1, t1, 2
    //   beq t1, zero, wait_rx
    while (!(UART_STATUS & RX_DONE_BIT)) {
        // 按位与，取出UART_STATUS的第一位，接收完成标志（1表示接收完成，0表示正在接收）
        // 当为0时，与运算得到的是0，表示正在接收，
        // 取非，值为1,进入循环等待
    }

    // 对应 lw a0, 16(t0)，读数
    unsigned int data = UART_RXDATA ;

    // 对应 sw zero, 4(t0)，置零
    UART_STATUS = 0; 

    return data;
}

void start_kernel() {
    // 初始化 UART (使能接收 Bit 1 = 1)
    // 对应汇编: addi t1, zero, 3; sw t1, 0(t0)
    UART_CTRL = 3; // ..000011,控制寄存器，可以发送/接收

    // 清屏
    SEG_1 = 0; SEG_2 = 0; SEG_3 = 0;
    SEG_4 = 0; SEG_5 = 0; SEG_6 = 0;

    while (1) {
        // 接收被除数
        unsigned int num1 = uart_rx();

        // 接收除数
        unsigned int num2 = uart_rx();

        // 显示被除数
        SEG_1 = (num1 / 100) % 10; // 百
        SEG_2 = (num1 / 10) % 10;  // 十
        SEG_3 = num1 % 10;         // 个

        // 显示除数
        SEG_4 = (num2 / 100) % 10; // 百
        SEG_5 = (num2 / 10) % 10;  // 十
        SEG_6 = num2 % 10;         // 个
    }
}