library ieee;
  use ieee.std_logic_1164.all;

package types_pack_93 is

  type std_matrix4 is array(natural range <>) of std_logic_vector(3 downto 0);
  type std_matrix16 is array(natural range <>) of std_logic_vector(15 downto 0);
  type std_matrix32 is array(natural range <>) of std_logic_vector(31 downto 0);
  type std_matrix64 is array(natural range <>) of std_logic_vector(63 downto 0);

end package types_pack_93;