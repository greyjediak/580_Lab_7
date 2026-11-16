`timescale 1ns/1ps
// uses eq1 to check if a and b are equal when a and b have multiple N bits
module eqN #(
    parameter int N = 8
)(
    input  logic [N-1:0] a,
    input  logic [N-1:0] b,
    output logic         eq
);

    logic [N-1:0] bit_eq;

    for (genvar i = 0; i < N; i++) begin : g_eq
        eq1 u_eq (.a(a[i]),.b(b[i]),.eq(bit_eq[i]));
    end

    assign eq = &bit_eq;

endmodule
