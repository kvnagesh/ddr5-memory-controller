# DDR5 Memory Controller UVM Testbench

## Overview

This directory contains a production-grade UVM testbench for verifying the DDR5 Memory Controller. The testbench provides comprehensive verification coverage for all features including DFI interface, AXI interface, ECC protection, QoS management, out-of-order execution, refresh operations, security features, and error handling.

## Directory Structure

```
uvm_tb/
├── README.md                          # This file
├── ddr5_tb_top.sv                     # Top-level testbench module
├── ddr5_test_pkg.sv                   # Test package
├── env/
│   ├── ddr5_env.sv                    # Top-level environment
│   ├── ddr5_env_config.sv             # Environment configuration
│   └── ddr5_scoreboard.sv             # Scoreboard for checking
├── agents/
│   ├── axi/
│   │   ├── axi_agent.sv               # AXI agent
│   │   ├── axi_sequencer.sv           # AXI sequencer
│   │   ├── axi_driver.sv              # AXI driver
│   │   ├── axi_monitor.sv             # AXI monitor
│   │   └── axi_seq_item.sv            # AXI sequence item
│   └── dfi/
│       ├── dfi_agent.sv               # DFI agent
│       ├── dfi_sequencer.sv           # DFI sequencer
│       ├── dfi_driver.sv              # DFI driver (for DFI slave)
│       ├── dfi_monitor.sv             # DFI monitor
│       └── dfi_seq_item.sv            # DFI sequence item
├── sequences/
│   ├── ddr5_base_sequence.sv          # Base sequence class
│   ├── axi_sequences.sv               # AXI sequence library
│   ├── ecc_test_sequences.sv          # ECC verification sequences
│   ├── qos_test_sequences.sv          # QoS verification sequences
│   ├── ordering_test_sequences.sv     # Out-of-order test sequences
│   ├── refresh_test_sequences.sv      # Refresh operation sequences
│   ├── security_test_sequences.sv     # Security feature sequences
│   └── corner_case_sequences.sv       # Corner case scenarios
├── tests/
│   ├── ddr5_base_test.sv              # Base test class
│   ├── ddr5_sanity_test.sv            # Basic sanity test
│   ├── ddr5_ecc_test.sv               # ECC feature tests
│   ├── ddr5_qos_test.sv               # QoS feature tests
│   ├── ddr5_ordering_test.sv          # Out-of-order execution tests
│   ├── ddr5_refresh_test.sv           # Refresh operation tests
│   ├── ddr5_security_test.sv          # Security feature tests
│   └── ddr5_stress_test.sv            # Stress and corner case tests
├── checkers/
│   ├── ddr5_protocol_checker.sv       # Protocol compliance checker
│   └── ddr5_assertions.sv             # SVA property assertions
└── sim/
    ├── Makefile                       # Simulation Makefile
    └── run.do                         # ModelSim/Questa run script
```

## Features Verified

### 1. **DFI (DDR PHY Interface)**
   - Command interface timing
   - Data interface protocol
   - Command/address parity
   - DFI status signals
   - Initialization sequences

### 2. **AXI Interface**
   - AXI4 protocol compliance
   - Read/write transactions
   - Outstanding transaction handling
   - Address alignment and wrapping
   - Response handling (OKAY, SLVERR, DECERR)

### 3. **ECC (Error Correction Code)**
   - Single-bit error correction
   - Double-bit error detection
   - ECC encoding/decoding
   - Error injection and recovery
   - Error logging and reporting

### 4. **QoS (Quality of Service)**
   - Priority-based arbitration
   - Bandwidth allocation
   - Latency optimization
   - Traffic class management
   - Real-time vs. best-effort traffic

### 5. **Out-of-Order Execution**
   - Transaction reordering
   - Bank conflict resolution
   - Page hit/miss optimization
   - Write-to-read turnaround
   - Read-after-write hazards

### 6. **Refresh Operations**
   - Auto-refresh timing
   - Self-refresh entry/exit
   - Refresh management (RFM)
   - Per-bank refresh
   - Command blocking during refresh

### 7. **Security Features**
   - Secure region protection
   - Access control verification
   - Data scrambling/descrambling
   - Security violation detection

### 8. **Error Handling**
   - Parity errors
   - CRC errors
   - Timeout handling
   - Protocol violations
   - Recovery mechanisms

## Getting Started

### Prerequisites

- UVM 1.2 or later
- SystemVerilog simulator (Questa/VCS/Xcelium)
- DDR5 memory model (not included)
- Make utility

### Compilation

```bash
cd sim
make compile
```

### Running Tests

```bash
# Run specific test
make run TEST=ddr5_sanity_test

# Run with GUI
make run TEST=ddr5_ecc_test GUI=1

# Run with coverage
make run TEST=ddr5_stress_test COV=1

# Run all tests
make regression
```

### Waveform Debug

```bash
make wave TEST=ddr5_qos_test
```

## Configuration

The testbench is highly configurable through `ddr5_env_config.sv`:

- **Memory Configuration**: Size, width, timing parameters
- **Interface Configuration**: AXI/DFI widths, frequencies
- **Feature Enable/Disable**: ECC, QoS, Security, etc.
- **Checker Control**: Enable/disable specific checkers
- **Coverage Control**: Functional and code coverage options

## Extending the Testbench

### Adding New Sequences

1. Extend from `ddr5_base_sequence`
2. Implement your sequence logic in `body()` task
3. Add to appropriate sequence library file
4. Register with the factory

### Adding New Tests

1. Extend from `ddr5_base_test`
2. Override `build_phase()` to configure environment
3. Override `run_phase()` to start your sequences
4. Add to test list in Makefile

### Adding New Checkers

1. Create checker module/class
2. Instantiate in environment or monitor
3. Connect to appropriate interfaces/analysis ports
4. Add enable/disable control in config

## Verification Methodology

### Layered Architecture

```
┌─────────────────────────────────────────┐
│           Test Layer                    │
│  (Scenarios, Sequences, Constraints)    │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│         Environment Layer               │
│  (Env, Scoreboard, Checkers, Coverage)  │
└─────────────┬───────────┬───────────────┘
              │           │
    ┌─────────▼─────┐ ┌──▼──────────┐
    │  AXI Agent    │ │  DFI Agent  │
    │  (Seq/Drv/Mon)│ │ (Seq/Drv/Mon)│
    └───────┬───────┘ └──┬──────────┘
            │            │
    ┌───────▼────────────▼──────────┐
    │   DDR5 Memory Controller DUT  │
    └───────────────────────────────┘
```

### Verification Plan

1. **Protocol Verification**: Ensure DFI and AXI protocol compliance
2. **Functional Verification**: Verify all controller features
3. **Performance Verification**: Check bandwidth, latency, QoS
4. **Stress Testing**: Corner cases, back-to-back operations
5. **Error Injection**: Validate error detection and recovery
6. **Power Management**: Verify refresh and power-down modes

## Coverage Goals

- **Code Coverage**: > 95%
- **Functional Coverage**: > 98%
- **Assertion Coverage**: 100%

## Assertions

The testbench includes comprehensive SVA assertions for:

- Protocol compliance (AXI, DFI)
- Timing constraints
- Data integrity
- State machine transitions
- Command/address ordering
- Refresh timing
- ECC correctness

## Debug Features

- Transaction logging with verbosity control
- Waveform markers for key events
- Error injection hooks
- Runtime configuration changes
- Scoreboard detailed comparison

## Known Limitations

- DDR5 memory model must be provided separately
- Some timing checks assume ideal PHY behavior
- Maximum supported AXI data width: 512 bits

## Contributing

When adding new features to the testbench:

1. Follow UVM coding guidelines
2. Add appropriate comments and documentation
3. Include self-checking mechanisms
4. Update this README
5. Add test cases for new features

## Contact

For questions or issues, please refer to the main repository.

## License

Refer to the main repository LICENSE file.
