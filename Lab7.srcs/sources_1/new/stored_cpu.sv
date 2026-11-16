// Day 15: connect a hardware instruction controller to the Day 14 datapath.
module stored_cpu #(
    parameter MEM_FILE = "program_5.mem"
)(
    input  logic       clk,
    input  logic       rst,
    input  logic [1:0] debug_sel,
    output logic [7:0] debug_reg,
    output logic [3:0] debug_pc,
    output logic [7:0] debug_ir,
    output logic [2:0] debug_state,
    output logic       halted,
    output logic       illegal_instr,
    output logic [7:0] debug_r0,
    output logic [7:0] debug_r1,
    output logic [7:0] debug_r2,
    output logic [7:0] debug_r3
);
    // All SIX control signals from the Day 15 controller.
    logic rom_en, ir_en, alu_result_en, reg_wr_en, pc_en, wb_sel_imm;

    // Decoded instruction classes returned by the Day 14 datapath.
    logic is_rtype, is_ldi, is_halt, is_valid;

    // Internal debug / datapath observation signals.
    logic [7:0] rom_data, operand_a, operand_b, alu_y, alu_q, wb_data;
    logic [2:0] opcode, imm3;
    logic [1:0] rd, rs, alu_op;

    // Day 14 datapath.
    cpu_datapath #(.MEM_FILE(MEM_FILE)) u_datapath (
        .clk(clk), .rst(rst),
        .rom_en(rom_en), .ir_en(ir_en),
        .alu_result_en(alu_result_en),
        .reg_wr_en(reg_wr_en), .pc_en(pc_en),
        .wb_sel_imm(wb_sel_imm),
        .pc(debug_pc), .rom_data(rom_data), .ir(debug_ir),
        .opcode(opcode), .rd(rd), .rs(rs), .imm3(imm3),
        .is_rtype(is_rtype), .is_ldi(is_ldi),
        .is_halt(is_halt), .is_valid(is_valid),
        .alu_op(alu_op), .operand_a(operand_a), .operand_b(operand_b),
        .alu_y(alu_y), .alu_q(alu_q), .wb_data(wb_data),
        .r0(debug_r0), .r1(debug_r1),
        .r2(debug_r2), .r3(debug_r3)
    );

    // TODO 10: Instantiate stored_cpu_controller here.
    stored_cpu_controller u_controller (
        .clk(clk), .rst(rst),
        .is_rtype(is_rtype), .is_ldi(is_ldi),
        .is_halt(is_halt), .is_valid(is_valid),
        .rom_en(rom_en), .ir_en(ir_en),
        .alu_result_en(alu_result_en), .reg_wr_en(reg_wr_en),
        .pc_en(pc_en), .wb_sel_imm(wb_sel_imm),
        .halted(halted), .illegal_instr(illegal_instr),
        .dbg_state(debug_state)
    );


    // External selection of the four architectural registers.
    always_comb begin
        case (debug_sel)
            2'd0: debug_reg = debug_r0;
            2'd1: debug_reg = debug_r1;
            2'd2: debug_reg = debug_r2;
            2'd3: debug_reg = debug_r3;
            default: debug_reg = 8'h00;
        endcase
    end
endmodule
