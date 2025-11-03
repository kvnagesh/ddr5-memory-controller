//==============================================================================
// File: ddr5_timing_hazard_engine.sv
// Description: Advanced timing and hazard control engine for DDR5 memory
//              controller with tRRD, tFAW, 1N/2N command spacing, and
//              anti-starvation logic.
// Author: Production-Grade DDR5 Controller Team
// Date: November 2025
//==============================================================================

module ddr5_timing_hazard_engine #(
  parameter int NUM_BANKS = 32,        // DDR5: 32 banks (8 bank groups × 4 banks)
  parameter int NUM_RANKS = 2,
  parameter int ADDR_WIDTH = 17,
  parameter int tRRD_S = 4,            // Same bank group RRD (cycles)
  parameter int tRRD_L = 6,            // Different bank group RRD (cycles)
  parameter int tFAW_WINDOW = 16,      // Four Activate Window (cycles)
  parameter int tFAW_MAX_ACTS = 4,     // Max activates in tFAW window
  parameter int MAX_STARVATION_CYCLES = 1024
) (
  input  logic clk,
  input  logic rst_n,
  
  // Configuration
  input  logic cmd_spacing_1n,         // 1N vs 2N command spacing
  input  logic enable_anti_starvation,
  
  // Command request interface
  input  logic        req_valid,
  input  logic [3:0]  req_cmd,         // ACT, PRE, RD, WR, REF, etc.
  input  logic [4:0]  req_bank,        // Bank address
  input  logic [2:0]  req_bg,          // Bank group
  input  logic        req_rank,
  input  logic [ADDR_WIDTH-1:0] req_addr,
  input  logic [7:0]  req_priority,    // For anti-starvation
  output logic        req_ready,       // Timing hazard clear
  
  // Hazard status outputs
  output logic hazard_trrd_s,
  output logic hazard_trrd_l,
  output logic hazard_tfaw,
  output logic hazard_cmd_spacing,
  output logic starvation_override,
  
  // Performance counters
  output logic [31:0] cnt_trrd_stalls,
  output logic [31:0] cnt_tfaw_stalls,
  output logic [31:0] cnt_starvation_events
);

  //============================================================================
  // Type Definitions
  //============================================================================
  typedef enum logic [3:0] {
    CMD_NOP  = 4'b0000,
    CMD_ACT  = 4'b0001,
    CMD_RD   = 4'b0010,
    CMD_WR   = 4'b0011,
    CMD_PRE  = 4'b0100,
    CMD_REF  = 4'b0101,
    CMD_MRS  = 4'b0110
  } cmd_type_e;

  typedef struct packed {
    logic [2:0]  bg;
    logic [4:0]  bank;
    logic        rank;
    logic [15:0] timestamp;
  } act_history_t;

  //============================================================================
  // Internal Signals
  //============================================================================
  logic [15:0] cycle_counter;
  
  // tRRD tracking - last activate per bank group and rank
  logic [15:0] last_act_time [NUM_RANKS][8];  // 8 bank groups
  logic [2:0]  last_act_bg [NUM_RANKS];
  
  // tFAW tracking - sliding window of last 4 activates
  act_history_t act_history [tFAW_MAX_ACTS];
  logic [2:0] act_history_ptr;
  logic [2:0] act_count_in_window;
  
  // Command spacing tracker
  logic [3:0] cycles_since_last_cmd;
  logic       cmd_spacing_met;
  
  // Anti-starvation tracking
  logic [15:0] req_wait_time;
  logic        starvation_detected;
  
  // Hazard detection
  logic trrd_s_hazard, trrd_l_hazard, tfaw_hazard;
  
  //============================================================================
  // Cycle Counter
  //============================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      cycle_counter <= '0;
    else
      cycle_counter <= cycle_counter + 1'b1;
  end

  //============================================================================
  // Command Spacing Logic (1N vs 2N)
  //============================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycles_since_last_cmd <= '1;
    end else if (req_valid && req_ready) begin
      cycles_since_last_cmd <= '0;
    end else if (cycles_since_last_cmd < 4'hF) begin
      cycles_since_last_cmd <= cycles_since_last_cmd + 1'b1;
    end
  end

  assign cmd_spacing_met = cmd_spacing_1n ? 
                          (cycles_since_last_cmd >= 1) :
                          (cycles_since_last_cmd >= 2);

  //============================================================================
  // tRRD Hazard Detection (Same/Different Bank Group)
  //============================================================================
  always_comb begin
    trrd_s_hazard = 1'b0;
    trrd_l_hazard = 1'b0;
    
    if (req_cmd == CMD_ACT) begin
      // Check same bank group timing
      if ((cycle_counter - last_act_time[req_rank][req_bg]) < tRRD_S) begin
        trrd_s_hazard = 1'b1;
      end
      
      // Check different bank group timing
      if (last_act_bg[req_rank] != req_bg) begin
        if ((cycle_counter - last_act_time[req_rank][last_act_bg[req_rank]]) < tRRD_L) begin
          trrd_l_hazard = 1'b1;
        end
      end
    end
  end

  //============================================================================
  // tFAW Hazard Detection (4 Activates in Window)
  //============================================================================
  always_comb begin
    act_count_in_window = '0;
    tfaw_hazard = 1'b0;
    
    if (req_cmd == CMD_ACT) begin
      // Count valid activates within tFAW window
      for (int i = 0; i < tFAW_MAX_ACTS; i++) begin
        if ((cycle_counter - act_history[i].timestamp) < tFAW_WINDOW &&
            act_history[i].rank == req_rank) begin
          act_count_in_window++;
        end
      end
      
      // Hazard if we already have 4 activates in window
      if (act_count_in_window >= (tFAW_MAX_ACTS - 1)) begin
        tfaw_hazard = 1'b1;
      end
    end
  end

  //============================================================================
  // Activate History Update
  //============================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < NUM_RANKS; i++) begin
        for (int j = 0; j < 8; j++) begin
          last_act_time[i][j] <= '0;
        end
        last_act_bg[i] <= '0;
      end
      
      for (int i = 0; i < tFAW_MAX_ACTS; i++) begin
        act_history[i] <= '0;
      end
      act_history_ptr <= '0;
      
    end else if (req_valid && req_ready && req_cmd == CMD_ACT) begin
      // Update last activate time for this bank group
      last_act_time[req_rank][req_bg] <= cycle_counter;
      last_act_bg[req_rank] <= req_bg;
      
      // Update circular activate history buffer
      act_history[act_history_ptr].bg <= req_bg;
      act_history[act_history_ptr].bank <= req_bank;
      act_history[act_history_ptr].rank <= req_rank;
      act_history[act_history_ptr].timestamp <= cycle_counter;
      
      act_history_ptr <= (act_history_ptr == (tFAW_MAX_ACTS-1)) ? '0 : act_history_ptr + 1'b1;
    end
  end

  //============================================================================
  // Anti-Starvation Logic
  //============================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      req_wait_time <= '0;
      starvation_detected <= 1'b0;
    end else begin
      if (req_valid && !req_ready) begin
        req_wait_time <= req_wait_time + 1'b1;
        
        // Detect starvation condition
        if (enable_anti_starvation && 
            (req_wait_time >= MAX_STARVATION_CYCLES || req_priority >= 8'hF0)) begin
          starvation_detected <= 1'b1;
        end
      end else if (req_valid && req_ready) begin
        req_wait_time <= '0;
        starvation_detected <= 1'b0;
      end
    end
  end

  //============================================================================
  // Hazard Aggregation and Ready Generation
  //============================================================================
  assign hazard_trrd_s = trrd_s_hazard;
  assign hazard_trrd_l = trrd_l_hazard;
  assign hazard_tfaw = tfaw_hazard;
  assign hazard_cmd_spacing = !cmd_spacing_met;
  assign starvation_override = starvation_detected;
  
  // Ready when no hazards OR starvation override active
  assign req_ready = starvation_detected ? 1'b1 : 
                    !(trrd_s_hazard || trrd_l_hazard || tfaw_hazard || !cmd_spacing_met);

  //============================================================================
  // Performance Counters
  //============================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt_trrd_stalls <= '0;
      cnt_tfaw_stalls <= '0;
      cnt_starvation_events <= '0;
    end else begin
      if (req_valid && (trrd_s_hazard || trrd_l_hazard))
        cnt_trrd_stalls <= cnt_trrd_stalls + 1'b1;
      
      if (req_valid && tfaw_hazard)
        cnt_tfaw_stalls <= cnt_tfaw_stalls + 1'b1;
      
      if (starvation_detected && req_ready)
        cnt_starvation_events <= cnt_starvation_events + 1'b1;
    end
  end

  //============================================================================
  // Assertions
  //============================================================================
  `ifdef FORMAL
    // Verify tRRD_S timing is enforced
    property p_trrd_s_enforced;
      @(posedge clk) disable iff (!rst_n)
      (req_valid && req_cmd == CMD_ACT && req_ready) |=>
      ##[1:tRRD_S-1] !(req_valid && req_cmd == CMD_ACT && 
                       req_bg == $past(req_bg) && req_rank == $past(req_rank));
    endproperty
    assert_trrd_s: assert property(p_trrd_s_enforced);
    
    // Verify tFAW constraint (max 4 activates)
    property p_tfaw_enforced;
      @(posedge clk) disable iff (!rst_n)
      act_count_in_window <= tFAW_MAX_ACTS;
    endproperty
    assert_tfaw: assert property(p_tfaw_enforced);
  `endif

endmodule
