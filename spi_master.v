`timescale 1ns / 1ps

module spi_master_byte #(
    // 1 MHz SCLK
    parameter CLKS_PER_HALF_BIT = 50 
)(
    input wire clk,
    input wire reset,
    input wire start, 
    input wire [7:0] tx_byte,
    output reg busy,
    output reg done,    
    output reg [7:0] rx_byte,

    // SPI pins
    output reg sclk,
    output reg mosi,
    input wire miso
);

    localparam STATE_IDLE = 2'd0;
    localparam STATE_TRANSFER= 2'd1;
    localparam STATE_DONE = 2'd2;

    reg [1:0] state;

    reg [7:0] tx_shift;
    reg [7:0] rx_shift;
    reg [2:0] bit_index; 
    reg [7:0] clk_count;     

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= STATE_IDLE;
            sclk <= 1'b0;
            mosi <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            rx_byte <= 8'h00;
            tx_shift <= 8'h00;
            rx_shift <= 8'h00;
            bit_index <= 3'd0;
            clk_count <= 8'd0;
        end else begin
            done <= 1'b0; 

            case (state)
            STATE_IDLE: begin
                sclk <= 1'b0; // sclk idle low
                busy <= 1'b0;
                if (start) begin
                    busy <= 1'b1;
                    tx_shift <= tx_byte;
                    rx_shift <= 8'h00;
                    bit_index <= 3'd7; // MSB comes first
                    clk_count <= 8'd0;
                    mosi <= tx_byte[7]; // first bit on MOSI
                    state <= STATE_TRANSFER;
                end
            end

            STATE_TRANSFER: begin
                busy <= 1'b1;

                if (clk_count == CLKS_PER_HALF_BIT - 1) begin
                    clk_count <= 8'd0;
                    sclk <= ~sclk; 

                    if (sclk == 1'b0) begin
                        // 0 -> 1 (rising edge), sample MISO
                        rx_shift <= {rx_shift[6:0], miso};
                    end else begin
                        // 1 -> 0 (falling edge)
                        if (bit_index == 0) begin
                            // last bit just shifted, next state will finish
                            state <= STATE_DONE;
                        end else begin
                            bit_index <= bit_index - 1'b1;
                            tx_shift <= {tx_shift[6:0], 1'b0};
                            mosi <= tx_shift[6]; // next bit
                        end
                    end
                end else begin
                    clk_count <= clk_count + 1'b1;
                end
            end

            STATE_DONE: begin
                sclk <= 1'b0;
                busy <= 1'b0;
                done <= 1'b1;
                rx_byte <= rx_shift;
                state <= STATE_IDLE;
            end

            default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule

