// ddr_channel_rank_scheduler.sv
// Channel/Rank Scheduler: bank/rank interleave, reordering, timing guardrails (scaffold)
// SPDX-License-Identifier: Apache-2.0

`include "ddr_defines.svh"

module ddr_channel_rank_scheduler
  import ddr_types_pkg::*;
  #(parameter int NUM_CHANNELS     = 1,
    parameter int NUM_RANKS        = 2,
    parameter int QUEUE_DEPTH      = 32,
    parameter int TIMING_TCK_PS    = 625,
    parameter bit ENABLE_REORDER   = 1)
  (
    input  logic           clk,
    input  logic           rst_n,
    // Incoming requests from AXI front-end
    input  logic           req_valid,
    output logic           req_ready,
    input  ddr_req_t       req,
    // Scheduled commands out to protocol layer
    output logic           sched_valid,
    input  logic           sched_ready,
    output ddr_cmd_t       sched_cmd,
    // Hazard feedback from protocol layer
    input  logic           bank_busy,
    input  logic           rank_busy,
    // Stats/QoS hooks
    output logic [15:0]    rd_wrr_credit,
    output logic [15:0]    wr_wrr_credit
  );

  // Simple queue placeholders
  ddr_req_t q_mem   [QUEUE_DEPTH];
  logic [$clog2(QUEUE_DEPTH):0] wptr, rptr;
  logic full, empty;

  assign full  = (wptr - rptr) == QUEUE_DEPTH;
  assign empty = (wptr == rptr);

  assign req_ready   = !full;
  assign sched_valid = !empty;
  assign sched_cmd   = '{default:'0}; // TODO: translate selected req to cmd respecting timing

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wptr <= '0; rptr <= '0; rd_wrr_credit <= '0; wr_wrr_credit <= '0;
    end else begin
      if (req_valid && req_ready) begin
        q_mem[wptr[$clog2(QUEUE_DEPTH)-1:0]] <= req;
        wptr <= wptr + 1'b1;
      end
      if (sched_valid && sched_ready) begin
        rptr <= rptr + 1'b1;
      end
    end
  end

endmodule : ddr_channel_rank_scheduler
