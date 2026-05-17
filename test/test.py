# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

# VGA timing constants (640x480 @ 60Hz)
H_TOTAL = 800   # 640 + 16 + 96 + 48
V_TOTAL = 525   # 480 + 10 + 2 + 33
FRAME_CLOCKS = H_TOTAL * V_TOTAL  # 420000 clocks per frame

# TinyVGA Pmod output bit mapping from uo_out:
#   uo_out = {hsync, b0, g0, r0, vsync, b1, g1, r1}
#   bit 7 = hsync, bit 3 = vsync
HSYNC_BIT = 7
VSYNC_BIT = 3


async def reset_dut(dut):
    """Apply reset and initialize inputs."""
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)


@cocotb.test()
async def test_reset(dut):
    """Verify the design comes out of reset without errors."""
    dut._log.info("Test: Reset")

    # 25.175 MHz VGA pixel clock -> ~39.72 ns period
    clock = Clock(dut.clk, 39.72, units="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    # Run for a short time after reset
    await ClockCycles(dut.clk, 1000)

    # uio_out and uio_oe should be 0 (unused)
    assert dut.uio_out.value == 0, "uio_out should be 0"
    assert dut.uio_oe.value == 0, "uio_oe should be 0"

    dut._log.info("Reset test passed")


@cocotb.test()
async def test_vga_hsync(dut):
    """Verify that hsync toggles within one horizontal line."""
    dut._log.info("Test: VGA hsync signal")

    clock = Clock(dut.clk, 39.72, units="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    # Sample hsync over one full line (800 clocks) and check it toggles
    hsync_values = set()
    for _ in range(H_TOTAL):
        await RisingEdge(dut.clk)
        hsync_val = (dut.uo_out.value >> HSYNC_BIT) & 1
        hsync_values.add(hsync_val)

    assert len(hsync_values) == 2, "hsync should toggle during one horizontal line"
    dut._log.info("hsync toggling confirmed")


@cocotb.test()
async def test_vga_vsync(dut):
    """Verify that vsync toggles within one full frame."""
    dut._log.info("Test: VGA vsync signal")

    clock = Clock(dut.clk, 39.72, units="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    # Sample vsync over one full frame and check it toggles
    vsync_values = set()
    for _ in range(FRAME_CLOCKS):
        await RisingEdge(dut.clk)
        vsync_val = (dut.uo_out.value >> VSYNC_BIT) & 1
        vsync_values.add(vsync_val)

    assert len(vsync_values) == 2, "vsync should toggle during one full frame"
    dut._log.info("vsync toggling confirmed")


@cocotb.test()
async def test_button_input(dut):
    """Verify that pressing direction buttons doesn't crash the design."""
    dut._log.info("Test: Button input")

    clock = Clock(dut.clk, 39.72, units="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    # Press each direction button for a few clocks
    for btn in [0x01, 0x02, 0x04, 0x08]:  # UP, DOWN, LEFT, RIGHT
        dut.ui_in.value = btn
        await ClockCycles(dut.clk, 500)
        dut.ui_in.value = 0
        await ClockCycles(dut.clk, 100)

    # Design should still be running (uio signals stay 0)
    assert dut.uio_out.value == 0
    assert dut.uio_oe.value == 0

    dut._log.info("Button input test passed")


@cocotb.test()
async def test_color_output_during_display(dut):
    """Verify that color output is non-zero during the visible area."""
    dut._log.info("Test: Color output in visible area")

    clock = Clock(dut.clk, 39.72, units="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    # Wait for start of a frame (skip to visible area)
    # Run past a few lines to get into the display region
    await ClockCycles(dut.clk, H_TOTAL * 5 + 100)

    # Sample some pixels in the visible region
    nonzero_seen = False
    for _ in range(640):
        await RisingEdge(dut.clk)
        out = dut.uo_out.value & 0x77  # mask out hsync/vsync bits
        if out != 0:
            nonzero_seen = True
            break

    assert nonzero_seen, "Should see non-zero color output in visible area"
    dut._log.info("Color output test passed")