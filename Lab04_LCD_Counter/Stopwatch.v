`timescale 1ns / 1ns
`include "LCD_Initialize.v"
`include "LCD_Display.v"
`include "clock_10Hz.v"
`include "Display_decoder.v"

module Stopwatch ( output SF_CE0,			// 4 位 LCD 数据信号与 StrataFlash 存储器共享数据线 SF_D<11:8>. 
									// 当 SF_CE0 = High 时, 禁用 StrataFlash 存储器, 
									// 此时 FPGA 完全 read/write 访问 LCD.
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
			  input clock,				// 连接 On-Board 50 MHz Oscillator CLK_50MHz (C9)
			  input reset,				// 使用按键开?BTN_EAST(H13) 做为复位键
			  input restart				// 使用滑杆开关 SW3(N17) 做为秒计数复位键					
				  );
	///////////////////////////////////////////////////////////////////////////
	// 定义 LCD 配置和字符显示主状态机的状态变量
	// 定义 LCD 配置和字符显示主状态机的状态变量
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
				
				
	// 复位后, 等待 2 sec, 运行在 50 MHz 时钟频率
	// 等待 100,000,000(dec) = 101_1111_0101_1110_0001_0000_0000 (bin) (27 bits) 时钟周期
	reg [26:0] cnt_2sec;
	// 保存 LCD 配置和字符显示主状态机: 位宽 4 bits
	reg [3:0] ctrl_state;
	// 主状态机时序控制计数器
	// Clear the display and return the cursor to the home position, the top-left corner.
	// Execution Time at least 1.64 ms (82,000 clock cycles)
	// 82,000 (dec) = 1_0100_0000_0101_0000 (bin) 需要 17 bits
	reg [16:0] cnt_delay;	
	// 1: 启动初始化过程
	// 0: 停止初始化
     wire init_exec;
	// 初始化状态标志
	// 4'hB 	: 初始化已完成
	// elsewise : 初始化未完成
	wire [3:0] init_state;
	// 传输控制标志
	// 1: 启动传输过程
	// 0: 停止传输过程
	reg tx_exec;
	// 命令/数据传输延时
	wire [10:0] tx_delay;
	// Register Select
	// 0: Instruction register during write operations. Busy Flash during read operations
	// 1: Data for read or write operations
	reg select;
	
	// The upper nibble is transferred first, followed by the lower nibble.
	wire [3:0] nibble; 
	wire [3:0] DB_init; 	// 用于初始化
	// Read/Write Enable Pulse, 0: Disabled, 1: Read/Write operation enabled
	wire enable;
	wire en_init;       	// 用于初始化
	reg mux;			// 标志数据接口用于初始化, 或是,用于传输命令或数据
						// 0: 初始化过程占据数据接口
						// 1: 命令/数据占据数据接口
	// 向 LCD 传输的数据字? 位宽 8 bits
	reg [7:0] tx_byte;
	// 保存第 1 行显示输出的字符数据
	reg [7:0] tx_Line1;
	// 保存第 2 行显示输出的字符数据
	reg [7:0] tx_Line2;
	// 显示字符计数器
	reg [3:0] cnt_1 = 4'b0;	// For Line 1
	reg [3:0] cnt_2 = 4'b0;	// For Line 2
	// 连接 1Hz 时有藕?	wire clk_10Hz;
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// 下面的三个 always 过程语句用于主状态机在各个状态时传输的命令/数据
	
	// 向 LCD 传输的命令字节: 位宽 8 bits
	always @( * ) begin
		case ( ctrl_state )
			DISPLAY_INIT,
			///////////////////////////////////////////////////
			FUNCTION_SET,
			ENTRY_MODE_SET,
			DISPLAY_ON_OFF,
			DISPLAY_CLEAR,
			SET_DD_RAM_ADDR,
			SET_NEWLINE:		select = 1'b0;	// 传输命令
			///////////////////////////////////////////////////
			LCD_LINE_1,
			LCD_LINE_2:			select = 1'b1;	// 传输数据
			default: 			select = 1'b0;
 		endcase
	end
	// 向 LCD 传输的命令字节: 位宽 8 bits
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
	//一共有5个digit位
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
	
	// 初始化和命令/数据标志使用 4 位数据接口控制标志	
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
	// 禁用 Intel strataflash 存储器, 将 Read/Write 控制设置为 Write, 即: LCD 接收数据
	assign SF_CE0 	= 1'b1; 	// Disable intel strataflash
	assign LCD_RW 	= 1'b0;		// Write only
	assign LCD_RS 	= select;
	assign SF_D 	= ( mux ) ? nibble : DB_init;	
	assign LCD_E 	= ( mux ) ? enable : en_init;
	///////////////////////////////////////////////////////////////////////////////////////////	
	// 初始化启动/停止控制标志
	assign init_exec = ( ctrl_state == DISPLAY_INIT ) ? 1'b1 : 1'b0;
	
	// 命令/数据传输启动, 停止控制标志
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
						.state(init_state),		     // 初始化状态
						.init_exec(init_exec),       // 控制初始化标志, 1: 启动初始化过程, 0: 停止初始化过程
				   		.clock(clock),			// 连接 On-Board 50 MHz Oscillator CLK_50MHz (C9)
				   		.reset(reset)				// 使用按键开关 BTN_EAST(H13) 做为复位键
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
				DISPLAY_INIT:		begin	// 等待 15 ms 或更长, LCD 准备显示
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
				
				IDLE_WAIT:			begin // 清屏后, 等待 400 ms, 观察复位
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
										else if ( cnt_1 < 8 ) // Line 1 有 9 字符 
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
										else if ( cnt_2 < 11 ) begin		// Line 2 有 12 字符
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

	// 产生 10 Hz 时钟信号
	clock_10Hz m_clk10Hz( .clk_10Hz(clk_10Hz),	// 10Hz 时钟输出信号
						.clk(clock),	    // 系统时钟输入信号
						.rst(reset)			// 复位输入信号
					   );
    reg [3:0] buf_num4;				// -- 第 5 个 LCD 显示数据缓冲器
	reg [3:0] buf_num3;			    // -- 第 4 个 LCD 显示数据缓冲器
	reg [3:0] buf_num2;			    // -- 第 3 个 LCD 显示数据缓冲器
	reg [3:0] buf_num1;			    // -- 第 2 个 LCD 显示数据缓冲器
	reg [3:0] buf_num0;			    // -- 第 1 个 LCD 显示数据缓冲器

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