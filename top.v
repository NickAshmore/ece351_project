
`timescale 1ns / 1ps

    module top (
    input wire clk, 
    input wire btnC,         
    input wire gps_rx,
    input wire [15:0] sw,
    
    // SPI pins to Pmod ACL2 
    output wire acl_sclk,
    output wire acl_mosi,
    input  wire acl_miso,
    output wire acl_cs_n,

    // 7-seg
    output wire [6:0] seg,
    output wire [3:0] an,
    output wire dp
);
    wire reset = btnC;

//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
// GPS MODE INSTANTIATIONS

//  UART RECEIVER
wire [7:0] gps_data_out;
wire       gps_data_valid;

uart_rx #(
    .CLK_FREQ_HZ(100000000),
    .BAUD_RATE(9600)
)
UART_RX (
    .clk(clk),
    .rst(reset),
    .gps_rx(gps_rx),
    .data_out(gps_data_out),
    .data_valid(gps_data_valid)
);

wire [7:0] lat0, lat1, lat2, lat3, lat4, lat5, lat6, lat7;
wire [7:0] lon0, lon1, lon2, lon3, lon4, lon5, lon6, lon7;

wire [7:0] spd0, spd1, spd2, spd3, spd4, spd5;
wire       speed_ready;

gprmc_parser PARSER (
    .clk(clk),
    .rst(reset),
    .rx_data(gps_data_out),
    .rx_valid(gps_data_valid),

    .fix_valid(),       // already handled
    .lat0(lat0), .lat1(lat1), .lat2(lat2), .lat3(lat3),
    .lat4(lat4), .lat5(lat5), .lat6(lat6), .lat7(lat7),

    .lon0(lon0), .lon1(lon1), .lon2(lon2), .lon3(lon3),
    .lon4(lon4), .lon5(lon5), .lon6(lon6), .lon7(lon7),

    .spd0(spd0), .spd1(spd1), .spd2(spd2),
    .spd3(spd3), .spd4(spd4), .spd5(spd5),

    .speed_ready(speed_ready)
);

wire [3:0] mph0, mph1, mph2, mph3;
wire [15:0] mph_x100;

knots_to_mph MPH (
    .clk(clk),
    .rst(reset),
    .speed_ready(speed_ready),

    .spd0(spd0), .spd1(spd1), .spd2(spd2),
    .spd3(spd3), .spd4(spd4), .spd5(spd5),

    .mph0(mph0), .mph1(mph1), .mph2(mph2), .mph3(mph3),
    .mph_x100_out(mph_x100)
);


reg [3:0] d0, d1, d2, d3;

always @(*) begin

    if (sw[1]) begin
        d0 = mph0; d1 = mph1; d2 = mph2; d3 = mph3; // MPH mode
    end
    else if (sw[2]) begin
        d0 = lon0; d1 = lon1; d2 = lon2; d3 = lon3; // Longitude
    end
    else if (~sw[2]) begin
        d0 = lat0; d1 = lat1; d2 = lat2; d3 = lat3; // Latitude (default)
    end

end

wire [15:0] gps_output = {d3, d2, d1, d0};
//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////

 
    wire signed [15:0] z_data;
    wire z_valid;

    adxl362_simple u_acl (
        .clk (clk),
        .reset (reset),
        .spi_cs_n (acl_cs_n),
        .spi_sclk (acl_sclk),
        .spi_mosi (acl_mosi),
        .spi_miso (acl_miso),
        .z_data (z_data),
        .z_valid (z_valid)
    );

    wire signed [15:0] z_baseline;
    wire signed [15:0] z_dynamic;
    wire [15:0] z_dynamic_abs;
    wire dyn_valid;

    accel_preprocess #(
        .BASELINE_SHIFT(6)  
    ) u_pre (
        .clk (clk),
        .reset (reset),
        .z_data (z_data),
        .z_valid (z_valid),
        .z_baseline (z_baseline),
        .z_dynamic (z_dynamic),
        .z_dynamic_abs (z_dynamic_abs),
        .dyn_valid (dyn_valid)
    );

    // Step detector
    wire step_pulse;
    wire [15:0] step_count;
    wire in_peak_dbg;
    wire [15:0] peak_len_dbg;
    wire [15:0] gap_dbg;

    step_detector #(
        .TH_HIGH (16'd250),
        .TH_LOW (16'd150),
        .MIN_PEAK_SAMPLES (8),
        .MAX_PEAK_SAMPLES (200),
        .MIN_STEP_GAP_SAMPLES (200),
        .MIN_STEP_GAP_CYCLES (1000) // CHANGED FOR SIMULATION
    ) u_step (
        .clk (clk),
        .reset (reset),
        .dyn_valid (dyn_valid),
        .z_dynamic_abs (z_dynamic_abs),
        .step_pulse (step_pulse),
        .step_count (step_count),
        .in_peak (in_peak_dbg),
        .peak_len_samples (peak_len_dbg),
        .gap_samples (gap_dbg)
    );
    
    wire [15:0] spm;
    steps_per_min spm1(.clk(clk), .rst(reset), .spm(spm), .step_count(step_count));

    // 7-seg display multiplexing 
    wire [15:0] output_to_display;
    
    /*
    If switch 15 is HIGH, mode is step_count
        If switch 1 is HIGH, mode is total step_count
        If switch 1 is LOW, mode is steps_per_minute
    If switch 15 is LOW, mode is GPS
        If switch 2 is HIGH, mode is long/lat 
        If Switch 2 is LOW, mode is speed
        If Switch 3 is HIGH, display long
        If Switch 4 is LOW, display lat
    */
    
    reg [15:0] output_to_display_r;
assign output_to_display = output_to_display_r;
    wire [15:0] step_output;
always @(*) begin
    // GPS output
    output_to_display_r = 16'd0;
    

    if (sw[15]) begin
        // STEP MODE
        if (sw[0]) begin
            output_to_display_r = step_count;   // total steps
        end else begin
            output_to_display_r = spm;          // steps per minute
        end
    end else begin
        // GPS MODE
        output_to_display_r = gps_output;       // already muxed long/lat/speed externally
    end
end

// Ensure the display value is under 5 digits
    wire [15:0] display_value = (output_to_display > 16'd9999) ? 16'd9999 : output_to_display;
    wire [3:0] thousands, hundreds, tens, ones;
    bin_to_bcd_4digits bcd_convert(
        .d0 (thousands),
        .d1 (hundreds),
        .d2 (tens),
        .d3 (ones),
        .value (display_value)
        );
        
    wire [15:0] seg_digits;
    assign seg_digits = {thousands, hundreds, tens, ones};
    // Step Driver
    wire [3:0] an_step;
    wire [6:0] seg_step;
    sevenseg_hex display_output (
        .clk   (clk),
        .reset (reset),
        .value (seg_digits),  
        .seg   (seg_step),
        .an    (an_step),
        .dp    (dp)
    );
    assign step_display = seg_digits;
    // GPS Driver
    wire [3:0] an_gps;
    wire [6:0] seg_gps;
    seven_seg_driver gps_driver(
    .clk(clk),
    .rst(reset),
    .d0(output_to_display[3:0]),
    .d1(output_to_display[7:4]),
    .d2(output_to_display[11:8]),
    .d3(output_to_display[15:12]),
    .an (an_gps),
    .seg(seg_gps)
    );
    
    assign an  = (sw[15]) ? an_step : an_gps;
    assign seg = (sw[15]) ? seg_step : seg_gps;
    


///////////////////////////

endmodule

