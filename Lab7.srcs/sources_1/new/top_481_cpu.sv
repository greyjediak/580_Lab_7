`timescale 1ns / 1ps

module top_481_cpu(
    input logic clk,
    input logic btnC,
    input logic [1:0] sw,
    output logic [14:0] led
    );
    
    logic btn_temp, rst;
    always_ff @(posedge clk) begin
        btn_temp <= btnC;
        rst <= btn_temp;
    end
    logic [7:0] sel_reg;
    logic[3:0] pc;
    logic halted, illegal;
    
    stored_cpu #(.MEM_FILE("program_13.mem")) u_long (
        .clk(clk), 
        .rst(rst), 
        .debug_sel(sw), 
        .debug_reg(sel_reg),
        .debug_pc(pc), 
        .debug_ir(), 
        .debug_state(),
        .halted(halted), 
        .illegal_instr(illegal),
        .debug_r0(), 
        .debug_r1(),
        .debug_r2(), 
        .debug_r3()
    );
    assign led[7:0]  = sel_reg;   
    assign led[11:8] = pc;        // current PC
    assign led[12]   = halted;
    assign led[13]   = illegal;
    assign led[14]   = ~halted;   // running indicator
endmodule
