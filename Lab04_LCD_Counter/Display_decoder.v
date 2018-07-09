`timescale 1ns / 1ps
module Display_decoder( output reg [7:0] DigitalCG, 
				   input	[3:0] number
					  );
	parameter	SPACE	 = 8'b0010_0000,			// 8'hff: ��ʾ�ո�
				ZERO	 = 8'b0011_0000,			// 8'h03: ��ʾ 0           
				ONE		 = 8'b0011_0001,			// 8'h9f: ��ʾ 1
				TWO		 = 8'b0011_0010,			// 8'h25: ��ʾ 2
				THREE	 = 8'b0011_0011,			// 8'h0d: ��ʾ 3
				FOUR	 = 8'b0011_0100,		    // 8'h99: ��ʾ 4
				FIVE	 = 8'b0011_0101,			// 8'h41: ��ʾ 5
				SIX		 = 8'b0011_0110,			// 8'h61: ��ʾ 6
				SEVEN	 = 8'b0011_0111,			// 8'h1f: ��ʾ 7
				EIGHT	 = 8'b0011_1000,			// 8'h01: ��ʾ 8
				NINE	 = 8'b0011_1001;			// 8'h09: ��ʾ 9
	always@( * )									// �����������
	begin
		case( number )							// ������������
			4'h0:	DigitalCG = ZERO;			// ��ʾ 0
			4'h1:	DigitalCG = ONE;				// ��ʾ 1
			4'h2:	DigitalCG = TWO;				// ��ʾ 2
			4'h3: 	DigitalCG = THREE;			// ��ʾ 3
			4'h4: 	DigitalCG = FOUR;			// ��ʾ 4
			4'h5: 	DigitalCG = FIVE;			// ��ʾ 5
			4'h6: 	DigitalCG = SIX;				// ��ʾ 6
			4'h7: 	DigitalCG = SEVEN;			// ��ʾ 7
			4'h8: 	DigitalCG = EIGHT;			// ��ʾ 8
			4'h9: 	DigitalCG = NINE;			// ��ʾ 9      
			4'ha: 	DigitalCG = ZERO;			// ��ʾ�ո�
			default:DigitalCG = SPACE;			// ��ʾ�ո�
		endcase
	end
endmodule