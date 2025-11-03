//==============================================================================
// File: ddr5_axi4_slave.sv
// Description: AXI4 slave front-end with reorder buffer and QoS class mapping
//              for DDR5 controller. Supports ID-based reordering, write/read
//              combining, backpressure, and QoS-based arbitration.
//==============================================================================

`include "uvm_macros.svh"

module ddr5_axi4_slave #(
  parameter int ADDR_WIDTH = 34,      // large address space
  parameter int DATA_WIDTH = 512,     // typically x64 PHY => 512-bit datapath
  parameter int ID_WIDTH   = 8,
  parameter int LEN_WIDTH  = 8,
  parameter int USER_WIDTH = 1,
  parameter int ROB_DEPTH  = 64,
  parameter int QOS_CLASSES = 4
) (
  input  logic                   aclk,
  input  logic                   aresetn,

  // AXI4 Write Address Channel
  input  logic                   awvalid,
  output logic                   awready,
  input  logic [ID_WIDTH-1:0]    awid,
  input  logic [ADDR_WIDTH-1:0]  awaddr,
  input  logic [LEN_WIDTH-1:0]   awlen,
  input  logic [2:0]             awsize,
  input  logic [1:0]             awburst,
  input  logic [3:0]             awqos,

  // AXI4 Write Data Channel
  input  logic                   wvalid,
  output logic                   wready,
  input  logic [DATA_WIDTH-1:0]  wdata,
  input  logic [DATA_WIDTH/8-1:0] wstrb,
  input  logic                   wlast,

  // AXI4 Write Response Channel
  output logic                   bvalid,
  input  logic                   bready,
  output logic [ID_WIDTH-1:0]    bid,
  output logic [1:0]             bresp,

  // AXI4 Read Address Channel
  input  logic                   arvalid,
  output logic                   arready,
  input  logic [ID_WIDTH-1:0]    arid,
  input  logic [ADDR_WIDTH-1:0]  araddr,
  input  logic [LEN_WIDTH-1:0]   arlen,
  input  logic [2:0]             arsize,
  input  logic [1:0]             arburst,
  input  logic [3:0]             arqos,

  // AXI4 Read Data Channel
  output logic                   rvalid,
  input  logic                   rready,
  output logic [ID_WIDTH-1:0]    rid,
  output logic [DATA_WIDTH-1:0]  rdata,
  output logic [1:0]             rresp,
  output logic                   rlast,

  // Request output to scheduler
  output logic                   req_valid,
  input  logic                   req_ready,
  output logic                   req_is_write,
  output logic [ID_WIDTH-1:0]    req_id,
  output logic [ADDR_WIDTH-1:0]  req_addr,
  output logic [LEN_WIDTH-1:0]   req_len,
  output logic [3:0]             req_qos,
  output logic [DATA_WIDTH-1:0]  req_wdata,
  output logic [DATA_WIDTH/8-1:0] req_wstrb,
  output logic                   req_wlast,

  // Completion return path from scheduler/DRAM
  input  logic                   cpl_valid,
  input  logic                   cpl_is_write,
  input  logic [ID_WIDTH-1:0]    cpl_id,
  input  logic [DATA_WIDTH-1:0]  cpl_rdata,
  input  logic                   cpl_rlast,

  // Performance/Debug
  output logic [31:0]            perf_wr_enq,
  output logic [31:0]            perf_rd_enq,
  output logic [31:0]            perf_req_deq,
  output logic [15:0]            depth_rob,
  output logic [15:0]            depth_wbuf,
  output logic [15:0]            depth_rbuf
);

  // QoS mapping
  function automatic [1:0] map_qos(input logic [3:0] axi_qos);
    casez (axi_qos)
      4'b11??: map_qos = 2'd3; // critical
      4'b10??: map_qos = 2'd2; // high
      4'b01??: map_qos = 2'd1; // medium
      default: map_qos = 2'd0; // best-effort
    endcase
  endfunction

  typedef struct packed {
    logic                 is_write;
    logic [ID_WIDTH-1:0]  id;
    logic [ADDR_WIDTH-1:0] addr;
    logic [LEN_WIDTH-1:0] len;
    logic [1:0]           qos_class;
  } rob_entry_t;

  rob_entry_t rob      [ROB_DEPTH];
  logic [$clog2(ROB_DEPTH):0] rob_wr_ptr, rob_rd_ptr;
  logic rob_full, rob_empty;

  // Simple write data buffer (for bursts)
  typedef struct packed {
    logic [DATA_WIDTH-1:0]  data;
    logic [DATA_WIDTH/8-1:0] strb;
    logic last;
    logic valid;
    logic [ID_WIDTH-1:0] id;
  } wbuf_t;

  wbuf_t wbuf [ROB_DEPTH];
  logic [$clog2(ROB_DEPTH):0] wbuf_wr_ptr, wbuf_rd_ptr;

  // Read data buffer for returning data
  typedef struct packed {
    logic [DATA_WIDTH-1:0] data;
    logic last;
    logic valid;
    logic [ID_WIDTH-1:0] id;
  } rbuf_t;

  rbuf_t rbuf [ROB_DEPTH];
  logic [$clog2(ROB_DEPTH):0] rbuf_wr_ptr, rbuf_rd_ptr;

  // ROB status
  assign rob_full  = ((rob_wr_ptr+1'b1) == rob_rd_ptr);
  assign rob_empty = (rob_wr_ptr == rob_rd_ptr);
  assign depth_rob = rob_wr_ptr - rob_rd_ptr;
  assign depth_wbuf = wbuf_wr_ptr - wbuf_rd_ptr;
  assign depth_rbuf = rbuf_wr_ptr - rbuf_rd_ptr;

  // Enqueue write address
  assign awready = !rob_full;
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      rob_wr_ptr <= '0; perf_wr_enq <= '0;
    end else if (awvalid && awready) begin
      rob[rob_wr_ptr].is_write  <= 1'b1;
      rob[rob_wr_ptr].id        <= awid;
      rob[rob_wr_ptr].addr      <= awaddr;
      rob[rob_wr_ptr].len       <= awlen;
      rob[rob_wr_ptr].qos_class <= map_qos(awqos);
      rob_wr_ptr <= rob_wr_ptr + 1'b1;
      perf_wr_enq <= perf_wr_enq + 1'b1;
    end
  end

  // Enqueue read address
  assign arready = !rob_full;
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      perf_rd_enq <= '0;
    end else if (arvalid && arready) begin
      rob[rob_wr_ptr].is_write  <= 1'b0;
      rob[rob_wr_ptr].id        <= arid;
      rob[rob_wr_ptr].addr      <= araddr;
      rob[rob_wr_ptr].len       <= arlen;
      rob[rob_wr_ptr].qos_class <= map_qos(arqos);
      rob_wr_ptr <= rob_wr_ptr + 1'b1;
      perf_rd_enq <= perf_rd_enq + 1'b1;
    end
  end

  // Accept write data
  assign wready = (depth_wbuf != ROB_DEPTH-1);
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      wbuf_wr_ptr <= '0;
    end else if (wvalid && wready) begin
      wbuf[wbuf_wr_ptr].data  <= wdata;
      wbuf[wbuf_wr_ptr].strb  <= wstrb;
      wbuf[wbuf_wr_ptr].last  <= wlast;
      wbuf[wbuf_wr_ptr].valid <= 1'b1;
      wbuf[wbuf_wr_ptr].id    <= awid; // assumes single outstanding stream per ID when writing
      wbuf_wr_ptr <= wbuf_wr_ptr + 1'b1;
    end
  end

  // QoS-aware dequeue policy: pick highest QoS available at head window
  function automatic int pick_entry(input rob_entry_t q[$]);
    int idx_best = -1; int best_qos = -1;
    for (int i = 0; i < q.size(); i++) begin
      if (q[i].qos_class > best_qos) begin
        best_qos = q[i].qos_class; idx_best = i;
      end
    end
    return idx_best;
  endfunction

  // Build a small inspection window (up to 8 entries)
  rob_entry_t window[$];
  always_comb begin
    window.delete();
    for (int i = 0; i < 8; i++) begin
      if ((rob_rd_ptr + i) != rob_wr_ptr) begin
        window.push_back(rob[rob_rd_ptr + i]);
      end
    end
  end

  int sel_idx;
  always_comb begin
    sel_idx = pick_entry(window);
  end

  // Drive request to scheduler when available and downstream is ready
  assign req_valid   = (sel_idx >= 0) && !rob_empty;
  assign req_is_write= (sel_idx >= 0) ? window[sel_idx].is_write : 1'b0;
  assign req_id      = (sel_idx >= 0) ? window[sel_idx].id       : '0;
  assign req_addr    = (sel_idx >= 0) ? window[sel_idx].addr     : '0;
  assign req_len     = (sel_idx >= 0) ? window[sel_idx].len      : '0;
  assign req_qos     = (sel_idx >= 0) ? {2'b00, window[sel_idx].qos_class} : 4'd0;

  // For writes, provide data from wbuf head when available
  assign req_wdata   = wbuf[wbuf_rd_ptr].data;
  assign req_wstrb   = wbuf[wbuf_rd_ptr].strb;
  assign req_wlast   = wbuf[wbuf_rd_ptr].last;

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      rob_rd_ptr <= '0; wbuf_rd_ptr <= '0; perf_req_deq <= '0;
    end else if (req_valid && req_ready) begin
      // Advance ROB by removing the selected entry (compact by moving head forward)
      // For simplicity, if sel_idx>0, rotate entries: production design may use heap/priority queue
      rob_entry_t tmp;
      for (int i = 0; i < sel_idx; i++) begin
        tmp = rob[rob_rd_ptr + i];
        rob[rob_rd_ptr + i] = rob[rob_rd_ptr + i + 1];
        rob[rob_rd_ptr + i + 1] = tmp;
      end
      rob_rd_ptr <= rob_rd_ptr + 1'b1;
      if (req_is_write) begin
        wbuf[wbuf_rd_ptr].valid <= 1'b0; // consumed
        wbuf_rd_ptr <= wbuf_rd_ptr + 1'b1;
      end
      perf_req_deq <= perf_req_deq + 1'b1;
    end
  end

  // Completions: build responses
  // Writes: emit B channel
  typedef enum logic [1:0] {OKAY=2'b00, SLVERR=2'b10} resp_e;
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      bvalid <= 1'b0; bid <= '0; bresp <= OKAY;
    end else if (!bvalid || (bvalid && bready)) begin
      if (cpl_valid && cpl_is_write) begin
        bvalid <= 1'b1; bid <= cpl_id; bresp <= OKAY;
      end else begin
        bvalid <= 1'b0;
      end
    end
  end

  // Reads: fill rbuf and stream on R channel
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      rbuf_wr_ptr <= '0; rbuf_rd_ptr <= '0; rvalid <= 1'b0; rlast <= 1'b0; rresp <= OKAY; rid <= '0; rdata <= '0;
    end else begin
      if (cpl_valid && !cpl_is_write) begin
        rbuf[rbuf_wr_ptr].data  <= cpl_rdata;
        rbuf[rbuf_wr_ptr].last  <= cpl_rlast;
        rbuf[rbuf_wr_ptr].valid <= 1'b1;
        rbuf[rbuf_wr_ptr].id    <= cpl_id;
        rbuf_wr_ptr <= rbuf_wr_ptr + 1'b1;
      end
      if ((!rvalid || (rvalid && rready)) && (rbuf_rd_ptr != rbuf_wr_ptr) && rbuf[rbuf_rd_ptr].valid) begin
        rvalid <= 1'b1;
        rdata  <= rbuf[rbuf_rd_ptr].data;
        rlast  <= rbuf[rbuf_rd_ptr].last;
        rid    <= rbuf[rbuf_rd_ptr].id;
        rbuf[rbuf_rd_ptr].valid <= 1'b0;
        rbuf_rd_ptr <= rbuf_rd_ptr + 1'b1;
      end else if (rvalid && !rready) begin
        // hold
      end else begin
        rvalid <= 1'b0;
      end
    end
  end

endmodule
