// ddr5_env_config.sv - Configuration object for DDR5 UVM env
class ddr5_env_config extends uvm_object;
  `uvm_object_utils(ddr5_env_config)

  // AXI params
  int unsigned axi_addr_width = 32;
  int unsigned axi_data_width = 512;
  int unsigned axi_id_width   = 8;

  // DFI params
  int unsigned dfi_data_width = 512;

  // Feature enables
  bit enable_ecc      = 1;
  bit enable_qos      = 1;
  bit enable_security = 1;
  bit enable_asserts  = 1;

  // Runtime knobs
  int unsigned max_outstanding = 32;
  int unsigned max_burst_len   = 16;

  // Virtual interfaces
  virtual axi_if vif_axi;
  virtual dfi_if vif_dfi;

  function new(string name = "ddr5_env_config");
    super.new(name);
  endfunction
endclass
