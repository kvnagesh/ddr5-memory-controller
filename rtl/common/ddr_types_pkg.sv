//******************************************************************************
// File: ddr_types_pkg.sv
// Description: Common types, timing bins, protocol maps for DDR5/LPDDR5/LPDDR5X up to 8533 MT/s
// Author: Production RTL Team
// Date: 2025-11-03
//******************************************************************************
package ddr_types_pkg;
  `include "ddr_defines.svh"

  //============================================================================
  // Speed Bin and Timing Parameterization
  //============================================================================
  typedef struct packed {
    int unsigned tck_ps;     // clock period in ps
    int unsigned trcd_ck;
    int unsigned trp_ck;
    int unsigned tras_ck;
    int unsigned trc_ck;
    int unsigned trfc_ns;
    int unsigned trefi_us;
    int unsigned twr_ck;
    int unsigned twtr_s_ck;
    int unsigned twtr_l_ck;
    int unsigned trtp_ck;
    int unsigned trrd_s_ck;
    int unsigned trrd_l_ck;
    int unsigned tccd_s_ck;
    int unsigned tccd_l_ck;
    int unsigned tccd_wr_ck;
    int unsigned tfaw_ck;
    int unsigned tmrw_ck;
    int unsigned tmrd_ck;
    int unsigned tdqsck_ps;
    int unsigned tdqsck_var_ps;
  } timing_t;

  // Provide representative timing for common speed bins; values are placeholders
  // and must be calibrated against vendor datasheets during integration.
  localparam timing_t TIMING_DDR5_6400 = '{tck_ps:312, trcd_ck:18, trp_ck:18, tras_ck:42, trc_ck:60,
                                           trfc_ns:260, trefi_us:3_900, twr_ck:18, twtr_s_ck:6, twtr_l_ck:10,
                                           trtp_ck:10, trrd_s_ck:6, trrd_l_ck:8, tccd_s_ck:4, tccd_l_ck:8,
                                           tccd_wr_ck:8, tfaw_ck:32, tmrw_ck:8, tmrd_ck:8, tdqsck_ps:75, tdqsck_var_ps:25};
  localparam timing_t TIMING_DDR5_8533 = '{tck_ps:234, trcd_ck:20, trp_ck:20, tras_ck:44, trc_ck:64,
                                           trfc_ns:300, trefi_us:3_900, twr_ck:20, twtr_s_ck:6, twtr_l_ck:10,
                                           trtp_ck:10, trrd_s_ck:6, trrd_l_ck:8, tccd_s_ck:4, tccd_l_ck:8,
                                           tccd_wr_ck:8, tfaw_ck:32, tmrw_ck:8, tmrd_ck:8, tdqsck_ps:65, tdqsck_var_ps:25};
  localparam timing_t TIMING_LP5_6400  = '{tck_ps:312, trcd_ck:18, trp_ck:18, tras_ck:42, trc_ck:60,
                                           trfc_ns:210, trefi_us:3_900, twr_ck:14, twtr_s_ck:6, twtr_l_ck:8,
                                           trtp_ck:8,  trrd_s_ck:6, trrd_l_ck:8, tccd_s_ck:4, tccd_l_ck:8,
                                           tccd_wr_ck:8, tfaw_ck:28, tmrw_ck:8, tmrd_ck:8, tdqsck_ps:60, tdqsck_var_ps:20};
  localparam timing_t TIMING_LP5X_8533 = '{tck_ps:234, trcd_ck:20, trp_ck:20, tras_ck:44, trc_ck:64,
                                           trfc_ns:240, trefi_us:3_900, twr_ck:16, twtr_s_ck:6, twtr_l_ck:8,
                                           trtp_ck:8,  trrd_s_ck:6, trrd_l_ck:8, tccd_s_ck:4, tccd_l_ck:8,
                                           tccd_wr_ck:8, tfaw_ck:28, tmrw_ck:8, tmrd_ck:8, tdqsck_ps:55, tdqsck_var_ps:20};

  // Active timing selection based on MEM_STD and rate
  function automatic timing_t select_timing();
    timing_t t;
    if (`FEAT_DDR5) begin
      t = (`DDR_DATA_RATE_MT >= 8000) ? TIMING_DDR5_8533 : TIMING_DDR5_6400;
    end else if (`FEAT_LP5) begin
      t = TIMING_LP5_6400;
    end else begin
      t = TIMING_LP5X_8533;
    end
    return t;
  endfunction

  localparam timing_t TIMING = select_timing();

  // Exported parameters for modules to use (mapped from TIMING record)
  localparam int unsigned TCK_PS        = TIMING.tck_ps;
  localparam int unsigned TRCD_CK       = TIMING.trcd_ck;
  localparam int unsigned TRP_CK        = TIMING.trp_ck;
  localparam int unsigned TRAS_CK       = TIMING.tras_ck;
  localparam int unsigned TRC_CK        = TIMING.trc_ck;
  localparam int unsigned TRFC_NS       = TIMING.trfc_ns;
  localparam int unsigned TREFI_US      = TIMING.trefi_us;
  localparam int unsigned TWR_CK        = TIMING.twr_ck;
  localparam int unsigned TWTR_S_CK     = TIMING.twtr_s_ck;
  localparam int unsigned TWTR_L_CK     = TIMING.twtr_l_ck;
  localparam int unsigned TRTP_CK       = TIMING.trtp_ck;
  localparam int unsigned TRRD_S_CK     = TIMING.trrd_s_ck;
  localparam int unsigned TRRD_L_CK     = TIMING.trrd_l_ck;
  localparam int unsigned TCCD_S_CK     = TIMING.tccd_s_ck;
  localparam int unsigned TCCD_L_CK     = TIMING.tccd_l_ck;
  localparam int unsigned TCCD_WR_CK    = TIMING.tccd_wr_ck;
  localparam int unsigned TFAW_CK       = TIMING.tfaw_ck;
  localparam int unsigned TMRW_CK       = TIMING.tmrw_ck;
  localparam int unsigned TMRD_CK       = TIMING.tmrd_ck;
  localparam int unsigned TDQSCK_PS     = TIMING.tdqsck_ps;
  localparam int unsigned TDQSCK_VAR_PS = TIMING.tdqsck_var_ps;

  //============================================================================
  // Protocol Feature Map (DDR5 vs LPDDR5/5X)
  //============================================================================
  typedef struct packed {
    logic ca_parity;
    logic cmdaddr_mux;
    logic dm_dbi;
    logic wr_leveling;
    logic rd_gating;
    logic vref_train;
    logic bl32_support; // LPDDR5X BL32 write burst mapping
  } proto_feat_t;

  localparam proto_feat_t PROTO_FEAT = '{
    ca_parity:   (`FEAT_DDR5)?1:0,
    cmdaddr_mux: (`FEAT_DDR5)?0:1,
    dm_dbi:      1,
    wr_leveling: (`FEAT_DDR5)?1:0,
    rd_gating:   1,
    vref_train:  1,
    bl32_support:(`FEAT_LP5X)?1:0
  };

  //==============================================================================
  // Command encodings and structures
  //==============================================================================
  typedef enum logic [3:0] {
    CMD_NOP     = `CMD_NOP,
    CMD_MRW     = `CMD_MRW,
    CMD_PRE     = `CMD_PRE,
    CMD_ACT     = `CMD_ACT,
    CMD_RD      = `CMD_RD,
    CMD_WR      = `CMD_WR,
    CMD_REF     = `CMD_REF,
    CMD_ZQC     = `CMD_ZQC,
    CMD_SREF    = `CMD_SREF,
    CMD_PD      = `CMD_PD
  } ddr_cmd_t;

  typedef struct packed {
    logic                           valid;
    ddr_cmd_t                       cmd;
    logic [`DDR_CHANNEL_LOG2-1:0]   channel;
    logic [`DDR_RANK_LOG2-1:0]      rank;
    logic [`DDR_BANK_ADDR_WIDTH-1:0] bank;
    logic [`DDR_ROW_ADDR_WIDTH-1:0]  row;
    logic [`DDR_COL_ADDR_WIDTH-1:0]  col;
    logic                           autopre;
    logic [7:0]                     qos;
    logic [15:0]                    txid;
  } mem_cmd_s;

  //==============================================================================
  // DFI Interface Parameters and Records
  //==============================================================================
  `ifndef DFI_ADDR_WIDTH
    `define DFI_ADDR_WIDTH  24
  `endif
  `ifndef DFI_BANK_WIDTH
    `define DFI_BANK_WIDTH  8
  `endif
  `ifndef DFI_DATA_WIDTH
    `define DFI_DATA_WIDTH  (`DDR_DQ_WIDTH)
  `endif

  typedef struct packed {
    logic [`DFI_ADDR_WIDTH-1:0]  address;
    logic [`DFI_BANK_WIDTH-1:0]  bank;
    logic                        cas_n;
    logic                        ras_n;
    logic                        we_n;
    logic                        cs_n;
    logic                        cke;
    logic                        odt;
    logic                        reset_n;
  } dfi_cmd_s;

  typedef struct packed {
    logic [`DFI_DATA_WIDTH-1:0]  wrdata;
    logic [`DFI_DATA_WIDTH/8-1:0] wrdata_mask;
    logic                        wrdata_en;
    logic                        rddata_en;
    logic [`DFI_DATA_WIDTH-1:0]  rddata;
    logic                        rddata_valid;
  } dfi_data_s;

  //==============================================================================
  // Bank, Scheduler, QoS, ECC, Security Types (stubs remain compatible)
  //==============================================================================
  typedef enum logic [2:0] {
    BANK_IDLE, BANK_ACTIVATING, BANK_ACTIVE, BANK_READING, BANK_WRITING, BANK_PRECHARGE, BANK_REFRESH
  } bank_state_t;

  typedef struct packed {
    bank_state_t                    state;
    logic [`DDR_ROW_ADDR_WIDTH-1:0] open_row;
    logic [15:0]                    t_last_act;
    logic [15:0]                    t_last_pre;
    logic [15:0]                    t_last_rd;
    logic [15:0]                    t_last_wr;
  } bank_status_s;

  typedef struct packed {
    logic [3:0] priority;
    logic [7:0] bandwidth_limit;
    logic [7:0] bandwidth_used;
    logic       urgent;
    logic       guaranteed;
  } qos_info_s;

endpackage : ddr_types_pkg
