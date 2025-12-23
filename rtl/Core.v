// 顶层模块
module Core(
    input CLK,
    input RESET, //cpu执行,低电平有效
    input wait_transport,   //等待传输信号,低电平有效
// --- 外部设备物理接口 ---
    output wire dig1,    //数码管从左到右为1-6
    output wire dig2,
    output wire dig3,
    output wire dig4, 
    output wire dig5, 
    output wire dig6, 
    output wire[6:0] out, // 数码管的公共I/O接口 
    output wire led1,     //led灯显示
    output wire led2,
    output wire led3,
    output wire led4,
    // output wire led5,
    // output wire led6,
    // output wire led7,
    // output wire led8,
    // 物理接口(输入输出串口)
    output wire uart_tx,
    input wire uart_rx

);

// 状态机
    //  1. 定义状态，用于处理字节接收和拼接
    localparam S_WAIT_COUNT    = 4'b0001; // 等待接收指令总数的低字节 1
    localparam S_WAIT_COUNT_MSB    = 4'b0010; // 等待接收指令总数的高字节 2
    localparam S_LOADING_INSTR_LSB1 = 4'b0011; // 等待接收指令的第一个低字节 3
    localparam S_LOADING_INSTR_LSB2 = 4'b0100; // 等待接收指令的第二个低字节 4
    localparam S_LOADING_INSTR_LSB3 = 4'b0101; // 等待接收指令的第三个低字节 5
    localparam S_LOADING_INSTR_MSB = 4'b0110; // 等待接收指令的高字节 6
    localparam S_LOAD_DONE         = 4'b0111; // 加载完成，等待启动 7
    localparam S_RUNNING           = 4'b1000; // CPU运行 8

    // 2. 添加状态寄存器、计数器和临时字节存储器
    reg [3:0] state_reg;
    reg [7:0] temp_lsb_reg1; // 用于暂存第一次接收到的低字节
    reg [7:0] temp_lsb_reg2; // 用于暂存第二次接收到的低字节
    reg [7:0] temp_lsb_reg3; // 用于暂存第三次接收到的低字节
    reg [15:0] expected_instr_count_reg;    // 期望的指令总数
    reg [15:0] received_instr_count_reg;    //  已接收的指令数

    // UART接口信号
    wire [7:0] uart_received_byte; // UART现在输出8位字节
    wire uart_byte_valid;   //UART数据有效信号

    // ROM接口
    wire [31:0] MachineCodeData;   //拼接后的机器码数据
    reg [31:0] MachineCodeAddress;    //机器码对应的地址
    
    // 指令总数寄存器
    wire [15:0] instr_count;
    assign instr_count = {uart_received_byte, temp_lsb_reg1};

// 内部信号
    wire cpu_run_enable;        // CPU运行使能


    // 控制单元模块
        wire[16:0]  op;   //17位操作码
        wire zero; // ALU的zero输出,作为条件，zero=0为真，zero=1为假
        wire divReady;    // 除法模块是否就绪
        wire[1:0]    m2reg; //决定写回寄存器文件来源。 0：把ALU的运算结果传回，1：把数据存储器的数据传回 2:把立即数左移后的数据传回 
        wire[1:0]    PCsrc;    // 控制程序计数器（PC）的更新来源，通常用于分支或跳转操作。PCsrc=0为不跳转，PCsrc=1为跳转PC=PC+offset, PCsrc=2为跳转PC=result=immExt + A_data(ALU的运算结果)
        wire    wmem; //控制存储器的写操作, 0为读，1为写
        wire[2:0] memc;    //控制写一字节还是两个字节，memc=0为 1字节（无符号），memc=1为 2字节（无符号）, memc=2为1个字(32位，4个字节), memc=3为 1字节（有符号）, memc=4为 2字节（有符号）
        wire[4:0]  aluc; //控制 ALU 的操作类型，通常用于选择 ALU 的加法、减法、逻辑运算等操作。共16种，前10种是计算，后六种是逻辑运算（作为条件实现跳转）
        wire    alusrc1;  // 控制 ALU 的操作数A输入来源，通常用于选择 ALU 的操作数。0为寄存器的数（add),1为立即数（addi)
        wire    alusrc2;  // 控制 ALU 的操作数B输入来源，通常用于选择 ALU 的操作数。0为寄存器的数（add),1为立即数（addi)
        wire    wreg;  // 控制寄存器的写操作  1为写回，0为不写回
        wire    jal;   // 控制跳转指令的跳转类型，通常用于选择跳转指令的类型。1为跳转，0为不跳转
        wire PCHold;     // 控制PC的更新，0为更新，1为不更新
    
    // PC模块
        wire [31:0] newAddress;     //PC的新指令地址
        wire [31:0] currentAddress;     //当前指令地址
    
    // ROM模块
        wire ROM_write_enable; // ROM实际写使能
        wire[31:0] instruction;     //根据指令地址取出的指令
        wire[31:0] RamDataAddress;  // RAM数据地址入口 
        wire[31:0] RamData;    // ROM传递给RAM的数据
    
    // 指令译码模块
        wire[4:0] rs1;    //源操作数1 (寄存器模块输入 A_addr)
        wire[4:0] rs2;    //源操作数2 (寄存器模块输入 B_addr)
        wire[4:0] rd;    //目的操作数   (寄存器模块输入 W_addr)
        wire[31:0] instruction_imm; //传递给立即数扩展模块的指令
    
    // 二路选择器模块，决定写入寄存器的数据
        wire [31:0] m2regData;   // 三路选择器的输出
        wire [31:0] Data;    // 写入寄存器的数据 （rd）

    // 寄存器模块
        wire [31:0] A_data;   // rs1寄存器数据输出
        wire [31:0] B_data;    // rs2寄存器数据输出


    //  立即数扩展模块
     wire[31:0] immExt;  //扩展后的32位立即数

    // ALU模块
        wire [31:0] A;     //操作数1(A_data)
        wire [31:0] B;     //操作数2(B_data 或 immExt)
        wire [31:0] Result;   //ALU运算结果(输入到三路选择器 | 输入到bus作为地址)

    // bus模块          //控制写入字节数，memc=0为1字节，memc=1为两个字节, memc=2为4个字节
        wire [31:0] Do;  //bus的输出数据
        wire led1_from_Bus;
        wire led2_from_Bus;
        wire led3_from_Bus;
        wire led4_from_Bus;
        reg uart_rx_inside;    // 串口通信的串行数据输入

    // uart_rx（动态下载模块）
        reg uart_rx_outside;    // 动态下载的串行数据输入


    // 3. 机器码数据拼接逻辑
    assign MachineCodeData = {uart_received_byte, temp_lsb_reg3, temp_lsb_reg2, temp_lsb_reg1}; // MSB在高位，LSB在低位

    // 4. 根据状态控制LED4，CPU运行，串口输入的选择
    assign led1 = ((state_reg == S_LOAD_DONE) || (state_reg == S_RUNNING)) ? led1_from_Bus : 1'b0;
    assign led2 = ((state_reg == S_LOAD_DONE) || (state_reg == S_RUNNING)) ? led2_from_Bus : 1'b0;
    assign led3 = ((state_reg == S_LOAD_DONE) || (state_reg == S_RUNNING)) ? led3_from_Bus : 1'b0;
    assign led4 = ((state_reg == S_LOAD_DONE) || (state_reg == S_RUNNING)) ? led4_from_Bus : 1'b1;
    
    // // CPU运行使能
    // assign cpu_run_enable = (state_reg == S_RUNNING);  
    
    // 串口输入的选择
    always @(*) begin
        if(state_reg == S_LOAD_DONE || state_reg == S_RUNNING) begin
            uart_rx_inside = uart_rx; // 串口输入选择
            uart_rx_outside = 1'b1;
        end
        else begin
            uart_rx_inside = 1'b1;
            uart_rx_outside = uart_rx; 
        end
    end
    

    // 5. 状态机逻辑 (核心改动)
    initial begin
        state_reg <= S_WAIT_COUNT;
        expected_instr_count_reg <= 0;
        received_instr_count_reg <= 0;
        MachineCodeAddress <= 0;
        // ... 其他寄存器初始化
    end
    // 指令下载ing
    always @(posedge CLK or negedge RESET) begin
        if (!RESET) begin
            state_reg <= S_RUNNING;
        end
        else if(wait_transport == 0)
            state_reg <= S_WAIT_COUNT;
        else begin
            case (state_reg)
                S_WAIT_COUNT: begin
                    if (uart_byte_valid) begin
                        temp_lsb_reg1 <= uart_received_byte;
                        state_reg <= S_WAIT_COUNT_MSB;
                    end
                end
                
                S_WAIT_COUNT_MSB: begin
                    if (uart_byte_valid) begin
                        expected_instr_count_reg <= instr_count; // 拼接成16计数值
                        received_instr_count_reg <= 0;
                        MachineCodeAddress <= 0;
                        if (instr_count == 0) begin
                            state_reg <= S_LOAD_DONE;
                        end else begin
                            state_reg <= S_LOADING_INSTR_LSB1;
                        end
                    end
                end

                S_LOADING_INSTR_LSB1: begin
                    if (uart_byte_valid) begin
                        temp_lsb_reg1 <= uart_received_byte;
                        state_reg <= S_LOADING_INSTR_LSB2;
                    end
                end
                
                S_LOADING_INSTR_LSB2: begin
                    if (uart_byte_valid) begin
                        temp_lsb_reg2 <= uart_received_byte;
                        state_reg <= S_LOADING_INSTR_LSB3;
                    end
                end
                
                S_LOADING_INSTR_LSB3: begin
                    if (uart_byte_valid) begin
                        temp_lsb_reg3 <= uart_received_byte;
                        state_reg <= S_LOADING_INSTR_MSB;
                    end
                end

                S_LOADING_INSTR_MSB: begin
                    if (uart_byte_valid) begin
                        // 此时 MachineCodeData 是完整的32位指令，可以写入ROM
                        // ROM_write_enable 会在此状态且uart_byte_valid时为高
                        
                        received_instr_count_reg <= received_instr_count_reg + 1;
                        MachineCodeAddress <= MachineCodeAddress + 1;

                        if ((received_instr_count_reg + 1) == expected_instr_count_reg) begin
                            state_reg <= S_LOAD_DONE;
                        end else begin
                            state_reg <= S_LOADING_INSTR_LSB1; // 返回等待下一条指令的低字节
                        end
                    end
                end
                
                S_LOAD_DONE: begin

                end
                
                S_RUNNING: begin

                end

            endcase
        end
    end



    // 6. 指令存储器写使能逻辑
    // 只有在接收到一条指令的高字节时，才产生写使能脉冲
    assign ROM_write_enable = (state_reg == S_LOADING_INSTR_MSB) && uart_byte_valid;





// 模块实例
    // 点号前的名称是形参， 括号内的是实参
    ControlUnit controlUnit(
        .op(op),
        .zero(zero),
        .divReady(divReady),
        .m2reg(m2reg),
        .PCsrc(PCsrc),
        .wmem(wmem),
        .memc(memc),
        .aluc(aluc),
        .alusrc1(alusrc1),
        .alusrc2(alusrc2),
        .wreg(wreg),
        .jal(jal),
        .PCHold(PCHold)
    );

    PC pc(
        .CLK(CLK),
        .RESET(RESET),
        .PCHold(PCHold),
        .newAddress(newAddress),
        .currentAddress(currentAddress)
    );

    Rom rom(
        .CLK(CLK),
        .ROM_write_enable(ROM_write_enable),
        .MachineCodeAddress(MachineCodeAddress),
        .MachineCodeData(MachineCodeData),
        .A(currentAddress),
        .RamDataAddress(RamDataAddress),
        .instruction(instruction),
        .RamData(RamData)
    );

    InstructionMemory instructionMemory(
        .instruction(instruction),
        .op(op),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .instruction_imm(instruction_imm)
    );

    // 二路选择器，决定写入寄存器的数据
    wire [31:0] currentAddress_4; // 显式定义为32位
    assign currentAddress_4 = currentAddress + 4;
    Multiplexer21 m21_0(
        .control(jal),
        .in0(m2regData),
        .in1(currentAddress_4),
        .out(Data)
    );

    RegisterFile registerFile(
        .CLK(CLK),
        .RESET(RESET),
        .wreg(wreg),
        .A_addr(rs1),
        .B_addr(rs2),
        .W_addr(rd),
        .Data(Data),
        .A_data(A_data),
        .B_data(B_data)
    );

    immGen immGen(
        .instruction(instruction_imm),
        .immExt(immExt)
    );

    // 二路选择器，决定A的输入来源是 A_data 或者 currentAddress
    Multiplexer21 m21_1(
        .control(alusrc1),
        .in0(A_data),
        .in1(currentAddress),
        .out(A)
    );

    // 二路选择器，决定B的输入来源是B_data或者immExt
    Multiplexer21 m21_2(
        .control(alusrc2),
        .in0(B_data),
        .in1(immExt),
        .out(B)
    );

    ALU alu(
        .CLK(CLK),
        .RESET(RESET),
        .aluc(aluc),
        .A(A),
        .B(B),
        .Result(Result),
        .zero(zero),
        .divReady(divReady)
    );
    wire [31:0] currentAddress_Imm;
    assign currentAddress_Imm = currentAddress + $signed(immExt);

    // 三路选择器，选择写回pc的数据源
    Multiplexer31 m31_0(
        .control(PCsrc),
        .in0(currentAddress_4),
        .in1(currentAddress_Imm),
        .in2(Result),
        .out(newAddress)
    );


    Bus bus(
        .CLK(CLK),
        .RESET(RESET),
        .wmem(wmem),
        .memc(memc),
        .A(Result),
        .Di(B_data),
        .RamData(RamData),
        .Do(Do),
        .RamDataAddress(RamDataAddress),
    // --- 外部设备物理接口 ---
        .dig1(dig1),    //数码管从左到右为1-6
        .dig2(dig2),
        .dig3(dig3),
        .dig4(dig4), 
        .dig5(dig5), 
        .dig6(dig6), 
        .out(out), // 数码管的公共I/O接口 
        .led1(led1_from_Bus),     //led灯显示
        .led2(led2_from_Bus),
        .led3(led3_from_Bus),
        .led4(led4_from_Bus),
        // .led5(led5),
        // .led6(led6),
        // .led7(led7),
        // .led8(led8),
        
        .uart_tx(uart_tx),
        .uart_rx(uart_rx_inside)

    );

    // 三路选择器 选择写回寄存器的二路选择器的数据
    Multiplexer31 m31_1(
        .control(m2reg),
        .in0(Result),
        .in1(Do),
        .in2(immExt),
        .out(m2regData)
    );

    // 动态下载部件
    uart_rx u_uart_rx (
        .sys_clk(CLK),
        .sys_rst_n(RESET), // UART模块可以被主复位按钮复位
        .rx(uart_rx_outside),
        .po_data(uart_received_byte),
        .po_flag(uart_byte_valid)
    );

endmodule