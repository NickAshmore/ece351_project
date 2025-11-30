`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/06/2025 10:23:26 AM
// Design Name: 
// Module Name: uart_rx
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// uart_rx.v
// Generic UART Receiver Module (9600 Baud, 8N1)
// Reads serial data from the RxD line and outputs data_out when data_valid pulses high.
/*
module uart_rx #(
    parameter CLK_FREQ_HZ   = 100000000,
    parameter BAUD_RATE     = 9600
) (
    input  clk,          // 100 MHz System Clock
    input  rst,          // Asynchronous Reset
    input  gps_rx,          // Serial Data Input (from GPS TX)
    
    output reg [7:0] data_out,    // Received 8-bit data
    output reg data_valid        // Pulse high for one clock cycle when data_out is valid
);

// --- Calculated Constants (FIXED for accuracy) ---
// Using 10417 to achieve 9600.00 Baud (100,000,000 / 10417 = 9599.11 Baud, 0.009% error)
localparam BAUD_CNT_MAX  = 10417;
// Baud Tick Half (Used for sampling data in the middle of a bit)
localparam BAUD_CNT_HALF = 10417 / 2; // 5208
localparam DATA_WIDTH    = 8;

// --- State Definitions ---
localparam [3:0] IDLE          = 4'd0;
localparam [3:0] START_DETECT  = 4'd1;
localparam [3:0] DATA_SAMPLE   = 4'd2;
localparam [3:0] STOP_CHECK    = 4'd3;

// --- Internal Registers ---
reg [3:0]  current_state, next_state;
reg [13:0] bit_counter;    // Counts clock ticks within a bit
reg [3:0]  bit_index;      // Counts data bits (0 to 7)
reg [7:0]  rx_buffer;      // Holds incoming data bits
reg        data_valid_reg; // Internal data valid signal

// --- 1. Edge Detection & Synchronization (3-Tick Filter) ---
// Used to capture the asynchronous gps_rx signal safely and detect the falling edge (Start Bit).
reg [2:0]  sync_reg;

always @(posedge clk) begin
    sync_reg[0] <= gps_rx;
    sync_reg[1] <= sync_reg[0];
    sync_reg[2] <= sync_reg[1];
    
    // data_valid_reg signal is not strictly needed but kept for potential future use.
    data_valid_reg <= 1'b0; // Default to low 
end

wire rx_sync = sync_reg[2]; // The fully synchronized gps_rx line

// --- 2. State Machine Sequential Logic ---
always @(posedge clk) begin
    if (rst) begin
        current_state <= IDLE;
        bit_counter   <= 14'd0;
        bit_index     <= 4'd0;
        rx_buffer     <= 8'h00;
        data_valid    <= 1'b0;
    end else begin
        current_state <= next_state;
        data_valid    <= 1'b0; // Default data_valid to low
        
        // Bit counter logic:
        // Only count when not in IDLE, and reset when max is reached.
        if (current_state != IDLE) begin
            if (bit_counter == BAUD_CNT_MAX - 1) begin
                bit_counter <= 14'd0;
            end else begin
                bit_counter <= bit_counter + 1'b1;
            end
        end else begin
            // Reset counter in IDLE state
            bit_counter <= 14'd0;
        end
        
        // State-specific actions:
        case (current_state)
            START_DETECT: begin
                // If we reach half the bit time, jump to sampling data
                if (bit_counter == BAUD_CNT_HALF) begin
                    bit_index <= 4'd0;
                end
            end

            DATA_SAMPLE: begin
                // Check if we reached the sample point (middle of the bit)
                if (bit_counter == BAUD_CNT_HALF) begin
                    // Shift the new bit into the MSB position of the buffer
                    // Note: rx_buffer receives LSB first (standard UART)
                    rx_buffer <= {rx_sync, rx_buffer[7:1]}; 
                    bit_index <= bit_index + 1'b1;
                end
            end
            
            STOP_CHECK: begin
                // After checking the STOP bit, set the data as valid
                if (bit_counter == BAUD_CNT_HALF) begin
                    // Check if stop bit is valid (high)
                    if (rx_sync == 1'b1) begin
                        data_out   <= {rx_buffer[0], rx_buffer[1], rx_buffer[2], rx_buffer[3], 
                                       rx_buffer[4], rx_buffer[5], rx_buffer[6], rx_buffer[7]};
                        data_valid <= 1'b1; // Pulse high for one clock cycle
                    end
                end
            end
        endcase
    end
end

// --- 3. State Machine Combinational Logic (Determines next state) ---
always @(*) begin
    next_state = current_state;
    
    case (current_state)
        IDLE: begin
            // Wait for a falling edge (START bit = '0')
            if (rx_sync == 1'b0) begin
                next_state = START_DETECT;
            end
        end

        START_DETECT: begin
            // We spent half a bit time confirming the START bit; now move to sampling data.
            if (bit_counter == BAUD_CNT_HALF) begin
                next_state = DATA_SAMPLE;
            end
        end

        DATA_SAMPLE: begin
            // Transition only happens after a full BAUD_CNT_MAX cycle, when the counter resets.
            if (bit_counter == BAUD_CNT_MAX - 1) begin
                // If we have sampled all 8 bits, move to STOP bit check.
                if (bit_index == DATA_WIDTH - 1) begin
                    next_state = STOP_CHECK;
                end
                // Otherwise, stay in DATA_SAMPLE for the next bit
            end
        end
        
        STOP_CHECK: begin
            // Transition only happens after a full BAUD_CNT_MAX cycle, when the counter resets.
            if (bit_counter == BAUD_CNT_MAX - 1) begin
                next_state = IDLE;
            end
        end
        
        default: next_state = IDLE;
    endcase
end

endmodule
*/

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

    localparam integer BAUD_TICK      = CLK_FREQ_HZ / BAUD_RATE;
    localparam integer BAUD_TICK_HALF = BAUD_TICK / 2;

    localparam IDLE  = 0,
               START = 1,
               DATA  = 2,
               STOP  = 3;

    reg [1:0] state = IDLE;

    reg [13:0] baud_cnt = 0;
    reg [2:0]  bit_idx  = 0;
    reg [7:0]  shiftreg = 0;

    // 3-stage synchronizer
    reg [2:0] sync;
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

            case (state)

            //------------------------------------------------
            IDLE:
            //------------------------------------------------
                if (rx == 0) begin
                    // Start bit detected
                    state    <= START;
                    baud_cnt <= 0;
                end

            //------------------------------------------------
            START:
            //------------------------------------------------
                if (baud_cnt == BAUD_TICK_HALF) begin
                    // Sample in middle of start bit
                    state    <= DATA;
                    baud_cnt <= 0;
                    bit_idx  <= 0;
                end else begin
                    baud_cnt <= baud_cnt + 1;
                end

            //------------------------------------------------
            DATA:
            //------------------------------------------------
                if (baud_cnt == BAUD_TICK-1) begin
                    // Sample data bit
                    shiftreg <= {rx, shiftreg[7:1]};
                    baud_cnt <= 0;

                    if (bit_idx == 7)
                        state <= STOP;
                    else
                        bit_idx <= bit_idx + 1;

                end else
                    baud_cnt <= baud_cnt + 1;

            //------------------------------------------------
            STOP:
            //------------------------------------------------
                if (baud_cnt == BAUD_TICK-1) begin
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

