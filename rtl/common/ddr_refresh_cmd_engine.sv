// ddr_refresh_cmd_engine.sv
// Refresh/Command Engine: auto-refresh, ZQ calibration hooks, command issue arbiter (scaffold)
// SPDX-License-Identifier: Apache-2.0

`include "ddr_defines.svh"

module ddr_refresh_cmd_engine
  import ddr_types_pkg::*;
  #(parameter int tREFI_CYC     = 7800, // per JEDEC at given freq (placeholder)
    parameter int tRFC_CYC      = 350,  // refresh cycle time
    parameter int CMD_FIFO_DEPTH= 16)
  (
    input  logic       clk,
    input  logic       rst_n,
    // Command inputs from scheduler
    input  logic       in_valid,
    output logic       in_ready,
    input  ddr_cmd_t   in_cmd,
    // Output to protocol layer/DFI
    output logic       out_valid,
    input  logic       out_ready,
    output ddr_cmd_t   out_cmd,
    // Status
    output logic       in_refresh,
    output logic       zqcal_req
  );

  // Refresh timer
  logic [$clog2(tREFI_CYC+1)-1:0] refi_cnt_q;
  logic                           refi_expired;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      refi_cnt_q <= '0;
    end else if (refi_cnt_q == tREFI_CYC[$bits(refi_cnt_q)-1:0]) begin
      refi_cnt_q <= '0;
    end else begin
      refi_cnt_q <= refi_cnt_q + 1'b1;
    end
  end

  assign refi_expired = (refi_cnt_q == tREFI_CYC[$bits(refi_cnt_q)-1:0]);

  // Simple arbiter: refresh takes priority when expired
  typedef enum logic [1:0] {IDLE, ISSUE_SCHED, ISSUE_REF, BLOCKED} st_e;
  st_e st_q, st_d;
  logic [$clog2(tRFC_CYC+1)-1:0] rfc_cnt_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st_q <= IDLE; rfc_cnt_q <= '0;
    end else begin
      st_q <= st_d;
      if (st_q == ISSUE_REF && out_valid && out_ready) rfc_cnt_q <= tRFC_CYC[$bits(rfc_cnt_q)-1:0];
      else if (rfc_cnt_q != '0) rfc_cnt_q <= rfc_cnt_q - 1'b1;
    end
  end

  always_comb begin
    st_d = st_q;
    unique case (st_q)
      IDLE:        st_d = refi_expired ? ISSUE_REF : (in_valid ? ISSUE_SCHED : IDLE);
      ISSUE_SCHED: st_d = (out_valid && out_ready) ? IDLE : ISSUE_SCHED;
      ISSUE_REF:   st_d = (out_valid && out_ready) ? BLOCKED : ISSUE_REF;
      BLOCKED:     st_d = (rfc_cnt_q == '0) ? IDLE : BLOCKED;
      default:     st_d = IDLE;
    endcase
  end

  // Outputs
  assign in_ready   = (st_q == ISSUE_SCHED) && out_ready;
  assign out_valid  = (st_q == ISSUE_SCHED && in_valid) || (st_q == ISSUE_REF);
  assign out_cmd    = (st_q == ISSUE_REF) ? '{opcode:`DDR_CMD_REFRESH, default:'0} : in_cmd;
  assign in_refresh = (st_q == ISSUE_REF) || (st_q == BLOCKED);
  assign zqcal_req  = 1'b0; // TODO: trigger per interval or CSR

endmodule : ddr_refresh_cmd_engine
