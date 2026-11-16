`timescale 1ns/1ps
module tb_cpu_decode;
    logic [7:0] instr;
    logic [2:0] opcode, imm3;
    logic [1:0] rd, rs, alu_op;
    logic is_rtype, is_ldi, is_halt, is_valid;
    int errors = 0;

    cpu_decode dut (
        .instr(instr),
        .opcode(opcode), .rd(rd), .rs(rs), .imm3(imm3),
        .is_rtype(is_rtype), .is_ldi(is_ldi),
        .is_halt(is_halt), .is_valid(is_valid),
        .alu_op(alu_op)
    );

    task automatic check_byte(input logic [7:0] value);
        logic [2:0] expected_op;
        logic expected_r, expected_l, expected_h, expected_v;
        logic [1:0] expected_alu;
        begin
            instr = value;
            #1; // allow purely combinational logic to settle
            expected_op  = value[7:5];
            expected_r   = (expected_op <= 3'b011);
            expected_l   = (expected_op == 3'b110);
            expected_h   = (expected_op == 3'b111);
            expected_v   = expected_r || expected_l || expected_h;
            expected_alu = expected_r ? expected_op[1:0] : 2'b00;

            if (opcode !== expected_op || rd !== value[4:3] ||
                rs !== value[2:1] || imm3 !== value[2:0] ||
                is_rtype !== expected_r || is_ldi !== expected_l ||
                is_halt !== expected_h || is_valid !== expected_v ||
                alu_op !== expected_alu) begin
                $error("decode mismatch at instr=%02h: op=%b rd=%b rs=%b imm3=%b R/L/H/V=%b%b%b%b ALU=%b",
                    value, opcode, rd, rs, imm3,
                    is_rtype, is_ldi, is_halt, is_valid, alu_op);
                errors++;
            end
        end
    endtask

    initial begin
        instr = 8'h00;
        // Worked program and two reserved opcodes.
        check_byte(8'hC2); // LDI R0,#2
        check_byte(8'hCB); // LDI R1,#3
        check_byte(8'h02); // ADD R0,R1
        check_byte(8'h42); // AND R0,R1
        check_byte(8'hE0); // HALT
        check_byte(8'h80); // reserved 100
        check_byte(8'hA0); // reserved 101

        // Stretch test: every possible instruction byte.
        for (int i=0; i<256; i++) begin
            check_byte(i[7:0]);
        end

        if (errors == 0)
            $display("PASS: cpu_decode (all 256 instruction bytes)");
        else
            $display("FAIL: cpu_decode (%0d mismatches)",errors);
        $finish;
    end
endmodule
