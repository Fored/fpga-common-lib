library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.types_pkg.all;

entity deserializer is
  Generic (

    G_CH_NUM     : natural := 8;
    G_DATA_WIDTH : natural := 32;
    G_FIFO_DEPTH : integer := 16;
    G_CLOCKING_MODE : string := "common_clock"
  );
  Port (
    clk_in   : in    std_logic;
    clk_user : in    std_logic;
    rst      : in    std_logic;
    s_axis : inout axis_t(tdata(G_DATA_WIDTH - 1 downto 0));
    m_axis : inout axis_arr_t(G_CH_NUM - 1 downto 0)(tdata(G_DATA_WIDTH - 1 downto 0))
  );
end entity deserializer;

architecture behavioral of deserializer is

  signal reset_reg       : std_logic;
  signal reset_reg_deser : std_logic_vector(G_CH_NUM - 1 downto 0);
  signal fifo_almost_full : std_logic_vector(G_CH_NUM - 1 downto 0);
  signal fifo_s_axis, fifo_m_axis : axis_arr_t(G_CH_NUM - 1 downto 0)(tdata(G_DATA_WIDTH - 1 downto 0));
  signal fifo_s_ready : std_logic_vector(G_CH_NUM - 1 downto 0);
  signal stripe_data, stripe_data_next : std_matrix(G_CH_NUM - 1 downto 0)(G_DATA_WIDTH - 1 downto 0);
  signal channel_index : std_logic_vector(G_CH_NUM - 1 downto 0);
  signal fifo_can_accept, fifo_all_ready, stripe_write_en : std_logic;

  attribute keep : string;
  attribute keep of reset_reg       : signal is "TRUE";
  attribute keep of reset_reg_deser : signal is "TRUE";
  attribute max_fanout : integer;
  attribute max_fanout of reset_reg : signal is 1; -- Fanout from CDC

begin

  fifo_can_accept <= '1' when unsigned(fifo_almost_full) = 0 else '0';
  fifo_all_ready  <= '1' when fifo_s_ready = (fifo_s_ready'range => '1') else '0';
  stripe_data_next <= s_axis.tdata & stripe_data(stripe_data'high downto 1);
  stripe_write_en <= s_axis.tvalid and s_axis.tready and channel_index(channel_index'high);

  -- В режиме десериализации полоса целиком буферизуется перед записью
  -- в выходные FIFO. Поэтому входной TLAST доступен при записи последнего
  -- слова каждого выходного пакета. Длина входного пакета должна быть
  -- кратна числу каналов.
  s_axis.tready <= fifo_can_accept and fifo_all_ready;

  process (clk_in) is
  begin
    if rising_edge(clk_in) then
      reset_reg       <= rst;                                                                                                                -- антислак
      reset_reg_deser <= (others => rst);                                                                                                    -- fix CDC-11
    end if;
  end process;

  process (clk_in) is
  begin
    if rising_edge(clk_in) then
      if (reset_reg = '1') then
        channel_index <= std_logic_vector(to_unsigned(1, channel_index'length));
      else
        if s_axis.tvalid = '1' and s_axis.tready = '1' then
          -- На последнем слове stripe_data_next уже содержит всю полосу,
          -- поэтому её можно записать в FIFO без отдельного такта ожидания.
          stripe_data <= stripe_data_next;
          if channel_index(channel_index'high) = '0' then
            assert s_axis.tlast = '0'
              report "deserializer: input packet length must be a multiple of G_CH_NUM"
              severity failure;
          end if;
          channel_index <= channel_index(channel_index'high - 1 downto 0) & channel_index(channel_index'high);
        end if;
      end if;
    end if;
  end process;

  gen_fifo_deser: for i in G_CH_NUM - 1 downto 0 generate
  begin
    fifo_s_ready(i) <= fifo_s_axis(i).tready;
    fifo_m_axis(i).tready <= m_axis(i).tready;
    m_axis(i).tlast  <= fifo_m_axis(i).tlast;
    m_axis(i).tdata  <= fifo_m_axis(i).tdata;
    m_axis(i).tvalid <= fifo_m_axis(i).tvalid;

    fifo_s_axis(i).tdata  <= stripe_data_next(i);
    fifo_s_axis(i).tlast  <= s_axis.tlast;
    fifo_s_axis(i).tvalid <= stripe_write_en;

    inst_fifo_deser: entity work.xpm_axis_fifo
      generic map (
        CLOCKING_MODE => G_CLOCKING_MODE,
        FIFO_DEPTH    => G_FIFO_DEPTH,
        TDATA_WIDTH   => G_DATA_WIDTH
      )
      port map (
        s_aclk      => clk_in,
        m_aclk      => clk_user,
        s_aresetn   => not reset_reg_deser(i),
        almost_full => fifo_almost_full(i),
        m_axis      => fifo_m_axis(i),
        s_axis      => fifo_s_axis(i)
      );

  end generate gen_fifo_deser;

end architecture behavioral;
