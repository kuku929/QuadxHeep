# QuadxHeep

**X-HEEP extended with the Quadrilatero systolic-array co-processor.**

[X-HEEP](https://github.com/esl-epfl/x-heep) (eXtensible Heterogeneous Energy-Efficient Platform) is a configurable RISC-V microcontroller developed at EPFL. This repository extends it with [Quadrilatero](https://github.com/esl-epfl/quadrilatero), a systolic-array hardware accelerator that implements a custom RISC-V ISA extension (`xtheadmatrix`) for matrix operations. The accelerator is connected to the CPU via the [CV-X-IF](https://docs.openhwgroup.org/projects/cv-x-if/) co-processor interface.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Repository Structure](#repository-structure)
3. [Docker Environment](#docker-environment)
4. [MCU Generation](#mcu-generation)
5. [Simulation with Verilator](#simulation-with-verilator)
6. [Building Applications](#building-applications)
7. [FPGA Flow](#fpga-flow)
8. [Running on Hardware](#running-on-hardware)

---

## Prerequisites

| Tool | Notes |
|------|-------|
| Docker | For the containerised build environment |
| Vivado 2022.1+ | Mounted into the container; **not** bundled |
| Custom LLVM toolchain | Built from [xheep_matrix_spec](https://github.com/esl-epfl/xheep_matrix_spec); mounted into the container |
| Verilator 5.x | For RTL simulation (inside the container) |
| OpenOCD | For JTAG programming (on the host, or inside the container) |
| Nexys-A7-200t FPGA board | Or any other [X-HEEP-supported board](#fpga-flow) |

> **Note on the LLVM toolchain:** The custom toolchain adds the `xtheadmatrix` instruction-set extension needed to compile code targeting Quadrilatero. See [Building Applications](#building-applications) for build instructions.

---

## Repository Structure

```
QuadxHeep/
├── Dockerfile                  # Container image built on top of x-heep-toolchain
├── entrypoint.sh               # Vivado path-fixup entrypoint
├── Makefile                    # Top-level convenience targets (delegates to X-HEEP)
├── hw/
│   └── vendor/
│       └── esl_epfl_x_heep/   # X-HEEP submodule
│           └── configs/
│               └── cv32e40px_xif_quadrilatero.py  # MCU config with Quadrilatero enabled
└── sw/
    ├── applications/
    │   └── example_matmul_quadrilatero/  # Matrix-multiply demo
    ├── device/                 # BSP and target-specific headers
    └── linker/                 # Linker scripts
```

The `Makefile` at the repo root is a thin wrapper. All make targets ultimately delegate to `hw/vendor/esl_epfl_x_heep/external.mk`.

---

## Docker Environment

The Docker image layers on top of the official `x-heep-toolchain` image and adds the libraries needed to run Vivado inside the container. Vivado itself and the custom LLVM toolchain are **mounted at runtime**, not baked in.

### Build the image

```bash
docker build -t quadxheep .
```

### Launch the container

```bash
make docker \
  RISCV_MATRIX_TOOLCHAIN=/path/to/riscv_matrix_toolchain \
  VIVADO_PATH=/path/to/vivado/root \
  VIVADO_VERSION=2025.2
```

This mounts:
- The repo root → `/workspace/QuadxHeep`
- Your LLVM toolchain → `/tools/riscv_matrix_toolchain`
- Your Vivado installation → `/tools/vivado-<VIVADO_VERSION>`

`VIVADO_PATH` should point to the directory that *contains* the versioned Vivado subdirectory (e.g. if Vivado lives at `/opt/Xilinx/2022.1/Vivado/bin/vivado`, set `VIVADO_PATH=/opt/Xilinx` and `VIVADO_VERSION=2022.1`). Both variables default to the lab machine's paths and can be overridden without editing the `Makefile`.

All subsequent steps are run **inside the container** unless noted otherwise.

---

## MCU Generation

`mcu-gen` renders all auto-generated RTL and linker scripts from the Python configuration. It must be run before any simulation or synthesis step.

```bash
make mcu-gen \
  PYTHON_X_HEEP_CFG=configs/cv32e40px_xif_quadrilatero.py \
  X_HEEP_CFG=configs/python_unsupported.hjson
```

The config `cv32e40px_xif_quadrilatero.py` sets:
- CPU: `cv32e40px`
- CV-X-IF interface enabled (2 read ports, to match Quadrilatero's register file)
- `QUADRILATERO=1` in the testharness extension block

---

## Simulation with Verilator

### Build the simulation model

```bash
make verilator-build
```

This uses FuseSoC to compile the RTL into a Verilator model. Build output and logs go to `hw/vendor/esl_epfl_x_heep/build/` and `buildsim.log`.

> **Tip:** If Verilator exits with a `COMBDLY` warning-as-error from `cv32e40px_sim_clock_gate.sv`, the fix is already applied in this repo's vendored copy of X-HEEP.

### Run an application in simulation

After building both the simulation model and an application binary (see [Building Applications](#building-applications)):

```bash
make verilator-run
```

Waveform dumps (`.vcd` / `.fst`) are written to the build directory and can be opened with GTKWave.

---

## Building Applications

### Set up the custom LLVM toolchain

The `xtheadmatrix` extension is not in upstream LLVM. Build the toolchain from source once (outside the container is fine, as long as the output directory is mounted):

```bash
# Clone the spec repo on the host
git clone https://github.com/esl-epfl/xheep_matrix_spec

# Run the container with the spec repo also mounted
docker run -it --rm \
  -v $(pwd):/workspace/QuadxHeep \
  -v /path/to/riscv_matrix_toolchain:/tools/riscv_matrix_toolchain \
  -v /path/to/xheep_matrix_spec:/workspace/xheep_matrix_spec \
  quadxheep
```

Inside the container:

```bash
export RISCV=/tools/riscv_matrix_toolchain
export RVM_TEMP_DIR=/workspace/xheep_matrix_spec/temp
mkdir -p $RVM_TEMP_DIR

# 1. Build the RISC-V GCC toolchain (needed for sysroot)
cd $RVM_TEMP_DIR
git clone --branch 2022.01.17 --recursive https://github.com/riscv/riscv-gnu-toolchain
cd riscv-gnu-toolchain
./configure --prefix=$RISCV --with-abi=ilp32 --with-arch=rv32imc --with-cmodel=medlow
make -j$(nproc)

# 2. Build LLVM with the xtheadmatrix backend
mkdir $RVM_TEMP_DIR/llvm-build && cd $RVM_TEMP_DIR/llvm-build
cmake -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=True \
      -DLLVM_USE_SPLIT_DWARF=True \
      -DCMAKE_INSTALL_PREFIX="$RISCV" \
      -DLLVM_OPTIMIZED_TABLEGEN=True \
      -DLLVM_BUILD_TESTS=False \
      -DDEFAULT_SYSROOT="$RISCV/riscv32-unknown-elf" \
      -DLLVM_DEFAULT_TARGET_TRIPLE="riscv32-unknown-elf" \
      -DLLVM_ENABLE_PROJECTS="clang" \
      -DLLVM_TARGETS_TO_BUILD="RISCV" \
      ../../llvm-project/llvm
cmake --build . --target install -j$(nproc)
```

This is a one-time step. The toolchain is installed into the mounted directory and persists across container runs.

### Compile and run the matrix-multiply demo

```bash
# Inside the container
export RISCV_XHEEP=/tools/riscv_matrix_toolchain
export PATH=$RISCV_XHEEP/bin:$PATH
init_clang   # sets up the Clang environment for X-HEEP

make app \
  PROJECT=example_matmul_quadrilatero \
  ARCH=rv32imc_zicsr_xtheadmatrix0p1 \
  COMPILER_FLAGS=-menable-experimental-extensions \
  COMPILER=clang \
  CLANG_LINKER_USE_LD=1

make verilator-run
```

> **Memory note:** For matrix sizes larger than 16×16, the binary must be linked at `0x10000` instead of the default `0x8000`. Large inputs (e.g. 64×64) may trigger a `$readmem file address beyond bounds of array` error from the simulator; this is a known limitation of the current memory configuration.

### Available example applications

Run `make app-list` inside the container to see all applications. Key ones:

| Application | Description |
|-------------|-------------|
| `example_matmul_quadrilatero` | Matrix multiply using Quadrilatero custom instructions |
| `example_matmul` | Scalar matrix multiply (baseline, no accelerator) |
| `example_matadd` | Matrix addition |
| `example_im2col` | im2col for convolution |
| `example_dma` / `example_dma_2d` | DMA engine demos |
| `coremark` | CoreMark CPU benchmark |

---

## FPGA Flow

Tested on the **Nexys-A7-200t**. Other X-HEEP-supported boards: Nexys-A7-100t, Pynq-Z2, ZCU-104, ZCU-102, Genesys2.

### Generate the bitstream

Vivado must be mounted into the container (see [Docker Environment](#docker-environment)).

```bash
# Inside the container — run mcu-gen first if not already done
make mcu-gen \
  PYTHON_X_HEEP_CFG=configs/cv32e40px_xif_quadrilatero.py \
  X_HEEP_CFG=configs/python_unsupported.hjson

make vivado-fpga FPGA_BOARD=nexys-a7-200t
```

The bitstream and implementation reports are written to `hw/vendor/esl_epfl_x_heep/build/`.

> **Vivado version:** Vivado 2022.1 or newer is required. Older versions (e.g. 2018.x) do not support the `-freq_hz` flag used in the clock-wizard TCL scripts.

### Build an application for FPGA

Same `make app` command as simulation but with the `nexys-a7-200t` linker target:

```bash
make app \
  PROJECT=example_matmul_quadrilatero \
  ARCH=rv32imc_zicsr_xtheadmatrix0p1 \
  COMPILER_FLAGS=-menable-experimental-extensions \
  COMPILER=clang \
  CLANG_LINKER_USE_LD=1 \
  TARGET=nexys-a7-200t
```

---

## Running on Hardware

### Program the FPGA

Use Vivado's hardware manager or the Vivado TCL console to program the `.bit` file onto the board.

### Connect via JTAG (OpenOCD)

A pre-configured OpenOCD config is provided at `quad-x-heep-openocd.cfg`. It uses the FTDI JTAG adapter exposed by the Nexys board's on-board USB-JTAG bridge.

```bash
openocd -f quad-x-heep-openocd.cfg
```

Once OpenOCD reports `Ready for Remote Connections`, attach GDB in a second terminal:

```bash
riscv32-unknown-elf-gdb path/to/app.elf \
  -ex "target remote :3333" \
  -ex "load" \
  -ex "continue"
```

The UART output from the application is available on the board's USB-serial port (115200 8N1).

---

## Known Issues

### Large matrix inputs fail in simulation (`$readmem file address beyond bounds of array`)

The default linker script places the code segment at `0x8000`. For matrix sizes above roughly 16×16, the binary grows large enough that data spills past the end of the simulated SRAM, causing Verilator to print:

```
$readmem file address beyond bounds of array
```

**Workaround:** link the binary at `0x10000` instead. Pass a custom linker script or override the `LINK_FOLDER` variable when calling `make app` so the code section starts at the higher address. This has been verified to work for inputs up to 16×16 (32×32 untested); 64×64 still fails even with the higher base address, which points to a deeper memory-layout issue in the current configuration.

### Quadrilatero valid-ready deadlock (fixed in this repo)

Upstream Quadrilatero had a deadlock in the handshake between the register-file sequencer and the systolic array: the sequencer waited for `ready` while the array waited for `valid`, and neither ever fired because the Weight, Accumulate, and Data registers were not always loaded simultaneously (memory latency delayed some of them).

The fix applied in this repo makes the sequencer assert `valid` as soon as each individual register is loaded, and the systolic array asserts `ready` only once all three registers (`W`, `A`, `D`) are valid — the standard ready-valid handshake semantics. The corrected RTL is in the vendored copy of X-HEEP under `hw/vendor/esl_epfl_x_heep/`.

---

## References

- [X-HEEP repository](https://github.com/esl-epfl/x-heep)
- [X-HEEP documentation](https://x-heep.readthedocs.io)
- [Quadrilatero repository](https://github.com/esl-epfl/quadrilatero)
- [xheep_matrix_spec — custom LLVM toolchain](https://github.com/esl-epfl/xheep_matrix_spec)
- [CV-X-IF co-processor interface spec](https://docs.openhwgroup.org/projects/cv-x-if/)
