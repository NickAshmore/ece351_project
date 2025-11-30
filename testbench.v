`timescale 1ns / 1ps

module top_tb;

reg clk;
reg btnC;
reg gps_rx;
reg [15:0] sw;
wire acl_sclk;
wire acl_mosi;
reg  acl_miso;
wire acl_cs_n;
wire [6:0] seg;
wire [3:0] an;
wire dp;

localparam integer BIT_PERIOD = 104167;

top uut (
    .clk(clk),
    .btnC(btnC),
    .gps_rx(gps_rx),
    .sw(sw),
    .acl_sclk(acl_sclk),
    .acl_mosi(acl_mosi),
    .acl_miso(acl_miso),
    .acl_cs_n(acl_cs_n),
    .seg(seg),
    .an(an),
    .dp(dp)
);

always #5 clk = ~clk;

task send_byte;
    input [7:0] b;
    integer i;
    begin
        gps_rx = 1'b0;
        #(BIT_PERIOD);
        for (i = 0; i < 8; i = i + 1) begin
            gps_rx = b[i];
            #(BIT_PERIOD);
        end
        gps_rx = 1'b1;
        #(BIT_PERIOD);
    end
endtask

task send_gprmc_sentence;
    begin
        send_byte("$");
        send_byte("G");
        send_byte("P");
        send_byte("R");
        send_byte("M");
        send_byte("C");
        send_byte(",");
        send_byte("1");
        send_byte("2");
        send_byte("3");
        send_byte("5");
        send_byte("1");
        send_byte("9");
        send_byte(",");
        send_byte("A");
        send_byte(",");
        send_byte("4");
        send_byte("8");
        send_byte("0");
        send_byte("7");
        send_byte(".");
        send_byte("0");
        send_byte("3");
        send_byte("8");
        send_byte(",");
        send_byte("N");
        send_byte(",");
        send_byte("0");
        send_byte("1");
        send_byte("1");
        send_byte("3");
        send_byte("1");
        send_byte(".");
        send_byte("0");
        send_byte("0");
        send_byte("0");
        send_byte(",");
        send_byte("E");
        send_byte(",");
        send_byte("0");
        send_byte("2");
        send_byte("2");
        send_byte(".");
        send_byte("4");
        send_byte(",");
        send_byte("0");
        send_byte("8");
        send_byte("4");
        send_byte(".");
        send_byte("4");
        send_byte(",");
        send_byte("2");
        send_byte("3");
        send_byte("0");
        send_byte("3");
        send_byte("9");
        send_byte("4");
        send_byte(",");
        send_byte("0");
        send_byte("0");
        send_byte("*");
        send_byte("4");
        send_byte("1");
        send_byte(8'h0D);
        send_byte(8'h0A);
    end
endtask

task gen_step;
    integer s;
    begin
        for (s = 0; s < 20; s = s + 1) begin
            @(posedge clk);
            force uut.z_dynamic_abs = 16'd300;
            force uut.dyn_valid = 1'b1;
        end
        for (s = 0; s < 400; s = s + 1) begin
            @(posedge clk);
            force uut.z_dynamic_abs = 16'd0;
            force uut.dyn_valid = 1'b1;
        end
        repeat (1200) @(posedge clk);
    end
endtask

integer i;

initial begin
    clk = 0;
    btnC = 1;
    gps_rx = 1;
    acl_miso = 0;
    sw = 16'h8001;
    #200;
    btnC = 0;
    #500;
    for (i = 0; i < 3; i = i + 1) gen_step();
    #5000;
    sw[0] = 1'b0;
    #50000;
    release uut.z_dynamic_abs;
    release uut.dyn_valid;
    sw = 16'h0000;
    #(BIT_PERIOD*50);
    send_gprmc_sentence();
    #(BIT_PERIOD*200);
    send_gprmc_sentence();
    #(BIT_PERIOD*200);
    $display("time=%0t step_count=%0d spm=%0d",$time,uut.step_count,uut.spm);
    $finish;
end

endmodule





