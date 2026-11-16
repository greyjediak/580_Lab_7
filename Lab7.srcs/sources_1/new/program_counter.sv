`timescale 1ns/1ps

module program_counter #(
  parameter int WIDTH = 4
)(
  input  logic             clk,
  input  logic             rst,
  input  logic             en,
  input  logic             take_branch,
  input  logic [WIDTH-1:0] branch_target,
  output logic [WIDTH-1:0] pc
);

  logic [WIDTH-1:0] pc_next;

  // --------------------------------------------------------
  // Next-state logic
  // --------------------------------------------------------

  assign pc_next = take_branch ? branch_target : pc + 1;

  // --------------------------------------------------------
  // State register
  // --------------------------------------------------------

  regN #(
    .WIDTH(WIDTH)
  ) u_pc_reg (
    .clk (clk),
    .rst (rst),
    .en  (en),
    .d   (pc_next),
    .q   (pc)
  );

endmodule
