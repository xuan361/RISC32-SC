// DataMemory：用于内存存储，内存读写
// 更改为Bus.v 模块
module DataMemory(
    input CLK,
    input RESET,
    // 信号
    input wmem,           //读写信号，1为写，0为读
    input memc,             //控制写入字节数，memc=0为1字节，memc=1为两个字节, memc=2为4个字节
    // 输入数据
    input [31:0] A,     //地址 (ALU的result)
    input [31:0] Di,    //输入数据 (B_data)

    // 输出数据
    output reg [31:0] Do  //输出数据

); 







endmodule