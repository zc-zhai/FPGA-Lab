`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    13:15:10 03/27/2018 
// Design Name: 
// Module Name:    RotarySwitch 
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
module RotarySwitch(
    input rotary_a,
    input rotary_b,
    input buttom,
	 input clk,
    output [7:0] ledout
    );
	 
	 reg rotary_q1,rotary_q2,delay_rotary_q1,rotary_event,rotary_left;
	 reg [1:0] rotary_in;
	 reg [7:0] led;
	 
	 always @( posedge clk )
    begin : rotary_filter
	// concatinate rotary input signals to form vector for case construct.
	rotary_in <= {rotary_b, rotary_a};
	case (rotary_in)
		2'b00: rotary_q1 <= 1'b0;
		2'b01: rotary_q2 <= 1'b0;
		2'b10: rotary_q2 <= 1'b1;
		2'b11: rotary_q1 <= 1'b1;
		default: begin
			rotary_q1 <= 1'b0;
			rotary_q2 <= 1'b0;
		end
	endcase
	end
	
	always @(posedge clk )
	begin : direction
	delay_rotary_q1 <= rotary_q1;
	if ( rotary_q1 && (!delay_rotary_q1) )
	begin
		rotary_event <= 1'b1;
		rotary_left <= rotary_q2;
	end
	else
		rotary_event <= 1'b0;
	end
	
	always @(posedge clk)
	begin
	if (rotary_event && rotary_left)
	begin
	case(led)
		8'b0000_0000: led<=8'b0000_0001;
		8'b0000_0001: led<=8'b0000_0010;
		8'b0000_0010: led<=8'b0000_0100;
		8'b0000_0100: led<=8'b0000_1000;
		8'b0000_1000: led<=8'b0001_0000;
		8'b0001_0000: led<=8'b0010_0000;
		8'b0010_0000: led<=8'b0100_0000;
		8'b0100_0000: led<=8'b1000_0000;
		8'b1000_0000: led<=8'b0000_0001;
		default:led<=8'b0000_0000;
	endcase
	end
	else
	begin
	if(rotary_event && (!rotary_left))
	begin
	case(led)
		8'b0000_0000: led<=8'b0000_0001;
		8'b1000_0000: led<=8'b0100_0000;
		8'b0100_0000: led<=8'b0010_0000;
		8'b0010_0000: led<=8'b0001_0000;
		8'b0001_0000: led<=8'b0000_1000;
		8'b0000_1000: led<=8'b0000_0100;
		8'b0000_0100: led<=8'b0000_0010;
		8'b0000_0010: led<=8'b0000_0001;
		8'b0000_0001: led<=8'b1000_0000;
		default:led<=8'b0000_0000;
	endcase
	end
	else ;
	end
	end
	
	assign ledout = (buttom) ? (~led) : led ;

endmodule
