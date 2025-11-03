//==============================================================================
// File: ddr5_refresh_dbi_ca_parity.sv
// Description: DDR5 refresh engines (per-bank, same-bank, FGR), DBI/DM lane
//              handling, CA parity generation/check, and bus features.
//==============================================================================

module ddr5_refresh_dbi_ca_parity #(
  parameter int NUM_RANKS = 2,
  parameter int NUM_BANKS = 32,
  parameter int tREFI     = 7800,    // nominal 7.8us in cycles @1MHz placeholder
  parameter int tRFC_PB   = 160,
  parameter int tRFC_SB   = 120,
  parameter int tRFC_AB   = 350,
  parameter int FGR_LEVELS= 4
) (
  input  logic clk,
  input  logic rst_n,

  // Control/config
  input  logic        cfg_en_refresh,
  input  logic        cfg_en_fgr,
  input  logic [1:0]  cfg_fgr_ratio,     // 1/2/4/8x
  input  logic        cfg_en_ca_parity,
  input  logic        cfg_en_dbi_rd,
  input  logic        cfg_en_dbi_wr,

  // Scheduler handshake
  output logic        ref_req_valid,
  input  logic        ref_req_ready,
  output logic [1:0]  ref_type,         // 0:all-bank, 1:per-bank, 2:same-bank, 3:FGR tick
  output logic [4:0]  ref_bank,
  output logic [2:0]  ref_bg,
  output logic        ref_rank,

  // PHY-side CA parity/DBI/DM
  input  logic [15:0] ca_bus_in,
  output logic [15:0] ca_bus_out,
  output logic        ca_parity,
  input  logic        ca_parity_in,
  output logic [71:0] dq_out_dbi_wr,    // example width: 64b + 8 DM/DBI bits
  input  logic [71:0] dq_in_dbi_rd,
  output logic [7:0]  dm_out,

  // Error/status/telemetry
  output logic [31:0] cnt_ref_ab,
  output logic [31:0] cnt_ref_pb,
  output logic [31:0] cnt_ref_sb,
  output logic [31:0] cnt_fgr_ticks,
  output logic        ca_parity_err
);

  //======================== Refresh timers ========================
  logic [31:0] refi_cnt;
  logic fgr_tick;

  // FGR divider
  logic [2:0] fgr_div;
  always_comb begin
    case (cfg_fgr_ratio)
      2'd0: fgr_div = 3'd1; // x1
      2'd1: fgr_div = 3'd2; // x2
      2'd2: fgr_div = 3'd4; // x4
      default: fgr_div = 3'd8; // x8
    endcase
  end

  logic [7:0] fgr_cnt;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin fgr_cnt <= '0; fgr_tick <= 1'b0; end
    else if (cfg_en_fgr) begin
      if (fgr_cnt == (fgr_div-1)) begin fgr_cnt <= '0; fgr_tick <= 1'b1; end
      else begin fgr_cnt <= fgr_cnt + 1'b1; fgr_tick <= 1'b0; end
    end else begin
      fgr_cnt <= '0; fgr_tick <= 1'b0;
    end
  end

  // Main tREFI counter
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) refi_cnt <= '0;
    else if (!cfg_en_refresh) refi_cnt <= '0;
    else if (refi_cnt == (tREFI-1)) refi_cnt <= '0;
    else refi_cnt <= refi_cnt + 1'b1;
  end

  // Simple bank round-robin for PB/SB
  logic [4:0] rr_bank;
  logic [2:0] rr_bg;
  logic       rr_rank;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin rr_bank <= '0; rr_bg <= '0; rr_rank <= '0; end
    else if (ref_req_valid && ref_req_ready) begin
      if (rr_bank == (NUM_BANKS-1)) begin rr_bank <= '0; rr_bg <= rr_bg + 1'b1; rr_rank <= rr_rank ^ 1'b1; end
      else rr_bank <= rr_bank + 1'b1;
    end
  end

  // Issue policy: alternate AB and PB/SB, include FGR tick notifications
  typedef enum logic [1:0] {REF_AB=2'd0, REF_PB=2'd1, REF_SB=2'd2, REF_FGR=2'd3} ref_e;
  logic want_ab;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) want_ab <= 1'b1;
    else if (ref_req_valid && ref_req_ready) want_ab <= ~want_ab;
  end

  logic due_ref, due_pb, due_sb;
  assign due_ref = cfg_en_refresh && (refi_cnt == (tREFI-1));
  assign due_pb  = due_ref; // allow config expansion later
  assign due_sb  = 1'b0;    // placeholder for same-bank targeted refresh

  always_comb begin
    ref_req_valid = 1'b0; ref_type = REF_AB; ref_bank = rr_bank; ref_bg = rr_bg; ref_rank = rr_rank;
    if (fgr_tick) begin
      ref_req_valid = 1'b1; ref_type = REF_FGR;
    end else if (due_ref) begin
      ref_req_valid = 1'b1;
      if (want_ab) begin ref_type = REF_AB; end
      else if (due_pb) begin ref_type = REF_PB; end
      else if (due_sb) begin ref_type = REF_SB; end
    end
  end

  // Counters
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin cnt_ref_ab <= '0; cnt_ref_pb <= '0; cnt_ref_sb <= '0; cnt_fgr_ticks <= '0; end
    else begin
      if (ref_req_valid && ref_req_ready) begin
        unique case (ref_type)
          REF_AB: cnt_ref_ab <= cnt_ref_ab + 1'b1;
          REF_PB: cnt_ref_pb <= cnt_ref_pb + 1'b1;
          REF_SB: cnt_ref_sb <= cnt_ref_sb + 1'b1;
          default: ;
        endcase
      end
      if (fgr_tick) cnt_fgr_ticks <= cnt_fgr_ticks + 1'b1;
    end
  end

  //======================== CA parity ========================
  // DDR5 CA parity is odd parity over CA bits; model simple generator
  function automatic logic odd_parity16(input logic [15:0] x);
    odd_parity16 = ~(^x); // odd parity: invert even parity
  endfunction

  assign ca_bus_out = ca_bus_in; // pass-through by default
  assign ca_parity  = cfg_en_ca_parity ? odd_parity16(ca_bus_in) : 1'b0;

  // Parity check on return side (if any loopback/echo)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) ca_parity_err <= 1'b0;
    else if (cfg_en_ca_parity) ca_parity_err <= (ca_parity_in != odd_parity16(ca_bus_in));
    else ca_parity_err <= 1'b0;
  end

  //======================== DBI/DM ========================
  // For write DBI: invert data bytes when number of 0s exceeds threshold
  function automatic logic [8:0] dbi_byte(input logic [7:0] d);
    int zeros = 8-$countones(d);
    logic dbi = (zeros > 4);
    logic [7:0] dout = dbi ? ~d : d;
    return {dbi, dout};
  endfunction

  genvar b;
  generate
    for (b = 0; b < 8; b++) begin : g_dbi
      wire [8:0] w = dbi_byte(dq_in_dbi_rd[b*9 +: 8]); // expecting packing externally
    end
  endgenerate

  // Map to outputs (placeholder wiring model)
  assign dq_out_dbi_wr = dq_in_dbi_rd; // in real design, apply dbi on transmit
  assign dm_out        = 8'h00;        // placeholder: DM low

endmodule
