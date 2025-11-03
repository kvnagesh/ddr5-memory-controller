# DDR5 Protocol Layer Review vs AMD Integrated DDR5 Controller (PG456)

This review compares the current `rtl/common/ddr5_protocol_layer.sv` against AMD PG456/UG1273/AM011 feature set for the Versal DDR5/LPDDR5/LPDDR5X Integrated Memory Controller. Status per feature is marked as: Fully Compliant (FC), Partially Compliant (PC), or Missing (M). Detailed step-by-step improvements are listed for each shortfall.

References: PG456 Feature Summary; UG1273 DDR Controller overview; AM011 DDR5 Enhanced Memory Controller notes.

| Feature | AMD PG456 Expectation | Current Implementation Evidence | Status | Gaps | Step-by-step Improvements |
|---|---|---|---|---|---|
| Protocols / Config | DDR5 and LPDDR5/LPDDR5X; BL16 fixed; DFI ratio; component/SO/UDIMM | Parameter MEM_STD supports DDR5/LPDDR5/LPDDR5X; local BL param; DFI interface with ratio. | PC | Topology selection not surfaced; BL fixed not enforced in scheduler; no rank/slot handling. | 1) Add topo params: MODULE_TYPE (COMP, UDIMM, SODIMM), RANKS, SLOTS. 2) Enforce BL16 in command scheduler and data pipeline alignment. 3) Add timing tables per device type (1N/2N). 4) Validate DFI ratio constraints at compile-time and assert at run-time. |
| Channels | Single and dual channel up to x16 each | Single instance; no explicit multi-channel fabric | M | No multi-channel instantiation or cross-channel arb. | 1) Wrap protocol layer in channel generator (N_CHANNELS param). 2) Add per-channel schedulers and a crossbar/onion bus. 3) Provide interleave policies (addr bit swizzle). 4) Expose AXI port mapping to channels with QoS classes. |
| Data Width / ECC | Up to x32, or x40 for sideband ECC; inline ECC option; sideband 4/8-bit for DDR5 | Parameter DATA_BYTES and ENABLE_ECC=1, but no ECC datapath or syndrome | M | No SEC-CRC encode/decode, scrub, error injection | 1) Add ECC mode param: ECC_MODE={NONE, SIDEBAND4, SIDEBAND8, INLINE}. 2) Integrate SEC-CRC encoder on write, decoder on read with syndrome reporting. 3) Add error injection registers (per PG456). 4) Implement background and on-the-fly scrubbing FSM. 5) Wire error counters and logging (correctable/uncorrectable). |
| Security / Encryption | AES-GCM/AES-XTS, hardware masking, XMPU-like access control | None visible | M | No crypto, no MPU | 1) Add optional encrypt/decrypt stage with AES-GCM/AES-XTS cores; select per region via key slot regs. 2) Add address-range protection unit (MPU) with R/W/X, secure attributes and AXI ID filters. 3) Side-channel masking enable for crypto data paths. 4) Key management registers with zeroize and versioning. |
| RDIMM/Topology Features | Command/Addr parity (RDIMM), 1N/2N timing; dual-rank, dual-slot support | No RDIMM parity, ranks, or timing multiplier | M | No CA parity gen/check; no rank timing | 1) Add CA parity bit generation for RDIMM and parity error handling. 2) Add rank/slot abstraction in scheduler (open-page per rank, tFAW, tRRD_S/L constraints per DIMM). 3) Implement 1N/2N timing selection affecting command spacing. 4) MRS programming tables per topology. |
| AXI Interface and Hazards | AXI4 ports, AXI ID ordering; RAW/WAW hazard checks; QoS classes | Front-end is custom mem_cmd_s; ENABLE_QOS=1 but unused; simple accept in IDLE; mentions AXI ordering but not implemented | M | No AXI interface; no ID ordering; no hazard checks | 1) Add AXI4 slave interface(s) with ID, burst, size, lock, qos. 2) Implement reorder buffers per ID with fences to preserve AXI ID ordering. 3) Add RAW/WAW/REF hazards: row/bank trackers, read-after-write forwarding or bubbles, write-drain policy. 4) Map AXI QoS to read/write classes (Isochronous/LL/BE) with queues and age/cut-through rules. |
| Command Scheduler | Out-of-order scheduling for efficiency; QoS classes; write leveling for power/latency | Finite-state immediate issue; no OOO; have_cmd single-entry; timing placeholders | M | No bank machine, no tXX timing checks, no queues | 1) Implement bank machines (per bank group) with timing state (tRCD, tRP, tRAS, tRC, tCCD_S/L, tRRD_S/L, tFAW, tWTR, tRTW, tWR, tRTP). 2) Add per-class queues and OOO pickers (row-hit first with starvation prevention). 3) Add write-coalescing and write-drain thresholds to manage bus turnaround. 4) Enforce command spacing per 1N/2N and BL16. 5) Sim hooks for efficiency KPI (row-hit rate, turnaround, bandwidth). |
| Calibration / Training | Enhanced calibration; write leveling, Vref, read gate; PHY handshakes | lvl/vref/gate req/ack hooks present; S_MRW training stage | PC | No training microcode, no timing to MRW sequences, no PHY-specific timing | 1) Add training micro-sequencer with per-standard scripts (DDR5, LPDDR5/X). 2) Implement MRW sequences with delays (tMOD, tMRD). 3) Track per-lane results and expose via status regs. 4) Add retry/timeout and error codes for failed training. 5) Drive DFI training opcodes/CS/CK gating as PHY requires. |
| Refresh | 1x/2x/4x refresh for DDR5; 2x FGR; same-bank refresh; refresh management | S_REF state issues REF when requested; no scheduler-level management | M | No PB/SB refresh, no throttling or deferral | 1) Add refresh manager with counters supporting 1x/2x/4x and 2x FGR. 2) Implement same-bank refresh (DDR5) policy and integrate with bank machines to avoid conflicts. 3) Allow refresh deferral and pull-in within JEDEC windows with credit accounting. 4) Stats: refresh credits, deferrals, violations. |
| Error Logging / Telemetry | Correctable/uncorrectable logs; counters; address capture | fatal_err_code hardwired 0x00 | M | No logging infra | 1) Add error log CSR block: CE/UE counters, last N events with address/bank/row/column, syndrome, source (ECC/Parity/CMD). 2) Add interrupt lines and mask registers. 3) Performance counters: bandwidth per class, latency histograms, queue depths. |
| Data Bus Features (DBI/DM/CRC) | Data Mask, Dynamic Bus Inversion, CRC/ECC behaviors | Not present; write data placeholder | M | No DBI/DM handling | 1) Add DBI enable with per-byte inversion on write; reverse on read. 2) LPDDR5 DM support mapping from AXI strobe. 3) Ensure SEC-CRC/ECC interplay with DBI. |
| Bandwidth/Latency | High efficiency; QoS; OOO; multi-port; turnaround optimization | Minimal FSM cannot reach high BW | M | Missing all perf mechanisms | 1) Implement read-write grouping, write drain thresholds. 2) Add speculative activate to hot rows. 3) Bank-group aware scheduling to avoid tCCD_L penalties. 4) AXI burst coalescing and address interleave. 5) Backpressure control to avoid head-of-line blocking. |
| Testbench / Verification | Error injection; scrub; calibration coverage; traffic classes; compliance | No TB shown | M | No verification infra in repo file | 1) Build SV/UVM environment with AXI VIP, DFI/PHY model. 2) Add JEDEC timing checks and assertion library. 3) Provide ECC error injection tests, refresh corner cases, training timeouts. 4) Add coverage for QoS arbitration and hazard cases. |
| Power/Clocking | Operates at half DRAM rate; power-down/self-refresh control | DFI_RATIO param; no power states | M | No power mgmt | 1) Implement power-down, self-refresh entry/exit sequences. 2) Clock gating for scheduler when idle. 3) Thermal throttling hooks. |

Additional Detailed Notes
- DFI Interface: The interface is present with ready/valid semantics; add explicit mapping to DFI 5.0 command fields (CS, ACT_n, RAS/CAS/WE equivalents via CA encoding) and timing for tCMD and 1N/2N.
- Initialization: S_INIT→S_MRW gating exists; expand with JEDEC DDR5 init: reset, CKE sequence, MR writes order, ZQCAL, tZQinit, DRAM Vref training, WCK training for LPDDR5/X.
- Address Mapping: Add user-configurable address map (row/col/bank/bank-group/channel) to maximize bank parallelism and align with DIMM topology.
- Safety/FUSA: If targeting AMD DDRMC5E-like feature set, add safety monitors, diagnostic test modes, parity coverage, and error pinouts.

Implementation Plan (Phased)
1) Infrastructure: AXI4 front-end, CSR/IPIF block, register map, clock/reset/power states.
2) Bank Machines and Timers: JEDEC timing database and per-bank state. Add OOO arbiter and QoS.
3) ECC + Logging: Integrate SEC-CRC engines, logs, interrupts, injection, scrub.
4) Refresh Manager: PB/SB, FGR, deferral, telemetry.
5) Training Sequencer: Scripts, retries, PHY hooks, status.
6) Security: AES-GCM/XTS data path, MPU, keys.
7) DBI/DM/Parity: Bus features; RDIMM parity.
8) Performance Tuning: Write drain, grouping, speculative activate, interleave.
9) Verification: UVM testbench, checkers, coverage, regressions.

Summary
- Current file establishes a portable, parameterized skeleton with DFI hooks and basic state flow (good foundation) but lacks most of PG456 production features. The improvement plan above brings it to parity with AMD DDR5 controller capabilities in stages.

References
- AMD PG456 Integrated DDR5/LPDDR5/5X Memory Controller, Feature Summary.  
- UG1273 DDR Controller overview (Versal).  
- AM011 TRM DDR5 Enhanced Memory Controller notes.
