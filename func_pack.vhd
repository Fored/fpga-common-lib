library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

package func_pack is

  function h1 (inp : std_logic_vector) return integer; -- high_1 найти старшую единицу можно использовать вместо log2
  function h1 (inp : integer) return integer;

end package func_pack;

package body func_pack is

  function h1 (inp : std_logic_vector) return integer is
  begin
    for i in inp'high downto inp'low loop
      if (inp(i) = '1') then
        return i;
      end if;
    end loop;
    -- all zero
    return 0;
  end function h1;

  function h1 (inp : integer) return integer is
  begin
    return h1(std_logic_vector(to_unsigned(inp, 32)));
  end function h1;

end package body func_pack;