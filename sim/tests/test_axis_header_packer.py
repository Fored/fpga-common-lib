import cocotb

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from cocotb_test_utils import (
    recv_axis_bytes,
    recv_axis_samples,
    reset_dut,
    send_axis_bytes,
    set_axis_idle,
)


@cocotb.test()
async def test_header_is_prepended_to_payload(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    set_axis_idle(dut.s_axis, dut.m_axis)
    dut.header.value = 0x11223344
    await reset_dut(dut)

    payload = b"payload"
    recv_task = cocotb.start_soon(
        recv_axis_bytes(
            dut.clk,
            dut.m_axis,
            count=4 + len(payload),
            timeout_cycles=100,
            require_count=True,
        )
    )

    await send_axis_bytes(dut.clk, dut.s_axis, payload)
    received = bytes(await recv_task)

    assert received == bytes([0x11, 0x22, 0x33, 0x44]) + payload


@cocotb.test()
async def test_payload_waits_until_header_is_accepted(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    set_axis_idle(dut.s_axis, dut.m_axis)
    dut.header.value = 0x01020304
    await reset_dut(dut)

    dut.s_axis.tdata.value = 0xAA
    dut.s_axis.tlast.value = 1
    dut.s_axis.tvalid.value = 1

    recv_task = cocotb.start_soon(
        recv_axis_bytes(dut.clk, dut.m_axis, count=5, timeout_cycles=100, require_count=True)
    )

    for _ in range(3):
        await RisingEdge(dut.clk)
        assert int(dut.s_axis.tready.value) == 0

    received = bytes(await recv_task)

    dut.s_axis.tvalid.value = 0
    dut.s_axis.tlast.value = 0

    assert received == bytes([1, 2, 3, 4, 0xAA])


@cocotb.test()
async def test_backpressure_stalls_header_and_payload(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    set_axis_idle(dut.s_axis, dut.m_axis)
    dut.header.value = 0xAABBCCDD
    await reset_dut(dut)

    dut.m_axis.tready.value = 0
    dut.s_axis.tdata.value = 0x10
    dut.s_axis.tlast.value = 0
    dut.s_axis.tvalid.value = 1

    await RisingEdge(dut.clk)

    for _ in range(5):
        await RisingEdge(dut.clk)
        assert int(dut.m_axis.tvalid.value) == 1
        assert int(dut.m_axis.tdata.value) == 0xAA
        assert int(dut.s_axis.tready.value) == 0

    recv_task = cocotb.start_soon(
        recv_axis_bytes(dut.clk, dut.m_axis, count=6, timeout_cycles=100, require_count=True)
    )

    dut.m_axis.tready.value = 1
    while True:
        await RisingEdge(dut.clk)
        if int(dut.s_axis.tready.value) == 1:
            break

    dut.s_axis.tdata.value = 0x20
    dut.s_axis.tlast.value = 1
    await RisingEdge(dut.clk)

    dut.s_axis.tvalid.value = 0
    dut.s_axis.tlast.value = 0

    received = bytes(await recv_task)

    assert received == bytes([0xAA, 0xBB, 0xCC, 0xDD, 0x10, 0x20])


@cocotb.test()
async def test_empty_packet_contains_only_header(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    set_axis_idle(dut.s_axis, dut.m_axis)
    dut.header.value = 0x00000000
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

    await send_axis_bytes(dut.clk, dut.s_axis, b"\x00")
    received = await recv_task

    assert received == [(0, 0), (0, 0), (0, 0), (0, 1)]
