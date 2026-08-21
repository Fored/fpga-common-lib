import cocotb

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from cocotb_test_utils import reset_dut, recv_axis_bytes, send_axis_bytes, set_axis_idle


async def wait_for_pulse(clk, signal, timeout_cycles=100):
    for _ in range(timeout_cycles):
        await RisingEdge(clk)
        if int(signal.value) == 1:
            return

    raise AssertionError(f"Timed out waiting for {signal._name}")


@cocotb.test()
async def test_header_is_removed_and_payload_forwarded(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    set_axis_idle(dut.s_axis, dut.m_axis)
    await reset_dut(dut)

    frame = bytes([0x11, 0x22, 0x33, 0x44]) + b"payload"
    recv_task = cocotb.start_soon(
        recv_axis_bytes(
            dut.clk,
            dut.m_axis,
            count=len(b"payload"),
            timeout_cycles=100,
            require_count=True,
        )
    )

    await send_axis_bytes(dut.clk, dut.s_axis, frame)
    received = bytes(await recv_task)

    assert received == b"payload"
    assert int(dut.header.value) == 0x11223344
    assert int(dut.header_error.value) == 0


@cocotb.test()
async def test_header_only_packet_reports_header_without_payload(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    set_axis_idle(dut.s_axis, dut.m_axis)
    await reset_dut(dut)

    valid_task = cocotb.start_soon(wait_for_pulse(dut.clk, dut.header_valid))

    await send_axis_bytes(dut.clk, dut.s_axis, bytes([0xAA, 0xBB, 0xCC, 0xDD]))
    await valid_task

    assert int(dut.header.value) == 0xAABBCCDD

    for _ in range(10):
        await RisingEdge(dut.clk)
        assert int(dut.m_axis.tvalid.value) == 0


@cocotb.test()
async def test_short_header_reports_error_and_drops_frame(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    set_axis_idle(dut.s_axis, dut.m_axis)
    await reset_dut(dut)

    error_task = cocotb.start_soon(wait_for_pulse(dut.clk, dut.header_error))

    await send_axis_bytes(dut.clk, dut.s_axis, bytes([0xDE, 0xAD]))
    await error_task

    for _ in range(10):
        await RisingEdge(dut.clk)
        assert int(dut.m_axis.tvalid.value) == 0
