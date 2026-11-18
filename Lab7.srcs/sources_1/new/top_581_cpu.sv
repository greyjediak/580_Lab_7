`timescale 1ns / 1ps

module top_581_cpu (
    input  logic        clk,      // 100 MHz Basys3 clock
    input  logic        btnC,     // active-high reset button
    input  logic [1:0]  sw,       // selects R0-R3 for display
    output logic [14:0] led
);
    // Two-flop synchronizer: btnC is asynchronous to clk.
    logic btn_meta, rst;
    always_ff @(posedge clk) begin
        btn_meta <= btnC;
        rst      <= btn_meta;
    end

    logic [7:0] sel_reg;
    logic [3:0] pc;
    logic       halted, illegal;

    ext_stored_cpu #(.MEM_FILE("ext_program.mem")) u_cpu (   // 581 CPU + loop program
        .clk(clk),
        .rst(rst),
        .debug_sel(sw),
        .debug_reg(sel_reg),
        .debug_pc(pc),
        .debug_ir(),
        .debug_state(),
        .halted(halted),
        .illegal_instr(illegal),
        .debug_r0(), .debug_r1(),
        .debug_r2(), .debug_r3()
    );

    assign led[7:0]  = sel_reg;   // selected register
    assign led[11:8] = pc;        // current PC
    assign led[12]   = halted;
    assign led[13]   = illegal;
    assign led[14]   = ~halted;   // running indicator
endmodule