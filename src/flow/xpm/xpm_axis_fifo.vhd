library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library xpm;
  use xpm.vcomponents.all;

library work;
  use work.types_pkg.all;

entity xpm_axis_fifo is
  Generic (
    CLOCKING_MODE    : string  := "common_clock";
    FIFO_DEPTH       : integer := 16;
    TDATA_WIDTH      : integer := 32;
    FIFO_MEMORY_TYPE : string  := "auto"
  );
  Port (
    s_aclk    : in    std_logic;
    m_aclk    : in    std_logic;
    s_aresetn : in    std_logic;

    almost_full : out   std_logic;

    m_axis : inout axis_t(tdata(TDATA_WIDTH - 1 downto 0));
    s_axis : inout axis_t(tdata(TDATA_WIDTH - 1 downto 0))
  );
end entity xpm_axis_fifo;

architecture behavioral of xpm_axis_fifo is

  constant C_XPM_DATA_WIDTH : natural := 8 * ((TDATA_WIDTH + 7) / 8);

  signal xpm_s_axis : axis_t(tdata(C_XPM_DATA_WIDTH - 1 downto 0));
  signal xpm_m_axis : axis_t(tdata(C_XPM_DATA_WIDTH - 1 downto 0));

begin

  xpm_s_axis.tdata  <= std_logic_vector(resize(unsigned(s_axis.tdata), C_XPM_DATA_WIDTH));
  xpm_s_axis.tvalid <= s_axis.tvalid;
  s_axis.tready     <= xpm_s_axis.tready;
  xpm_s_axis.tlast  <= s_axis.tlast;

  m_axis.tdata      <= xpm_m_axis.tdata(TDATA_WIDTH - 1 downto 0);
  m_axis.tvalid     <= xpm_m_axis.tvalid;
  xpm_m_axis.tready <= m_axis.tready;
  m_axis.tlast      <= xpm_m_axis.tlast;

  xpm_fifo_axis_inst: component xpm_fifo_axis
    generic map (
      CASCADE_HEIGHT      => 0,
      CDC_SYNC_STAGES     => 2,
      CLOCKING_MODE       => CLOCKING_MODE,
      ECC_MODE            => "no_ecc",
      FIFO_DEPTH          => FIFO_DEPTH,
      FIFO_MEMORY_TYPE    => FIFO_MEMORY_TYPE,
      PACKET_FIFO         => "false",
      PROG_EMPTY_THRESH   => 10,
      PROG_FULL_THRESH    => 10,
      RD_DATA_COUNT_WIDTH => 1,
      RELATED_CLOCKS      => 0,
      SIM_ASSERT_CHK      => 0,
      TDATA_WIDTH         => C_XPM_DATA_WIDTH,
      TDEST_WIDTH         => 1,
      TID_WIDTH           => 1,
      TUSER_WIDTH         => 1,
      USE_ADV_FEATURES    => "1000",
      WR_DATA_COUNT_WIDTH => 1
    )
    port map (
      almost_empty_axis => open,
      -- indicates that only one more read can be performed before
      -- the FIFO goes to empty.

      almost_full_axis => almost_full,
      -- indicates that only one more write can be performed before
      -- the FIFO is full.

      dbiterr_axis => open,
      -- decoder detected a double-bit error and data in the FIFO
      -- core is corrupted.

      m_axis_tdata => xpm_m_axis.tdata,
      -- used to provide the data that is passing across the
      -- interface. The width of the data payload is an integer
      -- number of bytes.

      m_axis_tdest => open,
      -- for the data stream.

      m_axis_tid => open,
      -- indicates different streams of data.

      m_axis_tkeep => open,
      -- indicates whether the content of the associated byte of
      -- TDATA is processed as part of the data stream. Associated
      -- bytes that have the TKEEP byte qualifier deasserted are null
      -- bytes and can be removed from the data stream. For a 64-bit
      -- DATA, bit 0 corresponds to the least significant byte on
      -- DATA, and bit 7 corresponds to the most significant byte.
      -- For example: KEEP[0] = 1b, DATA[7:0] is not a NULL byte
      -- KEEP[7] = 0b, DATA[63:56] is a NULL byte

      m_axis_tlast => xpm_m_axis.tlast,
      m_axis_tstrb => open,
      -- indicates whether the content of the associated byte of
      -- TDATA is processed as a data byte or a position byte. For a
      -- 64-bit DATA, bit 0 corresponds to the least significant byte
      -- on DATA, and bit 0 corresponds to the least significant byte
      -- on DATA, and bit 7 corresponds to the most significant byte.
      -- For example: STROBE[0] = 1b, DATA[7:0] is valid STROBE[7] =
      -- 0b, DATA[63:56] is not valid

      m_axis_tuser => open,
      -- information that can be transmitted alongside the data
      -- stream.

      m_axis_tvalid => xpm_m_axis.tvalid,
      -- valid transfer. A transfer takes place when both TVALID and
      -- TREADY are asserted

      prog_empty_axis => open,
      -- when the number of words in the FIFO is less than or equal
      -- to the programmable empty threshold value. It is de-asserted
      -- when the number of words in the FIFO exceeds the
      -- programmable empty threshold value.

      prog_full_axis => open,
      -- when the number of words in the FIFO is greater than or
      -- equal to the programmable full threshold value. It is
      -- de-asserted when the number of words in the FIFO is less
      -- than the programmable full threshold value.

      rd_data_count_axis => open,
      -- indicates the number of words available for reading in the
      -- FIFO.

      s_axis_tready => xpm_s_axis.tready,
      -- transfer in the current cycle.

      sbiterr_axis => open,
      -- decoder detected and fixed a single-bit error.

      wr_data_count_axis => open,
      -- indicates the number of words written into the FIFO.

      injectdbiterr_axis => '0',
      -- bit error if the ECC feature is used.

      injectsbiterr_axis => '0',
      -- bit error if the ECC feature is used.

      m_aclk => m_aclk,
      -- interface are sampled on the rising edge of this clock.

      m_axis_tready => xpm_m_axis.tready,
      -- transfer in the current cycle.

      s_aclk => s_aclk,
      -- interface are sampled on the rising edge of this clock.

      s_aresetn    => s_aresetn,
      s_axis_tdata => xpm_s_axis.tdata,
      -- used to provide the data that is passing across the
      -- interface. The width of the data payload is an integer
      -- number of bytes.

      s_axis_tdest => (others => '0'),
      -- for the data stream.

      s_axis_tid => (others => '0'),
      -- indicates different streams of data.

      s_axis_tkeep => (others => '1'),
      -- indicates whether the content of the associated byte of
      -- TDATA is processed as part of the data stream. Associated
      -- bytes that have the TKEEP byte qualifier deasserted are null
      -- bytes and can be removed from the data stream. For a 64-bit
      -- DATA, bit 0 corresponds to the least significant byte on
      -- DATA, and bit 7 corresponds to the most significant byte.
      -- For example: KEEP[0] = 1b, DATA[7:0] is not a NULL byte
      -- KEEP[7] = 0b, DATA[63:56] is a NULL byte

      s_axis_tlast => xpm_s_axis.tlast,
      s_axis_tstrb => (others => '0'),
      -- indicates whether the content of the associated byte of
      -- TDATA is processed as a data byte or a position byte. For a
      -- 64-bit DATA, bit 0 corresponds to the least significant byte
      -- on DATA, and bit 0 corresponds to the least significant byte
      -- on DATA, and bit 7 corresponds to the most significant byte.
      -- For example: STROBE[0] = 1b, DATA[7:0] is valid STROBE[7] =
      -- 0b, DATA[63:56] is not valid

      s_axis_tuser => (others => '0'),
      -- information that can be transmitted alongside the data
      -- stream.

      s_axis_tvalid => xpm_s_axis.tvalid
    -- valid transfer. A transfer takes place when both TVALID and
    -- TREADY are asserted

    );

end architecture behavioral;
