// ddr5_test_pkg.sv - UVM package for DDR5 testbench
package ddr5_test_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Forward includes of environment and components
  `include "env/ddr5_env_config.sv"
  `include "env/ddr5_scoreboard.sv"
  `include "env/ddr5_env.sv"

  // AXI Agent
  `include "agents/axi/axi_seq_item.sv"
  `include "agents/axi/axi_sequencer.sv"
  `include "agents/axi/axi_driver.sv"
  `include "agents/axi/axi_monitor.sv"
  `include "agents/axi/axi_agent.sv"

  // DFI Agent
  `include "agents/dfi/dfi_seq_item.sv"
  `include "agents/dfi/dfi_sequencer.sv"
  `include "agents/dfi/dfi_driver.sv"
  `include "agents/dfi/dfi_monitor.sv"
  `include "agents/dfi/dfi_agent.sv"

  // Checkers and Assertions
  `include "checkers/ddr5_protocol_checker.sv"
  `include "checkers/ddr5_assertions.sv"

  // Sequences
  `include "sequences/ddr5_base_sequence.sv"
  `include "sequences/axi_sequences.sv"
  `include "sequences/ecc_test_sequences.sv"
  `include "sequences/qos_test_sequences.sv"
  `include "sequences/ordering_test_sequences.sv"
  `include "sequences/refresh_test_sequences.sv"
  `include "sequences/security_test_sequences.sv"
  `include "sequences/corner_case_sequences.sv"

  // Tests
  `include "tests/ddr5_base_test.sv"
  `include "tests/ddr5_sanity_test.sv"
  `include "tests/ddr5_ecc_test.sv"
  `include "tests/ddr5_qos_test.sv"
  `include "tests/ddr5_ordering_test.sv"
  `include "tests/ddr5_refresh_test.sv"
  `include "tests/ddr5_security_test.sv"
  `include "tests/ddr5_stress_test.sv"

endpackage : ddr5_test_pkg
