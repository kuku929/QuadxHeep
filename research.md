---
title: UGRC Research Report — Hardware Processing Engines on FPGA
author: Krutarth Patel (EE23B137)
supervisors: Dr. Gopalakrishnan Srinivasan, Dr. Karthik Sankaranarayanan, Prof. Nitin Chandrachoodan
date: May 2026
---

# Research Report: Evaluating Hardware Processing Engine Platforms for FPGA Deployment

## Abstract

This report documents the research conducted over approximately three months (February–May 2026) as part of the UGRC project at IIT Madras. The goal was to identify and evaluate an open-source hardware platform capable of running a Hardware Processing Engine (HWPE) on an FPGA, and to then use a software toolchain to compile and execute benchmarks on it. Three broad platform families were investigated: Google Coral NPU, the PULP Platform (PULPissimo and a range of alternative PULP-derived platforms) and X-HEEP extended with the Quadrilatero systolic-array co-processor. The project concluded with a working simulation of X-HEEP+Quadrilatero executing matrix-multiply and convolution workloads, a fixed RTL bug in Quadrilatero's handshake logic, and a generated FPGA bitstream ready for hardware testing.

---

## 1. Introduction

The broad research question was: *Can a modern, open-source RISC-V SoC be extended with a hardware accelerator, programmed using a software toolchain, and demonstrated on an FPGA?*

The motivation was the growing relevance of Hardware Processing Engines in embedded AI — accelerators that offload matrix-heavy operations from the CPU while remaining tightly coupled to a microcontroller. The project explored whether a researcher with standard lab resources (commodity FPGA, open-source EDA tools) could set up such a system end-to-end.

The constraint driving platform selection throughout was **FPGA support**: the platform had to be synthesisable on available boards (primarily the Nexys-A7 family and Genesys2) and had to have an associated software toolchain.

---

## 2. Platform 1: Google Coral NPU

**Period:** February 2026

### Background

Google's Coral is an edge AI hardware ecosystem built around a purpose-built Neural Processing Unit (NPU). It provides pre-compiled TensorFlow Lite models and a Python API, making it attractive for rapid prototyping of neural network inference on embedded hardware.

### Trial

The first month of the project was spent evaluating Coral as a candidate platform. The NPU was examined for its ability to support custom workloads and its compatibility with FPGA-based deployment flows.

### Issues Faced

- **Developmental stage:** The software ecosystem was still maturing, with limited documentation for anything beyond the standard TFLite-to-Coral flow.
- **No FPGA support:** Coral is a proprietary ASIC; there is no RTL netlist or synthesis flow available. Deploying or simulating the NPU on an FPGA is not possible.
- **Closed architecture:** The internal microarchitecture of the NPU is not documented, making it impossible to extend or study in a research context.
- **No custom ISA support:** Adding custom instructions or interfacing a custom accelerator is not supported.

### Resolution

Coral was abandoned. The platform does not satisfy the core requirement of FPGA deployability or extensibility. The project pivoted to the open-source PULP ecosystem, which is specifically designed for research into embedded processing and hardware accelerators.

---

## 3. Platform 2: PULP Platform (PULPissimo)

**Period:** March 9 – March 30, 2026

### Background

PULPissimo is a microcontroller SoC from ETH Zurich's PULP (Parallel Ultra Low Power) Platform. It features a RISC-V core and is designed to interface with HWPEs through a standardised HWPE-Stream interface. It has been widely used in embedded AI research and is the most established open-source platform for HWPE work.

### Trial

The main branch of PULPissimo was cloned and setup was attempted on a modern Ubuntu 22.04 host. When that failed, progressively older versions and environments were tried, culminating in a successful partial setup inside a Docker container (Ubuntu 20.04 image: `patata0717/pulpissimo`).

Within the Docker container:
- The PULP SDK compiled successfully without dependency issues.
- RISC-V code could be emulated using **GVSoC**, the PULP virtual platform emulator.

### Issues Faced

**1. SDK end-of-life on main branch**
The main branch of PULPissimo has no active software SDK. The `pulp-sdk` is incompatible with modern GCC versions (it requires `gcc-5`, which is only available on Ubuntu 18). Attempting to build the SDK on Ubuntu 22 or 20 failed. Switching to the last tagged release (June 2021) introduced further dependency conflicts.

**2. RTL simulation requires QuestaSim**
Attempts to build the RTL simulation using ModelSim (trial version) failed at compilation:

```
** Error: ../ips/common_cells/src/id_queue.sv(278):
Questa has encountered an unexpected internal error.
```

The `common_cells` library used by PULPissimo contains SystemVerilog testbench features (randomisation, coverage, assertions) that ModelSim's trial version does not support — QuestaSim (the commercial version) is required. QuestaSim is not freely available.

**3. Bender-based build fails immediately**
Using the newer `bender` IP management tool instead of the legacy `IPAPPROX` also failed:

```
chmod: cannot access 'modelsim.ini': No such file or directory
make[1]: *** [Makefile:57: lib] Error 1
```

The Makefile assumed a pre-existing ModelSim workspace that does not exist until QuestaSim is installed and initialised.

**4. Not future-proof**
Even setting aside the simulation issue, building the PULP SDK required downgrading the host OS to Ubuntu 18. This approach produces a working environment but is fragile and not reproducible on modern systems.

### Resolution

PULPissimo was abandoned as a primary platform. The combination of a dead SDK, a dependency on proprietary QuestaSim for simulation, and severe environment fragility made it impractical for research reproducibility. The project pivoted to identifying a more actively maintained alternative.

---

## 4. Platform 3: Alternative PULP-Derived Platforms

**Period:** March 13 and March 30, 2026

Following the decision to focus on platforms compatible with the **Deeploy** compiler framework (a bottom-up deployment compiler for heterogeneous SoCs), a survey of alternatives was conducted.

### Platforms Evaluated

| Platform | Description | Status |
|---|---|---|
| **Chimera** (March 13) | Template architecture for multi-HWPE pipelines; used in transformer accelerator research | Too abstract for direct use; documentation non-existent for the parts needed. No FPGA support. |
| **Siracusa** | Research SoC from ETHZ/UniBO | No public repository available. |
| **Mempool + ITA** | 256-core mesh + integer transformer accelerator | FPGA infeasible at full scale. Scaled-down `minpool` (16 cores) has Verilator support but no FPGA flow. |
| **Snitch Cluster** | RISC-V cluster with FREP and SSR extensions | Docker image available, Verilator supported. No FPGA support out of the box. |
| **GAP9** | Greenwaves Technologies SoC | Proprietary; not open-source. |
| **Cheshire** | Linux-capable RISC-V SoC; Chimera is implemented on top of it | FPGA support exists for some boards. However, no direct Deeploy backend for Cheshire. |

### Analysis

The unifying limitation across all alternatives was **no ready-made FPGA synthesis flow**. Cheshire came closest but lacked Deeploy integration. Snitch and Mempool had the best software ecosystem (Verilator, Docker) but were designed for simulation-first/ASIC workflows, with FPGA support requiring significant porting effort.

Two options remained under consideration at this stage:
1. Downscale Chimera (4 Snitch clusters → 1–2) and port it to available FPGAs.
2. Use Cheshire as a baseline microcontroller and integrate an HWPE.

Both were set aside when X-HEEP was discovered.

---

## 5. Platform 4: X-HEEP + Quadrilatero

**Period:** March 31 – May 2026

### Background

**X-HEEP** (eXtensible Heterogeneous Energy-Efficient Platform) is a configurable RISC-V microcontroller developed at EPFL's ESL lab. It is purpose-built for extensibility: a co-processor can be attached via the **CV-X-IF** interface without modifying the MCU's RTL. It ships with first-class FPGA support for several boards and an active Docker-based toolchain.

**Quadrilatero** is a systolic-array hardware accelerator that implements a custom RISC-V ISA extension (`xtheadmatrix`) for matrix operations. It attaches to X-HEEP through CV-X-IF, enabling the CPU to dispatch matrix instructions directly to the accelerator.

The combination — **X-HEEP+Quadrilatero** — was identified as the project target after Dr. Karthik confirmed that getting Deeploy and X-HEEP to work together "certainly can be the project."

### 5.1 Environment Setup and FPGA Bitstream Generation

**Trial:** X-HEEP provides an official Docker container (`x-heep-toolchain`). A custom `Dockerfile` was written on top of this to add Vivado support (libraries, locale, path fixup via `entrypoint.sh`). Vivado was mounted as an external volume rather than bundled into the image to keep the image size manageable — a design point later confirmed as correct by Prof. Nitin.

**Issue — Vivado version incompatibility:** The initially available Vivado version (2018.3) was too old. The X-HEEP FPGA scripts use the `-freq_hz` flag in `create_bd_port`, which was introduced in a later Vivado release:

```
Unknown option '-freq_hz', please type 'create_bd_port -help' for usage info.
while executing "source xilinx_generate_clk_wizard.tcl"
```

**Resolution:** A newer Vivado installation (2022.1+) was obtained and mounted into the container. Once the correct version was in place, `make mcu-gen` followed by `make vivado-fpga FPGA_BOARD=nexys-a7-200t` produced a complete bitstream successfully.

### 5.2 Verilator Simulation

**Trial:** The X-HEEP simulation was built using FuseSoC and Verilator. The first attempt to simulate `example_matmul_quadrilatero` failed immediately during model compilation.

**Issue — COMBDLY warning treated as error:** Verilator 5.x upgrades certain warnings to errors by default. The `cv32e40px_sim_clock_gate.sv` file from the CV32E40PX behavioural model uses a non-blocking assignment inside a combinational block:

```
if (clk_i == 1'b0) clk_en <= en_i | scan_cg_en_i;
```

Verilator exits with:
```
%Error: Exiting due to 1 warning(s) [COMBDLY]
ERROR: Failed to build openhwgroup.org:systems:core-v-mini-mcu:1.0.5
```

**Resolution:** A `/* verilator lint_off COMBDLY */` guard was applied around the offending line in the vendored copy of the behavioural model. The simulation then compiled and ran cleanly.

### 5.3 Custom LLVM Compiler Toolchain

**Background:** The `xtheadmatrix` ISA extension used by Quadrilatero is not in upstream LLVM/GCC. A patched LLVM must be built from the [`xheep_matrix_spec`](https://github.com/esl-epfl/xheep_matrix_spec) repository.

**Trial:** The toolchain was built inside the Docker container by first compiling `riscv-gnu-toolchain` (for the sysroot) and then building LLVM with the custom RISC-V backend. The installation was directed to a host-mounted directory so it persists across container runs.

**Issue:** Attempting to install into a system-owned path (`/usr/`) failed with permission errors inside the container. 

**Resolution:** The toolchain was installed into a user-owned mounted directory (`/tools/riscv_matrix_toolchain`), which resolved the permission issue and made the install portable. Once built, applications are compiled with:

```bash
make app PROJECT=example_matmul_quadrilatero \
  ARCH=rv32imc_zicsr_xtheadmatrix0p1 \
  COMPILER_FLAGS=-menable-experimental-extensions \
  COMPILER=clang CLANG_LINKER_USE_LD=1
```

### 5.4 Quadrilatero Integration and Debugging

**Trial:** With the bitstream generated and the compiler toolchain in place, the `example_matmul_quadrilatero` application was compiled and simulated in Verilator. Waveform analysis was performed using GTKWave.

**Observation from waveforms:**
1. The CPU correctly dispatches all `xtheadmatrix` instructions to Quadrilatero over the CV-X-IF interface.
2. Quadrilatero accepts each instruction (the accelerator responds with `accept = 1`).
3. **The accelerator never sends back a result.** The result-valid signal is never asserted.

This ruled out a simple configuration or interface error and indicated a deeper issue in Quadrilatero's internal pipeline.

**Root cause — valid-ready deadlock in the systolic array handshake:**

After extensive waveform debugging, the issue was traced to a deadlock in the handshake between Quadrilatero's register-file (RF) sequencer and the systolic array:

- The RF sequencer waited for `ready` from the systolic array before asserting `valid`.
- The systolic array waited for `valid` from the RF sequencer before asserting `ready`.

Neither side could proceed. The underlying cause was that loading the Weight (W), Accumulate (A), and Data (D) registers from memory is not instantaneous — memory latency meant the three registers were not all ready at the same tick, but the original code assumed they would be loaded simultaneously and held `valid` low until all three were available.

**Fix:** The RTL was modified so that:
- The RF sequencer asserts `valid` as soon as *each individual register* is loaded, rather than waiting for all three simultaneously.
- The systolic array asserts `ready` only once it has received `valid` for all three registers (W, A, and D).

This is the standard ready-valid handshake semantics. After the fix, the accelerator produces correct results for matrix inputs up to at least 16×16.

**Remaining issue — large matrix inputs:**

For matrix sizes beyond 16×16, a secondary issue appears. The simulation fails with:

```
$readmem file address beyond bounds of array
```

This was traced to the default linker script placing the code segment at `0x8000`. For larger binaries, the code and data together overflow the simulated SRAM. Linking at `0x10000` resolves the issue for 16×16 inputs and is expected to work for 32×32. The 64×64 case still fails even with the higher base address, suggesting a deeper constraint in the current memory configuration (3 × 32 kB banks + 8 × 16 kB interleaved banks as configured in `cv32e40px_xif_quadrilatero.py`).

### 5.5 FPGA Hardware Testing (In Progress)

The X-HEEP+Quadrilatero bitstream for the Nexys-A7-200t was generated successfully. The board is programmable via a Digilent JTAG high-speed cable using the `quad-x-heep-openocd.cfg` configuration provided in this repository. Hardware bring-up was underway at the time of report writing, with lab support from the RISE lab.

---

## 6. Final Conclusion

### Summary of Findings

| Platform | FPGA Support | Open-Source Toolchain | Simulation | HWPE Integration | Verdict |
|---|---|---|---|---|---|
| Google Coral NPU | None | Partial | N/A | None | Abandoned |
| PULPissimo | Yes (paper) | Dead SDK; QuestaSim required | Not achieved | Possible but undocumented | Abandoned |
| Snitch / Mempool / Cheshire | Partial / None | Varies | Verilator (some) | Complex | Not pursued |
| **X-HEEP + Quadrilatero** | **Extensive** | **Active; Docker; Clang/GCC** | **Working** | **CV-X-IF (working)** | **Adopted** |

### What Was Achieved

1. A **reproducible Docker-based build environment** for X-HEEP+Quadrilatero that handles the Vivado path-fixup problem and pins the LLVM toolchain to a mounted external volume.
2. A **working Verilator simulation** of the full X-HEEP+Quadrilatero system, with GEMM and convolution workloads verified correct by waveform inspection.
3. **An RTL bug fix in Quadrilatero**: the valid-ready deadlock between the RF sequencer and systolic array was identified, root-caused, and corrected.
4. A **generated FPGA bitstream** for the Nexys-A7-200t and a complete procedure to reproduce it from source.

### Lessons Learned

**On platform selection:** The maturity of the *software* ecosystem is as important as the hardware design. PULPissimo's hardware is well-designed, but without an active SDK and without access to QuestaSim, it is practically unusable for new research. X-HEEP's investment in Docker, an active Makefile-based build system, and Verilator support made it possible to go from zero to a working simulation in days rather than weeks.

**On HWPE design:** The CV-X-IF interface is well-specified, but implementing the downstream ready-valid handshake correctly requires care about timing. The Quadrilatero bug demonstrates that assuming simultaneous register availability in a memory-latency-sensitive pipeline is a subtle but critical error. The fix is straightforward once the deadlock is understood, but waveform analysis was essential to diagnose it.

**On toolchain extensibility:** Extending LLVM to support a custom ISA is non-trivial but tractable. The `xheep_matrix_spec` build process works reliably when the installation target is a user-owned directory. The resulting compiler correctly emits `xtheadmatrix` instructions and the CPU-to-accelerator dispatch chain functions correctly end-to-end.

**On scope management:** The original project plan included higher-level compiler integration (Deeploy, TVM, or Exo targeting the custom ISA) and a full FPGA demonstration with benchmarks. The time spent on platform selection and environment setup — particularly the Vivado version issue and the Quadrilatero RTL debugging — consumed a significant portion of the project timeline. A more narrowly scoped initial target (simulation only, one matrix size) would have left more time for the software stack.

### Open Problems and Future Work

- **64×64 matrix support in simulation:** The `$readmem` overflow for large inputs needs a proper memory layout fix, likely by increasing the SRAM bank configuration in `cv32e40px_xif_quadrilatero.py` or by using the flash-exec linker mode.
- **FPGA hardware validation:** The bitstream is ready; running the application on the Nexys-A7-200t and verifying results against the simulation is the immediate next step.
- **Deeploy integration:** The original goal of compiling a neural network layer from a high-level representation (ONNX / Python) down to `xtheadmatrix` instructions via Deeploy remains unachieved and is a natural continuation of this work.
- **Benchmarking:** Comparing cycle counts between the scalar `example_matmul` and the accelerated `example_matmul_quadrilatero` would quantify the speedup and energy efficiency of the Quadrilatero co-processor, which is the core research question motivating the whole platform.
