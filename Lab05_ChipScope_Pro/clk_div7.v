module clock_div7( output reg clk_div7 , input clock , input rst_n);
	reg[5:0]temp;
	always@(posedge clock or negedge rst_n)
	begin
		if(!rst_n)
		begin
			clk_div7<=1;
			temp<=6'b0;
		end
		else 
		begin
			temp<={temp[4:0],clk_div7};
			clk_div7<=temp[5];
		end
	end
endmodule