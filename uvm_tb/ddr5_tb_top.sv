// ddr5_tb_top.sv - Top-level UVM testbench for DDR5 Memory Controller
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

`include "ddr5_test_pkg.sv"

module ddr5_tb_top;

  // Clock and reset generation
  bit clk_axi;
  bit clk_dfi;
  bit rst_n;

  // Clock generation (configurable via plusargs)
  initial begin
    clk_axi = 0;
    forever #2.5 clk_axi = ~clk_axi; // 200 MHz example
  end

  initial begin
    clk_dfi = 0;
    forever #1 clk_dfi = ~clk_dfi;   // 500 MHz example
  end

  initial begin
    rst_n = 0;
    repeat (10) @(posedge clk_axi);
    rst_n = 1;
  end

  // Interfaces
  // AXI virtual interface to DUT
  // Replace widths to match RTL config
  interface axi_if(input bit ACLK, input bit ARESETn);
    // Write address channel
    logic [31:0]  AWADDR;
    logic [7:0]   AWLEN;
    logic [2:0]   AWSIZE;
    logic [1:0]   AWBURST;
    logic         AWVALID;
    logic         AWREADY;
    // Write data channel
    logic [511:0] WDATA;
    logic [63:0]  WSTRB;
    logic         WLAST;
    logic         WVALID;
    logic         WREADY;
    // Write response
    logic [1:0]   BRESP;
    logic         BVALID;
    logic         BREADY;
    // Read address
    logic [31:0]  ARADDR;
    logic [7:0]   ARLEN;
    logic [2:0]   ARSIZE;
    logic [1:0]   ARBURST;
    logic         ARVALID;
    logic         ARREADY;
    // Read data
    logic [511:0] RDATA;
    logic [1:0]   RRESP;
    logic         RLAST;
    logic         RVALID;
    logic         RREADY;
  endinterface

  axi_if axi_vif(.ACLK(clk_axi), .ARESETn(rst_n));

  // DFI interface (abstracted for checker/monitor)
  interface dfi_if(input bit DFI_CLK, input bit DFI_RESETn);
    logic        dfi_init_start;
    logic        dfi_init_complete;
    logic [3:0]  dfi_cmd;
    logic [15:0] dfi_addr;
    logic [7:0]  dfi_bank;
    logic        dfi_cs_n;
    logic        dfi_cke;
    logic        dfi_odt;
    logic [511:0] dfi_wrdata;
    logic        dfi_wrdata_en;
    logic        dfi_rddata_valid;
    logic [511:0] dfi_rddata;
    logic        dfi_alert_n;
  endinterface

  dfi_if dfi_vif(.DFI_CLK(clk_dfi), .DFI_RESETn(rst_n));

  // Instantiate DUT here (placeholder)
  // ddr5_controller dut (... connect to axi_vif and dfi_vif ...);

  // Run UVM
  initial begin
    uvm_config_db#(virtual axi_if)::set(null, "*", "vif_axi", axi_vif);
    uvm_config_db#(virtual dfi_if)::set(null, "*", "vif_dfi", dfi_vif);
    run_test();
  end

endmodule : ddr5_tb_top
