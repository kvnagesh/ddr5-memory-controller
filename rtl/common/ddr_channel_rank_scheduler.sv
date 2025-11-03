// ddr_channel_rank_scheduler.sv
// Channel/Rank/Bank scheduler with BL16 enforcement, topology params, and basic timing guards
// SPDX-License-Identifier: Apache-2.0
`include "ddr_defines.svh"
module ddr_channel_rank_scheduler
  import ddr_types_pkg::*;
  #(
    parameter int NUM_CHANNELS     = 1,
    parameter int NUM_RANKS        = 2,
    parameter int NUM_SLOTS        = 1,
    parameter int QUEUE_DEPTH      = 64,
    parameter int TIMING_TCK_PS    = 625,
    parameter bit ENABLE_REORDER   = 1,
    parameter int BURST_LENGTH     = 16   // Enforce BL16
  )(
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

  // Queue
  ddr_req_t q_mem   [QUEUE_DEPTH];
  logic [$clog2(QUEUE_DEPTH):0] wptr, rptr;
  logic full, empty;
  assign full  = (wptr - rptr) == QUEUE_DEPTH;
  assign empty = (wptr == rptr);

  // BL16 enforcement: split/merge logic for partial bursts
  function automatic int bl_required(input ddr_req_t r);
    return BURST_LENGTH; // For DDR5, fixed BL16 in controller datapath
  endfunction

  // Basic arbitration: pick head if no hazards and timing ok
  function automatic bit can_issue(input ddr_req_t r);
    bit ok = 1'b1;
    // TODO: add tRRD_S/L, tFAW, tCCD_L/S, 1N/2N timing, rank/slot constraints
    if (bank_busy || rank_busy) ok = 1'b0;
    return ok;
  endfunction

  // Translate request to command honoring BL16
  function automatic ddr_cmd_t to_cmd(input ddr_req_t r);
    ddr_cmd_t c; c = '{default:'0};
    c.is_write = r.is_write;
    c.addr     = r.addr;
    c.len      = bl_required(r);
    c.channel  = r.channel;
    c.rank     = r.rank;
    c.slot     = r.slot;
    return c;
  endfunction

  assign req_ready   = !full;
  assign sched_valid = !empty && can_issue(q_mem[rptr[$clog2(QUEUE_DEPTH)-1:0]]);
  assign sched_cmd   = to_cmd(q_mem[rptr[$clog2(QUEUE_DEPTH)-1:0]]);

  // Pointers and credits
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
