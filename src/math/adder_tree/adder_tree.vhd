library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

library work;
  use work.types_pkg.all;
  use work.func_pkg.all;

entity adder_tree is
  Generic (

    G_CH_NUM     : integer;
    G_DATA_WIDTH : natural
  );
  Port (
    clk : in    std_logic;
    rst : in    std_logic;

    s_data  : in    std_matrix(G_CH_NUM - 1 downto 0)(G_DATA_WIDTH - 1 downto 0);
    s_valid : in    std_logic;
    s_last  : in    std_logic;

    m_data  : out   std_logic_vector(G_DATA_WIDTH + clog2(G_CH_NUM) - 1 downto 0);
    m_valid : out   std_logic;
    m_last  : out   std_logic
  );
end entity adder_tree;

architecture behavioral of adder_tree is

  constant c_tree_lvl  : integer := clog2(G_CH_NUM);
  signal   sum_steps   : std_tensor(c_tree_lvl + 1 - 1 downto 0)(G_CH_NUM - 1 downto 0)(G_DATA_WIDTH + c_tree_lvl - 1 downto 0);
  signal   valid_steps : std_logic_vector(c_tree_lvl - 1 downto 0);
  signal   last_steps  : std_logic_vector(c_tree_lvl - 1 downto 0);
  function ch_num_f return int_arr is
    variable result : int_arr(c_tree_lvl + 1 - 1 downto 0);
  begin
    result(0) := G_CH_NUM;
    for i in 1 to c_tree_lvl + 1 - 1 loop
      result(i) := integer(ceil(real(result(i - 1)) / real(2)));
    end loop;
    return result;
  end function ch_num_f;

  constant ch_num : int_arr := ch_num_f;

  function resize (inp: std_matrix; size : integer) return std_matrix is
    variable result : std_matrix(inp'range)(size - 1 downto 0);
  begin
    for i in inp'range loop
      result(i) := std_logic_vector(resize(signed(inp(i)), size));
    end loop;
    return result;
  end function resize;

begin

  m_data  <= sum_steps(sum_steps'high)(0);
  m_valid <= valid_steps(valid_steps'high);
  m_last  <= last_steps(last_steps'high);

  process (clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        valid_steps <= (others => '0');
        last_steps  <= (others => '0');
      else
        valid_steps <= valid_steps(valid_steps'high - 1 downto 0) & s_valid;
        last_steps  <= last_steps(last_steps'high - 1 downto 0) & s_last;
      end if;
    end if;
  end process;

  gen_datain: for i in G_CH_NUM - 1 downto 0 generate
    sum_steps(0)(i) <= std_logic_vector(resize(signed(s_data(i)), G_DATA_WIDTH + c_tree_lvl));
  end generate gen_datain;

  gen_m_sum_pair: for i in 0 to c_tree_lvl - 1 generate

    inst_m_sum_pair: entity work.adder_pair
      generic map (

        G_CH_NUM         => ch_num(i),
        G_DATA_WIDTH     => G_DATA_WIDTH + i,
        G_DATA_OUT_WIDTH => G_DATA_WIDTH + c_tree_lvl
      )
      port map (
        clk    => clk,
        s_data => resize(sum_steps(i)(ch_num(i) - 1 downto 0), G_DATA_WIDTH + i),
        m_data => sum_steps(i + 1)(ch_num(i + 1) - 1 downto 0)
      );

  end generate gen_m_sum_pair;

end architecture behavioral;
