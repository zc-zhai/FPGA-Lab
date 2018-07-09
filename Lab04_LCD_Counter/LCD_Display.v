`timescale 1ns / 1ps
module LCD_Display(     output [3:0] SF_D,
				    output LCD_E,		// Read/Write Enable Pulse,
									// 0: Disabled, 1: Read/Write operation enabled					
					output [10:0] delay,	// 输出传输延时计数器, 当 delay = 2000 时, 传输完成
					input tx_exec,		// 控制初始化标志,  1: 启动传输过程, 0: 停止传输过程
					input [7:0] tx_byte,	// 向 LCD 传输的数据字节: 位宽 8 bits
					input clock,			// 连接 On-Board 50 MHz Oscillator CLK_50MHz (C9)
				    input reset			// 使用按键开关 BTN_EAST(H13) 做为复位键
   				  );
	
	// 定义向 LCD 控制器传输命令/字符时序状态
	parameter 	TX_IDLE		= 8'H01,
				UPPER_SETUP	= 8'H02,
				UPPER_HOLD	= 8'H04,
				ONE_US		= 8'H08,
				LOWER_SETUP	= 8'H10,
				LOWER_HOLD	= 8'H20,
				FORTY_US	= 8'H40;

	// 保存传输命令/字符时序状态: 位宽 7 bits
	reg [6:0] tx_state;
	// The time between successive commands is 40us, which corresponds to 2000 clock cycles
	// 2000 (dec ) = 111_1101_0000 (bin) 需要 11 bits
	reg [10:0] cnt_tx;
	reg enable;
	// The upper nibble is transferred first, followed by the lower nibble.
	reg [3:0] nibble; 	
	assign SF_D 	= nibble;
	assign LCD_E 	= enable;	
	always @( posedge clock )
	begin
		if ( reset ) begin
			enable <= 1'b0;
			nibble <= 4'b0;

			tx_state <= TX_IDLE;
			cnt_tx <= 0;
		end
		else  begin
			case ( tx_state )
				TX_IDLE:			begin
										enable <= 1'b0;
										nibble <= 4'b0;
										cnt_tx <= 0;
										if ( tx_exec ) begin
											tx_state <= UPPER_SETUP;
										end
										else begin
											tx_state <= TX_IDLE;
										end
									end
				// Setup time ( time for the outputs to stabilize ) is 40ns, which is 2 clock cycles
				UPPER_SETUP:		begin	
										nibble <= tx_byte[7:4];
										if ( cnt_tx < 2 ) begin
											enable <= 1'b0;
											tx_state <= UPPER_SETUP;
											cnt_tx <= cnt_tx + 1;
										end
										else begin
											enable <= 1'b1;
											tx_state <= UPPER_HOLD;
											cnt_tx <= 0;
										end
									end
				// Hold time ( time to assert the LCD_E pin ) is 230ns, which translates to roughly 12 clock cycles
				UPPER_HOLD:			begin
										nibble <= tx_byte[7:4];
										if ( cnt_tx < 12 ) begin
											enable <= 1'b1;
											tx_state <= UPPER_HOLD;
											cnt_tx <= cnt_tx + 1;
										end
										else begin
											enable <= 1'b0;
											tx_state <= ONE_US;
											cnt_tx <= 0;
										end
									end
				// Each 8-bit transfer must be decomposed into two 4-bit transfers, spaced apart by at least 1 μs.
				// The upper nibble is transferred first, followed by the lower nibble. 
				// The time between corresponding nibbles is 1us, which is equivalent to 50 clock cycles.
				ONE_US:				begin
										enable <= 1'b0;
										if ( cnt_tx <= 50 ) begin
											tx_state <= ONE_US;
											cnt_tx <= cnt_tx + 1;
										end
										else begin
											tx_state <= LOWER_SETUP;
											cnt_tx <= 0;
										end
									end
				// Setup time ( time for the outputs to stabilize ) is 40ns, which is 2 clock cycles					
				LOWER_SETUP:		begin	
										nibble <= tx_byte[3:0];
										if ( cnt_tx < 2 ) begin
											enable <= 1'b0;
											tx_state <= LOWER_SETUP;
											cnt_tx <= cnt_tx + 1;
										end
										else begin
											enable <= 1'b1;
											tx_state <= LOWER_HOLD;
											cnt_tx <= 0;
										end
									end
				// Hold time ( time to assert the LCD_E pin ) is 230ns, which translates to roughly 12 clock cycles
				LOWER_HOLD:			begin
										nibble <= tx_byte[3:0];
										if ( cnt_tx < 12 ) begin
											enable <= 1'b1;
											tx_state <= LOWER_HOLD;
											cnt_tx <= cnt_tx + 1;
										end
										else begin
											enable <= 1'b0;
											tx_state <= FORTY_US;
											cnt_tx <= 0;
										end
									end
				// The time between successive commands is 40us, which corresponds to 2000 clock cycles. 
				FORTY_US:			begin
										enable <= 1'b0;
										if ( cnt_tx <= 2000 ) begin
											tx_state <= FORTY_US;
											cnt_tx <= cnt_tx + 1;
										end
										else begin
											tx_state <= TX_IDLE;
											cnt_tx <= 0;
										end
									end
				default:			begin
											enable <= 1'b0;
											nibble <= 4'b0;
											tx_state <= TX_IDLE;
											cnt_tx <= 0;
									end
			endcase
		end
	end
	assign delay = cnt_tx;
endmodule