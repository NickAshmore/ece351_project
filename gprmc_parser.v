`timescale 1ns / 1ps

module gprmc_parser (

    input  wire       clk,
    input  wire       rst,

    input  wire [7:0] rx_data,
    input  wire       rx_valid,

    output reg        fix_valid, 

    output wire [7:0] lat0, lat1, lat2, lat3, lat4, lat5, lat6, lat7, //latitude4-7 ended not being used but kept anyway

    output wire [7:0] lon0, lon1, lon2, lon3, lon4, lon5, lon6, lon7, //longitude4-7 not used as well

    output wire [7:0] spd0, spd1, spd2, spd3, spd4, spd5, //speed in knots
    output reg        speed_ready //1 cycle pulse whenever speed cycle is done
);

    reg [2:0] gprmc_state;

    reg [3:0] comma_count; //counts commas in gpmrc

    //latitude
    reg [7:0] lat0_reg, lat1_reg, lat2_reg, lat3_reg;
    reg [7:0] lat4_reg, lat5_reg, lat6_reg, lat7_reg;
    reg [3:0] lat_len;

    //longitude
    reg [7:0] lon0_reg, lon1_reg, lon2_reg, lon3_reg;
    reg [7:0] lon4_reg, lon5_reg, lon6_reg, lon7_reg;
    reg [3:0] lon_len;

    //speed
    reg [7:0] spd0_reg, spd1_reg, spd2_reg, spd3_reg, spd4_reg, spd5_reg;
    reg [2:0] speed_len;

    always @(posedge clk) begin
        if (rst) begin //resets parser state
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
            speed_ready <= 1'b0; //default 

            case (gprmc_state) //detects gpmrc header
                3'd0: begin
                    if (rx_data == "$") //idles and waits for $
                        gprmc_state <= 3'd1;
                    else
                        gprmc_state <= 3'd0;
                end

                3'd1: begin //expect G
                    if (rx_data == "G")
                        gprmc_state <= 3'd2;
                    else if (rx_data == "$")
                        gprmc_state <= 3'd1;
                    else
                        gprmc_state <= 3'd0;
                end

                3'd2: begin //expect P
                    if (rx_data == "P")
                        gprmc_state <= 3'd3;
                    else if (rx_data == "$")
                        gprmc_state <= 3'd1;
                    else
                        gprmc_state <= 3'd0;
                end

                3'd3: begin //expect R
                    if (rx_data == "R")
                        gprmc_state <= 3'd4;
                    else if (rx_data == "$")
                        gprmc_state <= 3'd1;
                    else
                        gprmc_state <= 3'd0;
                end

                3'd4: begin //exepct M
                    if (rx_data == "M")
                        gprmc_state <= 3'd5;
                    else if (rx_data == "$")
                        gprmc_state <= 3'd1;
                    else
                        gprmc_state <= 3'd0;
                end

                3'd5: begin //expect C
                    if (rx_data == "C") begin
                        gprmc_state <= 3'd6;

                        comma_count <= 4'd0; //reset field, new sentences start here

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
                    if (rx_data == "$") //if we see another $ start over
                        gprmc_state <= 3'd1;
                    else
                        gprmc_state <= 3'd6;
                end

                default: gprmc_state <= 3'd0;
            endcase


            if (gprmc_state == 3'd6) begin //state = 6 when in valid

                if (rx_data == ",") //count commas
                    comma_count <= comma_count + 1'b1;

                if (comma_count == 4'd2 && rx_data != "," ) begin //used to get fix status A/V (not used)
                    fix_valid <= (rx_data == "A") ? 1'b1 : 1'b0;
                end

                if (comma_count == 4'd3) begin //read in latitude when at at third comma
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
                        lat_len <= 4'd0; //end of latitude
                    end
                end

                if (comma_count == 4'd5) begin //read in longitude at fifth comma
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
                        lon_len <= 4'd0; //end longitude
                    end
                end

                if (comma_count == 4'd7) begin //read in speed at 7th comma
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

                        speed_ready <= 1'b0; //pulse on comma end
                    end
                    else begin
                        speed_ready <= 1'b1;
                        speed_len   <= 3'd0;
                    end
                end

            end

        end
    end


    //output assignments
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
