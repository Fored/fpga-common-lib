library ieee;
  use ieee.std_logic_1164.all;

library work;
  use work.types_pkg.all;

-- Flat AXI4-Stream adapter for mixed-language integration.
-- Channel i occupies m_axis_tdata((i + 1) * G_DATA_WIDTH - 1 downto i * G_DATA_WIDTH).
entity deserializer_flat is
  generic (
    G_CH_NUM     : natural := 8;
    G_DATA_WIDTH : natural := 32;
    G_FIFO_DEPTH : integer := 16;
    G_CLOCKING_MODE : string := "common_clock"
  );
  port (
    clk_in   : in  std_logic;
    clk_user : in  std_logic;
    rst      : in  std_logic;

    s_axis_tdata  : in  std_logic_vector(G_DATA_WIDTH - 1 downto 0);
    s_axis_tvalid : in  std_logic;
    s_axis_tready : out std_logic;
    s_axis_tlast  : in  std_logic;

    m_axis_tdata  : out std_logic_vector(G_CH_NUM * G_DATA_WIDTH - 1 downto 0);
    m_axis_tvalid : out std_logic_vector(G_CH_NUM - 1 downto 0);
    m_axis_tready : in  std_logic_vector(G_CH_NUM - 1 downto 0);
    m_axis_tlast  : out std_logic_vector(G_CH_NUM - 1 downto 0)
  );
end entity deserializer_flat;

architecture rtl of deserializer_flat is
  signal s_axis : axis_t(tdata(G_DATA_WIDTH - 1 downto 0));
  signal m_axis : axis_arr_t(G_CH_NUM - 1 downto 0)(tdata(G_DATA_WIDTH - 1 downto 0));
begin

  s_axis.tdata  <= s_axis_tdata;
  s_axis.tvalid <= s_axis_tvalid;
  s_axis.tlast  <= s_axis_tlast;
  s_axis_tready <= s_axis.tready;

  gen_m_axis: for i in G_CH_NUM - 1 downto 0 generate
    m_axis_tdata((i + 1) * G_DATA_WIDTH - 1 downto i * G_DATA_WIDTH) <= m_axis(i).tdata;
    m_axis_tvalid(i) <= m_axis(i).tvalid;
    m_axis(i).tready <= m_axis_tready(i);
    m_axis_tlast(i)  <= m_axis(i).tlast;
  end generate gen_m_axis;

  inst_deserializer: entity work.deserializer
    generic map (
      G_CH_NUM     => G_CH_NUM,
      G_DATA_WIDTH => G_DATA_WIDTH,
      G_FIFO_DEPTH => G_FIFO_DEPTH,
      G_CLOCKING_MODE => G_CLOCKING_MODE
    )
    port map (
      clk_in   => clk_in,
      clk_user => clk_user,
      rst      => rst,
      s_axis   => s_axis,
      m_axis   => m_axis
    );

end architecture rtl;
