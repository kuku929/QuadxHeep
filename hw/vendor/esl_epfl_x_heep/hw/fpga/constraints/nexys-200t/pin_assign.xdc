# Copyright 2022 EPFL
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Nexys Video pin assignments (XC7A200TSBG484).
# Minimal — only signals required for boot, JTAG, and UART.
# Note: the Nexys Video has mixed bank voltages; standards are set accordingly.

## Clock (100 MHz, Bank 34 MRCC — dedicated clock routing to MMCM)
set_property -dict {PACKAGE_PIN R4 IOSTANDARD LVCMOS33} [get_ports {clk_i}];

## Reset (CPU_RESETN, active low, Bank 35 — VCCIO = 1.5 V)
set_property -dict {PACKAGE_PIN G4 IOSTANDARD LVCMOS15} [get_ports {rst_i}];

## Status LEDs (Bank 13 — VCCIO = 2.5 V)
set_property -dict {PACKAGE_PIN T14 IOSTANDARD LVCMOS25} [get_ports {rst_led_o}];    # LD0
set_property -dict {PACKAGE_PIN T15 IOSTANDARD LVCMOS25} [get_ports {clk_led_o}];    # LD1
set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVCMOS25} [get_ports {exit_valid_o}]; # LD2
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS25} [get_ports {exit_value_o}]; # LD3
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_led_o_OBUF]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets rst_led_o_OBUF]

## Boot control (Switches SW0-SW2, Bank 16 — VCCIO = 1.2 V)
set_property -dict {PACKAGE_PIN E22 IOSTANDARD LVCMOS12} [get_ports {jtag_trst_ni}];         # SW0
set_property -dict {PACKAGE_PIN F21 IOSTANDARD LVCMOS12} [get_ports {execute_from_flash_i}]; # SW1
set_property -dict {PACKAGE_PIN G21 IOSTANDARD LVCMOS12} [get_ports {boot_select_i}];        # SW2

## UART (Bank 14 — LVCMOS33)
set_property -dict {PACKAGE_PIN V18  IOSTANDARD LVCMOS33} [get_ports {uart_rx_i}]; # Sch=uart_tx_in
set_property -dict {PACKAGE_PIN AA19 IOSTANDARD LVCMOS33} [get_ports {uart_tx_o}]; # Sch=uart_rx_out

## JTAG (Pmod JA pins 7-10, Bank 14 — LVCMOS33)
set_property -dict {PACKAGE_PIN Y21  IOSTANDARD LVCMOS33} [get_ports {jtag_tms_i}]; # JA7
set_property -dict {PACKAGE_PIN AA21 IOSTANDARD LVCMOS33} [get_ports {jtag_tdi_i}]; # JA8
set_property -dict {PACKAGE_PIN AA20 IOSTANDARD LVCMOS33} [get_ports {jtag_tdo_o}]; # JA9
set_property -dict {PACKAGE_PIN AA18 IOSTANDARD LVCMOS33} [get_ports {jtag_tck_i}]; # JA10
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets jtag_tck_i_IBUF]

## Required by Vivado DRC for mixed-voltage designs
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
