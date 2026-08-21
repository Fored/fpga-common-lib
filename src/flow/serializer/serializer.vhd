library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.types_pkg.all;
  use work.func_pkg.all;

entity serializer is
  generic (

    G_CH_NUM     : natural range 2 to 124 := 8;
    G_DATA_WIDTH : natural                := 32;
    G_FIFO_DEPTH : integer                := 16;
    G_CLOCKING_MODE : string              := "common_clock"
  );
  port (
    clk_out     : in    std_logic;
    clk_user    : in    std_logic;
    rst         : in    std_logic;
    data_in_num : in    unsigned(6 downto 0) := to_unsigned(G_CH_NUM, 7);
    s_axis      : inout axis_arr_t(G_CH_NUM - 1 downto 0)(tdata(G_DATA_WIDTH - 1 downto 0));
    m_axis      : inout axis_t(tdata(G_DATA_WIDTH - 1 downto 0))
  );
end entity serializer;

architecture behavioral of serializer is

  constant C_AXIS_LITE_ZERO : axis_lite_t(tdata(G_DATA_WIDTH - 1 downto 0)) :=
    (tdata => (others => '0'), tvalid => '0', tlast => '0');

  signal reset_reg        : std_logic;
  signal reset_reg_ser    : std_logic_vector(G_CH_NUM - 1 downto 0);
  signal reset_reg_out    : std_logic;
  signal fifo_m_axis      : axis_arr_t(G_CH_NUM - 1 downto 0)(tdata(G_DATA_WIDTH - 1 downto 0));
  signal fifo_out_s_axis  : axis_t(tdata(G_DATA_WIDTH - 1 downto 0));
  signal shift_axis       : axis_lite_arr_t(G_CH_NUM - 1 downto 0)(tdata(G_DATA_WIDTH - 1 downto 0));
  signal shift_empty      : std_logic;
  signal shift_tail_empty : std_logic;
  signal stripe_can_load  : std_logic;
  signal stripe_load      : std_logic;
  signal last_word_accept : std_logic;
  signal packet_open      : std_logic;
  signal active_ch_num    : natural range 1 to G_CH_NUM;

  attribute keep : string;
  attribute keep of reset_reg       : signal is "TRUE";
  attribute keep of reset_reg_ser   : signal is "TRUE";
  attribute keep of reset_reg_out   : signal is "TRUE";
  attribute max_fanout : integer;
  attribute max_fanout of reset_reg : signal is 1; -- Fanout from CDC

begin

  -- Полоса забирается из входных FIFO целиком. Пока последнее слово
  -- предыдущей полосы принимается выходным FIFO, можно сразу загрузить
  -- следующую полосу без промежуточного пустого такта.
  shift_empty <= '1' when tvalid(shift_axis) = (shift_axis'range => '0') else
                 '0';
  shift_tail_empty <= '1' when tvalid(shift_axis(shift_axis'high downto 1)) =
                                   (shift_axis'high downto 1 => '0') else
                        '0';
  last_word_accept <= shift_axis(0).tvalid and fifo_out_s_axis.tready and shift_tail_empty;
  stripe_can_load  <= shift_empty or last_word_accept;
  stripe_load      <= stripe_can_load and (and tvalid(fifo_m_axis));

  fifo_out_s_axis.tdata  <= shift_axis(0).tdata;
  fifo_out_s_axis.tvalid <= shift_axis(0).tvalid;
  fifo_out_s_axis.tlast  <= shift_axis(0).tlast;

  process (clk_user) is
  begin
    if rising_edge(clk_user) then
      reset_reg     <= rst;                                                   -- антислак
      reset_reg_ser <= (others => rst);                                       -- fix CDC-11
      reset_reg_out <= rst;
    end if;
  end process;

  process (clk_user) is

    variable loaded_ch_num : natural;

  begin
    if rising_edge(clk_user) then
      if (reset_reg = '1') then
        shift_axis   <= (others => (tdata => (others => '0'), tvalid => '0', tlast => '0'));
        packet_open  <= '0';
        active_ch_num <= G_CH_NUM;
      else
        if (stripe_load = '1') then
          if (packet_open = '0') then
            -- Новое число каналов вступает в силу только на границе пакета.
            loaded_ch_num := to_integer(data_in_num);
          else
            loaded_ch_num := active_ch_num;
          end if;

          for i in G_CH_NUM - 1 downto 0 loop
            shift_axis(i).tdata <= fifo_m_axis(i).tdata;
            if (i < loaded_ch_num) then
              shift_axis(i).tvalid <= '1';
            else
              shift_axis(i).tvalid <= '0';
            end if;

            if (i = loaded_ch_num - 1) then
              shift_axis(i).tlast <= fifo_m_axis(0).tlast;
            else
              shift_axis(i).tlast <= '0';
            end if;
          end loop;
          packet_open  <= not fifo_m_axis(0).tlast;
          active_ch_num <= loaded_ch_num;
        elsif (shift_axis(0).tvalid = '1' and fifo_out_s_axis.tready = '1') then
          shift_axis <= C_AXIS_LITE_ZERO & shift_axis(shift_axis'high downto 1);
        end if;
      end if;
    end if;
  end process;

  gen_fifo_ser: for i in G_CH_NUM - 1 downto 0 generate
  begin
    fifo_m_axis(i).tready <= stripe_load;

    inst_fifo_ser: entity work.xpm_axis_fifo
      generic map (
        CLOCKING_MODE => "common_clock",
        FIFO_DEPTH    => G_FIFO_DEPTH,
        TDATA_WIDTH   => G_DATA_WIDTH
      )
      port map (
        s_aclk      => clk_user,
        m_aclk      => clk_user,
        s_aresetn   => not reset_reg_ser(i),
        almost_full => open,
        m_axis      => fifo_m_axis(i),
        s_axis      => s_axis(i)
      );

  end generate gen_fifo_ser;

  inst_fifo_out: entity work.xpm_axis_fifo
    generic map (
      CLOCKING_MODE => G_CLOCKING_MODE,
      FIFO_DEPTH    => G_FIFO_DEPTH,
      TDATA_WIDTH   => G_DATA_WIDTH
    )
    port map (
      s_aclk      => clk_user,
      m_aclk      => clk_out,
      s_aresetn   => not reset_reg_out,
      almost_full => open,
      m_axis      => m_axis,
      s_axis      => fifo_out_s_axis
    );

end architecture behavioral;
