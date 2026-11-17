`timescale 1ns/1ps

module ext_cpu_decode (
    input logic [7:0] instr,
    output logic [2:0] opcode,
    output logic [1:0] rd,
    output logic [1:0] rs,
    output logic [2:0] imm3,
    output logic is_rtype,
    output logic is_ldi,
    output logic is_halt,
    output logic is_valid,
    output logic [1:0] alu_op,
    output logic is_jnz
);

    assign opcode = instr[7:5]; // first three bits are opcde
    assign rd = instr[4:3]; // destination register
    assign rs = instr[2:1]; // source register
    assign imm3 = instr[2:0]; // immediate address
    
    always_comb begin   
        is_rtype = 1'b0;
        is_ldi = 1'b0;
        is_halt = 1'b0;
        is_jnz = 1'b0;
        
        
        case (opcode)
            3'b000, 3'b001, 3'b010, 3'b011: is_rtype = 1'b1; // add, sub, and, ior
            3'b110: is_ldi = 1'b1;
            3'b111: is_halt = 1'b1;
            3'b100: is_jnz = 1'b1;
            default: ; // default
        endcase
    end // end always begin
    
    assign is_valid = is_rtype | is_ldi | is_halt | is_jnz;
    assign alu_op = is_rtype ? opcode[1:0] : 2'b00;

endmodule