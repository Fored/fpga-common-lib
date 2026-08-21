library ieee;
  use ieee.std_logic_1164.all;

library work;
  use work.types_pack.all;
  use work.types_pkg.all;

entity xpm_fifo_arr is
  Generic (
    G_FIFO_NUM : integer;
    CLOCKING_MODE    : string  := "common_clock";
    FIFO_DEPTH       : integer := 16;
    TDATA_WIDTH      : integer := 32;
    FIFO_MEMORY_TYPE : string  := "auto"
  );
  Port (
    s_aclk    : in    std_logic;
    m_aclk    : in    std_logic;
    s_aresetn : in    std_logic;

    m_axis_tlast  : out   std_logic_vector(G_FIFO_NUM - 1 downto 0);
    m_axis_tdata  : out   std_matrix(G_FIFO_NUM - 1 downto 0)(TDATA_WIDTH - 1 downto 0);
    m_axis_tvalid : out   std_logic_vector(G_FIFO_NUM - 1 downto 0);
    m_axis_tready : in    std_logic_vector(G_FIFO_NUM - 1 downto 0);

    s_axis_tlast  : in    std_logic_vector(G_FIFO_NUM - 1 downto 0);
    s_axis_tdata  : in    std_matrix(G_FIFO_NUM - 1 downto 0)(TDATA_WIDTH - 1 downto 0);
    s_axis_tvalid : in    std_logic_vector(G_FIFO_NUM - 1 downto 0);
    s_axis_tready : out   std_logic_vector(G_FIFO_NUM - 1 downto 0)
  );
end entity xpm_fifo_arr;

architecture behavioral of xpm_fifo_arr is

  type axis_arr_t is array (G_FIFO_NUM - 1 downto 0) of axis_t(tdata(TDATA_WIDTH - 1 downto 0));

  signal m_axis, s_axis : axis_arr_t;

begin

  gen_fifo: for i in G_FIFO_NUM - 1 downto 0 generate
    m_axis_tlast(i)  <= m_axis(i).tlast;
    m_axis_tdata(i)  <= m_axis(i).tdata;
    m_axis_tvalid(i) <= m_axis(i).tvalid;
    m_axis(i).tready <= m_axis_tready(i);

    s_axis(i).tlast  <= s_axis_tlast(i);
    s_axis(i).tdata  <= s_axis_tdata(i);
    s_axis(i).tvalid <= s_axis_tvalid(i);
    s_axis_tready(i) <= s_axis(i).tready;

    inst_xpm_axis_fifo: entity work.xpm_axis_fifo
    Generic map (
      CLOCKING_MODE    => CLOCKING_MODE,
      FIFO_DEPTH       => FIFO_DEPTH,
      TDATA_WIDTH      => TDATA_WIDTH,
      FIFO_MEMORY_TYPE => FIFO_MEMORY_TYPE
    )
    Port map (
      s_aclk    => s_aclk,
      m_aclk    => m_aclk,
      s_aresetn => s_aresetn,
      almost_full => open,

      m_axis => m_axis(i),
      s_axis => s_axis(i)
    );
  end generate;
end architecture behavioral;
