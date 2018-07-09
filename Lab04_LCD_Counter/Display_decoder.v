`timescale 1ns / 1ps
module Display_decoder( output reg [7:0] DigitalCG, 
				   input	[3:0] number
					  );
	parameter	SPACE	 = 8'b0010_0000,			// 8'hff: 显示空格
				ZERO	 = 8'b0011_0000,			// 8'h03: 显示 0           
				ONE		 = 8'b0011_0001,			// 8'h9f: 显示 1
				TWO		 = 8'b0011_0010,			// 8'h25: 显示 2
				THREE	 = 8'b0011_0011,			// 8'h0d: 显示 3
				FOUR	 = 8'b0011_0100,		    // 8'h99: 显示 4
				FIVE	 = 8'b0011_0101,			// 8'h41: 显示 5
				SIX		 = 8'b0011_0110,			// 8'h61: 显示 6
				SEVEN	 = 8'b0011_0111,			// 8'h1f: 显示 7
				EIGHT	 = 8'b0011_1000,			// 8'h01: 显示 8
				NINE	 = 8'b0011_1001;			// 8'h09: 显示 9
	always@( * )									// 产生译码输出
	begin
		case( number )							// 输入数据译码
			4'h0:	DigitalCG = ZERO;			// 显示 0
			4'h1:	DigitalCG = ONE;				// 显示 1
			4'h2:	DigitalCG = TWO;				// 显示 2
			4'h3: 	DigitalCG = THREE;			// 显示 3
			4'h4: 	DigitalCG = FOUR;			// 显示 4
			4'h5: 	DigitalCG = FIVE;			// 显示 5
			4'h6: 	DigitalCG = SIX;				// 显示 6
			4'h7: 	DigitalCG = SEVEN;			// 显示 7
			4'h8: 	DigitalCG = EIGHT;			// 显示 8
			4'h9: 	DigitalCG = NINE;			// 显示 9      
			4'ha: 	DigitalCG = ZERO;			// 显示空格
			default:DigitalCG = SPACE;			// 显示空格
		endcase
	end
endmodule