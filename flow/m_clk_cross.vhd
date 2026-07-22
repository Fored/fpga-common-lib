library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--vivado
--set_false_path -to [get_pins -hier -filter name=~*Inst_m_clk_cross*/*data_reg*/D]
--quartus
--set_false_path -to [get_registers {*Inst_m_clk_cross*|data_reg*}]
entity m_clk_cross is
	Generic
	(
		G_WIDTH					: positive := 32;
		G_PULSE_SYNC			: boolean := false;
		G_PULSE_MIN_PERIOD	: std_logic_vector(1 downto 0) := "01"; --old VHDL
		G_DIN_REG_EN			: boolean := true;
		G_DOUT_REG_EN			: boolean := true	
	);
	Port 
	(
		ClkIn		: in  std_logic := '0';
		ClkOut	: in  std_logic;
		DIn		: in  std_logic_vector(G_WIDTH - 1 downto 0);
		DOut		: out std_logic_vector(G_WIDTH - 1 downto 0)
	);
end m_clk_cross;

architecture Behavioral of m_clk_cross is
	type std_matrix2 is array (natural range <>) of std_logic_vector(1 downto 0);

	signal data_in, data_reg			: std_logic_vector(G_WIDTH - 1 downto 0) := (others => '0');
	signal data_reg_2, data_reg_3		: std_logic_vector(G_WIDTH - 1 downto 0) := (others => '0');
	signal pulse_period_cnt				: std_matrix2(G_WIDTH - 1 downto 0) := (others => (others => '0'));
	
	attribute dont_touch : string;
	attribute dont_touch of data_reg : signal is "true";
	attribute keep : string;
	attribute keep of data_reg : signal is "true";
begin

	Gen_pulse_true: if G_PULSE_SYNC generate 			--синхронизация импульса
		process(ClkIn)
		begin
			if rising_edge(ClkIn) then
				for i in G_WIDTH - 1 downto 0 loop
					if DIn(i) = '1' and unsigned(pulse_period_cnt(i)) = 0 then
						data_in(i) <= not data_in(i);
					else
						data_in(i) <= data_in(i);
					end if;
				end loop;
			end if;
		end process;
		process(ClkIn)
		begin
			if rising_edge(ClkIn) then
				for i in G_WIDTH - 1 downto 0 loop
					if DIn(i) = '1' and unsigned(pulse_period_cnt(i)) = 0 then
						pulse_period_cnt(i) <= G_PULSE_MIN_PERIOD;
					else
						if unsigned(pulse_period_cnt(i)) > 0 then
							pulse_period_cnt(i) <= std_logic_vector(unsigned(pulse_period_cnt(i)) - 1);
						else
							pulse_period_cnt(i) <= pulse_period_cnt(i);
						end if;
					end if;
				end loop;
			end if;
		end process;
		process(ClkOut)
		begin
			if rising_edge(ClkOut) then
				data_reg <= data_in; --set_false_path
				data_reg_2 <= data_reg;
				data_reg_3 <= data_reg_2;
			end if;
		end process;
		DOut <= data_reg_2 xor data_reg_3;
	end generate;
	
	Gen_pulse_false: if not G_PULSE_SYNC generate 											--синхронизация регистра
		Gen_din_reg: if G_DIN_REG_EN generate
			process(ClkIn)
			begin
				if rising_edge(ClkIn) then
					data_in <= DIn;
				end if;
			end process;
		end generate;
		Gen_din_wire: if not G_DIN_REG_EN generate
			data_in <= DIn;
		end generate;
		
		process(ClkOut)
		begin
			if rising_edge(ClkOut) then
				data_reg <= data_in; --set_false_path
			end if;
		end process;
		
		Gen_dout_reg: if G_DOUT_REG_EN generate
			process(ClkOut)
			begin
				if rising_edge(ClkOut) then
					DOut <= data_reg;
				end if;
			end process;
		end generate;
		Gen_dout_wire: if not G_DOUT_REG_EN generate
			DOut <= data_reg;
		end generate;
	end generate;

end Behavioral;
