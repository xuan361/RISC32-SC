/*
 * 时钟显示
 * 从 Timer (0x20000000) 读取毫秒数
 * 将毫秒数转换为 时:分:秒
 * 将 时:分:秒 的 6 个数字显示在 GPIO 的 6 个数码管上 (0x40000001 - 0x40000006)
 */

// Timer : 1 个 32位 毫秒计数器
// 地址: 0x20000000, 偏移: 0x0
#define TIMER_MS (*(volatile unsigned int*)0x20000000)

// GPIO : 6 个 8位 寄存器 (0x1 到 0x6)
// 基地址: 0x40000000
#define SMG_DISPLAY_1 (*(volatile unsigned char*)0x40000001)
#define SMG_DISPLAY_2 (*(volatile unsigned char*)0x40000002)
#define SMG_DISPLAY_3 (*(volatile unsigned char*)0x40000003)
#define SMG_DISPLAY_4 (*(volatile unsigned char*)0x40000004)
#define SMG_DISPLAY_5 (*(volatile unsigned char*)0x40000005)
#define SMG_DISPLAY_6 (*(volatile unsigned char*)0x40000006)


// unsigned char get_7seg_code(unsigned int digit) {
//     // 7-segment 编码 (0, 1, 2, 3, 4, 5, 6, 7, 8, 9)
//     // 索引 (index) 对应数字
//     const unsigned char seg_codes[10] = {
//         0x3F, // 0
//         0x06, // 1
//         0x5B, // 2
//         0x4F, // 3
//         0x66, // 4
//         0x6D, // 5
//         0x7D, // 6
//         0x07, // 7
//         0x7F, // 8
//         0x6F  // 9
//     };

//     if (digit > 9) {
//         return 0x00; // 错误或关闭
//     }
//     return seg_codes[digit];
// }


void start_kernel() {
    unsigned int time_ms;
    unsigned int total_seconds;
    unsigned int hours, minutes, seconds;

    unsigned int s1, s2, m1, m2, h1, h2; // 6 个数字

    // 无限循环
    while (1) {
        // 读取毫秒数
        time_ms = TIMER_MS;

        // 毫秒转换时分秒
        total_seconds = time_ms / 1000;
        seconds = total_seconds % 60;
        minutes = (total_seconds / 60) % 60;
        hours   = (total_seconds / 3600) % 100; 

        // 时分秒 分解 6 个单独数字
        s2 = seconds % 10; // 秒 (个位)
        s1 = seconds / 10; // 秒 (十位)
        m2 = minutes % 10; // 分 (个位)
        m1 = minutes / 10; // 分 (十位)
        h2 = hours   % 10; // 时 (个位)
        h1 = hours   / 10; // 时 (十位)

        // 6 个数字写入 6 个数码管
        // (顺序 H1 H2 : M1 M2 : S1 S2)
        SMG_DISPLAY_1 = h1;
        SMG_DISPLAY_2 = h2;
        SMG_DISPLAY_3 = m1;
        SMG_DISPLAY_4 = m2;
        SMG_DISPLAY_5 = s1;
        SMG_DISPLAY_6 = s2;
    }
}