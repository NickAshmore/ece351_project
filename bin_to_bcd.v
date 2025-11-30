`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/23/2025 12:43:15 PM
// Design Name: 
// Module Name: bin_to_bcd_4digits
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


module bin_to_bcd_4digits (
    input  wire [15:0] value,
    output wire [3:0]  d0,
    output wire [3:0]  d1,
    output wire [3:0]  d2,
    output wire [3:0]  d3
);
    wire [15:0] v = (value > 16'd9999) ? 16'd9999 : value;

    assign d0 = (v / 16'd1000) % 10;
    assign d1 = (v / 16'd100)  % 10;
    assign d2 = (v / 16'd10)   % 10;
    assign d3 =  v             % 10;

endmodule
