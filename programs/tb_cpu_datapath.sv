`timescale 1ns/1ps
module tb_cpu_datapath;
    logic clk=1'b0;
    logic rst;
    logic rom_en, ir_en, alu_result_en, reg_wr_en, pc_en, wb_sel_imm;
    wire [3:0] pc;
    wire [7:0] rom_data,ir,operand_a,operand_b,alu_y,alu_q,wb_data;
    wire [7:0] r0,r1,r2,r3;
    wire [2:0] opcode,imm3;
    wire [1:0] rd,rs,alu_op;
    wire is_rtype,is_ldi,is_halt,is_valid;
    integer errors=0;

    always #5 clk=~clk;

    cpu_datapath #(.MEM_FILE("program_5.mem")) dut(
        .clk(clk),.rst(rst),
        .rom_en(rom_en),.ir_en(ir_en),
        .alu_result_en(alu_result_en),.reg_wr_en(reg_wr_en),
        .pc_en(pc_en),.wb_sel_imm(wb_sel_imm),
        .pc(pc),.rom_data(rom_data),.ir(ir),
        .opcode(opcode),.rd(rd),.rs(rs),.imm3(imm3),
        .is_rtype(is_rtype),.is_ldi(is_ldi),
        .is_halt(is_halt),.is_valid(is_valid),.alu_op(alu_op),
        .operand_a(operand_a),.operand_b(operand_b),
        .alu_y(alu_y),.alu_q(alu_q),.wb_data(wb_data),
        .r0(r0),.r1(r1),.r2(r2),.r3(r3)
    );

    task automatic clear_controls;
        begin
            rom_en=0;ir_en=0;alu_result_en=0;
            reg_wr_en=0;pc_en=0;wb_sel_imm=0;
        end
    endtask

    task automatic check8(input [7:0] actual, input [7:0] expected,
                          input string description);
        if (actual !== expected) begin
            $error("%s: expected %02h got %02h",description,expected,actual);
            errors=errors+1;
        end
    endtask

    task automatic check4(input [3:0] actual, input [3:0] expected,
                          input string description);
        if (actual !== expected) begin
            $error("%s: expected %01h got %01h",description,expected,actual);
            errors=errors+1;
        end
    endtask

    // Assert exactly one control for exactly one rising edge.
    // Controls return low afterward, so no unintended second writes occur.
    task automatic step(input int which);
        begin
            @(negedge clk);
            clear_controls();
            case(which)
                0: rom_en=1;
                1: ir_en=1;
                2: alu_result_en=1;
                3: reg_wr_en=1;
                4: pc_en=1;
                5: begin reg_wr_en=1;wb_sel_imm=1;end
                default: $fatal(1,"invalid step");
            endcase
            @(posedge clk);
            #1;
            @(negedge clk);
            clear_controls();
            #1;
        end
    endtask

    task automatic fetch_decode(input [3:0] expected_pc,
                                input [7:0] expected_ir);
        reg [7:0] previous_ir;
        begin
            check4(pc,expected_pc,"PC before FETCH");
            previous_ir=ir;
            step(0); // FETCH: ROM output updates on a rising edge
            check8(rom_data,expected_ir,"synchronous ROM output");
            check8(ir,previous_ir,"IR must hold until its own enable");
            step(1); // IR capture on a LATER rising edge
            check8(ir,expected_ir,"instruction register");
            if (!is_valid) begin
                $error("Program contains an invalid instruction at %0d",pc);
                errors=errors+1;
            end
        end
    endtask

    task automatic increment_pc(input [3:0] expected_next);
        begin
            step(4);
            check4(pc,expected_next,"PC after increment");
        end
    endtask

    initial begin
        clear_controls();
        rst=1;
        repeat(2) @(posedge clk);
        #1;
        check4(pc,0,"PC reset");
        check8(ir,0,"IR reset");
        check8(r0,0,"R0 reset");
        check8(r1,0,"R1 reset");
        check8(r2,0,"R2 reset");
        check8(r3,0,"R3 reset");
        @(negedge clk); rst=0;

        // LDI R0,#2 (C2): immediate path bypasses the ALU.
        fetch_decode(4'd0,8'hC2);
        if (!is_ldi || rd!=0 || imm3!=2) $fatal(1,"LDI decode mismatch");
        step(5);
        check8(r0,8'd2,"LDI R0,#2");
        check8(r1,8'd0,"R1 must hold on R0 write");
        increment_pc(4'd1);

        // LDI R1,#3 (CB).
        fetch_decode(4'd1,8'hCB);
        if (!is_ldi || rd!=1 || imm3!=3) $fatal(1,"LDI R1 decode mismatch");
        step(5);
        check8(r0,8'd2,"R0 must hold on R1 write");
        check8(r1,8'd3,"LDI R1,#3");
        increment_pc(4'd2);

        // ADD R0,R1 (02). Combinational operand reads and ALU output
        // are captured in an explicit ALU-result register on EXEC.
        fetch_decode(4'd2,8'h02);
        if (!is_rtype || rd!=0 || rs!=1 || alu_op!=0)
            $fatal(1,"ADD decode mismatch");
        check8(operand_a,8'd2,"ADD operand A");
        check8(operand_b,8'd3,"ADD operand B");
        check8(alu_y,8'd5,"ADD combinational ALU");
        step(2);
        check8(alu_q,8'd5,"ADD ALU result registered");
        check8(r0,8'd2,"R0 holds before WB");
        step(3);
        check8(r0,8'd5,"ADD writeback");
        increment_pc(4'd3);

        // AND R0,R1 (42), reusing Day 5 op_block hardware.
        fetch_decode(4'd3,8'h42);
        if (!is_rtype || rd!=0 || rs!=1 || alu_op!=2)
            $fatal(1,"AND decode mismatch");
        check8(operand_a,8'd5,"AND operand A");
        check8(operand_b,8'd3,"AND operand B");
        check8(alu_y,8'd1,"AND combinational ALU");
        step(2);
        check8(alu_q,8'd1,"AND ALU result registered");
        step(3);
        check8(r0,8'd1,"AND writeback");
        increment_pc(4'd4);

        // HALT (E0). The controller is not part of Day 14.
        // No writeback or PC advance is requested here.
        fetch_decode(4'd4,8'hE0);
        if (!is_halt || !is_valid) $fatal(1,"HALT decode mismatch");
        repeat(3) @(posedge clk);
        #1;
        check4(pc,4'd4,"PC holds at HALT");
        check8(r0,8'd1,"final R0");
        check8(r1,8'd3,"final R1");
        check8(r2,8'd0,"final R2");
        check8(r3,8'd0,"final R3");

        if(errors==0) $display("PASS: Day 14 CPU datapath -- 5 instructions");
        else $fatal(1,"FAIL: %0d datapath checks failed",errors);
        $finish;
    end
endmodule
