// Bus: 这个总线模块的核心功能是 地址译码。
// 它会根据CPU（Core）发出的地址，判断请求应该发往哪个外设（ROM、RAM、Timer等）。
module Bus(
    input CLK,
    input RESET,
    // 信号
    input wmem,           //读写信号，1为写，0为读
    input memc,             //控制写入字节数，memc=0为1字节，memc=1为两个字节, memc=2为4个字节
    // 输入数据
    input [31:0] A,     //地址 (ALU的result)
    input [31:0] Di,    //输入数据 (B_data)
    input [31:0] RamData, //RAM数据

    // 输出数据
    output reg [31:0] Do,  //输出数据
    output reg [31:0] RamDataAddress, // RAM数据地址

    // --- 物理接口 (实际硬件连接) ---
    output wire uart_tx,
    input wire uart_rx,

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
    output reg led4,
    output reg led5,
    output reg led6,
    output reg led7,
    output reg led8
);
    // 片选信号
    reg wRam;
    reg wUart;
    reg wGpio;   
    // 片选地址
    reg[31:0] A_Ram;    //Ram的输入地址
    reg[31:0] A_Timer;    //Timer的输入地址
    reg[31:0] A_UART;    //UART的输入地址
    reg[31:0] A_GPIO;    //GPIO的输入地址
    // 输入数据
    reg[31:0] Di_Ram;
    // 输出数据
    reg[31:0] Do_Ram;    //Ram的输出数据
    reg[31:0] Do_Timer;    
    reg[31:0] Do_Uart;    
    reg[31:0] Do_Gpio;    

    always @(*) begin
        Di_Ram = Di;
        // 地址译码
        case(A[31:28])
            4'd0: begin     // 向ROM传递地址，接收来自ROM的数据并输出
                RamDataAddress = A;
                Do = RamData;
                wRam = 0;
                wUart = 0;
                wGpio = 0; 
            end
            4'd1: begin
                A_Ram = {4'd0, A[27:0]};
                Do = Do_Ram;
                wRam = 1;
                wUart = 0;
                wGpio = 0; 
            end
            4'd2: begin
                A_Timer = {4'd0, A[27:0]};
                Do = Do_Timer;
                wRam = 0;
                wUart = 0;
                wGpio = 0; 
            end
            4'd3: begin
                A_UART = {4'd0, A[27:0]};
                Do = Do_Uart;
                wRam = 0;
                wUart = 1;
                wGpio = 0; 
            end
            4'd4: begin     // GPIO
                A_GPIO = {4'd0, A[27:0]};
                Do = Do_Gpio;
                wRam = 0;
                wUart = 0;
                wGpio = 1; 
            end
            default: begin // 默认处理，防止产生锁存器
                Do = 32'h0;
                RamDataAddress = A;
                A_Ram = {4'd0, A[27:0]};
                A_Timer = {4'd0, A[27:0]};
                A_UART = {4'd0, A[27:0]};
                A_GPIO = {4'd0, A[27:0]};
                wRam = 0;
                wUart = 0;
                wGpio = 0;
            end
        endcase
    end

    
    Ram ram(CLK, RESET, wRam, memc, A_Ram, Di_Ram, Do_Ram);
    Timer timer(CLK, RESET, Do_Timer);
    
    // 仍需完善
    Uart uart(
        .CLK(CLK), 
        .RESET(RESET), 
        .wUart(wUart),       // 片选信号
        .wmem(wmem),     // 写使能信号
        .A_UART(A_UART),    // 内部地址
        .Di(Di),       // 写入数据
        .Do_Uart(Do_Uart),   // 读出数据
        .uart_tx(uart_tx),          // 可连接到FPGA顶层引脚
        .uart_rx(uart_rx)           // 可连接到FPGA顶层引脚
    );
    
    Gpio gpio(
        .CLK(CLK), 
        .RESET(RESET), 
        .wGpio(wGpio),       // 片选信号
        .wmem(wmem),     // 写使能信号
        .A_GPIO(A_GPIO),    // 内部地址
        .Di(Di),       // 写入数据
        .Do_Gpio(Do_Gpio),   // 读出数据
    // --- 外部设备物理接口 ---
        .dig1(dig1),
        .dig2(dig2),
        .dig3(dig3),
        .dig4(dig4),
        .dig5(dig5),
        .dig6(dig6),
        .out(out),
        .led1(led1),
        .led2(led2),
        .led3(led3),
        .led4(led4),
        .led5(led5),
        .led6(led6),
        .led7(led7),
        .led8(led8)
    );



    
endmodule