# REVIEW: DDR5 Controller vs AMD Integrated DDR5 (PG456) — Action Plan to Match and Exceed

Scope
- Goal: Elevate this DDR5 controller to match and beat AMD PG456-class DDR5 controller capabilities (Versal DDR5/LPDDR5/X family) in bandwidth, latency, robustness, safety, debug, and testability.
- Method: Per feature, provide concrete architecture recommendations and step-by-step action checklists. Where AMD specifies features, we target parity first, then exceed with deeper pipelining, smarter scheduling, telemetry, and resilience.
- Evidence Base: Public AMD docs (PG456, UG1273-like summaries). No AMD proprietary details are included.

Legend
- Status: FC = Fully Compliant, PC = Partially Compliant, M = Missing (relative to PG456-class features)

Top-Level Architecture Actions (cross-cutting)
- Introduce a multi-channel, bank-machine-based OOO scheduler with QoS classes, timing wheels, and performance counters.
- Add AXI4 front-end with reorder buffers, ID-ordering per AXI spec, and class-based queues.
- Implement full DDR5 timing database and per-bank/group timing trackers.
- Add comprehensive ECC+logging, refresh manager, training sequencer, security/MPU, and DBI/Parity/DM.
- Build UVM environment with coverage-driven verification and performance validation.

1) Protocol, Configuration, Topology [Status: PC]
Action checklist
- Add parameters: MEM_STD{DDR5,LPDDR5,LPDDR5X}, MODULE_TYPE{COMP,UDIMM,SODIMM,RDIMM}, RANKS, SLOTS, DFI_RATIO, BL=16 enforced.
- Create device/topology timing profile tables (1N/2N, rank-to-rank, DIMM-specific tFAW/tRRD_S/L).
- Provide address map configurability (row/col/bank/bank-group/channel) with presets for DIMMs to maximize parallelism.
- Build CSR block to select profiles and lock with a “config committed” bit.

2) AXI Interface, Ordering, Hazards, QoS [Status: M]
Architecture
- AXI4 slave ports: up to N ports, each with ID space and QoS field; optional cache/region hints.
- Reorder buffers per ID to enforce ID-ordering; global OOO across IDs allowed.
- Class-based ingress queues: Isochronous (Iso), Low-Latency (LL), Best-Effort (BE); starvation prevention via aging.
- Hazard tracking: row/bank trackers, RAW/WAW detection, read-after-write forwarding buffer.
Action checklist
- Implement AXI4 port(s) with full signals (AW/AR/W/R/B), bursts up to 256 beats, narrow/wide handling.
- Build ID-to-ROB allocation; introduce fence/Barrier recognition (AWBAR/ARBAR via sideband CSR if needed).
- Map AXI QoS to classes; implement age-based priority lift and queue depth watermarks.
- Add write-combine and write-drain policies; expose knobs via CSR (low/high thresholds, hysteresis).
- Provide backpressure control to avoid HoL blocking; implement credits towards scheduler.
- Add protocol checkers and assertions for AXI ordering and response codes.

3) Command Scheduler, OOO, Timing Engine [Status: M]
Architecture
- Per-bank machine (PBM) per bank, grouped by bank-group for tCCD_S/L awareness.
- Timing engine with token/timer wheels that enforce tRCD,tRAS,tRC,tRP,tCCD_S/L,tRRD_S/L,tFAW,tWTR,tRTW,tWR,tRTP,tRFC,tREFI, 1N/2N.
- Row-policy: open-page row-hit-first with anti-starvation; speculative ACT for hot rows.
Action checklist
- Implement PBMs with state: closed/open row, timers, pending ops.
- Add global picker: prioritize row-hits, then aged LL/Iso, then BE; respect bank-group penalties.
- Add speculative ACT: track hot rows by history table; cancel if conflict or window expires.
- Enforce BL16 alignment in data pipeline and cmd spacing.
- Expose knobs: row-hit bias %, max queue age, speculative window, write-drain threshold, grouping size.

4) Refresh Management (All Types) [Status: M]
Architecture
- Central refresh manager with counters for 1x/2x/4x refresh; fine granularity refresh (FGR 2x) and same-bank refresh (SBR) for DDR5.
- Deferral/pull-in within JEDEC windows using credit accounting; coordinate with PBMs to minimize interruptions.
Action checklist
- Implement PB/SB refresh support; select SBR where beneficial to limit impact to active banks.
- Integrate refresh requests with scheduler: preemptible windows, refuse when harmful, re-issue with credits.
- Track stats: deferrals, pull-ins, violations; expose via CSRs and interrupts.

5) Calibration / Training [Status: PC]
Architecture
- Training micro-sequencer running scripts for write leveling, read gate, read/write Vref, WCK/CK alignment (LPDDR5/X as applicable), with PHY handshakes.
Action checklist
- Implement sequencer with MRW programming and timed waits (tMOD,tMRD,tDLLK,tZQinit).
- Per-lane result capture; retry with bounded attempts; error codes on failure.
- DFI training opcodes and CS/CK gating as required by PHY; expose progress/status.

6) ECC, CRC, Scrubbing, Logging [Status: M]
Architecture
- Modes: ECC_MODE{NONE, SIDEBAND4, SIDEBAND8, INLINE}. SEC-DED with optional CRC or SEC-CRC per data slice.
- Background scrubber and on-access correction; error injection framework.
Action checklist
- Integrate encoder on write path and decoder on read path; surface syndrome, CE/UE flags.
- Implement error log RAM (ring): timestamp, addr, bank/row/col, syndrome, source; CE/UE counters.
- Add interrupt/mask and “first-fail capture.”
- Add scrub FSM with bandwidth cap; track scrub coverage and rates.

7) Data Bus Features: DBI/DM/Parity [Status: M]
Action checklist
- Implement write DBI generation per byte; read DBI reverse; ensure ECC interworking.
- LPDDR5 DM handling from AXI WSTRB; parity generation/check for RDIMM CA.
- Add CA parity error reporting, counters, and fault policy (retry/log/interrupt).

8) RDIMM/Topology, 1N/2N, Ranks/Slots [Status: M]
Action checklist
- Implement rank/slot models: per-rank timing offsets, rank-to-rank switching penalties.
- 1N/2N timing multiplier selection impacting cmd spacing.
- MRS tables per topology with safe presets and overrides.

9) Power Management and Thermal Hooks [Status: M]
Action checklist
- Implement self-refresh and power-down entry/exit sequences with JEDEC timing.
- Idle clock gating of scheduler and front-end; light/deep power states policy.
- Thermal throttling hooks via CSR (reduce issue rate, cap bandwidth) and sensors input.

10) Security: Encryption and MPU [Status: M]
Action checklist
- Optional AES-GCM/AES-XTS datapaths selectable per region; key slots with zeroize.
- XMPU-like address-range protection with R/W/X, secure/non-secure, AXI ID filters, violation logging.
- Side-channel masking option for crypto blocks; performance counters for crypto stalls.

11) Performance Targets and Exceeding AMD
Targets
- Bandwidth: ≥95% of theoretical with mixed traffic; ≥98% for streaming.
- Latency: minimize 50th/95th percentiles for LL class; bounded tail.
Exceed strategies
- Deeper pipelining in front-end and scheduler to accept ≥2 cmds/cycle under load.
- Bank-group-aware reordering to avoid tCCD_L penalties; speculative ACT with correctness guards.
- Smarter write-drain with dynamic thresholds and look-ahead based on read arrival predictions.
- Burst coalescing at AXI layer; adaptive interleave across channels/banks using address swizzle.
- Rich telemetry: per-class bandwidth, latency histograms, row-hit ratio, turnaround counters; feedback-driven tuning.

12) Debuggability, Telemetry, and Testability [Status: M]
Action checklist
- Add comprehensive counters: issued/served per class, queue depth histos, timing stall reasons, refresh impact, write-drain events, speculative success rate.
- Event trace FIFO with triggers (e.g., latency > threshold, ECC UE) and time-stamping.
- CSR readout with snapshot/clear mechanisms; firmware driver examples.
- Built-in self-test modes: pattern generators, loopback, error-injection toggles.

13) Verification (UVM) [Repo has uvm_tb — strengthen to coverage goals] [Status: PC]
Planned environment
- Agents: AXI VIP, DFI/PHY model, Error injector, Thermal/power hooks.
- Scoreboard: functional, timing compliance; performance scoreboards for BW/latency vs model.
Action checklist
- Complete sequences: QoS arbitration, OOO reordering, hazards (RAW/WAW), refresh deferral/pull-in, ECC CE/UE, DBI/DM, CA parity, training retries, security violations.
- Add SVA: JEDEC timing (all tXX), AXI ordering, ECC correctness, refresh windows, power-state sequencing.
- Coverage goals: Code>95%, Functional>98%, Assertions=100%, Perf bins covering bandwidth/latency/turnaround regimes.
- Regression tiers: sanity, feature, stress, perf, power/refresh, security, error-injection.

14) Interfaces to PHY (DFI 5.x alignment) [Status: PC]
Action checklist
- Explicit mapping of scheduler outputs to DFI CA/CS/ACT_n encodings and data strobes; 1N/2N timing.
- Lane repair hooks; training status handshake; DFI status/error propagation to logs.

15) Firmware/CSR Map [Status: M]
Action checklist
- Define CSR map: config profiles, QoS knobs, write-drain thresholds, speculative enable, refresh credits, ECC logs, perf counters, interrupts, security/MPU, scrub controls, thermal throttles.
- Provide Linux driver/HAL examples and perf tools for telemetry.

Phased Implementation Plan
- Phase 0: CSR/IPIF, address map, basic AXI shell; compile-time timing tables; BL16 enforcement.
- Phase 1: PBMs + timing engine + OOO picker + QoS queues; minimal counters.
- Phase 2: ECC/SEC-DED + logging + interrupts + error injection + scrubber.
- Phase 3: Refresh manager (PB/SB/FGR) + deferral/pull-in + telemetry; power states.
- Phase 4: Training micro-sequencer + PHY hooks + robust status + retries.
- Phase 5: Security (AES-GCM/XTS) + MPU + key mgmt; DBI/DM + RDIMM CA parity.
- Phase 6: Performance tuning (speculative ACT, dynamic write-drain, interleave) + deep counters + event trace.
- Phase 7: Verification expansion to full coverage with perf scoreboards and regressions.

Acceptance and Success Metrics
- Functional parity with AMD feature list; all timing SVA clean on random and stressed traffic.
- Perf: Streaming BW ≥98% theoretical; mixed BW ≥95%; LL P95 latency improved ≥10% vs baseline.
- Resilience: ECC CE/UE handling verified; refresh deferral without violations; security violations logged and contained.
- Debug: Telemetry usable to root-cause issues within 10 minutes under lab conditions.

References
- AMD PG456 Integrated DDR5/LPDDR5/LPDDR5X Memory Controller (feature summary, public docs).
- AMD/Versal DDR Controller overviews (UG-class docs).
- JEDEC DDR5/LPDDR5 specifications for timing definitions.
