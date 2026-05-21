----------------------------------------------------------------------------------
--  Преобразует данные из памяти (mem_port) в массив 32-хбитных слов
--  (std_matrix32) и наоборот.
--
--  G_RANGE             -- диапазон адресного пространства
--  G_REG_ARRAY_DEFAULT -- дефолтные настройки в случае сброса
--  G_READ_ONLY         -- запись/чтение :or: только чтение
----------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.types_pack_93.all;
  use work.types_pack.all;
  use work.func_pack.all;

entity m_mem_reg is
  Generic (
    G_RANGE             : natural;
    G_REG_ARRAY_DEFAULT : std_matrix32;
    G_READ_ONLY         : boolean
  );
  Port (
    Clk   : in    std_logic;
    Reset : in    std_logic;

    MemIn  : in    mem_port;
    MemOut : out   mem_port;

    RegArray        : out   std_matrix32     (G_RANGE - 1 downto 0);
    RegArrayIn      : in    std_matrix32     (G_RANGE - 1 downto 0) := (others => (others => '0'));
    RegArrayInValid : in    std_logic_vector(G_RANGE - 1 downto 0)  := (others => '0')
  );
end entity m_mem_reg;

architecture arch of m_mem_reg is

  constant c_addr_high : integer := h1(G_RANGE - 1);
  signal   settings    : std_matrix32(G_RANGE - 1 downto 0);

begin

  RegArray <= settings;

  read_proc: process (Clk) is
  begin
    if rising_edge(Clk) then
      if (Reset = '1') then
        MemOut.data_valid <= '0';
      else
        MemOut.data_valid <= MemIn.read_req;
        if (unsigned(MemIn.addr(c_addr_high downto 0)) < G_RANGE) then
          MemOut.data <= settings(to_integer(unsigned(MemIn.addr(c_addr_high downto 0))));
        else
          MemOut.data <= (others => '0');
        end if;
      end if;
    end if;
  end process;

  gen_read_only: if G_READ_ONLY generate
    settings <= RegArrayIn;
  end generate gen_read_only;

  gen_not_read_only: if not G_READ_ONLY generate

    wr_proc: process (Clk) is
    begin
      if rising_edge(Clk) then
        if (Reset = '1') then
          settings <= G_REG_ARRAY_DEFAULT;
        else
          if (unsigned(MemIn.addr(c_addr_high downto 0)) < G_RANGE and MemIn.data_valid = '1') then
            settings(to_integer(unsigned(MemIn.addr(c_addr_high downto 0)))) <= MemIn.data;
          elsif (unsigned(RegArrayInValid) > 0) then
            for i in G_RANGE - 1 downto 0 loop
              if (RegArrayInValid(i) = '1') then
                settings(i) <= RegArrayIn(i);
              else
                settings(i) <= settings(i);
              end if;
            end loop;
          else
            settings <= settings;
          end if;
        end if;
      end if;
    end process;

  end generate gen_not_read_only;

end architecture arch;
