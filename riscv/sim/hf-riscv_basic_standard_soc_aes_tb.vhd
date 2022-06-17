library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.std_logic_unsigned.all;
use std.textio.all;
use ieee.numeric_std.all;

entity tb is 
	generic(
		address_width: integer := 15;
		memory_file : string := "code.txt";
		log_file: string := "out.txt";
		uart_support : string := "no"
	);
end tb;

architecture tb of tb is
	type STATE is (s_idle, s_load, s_cipher, s_done);
	signal clock_in, reset, data, stall, stall_sig: std_logic := '0';
	signal uart_read, uart_write: std_logic;
	signal boot_enable_n, ram_enable_n, ram_dly: std_logic;
	signal address, data_read, data_write, data_read_boot, data_read_ram: std_logic_vector(31 downto 0);
	signal ext_irq: std_logic_vector(7 downto 0);
	signal data_we, data_w_n_ram: std_logic_vector(3 downto 0);

	signal periph, periph_dly, periph_wr, periph_irq: std_logic;
	signal data_read_periph, data_read_periph_s, data_write_periph: std_logic_vector(31 downto 0);
	signal gpioa_in, gpioa_out, gpioa_ddr: std_logic_vector(15 downto 0);
	signal gpiob_in, gpiob_out, gpiob_ddr: std_logic_vector(15 downto 0);
	signal gpio_sig, gpio_sig2, gpio_sig3: std_logic := '0';
	
	-- mini_aes
	signal current_state: STATE;
	signal counter: integer;
	signal ext_periph, ext_periph_dly: std_logic;
	signal clear, done_o, enc, load_i, start: std_logic;
	signal key_i, data_i, data_o: std_logic_vector (7 downto 0);
	signal data_read_aes, data_read_aes_s: std_logic_vector(31 downto 0);
	signal key_in, data_in, data_out: std_logic_vector(127 downto 0); 
	
begin

	process						--25Mhz system clock
	begin
		clock_in <= not clock_in;
		wait for 20 ns;
		clock_in <= not clock_in;
		wait for 20 ns;
	end process;

	process
	begin
		wait for 4 ms;
		gpio_sig <= not gpio_sig;
		gpio_sig2 <= not gpio_sig2;
		wait for 100 us;
		gpio_sig <= not gpio_sig;
		gpio_sig2 <= not gpio_sig2;
	end process;

	process
	begin
		wait for 5 ms;
		gpio_sig3 <= not gpio_sig3;
		wait for 5 ms;
		gpio_sig3 <= not gpio_sig3;
	end process;

	gpioa_in <= x"00" & "0000" & gpio_sig & "000";
	gpiob_in <= "10000" & gpio_sig3 & "00" & "00000" & gpio_sig2 & "00";

	process
	begin
		stall <= not stall;
		wait for 123 ns;
		stall <= not stall;
		wait for 123 ns;
	end process;

	reset <= '0', '1' after 5 ns, '0' after 500 ns;
	stall_sig <= '0'; --stall;
	ext_irq <= "0000000" & periph_irq;

	boot_enable_n <= '0' when (address(31 downto 28) = "0000" and stall_sig = '0') or reset = '1' else '1';
	ram_enable_n <= '0' when (address(31 downto 28) = "0100" and stall_sig = '0') or reset = '1' else '1';
	data_read <= 	data_read_aes when ext_periph = '1' or ext_periph_dly = '1' else
								data_read_periph when periph = '1' or periph_dly = '1' else 
								data_read_boot when address(31 downto 28) = "0000" and ram_dly = '0' else 
								data_read_ram;
	data_w_n_ram <= not data_we;

	process(clock_in, reset)
	begin
		if reset = '1' then
			ram_dly <= '0';
			periph_dly <= '0';
			ext_periph_dly <= '0';
		elsif clock_in'event and clock_in = '1' then
			ram_dly <= not ram_enable_n;
			periph_dly <= periph;
			ext_periph_dly <= ext_periph;
		end if;
	end process;

	-- HF-RISCV core
	processor: entity work.processor
	port map(	clk_i => clock_in,
			rst_i => reset,
			stall_i => stall_sig,
			addr_o => address,
			data_i => data_read,
			data_o => data_write,
			data_w_o => data_we,
			data_mode_o => open,
			extio_in => ext_irq,
			extio_out => open
	);

	data_read_periph <= data_read_periph_s(7 downto 0) & data_read_periph_s(15 downto 8) & data_read_periph_s(23 downto 16) & data_read_periph_s(31 downto 24);
	data_write_periph <= data_write(7 downto 0) & data_write(15 downto 8) & data_write(23 downto 16) & data_write(31 downto 24);
	periph_wr <= '1' when data_we /= "0000" else '0';
	periph <= '1' when address(31 downto 24) = x"e1" else '0';

	peripherals: entity work.peripherals
	port map(
		clk_i => clock_in,
		rst_i => reset,
		addr_i => address,
		data_i => data_write_periph,
		data_o => data_read_periph_s,
		sel_i => periph,
		wr_i => periph_wr,
		irq_o => periph_irq,
		gpioa_in => gpioa_in,
		gpioa_out => gpioa_out,
		gpioa_ddr => gpioa_ddr,
		gpiob_in => gpiob_in,
		gpiob_out => gpiob_out,
		gpiob_ddr => gpiob_ddr
	);
	
	data_read_aes <= 	data_read_aes_s(7 downto 0) &
										data_read_aes_s(15 downto 8) &
										data_read_aes_s(23 downto 16) &
										data_read_aes_s(31 downto 24);
	ext_periph <= '1' when address(31 downto 24) = x"e7" else '0';

	-- read data from register mapped in memory 
	read_data: process (clock_in, reset, address, key_in, data_in, data_out)
	begin
		if reset = '1' then
			data_read_aes_s <= (others => '0');
		elsif clock_in'event and clock_in = '1' then
			if (ext_periph = '1') then	-- MINI_AES is at 0xe7000000
				case address(7 downto 4) is
					when "0000" =>		-- control	0xe7000000	(bit3 - start (RW), bit2 - done_o (R), bit1 - enc (RW), bit0 - load_i (R))
						data_read_aes_s <= x"0000000" & start & done_o & enc & load_i;
					when "0001" =>		-- key_in[0]	0xe7000010
						data_read_aes_s <= key_in(127 downto 96);
					when "0010" =>		-- key_in[1]	0xe7000020
						data_read_aes_s <= key_in(95 downto 64);
					when "0011" =>		-- key_in[2]	0xe7000030
						data_read_aes_s <= key_in(63 downto 32);
					when "0100" =>		-- key_in[3]	0xfa000040
						data_read_aes_s <= key_in(31 downto 0);
					when "0101" =>		-- data_in[0]	0xe7000050
						data_read_aes_s <= data_in(127 downto 96);
					when "0110" =>		-- data_in[1]	0xe7000060
						data_read_aes_s <= data_in(95 downto 64);
					when "0111" =>		-- data_in[2]	0xe7000070
						data_read_aes_s <= data_in(63 downto 32);
					when "1000" =>		-- data_in[3]	0xe7000080
						data_read_aes_s <= data_in(31 downto 0);
					when "1001" =>		-- data_out[0]	0xe7000090
						data_read_aes_s <= data_out(127 downto 96);
					when "1010" =>		-- data_out[1]	0xe70000a0
						data_read_aes_s <= data_out(95 downto 64);
					when "1011" =>		-- data_out[2]	0xe70000b0
						data_read_aes_s <= data_out(63 downto 32);
					when "1100" =>		-- data_out[3]	0xe70000c0
						data_read_aes_s <= data_out(31 downto 0);
					when others =>
						data_read_aes_s <= (others => '0');
				end case;
			end if;
		end if;
	end process;

	-- write data on register mapped in memory 
	write_data: process (clock_in, reset, address, key_in, data_in, data_out)
	begin
		if reset = '1' then
			key_in <= (others => '0');
			data_in <= (others => '0');
		elsif clock_in'event and clock_in = '1' then
			if (ext_periph = '1' and data_we /= "0000") then	-- MINI_AES is at 0xe7000000
				case address(7 downto 4) is
					when "0000" =>		-- control	0xe7000000	(bit3 - start (RW), bit2 - done_o (R), bit1 - enc (RW), bit0 - load_i (R))
						start <= data_write_periph(3);
						enc <= data_write_periph(1);
					when "0001" =>		-- key_i[0]	0xe7000010
						key_in(127 downto 96) <= data_write_periph;
					when "0010" =>		-- key_i[1]	0xe7000020
						key_in(95 downto 64) <= data_write_periph;
					when "0011" =>		-- key_i[2]	0xe7000030
						key_in(63 downto 32) <= data_write_periph;
					when "0100" =>		-- key_i[3]	0xe7000040
						key_in(31 downto 0) <= data_write_periph;
					when "0101" =>		-- data_i[0]	0xe7000050
						data_in(127 downto 96) <= data_write_periph;
					when "0110" =>		-- data_i[1]	0xe7000060
						data_in(95 downto 64) <= data_write_periph;
					when "0111" =>	  -- data_i[2]	0xe7000070
						data_in(63 downto 32) <= data_write_periph;
					when "1000" =>		-- data_i[3]	0xe7000080
						data_in(31 downto 0) <= data_write_periph;
					when others =>
				end case;
			end if;
		end if;
	end process;

	fsm_aes: process (clock_in, reset)
	begin
		if reset = '1' then
			enc <= '0';
			clear <= '1';
			load_i <= '0';
			counter <= 0;
			current_state <= s_idle;
		elsif clock_in'event and clock_in = '1' then
			case current_state is
				when s_idle =>
					if start = '1' then 		-- start = '1'
						current_state <= s_load;
						counter <= 0;
						clear <= '0';
					end if;
				when s_load =>
						if counter < 16 then
							counter <= counter + 1;
							load_i <= '1'; 			-- load_i = '1'
						else
							current_state <= s_cipher;
							load_i <= '0'; 			-- load_i = '0'
							counter <= 0;
						end if;
				when s_cipher =>
						if done_o = '1' then	-- done_o = '1'
							current_state <= s_done;
							counter <= counter + 1;
						end if;
				when s_done =>
					if done_o = '1' then
						counter <= counter + 1;
					else 										-- done_o = '0'
						current_state <= s_idle;
						counter <= 0;
						clear <= '1';
					end if;
			end case;
		end if;
	end process;

	process (clock_in, reset)
	begin
		if reset = '1' then
			key_i <= x"00";
			data_i <= x"00";
		elsif clock_in'event and clock_in = '1' then
			if current_state = s_load then
				case counter is
					when 0 =>
						key_i <= key_in (127 downto 120);
						data_i <= data_in (127 downto 120);
					when 1 =>
						key_i <= key_in (119 downto 112);
						data_i <= data_in (119 downto 112);
					when 2 =>
						key_i <= key_in (111 downto 104);
						data_i <= data_in (111 downto 104);
					when 3 =>
						key_i <= key_in (103 downto 96);
						data_i <= data_in (103 downto 96);
					when 4 =>
						key_i <= key_in (95 downto 88);
						data_i <= data_in (95 downto 88);
					when 5 =>
						key_i <= key_in (87 downto 80);
						data_i <= data_in (87 downto 80);
					when 6 =>
						key_i <= key_in (79 downto 72);
						data_i <= data_in (79 downto 72);
					when 7 =>
						key_i <= key_in (71 downto 64);
						data_i <= data_in (71 downto 64);
					when 8 =>
						key_i <= key_in (63 downto 56);
						data_i <= data_in (63 downto 56);
					when 9 =>
						key_i <= key_in (55 downto 48);
						data_i <= data_in (55 downto 48);
					when 10 =>
						key_i <= key_in (47 downto 40);
						data_i <= data_in (47 downto 40);
					when 11 =>
						key_i <= key_in (39 downto 32);
						data_i <= data_in (39 downto 32);
					when 12 =>
						key_i <= key_in (31 downto 24);
						data_i <= data_in (31 downto 24);
					when 13 =>
						key_i <= key_in (23 downto 16);
						data_i <= data_in (23 downto 16);
					when 14 =>
						key_i <= key_in (15 downto 8);
						data_i <= data_in (15 downto 8);
					when 15 =>					
						key_i <= key_in (7 downto 0);
						data_i <= data_in (7 downto 0);
					when others =>
				end case;
			end if;
		end if;
	end process;

	process (clock_in, reset)
	begin
		if reset = '1' then
			data_out <= (others => '0');
		elsif clock_in'event and clock_in = '1' then
			if done_o = '1' then
				case counter is
					when 0 =>
						data_out (127 downto 120) <= data_o;
					when 1 =>
						data_out (119 downto 112) <= data_o;
					when 2 =>
						data_out (111 downto 104) <= data_o;
					when 3 =>
						data_out (103 downto 96) <= data_o;
					when 4 =>
						data_out (95 downto 88) <= data_o;
					when 5 =>
						data_out (87 downto 80) <= data_o;
					when 6 =>
						data_out (79 downto 72) <= data_o;
					when 7 =>
						data_out (71 downto 64) <= data_o;
					when 8 =>
						data_out (63 downto 56) <= data_o;
					when 9 =>
						data_out (55 downto 48) <= data_o;
					when 10 =>
						data_out (47 downto 40) <= data_o;
					when 11 =>
						data_out (39 downto 32) <= data_o;
					when 12 =>
						data_out (31 downto 24) <= data_o;
					when 13 =>
						data_out (23 downto 16) <= data_o;
					when 14 =>
						data_out (15 downto 8) <= data_o;
					when 15 =>					
						data_out (7 downto 0) <= data_o;
					when others =>
				end case;
			end if;
		end if;
	end process;

	-- AES core
	crypto_core: entity work.mini_aes
	port map(
		clock => clock_in,
		clear => clear,
		load_i => load_i, -- 1: loading key and data
		enc => enc, -- 0: encrypt | 1: decrypt
		key_i => key_i,
		data_i => data_i,
		data_o => data_o,
		done_o => done_o -- 1: done cipher process
	);

	-- boot ROM
	boot0lb: entity work.boot_ram
	generic map (	memory_file => "boot.txt",
					data_width => 8,
					address_width => 12,
					bank => 0)
	port map(
		clk 	=> clock_in,
		addr 	=> address(11 downto 2),
		cs_n 	=> boot_enable_n,
		we_n	=> '1',
		data_i	=> (others => '0'),
		data_o	=> data_read_boot(7 downto 0)
	);

	boot0ub: entity work.boot_ram
	generic map (	memory_file => "boot.txt",
					data_width => 8,
					address_width => 12,
					bank => 1)
	port map(
		clk 	=> clock_in,
		addr 	=> address(11 downto 2),
		cs_n 	=> boot_enable_n,
		we_n	=> '1',
		data_i	=> (others => '0'),
		data_o	=> data_read_boot(15 downto 8)
	);

	boot1lb: entity work.boot_ram
	generic map (	memory_file => "boot.txt",
					data_width => 8,
					address_width => 12,
					bank => 2)
	port map(
		clk 	=> clock_in,
		addr 	=> address(11 downto 2),
		cs_n 	=> boot_enable_n,
		we_n	=> '1',
		data_i	=> (others => '0'),
		data_o	=> data_read_boot(23 downto 16)
	);

	boot1ub: entity work.boot_ram
	generic map (	memory_file => "boot.txt",
					data_width => 8,
					address_width => 12,
					bank => 3)
	port map(
		clk 	=> clock_in,
		addr 	=> address(11 downto 2),
		cs_n 	=> boot_enable_n,
		we_n	=> '1',
		data_i	=> (others => '0'),
		data_o	=> data_read_boot(31 downto 24)
	);

	-- RAM
	memory0lb: entity work.bram
	generic map (	memory_file => memory_file,
					data_width => 8,
					address_width => address_width,
					bank => 0)
	port map(
		clk 	=> clock_in,
		addr 	=> address(address_width -1 downto 2),
		cs_n 	=> ram_enable_n,
		we_n	=> data_w_n_ram(0),
		data_i	=> data_write(7 downto 0),
		data_o	=> data_read_ram(7 downto 0)
	);

	memory0ub: entity work.bram
	generic map (	memory_file => memory_file,
					data_width => 8,
					address_width => address_width,
					bank => 1)
	port map(
		clk 	=> clock_in,
		addr 	=> address(address_width -1 downto 2),
		cs_n 	=> ram_enable_n,
		we_n	=> data_w_n_ram(1),
		data_i	=> data_write(15 downto 8),
		data_o	=> data_read_ram(15 downto 8)
	);

	memory1lb: entity work.bram
	generic map (	memory_file => memory_file,
					data_width => 8,
					address_width => address_width,
					bank => 2)
	port map(
		clk 	=> clock_in,
		addr 	=> address(address_width -1 downto 2),
		cs_n 	=> ram_enable_n,
		we_n	=> data_w_n_ram(2),
		data_i	=> data_write(23 downto 16),
		data_o	=> data_read_ram(23 downto 16)
	);

	memory1ub: entity work.bram
	generic map (	memory_file => memory_file,
					data_width => 8,
					address_width => address_width,
					bank => 3)
	port map(
		clk 	=> clock_in,
		addr 	=> address(address_width -1 downto 2),
		cs_n 	=> ram_enable_n,
		we_n	=> data_w_n_ram(3),
		data_i	=> data_write(31 downto 24),
		data_o	=> data_read_ram(31 downto 24)
	);

	-- debug process
	debug:
	if uart_support = "no" generate
		process(clock_in, address)
			file store_file : text open write_mode is "debug.txt";
			variable hex_file_line : line;
			variable c : character;
			variable index : natural;
			variable line_length : natural := 0;
		begin
			if clock_in'event and clock_in = '1' then
				if address = x"f00000d0" and data = '0' then
					data <= '1';
					index := conv_integer(data_write(30 downto 24));
					if index /= 10 then
						c := character'val(index);
						write(hex_file_line, c);
						line_length := line_length + 1;
					end if;
					if index = 10 or line_length >= 72 then
						writeline(store_file, hex_file_line);
						line_length := 0;
					end if;
				else
					data <= '0';
				end if;
			end if;
		end process;
	end generate;

	process(clock_in, reset, address)
	begin
		if reset = '1' then
		elsif clock_in'event and clock_in = '0' then
			assert address /= x"e0000000" report "end of simulation" severity failure;
			assert (address < x"50000000") or (address >= x"e0000000") report "out of memory region" severity failure;
			assert address /= x"40000104" report "handling IRQ" severity warning;
		end if;
	end process;

end tb;

