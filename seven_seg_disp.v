`timescale 1ns / 1ps

module sevenseg_hex (
    input wire clk,
    input wire reset,
    input wire [15:0] value,
    output reg [6:0] seg,
    output reg [3:0] an,
    output wire dp
);
    assign dp = 1'b1; // decimal point off

    // simple refresh counter
    reg [15:0] refresh_cnt;
    reg [1:0]  digit_sel;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            refresh_cnt <= 16'd0;
            digit_sel   <= 2'd0;
        end else begin
            refresh_cnt <= refresh_cnt + 1'b1;
            // use top bits as slow selector
            digit_sel   <= refresh_cnt[15:14];
        end
    end

    // digit multiplexing
    wire [3:0] nibble =
        (digit_sel == 2'd0) ? value[3:0]  :
        (digit_sel == 2'd1) ? value[7:4]  :
        (digit_sel == 2'd2) ? value[11:8] :
                              value[15:12];

    always @(*) begin
        case (digit_sel)
            2'd0: an = 4'b1110;
            2'd1: an = 4'b1101;
            2'd2: an = 4'b1011;
            2'd3: an = 4'b0111;
        endcase
    end

    always @(*) begin
        case (nibble)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            4'hF: seg = 7'b0001110;
            default: seg = 7'b1111111;
        endcase
    end

endmodule

