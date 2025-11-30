`timescale 1ns / 1ps

module uart_rx #(
    parameter CLK_FREQ_HZ = 100_000_000,
    parameter BAUD_RATE   = 9600
)(
    input  wire clk,
    input  wire rst,
    input  wire gps_rx,
    output reg  [7:0] data_out,
    output reg        data_valid
);

    localparam integer BAUD_TICK      = CLK_FREQ_HZ / BAUD_RATE; //used this to be absolutely sure that baud rate wasn't an issue
    localparam integer BAUD_TICK_HALF = BAUD_TICK / 2;

    localparam IDLE  = 0,
               START = 1,
               DATA  = 2,
               STOP  = 3;

    reg [1:0] state = IDLE;

    reg [13:0] baud_cnt = 0;
    reg [2:0]  bit_idx  = 0;
    reg [7:0]  shiftreg = 0;

    
    reg [2:0] sync; //3 stage synchronizer used to reduce any noise
    always @(posedge clk) sync <= {sync[1:0], gps_rx};
    wire rx = sync[2];

    always @(posedge clk) begin
        if (rst) begin
            state     <= IDLE;
            data_valid<= 0;
            baud_cnt  <= 0;
            bit_idx   <= 0;
        end else begin
            data_valid <= 0;

            case (state) //state machine

            IDLE:
                if (rx == 0) begin
                    // Start bit detected
                    state    <= START;
                    baud_cnt <= 0;
                end

            START:
                if (baud_cnt == BAUD_TICK_HALF) begin
                    state    <= DATA; //sample in middle of start bit 
                    baud_cnt <= 0;
                    bit_idx  <= 0;
                end else begin
                    baud_cnt <= baud_cnt + 1;
                end

            DATA:
                if (baud_cnt == BAUD_TICK-1) begin
                    shiftreg <= {rx, shiftreg[7:1]}; //recieve 8 bits
                    baud_cnt <= 0;

                    if (bit_idx == 7)
                        state <= STOP;
                    else
                        bit_idx <= bit_idx + 1;

                end else
                    baud_cnt <= baud_cnt + 1;

            STOP:
                if (baud_cnt == BAUD_TICK-1) begin //sample stop bit and output byte
                    data_out   <= shiftreg;
                    data_valid <= 1;
                    state      <= IDLE;
                    baud_cnt   <= 0;
                end else
                    baud_cnt <= baud_cnt + 1;

            endcase
        end
    end

endmodule
