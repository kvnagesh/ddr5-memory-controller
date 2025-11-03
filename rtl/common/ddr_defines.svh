//******************************************************************************
// File: ddr_defines.svh
// Description: Global defines and parameters for DDR5/LPDDR5X Memory Controller
// Author: Production RTL Team
// Date: 2025-11-03
//******************************************************************************

`ifndef DDR_DEFINES_SVH
`define DDR_DEFINES_SVH

//==============================================================================
// Memory Type Selection
//==============================================================================
`define DDR5_ENABLED
// `define LPDDR5X_ENABLED  // Uncomment for LPDDR5X support

//==============================================================================
// Memory Configuration Parameters
//==============================================================================

// Memory Organization
`define DDR_DATA_WIDTH       512      // Data bus width (bits)
`define DDR_ADDR_WIDTH       34       // Physical address width
`define DDR_BANK_ADDR_WIDTH  6        // Bank address width (DDR5: 6 bits for 32 banks)
`define DDR_ROW_ADDR_WIDTH   18       // Row address width
`define DDR_COL_ADDR_WIDTH   10       // Column address width
`define DDR_CHANNEL_WIDTH    2        // Number of channels (log2)
`define DDR_RANK_WIDTH       2        // Number of ranks per channel (log2)

// Burst and Transfer
`define DDR_BURST_LENGTH     16       // BL16 for DDR5
`define DDR_PREFETCH         16       // Prefetch depth
`define DDR_DQ_WIDTH         64       // DQ bits per module
`define DDR_DQS_WIDTH        8        // DQS strobes
`define DDR_DM_WIDTH         8        // Data mask signals

// ECC Configuration
`define ECC_DATA_WIDTH       64       // Data width for ECC
`define ECC_CHECK_WIDTH      8        // Check bits (SECDED)
`define ECC_TOTAL_WIDTH      72       // Total width with ECC

//==============================================================================
// Timing Parameters (in clock cycles) - DDR5-5600
//==============================================================================

`define tCK                  357      // Clock period (ps) for DDR5-5600
`define tRCD                 16       // RAS to CAS delay
`define tRP                  16       // Row precharge time
`define tRAS                 42       // Row active time
`define tRC                  58       // Row cycle time
`define tRRD_L               6        // Row to row delay (same bank group)
`define tRRD_S               4        // Row to row delay (different bank group)
`define tCCD_L               8        // CAS to CAS delay (same bank group)
`define tCCD_S               4        // CAS to CAS delay (different bank group)
`define tWR                  24       // Write recovery time
`define tRTP                 12       // Read to precharge
`define tWTR_L               12       // Write to read (same bank group)
`define tWTR_S               4        // Write to read (different bank group)
`define tFAW                 16       // Four activate window
`define tRFC                 295      // Refresh cycle time (per bank)
`define tREFI                9360     // Refresh interval
`define tXS                  304      // Exit self-refresh to command

//==============================================================================
// Command Encoding
//==============================================================================

// DDR5 Command Opcodes
`define CMD_NOP              4'b0111
`define CMD_READ             4'b0101
`define CMD_WRITE            4'b0100
`define CMD_ACTIVATE         4'b0001
`define CMD_PRECHARGE        4'b0010
`define CMD_REFRESH          4'b1000
`define CMD_SELF_REFRESH     4'b1001
`define CMD_POWER_DOWN       4'b1010
`define CMD_MRS              4'b0000  // Mode Register Set
`define CMD_ZQC              4'b1011  // ZQ Calibration

//==============================================================================
// Mode Register Addresses
//==============================================================================

`define MR0_ADDR             3'h0
`define MR1_ADDR             3'h1
`define MR2_ADDR             3'h2
`define MR3_ADDR             3'h3
`define MR4_ADDR             3'h4
`define MR5_ADDR             3'h5
`define MR6_ADDR             3'h6
`define MR7_ADDR             3'h7

//==============================================================================
// AXI4 Configuration
//==============================================================================

`define AXI_ADDR_WIDTH       `DDR_ADDR_WIDTH
`define AXI_DATA_WIDTH       `DDR_DATA_WIDTH
`define AXI_ID_WIDTH         8
`define AXI_USER_WIDTH       4
`define AXI_STRB_WIDTH       (`AXI_DATA_WIDTH/8)

// AXI Response Codes
`define AXI_RESP_OKAY        2'b00
`define AXI_RESP_EXOKAY      2'b01
`define AXI_RESP_SLVERR      2'b10
`define AXI_RESP_DECERR      2'b11

// AXI Burst Types
`define AXI_BURST_FIXED      2'b00
`define AXI_BURST_INCR       2'b01
`define AXI_BURST_WRAP       2'b10

//==============================================================================
// DFI (DDR PHY Interface) Configuration
//==============================================================================

`define DFI_ADDR_WIDTH       18
`define DFI_BANK_WIDTH       6
`define DFI_DATA_WIDTH       `DDR_DQ_WIDTH
`define DFI_FREQ_RATIO       2        // 2:1 or 4:1 frequency ratio
`define DFI_PHASES           4        // Number of DFI phases

//==============================================================================
// Queue Depths
//==============================================================================

`define CMD_QUEUE_DEPTH      32       // Command queue depth
`define READ_QUEUE_DEPTH     16       // Read transaction queue
`define WRITE_QUEUE_DEPTH    16       // Write transaction queue
`define REFRESH_QUEUE_DEPTH  8        // Refresh command queue

//==============================================================================
// QoS Configuration
//==============================================================================

`define QOS_LEVELS           4        // Number of QoS priority levels
`define QOS_ID_WIDTH         2        // QoS identifier width
`define BANDWIDTH_BUCKETS    8        // Traffic shaping buckets

//==============================================================================
// Security Configuration
//==============================================================================

`define AES_KEY_WIDTH        256      // AES-256 encryption
`define AES_BLOCK_SIZE       128      // AES block size
`define SECURE_REGIONS       16       // Number of secure memory regions

//==============================================================================
// Error Detection and Reporting
//==============================================================================

`define ERROR_LOG_DEPTH      16       // Error logging FIFO depth
`define ERROR_COUNTER_WIDTH  16       // Error counter width

//==============================================================================
// Debug and Performance Monitoring
//==============================================================================

`define PERF_COUNTER_WIDTH   32       // Performance counter width
`define NUM_PERF_COUNTERS    8        // Number of performance counters

//==============================================================================
// Derived Parameters (Do not modify)
//==============================================================================

`define NUM_CHANNELS         (1 << `DDR_CHANNEL_WIDTH)
`define NUM_RANKS            (1 << `DDR_RANK_WIDTH)
`define NUM_BANKS            (1 << `DDR_BANK_ADDR_WIDTH)
`define PAGE_SIZE            (1 << `DDR_COL_ADDR_WIDTH)

//==============================================================================
// Utility Macros
//==============================================================================

`define MAX(a, b)            (((a) > (b)) ? (a) : (b))
`define MIN(a, b)            (((a) < (b)) ? (a) : (b))
`define CLOG2(x)             $clog2(x)

//==============================================================================
// Simulation vs. Synthesis
//==============================================================================

`ifdef SIMULATION
  `define ASSERT_ERROR(msg) $error(msg)
  `define ASSERT_FATAL(msg) $fatal(1, msg)
`else
  `define ASSERT_ERROR(msg)
  `define ASSERT_FATAL(msg)
`endif

`endif // DDR_DEFINES_SVH
