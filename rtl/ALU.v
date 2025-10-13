`timescale 1ns / 1ps

//------------------------------------------------------------------
// 模块: ALU (功能丰富的算术逻辑单元)
// 描述: 一个32位的ALU，支持RISC-V指令集中常见的算术、逻辑、
//       移位、分支比较以及多周期的乘法、除法和求余操作。
//------------------------------------------------------------------
module ALU(
    input           CLK,
    input           RESET,
    input   [4:0]   aluc,
    input   [31:0]  A,
    input   [31:0]  B,
    output  [31:0]  Result,
    output          zero,
    output  reg     divReady    // divReady = 1 除法/求余完成
);

    // ========== 操作码定义 ==========
    // 基础运算 (I-Type, R-Type)
    localparam OP_ADD   = 5'd0;  // add
    localparam OP_SUB   = 5'd1;  // sub
    localparam OP_SLL   = 5'd2;  // sll
    localparam OP_SLT   = 5'd3;  // slt
    localparam OP_SLTU  = 5'd4;  // sltu
    localparam OP_XOR   = 5'd5;  // xor
    localparam OP_SRL   = 5'd6;  // srl
    localparam OP_SRA   = 5'd7;  // sra
    localparam OP_OR    = 5'd8;  // or
    localparam OP_AND   = 5'd9;  // and
    // 分支比较 (B-Type)
    localparam OP_BEQ   = 5'd10; // beq
    localparam OP_BNE   = 5'd11; // bne
    localparam OP_BLT   = 5'd12; // blt
    localparam OP_BGE   = 5'd13; // bge
    localparam OP_BLTU  = 5'd14; // bltu
    localparam OP_BGEU  = 5'd15; // bgeu
    // 乘法 (M-Extension)
    localparam OP_MUL   = 5'd16; // mul
    localparam OP_MULH  = 5'd17; // mulh (signed * signed)
    localparam OP_MULHSU= 5'd18; // mulhsu (signed * unsigned)
    localparam OP_MULHU = 5'd19; // mulhu (unsigned * unsigned)
    // 除法 (M-Extension)
    localparam OP_DIV   = 5'd20; // div (signed)
    localparam OP_DIVU  = 5'd21; // divu (unsigned)
    localparam OP_REM   = 5'd22; // rem (signed)
    localparam OP_REMU  = 5'd23; // remu (unsigned)

    // ========== 组合逻辑部分 ==========
    reg [31:0] comb_result;
    
    // 为不同类型的乘法准备64位中间结果
    wire [63:0] mul_res_ss = $signed(A) * $signed(B);   // signed * signed
    wire [63:0] mul_res_su = $signed(A)   * B; // signed * unsigned
    wire [63:0] mul_res_uu = A * B; // unsigned * unsigned

    always @(*) begin
        case (aluc)
            // 基础运算
            OP_ADD:  comb_result = A + B;
            OP_SUB:  comb_result = A - B;
            OP_SLL:  comb_result = A << B[4:0];
            OP_SLT:  comb_result = ($signed(A) < $signed(B)) ? 32'd1 : 32'd0;
            OP_SLTU: comb_result = (A < B) ? 32'd1 : 32'd0;
            OP_XOR:  comb_result = A ^ B;
            OP_SRL:  comb_result = A >> B[4:0];
            OP_SRA:  comb_result = $signed(A) >>> B[4:0];
            OP_OR:   comb_result = A | B;
            OP_AND:  comb_result = A & B;
            // 分支比较: 结果为1(真)或0(假)
            OP_BEQ:  comb_result = (A == B) ? 32'd1 : 32'd0;
            OP_BNE:  comb_result = (A != B) ? 32'd1 : 32'd0;
            OP_BLT:  comb_result = ($signed(A) < $signed(B)) ? 32'd1 : 32'd0;
            OP_BGE:  comb_result = ($signed(A) >= $signed(B)) ? 32'd1 : 32'd0;
            OP_BLTU: comb_result = (A < B) ? 32'd1 : 32'd0;
            OP_BGEU: comb_result = (A >= B) ? 32'd1 : 32'd0;
            // 乘法
            OP_MUL:  comb_result = mul_res_uu[31:0]; 
            OP_MULH: comb_result = mul_res_ss[63:32];
            OP_MULHSU:comb_result= mul_res_su[63:32];
            OP_MULHU:comb_result = mul_res_uu[63:32];
            // 默认值
            default: comb_result = 32'hxxxxxxxx;
        endcase
    end

    // ========== 时序逻辑部分 (除法/求余状态机) ==========
    localparam FSM_IDLE = 2'b00;
    localparam FSM_BUSY = 2'b01;
    localparam FSM_DONE = 2'b10;

    reg [1:0] state;
    reg [31:0] seq_result; 

    // 判断当前操作是否为多周期的除法/求余
    wire is_div_rem_op = (aluc >= OP_DIV) && (aluc <= OP_REMU);

    // 除法所需寄存器
    reg [4:0] div_op;   // 操作码
    reg [31:0] dividend;     // 被除数
    reg [31:0] divisor;      // 除数
    reg [31:0] quotient;    // 商
    reg [31:0] remainder;   // 余数
    reg [31:0] remainder_next;   // 余数暂存器, 保证比较使用的是“左移后”的余数

    reg [5:0] bit_count;            // 计数器，用来控制迭代次数

    // 记录除法的结果对应符号
    reg sign_dividend;
    reg sign_divisor;
    wire sign_quotient = sign_dividend ^ sign_divisor;  // 商的符号
    wire sign_remainder = sign_dividend;    // 余数的符号

    // 有符号结果
    reg [31:0] quotient_signed;    // 商
    reg [31:0] remainder_signed;   // 余数
    
    always @(posedge CLK or negedge RESET) begin
        if (!RESET) begin
            state       <= FSM_IDLE;
            divReady    <= 1'b1;
            seq_result  <= 32'd0;
            // 清空除法寄存器
            div_op <= 5'd0;
            dividend <= 32'd0;
            divisor <= 32'd0;
            quotient <= 32'd0;
            remainder <= 32'd0;
            bit_count <= 6'd0;
            sign_dividend <= 1'b0;
            sign_divisor <= 1'b0;
            remainder_next <= 32'd0;
        end else begin
            case (state)
                // 初始状态
                FSM_IDLE: begin
                    if (is_div_rem_op) begin
                        divReady <= 1'b0;
                        state <= FSM_BUSY;
                        div_op <= aluc;
                        // 进行除法初始值的配置
                        sign_dividend <= A[31];
                        sign_divisor <= B[31];
                        if(aluc == OP_DIV || aluc == OP_REM) begin
                            // 对负数取补码（得到正数），用于无符号除法
                            dividend <= A[31] ? (~A + 1) : A;     // 被除数
                            divisor <= B[31] ? (~B + 1) : B;      // 除数
                        end
                        else begin
                            dividend <= A;     // 被除数
                            divisor <= B;      // 除数
                        end
                        quotient <= 32'd0;    // 商
                        remainder <= 32'd0;   // 余数
                        bit_count <= 6'd32; // 迭代次数
                    end
                end
    
                // 计算进行中   
                FSM_BUSY: begin
                    // 特殊情况: -2^31 / -1
                    if ((aluc == OP_DIV || aluc == OP_REM) && (A == 32'h80000000) && (B == 32'hFFFFFFFF)) begin
                        case (aluc)
                            OP_DIV: seq_result <= 32'h80000000;
                            OP_REM: seq_result <= 32'd0;
                        endcase
                        state <= FSM_DONE;
                        divReady <= 1'b1;
                    end
                    // --- 除零处理 ---
                    else if (B == 32'd0) begin
                        case (aluc)
                            OP_DIV, OP_DIVU: seq_result <= 32'hFFFFFFFF;
                            OP_REM, OP_REMU: seq_result <= A; // 被除数
                        endcase
                        state <= FSM_DONE;
                        divReady <= 1'b1;
                    end 
                    // --- 正常计算 ---
                    else begin
                        if (bit_count == 6'd0) begin
                            
                            // 处理计算结果
                            quotient_signed = sign_quotient ? (~quotient + 1) : quotient;
                            remainder_signed = sign_remainder ? (~remainder + 1) : remainder;

                            case(div_op)
                                OP_DIV:  seq_result <= quotient_signed; 
                                OP_DIVU: seq_result <= quotient;
                                OP_REM:  seq_result <= remainder_signed;
                                OP_REMU: seq_result <= remainder;
                            endcase
                            state <= FSM_DONE;
                            divReady <= 1'b1;
                        end
                        else begin
                            bit_count <= bit_count - 1;
                            // 进行除法迭代
                            remainder_next = {remainder[30:0], dividend[31]};    // 将被除数的最高位移入余数中

                            if(remainder_next >= divisor)begin
                                remainder <= remainder_next - divisor; 
                                quotient <= {quotient[30:0], 1'b1};
                            end
                            else begin
                                remainder <= remainder_next;    
                                quotient <= {quotient[30:0], 1'b0}; 
                            end
                            
                            dividend <= dividend << 1;
                        end
                    end
                end
                
                // 计算完成
                FSM_DONE: begin
                    state <= FSM_IDLE;
                end

                default: begin
                    state <= FSM_IDLE;
                end
            endcase
        end
    end

    // ========== 输出逻辑 ==========
    // 如果是除法/求余且已完成，则输出时序逻辑的结果(seq_result)
    // 否则，直接输出组合逻辑的结果(comb_result)
    assign Result = (state == FSM_DONE) ? seq_result : comb_result;
    assign zero = (Result == 32'd0);

endmodule