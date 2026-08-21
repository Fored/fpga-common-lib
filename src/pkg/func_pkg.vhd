library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.types_pkg.all;

package func_pkg is

  function clog2 (inp : integer) return integer;
  function re (inp : axis_lite_t) return signed;
  function im (inp : axis_lite_t) return signed;
  function tvalid (axis : axis_arr_t) return std_logic_vector;
  function tvalid (axis : axis_lite_arr_t) return std_logic_vector;

end package func_pkg;

package body func_pkg is

  function clog2 (inp : integer) return integer is
    variable v   : integer;
    variable tmp : integer;
  begin
    v   := 0;
    tmp := 1;
    while tmp < inp loop
      v   := v + 1;
      tmp := tmp * 2;
    end loop;
    return v;
  end function clog2;

  function re (inp : axis_lite_t) return signed is
    constant c_component_width : natural := inp.tdata'length / 2;
  begin
    assert not inp.tdata'ascending and inp.tdata'length mod 2 = 0
      report "re: AXIS data must have descending range and even width"
      severity failure;
    return signed(inp.tdata(inp.tdata'low + c_component_width - 1 downto inp.tdata'low));
  end function re;

  function im (inp : axis_lite_t) return signed is
    constant c_component_width : natural := inp.tdata'length / 2;
  begin
    assert not inp.tdata'ascending and inp.tdata'length mod 2 = 0
      report "im: AXIS data must have descending range and even width"
      severity failure;
    return signed(inp.tdata(inp.tdata'high downto inp.tdata'low + c_component_width));
  end function im;

  function tvalid (axis : axis_lite_arr_t) return std_logic_vector is
    variable result : std_logic_vector(axis'range);
  begin
    for i in axis'range loop
      result(i) := axis(i).tvalid;
    end loop;
    return result;
  end function tvalid;

  function tvalid (axis : axis_arr_t) return std_logic_vector is
    variable result : std_logic_vector(axis'range);
  begin
    for i in axis'range loop
      result(i) := axis(i).tvalid;
    end loop;
    return result;
  end function tvalid;

end package body func_pkg;
