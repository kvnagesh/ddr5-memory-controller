// ddr_qos_manager.sv
// QoS/Traffic management: WRR/aging, credits, per-class limits (scaffold)
// SPDX-License-Identifier: Apache-2.0

`include "ddr_defines.svh"

module ddr_qos_manager
  import ddr_types_pkg::*;
  #(parameter int NUM_CLASSES = 4,
    parameter int CREDIT_MAX  = 1024)
  (
    input  logic             clk,
    input  logic             rst_n,
    // Incoming requests with class
    input  logic             in_valid,
    output logic             in_ready,
    input  ddr_req_t         in_req,
    input  logic [1:0]       in_class,
    // Issued requests out
    output logic             out_valid,
    input  logic             out_ready,
    output ddr_req_t         out_req,
    // Stats
    output logic [15:0]      class_credit   [NUM_CLASSES]
  );

  // Simple round-robin with credits (stub)
  logic [$clog2(NUM_CLASSES)-1:0] rr_q, rr_d;
  logic [15:0] credits_q [NUM_CLASSES];

  assign in_ready  = out_ready; // backpressure tie-off for scaffold
  assign out_valid = in_valid;  // pass-through selection for scaffold
  assign out_req   = in_req;

  // Credits maintenance (placeholder)
  genvar i;
  generate for (i=0;i<NUM_CLASSES;i++) begin : g_credit
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) credits_q[i] <= CREDIT_MAX[15:0];
      else if (in_valid && out_ready && (in_class==i[1:0]) && (credits_q[i] != '0))
        credits_q[i] <= credits_q[i] - 1'b1;
      else if (credits_q[i] == '0)
        credits_q[i] <= CREDIT_MAX[15:0];
    end
    assign class_credit[i] = credits_q[i];
  end endgenerate

  // RR pointer (not used heavily in scaffold)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) rr_q <= '0; else if (out_valid && out_ready) rr_q <= rr_q + 1'b1;
  end
  assign rr_d = rr_q;

endmodule : ddr_qos_manager
