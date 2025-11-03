//******************************************************************************
// File: ddr_types_pkg.sv
// Description: Common types and structures for DDR5/LPDDR5X Memory Controller
// Author: Production RTL Team
// Date: 2025-11-03
//******************************************************************************

package ddr_types_pkg;

  import "DPI-C" function void debug_log(string msg);

  `include "ddr_defines.svh"

  //============================================================================
  // Memory Command Types
  //============================================================================

  typedef enum logic [3:0] {
    CMD_NOP        = 4'b0111,
    CMD_READ       = 4'b0101,
    CMD_WRITE      = 4'b0100,
    CMD_ACTIVATE   = 4'b0001,
    CMD_PRECHARGE  = 4'b0010,
    CMD_REFRESH    = 4'b1000,
    CMD_SELF_REF   = 4'b1001,
    CMD_POWER_DOWN = 4'b1010,
    CMD_MRS        = 4'b0000,
    CMD_ZQC        = 4'b1011
  } ddr_cmd_t;

  //============================================================================
  // Memory Command Structure
  //============================================================================

  typedef struct packed {
    logic                            valid;
    ddr_cmd_t                        cmd;
    logic [`DDR_CHANNEL_WIDTH-1:0]  channel;
    logic [`DDR_RANK_WIDTH-1:0]      rank;
    logic [`DDR_BANK_ADDR_WIDTH-1:0] bank;
    logic [`DDR_ROW_ADDR_WIDTH-1:0]  row;
    logic [`DDR_COL_ADDR_WIDTH-1:0]  col;
    logic [`DDR_DATA_WIDTH-1:0]      data;
    logic [`DDR_DATA_WIDTH/8-1:0]    data_mask;
    logic                            auto_precharge;
    logic [7:0]                      priority;
    logic [15:0]                     transaction_id;
  } mem_cmd_s;

  //============================================================================
  // AXI Transaction Structures
  //============================================================================

  // AXI Write Address Channel
  typedef struct packed {
    logic [`AXI_ID_WIDTH-1:0]     awid;
    logic [`AXI_ADDR_WIDTH-1:0]   awaddr;
    logic [7:0]                   awlen;
    logic [2:0]                   awsize;
    logic [1:0]                   awburst;
    logic                         awlock;
    logic [3:0]                   awcache;
    logic [2:0]                   awprot;
    logic [3:0]                   awqos;
    logic [`AXI_USER_WIDTH-1:0]   awuser;
    logic                         awvalid;
  } axi_aw_s;

  // AXI Write Data Channel
  typedef struct packed {
    logic [`AXI_DATA_WIDTH-1:0]   wdata;
    logic [`AXI_STRB_WIDTH-1:0]   wstrb;
    logic                         wlast;
    logic [`AXI_USER_WIDTH-1:0]   wuser;
    logic                         wvalid;
  } axi_w_s;

  // AXI Write Response Channel
  typedef struct packed {
    logic [`AXI_ID_WIDTH-1:0]     bid;
    logic [1:0]                   bresp;
    logic [`AXI_USER_WIDTH-1:0]   buser;
    logic                         bvalid;
  } axi_b_s;

  // AXI Read Address Channel
  typedef struct packed {
    logic [`AXI_ID_WIDTH-1:0]     arid;
    logic [`AXI_ADDR_WIDTH-1:0]   araddr;
    logic [7:0]                   arlen;
    logic [2:0]                   arsize;
    logic [1:0]                   arburst;
    logic                         arlock;
    logic [3:0]                   arcache;
    logic [2:0]                   arprot;
    logic [3:0]                   arqos;
    logic [`AXI_USER_WIDTH-1:0]   aruser;
    logic                         arvalid;
  } axi_ar_s;

  // AXI Read Data Channel
  typedef struct packed {
    logic [`AXI_ID_WIDTH-1:0]     rid;
    logic [`AXI_DATA_WIDTH-1:0]   rdata;
    logic [1:0]                   rresp;
    logic                         rlast;
    logic [`AXI_USER_WIDTH-1:0]   ruser;
    logic                         rvalid;
  } axi_r_s;

  //============================================================================
  // DFI Interface Structures
  //============================================================================

  typedef struct packed {
    logic [`DFI_ADDR_WIDTH-1:0]   address;
    logic [`DFI_BANK_WIDTH-1:0]   bank;
    logic                         cas_n;
    logic                         ras_n;
    logic                         we_n;
    logic                         cs_n;
    logic                         cke;
    logic                         odt;
    logic                         reset_n;
  } dfi_cmd_s;

  typedef struct packed {
    logic [`DFI_DATA_WIDTH-1:0]   wrdata;
    logic [`DFI_DATA_WIDTH/8-1:0] wrdata_mask;
    logic                         wrdata_en;
    logic                         rddata_en;
    logic [`DFI_DATA_WIDTH-1:0]   rddata;
    logic                         rddata_valid;
  } dfi_data_s;

  //============================================================================
  // ECC Structures
  //============================================================================

  typedef struct packed {
    logic [`ECC_DATA_WIDTH-1:0]   data;
    logic [`ECC_CHECK_WIDTH-1:0]  check_bits;
    logic                         single_error;
    logic                         double_error;
    logic [5:0]                   error_bit_position;
  } ecc_word_s;

  //============================================================================
  // Scheduler Structures
  //============================================================================

  typedef struct packed {
    logic                            valid;
    logic [3:0]                      priority;
    logic [`DDR_CHANNEL_WIDTH-1:0]   channel;
    logic [`DDR_RANK_WIDTH-1:0]       rank;
    logic [`DDR_BANK_ADDR_WIDTH-1:0]  bank;
    logic [`DDR_ROW_ADDR_WIDTH-1:0]   row;
    logic                             is_read;
    logic                             is_write;
    logic [15:0]                      age_counter;
    logic [7:0]                       qos_level;
  } sched_entry_s;

  //============================================================================
  // Bank State Machine
  //============================================================================

  typedef enum logic [2:0] {
    BANK_IDLE       = 3'b000,
    BANK_ACTIVATING = 3'b001,
    BANK_ACTIVE     = 3'b010,
    BANK_READING    = 3'b011,
    BANK_WRITING    = 3'b100,
    BANK_PRECHARGE  = 3'b101,
    BANK_REFRESH    = 3'b110
  } bank_state_t;

  typedef struct packed {
    bank_state_t                     state;
    logic [`DDR_ROW_ADDR_WIDTH-1:0]  open_row;
    logic [15:0]                     last_activate_time;
    logic [15:0]                     last_precharge_time;
    logic [15:0]                     last_read_time;
    logic [15:0]                     last_write_time;
  } bank_status_s;

  //============================================================================
  // QoS Structures
  //============================================================================

  typedef struct packed {
    logic [3:0]                      priority;
    logic [7:0]                      bandwidth_limit;
    logic [7:0]                      bandwidth_used;
    logic                            urgent;
    logic                            guaranteed_service;
  } qos_info_s;

  //============================================================================
  // Security Structures
  //============================================================================

  typedef struct packed {
    logic [`AES_KEY_WIDTH-1:0]       key;
    logic [127:0]                    iv;  // Initialization vector
    logic                            encrypt_enable;
    logic                            decrypt_enable;
  } security_context_s;

  typedef struct packed {
    logic [`DDR_ADDR_WIDTH-1:0]      start_addr;
    logic [`DDR_ADDR_WIDTH-1:0]      end_addr;
    logic                            secure;
    logic                            read_allowed;
    logic                            write_allowed;
    logic [7:0]                      region_id;
  } memory_region_s;

  //============================================================================
  // Refresh Structures
  //============================================================================

  typedef struct packed {
    logic                            refresh_req;
    logic                            refresh_urgent;
    logic [`DDR_BANK_ADDR_WIDTH-1:0] bank;
    logic [`DDR_RANK_WIDTH-1:0]      rank;
    logic [15:0]                     refresh_counter;
  } refresh_req_s;

  //============================================================================
  // Error Logging
  //============================================================================

  typedef enum logic [3:0] {
    ERR_NONE           = 4'h0,
    ERR_ECC_SINGLE     = 4'h1,
    ERR_ECC_DOUBLE     = 4'h2,
    ERR_CRC            = 4'h3,
    ERR_TIMEOUT        = 4'h4,
    ERR_PROTOCOL       = 4'h5,
    ERR_SECURITY       = 4'h6,
    ERR_ORDERING       = 4'h7,
    ERR_HAZARD         = 4'h8
  } error_type_t;

  typedef struct packed {
    error_type_t                     error_type;
    logic [31:0]                     timestamp;
    logic [`DDR_ADDR_WIDTH-1:0]      address;
    logic [63:0]                     error_data;
  } error_log_s;

  //============================================================================
  // Performance Monitoring
  //============================================================================

  typedef struct packed {
    logic [31:0]                     total_reads;
    logic [31:0]                     total_writes;
    logic [31:0]                     page_hits;
    logic [31:0]                     page_misses;
    logic [31:0]                     bank_conflicts;
    logic [31:0]                     refresh_cycles;
    logic [31:0]                     idle_cycles;
    logic [31:0]                     utilization_percent;
  } performance_counters_s;

  //============================================================================
  // Utility Functions
  //============================================================================

  function automatic logic is_same_page(
    input logic [`DDR_BANK_ADDR_WIDTH-1:0] bank1, bank2,
    input logic [`DDR_ROW_ADDR_WIDTH-1:0] row1, row2
  );
    return (bank1 == bank2) && (row1 == row2);
  endfunction

  function automatic logic [3:0] calculate_priority(
    input logic [7:0] qos,
    input logic [15:0] age
  );
    // Higher QoS and older transactions get higher priority
    return qos[3:0] + (age > 16'hFF ? 4'hF : age[7:4]);
  endfunction

  function automatic logic check_hazard(
    input logic [`DDR_ADDR_WIDTH-1:0] addr1, addr2,
    input logic is_write1, is_write2
  );
    logic same_addr = (addr1 == addr2);
    // RAW, WAR, or WAW hazard
    return same_addr && (is_write1 || is_write2);
  endfunction

endpackage : ddr_types_pkg
