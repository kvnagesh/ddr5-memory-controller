//******************************************************************************
// File: ddr_defines.svh
// Description: Global defines, parameters, and mode/timing hooks for DDR5/LPDDR5/LPDDR5X controller up to 8533 Mb/s
// Author: Production RTL Team
// Date: 2025-11-03
//******************************************************************************
`ifndef DDR_DEFINES_SVH
`define DDR_DEFINES_SVH

//==============================================================================
// Memory Standards and Mode Selection
//==============================================================================
// MEM_STD selects the active protocol: 0=DDR5, 1=LPDDR5, 2=LPDDR5X
`define MEM_STD_DDR5     0
`define MEM_STD_LPDDR5   1
`define MEM_STD_LPDDR5X  2

// Default to DDR5; override via parameters or synthesis define
`ifndef MEM_STD_DEFAULT
  `define MEM_STD_DEFAULT `MEM_STD_DDR5
`endif

// Convenience feature switches auto-derived from MEM_STD
`define FEAT_DDR5    (`MEM_STD_DEFAULT==`MEM_STD_DDR5)
`define FEAT_LP5     (`MEM_STD_DEFAULT==`MEM_STD_LPDDR5)
`define FEAT_LP5X    (`MEM_STD_DEFAULT==`MEM_STD_LPDDR5X)

//==============================================================================
// Global Speed/Rate Parameters (max up to 8533 Mb/s)
//==============================================================================
// Data rate MT/s (Mb/s per pin). Example bins: 4800, 5600, 6400, 7200, 8000, 8533
`ifndef DDR_DATA_RATE_MT
  `define DDR_DATA_RATE_MT 8533
`endif

// Controller/PHY clock ratios
// DFI frequency ratio N: 1=1:1, 2=1:2, 4=1:4 (commonly 1:2 or 1:4 at high speed)
`ifndef DFI_FREQ_RATIO
  `define DFI_FREQ_RATIO 2
`endif

//==============================================================================
// Memory Organization (may be overridden per design/top)
//==============================================================================
`ifndef DDR_DATA_WIDTH      // Controller internal data path width (bits)
  `define DDR_DATA_WIDTH 512
`endif
`ifndef DDR_DQ_WIDTH        // External DRAM DQ per channel
  `define DDR_DQ_WIDTH 64
`endif
`ifndef DDR_DQS_WIDTH       // DQS pairs per channel
  `define DDR_DQS_WIDTH 8
`endif
`ifndef DDR_DM_WIDTH        // DM/DBI width (if used)
  `define DDR_DM_WIDTH 8
`endif
`ifndef DDR_ADDR_WIDTH      // Physical address width (row+col+bank portions handled in mapper)
  `define DDR_ADDR_WIDTH 34
`endif
`ifndef DDR_BANK_ADDR_WIDTH // Bank address bits (DDR5 uses Bank/BankGroup)
  `define DDR_BANK_ADDR_WIDTH 6
`endif
`ifndef DDR_ROW_ADDR_WIDTH
  `define DDR_ROW_ADDR_WIDTH 18
`endif
`ifndef DDR_COL_ADDR_WIDTH
  `define DDR_COL_ADDR_WIDTH 10
`endif
`ifndef DDR_CHANNEL_LOG2
  `define DDR_CHANNEL_LOG2 1  // 2 channels default
`endif
`ifndef DDR_RANK_LOG2
  `define DDR_RANK_LOG2 1     // 2 ranks default
`endif

//==============================================================================
// Burst/Prefetch and Protocol Variants
//==============================================================================
// DDR5 uses BL16. LPDDR5/5X uses BL16/BL32 (write burst may be half-rate dependent)
`define DDR5_BURST_LENGTH   16
`define LP5_BURST_LENGTH    16
`define LP5X_BURST_LENGTH   16  // BL32 supported via WRPRE setting; controller issues two BL16 beats

// Effective burst length selected by MEM_STD
`define DDR_BURST_LENGTH ( `FEAT_DDR5  ? `DDR5_BURST_LENGTH : \
                           `FEAT_LP5  ? `LP5_BURST_LENGTH  : \
                                         `LP5X_BURST_LENGTH )

// Prefetch depth (x16 prefetch typical for DDR5/LPDDR5/5X)
`define DDR_PREFETCH 16

//==============================================================================
// DFI/PHY Laneing and Training Feature Flags
//==============================================================================
`define FEAT_WR_LEVELING      1  // DDR5 write leveling support
`define FEAT_RD_GATING        1  // Read DQS gating/training
`define FEAT_VREF_TRAIN       1  // MR-controlled VrefDQ training hooks
`define FEAT_CA_PARITY        1  // DDR5 CA parity support
`define FEAT_CMD_ADDR_MUX     1  // CA muxing for LPDDR5/5X
`define FEAT_DM_DBI           1  // Data Mask / DBI support
`define FEAT_DFE_RX           1  // Hook for PHY DFE at high speeds

//==============================================================================
// Timing Parameterization (ns/ck abstract). Concrete values set in types pkg.
// These defines provide names; actual numbers shall be parameters in ddr_types_pkg
//==============================================================================
`define TCK_PS           0
`define TRCD_CK          0
`define TRP_CK           0
`define TRAS_CK          0
`define TRC_CK           0
`define TRFC_NS          0
`define TREFI_US         0
`define TWR_CK           0
`define TWTR_S_CK        0
`define TWTR_L_CK        0
`define TRTP_CK          0
`define TRRD_S_CK        0
`define TRRD_L_CK        0
`define TCCD_S_CK        0
`define TCCD_L_CK        0
`define TMOD_CK          0
`define TMRD_CK          0
`define TFAW_CK          0
`define TCCD_WR_CK       0
`define TRPRE_CK         0
`define TWPRE_CK         0
`define TDQSCK_PS        0
`define TDQSCK_VAR_PS    0

// The actual timing values per speed bin and per standard are defined in ddr_types_pkg.sv

//==============================================================================
// Mode Register Encodings (abstract bitfields; concrete MR values in types pkg)
//==============================================================================
`define MR_ADDR_WIDTH  16
`define MR_DATA_WIDTH  32

//==============================================================================
// Command/State Machine Opcodes (abstract)
//==============================================================================
`define CMD_NOP     4'd0
`define CMD_MRW     4'd1
`define CMD_PRE     4'd2
`define CMD_ACT     4'd3
`define CMD_RD      4'd4
`define CMD_WR      4'd5
`define CMD_REF     4'd6
`define CMD_ZQC     4'd7
`define CMD_SREF    4'd8
`define CMD_PD      4'd9

//==============================================================================
// Utility Macros
//==============================================================================
`define MAX(a,b) ((a)>(b)?(a):(b))
`define MIN(a,b) ((a)<(b)?(a):(b))

//==============================================================================
// Notes:
// - This header centralizes feature flags and default widths. Concrete timing and
//   MR encodings live in ddr_types_pkg.sv to allow param-based selection at build.
// - Controllers should gate behavior on MEM_STD to map protocol differences.
// - PHY should honor DFI_FREQ_RATIO and expose training hooks enabled above.
//==============================================================================

`endif // DDR_DEFINES_SVH
