library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

package types_pack is

  type uddcp_lite is record
    message_start : std_logic;
    data          : std_logic_vector(31 downto 0);
    data_valid    : std_logic;
  end record uddcp_lite;

  type mem_port is record
    addr       : std_logic_vector(31 downto 0);
    data       : std_logic_vector(31 downto 0);
    data_valid : std_logic;
    read_req   : std_logic;
  end record mem_port;

  type int_array is array(natural range <>) of integer;

end package types_pack;
