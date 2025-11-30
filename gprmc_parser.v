`timescale 1ns / 1ps

module gprmc_parser (

    input  wire       clk,
    input  wire       rst,

    // UART input
    input  wire [7:0] rx_data,
    input  wire       rx_valid,

    // Fix status output
    output reg        fix_valid,    // 1 = Active (A), 0 = Void (V)

    // Latitude ASCII digits (DDMMmmmm)
    output wire [7:0] lat0, lat1, lat2, lat3, lat4, lat5, lat6, lat7,

    // Longitude ASCII digits (DDDMMmmm) - we use first 8 chars
    output wire [7:0] lon0, lon1, lon2, lon3, lon4, lon5, lon6, lon7,

    // Speed ASCII digits (knots)
    output wire [7:0] spd0, spd1, spd2, spd3, spd4, spd5,
    output reg        speed_ready   // 1-cycle pulse when speed field completes
);


    // ---------------------------
    // Internal Registers
    // ---------------------------

    // GPRMC header detection state:
    // 0 = idle
    // 1 = saw '$'
    // 2 = "$G"
    // 3 = "$GP"
    // 4 = "$GPR"
    // 5 = "$GPRM"
    // 6 = "$GPRMC" (valid sentence - stay here until next '$')
    reg [2:0] gprmc_state;

    // Comma counting within a valid GPRMC sentence
    reg [3:0] comma_count;

    // Latitude
    reg [7:0] lat0_reg, lat1_reg, lat2_reg, lat3_reg;
    reg [7:0] lat4_reg, lat5_reg, lat6_reg, lat7_reg;
    reg [3:0] lat_len;

    // Longitude
    reg [7:0] lon0_reg, lon1_reg, lon2_reg, lon3_reg;
    reg [7:0] lon4_reg, lon5_reg, lon6_reg, lon7_reg;
    reg [3:0] lon_len;

    // Speed (knots)
    reg [7:0] spd0_reg, spd1_reg, spd2_reg, spd3_reg, spd4_reg, spd5_reg;
    reg [2:0] speed_len;


    // ---------------------------
    // Sequential Logic
    // ---------------------------
    always @(posedge clk) begin
        if (rst) begin
            // Reset parser state
            gprmc_state  <= 3'd0;
            comma_count  <= 4'd0;

            lat_len   <= 4'd0;
            lon_len   <= 4'd0;
            speed_len <= 3'd0;

            fix_valid   <= 1'b0;
            speed_ready <= 1'b0;

            // Clear stored digits
            lat0_reg <= "0"; lat1_reg <= "0"; lat2_reg <= "0"; lat3_reg <= "0";
            lat4_reg <= "0"; lat5_reg <= "0"; lat6_reg <= "0"; lat7_reg <= "0";

            lon0_reg <= "0"; lon1_reg <= "0"; lon2_reg <= "0"; lon3_reg <= "0";
            lon4_reg <= "0"; lon5_reg <= "0"; lon6_reg <= "0"; lon7_reg <= "0";

            spd0_reg <= "0"; spd1_reg <= "0"; spd2_reg <= "0";
            spd3_reg <= "0"; spd4_reg <= "0"; spd5_reg <= "0";
        end
        else if (rx_valid) begin
            // default
            speed_ready <= 1'b0;

            // -------------------------------------------------
            // 1) GPRMC HEADER DETECTION STATE MACHINE
            // -------------------------------------------------
            case (gprmc_state)
                3'd0: begin
                    // idle, wait for '$'
                    if (rx_data == "$")
                        gprmc_state <= 3'd1;
                    else
                        gprmc_state <= 3'd0;
                end

                3'd1: begin
                    // saw '$', expect 'G'
                    if (rx_data == "G")
                        gprmc_state <= 3'd2;
                    else if (rx_data == "$")
                        gprmc_state <= 3'd1;   // new '$'
                    else
                        gprmc_state <= 3'd0;
                end

                3'd2: begin
                    // "$G", expect 'P'
                    if (rx_data == "P")
                        gprmc_state <= 3'd3;
                    else if (rx_data == "$")
                        gprmc_state <= 3'd1;
                    else
                        gprmc_state <= 3'd0;
                end

                3'd3: begin
                    // "$GP", expect 'R'
                    if (rx_data == "R")
                        gprmc_state <= 3'd4;
                    else if (rx_data == "$")
                        gprmc_state <= 3'd1;
                    else
                        gprmc_state <= 3'd0;
                end

                3'd4: begin
                    // "$GPR", expect 'M'
                    if (rx_data == "M")
                        gprmc_state <= 3'd5;
                    else if (rx_data == "$")
                        gprmc_state <= 3'd1;
                    else
                        gprmc_state <= 3'd0;
                end

                3'd5: begin
                    // "$GPRM", expect 'C'
                    if (rx_data == "C") begin
                        gprmc_state <= 3'd6;

                        // NEW $GPRMC sentence starts here - reset fields
                        comma_count <= 4'd0;

                        lat_len   <= 4'd0;
                        lon_len   <= 4'd0;
                        speed_len <= 3'd0;

                        lat0_reg <= "0"; lat1_reg <= "0"; lat2_reg <= "0"; lat3_reg <= "0";
                        lat4_reg <= "0"; lat5_reg <= "0"; lat6_reg <= "0"; lat7_reg <= "0";

                        lon0_reg <= "0"; lon1_reg <= "0"; lon2_reg <= "0"; lon3_reg <= "0";
                        lon4_reg <= "0"; lon5_reg <= "0"; lon6_reg <= "0"; lon7_reg <= "0";

                        spd0_reg <= "0"; spd1_reg <= "0"; spd2_reg <= "0";
                        spd3_reg <= "0"; spd4_reg <= "0"; spd5_reg <= "0";
                    end
                    else if (rx_data == "$")
                        gprmc_state <= 3'd1;
                    else
                        gprmc_state <= 3'd0;
                end

                3'd6: begin
                    // Inside a valid $GPRMC sentence
                    // If we see another '$', start over
                    if (rx_data == "$")
                        gprmc_state <= 3'd1;
                    else
                        gprmc_state <= 3'd6;
                end

                default: gprmc_state <= 3'd0;
            endcase


            // -------------------------------------------------
            // 2) Within a valid $GPRMC sentence (state = 6)
            // -------------------------------------------------
            if (gprmc_state == 3'd6) begin

                // 2a) Count commas to know which field we're in
                if (rx_data == ",")
                    comma_count <= comma_count + 1'b1;

                // 2b) FIELD 2 - Fix status (A / V)
                // comma_count == 2 while reading the status char
                if (comma_count == 4'd2 && rx_data != "," ) begin
                    fix_valid <= (rx_data == "A") ? 1'b1 : 1'b0;
                end

                // 2c) FIELD 3 - Latitude DDMMmmmm
                // comma_count == 3 while reading latitude characters
                if (comma_count == 4'd3) begin
                    if (rx_data != ",") begin
                        case (lat_len)
                            4'd0: lat0_reg <= rx_data;
                            4'd1: lat1_reg <= rx_data;
                            4'd2: lat2_reg <= rx_data;
                            4'd3: lat3_reg <= rx_data;
                            4'd4: lat4_reg <= rx_data;
                            4'd5: lat5_reg <= rx_data;
                            4'd6: lat6_reg <= rx_data;
                            4'd7: lat7_reg <= rx_data;
                        endcase
                        if (lat_len < 4'd7)
                            lat_len <= lat_len + 1'b1;
                    end
                    else begin
                        lat_len <= 4'd0; // end of latitude field
                    end
                end

                // 2d) FIELD 5 - Longitude DDDMMmmm...
                // comma_count == 5 while reading longitude characters
                if (comma_count == 4'd5) begin
                    if (rx_data != ",") begin
                        case (lon_len)
                            4'd0: lon0_reg <= rx_data;
                            4'd1: lon1_reg <= rx_data;
                            4'd2: lon2_reg <= rx_data;
                            4'd3: lon3_reg <= rx_data;
                            4'd4: lon4_reg <= rx_data;
                            4'd5: lon5_reg <= rx_data;
                            4'd6: lon6_reg <= rx_data;
                            4'd7: lon7_reg <= rx_data;
                        endcase
                        if (lon_len < 4'd7)
                            lon_len <= lon_len + 1'b1;
                    end
                    else begin
                        lon_len <= 4'd0; // end of longitude field
                    end
                end

                // 2e) FIELD 7 - Speed in knots (ASCII)
                // comma_count == 7 while reading speed characters
                if (comma_count == 4'd7) begin
                    if (rx_data != ",") begin
                        case (speed_len)
                            3'd0: spd0_reg <= rx_data;
                            3'd1: spd1_reg <= rx_data;
                            3'd2: spd2_reg <= rx_data;
                            3'd3: spd3_reg <= rx_data;
                            3'd4: spd4_reg <= rx_data;
                            3'd5: spd5_reg <= rx_data;
                        endcase
                        if (speed_len < 3'd5)
                            speed_len <= speed_len + 1'b1;

                        speed_ready <= 1'b0;   // only pulse on comma at end
                    end
                    else begin
                        // end of speed field
                        speed_ready <= 1'b1;
                        speed_len   <= 3'd0;
                    end
                end

            end // if (gprmc_state == 6)

        end // else if (rx_valid)
    end // always @(posedge clk)



    // ---------------------------------
    // Output assignments
    // ---------------------------------
    assign lat0 = lat0_reg;
    assign lat1 = lat1_reg;
    assign lat2 = lat2_reg;
    assign lat3 = lat3_reg;
    assign lat4 = lat4_reg;
    assign lat5 = lat5_reg;
    assign lat6 = lat6_reg;
    assign lat7 = lat7_reg;

    assign lon0 = lon0_reg;
    assign lon1 = lon1_reg;
    assign lon2 = lon2_reg;
    assign lon3 = lon3_reg;
    assign lon4 = lon4_reg;
    assign lon5 = lon5_reg;
    assign lon6 = lon6_reg;
    assign lon7 = lon7_reg;

    assign spd0 = spd0_reg;
    assign spd1 = spd1_reg;
    assign spd2 = spd2_reg;
    assign spd3 = spd3_reg;
    assign spd4 = spd4_reg;
    assign spd5 = spd5_reg;

endmodule