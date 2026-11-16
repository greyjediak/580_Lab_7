`timescale 1ns/1ps

module stored_cpu_controller (
    input  logic       clk,
    input  logic       rst,
    input  logic       is_rtype,
    input  logic       is_ldi,
    input  logic       is_halt,
    input  logic       is_valid,

    output logic       rom_en,
    output logic       ir_en,
    output logic       alu_result_en,
    output logic       reg_wr_en,
    output logic       pc_en,
    output logic       wb_sel_imm,
    output logic       halted,
    output logic       illegal_instr,
    output logic [2:0] dbg_state
);
    // Keep these encodings unchanged for the supplied testbenches.
    localparam logic [2:0]
        S_FETCH  = 3'd0,
        S_IR     = 3'd1,
        S_DECODE = 3'd2,
        S_EXEC   = 3'd3,
        S_WB     = 3'd4,
        S_INC    = 3'd5,
        S_HALT   = 3'd6;

    logic [2:0] state, next_state;
    logic       illegal_seen;

    // State and illegal-instruction flag registers.
    always_ff @(posedge clk) begin
        if (rst) begin
            state        <= S_FETCH;
            illegal_seen <= 1'b0;
        end else begin
            state <= next_state;
            // Flag only the instruction being decoded right now.
            if (!is_valid && state == S_DECODE)
                illegal_seen <= 1'b1;
        end
    end

    // Next-state and Moore-style control outputs.
    always_comb begin
        // Defaults: hold state, all enables off.
        next_state    = state;
        rom_en        = 1'b0;
        ir_en         = 1'b0;
        alu_result_en = 1'b0;
        reg_wr_en     = 1'b0;
        pc_en         = 1'b0;
        wb_sel_imm    = 1'b0;
        halted        = 1'b0;

        case (state)
            S_FETCH: begin
                rom_en     = 1'b1;          // ROM registers mem[pc]
                next_state = S_IR;
            end

            S_IR: begin
                ir_en      = 1'b1;          // IR captures rom_data
                next_state = S_DECODE;
            end

            S_DECODE: begin
                // No enables: decoder settles on the new IR.
                if (!is_valid || is_halt)
                    next_state = S_HALT;
                else if (is_ldi)
                    next_state = S_WB;      // LDI skips EXEC
                else if (is_rtype)
                    next_state = S_EXEC;
                else
                    next_state = S_HALT;
            end

            S_EXEC: begin
                alu_result_en = 1'b1;       // capture alu_y into alu_q
                next_state    = S_WB;
            end

            S_WB: begin
                reg_wr_en  = 1'b1;          // write R[rd]
                wb_sel_imm = is_ldi;        // imm3 for LDI, alu_q for R-type
                next_state = S_INC;
            end

            S_INC: begin
                pc_en      = 1'b1;          // PC <= PC + 1
                next_state = S_FETCH;
            end

            S_HALT: begin
                halted     = 1'b1;          // all enables stay 0
                next_state = S_HALT;
            end

            default: next_state = S_HALT;
        endcase
    end

    assign illegal_instr = illegal_seen;
    assign dbg_state     = state;
endmodule