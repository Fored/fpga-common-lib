library ieee;
  use ieee.std_logic_1164.all;

package types_pkg is

  type std_matrix is array (natural range<>) of std_logic_vector;
  type std_tensor is array (natural range<>) of std_matrix;
  type int_arr is array (natural range <>) of integer;

  -- signal axis : axis_t(tdata(31 downto 0));
  type axis_t is record
    tdata  : std_logic_vector;
    tvalid : std_logic;
    tready : std_logic;
    tlast  : std_logic;
  end record axis_t;

  type axis_arr_t is array (natural range <>) of axis_t;

  type axis_lite_t is record
    tdata  : std_logic_vector;
    tvalid : std_logic;
    tlast  : std_logic;
  end record axis_lite_t;

  type axis_lite_arr_t is array (natural range <>) of axis_lite_t;

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

end package types_pkg;

package body types_pkg is

end package body types_pkg;
