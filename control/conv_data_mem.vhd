library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.types_pack.all;

entity conv_data_mem is
  Port (
    Clk   : in    std_logic;
    Reset : in    std_logic;
    --====data====
    DataLiteIn   : in    uddcp_lite;
    ReadReadyOut : out   std_logic;

    DataLiteOut : out   uddcp_lite;
    ReadReadyIn : in    std_logic;
    --====mem====
    ConvMemWriteOut : out   mem_port := ((others => '0'), (others => '0'), '0', '0');
    ConvMemReadIn   : in    mem_port := (addr => (others => '0'), data => (others => '0'), data_valid => '0', read_req => '1')
  );
end entity conv_data_mem;

architecture arc of conv_data_mem is

  signal read_ready_out                  : std_logic                                    := '0';
  signal addr                            : std_logic_vector(ConvMemWriteOut.addr'range) := (others => '0');
  signal data_write                      : std_logic_vector(DataLiteIn.data'range)      := (others => '0');
  signal data_valid_write                : std_logic;
  signal lite_out                        : uddcp_lite                                   := ('0', (others => '0'), '0');
  signal read_req                        : std_logic                                    := '0';
  signal sel_addr_data                   : std_logic                                    := '0';
  signal mes_read_mode                   : std_logic                                    := '0';
  signal fifo_a_data_in, fifo_a_data_out : std_logic_vector(32 downto 0)                := (others => '0');
  signal fifo_a_empty                    : std_logic;
  signal fifo_a_rdreq                    : std_logic                                    := '0';
  signal fifo_a_almost_full              : std_logic                                    := '0';
  signal fifo_a_wrreq                    : std_logic                                    := '0';
  signal fifo_d_data_in, fifo_d_data_out : std_logic_vector(32 downto 0)                := (others => '0');
  signal fifo_d_empty                    : std_logic;
  signal fifo_d_rdreq                    : std_logic                                    := '0';
  signal fifo_d_almost_full              : std_logic                                    := '0';
  signal fifo_d_wrreq                    : std_logic                                    := '0';
  signal fifo_rdreq                      : std_logic;
  signal sel_fifo_a_d                    : std_logic                                    := '0';

-- attribute mark_debug : string;
-- attribute mark_debug of ReadReadyOut : signal is "true";
-- attribute mark_debug of ReadReadyIn : signal is "true";
-- attribute mark_debug of fifo_a_almost_full : signal is "true";
-- attribute mark_debug of fifo_d_almost_full : signal is "true";
-- attribute mark_debug of ConvMemReadIn : signal is "true";
-- attribute mark_debug of ConvMemWriteOut : signal is "true";

begin

  ReadReadyOut <= read_ready_out;
  fifo_rdreq   <= ReadReadyIn;
  DataLiteOut  <= lite_out;

  ConvMemWriteOut.addr       <= addr;
  ConvMemWriteOut.data       <= data_write;
  ConvMemWriteOut.data_valid <= data_valid_write;
  ConvMemWriteOut.read_req   <= read_req;

  fifo_d_data_in <= '0' & ConvMemReadIn.data;
  fifo_d_wrreq   <= ConvMemReadIn.data_valid;
  fifo_a_rdreq   <= fifo_rdreq and (not sel_fifo_a_d) and (not fifo_a_empty);
  fifo_d_rdreq   <= fifo_rdreq and sel_fifo_a_d and (not fifo_d_empty);

  read_ready_out <= ReadReadyIn and (not fifo_a_almost_full) and (not fifo_d_almost_full) and ConvMemReadIn.read_req;

  --====WRITE_IN_MEM====
  control_proc: process (Clk) is
  begin
    if rising_edge(Clk) then
      if (Reset = '1') then
        sel_addr_data <= '0';
        mes_read_mode <= '1';
      else
        if (DataLiteIn.data_valid = '1' and read_ready_out = '1') then
          if (DataLiteIn.message_start = '1') then
            sel_addr_data <= '1';
            mes_read_mode <= DataLiteIn.data(DataLiteIn.data'high);
          else
            sel_addr_data <= not sel_addr_data;
            mes_read_mode <= mes_read_mode;
          end if;
        else
          sel_addr_data <= sel_addr_data;
          mes_read_mode <= mes_read_mode;
        end if;
      end if;
    end if;
  end process;

  write_addr_data_proc: process (Clk) is
  begin
    if rising_edge(Clk) then
      if (Reset = '1') then
        addr             <= (others => '0');
        data_valid_write <= '0';
      else
        if (DataLiteIn.data_valid = '1' and read_ready_out = '1') then
          if (DataLiteIn.message_start = '1' or sel_addr_data = '0') then
            addr             <= '0' & DataLiteIn.data(DataLiteIn.data'high - 1 downto 0);
            data_write       <= data_write;
            data_valid_write <= '0';
          else
            addr             <= addr;
            data_valid_write <= not mes_read_mode;
            if (mes_read_mode = '0') then
              data_write <= DataLiteIn.data;
            else
              data_write <= data_write;
            end if;
          end if;
        else
          addr             <= addr;
          data_write       <= data_write;
          data_valid_write <= '0';
        end if;
      end if;
    end if;
  end process;

  --====READ_FROM_MEM====
  read_req_proc: process (Clk) is
  begin
    if rising_edge(Clk) then
      if (Reset = '1') then
        read_req <= '0';
      else
        if (DataLiteIn.data_valid = '1' and read_ready_out = '1') then
          if (DataLiteIn.message_start = '1' or sel_addr_data = '0') then
            read_req <= '0';
          else
            read_req <= mes_read_mode;
          end if;
        else
          read_req <= '0';
        end if;
      end if;
    end if;
  end process;

  fifo_a_proc: process (Clk) is
  begin
    if rising_edge(Clk) then
      if (Reset = '1') then
        fifo_a_wrreq <= '0';
      else
        if (DataLiteIn.data_valid = '1' and read_ready_out = '1') then
          -- начало сообщения и режим чтения
          if ((DataLiteIn.message_start = '1' and DataLiteIn.data(DataLiteIn.data'high) = '1')
            -- слово адреса и флаг режима чтения
              or (DataLiteIn.message_start = '0' and sel_addr_data = '0' and mes_read_mode = '1')) then
            fifo_a_data_in <= DataLiteIn.message_start & '0' & DataLiteIn.data(DataLiteIn.data'length - 2 downto 0);
            fifo_a_wrreq   <= '1';
          else
            fifo_a_data_in <= fifo_a_data_in;
            fifo_a_wrreq   <= '0';
          end if;
        else
          fifo_a_data_in <= fifo_a_data_in;
          fifo_a_wrreq   <= '0';
        end if;
      end if;
    end if;
  end process;

  process (Clk) is
  begin
    if rising_edge(Clk) then
      if (Reset = '1') then
        sel_fifo_a_d <= '0';
      else
        if (DataLiteIn.data_valid = '1' and read_ready_out = '1' and DataLiteIn.message_start = '1') then
          sel_fifo_a_d <= '0';
        else
          if (fifo_a_rdreq = '1' or fifo_d_rdreq = '1') then
            if (fifo_a_data_out(fifo_a_data_out'high) = '1' and fifo_a_rdreq = '1') then
              sel_fifo_a_d <= '1';
            else
              sel_fifo_a_d <= not sel_fifo_a_d;
            end if;
          else
            sel_fifo_a_d <= sel_fifo_a_d;
          end if;
        end if;
      end if;
    end if;
  end process;

  lite_out_proc: process (Clk) is
  begin
    if rising_edge(Clk) then
      if (Reset = '1') then
        lite_out.data_valid <= '0';
      else
        if (fifo_rdreq = '1') then
          if (sel_fifo_a_d = '0') then
            lite_out.message_start <= fifo_a_data_out(fifo_a_data_out'high);
            lite_out.data          <= fifo_a_data_out(lite_out.data'range);
            lite_out.data_valid    <= (not fifo_a_empty);
          else
            lite_out.message_start <= '0';
            lite_out.data          <= fifo_d_data_out(lite_out.data'range);
            lite_out.data_valid    <= (not fifo_d_empty);
          end if;
        else
          lite_out.message_start <= lite_out.message_start;
          lite_out.data          <= lite_out.data;
          lite_out.data_valid    <= lite_out.data_valid;
        end if;
      end if;
    end if;
  end process;

  inst_fifo_addres: entity work.fifo_1024
    port map (
      clk       => Clk,
      srst      => Reset,
      din       => fifo_a_data_in,
      wr_en     => fifo_a_wrreq,
      rd_en     => fifo_a_rdreq,
      dout      => fifo_a_data_out,
      full      => open,
      prog_full => fifo_a_almost_full,
      empty     => fifo_a_empty
    );

  inst_fifo_data: entity work.fifo_1024
    port map (
      clk       => Clk,
      srst      => Reset,
      din       => fifo_d_data_in,
      wr_en     => fifo_d_wrreq,
      rd_en     => fifo_d_rdreq,
      dout      => fifo_d_data_out,
      full      => open,
      prog_full => fifo_d_almost_full,
      empty     => fifo_d_empty
    );

end architecture arc;
