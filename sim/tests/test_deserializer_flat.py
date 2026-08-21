import random

import cocotb

from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, ReadWrite, RisingEdge
from cocotb_test_utils import get_axis_data, recv_axis_samples, reset_dut, set_axis_data, set_axis_idle


CHANNELS = 4


async def send_axis_samples_with_random_valid(clk, axis, samples, rng):
    """Передаёт AXIS-выборки с паузами, сохраняя данные при tvalid=1."""
    index = 0
    active = False

    while index < len(samples):
        await FallingEdge(clk)
        if not active:
            if rng.random() < 0.7:
                data, last = samples[index]
                set_axis_data(axis, data)
                axis.tlast.value = last
                axis.tvalid.value = 1
                active = True
            else:
                axis.tvalid.value = 0
                axis.tlast.value = 0

        await ReadWrite()
        accepted = active and int(axis.tready.value) == 1
        await RisingEdge(clk)
        if accepted:
            index += 1
            active = False

    await FallingEdge(clk)
    set_axis_idle(axis)


async def recv_axis_samples_with_random_ready(clk, axis, count, rng, timeout_cycles):
    """Принимает AXIS-выборки со случайной готовностью приёмника."""
    samples = []

    for _ in range(timeout_cycles):
        await FallingEdge(clk)
        axis.tready.value = int(rng.random() < 0.65)

        await RisingEdge(clk)
        if int(axis.tvalid.value) == 1 and int(axis.tready.value) == 1:
            samples.append((get_axis_data(axis), int(axis.tlast.value)))

        if len(samples) == count:
            return samples

    raise AssertionError(f"Timed out waiting for {count} AXIS samples, received {len(samples)}")


@cocotb.test()
async def test_packet_is_distributed_and_tlast_restarts_at_channel_zero(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    set_axis_idle(dut.s_axis)
    for axis in dut.m_axis:
        axis.tready.value = 1
    await reset_dut(dut)

    expected = {
        0: [(0x110, 0), (0x114, 1)],
        1: [(0x111, 0), (0x115, 1)],
        2: [(0x112, 0), (0x116, 1)],
        3: [(0x113, 0), (0x117, 1)],
    }
    receivers = {
        channel: cocotb.start_soon(
            recv_axis_samples(dut.clk, dut.m_axis[channel], len(expected[channel]), timeout_cycles=200, require_count=True)
        )
        for channel in range(CHANNELS)
    }

    await send_axis_samples_with_random_valid(
        dut.clk,
        dut.s_axis,
        [(value, value == 0x117) for value in range(0x110, 0x118)],
        random.Random(0x13),
    )

    for channel in range(CHANNELS):
        assert await receivers[channel] == expected[channel]

    receivers = {
        channel: cocotb.start_soon(
            recv_axis_samples(dut.clk, dut.m_axis[channel], 1, timeout_cycles=200, require_count=True)
        )
        for channel in range(CHANNELS)
    }
    await send_axis_samples_with_random_valid(
        dut.clk,
        dut.s_axis,
        [(value, value == 0x123) for value in range(0x120, 0x124)],
        random.Random(0x14),
    )

    assert await receivers[0] == [(0x120, 1)]
    assert await receivers[1] == [(0x121, 1)]
    assert await receivers[2] == [(0x122, 1)]
    assert await receivers[3] == [(0x123, 1)]


@cocotb.test()
async def test_continuous_input_has_no_bubble_between_stripes(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    set_axis_idle(dut.s_axis)
    for axis in dut.m_axis:
        axis.tready.value = 1
    await reset_dut(dut)

    for _ in range(20):
        await RisingEdge(dut.clk)
        if int(dut.s_axis.tready.value) == 1:
            break
    else:
        raise AssertionError("Deserializer did not become ready after reset")

    stripe_count = 16
    sample_count = stripe_count * CHANNELS
    expected = {
        channel: [
            (stripe * CHANNELS + channel, int(stripe == stripe_count - 1))
            for stripe in range(stripe_count)
        ]
        for channel in range(CHANNELS)
    }
    receivers = {
        channel: cocotb.start_soon(
            recv_axis_samples(
                dut.clk,
                dut.m_axis[channel],
                stripe_count,
                timeout_cycles=sample_count * 2,
                require_count=True,
            )
        )
        for channel in range(CHANNELS)
    }

    for value in range(sample_count):
        await FallingEdge(dut.clk)
        set_axis_data(dut.s_axis, value)
        dut.s_axis.tlast.value = int(value == sample_count - 1)
        dut.s_axis.tvalid.value = 1

        await RisingEdge(dut.clk)
        assert int(dut.s_axis.tready.value) == 1, f"Unexpected input bubble before sample {value}"

    await FallingEdge(dut.clk)
    set_axis_idle(dut.s_axis)

    for channel in range(CHANNELS):
        assert await receivers[channel] == expected[channel]


@cocotb.test()
async def test_randomized_stream_with_backpressure(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    set_axis_idle(dut.s_axis)
    for axis in dut.m_axis:
        axis.tready.value = 0
    await reset_dut(dut)

    packet_rng = random.Random(0xD35E_2026)
    input_samples = []
    expected = {channel: [] for channel in range(CHANNELS)}
    value = 0

    # Длины пакетов случайны, но всегда кратны числу каналов.
    for _ in range(800):
        stripes_in_packet = packet_rng.randint(1, 8)
        for stripe in range(stripes_in_packet):
            last = int(stripe == stripes_in_packet - 1)
            for channel in range(CHANNELS):
                input_samples.append((value, last and channel == CHANNELS - 1))
                expected[channel].append((value, last))
                value = (value + 1) & 0x7F

    timeout_cycles = len(input_samples) * 40
    receivers = {
        channel: cocotb.start_soon(
            recv_axis_samples_with_random_ready(
                dut.clk,
                dut.m_axis[channel],
                len(expected[channel]),
                random.Random(0xA11CE),
                timeout_cycles,
            )
        )
        for channel in range(CHANNELS)
    }

    await send_axis_samples_with_random_valid(dut.clk, dut.s_axis, input_samples, random.Random(0x51DE))

    for channel in range(CHANNELS):
        assert await receivers[channel] == expected[channel]
