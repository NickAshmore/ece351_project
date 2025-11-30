`timescale 1ns / 1ps

module adxl362_simple #(
    parameter CLK_FREQ_HZ = 100_000_000,
    parameter SPI_HALF_PERIOD_CLKS = 50  // 1 MHz SCLK from 100 MHz
)(
    input wire clk,
    input wire reset,
    // SPI wires
    output reg spi_cs_n,
    output wire spi_sclk,
    output wire spi_mosi,
    input wire spi_miso,
    // Z-axis reading
    output reg signed [15:0] z_data,
    output reg z_valid
);

    reg spi_start;
    reg [7:0] spi_tx;
    wire spi_busy;
    wire spi_done;
    wire [7:0] spi_rx;

    spi_master_byte #(
        .CLKS_PER_HALF_BIT(SPI_HALF_PERIOD_CLKS)
    ) u_spi (
        .clk (clk),
        .reset (reset),
        .start (spi_start),
        .tx_byte(spi_tx),
        .busy (spi_busy),
        .done (spi_done),
        .rx_byte(spi_rx),
        .sclk (spi_sclk),
        .mosi (spi_mosi),
        .miso (spi_miso)
    );

    // ADXL362 SPI commands / registers
    localparam [7:0] CMD_WRITE = 8'h0A;
    localparam [7:0] CMD_READ = 8'h0B;
    localparam [7:0] REG_POWERCTL = 8'h2D;
    localparam [7:0] REG_ZDATA_L = 8'h12;

    // Simple FSM
    localparam ST_RESET_WAIT = 4'd0;
    localparam ST_WR_CMD = 4'd1;
    localparam ST_WR_ADDR = 4'd2;
    localparam ST_WR_DATA = 4'd3;
    localparam ST_WR_DONE = 4'd4;
    localparam ST_IDLE_BEFORE_READ = 4'd5;
    localparam ST_RD_CMD = 4'd6;
    localparam ST_RD_ADDR = 4'd7;
    localparam ST_RD_DUMMY1 = 4'd8;
    localparam ST_RD_DUMMY2 = 4'd9;
    localparam ST_RD_DONE = 4'd10;

    reg [3:0] state;
    reg [31:0] reset_counter;
    reg [15:0] z_raw;
    reg [31:0] read_delay_cnt;

    // Helper: a small startup delay (e.g. 10 ms at 100MHz = 1,000,000 cycles)
    localparam integer RESET_WAIT_CLKS = 1_000_000;
    // Delay between reads so we don't hammer the bus: ~1ms
    localparam integer READ_DELAY_CLKS = 100_000;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= ST_RESET_WAIT;
            reset_counter <= 32'd0;
            spi_cs_n <= 1'b1;
            spi_start <= 1'b0;
            spi_tx <= 8'h00;
            z_raw <= 16'd0;
            z_data <= 16'sd0;
            z_valid <= 1'b0;
            read_delay_cnt<= 32'd0;
        end else begin
            // defaults
            spi_start <= 1'b0;
            z_valid <= 1'b0;

            case (state)
            // initial wait after power-up
            ST_RESET_WAIT: begin
                spi_cs_n <= 1'b1;
                if (reset_counter < RESET_WAIT_CLKS)
                    reset_counter <= reset_counter + 1'b1;
                else begin
                    // start write: POWER_CTL = 0x02 (measurement mode)
                    spi_cs_n <= 1'b0; 
                    state <= ST_WR_CMD;
                end
            end

            // Write sequence: CMD_WRITE 
            ST_WR_CMD: begin
                if (!spi_busy && !spi_done) begin
                    spi_tx <= CMD_WRITE;
                    spi_start <= 1'b1; 
                end else if (spi_done) begin
                    state <= ST_WR_ADDR;
                end
            end

            // Write sequence: address POWER_CTL
            ST_WR_ADDR: begin
                if (!spi_busy && !spi_done) begin
                    spi_tx <= REG_POWERCTL;
                    spi_start <= 1'b1;
                end else if (spi_done) begin
                    state <= ST_WR_DATA;
                end
            end

            // Write sequence: data 0x02 
            ST_WR_DATA: begin
                if (!spi_busy && !spi_done) begin
                    spi_tx <= 8'h02;  // measurement mode
                    spi_start <= 1'b1;
                end else if (spi_done) begin
                    state <= ST_WR_DONE;
                end
            end

            ST_WR_DONE: begin
                spi_cs_n <= 1'b1;
                read_delay_cnt <= 32'd0;
                state <= ST_IDLE_BEFORE_READ;
            end

            // Wait some time, then start read loop 
            ST_IDLE_BEFORE_READ: begin
                if (read_delay_cnt < READ_DELAY_CLKS)
                    read_delay_cnt <= read_delay_cnt + 1'b1;
                else begin
                    read_delay_cnt <= 32'd0;
                    spi_cs_n <= 1'b0;   // start read
                    state <= ST_RD_CMD;
                end
            end

            // Read sequence: CMD_READ 
            ST_RD_CMD: begin
                if (!spi_busy && !spi_done) begin
                    spi_tx <= CMD_READ;
                    spi_start <= 1'b1;
                end else if (spi_done) begin
                    state <= ST_RD_ADDR;
                end
            end

            // Read sequence: starting at ZDATA_L 
            ST_RD_ADDR: begin
                if (!spi_busy && !spi_done) begin
                    spi_tx <= REG_ZDATA_L;
                    spi_start <= 1'b1;
                end else if (spi_done) begin
                    state <= ST_RD_DUMMY1;
                end
            end

            // Read ZDATA_L (dummy write, capture rx)
            ST_RD_DUMMY1: begin
                if (!spi_busy && !spi_done) begin
                    spi_tx <= 8'h00;  // dummy
                    spi_start <= 1'b1;
                end else if (spi_done) begin
                    z_raw[7:0] <= spi_rx; // Z_L
                    state <= ST_RD_DUMMY2;
                end
            end

            // Read ZDATA_H (dummy write, capture rx)
            ST_RD_DUMMY2: begin
                if (!spi_busy && !spi_done) begin
                    spi_tx <= 8'h00;     // dummy
                    spi_start <= 1'b1;
                end else if (spi_done) begin
                    z_raw[15:8] <= spi_rx;  // Z_H (already sign-extended)
                    state <= ST_RD_DONE;
                end
            end

            ST_RD_DONE: begin
                // End transaction
                spi_cs_n <= 1'b1;

                // Latch into signed output and assert valid
                z_data <= z_raw;
                z_valid <= 1'b1;

                // Wait a bit, then read again
                read_delay_cnt <= 32'd0;
                state <= ST_IDLE_BEFORE_READ;
            end

            default: state <= ST_RESET_WAIT;
            endcase
        end
    end

endmodule

