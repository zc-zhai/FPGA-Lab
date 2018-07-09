`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    12:20:52 03/27/2018 
// Design Name: 
// Module Name:    LEDflowing 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module LEDflowing(
    input clk,
    output reg [7:0] led
    );
	 
	 reg clk_1hz;
	 reg [24:0] count;
	 
	 always @ (posedge clk)
	 begin
	 if (count < 25'b1_0111_1101_0111_1000_0100_0000)
	 count <= count+1;
	 else
	 begin
	 count <= 0;
	 clk_1hz <= ~clk_1hz;
	 end
	 end
	 
	 always @ (posedge clk_1hz)
	 begin
	 case(led)
	 8'b0000_0000: led<=8'b0000_0001;
	 8'b0000_0001: led<=8'b0000_0011;
	 8'b0000_0011: led<=8'b0000_0111;
	 8'b0000_0111: led<=8'b0000_1111;
	 8'b0000_1111: led<=8'b0001_1111;
	 8'b0001_1111: led<=8'b0011_1111;
	 8'b0011_1111: led<=8'b0111_1111;
	 8'b0111_1111: led<=8'b1111_1111;
	 8'b1111_1111: led<=8'b0000_0001;
	 default: led <=8'b0000_0000;
	 endcase
	 end


endmodule
