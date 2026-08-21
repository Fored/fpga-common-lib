library ieee;
  use ieee.std_logic_1164.all;

library work;
  use work.types_pkg.all;
  use work.func_pkg.all;

entity adder_tree_complex is
  Generic (

    G_CH_NUM     : integer;
    G_DATA_WIDTH : natural
  );
  Port (
    clk : in    std_logic;
    rst : in    std_logic;

    s_re    : in    std_matrix(G_CH_NUM - 1 downto 0)(G_DATA_WIDTH - 1 downto 0);
    s_im    : in    std_matrix(G_CH_NUM - 1 downto 0)(G_DATA_WIDTH - 1 downto 0);
    s_valid : in    std_logic;
    s_last  : in    std_logic;

    m_re    : out   std_logic_vector(G_DATA_WIDTH + clog2(G_CH_NUM) - 1 downto 0);
    m_im    : out   std_logic_vector(G_DATA_WIDTH + clog2(G_CH_NUM) - 1 downto 0);
    m_valid : out   std_logic;
    m_last  : out   std_logic
  );
end entity adder_tree_complex;

architecture behavioral of adder_tree_complex is

begin

  inst_adder_tree_re: entity work.adder_tree
    generic map (

      G_CH_NUM     => G_CH_NUM,
      G_DATA_WIDTH => G_DATA_WIDTH
    )
    port map (
      clk => clk,
      rst => rst,

      s_data  => s_re,
      s_valid => s_valid,
      s_last  => s_last,

      m_data  => m_re,
      m_valid => m_valid,
      m_last  => m_last
    );

  inst_adder_tree_im: entity work.adder_tree
    generic map (

      G_CH_NUM     => G_CH_NUM,
      G_DATA_WIDTH => G_DATA_WIDTH
    )
    port map (
      clk => clk,
      rst => rst,

      s_data  => s_im,
      s_valid => s_valid,
      s_last  => s_last,

      m_data  => m_im,
      m_valid => open,
      m_last  => open
    );

end architecture behavioral;
