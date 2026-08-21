library ieee;
  use ieee.std_logic_1164.all;

library work;
  use work.types_pkg.all;

-- Flat AXI4-Stream Lite adapter for mixed-language integration.
-- TDATA contains IM in the upper half and RE in the lower half.
entity instant_power_flat is
  generic (
    G_DATA_WIDTH : positive := 64
  );
  port (
    clk : in    std_logic;

    s_axis_tdata  : in    std_logic_vector(G_DATA_WIDTH - 1 downto 0);
    s_axis_tvalid : in    std_logic;
    s_axis_tlast  : in    std_logic;

    m_axis_tdata  : out   std_logic_vector(G_DATA_WIDTH - 1 downto 0);
    m_axis_tvalid : out   std_logic;
    m_axis_tlast  : out   std_logic
  );
end entity instant_power_flat;

architecture rtl of instant_power_flat is

  signal s_axis : axis_lite_t(tdata(G_DATA_WIDTH - 1 downto 0));
  signal m_axis : axis_lite_t(tdata(G_DATA_WIDTH - 1 downto 0));

begin

  assert G_DATA_WIDTH mod 2 = 0
    report "instant_power_flat: G_DATA_WIDTH must be even"
    severity failure;

  s_axis.tdata  <= s_axis_tdata;
  s_axis.tvalid <= s_axis_tvalid;
  s_axis.tlast  <= s_axis_tlast;

  m_axis_tdata  <= m_axis.tdata;
  m_axis_tvalid <= m_axis.tvalid;
  m_axis_tlast  <= m_axis.tlast;

  inst_instant_power: entity work.instant_power
    port map (
      clk    => clk,
      s_axis => s_axis,
      m_axis => m_axis
    );

end architecture rtl;
