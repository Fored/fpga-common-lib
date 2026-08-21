import random

import cocotb

from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge
from cocotb_test_utils import get_axis_data, set_axis_data, set_axis_idle


CHANNELS = 4


async def reset_serializer(dut):
    dut.rst.value = 1
    for _ in range(8):
        await RisingEdge(dut.clk_user)
    dut.rst.value = 0

    # XPM FIFO keeps its AXIS ports inactive for several cycles after reset.
    for _ in range(12):
        await RisingEdge(dut.clk_user)


async def send_channel_samples(clk, axis, samples, rng):
    """Send one channel with independent valid gaps."""
    for data, last in samples:
        for _ in range(rng.randint(0, 3)):
            await RisingEdge(clk)

        await FallingEdge(clk)
        set_axis_data(axis, data)
        axis.tlast.value = last
        axis.tvalid.value = 1

        while True:
            await RisingEdge(clk)
            if int(axis.tready.value) == 1:
                break

        await FallingEdge(clk)
        set_axis_idle(axis)


async def send_stripes(dut, stripes, seed):
    senders = []
    for channel in range(CHANNELS):
        samples = [
            (stripe[channel], int(stripe_index == len(stripes) - 1))
            for stripe_index, stripe in enumerate(stripes)
        ]
        senders.append(
            cocotb.start_soon(
                send_channel_samples(
                    dut.clk_user,
                    dut.s_axis[channel],
                    samples,
                    random.Random(seed + channel),
                )
            )
        )

    for sender in senders:
        await sender


async def receive_samples(clk, axis, count, rng, timeout_cycles=2000):
    """Receive with backpressure and verify AXIS stability while stalled."""
    result = []
    stalled_sample = None

    for _ in range(timeout_cycles):
        await FallingEdge(clk)
        axis.tready.value = int(rng.random() < 0.65)

        await RisingEdge(clk)
        valid = int(axis.tvalid.value)
        if stalled_sample is not None:
            assert valid == 1, "AXIS output withdrew tvalid while stalled"

        if valid == 0:
            continue

        sample = (get_axis_data(axis), int(axis.tlast.value))
        if stalled_sample is not None:
            assert sample == stalled_sample, "AXIS output changed while stalled"

        if int(axis.tready.value) == 1:
            result.append(sample)
            stalled_sample = None
            if len(result) == count:
                return result
        else:
            stalled_sample = sample

    raise AssertionError(f"Timed out waiting for {count} AXIS samples, received {len(result)}")


@cocotb.test()
async def test_serializes_independent_channels_with_backpressure(dut):
    cocotb.start_soon(Clock(dut.clk_user, 10, unit="ns").start())
    cocotb.start_soon(Clock(dut.clk_out, 14, unit="ns").start())

    dut.data_in_num.value = CHANNELS
    for axis in dut.s_axis:
        set_axis_idle(axis)
    dut.m_axis.tready.value = 0
    await reset_serializer(dut)

    stripes = [
        [0x110, 0x111, 0x112, 0x113],
        [0x120, 0x121, 0x122, 0x123],
        [0x130, 0x131, 0x132, 0x133],
    ]
    expected = [
        (data, int(stripe_index == len(stripes) - 1 and channel == CHANNELS - 1))
        for stripe_index, stripe in enumerate(stripes)
        for channel, data in enumerate(stripe)
    ]

    receiver = cocotb.start_soon(
        receive_samples(dut.clk_out, dut.m_axis, len(expected), random.Random(0xA11CE))
    )
    await send_stripes(dut, stripes, seed=0x5100)

    assert await receiver == expected


@cocotb.test()
async def test_data_in_num_changes_only_at_packet_boundary(dut):
    cocotb.start_soon(Clock(dut.clk_user, 10, unit="ns").start())
    cocotb.start_soon(Clock(dut.clk_out, 14, unit="ns").start())

    dut.data_in_num.value = 2
    for axis in dut.s_axis:
        set_axis_idle(axis)
    dut.m_axis.tready.value = 0
    await reset_serializer(dut)

    first_packet = [
        [0x00, 0x01, 0x02, 0x03],
        [0x10, 0x11, 0x12, 0x13],
        [0x20, 0x21, 0x22, 0x23],
    ]
    first_expected = [
        (first_packet[stripe][channel], int(stripe == 2 and channel == 1))
        for stripe in range(3)
        for channel in range(2)
    ]

    sender = cocotb.start_soon(send_stripes(dut, first_packet, seed=0x2200))
    first_word = await receive_samples(dut.clk_out, dut.m_axis, 1, random.Random(0x2201))
    assert first_word == [first_expected[0]]

    # The current packet must remain two channels wide.
    dut.data_in_num.value = 3
    remainder = await receive_samples(
        dut.clk_out,
        dut.m_axis,
        len(first_expected) - 1,
        random.Random(0x2202),
    )
    await sender
    assert first_word + remainder == first_expected

    second_packet = [
        [0x40, 0x41, 0x42, 0x43],
        [0x50, 0x51, 0x52, 0x53],
    ]
    second_expected = [
        (second_packet[stripe][channel], int(stripe == 1 and channel == 2))
        for stripe in range(2)
        for channel in range(3)
    ]

    receiver = cocotb.start_soon(
        receive_samples(dut.clk_out, dut.m_axis, len(second_expected), random.Random(0x3301))
    )
    await send_stripes(dut, second_packet, seed=0x3300)
    assert await receiver == second_expected
