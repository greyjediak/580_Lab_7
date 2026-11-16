`timescale 1ns/1ps
module tb_stored_cpu;
    logic clk = 1'b0;
    always #5 clk = ~clk;
    logic rst = 1'b1;

    logic [7:0] five_r0, five_r1, five_r2, five_r3;
    logic [7:0] long_r0, long_r1, long_r2, long_r3;
    logic [7:0] bad_r0, bad_r1, bad_r2, bad_r3;
    logic [7:0] wrap_r0, wrap_r1, wrap_r2, wrap_r3;
    logic [3:0] five_pc, long_pc, bad_pc, wrap_pc;
    logic [7:0] five_ir, long_ir, bad_ir, wrap_ir;
    logic [2:0] five_state, long_state, bad_state, wrap_state;
    logic five_halted, long_halted, bad_halted, wrap_halted;
    logic five_illegal, long_illegal, bad_illegal, wrap_illegal;
    logic [7:0] five_sel, long_sel, bad_sel, wrap_sel;

    stored_cpu #(.MEM_FILE("program_5.mem")) u_five (
        .clk(clk), .rst(rst), .debug_sel(2'd0), .debug_reg(five_sel),
        .debug_pc(five_pc), .debug_ir(five_ir), .debug_state(five_state),
        .halted(five_halted), .illegal_instr(five_illegal),
        .debug_r0(five_r0), .debug_r1(five_r1),
        .debug_r2(five_r2), .debug_r3(five_r3)
    );
    stored_cpu #(.MEM_FILE("program_13.mem")) u_long (
        .clk(clk), .rst(rst), .debug_sel(2'd1), .debug_reg(long_sel),
        .debug_pc(long_pc), .debug_ir(long_ir), .debug_state(long_state),
        .halted(long_halted), .illegal_instr(long_illegal),
        .debug_r0(long_r0), .debug_r1(long_r1),
        .debug_r2(long_r2), .debug_r3(long_r3)
    );
    stored_cpu #(.MEM_FILE("program_invalid.mem")) u_bad (
        .clk(clk), .rst(rst), .debug_sel(2'd0), .debug_reg(bad_sel),
        .debug_pc(bad_pc), .debug_ir(bad_ir), .debug_state(bad_state),
        .halted(bad_halted), .illegal_instr(bad_illegal),
        .debug_r0(bad_r0), .debug_r1(bad_r1),
        .debug_r2(bad_r2), .debug_r3(bad_r3)
    );
    stored_cpu #(.MEM_FILE("program_wrap.mem")) u_wrap (
        .clk(clk), .rst(rst), .debug_sel(2'd0), .debug_reg(wrap_sel),
        .debug_pc(wrap_pc), .debug_ir(wrap_ir), .debug_state(wrap_state),
        .halted(wrap_halted), .illegal_instr(wrap_illegal),
        .debug_r0(wrap_r0), .debug_r1(wrap_r1),
        .debug_r2(wrap_r2), .debug_r3(wrap_r3)
    );

    int errors = 0;
    int five_retire = 0;
    int long_retire = 0;
    logic [3:0] previous_five_pc = 0;
    logic [3:0] previous_long_pc = 0;

    task automatic check(input logic condition, input string msg);
        if (condition !== 1'b1) begin
            $error("%s", msg);
            errors++;
        end
    endtask

    // Verify a series of architectural register states as instructions
    // retire (the PC increments once per non-HALT instruction).
    task automatic check_five_snapshot(input int index);
        case (index)
          1: check(five_r0 == 8'd2 && five_r1 == 0, "five: LDI R0");
          2: check(five_r0 == 8'd2 && five_r1 == 8'd3, "five: LDI R1");
          3: check(five_r0 == 8'd5 && five_r1 == 8'd3, "five: ADD");
          4: check(five_r0 == 8'd1 && five_r1 == 8'd3, "five: AND");
          default: begin $error("unexpected five-program retirement %0d",index); errors++; end
        endcase
    endtask

    task automatic check_long_snapshot(input int index);
        case (index)
          1: check(long_r0==8'd2,  "13: LDI R0");
          2: check(long_r1==8'd3,  "13: LDI R1");
          3: check(long_r2==8'd5,  "13: LDI R2");
          4: check(long_r3==8'd1,  "13: LDI R3");
          5: check(long_r0==8'd5,  "13: ADD R0,R1");
          6: check(long_r2==8'd4,  "13: SUB R2,R3");
          7: check(long_r1==8'd0,  "13: AND R1,R2");
          8: check(long_r3==8'd5,  "13: IOR R3,R0");
          9: check(long_r0==8'd1,  "13: SUB R0,R2");
         10: check(long_r1==8'd4,  "13: IOR R1,R2");
         11: check(long_r2==8'd9,  "13: ADD R2,R3");
         12: check(long_r3==8'h0D,"13: IOR R3,R2");
          default: begin $error("unexpected 13-program retirement %0d",index); errors++; end
        endcase
    endtask

    // Sample after NBA updates; each PC change corresponds to an INC.
    always @(negedge clk) begin
        if (rst) begin
            previous_five_pc = 0;
            previous_long_pc = 0;
            five_retire = 0;
            long_retire = 0;
        end else begin
            if (five_pc !== previous_five_pc) begin
                five_retire++;
                check(five_pc == five_retire, "five: PC advanced incorrectly");
                check_five_snapshot(five_retire);
                previous_five_pc = five_pc;
            end
            if (long_pc !== previous_long_pc) begin
                long_retire++;
                check(long_pc == long_retire, "13: PC advanced incorrectly");
                check_long_snapshot(long_retire);
                previous_long_pc = long_pc;
            end
        end
    end

    initial begin
        // At least two edges with synchronous reset asserted.
        repeat (3) @(negedge clk);
        check(five_pc == 0 && long_pc == 0, "PCs reset to zero");
        check(five_r0 == 0 && long_r0 == 0, "register file resets to zero");
        rst = 1'b0;

        // Explicit timeout for four independent programs.
        begin : wait_for_completion
            int c;
            c = 0;
            while (c < 300 &&
                   !(five_halted && long_halted && bad_halted && wrap_halted)) begin
                @(negedge clk);
                c++;
            end
        end

        check(five_halted && long_halted && bad_halted && wrap_halted,
               "all CPUs halted within timeout");
        check(five_pc == 4 && five_ir == 8'hE0, "five: HALT address/IR");
        check(five_r0 == 8'd1 && five_r1 == 8'd3 &&
               five_r2 == 0 && five_r3 == 0, "five: final register state");
        check(five_retire == 4 && !five_illegal, "five: retirement/illegal");
        check(five_sel == five_r0, "five: debug register selector");

        check(long_pc == 12 && long_ir == 8'hE0, "13: HALT address/IR");
        check(long_r0 == 8'd1 && long_r1 == 8'd4 &&
               long_r2 == 8'd9 && long_r3 == 8'h0D, "13: final registers");
        check(long_retire == 12 && !long_illegal, "13: retirement/illegal");
        check(long_sel == long_r1, "13: debug register selector");

        check(bad_pc == 1 && bad_r0 == 8'd5 && bad_illegal,
               "reserved opcode must trap without PC increment/writeback");
        check(wrap_pc == 4 && wrap_r0 == 0 && wrap_r1 == 1 &&
               !wrap_illegal, "8-bit modulo arithmetic / wraparound");

        // All architectural state must remain stable after halting.
        repeat (6) @(negedge clk);
        check(five_pc == 4 && five_r0 == 1 && long_pc == 12 &&
               long_r3 == 8'h0D && bad_pc == 1 && wrap_pc == 4,
               "registers/PC must hold while halted");

        if (errors == 0) $display("PASS: stored_cpu -- 4 programs and all retirement checks");
        else $fatal(1, "FAIL: stored_cpu (%0d errors)",errors);
        $finish;
    end
endmodule
