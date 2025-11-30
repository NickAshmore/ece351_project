`timescale 1ns / 1ps

module knots_to_mph (
    input  wire       clk,
    input  wire       rst,
    input  wire       speed_ready,

    input  wire [7:0] spd0,
    input  wire [7:0] spd1,
    input  wire [7:0] spd2,
    input  wire [7:0] spd3,
    input  wire [7:0] spd4,
    input  wire [7:0] spd5,

    output reg  [3:0] mph0,
    output reg  [3:0] mph1,
    output reg  [3:0] mph2,
    output reg  [3:0] mph3,

    output reg [15:0] mph_x100_out
);

    reg [15:0] speed_knots_x100;
    reg [15:0] mph_x100;

    integer k0, k1, k2, k3;
    integer num;

    always @(posedge clk) begin
        if (rst) begin
            mph0 <= 4'd0;
            mph1 <= 4'd0;
            mph2 <= 4'd0;
            mph3 <= 4'd0;
            mph_x100_out <= 0;
        end

        else if (speed_ready) begin

            k0 = (spd0 >= "0" && spd0 <= "9") ? (spd0 - "0") : 0; //subtract ascii 0 to convert the number
            k1 = (spd1 == ".")                ? -1          : (spd1 - "0");
            k2 = (spd2 >= "0" && spd2 <= "9") ? (spd2 - "0") : 0;
            k3 = (spd3 >= "0" && spd3 <= "9") ? (spd3 - "0") : 0;

            //converts ASCII speed to fixed point ×100
            if (k1 == -1) //format X.YY
                num = (k0 * 100) + (k2 * 10) + k3;
            else  //format XX.Y
                num = (k0 * 1000) + (k1 * 100) + (k2 * 10) + k3;

            speed_knots_x100 <= num;

            //convert knots×100 to mph×100
            mph_x100 <= (num * 115) / 100;

            //output MPH digits in 4 bit segments
            mph0 <= (mph_x100 / 1000) % 10;
            mph1 <= (mph_x100 / 100)  % 10;
            mph2 <= (mph_x100 / 10)   % 10;
            mph3 <= (mph_x100 / 1)    % 10;

            //output raw MPH ×100, had this just in case the 16 bit was needed
            mph_x100_out <= mph_x100;
        end
    end
endmodule
