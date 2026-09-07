library ieee;
  use ieee.std_logic_1164.all;

library work;
  use work.types_pkg.all;

-- Flat adapter for using the record-based xpm_axis_fifo from SystemVerilog.
entity xpm_axis_fifo_flat is
  generic (
    G_FIFO_DEPTH       : integer := 16;
    G_TDATA_WIDTH      : integer := 32;
    G_FIFO_MEMORY_TYPE : string  := "auto"
  );
  port (
    clk      : in  std_logic;
    aresetn  : in  std_logic;

    s_axis_tdata  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    s_axis_tvalid : in  std_logic;
    s_axis_tready : out std_logic;
    s_axis_tlast  : in  std_logic;

    m_axis_tdata  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    m_axis_tvalid : out std_logic;
    m_axis_tready : in  std_logic;
    m_axis_tlast  : out std_logic
  );
end entity xpm_axis_fifo_flat;

architecture rtl of xpm_axis_fifo_flat is
  signal s_axis : axis_t(tdata(G_TDATA_WIDTH - 1 downto 0));
  signal m_axis : axis_t(tdata(G_TDATA_WIDTH - 1 downto 0));
begin

  s_axis.tdata  <= s_axis_tdata;
  s_axis.tvalid <= s_axis_tvalid;
  s_axis.tlast  <= s_axis_tlast;
  s_axis_tready <= s_axis.tready;

  m_axis_tdata  <= m_axis.tdata;
  m_axis_tvalid <= m_axis.tvalid;
  m_axis.tready <= m_axis_tready;
  m_axis_tlast  <= m_axis.tlast;

  inst_fifo: entity work.xpm_axis_fifo
    generic map (
      CLOCKING_MODE    => "common_clock",
      FIFO_DEPTH       => G_FIFO_DEPTH,
      TDATA_WIDTH      => G_TDATA_WIDTH,
      FIFO_MEMORY_TYPE => G_FIFO_MEMORY_TYPE
    )
    port map (
      s_aclk      => clk,
      m_aclk      => clk,
      s_aresetn   => aresetn,
      almost_full => open,
      s_axis      => s_axis,
      m_axis      => m_axis
    );

end architecture rtl;
