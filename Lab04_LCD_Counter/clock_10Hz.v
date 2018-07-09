`timescale 1ns / 1ps
module clock_10Hz( output reg clk_10Hz,	// 10Hz 时钟输出信号
                  input  clk,	     	// 系统时钟输入信号
                  input  rst			// 复位输入信号
                );
    
	parameter PULSESCOUNT = 22'h26_25A0,
                RESETZERO = 22'h0;
	reg [21:0] counter; //计数器, 25 bits (1_0111_1101_0111_1000_0100_0000(bin)) 
                          // 用于对系统时钟脉冲进行计数, 以产生 10Hz 输出时钟信号
	always @(posedge clk)
	begin
		if ( rst ) begin
			counter <= 0;
			clk_10Hz <= 0;
		end
		else begin
			 // -- 由 clock 信号的上升沿触发
			if ( counter < PULSESCOUNT )
			counter <= counter + 1'b1;
			else begin
				clk_10Hz <= ~clk_10Hz;
				counter <= RESETZERO;
			end
		end					
	end
endmodule