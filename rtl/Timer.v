module Timer(
    input CLK,       // 系统时钟
    input RESET,     // 复位信号（高电平有效）
    output reg [31:0] Do  // 32位计数输出，单位：毫秒
); 
    reg [31:0] count;     // 主计数器（记录毫秒数）
    reg [31:0] div_count; // 分频计数器（产生1ms脉冲）
    wire tick;            // 1ms周期的脉冲信号

    assign tick = (div_count == 32'd49999); // div_count从0数到49999，产生一个tick

    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            div_count <= 32'd0; // 复位时，分频计数器清零
        end else begin
            if (tick) begin
                div_count <= 32'd0; // 产生tick后，分频计数器重置
            end else begin
                div_count <= div_count + 32'd1; // 否则继续计数
            end
        end
    end

    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            count <= 32'd0; // 复位时，主计数器清零
        end else begin
            if (tick) begin
                count <= count + 32'd1; // 每收到一个1ms脉冲，计数+1
            end
        end
    end

    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            Do <= 32'd0; // 复位时，输出清零
        end else begin
            Do <= count; // 输出始终等于主计数器值（单位：毫秒）
        end
    end

endmodule