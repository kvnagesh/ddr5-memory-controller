// ddr5_protocol_layer.sv
// Top-level protocol layer handling DDR5/LPDDR5X command translation and DFI interface
// Copyright (c) 2025
// SPDX-License-Identifier: Apache-2.0

`include "ddr_defines.svh"

package ddr5_pl_pkg;
  typedef enum logic [1:0] {PHY_IF_DFI=2'b00, PHY_IF_CUSTOM=2'b01} phy_if_e;
endpackage

interface dfi_if
  #(parameter int DFI_FREQ_RATIO = 2,
    parameter int DFI_DATA_BYTES = 16,
    parameter int DFI_CMD_WIDTH  = 32,
    parameter int DFI_ADDR_WIDTH = 24,
    parameter int DFI_BANK_WIDTH = 4);
  logic                      clk;
  logic                      rst_n;
  // Command/Address
  logic [DFI_ADDR_WIDTH-1:0] ca_addr;
  logic [DFI_BANK_WIDTH-1:0] ca_bank;
  logic [DFI_CMD_WIDTH-1:0]  cmd;
  logic                      cmd_valid;
  logic                      cmd_ready;
  // Write data
  logic [DFI_DATA_BYTES*8-1:0] wr_data;
  logic                        wr_valid;
  logic                        wr_ready;
  // Read data
  logic [DFI_DATA_BYTES*8-1:0] rd_data;
  logic                        rd_valid;
  logic                        rd_ready;
  // Status
  logic                        phy_up;
  modport ctrl (input clk, rst_n, rd_data, rd_valid, cmd_ready, wr_ready, phy_up,
                output ca_addr, ca_bank, cmd, cmd_valid, wr_data, wr_valid, rd_ready);
  modport phy  (input clk, rst_n, ca_addr, ca_bank, cmd, cmd_valid, wr_data, wr_valid, rd_ready,
                output rd_data, rd_valid, cmd_ready, wr_ready, phy_up);
endinterface : dfi_if

module ddr5_protocol_layer
  import ddr_types_pkg::*;
  import ddr5_pl_pkg::*;
  #(parameter string MEM_STD           = "DDR5",       // "DDR5" or "LPDDR5X"
    parameter phy_if_e PHY_IF          = PHY_IF_DFI,
    parameter int      ADDR_WIDTH      = 34,
    parameter int      BANK_WIDTH      = 4,
    parameter int      ROW_WIDTH       = 18,
    parameter int      COL_WIDTH       = 12,
    parameter int      DATA_BYTES      = 16,
    parameter int      DFI_FREQ_RATIO  = 2,
    parameter int      TIMING_TCK_PS   = 625,
    parameter bit      ENABLE_ECC      = 1,
    parameter bit      ENABLE_QOS      = 1)
  (
    input  logic                         clk,
    input  logic                         rst_n,
    // Request interface from AXI front-end scheduler
    input  logic                         req_valid,
    output logic                         req_ready,
    input  ddr_req_t                     req,
    // Response back to front-end
    output logic                         rsp_valid,
    input  logic                         rsp_ready,
    output ddr_rsp_t                     rsp,
    // DFI interface to PHY
    dfi_if.ctrl                          dfi,
    // Status/CSR
    output logic                         init_done,
    output logic [7:0]                   fatal_err_code
  );

  // ---------------------------------------------------------------------------
  // Local parameters and state
  // ---------------------------------------------------------------------------
  typedef enum logic [2:0] {S_RESET, S_INIT, S_IDLE, S_ACT, S_XFER, S_PRE} state_e;
  state_e state_q, state_d;

  // Simple command queue placeholders
  logic                       cmdq_push, cmdq_pop;
  ddr_cmd_t                   cmdq_wdata, cmdq_rdata;
  logic                       cmdq_full, cmdq_empty;

  // ---------------------------------------------------------------------------
  // Initialization sequence state machine (stub)
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q <= S_RESET;
    end else begin
      state_q <= state_d;
    end
  end

  always_comb begin
    state_d = state_q;
    unique case (state_q)
      S_RESET: state_d = S_INIT;
      S_INIT:  state_d = dfi.phy_up ? S_IDLE : S_INIT;
      S_IDLE:  state_d = (req_valid && !cmdq_full) ? S_XFER : S_IDLE;
      S_XFER:  state_d = S_IDLE;
      default: state_d = S_IDLE;
    endcase
  end

  assign init_done = (state_q != S_RESET) & dfi.phy_up;

  // ---------------------------------------------------------------------------
  // Request acceptance (placeholder translating to internal cmd type)
  // ---------------------------------------------------------------------------
  assign req_ready   = (state_q == S_IDLE) && !cmdq_full;
  assign rsp_valid   = (state_q == S_XFER);
  assign rsp.id      = req.id;
  assign rsp.err     = 1'b0;

  // Simple pass-through for demo: pack write/read to DFI signals
  always_comb begin
    // Defaults
    dfi.ca_addr   = '0;
    dfi.ca_bank   = '0;
    dfi.cmd       = '0;
    dfi.cmd_valid = 1'b0;
    dfi.wr_data   = '0;
    dfi.wr_valid  = 1'b0;
    dfi.rd_ready  = rsp_ready;

    if (state_q == S_XFER) begin
      dfi.ca_addr   = req.addr[DFI_ADDR_WIDTH-1:0];
      dfi.ca_bank   = req.bank[BANK_WIDTH-1:0];
      dfi.cmd       = (req.is_write) ? `DDR_CMD_WR : `DDR_CMD_RD;
      dfi.cmd_valid = 1'b1;
      dfi.wr_data   = req.wdata[DATA_BYTES*8-1:0];
      dfi.wr_valid  = req.is_write;
    end
  end

  // Capture read data (placeholder)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rsp.rdata <= '0;
      rsp.last  <= 1'b0;
    end else if (dfi.rd_valid && rsp_ready) begin
      rsp.rdata <= dfi.rd_data;
      rsp.last  <= 1'b1;
    end else if (rsp_ready) begin
      rsp.last  <= 1'b0;
    end
  end

  // Error code placeholder
  assign fatal_err_code = 8'h00;

endmodule : ddr5_protocol_layer
