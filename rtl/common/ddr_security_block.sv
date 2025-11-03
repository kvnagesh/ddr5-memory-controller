// ddr_security_block.sv
// Security/Encryption Block: AES logic stub, key masking, scrub hooks (scaffold)
// SPDX-License-Identifier: Apache-2.0

`include "ddr_defines.svh"

module ddr_security_block
  import ddr_types_pkg::*;
  #(parameter int DATA_BYTES   = 16,
    parameter bit ENABLE_AES   = 1,
    parameter bit ENABLE_MASK  = 1)
  (
    input  logic                     clk,
    input  logic                     rst_n,
    // Stream in from AXI/ECC
    input  logic                     in_valid,
    output logic                     in_ready,
    input  logic [DATA_BYTES*8-1:0]  in_data,
    input  logic                     in_is_write,
    // Stream out to protocol
    output logic                     out_valid,
    input  logic                     out_ready,
    output logic [DATA_BYTES*8-1:0]  out_data,
    // Key and control
    input  logic [127:0]             aes_key,
    input  logic                     key_valid,
    input  logic [127:0]             mask_seed,
    input  logic                     bypass
  );

  // Simple ready/valid pass-through
  assign in_ready  = out_ready;
  assign out_valid = in_valid;

  // Masking PRNG stub
  function automatic [DATA_BYTES*8-1:0] prng(input logic [127:0] seed, input logic [31:0] ctr);
    prng = {DATA_BYTES*8{1'b0}} ^ {seed, seed} >> (ctr[4:0]);
  endfunction

  // AES stub (non-cryptographic placeholder)
  function automatic [127:0] aes128_enc_stub(input logic [127:0] d, input logic [127:0] k);
    return d ^ k; // TODO: integrate real AES core
  endfunction

  logic [31:0] ctr_q;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) ctr_q <= '0; else if (in_valid & out_ready) ctr_q <= ctr_q + 32'd1;
  end

  logic [DATA_BYTES*8-1:0] data_t;
  always_comb begin
    data_t = in_data;
    if (!bypass) begin
      if (ENABLE_MASK) data_t ^= prng(mask_seed, ctr_q);
      if (ENABLE_AES) begin
        // Block-wise operate on low 128b only for scaffold
        data_t[127:0] = aes128_enc_stub(data_t[127:0], aes_key);
      end
    end
  end

  assign out_data = data_t;

endmodule : ddr_security_block
