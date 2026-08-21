library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.types_pkg.all;
  use work.func_pkg.all;

entity instant_power is
  Port (
    clk : in    std_logic;

    s_axis : in    axis_lite_t;
    m_axis : out   axis_lite_t
  );
end entity instant_power;

architecture behavioral of instant_power is

  signal square_re, square_im : signed(s_axis.tdata'length - 1 downto 0) := (others => '0');
  signal square_valid, square_last : std_logic := '0';

begin

  assert s_axis.tdata'length = m_axis.tdata'length
    report "instant_power: input and output AXIS data widths must match"
    severity failure;

  square_proc: process (clk) is
  begin
    if rising_edge(clk) then
      square_re    <= re(s_axis) * re(s_axis);
      square_im    <= im(s_axis) * im(s_axis);
      square_valid <= s_axis.tvalid;
      square_last  <= s_axis.tlast;
    end if;
  end process square_proc;

  square_sum_proc: process (clk) is
  begin
    if rising_edge(clk) then
      m_axis.tdata  <= std_logic_vector(square_re + square_im);
      m_axis.tvalid <= square_valid;
      m_axis.tlast  <= square_last;
    end if;
  end process square_sum_proc;

end architecture behavioral;
