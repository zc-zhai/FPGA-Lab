`timescale 1ns / 1ps
module clock_10Hz( output reg clk_10Hz,	// 10Hz ʱ������ź�
                  input  clk,	     	// ϵͳʱ�������ź�
                  input  rst			// ��λ�����ź�
                );
    
	parameter PULSESCOUNT = 22'h26_25A0,
                RESETZERO = 22'h0;
	reg [21:0] counter; //������, 25 bits (1_0111_1101_0111_1000_0100_0000(bin)) 
                          // ���ڶ�ϵͳʱ��������м���, �Բ��� 10Hz ���ʱ���ź�
	always @(posedge clk)
	begin
		if ( rst ) begin
			counter <= 0;
			clk_10Hz <= 0;
		end
		else begin
			 // -- �� clock �źŵ������ش���
			if ( counter < PULSESCOUNT )
			counter <= counter + 1'b1;
			else begin
				clk_10Hz <= ~clk_10Hz;
				counter <= RESETZERO;
			end
		end					
	end
endmodule