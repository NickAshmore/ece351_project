`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/19/2025 03:58:21 PM
// Design Name: 
// Module Name: seven_seg_driver
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


module seven_seg_driver(
    input wire clk,
    input wire rst,

    input wire [3:0] d0,
    input wire [3:0] d1,
    input wire [3:0] d2,
    input wire [3:0] d3,

    output reg [3:0] an,
    output reg [6:0] seg
);

    reg [1:0] digit_select = 0;
    reg [3:0] current_digit;

    reg [15:0] refresh_count = 0;

    always @(posedge clk) begin
        if (rst) begin
            refresh_count <= 0;
            digit_select <= 0;
        end else begin
            refresh_count <= refresh_count + 1;
            if (refresh_count == 50000) begin
                refresh_count <= 0;
                digit_select <= digit_select + 1;
            end
        end
    end

    always @(*) begin
        case (digit_select)
            2'd0: begin an = 4'b1110; current_digit = d3; end
            2'd1: begin an = 4'b1101; current_digit = d2; end
            2'd2: begin an = 4'b1011; current_digit = d1; end
            2'd3: begin an = 4'b0111; current_digit = d0; end
        endcase
    end

    always @(*) begin
        case (current_digit)
            4'd0: seg = 7'b1000000;
            4'd1: seg = 7'b1111001;
            4'd2: seg = 7'b0100100;
            4'd3: seg = 7'b0110000;
            4'd4: seg = 7'b0011001;
            4'd5: seg = 7'b0010010;
            4'd6: seg = 7'b0000010;
            4'd7: seg = 7'b1111000;
            4'd8: seg = 7'b0000000;
            4'd9: seg = 7'b0010000;
            default: seg = 7'b1111111;  // blank
        endcase
    end
endmodule
