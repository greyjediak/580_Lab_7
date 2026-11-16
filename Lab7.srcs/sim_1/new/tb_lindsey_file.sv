`timescale 1ns/1ps

module tb__lindsey_file;
    logic clk = 1'b0;
    always #5 clk = ~clk;             // 100 MHz
    logic rst = 1'b1;

    localparam int N_RETIRE = 9;      // instructions completed before HALT
    localparam int TIMEOUT  = 200;    // clocks allowed to reach HALT

    // Controller state encodings (must match stored_cpu_controller).
    localparam logic [2:0] S_FETCH = 3'd0, S_IR  = 3'd1, S_DECODE = 3'd2,
                           S_EXEC  = 3'd3, S_WB  = 3'd4, S_INC    = 3'd5,
                           S_HALT  = 3'd6;

    logic [7:0] r0, r1, r2, r3, ir, selected;
    logic [3:0] pc;
    logic [2:0] state;
    logic       halted, illegal_instr;
    logic [1:0] sel = 2'd0;

    stored_cpu #(.MEM_FILE("program_lindsey_10.mem")) dut (
        .clk(clk), .rst(rst), .debug_sel(sel), .debug_reg(selected),
        .debug_pc(pc), .debug_ir(ir), .debug_state(state),
        .halted(halted), .illegal_instr(illegal_instr),
        .debug_r0(r0), .debug_r1(r1),
        .debug_r2(r2), .debug_r3(r3)
    );

    // Independent copy of the program, used to check instruction fetch.
    logic [7:0] rom_copy [0:15];
    initial $readmemh("program_lindsey_10.mem", rom_copy);

    int errors  = 0;
    int retired = 0;

    task automatic check(input logic condition, input string msg);
        if (condition !== 1'b1) begin
            $error("%s", msg);
            errors++;
        end
    endtask

    // Compare PC and all four registers against one row of the trace.
    task automatic check_state(input logic [3:0] e_pc,
                               input logic [7:0] e0, e1, e2, e3,
                               input string label);
        check(pc === e_pc && r0 === e0 && r1 === e1 && r2 === e2 && r3 === e3,
              $sformatf("%s: got PC=%0d R0=%02h R1=%02h R2=%02h R3=%02h, expected PC=%0d R0=%02h R1=%02h R2=%02h R3=%02h",
                        label, pc, r0, r1, r2, r3, e_pc, e0, e1, e2, e3));
    endtask

    // Expected architectural state after each completed instruction.
    task automatic check_snapshot(input int index);
        case (index)
            1: check_state(1, 8'h01, 8'h00, 8'h00, 8'h00, "LDI R0,#1");
            2: check_state(2, 8'h01, 8'h02, 8'h00, 8'h00, "LDI R1,#2");
            3: check_state(3, 8'h01, 8'h02, 8'h05, 8'h00, "LDI R2,#5");
            4: check_state(4, 8'h01, 8'h02, 8'h05, 8'h06, "LDI R3,#6");
            5: check_state(5, 8'h01, 8'h02, 8'h03, 8'h06, "SUB R2,R1");
            6: check_state(6, 8'h01, 8'h03, 8'h03, 8'h06, "ADD R1,R0");
            7: check_state(7, 8'h01, 8'h03, 8'h02, 8'h06, "AND R2,R3");
            8: check_state(8, 8'h07, 8'h03, 8'h02, 8'h06, "IOR R0,R3");
            9: check_state(9, 8'h07, 8'h03, 8'h04, 8'h06, "ADD R2,R2");
            default: begin
                $error("unexpected extra instruction #%0d", index);
                errors++;
            end
        endcase
        $display("instr #%0d checked: PC=%0d R0=%02h R1=%02h R2=%02h R3=%02h",
                 index, pc, r0, r1, r2, r3);
    endtask

    logic       rst_q = 1'b1;          // reset value seen on the last rising edge
    always @(posedge clk) rst_q <= rst;

    logic [2:0] prev_state;
    logic [3:0] prev_pc;
    logic [7:0] prev_r0, prev_r1, prev_r2, prev_r3;

    always @(negedge clk) begin
        if (rst_q) begin
            check(pc === 0 && r0 === 0 && r1 === 0 && r2 === 0 && r3 === 0 &&
                  halted === 1'b0 && illegal_instr === 1'b0 && state === S_FETCH,
                  "reset clears PC, R0-R3, halted, illegal_instr; FSM in FETCH");
            retired = 0;
        end else begin
            // Instruction acquisition from the synchronous ROM.
            if (state === S_DECODE)
                check(ir === rom_copy[pc],
                      $sformatf("IR=%02h in DECODE, expected ROM[%0d]=%02h",
                                ir, pc, rom_copy[pc]));

            // No register writes except on the edge that leaves WB
            // (covers FETCH, IR, DECODE, EXEC, INC, and HALT).
            if (prev_state !== S_WB)
                check({r0, r1, r2, r3} === {prev_r0, prev_r1, prev_r2, prev_r3},
                      $sformatf("register write on the edge leaving state %0d", prev_state));

            // PC may change only on the edge that leaves INC.
            if (prev_state !== S_INC)
                check(pc === prev_pc,
                      $sformatf("PC changed on the edge leaving state %0d", prev_state));

            // A completed instruction: the PC advanced on the INC edge.
            if (prev_state === S_INC) begin
                retired++;
                check_snapshot(retired);
            end
        end

        prev_state = state;
        prev_pc    = pc;
        {prev_r0, prev_r1, prev_r2, prev_r3} = {r0, r1, r2, r3};
    end
// Testing sequence
    initial begin
        // Synchronous reset for three clocks, released on a falling edge.
        repeat (3) @(negedge clk);
        rst = 1'b0;

        // Run until HALT, with an explicit timeout.
        begin : wait_for_halt
            int c;
            c = 0;
            while (c < TIMEOUT && halted !== 1'b1) begin
                @(negedge clk);
                c++;
            end
        end
        check(halted === 1'b1, "CPU halted within the timeout");

        // Final state at HALT.
        check(retired == N_RETIRE,
              $sformatf("%0d instructions completed, expected %0d", retired, N_RETIRE));
        check(state === S_HALT, "controller in HALT state");
        check(illegal_instr === 1'b0, "normal HALT: illegal_instr = 0");
        check(ir === 8'hE0, "IR holds the HALT instruction");
        check_state(9, 8'h07, 8'h03, 8'h04, 8'h06, "final state at HALT");

        // debug_sel / debug_reg selector.
        for (int i = 0; i < 4; i++) begin
            sel = i[1:0];
            #1;
            check(selected === (i == 0 ? r0 : i == 1 ? r1 : i == 2 ? r2 : r3),
                  $sformatf("debug_sel=%0d selects the right register", i));
        end
        sel = 2'd0;

        // Everything must hold for at least 10 clocks after HALT.
        repeat (12) begin
            @(negedge clk);
            check(halted === 1'b1 && illegal_instr === 1'b0,
                  "status flags hold after HALT");
            check_state(9, 8'h07, 8'h03, 8'h04, 8'h06, "state holds after HALT");
        end

        if (errors == 0)
            $display("PASS: program_lindsey_10 -- %0d instructions, all checks passed", retired);
        else
            $fatal(1, "FAIL: program_lindsey_10 (%0d errors)", errors);
        $finish;
    end

    // Global watchdog: the simulation can never hang.
    initial begin
        #10us;
        $fatal(1, "FAIL: global simulation timeout");
    end
endmodule