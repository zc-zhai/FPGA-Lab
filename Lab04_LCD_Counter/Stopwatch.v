`timescale 1ns / 1ns
`include "LCD_Initialize.v"
`include "LCD_Display.v"
`include "clock_10Hz.v"
`include "Display_decoder.v"

module Stopwatch ( output SF_CE0,			// 4 λ LCD �����ź��� StrataFlash �洢������������ SF_D<11:8>. 
									// �� SF_CE0 = High ʱ, ���� StrataFlash �洢��, 
									// ��ʱ FPGA ��ȫ read/write ���� LCD.
			  output LCD_RW,		     // Read/Write Control
									// 0: WRITE, LCD accepts SF_D
									// 1: READ, LCD presents SF_D
			  output LCD_RS,			// Register Select
									// 0: Instruction register during write operations. 
									// Busy Flash during read operations
									// 1: Data for read or write operations
			  output [3:0] SF_D,		     // Four-bit SF_D interface, Data bit DB7 ~ DB4, 
									// Shared with StrataFlash pins SF_D<11:8>
			  output LCD_E,			     // Read/Write Enable Pulse,
									// 0: Disabled, 1: Read/Write operation enabled				
			  input clock,				// ���� On-Board 50 MHz Oscillator CLK_50MHz (C9)
			  input reset,				// ʹ�ð�����?BTN_EAST(H13) ��Ϊ��λ��
			  input restart				// ʹ�û��˿��� SW3(N17) ��Ϊ�������λ��					
				  );
	///////////////////////////////////////////////////////////////////////////
	// ���� LCD ���ú��ַ���ʾ��״̬����״̬����
	// ���� LCD ���ú��ַ���ʾ��״̬����״̬����
	parameter		DISPLAY_INIT	= 4'h1,
				FUNCTION_SET	= 4'h2,
				ENTRY_MODE_SET	= 4'h3,
				DISPLAY_ON_OFF	= 4'h4,
				DISPLAY_CLEAR	= 4'h5,
				CLEAR_EXECUTION	= 4'h6,
				IDLE_WAIT 		= 4'h7,

				SET_DD_RAM_ADDR	= 4'h8,
				LCD_LINE_1		= 4'h9,
				SET_NEWLINE		= 4'hA,
				LCD_LINE_2		= 4'hB;
				
				
	// ��λ��, �ȴ� 2 sec, ������ 50 MHz ʱ��Ƶ��
	// �ȴ� 100,000,000(dec) = 101_1111_0101_1110_0001_0000_0000 (bin) (27 bits) ʱ������
	reg [26:0] cnt_2sec;
	// ���� LCD ���ú��ַ���ʾ��״̬��: λ�� 4 bits
	reg [3:0] ctrl_state;
	// ��״̬��ʱ����Ƽ�����
	// Clear the display and return the cursor to the home position, the top-left corner.
	// Execution Time at least 1.64 ms (82,000 clock cycles)
	// 82,000 (dec) = 1_0100_0000_0101_0000 (bin) ��Ҫ 17 bits
	reg [16:0] cnt_delay;	
	// 1: ������ʼ������
	// 0: ֹͣ��ʼ��
     wire init_exec;
	// ��ʼ��״̬��־
	// 4'hB 	: ��ʼ�������
	// elsewise : ��ʼ��δ���
	wire [3:0] init_state;
	// ������Ʊ�־
	// 1: �����������
	// 0: ֹͣ�������
	reg tx_exec;
	// ����/���ݴ�����ʱ
	wire [10:0] tx_delay;
	// Register Select
	// 0: Instruction register during write operations. Busy Flash during read operations
	// 1: Data for read or write operations
	reg select;
	
	// The upper nibble is transferred first, followed by the lower nibble.
	wire [3:0] nibble; 
	wire [3:0] DB_init; 	// ���ڳ�ʼ��
	// Read/Write Enable Pulse, 0: Disabled, 1: Read/Write operation enabled
	wire enable;
	wire en_init;       	// ���ڳ�ʼ��
	reg mux;			// ��־���ݽӿ����ڳ�ʼ��, ����,���ڴ������������
						// 0: ��ʼ������ռ�����ݽӿ�
						// 1: ����/����ռ�����ݽӿ�
	// �� LCD �����������? λ�� 8 bits
	reg [7:0] tx_byte;
	// ����� 1 ����ʾ������ַ�����
	reg [7:0] tx_Line1;
	// ����� 2 ����ʾ������ַ�����
	reg [7:0] tx_Line2;
	// ��ʾ�ַ�������
	reg [3:0] cnt_1 = 4'b0;	// For Line 1
	reg [3:0] cnt_2 = 4'b0;	// For Line 2
	// ���� 1Hz ʱ��ź?	wire clk_10Hz;
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// ��������� always �������������״̬���ڸ���״̬ʱ���������/����
	
	// �� LCD ����������ֽ�: λ�� 8 bits
	always @( * ) begin
		case ( ctrl_state )
			DISPLAY_INIT,
			///////////////////////////////////////////////////
			FUNCTION_SET,
			ENTRY_MODE_SET,
			DISPLAY_ON_OFF,
			DISPLAY_CLEAR,
			SET_DD_RAM_ADDR,
			SET_NEWLINE:		select = 1'b0;	// ��������
			///////////////////////////////////////////////////
			LCD_LINE_1,
			LCD_LINE_2:			select = 1'b1;	// ��������
			default: 			select = 1'b0;
 		endcase
	end
	// �� LCD ����������ֽ�: λ�� 8 bits
	always @( * ) begin
		case ( ctrl_state )
			FUNCTION_SET:		tx_byte = 8'b0010_1000;
			ENTRY_MODE_SET:		tx_byte = 8'b0000_0110;
			DISPLAY_ON_OFF:		tx_byte = 8'b0000_1100;
			DISPLAY_CLEAR:		tx_byte = 8'b0000_0001;
			SET_DD_RAM_ADDR:	tx_byte = 8'b1000_0000;
			SET_NEWLINE:		tx_byte = 8'b1100_0000; 
			///////////////////////////////////////////////////
			LCD_LINE_1:			tx_byte = tx_Line1;
			LCD_LINE_2:			tx_byte = tx_Line2;
			/////////////////////////////////////////////////// 
			default: 			tx_byte = 8'b0;
		endcase
	end
	
	always @(*)
	begin
		case ( cnt_1 )
			0:		tx_Line1 	= 8'b0101_0011;		// CHAR_S
			1:		tx_Line1	= 8'b0111_0100;		// CHAR_t_1
			2:		tx_Line1 	= 8'b0110_1111;		// CHAR_o
			3:		tx_Line1	= 8'b0111_0000;		// CHAR_p
			4:		tx_Line1	= 8'b0111_0111;		// CHAR_w
			5:		tx_Line1	= 8'b0110_0001;		// CHAR_a
			6:		tx_Line1	= 8'b0111_0100;		// CHAR_t_2
			7:		tx_Line1	= 8'b0110_0011;		// CHAR_c_1
			8:		tx_Line1	= 8'b0110_1000;		// CHAR_h
			default:tx_Line1 	= 8'b0;				// NONE
		endcase
	end
	//һ����5��digitλ
	wire [7:0] buf_digit4;
	wire [7:0] buf_digit3;
	wire [7:0] buf_digit2;
	wire [7:0] buf_digit1;
	wire [7:0] buf_digit0;
	
	always @(*)
	begin
		case ( cnt_2 )
			0:		tx_Line2	= 8'h54;			// CHAR_T
			1: 		tx_Line2	= 8'h69;			// CHAR_i
			2:		tx_Line2	= 8'h6d;			// CHAR_m
			3:    tx_Line2	= 8'h65;			// CHAR_e
			4:		tx_Line2 	= 8'h3A;				// CHAR_:
			5:		tx_Line2 	= buf_digit4;			// Digit 4
			6:		tx_Line2 	= buf_digit3;			// Digit 3
			7:		tx_Line2 	= 8'h3A;				// CHAR_:
			8:		tx_Line2 	= buf_digit2;			// Digit 2
			9:		tx_Line2 	= buf_digit1;			// Digit 1
			10:		tx_Line2 	= 8'h3A;				// CHAR_:
			11:		tx_Line2 	= buf_digit0;			// Digit 0
			default:tx_Line2 	= 8'b0;					// NONE
		endcase
	end
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	// ��ʼ��������/���ݱ�־ʹ�� 4 λ���ݽӿڿ��Ʊ�־	
	always @(*)
	begin
		case ( ctrl_state )
			DISPLAY_INIT:		mux = 1'b0;	// power on initialization sequence
			///////////////////
			FUNCTION_SET,
			ENTRY_MODE_SET,
			DISPLAY_ON_OFF,
			DISPLAY_CLEAR,
			CLEAR_EXECUTION,
			IDLE_WAIT,
			SET_DD_RAM_ADDR,
			LCD_LINE_1,
			SET_NEWLINE,
			LCD_LINE_2:			mux = 1'b1;
			default:			mux = 1'b0;
		endcase
	end
	
	///////////////////////////////////////////////////////////////////////////////////////////		
	// ���� Intel strataflash �洢��, �� Read/Write ��������Ϊ Write, ��: LCD ��������
	assign SF_CE0 	= 1'b1; 	// Disable intel strataflash
	assign LCD_RW 	= 1'b0;		// Write only
	assign LCD_RS 	= select;
	assign SF_D 	= ( mux ) ? nibble : DB_init;	
	assign LCD_E 	= ( mux ) ? enable : en_init;
	///////////////////////////////////////////////////////////////////////////////////////////	
	// ��ʼ������/ֹͣ���Ʊ�־
	assign init_exec = ( ctrl_state == DISPLAY_INIT ) ? 1'b1 : 1'b0;
	
	// ����/���ݴ�������, ֹͣ���Ʊ�־
	always @( * )
	begin
		case ( ctrl_state )
			DISPLAY_INIT:		tx_exec = 1'b0;
			FUNCTION_SET,
			ENTRY_MODE_SET,
			DISPLAY_ON_OFF,
			DISPLAY_CLEAR:		tx_exec = 1'b1;
			IDLE_WAIT,
			CLEAR_EXECUTION:	tx_exec = 1'b0;
			SET_DD_RAM_ADDR,
			LCD_LINE_1,
			SET_NEWLINE,
			LCD_LINE_2:			tx_exec = 1'b1;
			default:			tx_exec = 1'b0;
		endcase
	end		
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	LCD_Initialize m_init_proc( .SF_D(DB_init),			// Four-bit SF_D interface, Data bit DB7 ~ DB4, 
											// Shared with StrataFlash pins SF_D<11:8>
				   		.LCD_E(en_init),		     // Read/Write Enable Pulse,
										     // 0: Disabled, 1: Read/Write operation enabled
						.state(init_state),		     // ��ʼ��״̬
						.init_exec(init_exec),       // ���Ƴ�ʼ����־, 1: ������ʼ������, 0: ֹͣ��ʼ������
				   		.clock(clock),			// ���� On-Board 50 MHz Oscillator CLK_50MHz (C9)
				   		.reset(reset)				// ʹ�ð������� BTN_EAST(H13) ��Ϊ��λ��
				     		 );
				     
	LCD_Display	m_display(  .SF_D(nibble), 
							.LCD_E(enable),
							.delay(tx_delay),
							//////////////////////
							.tx_exec(tx_exec),
							.tx_byte(tx_byte),
							.clock(clock),
							.reset(reset)
   				  		 );
   	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////			  		 
	// Main state machine
	always @( posedge clock )
	begin
		if( reset ) begin
			ctrl_state <= DISPLAY_INIT;
			cnt_delay <= 0;
			cnt_1 <= 0;
			cnt_2 <= 0;
			cnt_2sec <= 0;
		end
		else begin
			case ( ctrl_state )
				// power on initialization sequence
				DISPLAY_INIT:		begin	// �ȴ� 15 ms �����, LCD ׼����ʾ
										if ( init_state == 4'hB ) begin
											ctrl_state <= FUNCTION_SET;
											cnt_1 <= 0;
											cnt_2 <= 0;
										end
										else begin
											ctrl_state <= DISPLAY_INIT;
										end
									end

				FUNCTION_SET:		begin
										// Wait 40 us or longer
										if ( tx_delay <= 2000 ) begin
											ctrl_state <= FUNCTION_SET;
										end
										else begin
											ctrl_state <= ENTRY_MODE_SET;
										end		
									end
				
				ENTRY_MODE_SET:		begin
										// Wait 40 us or longer
										if ( tx_delay <= 2000 ) begin
											ctrl_state <= ENTRY_MODE_SET;
										end
										else begin
											ctrl_state <= DISPLAY_ON_OFF;
										end
									end
				
				DISPLAY_ON_OFF:		begin
										// Wait 40 us or longer
										if ( tx_delay <= 2000 ) begin
											ctrl_state <= DISPLAY_ON_OFF;
										end
										else begin
											ctrl_state <= DISPLAY_CLEAR;
										end
									end
									
				DISPLAY_CLEAR:		begin 
										// Wait 40 us or longer
										if ( tx_delay <= 2000 ) begin
											ctrl_state <= DISPLAY_CLEAR;
										end
										else begin
											ctrl_state <= CLEAR_EXECUTION;
											cnt_delay <= 0;
										end
									end
				
				CLEAR_EXECUTION:	begin
										// The delay after a Clear Display command is 1.64ms, 
										// which corresponds to 82000 clock cycles. 
										if ( cnt_delay <= 82000 ) begin
											ctrl_state <= CLEAR_EXECUTION;
											cnt_delay <= cnt_delay + 1;
										end
										else begin
											ctrl_state <= IDLE_WAIT;
											cnt_delay <= 0;
											cnt_2sec <= 0;
										end
									end
				
				IDLE_WAIT:			begin // ������, �ȴ� 400 ms, �۲츴λ
										if ( cnt_2sec < 2000000 ) begin  
											ctrl_state <= IDLE_WAIT;
											cnt_2sec <= cnt_2sec + 1;
										end
										else begin
											ctrl_state <= SET_DD_RAM_ADDR;
											cnt_delay <= 0;
										end										
									end

				SET_DD_RAM_ADDR:	begin   
										// Wait 40 us or longer
										if ( tx_delay <= 2000 ) begin
											ctrl_state <= SET_DD_RAM_ADDR;
										end
										else begin
											ctrl_state <= LCD_LINE_1;
											cnt_1 <= 0;
										end
									end

				LCD_LINE_1:			begin
										// Wait 40 us or longer
										if ( tx_delay <= 2000 ) begin
											ctrl_state <= LCD_LINE_1;
										end
										else if ( cnt_1 < 8 ) // Line 1 �� 9 �ַ� 
											begin
												ctrl_state <= LCD_LINE_1;
												
												cnt_1 <= cnt_1 + 1;
											end
											else begin	
												ctrl_state <= SET_NEWLINE;

												cnt_1 <= 0;
											end
									end
													
				SET_NEWLINE:		begin
										// Wait 40 us or longer
										if ( tx_delay <= 2000 ) begin
											ctrl_state <= SET_NEWLINE;
										end
										else begin
											ctrl_state <= LCD_LINE_2;
											cnt_2 <= 0;
										end
									end	
									
				LCD_LINE_2:			begin
										// Wait 40 us or longer
										if ( tx_delay <= 2000 ) begin
											ctrl_state <= LCD_LINE_2;
										end
										else if ( cnt_2 < 11 ) begin		// Line 2 �� 12 �ַ�
												ctrl_state <= LCD_LINE_2;
												cnt_2 <= cnt_2 + 1;
											end
											else begin	
												ctrl_state <= SET_NEWLINE;
												cnt_2 <= 0;
											end
									end
				
				default:			begin
										ctrl_state <= DISPLAY_INIT;
										cnt_delay <= 0;
										cnt_1 <= 0;
										cnt_2 <= 0;
										cnt_2sec <= 0;
									end
			endcase
		end
	end

	// ���� 10 Hz ʱ���ź�
	clock_10Hz m_clk10Hz( .clk_10Hz(clk_10Hz),	// 10Hz ʱ������ź�
						.clk(clock),	    // ϵͳʱ�������ź�
						.rst(reset)			// ��λ�����ź�
					   );
    reg [3:0] buf_num4;				// -- �� 5 �� LCD ��ʾ���ݻ�����
	reg [3:0] buf_num3;			    // -- �� 4 �� LCD ��ʾ���ݻ�����
	reg [3:0] buf_num2;			    // -- �� 3 �� LCD ��ʾ���ݻ�����
	reg [3:0] buf_num1;			    // -- �� 2 �� LCD ��ʾ���ݻ�����
	reg [3:0] buf_num0;			    // -- �� 1 �� LCD ��ʾ���ݻ�����

	parameter	CARRYOUT = 4'b1001;

	always @(posedge clk_10Hz)
	if ( restart ) begin
	   buf_num4 <= 0;
		buf_num3 <= 0;
		buf_num2 <= 0;
		buf_num1 <= 0;
		buf_num0 <= 0;
	end
	else  begin
		buf_num0 <= buf_num0 + 1'b1;
		if ( buf_num0 == CARRYOUT )
		begin
			buf_num0 <= 4'b0000;
			buf_num1 <= buf_num1 + 1'b1;
			if ( buf_num1 == CARRYOUT )
			begin
				buf_num1 <= 4'b0000;
				buf_num2 <= buf_num2 + 1'b1;
				if ( buf_num2 == 4'b0101)
				begin
					buf_num2 <= 4'b0000;
					buf_num3 <= buf_num3 + 1'b1;
					if ( buf_num3 == CARRYOUT ) 
					begin
						buf_num3 <= 4'b0000;
						buf_num4 <= buf_num4 + 1;
						if (buf_num4 == 4'b0110)
						   buf_num4 <= 4'b0000;
					end
				end
			end
		end
	end
	
	Display_decoder m_decoder0( .DigitalCG(buf_digit0), .number(buf_num0) ),
					m_decoder1( .DigitalCG(buf_digit1), .number(buf_num1) ),
					m_decoder2( .DigitalCG(buf_digit2), .number(buf_num2) ),
					m_decoder3( .DigitalCG(buf_digit3), .number(buf_num3) ),
					m_decoder4( .DigitalCG(buf_digit4), .number(buf_num4) );

endmodule