import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer


def pack_complex(re_value, im_value, component_width):
    mask = (1 << component_width) - 1
    return ((im_value & mask) << component_width) | (re_value & mask)


async def drive(dut, sample):
    await FallingEdge(dut.clk)

    if sample is None:
        dut.s_axis.tdata.value = 0
        dut.s_axis.tvalid.value = 0
        dut.s_axis.tlast.value = 0
        return

    re_value, im_value, last = sample
    component_width = len(dut.s_axis.tdata) // 2
    dut.s_axis.tdata.value = pack_complex(re_value, im_value, component_width)
    dut.s_axis.tvalid.value = 1
    dut.s_axis.tlast.value = last


async def receive(dut, count, timeout_cycles=100):
    results = []

    for _ in range(timeout_cycles):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")

        if dut.m_axis.tvalid.value.is_resolvable and int(dut.m_axis.tvalid.value):
            results.append((int(dut.m_axis.tdata.value), int(dut.m_axis.tlast.value)))
            if len(results) == count:
                return results

    raise AssertionError(f"Timed out waiting for {count} results, received {len(results)}")


@cocotb.test()
async def test_instant_power_arithmetic_and_pipeline(dut):
    """Checks signed IQ arithmetic, bubbles, continuous input and TLAST alignment."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start(start_high=False))

    component_width = len(dut.s_axis.tdata) // 2
    assert component_width > 1
    result_mask = (1 << (2 * component_width)) - 1

    rng = random.Random(0x1A57)
    limit = 1 << (component_width - 1)
    samples = [
        (3, 4, False),
        (-3, 4, False),
        (0, 0, True),
        (-limit, 0, False),
        (limit - 1, -(limit - 1), True),
    ]
    samples.extend(
        (rng.randrange(-limit, limit), rng.randrange(-limit, limit), index == 15)
        for index in range(16)
    )

    schedule = samples[:3] + [None, None] + samples[3:]
    expected = [((re_value * re_value + im_value * im_value) & result_mask, int(last))
                for re_value, im_value, last in samples]

    dut.s_axis.tdata.value = 0
    dut.s_axis.tvalid.value = 0
    dut.s_axis.tlast.value = 0
    await RisingEdge(dut.clk)

    receiver = cocotb.start_soon(receive(dut, len(expected)))
    for sample in schedule:
        await drive(dut, sample)
    await drive(dut, None)

    assert await receiver == expected
