module counter_simple(output reg [5:0]count, input clock , input rst_n , input dir);
	always@(posedge clock or negedge rst_n)
	begin
		if (!rst_n)
			count <= (dir)? 6'b11_1111 : 6'b0;
		else
			begin
				if (!dir)
					count <= count + 1;
				else
					count <= count - 1;
			end
	end
endmodule