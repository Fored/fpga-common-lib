import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


async def drive_input(dut, samples_re, samples_im, valid, last):
    for channel in range(len(samples_re)):
        dut.s_re[channel].value = samples_re[channel]
        dut.s_im[channel].value = samples_im[channel]
    dut.s_valid.value = valid
    dut.s_last.value = last


async def send_schedule(dut, schedule):
    zero = [0] * len(dut.s_re)

    for item in schedule:
        if item is None:
            await drive_input(dut, zero, zero, valid=False, last=False)
        else:
            await drive_input(dut, item[0], item[1], valid=True, last=item[2])
        await RisingEdge(dut.clk)

    await drive_input(dut, zero, zero, valid=False, last=False)


async def receive_results(dut, count, timeout_cycles=100):
    results = []

    for _ in range(timeout_cycles):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")

        if dut.m_valid.value.is_resolvable and int(dut.m_valid.value):
            results.append(
                (dut.m_re.value.to_signed(), dut.m_im.value.to_signed(), int(dut.m_last.value))
            )
            if len(results) == count:
                return results

    raise AssertionError(f"Не получены все результаты: {len(results)} из {count}")


@cocotb.test()
async def test_adder_tree_complex(dut):
    """Проверяет сброс, сумму, знаковую арифметику, valid- и last-конвейеры."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start(start_high=False))

    ch_num = len(dut.s_re)
    zero = [0] * ch_num
    dut.rst.value = True
    await drive_input(dut, zero, zero, valid=False, last=False)
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    assert int(dut.m_valid.value) == 0
    assert int(dut.m_last.value) == 0
    await RisingEdge(dut.clk)
    dut.rst.value = False

    transactions = [
        ([channel + 1 for channel in range(ch_num)], [-(channel + 1) for channel in range(ch_num)], False),
        ([(-1) ** channel * (10 + channel) for channel in range(ch_num)],
         [(-1) ** (channel + 1) * (20 + channel) for channel in range(ch_num)], True),
        ([50 - 3 * channel for channel in range(ch_num)], [-50 + 2 * channel for channel in range(ch_num)], False),
    ]
    schedule = [transactions[0], transactions[1], None, transactions[2]]
    expected = [(sum(samples_re), sum(samples_im), last) for samples_re, samples_im, last in transactions]

    receive_task = cocotb.start_soon(receive_results(dut, count=len(expected)))
    await send_schedule(dut, schedule)

    assert await receive_task == expected
