library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.types_pkg.all;

-- Flat AXI4-Stream adapter for mixed-language integration.
-- Channel i occupies s_axis_tdata((i + 1) * G_DATA_WIDTH - 1 downto i * G_DATA_WIDTH).
entity serializer_flat is
  generic (
    G_CH_NUM     : natural range 2 to 124 := 8;
    G_DATA_WIDTH : natural                := 32;
    G_FIFO_DEPTH : integer                := 16;
    G_CLOCKING_MODE : string              := "common_clock"
  );
  port (
    clk_out     : in  std_logic;
    clk_user    : in  std_logic;
    rst         : in  std_logic;
    data_in_num : in  std_logic_vector(6 downto 0);

    s_axis_tdata  : in  std_logic_vector(G_CH_NUM * G_DATA_WIDTH - 1 downto 0);
    s_axis_tvalid : in  std_logic_vector(G_CH_NUM - 1 downto 0);
    s_axis_tready : out std_logic_vector(G_CH_NUM - 1 downto 0);
    s_axis_tlast  : in  std_logic_vector(G_CH_NUM - 1 downto 0);

    m_axis_tdata  : out std_logic_vector(G_DATA_WIDTH - 1 downto 0);
    m_axis_tvalid : out std_logic;
    m_axis_tready : in  std_logic;
    m_axis_tlast  : out std_logic
  );
end entity serializer_flat;

architecture rtl of serializer_flat is

  signal s_axis : axis_arr_t(G_CH_NUM - 1 downto 0)(tdata(G_DATA_WIDTH - 1 downto 0));
  signal m_axis : axis_t(tdata(G_DATA_WIDTH - 1 downto 0));

begin

  gen_s_axis: for i in G_CH_NUM - 1 downto 0 generate
    s_axis(i).tdata  <= s_axis_tdata((i + 1) * G_DATA_WIDTH - 1 downto i * G_DATA_WIDTH);
    s_axis(i).tvalid <= s_axis_tvalid(i);
    s_axis_tready(i) <= s_axis(i).tready;
    s_axis(i).tlast  <= s_axis_tlast(i);
  end generate gen_s_axis;

  m_axis_tdata  <= m_axis.tdata;
  m_axis_tvalid <= m_axis.tvalid;
  m_axis.tready <= m_axis_tready;
  m_axis_tlast  <= m_axis.tlast;

  inst_serializer: entity work.serializer
    generic map (
      G_CH_NUM     => G_CH_NUM,
      G_DATA_WIDTH => G_DATA_WIDTH,
      G_FIFO_DEPTH => G_FIFO_DEPTH,
      G_CLOCKING_MODE => G_CLOCKING_MODE
    )
    port map (
      clk_out     => clk_out,
      clk_user    => clk_user,
      rst         => rst,
      data_in_num => unsigned(data_in_num),
      s_axis      => s_axis,
      m_axis      => m_axis
    );

end architecture rtl;
