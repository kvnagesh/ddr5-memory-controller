// ddr5_env.sv - Top-level UVM environment
class ddr5_env extends uvm_env;
  `uvm_component_utils(ddr5_env)

  // Config
  ddr5_env_config cfg;

  // Agents
  axi_agent    m_axi_agent;
  dfi_agent    m_dfi_agent;

  // Scoreboard
  ddr5_scoreboard m_scb;

  // Protocol checker
  ddr5_protocol_checker m_checker;

  // Analysis exports
  uvm_analysis_export #(axi_seq_item) axi_ap_export;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ddr5_env_config)::get(this, "", "cfg", cfg)) begin
      cfg = ddr5_env_config::type_id::create("cfg");
      void'(uvm_config_db#(virtual axi_if)::get(this, "", "vif_axi", cfg.vif_axi));
      void'(uvm_config_db#(virtual dfi_if)::get(this, "", "vif_dfi", cfg.vif_dfi));
    end

    // Set VIFs to agents
    uvm_config_db#(virtual axi_if)::set(this, "m_axi_agent*", "vif", cfg.vif_axi);
    uvm_config_db#(virtual dfi_if)::set(this, "m_dfi_agent*", "vif", cfg.vif_dfi);

    m_axi_agent = axi_agent   ::type_id::create("m_axi_agent", this);
    m_dfi_agent = dfi_agent   ::type_id::create("m_dfi_agent", this);
    m_scb       = ddr5_scoreboard::type_id::create("m_scb", this);

    if (cfg.enable_asserts)
      m_checker  = ddr5_protocol_checker::type_id::create("m_checker", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Connect AXI monitor to scoreboard
    m_axi_agent.ap.connect(m_scb.axi_in);
    // Connect DFI monitor to scoreboard/checker
    m_dfi_agent.ap.connect(m_scb.dfi_in);
    if (m_checker!=null) begin
      m_dfi_agent.ap.connect(m_checker.dfi_in);
      m_axi_agent.ap.connect(m_checker.axi_in);
    end
  endfunction

endclass: ddr5_env
