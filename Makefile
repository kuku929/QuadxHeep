MAKE = make

FPGA_BOARD ?= nexys-video
TARGET     ?= nexys-video

# Path to Vivado installation on the host (e.g. /mnt/vivado2025 or /opt/Xilinx)
VIVADO_PATH ?= /mnt/vivado2025

# Vivado version string — must match the subdirectory inside VIVADO_PATH
VIVADO_VERSION ?= 2025.2

vivado-fpga:
	LD_PRELOAD=/lib/x86_64-linux-gnu/libudev.so.1 $(MAKE) -f $(XHEEP_MAKE) vivado-fpga FPGA_BOARD=$(FPGA_BOARD);

mcu-gen:
	$(MAKE) -f $(XHEEP_MAKE) mcu-gen PYTHON_X_HEEP_CFG=configs/cv32e40px_xif_quadrilatero.py X_HEEP_CFG=configs/python_unsupported.hjson

.PHONY: build
build:
	$(MAKE) mcu-gen
	$(MAKE) matmul 

matmul:
	$(MAKE) -f $(XHEEP_MAKE) app PROJECT=example_matmul_quadrilatero ARCH=rv32imc_zicsr_xtheadmatrix0p1 COMPILER_FLAGS=-menable-experimental-extensions COMPILER=clang CLANG_LINKER_USE_LD=1 SOURCE=$(SOURCE)

conv:
	$(MAKE) -f $(XHEEP_MAKE) app PROJECT=example_conv_quadrilatero ARCH=rv32imc_zicsr_xtheadmatrix0p1 COMPILER_FLAGS=-menable-experimental-extensions COMPILER=clang CLANG_LINKER_USE_LD=1 SOURCE=$(SOURCE)_quadrilatero ARCH=rv32imc_zicsr_xtheadmatrix0p1 COMPILER_FLAGS=-menable-experimental-extensions COMPILER=clang CLANG_LINKER_USE_LD=1 SOURCE=$(SOURCE)

.PHONY: run
run:
	$(MAKE) verilator-run

matmul-run:
	$(MAKE) matmul 
	$(MAKE) run

conv-run:
	$(MAKE) conv
	$(MAKE) run

.PHONY: docker
docker:
	# We mount the x-heep directory. All build files are generated there and can be further accessed by the host.
	docker run -it --rm -v $(CURDIR):/workspace/QuadxHeep \
		-v $(RISCV_MATRIX_TOOLCHAIN):/tools/riscv_matrix_toolchain \
		-v $(VIVADO_PATH)/:/tools/vivado-$(VIVADO_VERSION) \
		quadxheep
export HEEP_DIR = hw/vendor/esl_epfl_x_heep/
XHEEP_MAKE = $(HEEP_DIR)/external.mk
include $(XHEEP_MAKE)
