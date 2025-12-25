// GPIO (LED) 的寄存器地址位于 0x40000000
// 一个8位寄存器 ，使用 unsigned char (8位)
// volatile 关键字防止编译器优化掉对这个地址的读写
#define LED_REG (*(volatile unsigned char *)0x40000000)

/*
 * 裸机延迟函数
 * 通过执行一个空循环来消耗 CPU 时间
 * 循环的次数 "count" 需要根据实际硬件速度来调整
 */
void simple_delay(long long count) {
    volatile long long i;
    for (i = 0; i < count; i++);
}

/*
 * start.S 最后会 "j start_kernel"
 * C 语言入口点
 */
void start_kernel() {
    // 延迟时间
    const long long DELAY_COUNT = 100000;

    // 无限循环
    while (1) {
        // 对应 10000000 状态
        LED_REG = 0x01; // 二进制 00000001
        simple_delay(DELAY_COUNT);

        // 对应 01000000 状态
        LED_REG = 0x02; // 二进制 00000010
        simple_delay(DELAY_COUNT);

        // 对应 00100000 状态
        LED_REG = 0x04; // 二进制 00000100
        simple_delay(DELAY_COUNT);

        // 对应 00010000 状态
        LED_REG = 0x08; // 二进制 00001000
        simple_delay(DELAY_COUNT);

        // 对应 00001000 状态
        LED_REG = 0x10; // 二进制 00010000
        simple_delay(DELAY_COUNT);

        // 对应 00000100 状态
        LED_REG = 0x20; // 二进制 00100000
        simple_delay(DELAY_COUNT);

        // 对应 00000010 状态
        LED_REG = 0x40; // 二进制 01000000
        simple_delay(DELAY_COUNT);

        // 对应 00000001 状态
        LED_REG = 0x80; // 二进制 10000000
        simple_delay(DELAY_COUNT);
    }
}
