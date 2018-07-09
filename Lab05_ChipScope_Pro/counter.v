`timescale 1ns / 1ps
`include "counter_simple.v"
`include "clk_div7.v"
module counter(output [5:0]count, input clock , input rst_n , input dir);
	wire clk_div7;

	clock_div7 c(.clk_div7(clk_div7) , .clock(clock) , .rst_n(rst_n));
	counter_simple cs(.count(count) , .clock(clk_div7) , .rst_n(rst_n) , .dir(dir) );

	wire [35:0]CONTROL;

	// ---------- Begin Cut here for INSTANTIATION Template ----- INST_TAG
	CNT_ILA instance_name (
    	.CONTROL(CONTROL),
    	.CLK(clock),
    	.DATA(count),
    	.TRIG0(count[5:4])
	);
	// INST_TAG_END ------ End INSTANTIATION Template ---------

	// Instantiate the module
	// ---------- Begin Cut here for INSTANTIATION Template ----- INST_TAG
	CNT_ICON instance_name (
    	.CONTROL0(CONTROL)
	);
	// INST_TAG_END ------ End INSTANTIATION Template ---------	
endmodule