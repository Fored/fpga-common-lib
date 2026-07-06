library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.types_pack.all;

entity bscan_to_stream is
  port (
    Clk_100 : in    std_logic;
    ClkDIn  : in    std_logic;
    ClkDOut : in    std_logic;
    Reset   : in    std_logic;
    DataIn  : in    uddcp_lite;
    DataOut : out   uddcp_lite
  );
end entity bscan_to_stream;

architecture behavioral of bscan_to_stream is

  constant REQUEST_SIGNATURE  : std_logic_vector(15 downto 0) := x"B5CA";
  constant RESPONSE_SIGNATURE : std_logic_vector(15 downto 0) := x"CA5B";
  constant FRAME_WIDTH        : positive := 50;
  constant SIGNATURE_LSB      : natural := 34;
  constant MESSAGE_BIT        : natural := 33;
  constant VALID_BIT          : natural := 32;

  component bscan_virtex6 is
    generic (
      JTAG_CHAIN : integer := 1
    );
    port (
      CAPTURE : out   std_logic;
      DRCK    : out   std_logic;
      RESET   : out   std_logic;
      RUNTEST : out   std_logic;
      SEL     : out   std_logic;
      SHIFT   : out   std_logic;
      TCK     : out   std_logic;
      TDI     : out   std_logic;
      TMS     : out   std_logic;
      UPDATE  : out   std_logic;
      TDO     : in    std_logic
    );
  end component bscan_virtex6;

  signal cap    : std_logic;
  signal drck   : std_logic;
  signal sel    : std_logic;
  signal shift  : std_logic;
  signal tck    : std_logic;
  signal tdi    : std_logic;
  signal update : std_logic;
  signal tdo_i  : std_logic;

  signal dr                                 : std_logic_vector(FRAME_WIDTH - 1 downto 0);
  signal fifo_read_dout                     : std_logic_vector(33 downto 0);
  signal fifo_read_rd_en,  fifo_read_empty  : std_logic;
  signal fifo_write_din,   fifo_write_dout  : std_logic_vector(33 downto 0);
  signal fifo_write_wr_en, fifo_write_empty : std_logic;
  signal fifo_write_valid                   : std_logic;
  signal captured_read_valid                : std_logic := '0';
  signal tck_d,            tck_d2           : std_logic;
  signal drck_d,           drck_d2          : std_logic;
  signal drck_d3                            : std_logic;
  signal drck_100,         tck_100          : std_logic;
  signal sel_100                            : std_logic;
  signal cap_100,          update_100       : std_logic;
  signal shift_100                          : std_logic;

  signal tdi_100 : std_logic;

begin

  u_bscan: component bscan_virtex6
    generic map (
      JTAG_CHAIN => 3
    )
    port map (
      CAPTURE => cap,
      DRCK    => drck,
      RESET   => open,
      RUNTEST => open,
      SEL     => sel,
      SHIFT   => shift,
      TCK     => tck,
      TDI     => tdi,
      TMS     => open,
      UPDATE  => update,
      TDO     => tdo_i
    );

  tdo_i <= dr(0);

  inst_fifo_bscan_write: entity work.fifo_bscan
    port map (
      rst    => Reset,
      wr_clk => Clk_100,
      rd_clk => ClkDOut,
      din    => fifo_write_din,
      wr_en  => fifo_write_wr_en,
      rd_en  => '1',
      dout   => fifo_write_dout,
      full   => open,
      empty  => fifo_write_empty,
      valid  => fifo_write_valid
    );

  DataOut.message_start <= fifo_write_dout(fifo_write_dout'high);
  DataOut.data_valid    <= fifo_write_valid;
  DataOut.data          <= fifo_write_dout(31 downto 0);

  inst_fifo_bscan_read: entity work.fifo_bscan
    port map (
      rst    => Reset,
      wr_clk => ClkDIn,
      rd_clk => Clk_100,
      din    => DataIn.message_start & DataIn.data_valid & DataIn.data,
      wr_en  => DataIn.data_valid,
      rd_en  => fifo_read_rd_en,
      dout   => fifo_read_dout,
      full   => open,
      empty  => fifo_read_empty,
      valid  => open
    );

  process (Clk_100) is
  begin
    if rising_edge(Clk_100) then
      drck_d     <= drck;
      drck_d2    <= drck_d;
      drck_d3    <= drck_d2;
      drck_100   <= drck_d2 and not drck_d3;
      tck_d      <= tck;
      tck_d2     <= tck_d;
      tck_100    <= tck_d and not tck_d2;
      cap_100    <= cap;
      sel_100    <= sel;
      shift_100  <= shift;
      update_100 <= update;
      tdi_100    <= tdi;
    end if;
  end process;

  process (Clk_100) is
  begin
    if rising_edge(Clk_100) then
      if (sel_100 = '1') then
        if (cap_100 = '1' and drck_100 = '1') then
          dr(dr'high downto SIGNATURE_LSB) <= RESPONSE_SIGNATURE;
          dr(MESSAGE_BIT)                  <= fifo_read_dout(MESSAGE_BIT);
          dr(VALID_BIT)                    <= not fifo_read_empty;
          dr(31 downto 0)                  <= fifo_read_dout(31 downto 0);
          captured_read_valid              <= not fifo_read_empty;
        elsif (shift_100 = '1' and drck_100 = '1') then
          dr <= tdi_100 & dr(dr'high downto 1);
        else
          dr <= dr;
        end if;
      else
        dr <= dr;
      end if;
    end if;
  end process;

  process (Clk_100) is
  begin
    if rising_edge(Clk_100) then
      fifo_write_wr_en <= '0';
      fifo_read_rd_en  <= '0';

      if (sel_100 = '1' and update_100 = '1' and tck_100 = '1'
          and dr(dr'high downto SIGNATURE_LSB) = REQUEST_SIGNATURE) then
        fifo_write_din   <= dr(MESSAGE_BIT downto 0);
        fifo_write_wr_en <= dr(VALID_BIT);
        fifo_read_rd_en  <= captured_read_valid;
      end if;
    end if;
  end process;

end architecture behavioral;
