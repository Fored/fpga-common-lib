import cocotb

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from cocotb_test_utils import (
    recv_axis_samples,
    reset_dut,
    send_axis_sample,
    set_axis_idle,
)


async def wait_for_pulse(clk, signal, timeout_cycles=100):
    for _ in range(timeout_cycles):
        await RisingEdge(clk)
        if int(signal.value) == 1:
            return

    raise AssertionError(f"Timed out waiting for {signal._name}")


@cocotb.test()
async def test_multiple_frames_are_split_by_declared_length(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    set_axis_idle(dut.s_axis, dut.m_axis)
    await reset_dut(dut)

    recv_task = cocotb.start_soon(
        recv_axis_samples(
            dut.clk,
            dut.m_axis,
            count=6,
            timeout_cycles=100,
            require_count=True,
        )
    )

    words = [2, 0x10, 0x11, 0x12, 0x13, 1, 0x20, 0x21]
    for index, word in enumerate(words):
        await send_axis_sample(dut.clk, dut.s_axis, word, last=(index == len(words) - 1))

    assert await recv_task == [
        (0x10, 0),
        (0x11, 0),
        (0x12, 0),
        (0x13, 1),
        (0x20, 0),
        (0x21, 1),
    ]
    assert int(dut.length.value) == 1
    assert int(dut.frame_error.value) == 0


@cocotb.test()
async def test_early_input_tlast_closes_frame_and_recovers(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    set_axis_idle(dut.s_axis, dut.m_axis)
    await reset_dut(dut)

    recv_task = cocotb.start_soon(
        recv_axis_samples(
            dut.clk,
            dut.m_axis,
            count=4,
            timeout_cycles=100,
            require_count=True,
        )
    )
    error_task = cocotb.start_soon(wait_for_pulse(dut.clk, dut.frame_error))

    await send_axis_sample(dut.clk, dut.s_axis, 3)
    await send_axis_sample(dut.clk, dut.s_axis, 0x30)
    await send_axis_sample(dut.clk, dut.s_axis, 0x31, last=True)
    await error_task

    await send_axis_sample(dut.clk, dut.s_axis, 1)
    await send_axis_sample(dut.clk, dut.s_axis, 0x40)
    await send_axis_sample(dut.clk, dut.s_axis, 0x41, last=True)

    assert await recv_task == [
        (0x30, 0),
        (0x31, 1),
        (0x40, 0),
        (0x41, 1),
    ]


@cocotb.test()
async def test_backpressure_holds_generated_last_word(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    set_axis_idle(dut.s_axis, dut.m_axis)
    await reset_dut(dut)

    await send_axis_sample(dut.clk, dut.s_axis, 1)
    await send_axis_sample(dut.clk, dut.s_axis, 0x50)

    dut.m_axis.tready.value = 0
    dut.s_axis.tdata.value = 0x51
    dut.s_axis.tvalid.value = 1

    for _ in range(3):
        await RisingEdge(dut.clk)
        assert int(dut.s_axis.tready.value) == 0
        assert int(dut.m_axis.tvalid.value) == 1
        assert int(dut.m_axis.tdata.value) == 0x51
        assert int(dut.m_axis.tlast.value) == 1

    dut.m_axis.tready.value = 1
    await RisingEdge(dut.clk)
    dut.s_axis.tvalid.value = 0

    await send_axis_sample(dut.clk, dut.s_axis, 0, last=True)
    await RisingEdge(dut.clk)
    assert int(dut.length.value) == 0
    assert int(dut.frame_error.value) == 0


@cocotb.test()
async def test_nonzero_length_without_payload_reports_error(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    set_axis_idle(dut.s_axis, dut.m_axis)
    await reset_dut(dut)

    error_task = cocotb.start_soon(wait_for_pulse(dut.clk, dut.frame_error))

    await send_axis_sample(dut.clk, dut.s_axis, 2, last=True)
    await error_task

    for _ in range(5):
        await RisingEdge(dut.clk)
        assert int(dut.m_axis.tvalid.value) == 0
