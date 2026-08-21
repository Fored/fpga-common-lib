from cocotb.triggers import RisingEdge


def set_axis_idle(s_axis, m_axis=None):
    s_axis.tvalid.value = 0
    s_axis.tlast.value = 0

    if hasattr(s_axis.tdata, "re"):
        s_axis.tdata.re.value = 0
        s_axis.tdata.im.value = 0
    else:
        s_axis.tdata.value = 0

    if m_axis is not None:
        m_axis.tready.value = 1


def set_axis_data(axis, value):
    if hasattr(axis.tdata, "re"):
        re_value, im_value = value
        axis.tdata.re.value = re_value
        axis.tdata.im.value = im_value
    else:
        axis.tdata.value = value


def get_axis_data(axis):
    if hasattr(axis.tdata, "re"):
        return (
            axis.tdata.re.value.to_signed(),
            axis.tdata.im.value.to_signed(),
        )

    return axis.tdata.value.to_signed()


async def send_axis_sample(clk, axis, value, last=False):
    set_axis_data(axis, value)
    axis.tlast.value = int(last)
    axis.tvalid.value = 1

    while True:
        await RisingEdge(clk)
        if int(axis.tready.value) == 1:
            break

    axis.tvalid.value = 0
    axis.tlast.value = 0


async def send_axis_bytes(clk, axis, data):
    for index, byte in enumerate(data):
        await send_axis_sample(clk, axis, byte, last=(index == len(data) - 1))


async def send_axis_words_from_bytes(clk, axis, data, *, allow_partial_word=False):
    if len(data) % 4 != 0 and not allow_partial_word:
        raise AssertionError("32-bit AXIS payload must contain a whole number of words")

    for index in range(0, len(data), 4):
        chunk = data[index : index + 4]
        word = int.from_bytes(chunk.ljust(4, b"\x00"), byteorder="little")
        await send_axis_sample(clk, axis, word, last=(index + 4 >= len(data)))


async def recv_axis_samples(clk, axis, count, timeout_cycles, require_count=False):
    samples = []

    for _ in range(timeout_cycles):
        await RisingEdge(clk)
        if int(axis.tvalid.value) == 1 and int(axis.tready.value) == 1:
            samples.append((get_axis_data(axis), int(axis.tlast.value)))
            if len(samples) == count:
                break

    if require_count and len(samples) != count:
        raise AssertionError(f"Timed out waiting for {count} AXIS samples, received {len(samples)}")

    return samples


async def recv_axis_data(clk, axis, count, timeout_cycles, require_count=False):
    samples = await recv_axis_samples(
        clk,
        axis,
        count=count,
        timeout_cycles=timeout_cycles,
        require_count=require_count,
    )
    return [data for data, _ in samples]


async def recv_axis_bytes(clk, axis, count, timeout_cycles, require_count=False):
    return [
        byte & 0xFF
        for byte in await recv_axis_data(
            clk,
            axis,
            count=count,
            timeout_cycles=timeout_cycles,
            require_count=require_count,
        )
    ]


async def reset_dut(dut, active_cycles=5, settle_cycles=2):
    dut.rst.value = 1

    for _ in range(active_cycles):
        await RisingEdge(dut.clk)

    dut.rst.value = 0

    for _ in range(settle_cycles):
        await RisingEdge(dut.clk)
