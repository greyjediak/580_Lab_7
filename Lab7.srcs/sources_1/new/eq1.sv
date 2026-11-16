`timescale 1ns/1ps
// used by eqN
module eq1 (
  input  logic a,
  input  logic b,
  output logic eq
);

  assign eq = ~(a ^ b);

endmodule
