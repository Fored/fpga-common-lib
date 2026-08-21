library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

library work;
  use work.types_pkg.all;

entity adder_pair is
  Generic (

    G_CH_NUM         : integer;
    G_DATA_WIDTH     : integer;
    G_DATA_OUT_WIDTH : integer
  );
  Port (
    clk : in    std_logic;

    s_data : in    std_matrix(G_CH_NUM - 1 downto 0)(G_DATA_WIDTH - 1 downto 0);

    m_data : out   std_matrix(integer(ceil(real(G_CH_NUM) / real(2))) - 1 downto 0)(G_DATA_OUT_WIDTH - 1 downto 0)
  );
end entity adder_pair;

architecture behavioral of adder_pair is

  constant c_out_num : integer := integer(ceil(real(G_CH_NUM) / real(2)));

begin

  gen_sum: for i in 0 to c_out_num - 1 generate

    sum_proc: process (clk) is

      variable a : signed(G_DATA_WIDTH - 1 downto 0);
      variable b : signed(G_DATA_OUT_WIDTH - 1 downto 0);

    begin
      if rising_edge(clk) then
        if (i * 2 + 1 <= G_CH_NUM - 1) then
          a         := signed(s_data(i * 2));
          b         := resize(signed(s_data(i * 2 + 1)), G_DATA_OUT_WIDTH);
          m_data(i) <= std_logic_vector(a + b);
        else
          m_data(i) <= std_logic_vector(resize(signed(s_data(i * 2)), G_DATA_OUT_WIDTH));
        end if;
      end if;
    end process sum_proc;

  end generate gen_sum;

end architecture behavioral;
