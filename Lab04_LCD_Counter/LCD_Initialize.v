`timescale 1ns / 1ns
module LCD_Initialize( 
output [3:0] SF_D,		// Four-bit SF_D interface, Data bit DB7 ~ DB4, 
// Shared with StrataFlash pins SF_D<11:8>
			output LCD_E,			// Read/Write Enable Pulse,
								// 0: Disabled, 1: Read/Write operation enabled
			output [3:0] state,			// 初始化状态 											
			input init_exec,			// 控制初始化标志, 1: 启动初始化过程, 0: 停止初始化过程
			input clock,				// 连接 On-Board 50 MHz Oscillator CLK_50MHz (C9)
			input reset				// 使用按键开关 BTN_EAST(H13) 做为复位键
			);
	// 定义 LCD 初始化状态变量
	parameter 	INIT_IDLE	= 4'h1,
	WAITING_READY 	= 4'h2,
	WR_ENABLE_1		= 4'h3,
	WAITING_1		= 4'h4,
	WR_ENABLE_2		= 4'h5,
	WAITING_2		= 4'h6,
	WR_ENABLE_3		= 4'h7,
	WAITING_3		= 4'h8,
	WR_ENABLE_4		= 4'h9,
	WAITING_4		= 4'hA,
	INIT_DONE		= 4'hB;
						
	// 保存 LCD 初始化状态变量: 位宽 3 bits
	reg [3:0] init_state;
	// 时序控制计数器
	// The 15 ms interval is 750,000 clock cycles at 50 MHz.
	// 750,000 (dec) = 1011_0111_0001_1011_0000(bin) 需要 20 bits
	reg [19:0] cnt_init;
	// The upper nibble is transferred first, followed by the lower nibble.
	reg [3:0] DB_init; 	// 用于初始化
	
	// Read/Write Enable Pulse, 0: Disabled, 1: Read/Write operation enabled
	reg en_init;        // 用于初始化
	assign SF_D 	= DB_init;	
	assign LCD_E 	= en_init;
////////////////////////////////////////////////////////////////////////
	// Initializing the Display
	always @( posedge clock )
	begin
		if( reset ) begin
				init_state <= INIT_IDLE;
				DB_init <= 4'b0;
				en_init <= 0;
				cnt_init <= 0;
			end
		else begin
			case ( init_state )
				// power on initialization sequence
				INIT_IDLE:	begin
					DB_init <= 4'b0;
					en_init <= 0;
					cnt_init <= 0;
					if ( init_exec  )
						init_state <= WAITING_READY;
					else
						init_state <= INIT_IDLE;
				end
				
				WAITING_READY:begin	// 等待 15 ms 或更长, LCD 准备显示
					en_init <= 0;
					if ( cnt_init <= 750000 ) begin
							DB_init <= 4'h0;
							cnt_init <= cnt_init + 1;
							init_state <= WAITING_READY;
						end
					else begin
							cnt_init <= 0;
							init_state <= WR_ENABLE_1;
						end
			end
				WR_ENABLE_1:begin
					DB_init <= 4'h3;	// Write SF_D<11:8> = 0x3
					en_init <= 1'b1;	// Pulse LCD_E High for 12 clock cycles.
					if ( cnt_init < 12 ) begin	 
							cnt_init <= cnt_init + 1;
							init_state <= WR_ENABLE_1;
						end
					else begin
							cnt_init <= 0;
							init_state <= WAITING_1;
						end
				end
				WAITING_1:	begin	// Wait 4.1 ms or longer, which is 205,000 clock cycles at 50 MHz.
					en_init <= 1'b0;			
					if ( cnt_init <= 205000 ) begin	 
							cnt_init <= cnt_init + 1;
							init_state <= WAITING_1;
						end
					else begin
							cnt_init <= 0;
							init_state <= WR_ENABLE_2;
						end
				end
				WR_ENABLE_2:begin
					DB_init <= 4'h3;			// Write SF_D<11:8> = 0x3
					en_init <= 1'b1;			// Pulse LCD_E High for 12 clock cycles.
					if ( cnt_init < 12 ) begin	 
						cnt_init <= cnt_init + 1;
						init_state <= WR_ENABLE_2;
						end
					else begin
							cnt_init <= 0;
							init_state <= WAITING_2;
						end
				end
				// Wait 100 μs or longer, which is 5,000 clock cycles at 50 MHz.
				WAITING_2:begin
					en_init <= 1'b0;
					if ( cnt_init <= 5000 ) begin	 
							cnt_init <= cnt_init + 1;
							init_state <= WAITING_2;
						end
						else begin
							cnt_init <= 0;
							init_state <= WR_ENABLE_3;
						end
				end
				WR_ENABLE_3:begin	//  Write SF_D<11:8> = 0x3, pulse LCD_E High for 12 clock cycles.
					DB_init <= 4'h3;			// Write SF_D<11:8> = 0x3
					en_init <= 1'b1;			// Pulse LCD_E High for 12 clock cycles.
					if ( cnt_init < 12 ) begin	 
																												cnt_init <= cnt_init + 1;
						init_state <= WR_ENABLE_3;
					end
					else begin
						cnt_init <= 0;
						init_state <= WAITING_3;
						end
				end
				WAITING_3:	begin	//  Wait 40 us or longer, which is 2,000 clock cycles at 50 MHz.
					en_init <= 1'b0;	
					if ( cnt_init <= 2000 ) begin	 
						cnt_init <= cnt_init + 1;
						init_state <= WAITING_3;
					end
					else begin
						cnt_init <= 0;
						init_state <= WR_ENABLE_4;
					end
				end
				WR_ENABLE_4:begin	//  Write SF_D<11:8> = 0x2, pulse LCD_E High for 12 clock cycles.
					DB_init <= 4'h2;			// Write SF_D<11:8> = 0x3
					en_init <= 1'b1;			// Pulse LCD_E High for 12 clock cycles.
					if ( cnt_init < 12 ) begin	 
						cnt_init <= cnt_init + 1;
						init_state <= WR_ENABLE_4;
					end
					else begin
						cnt_init <= 0;
						init_state <= WAITING_4;
					end
				end
				WAITING_4:	begin	//  Wait 40 us or longer, which is 2,000 clock cycles at 50 MHz.
					en_init <= 1'b0;										
					if ( cnt_init <= 2000 ) begin
						cnt_init <= cnt_init + 1;
						init_state <= WAITING_4;
					end
					else begin
						DB_init <= 4'h0;		// Write SF_D<11:8> = 0x0
						en_init <= 0;
						cnt_init <= 0;
						init_state <= INIT_DONE;
					end
				end
				INIT_DONE:	begin
				// // Wait 100 μs or longer, which is 5,000 clock cycles at 50 MHz.
					if ( cnt_init < 5000 )	begin
						cnt_init <= cnt_init + 1;
						init_state <= INIT_DONE;
					end
					else begin
						cnt_init <= 0;
						init_state <= INIT_IDLE;
					end
				end
				default:begin
					init_state <= INIT_IDLE;
					DB_init <= 4'b0;
					en_init <= 0;
					cnt_init <= 0;
				end
			endcase
		end
	end
	assign state = init_state;
endmodule