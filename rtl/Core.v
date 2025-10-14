// 顶层模块
module Core(
    input CLK,
    input RESET, //cpu执行,低电平有效
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
    output wire led5,
    output wire led6,
    output wire led7,
    output wire led8

);


// 内部信号
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
    assign currentAddress_Imm = currentAddress + immExt;
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
        .led1(led1),     //led灯显示
        .led2(led2),
        .led3(led3),
        .led4(led4),
        .led5(led5),
        .led6(led6),
        .led7(led7),
        .led8(led8)

    );

    // 三路选择器 选择写回寄存器的二路选择器的数据
    Multiplexer31 m31_1(
        .control(m2reg),
        .in0(Result),
        .in1(Do),
        .in2(immExt),
        .out(m2regData)
    );

endmodule