`timescale 1ns / 1ps

// Goal of this module is to take the raw, signed z-axis acceleration value, convert it to unsigned 16 bit magnitude.
// Then, rather than tracking the magnitude, we need to track change in magnitude. If we take a moving average over the past 5 samples, 
// and subtract this moving average from the most recent reading, we will see the relative acceleration. 

    module accel_preprocess #(
        parameter integer BASELINE_SHIFT = 6 // tunable low-pass filter
    )(
        input wire clk,
        input wire reset,
        input wire signed [15:0] z_data, 
        input wire z_valid, 
    
        output reg signed [15:0] z_baseline,
        output reg signed [15:0] z_dynamic,
        output reg [15:0] z_dynamic_abs,
        output reg dyn_valid
    );
    
        always @(posedge clk or posedge reset) begin
            if (reset) begin
                z_baseline <= 16'sd0;
                z_dynamic <= 16'sd0;
                z_dynamic_abs <= 16'd0;
                dyn_valid <= 1'b0;
            end else begin
                dyn_valid <= 1'b0;  // default
    
                if (z_valid) begin
                    // dynamic = current sample - current baseline
                    z_dynamic <= z_data - z_baseline;
    
                    // absolute value of dynamic thru 2s complement
                    if (z_dynamic[15])
                        z_dynamic_abs <= (~z_dynamic + 16'd1);
                    else
                        z_dynamic_abs <= z_dynamic[15:0];
    
                    // update baseline
                    z_baseline <= z_baseline + ((z_data - z_baseline) >>> BASELINE_SHIFT);
    
                    // mark outputs valid this cycle
                    dyn_valid <= 1'b1;
                end
            end
        end
    
    endmodule

