`timescale 1ns / 1ps

module step_detector #(
    // High and low magnitude thresholds
    parameter [15:0] TH_HIGH = 16'd250,  
    parameter [15:0] TH_LOW  = 16'd150,  

    // Timing constraints for valid step
    parameter integer MIN_PEAK_SAMPLES = 8,
    parameter integer MAX_PEAK_SAMPLES = 200,

    // Minimum gap between two steps (both samples and cycles
    parameter integer MIN_STEP_GAP_SAMPLES = 200,
    parameter integer MIN_STEP_GAP_CYCLES = 50_000_000
)(
    input wire clk,
    input wire reset,

    // From accelerometer preprocessing:
    input wire dyn_valid, // pulse for new sample
    input wire [15:0] z_dynamic_abs, //sample - baseline

    // Outputs
    output reg step_pulse, // step detected
    output reg [15:0] step_count,
    output reg in_peak, 
    output reg [15:0] peak_len_samples, // samples in current peak
    output reg [15:0] gap_samples // samples since last accepted step
);

    // Clock cycles since last step
    reg [31:0] gap_cycles;

    // State encodings
    localparam [1:0]
        S_IDLE = 2'd0,
        S_PEAK_RISE = 2'd1,
        S_PEAK_FALL = 2'd2,
        S_COOLDOWN = 2'd3;

    reg [1:0] state, next_state;

    // Timing requirement wires
    wire peak_len_too_short = (peak_len_samples <  MIN_PEAK_SAMPLES[15:0]);
    wire peak_len_too_long = (peak_len_samples >  MAX_PEAK_SAMPLES[15:0]);
    wire peak_len_valid = (peak_len_samples >= MIN_PEAK_SAMPLES[15:0] && peak_len_samples <= MAX_PEAK_SAMPLES[15:0]);
    wire cooldown_done_samples = (gap_samples >= MIN_STEP_GAP_SAMPLES[15:0]);
    wire cooldown_done_cycles = (gap_cycles  >= MIN_STEP_GAP_CYCLES[31:0]);
    wire cooldown_done = cooldown_done_samples && cooldown_done_cycles;

    // Sequential block: state register & datapath updates
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_IDLE;
            step_pulse <= 1'b0;
            step_count <= 16'd0;
            in_peak <= 1'b0;
            peak_len_samples <= 16'd0;
            gap_samples <= 16'd0;
            gap_cycles <= 32'd0;
        end else begin
            state <= next_state;
            step_pulse <= 1'b0;

            // Count cycles since last valid step
            if (gap_cycles != 32'hFFFF_FFFF)
                gap_cycles <= gap_cycles + 32'd1;

            // Count samples since last valid step
            if (dyn_valid) begin
                if (gap_samples != 16'hFFFF)
                    gap_samples <= gap_samples + 16'd1;
            end
            in_peak <= (state == S_PEAK_RISE) || (state == S_PEAK_FALL);

            // Peak length counting & step detection
            case (state)
                // IDLE: waiting for a new peak
                S_IDLE: begin
                    // no active peak
                    peak_len_samples <= 16'd0;

                    if (dyn_valid && z_dynamic_abs >= TH_HIGH) begin
                        // starting a new peak
                        peak_len_samples <= 16'd1;
                    end
                end

                // PEAK_RISE: inside a peak while magnitude is high
                S_PEAK_RISE: begin
                    if (dyn_valid) begin
                        if (z_dynamic_abs >= TH_LOW) begin
                            // still inside peak, keep counting length
                            if (peak_len_samples != 16'hFFFF)
                                peak_len_samples <= peak_len_samples + 16'd1;
                        end
                    end
                end

                // PEAK_FALL: peak just ended, decide if it was a step
                S_PEAK_FALL: begin
                    // Decide only once, on entering this state.
                    // If peak duration is valid, register a step.
                    if (peak_len_valid) begin
                        step_pulse <= 1'b1;
                        step_count <= step_count + 16'd1;
                        gap_samples <= 16'd0;
                        gap_cycles <= 32'd0;
                    end
                    peak_len_samples <= 16'd0;
                end

                // COOLDOWN: enforce minimum time between steps
                S_COOLDOWN: begin
                    // cooldown checked in next state logic
                    peak_len_samples <= 16'd0;
                end

                default: begin
                    peak_len_samples <= 16'd0;
                end
            endcase
        end
    end


    // Combinational next state logic
    always @(*) begin
        next_state = state;

        case (state)
            // IDLE: can start a peak if TH_HIGH is crossed
            S_IDLE: begin
                if (dyn_valid && z_dynamic_abs >= TH_HIGH) begin
                    next_state = S_PEAK_RISE;
                end
            end

            // PEAK_RISE: stay while above TH_LOW, else go to PEAK_FALL
            // If peak gets too long, abandon and go to IDLE.
            S_PEAK_RISE: begin
                if (dyn_valid) begin
                    if (z_dynamic_abs >= TH_LOW) begin
                        // still in peak; if it's already too long, abandon
                        if (peak_len_samples >= MAX_PEAK_SAMPLES[15:0])
                            next_state = S_IDLE;  // invalid long peak
                        else
                            next_state = S_PEAK_RISE;
                    end else begin
                        next_state = S_PEAK_FALL;
                    end
                end
            end

            // PEAK_FALL: Check timing 
            S_PEAK_FALL: begin
                if (peak_len_valid)
                    next_state = S_COOLDOWN; // accepted
                else
                    next_state = S_IDLE; // rejected (too short/long)
            end

            // COOLDOWN: wait until both time-based and sample-based gaps, then go back to IDLE.
            S_COOLDOWN: begin
                if (cooldown_done)
                    next_state = S_IDLE;
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

endmodule

