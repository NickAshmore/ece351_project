`timescale 1ns / 1ps

module steps_per_min(input clk, rst, [15:0]step_count, output [15:0]spm);
    
    reg [15:0]sec_count;
    reg [27:0]cycle_count;
    reg [15:0]r_spm;
    
    always@(posedge clk) begin
        if(rst) begin
            sec_count <= 0; // seconds counter
            cycle_count <= 0; // cycle counter
        end
        else begin
            if(cycle_count == 27'd99_999_999) begin // the second counter increments every 100_000_000 10 ns cycles
                cycle_count <= 0;
                sec_count <= sec_count + 1;
            end
            else
                cycle_count <= cycle_count + 1; // increase cycle counter every clock edge 
        end
    end   
 
    always@(posedge clk) begin
        if(rst)
            r_spm <= 0;
        else if (sec_count != 0)
            r_spm <= (step_count * 16'd60) / sec_count; // total steps * 60 seconds / total seconds equals steps per minute
    end
    
    assign spm = r_spm;
        
endmodule
