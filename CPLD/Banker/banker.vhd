---------------------------------------------------------------------------------------------------------------------
-- HappyCart BSW2000
-- Bank Switching CPLD
--
-- HappyCart BSW2000 is Copyright (C) 1998, 1999 Stephen S Richardson 
-- and HackerWare Hardware Labs
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- The original HappyCart is Copyright (C) 1998 S. Richardson 
-- and Michael J. Andrews and HackerWare
---------------------------------------------------------------------------------------------------------------------
-- bank switching modes:
--   000 no bank switching, used to play standard 2K/4K cartridges
--   001 F8 type bank switching (8K)
--   010 F6 type bank switching (16K)
--   011 FA type bank switching (12K) with 256 bytes RAM (CBS RAM+)
--   100 presently unused
--   101 presently unused
--   110 presently unused
--   111 download HappyCart RAM from PC (puts SRAM address bus in hi-z)
--
-- to set the bank switching mode:
--   1. load bank switching mode on to PC parallel port lower 3 bits
--   2. pulse pc_n_sel (it's active low, so bring it low)
--   3. this will latch the lower 3 parallel port bits into the internal 'bsw_mode' variable
--
-- to write to the HappyCart RAM from the PC:
--   1. place the HappyCart into bank switch mode 111, this FPGA puts the SRAM address lines into hi-Z
--   2. use the other FPGA to latch an address on to the SRAM address bus (see hc2kpc.vhd)
--   3. set other FPGA in to 'no op' latch mode
--   4. place a data byte on the parallel port bus
--   5. pulse pc_n_strobe (it's active low, so bring it low)
--   6. repeat to step 2 until RAM is filled
--   7. place HappyCart in to appropriate bank switching mode for the game
--
--------------------------------------------------------------------------------------------------------------------
--
-- HISTORY
-- 04DEC99 SR   epoch
-- 17DEC99 SR   first working version (2K/4K only)
-- 18DEC99 SR   first semi-working F8 and F6
-- 18DEC99 SR   tweaked F8/F6, added SuperChip support
--              implemented CBS RAM+ and FA bankswitch for 3 games
-- 20DEC99 SR   2K/4K/F6/F8/FA work for many but not all games - need to investigate
--			  	Asteroids works, so that's all that really matters
--
--------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity banker is
PORT(
	atari_addr	:IN std_logic_vector (11 downto 0);	-- Atari address bus
	atari_cs	:IN std_logic;				-- Atari chip select (A12) - n.b. positive logic!
	sram_addr	:OUT std_logic_vector (11 downto 0);	-- SRAM address bus
	sram_a12	:OUT std_logic;				-- SRAM A12
	sram_a13	:OUT std_logic;				-- SRAM A13
	sram_n_we	:OUT std_logic;				-- SRAM /WE
	sram_n_oe	:OUT std_logic;				-- SRAM /OE
	pc_n_strobe	:IN std_logic;				-- PC parallel port /strobe signal
	pc_n_sel	:IN std_logic;				-- PC parallel port /select signal
	pc_data		:IN std_logic_vector (2 downto 0)	-- PC parallel port bits 2-0
);

end;

architecture behavior of banker is
	SIGNAL bsw_mode : std_logic_vector(2 DOWNTO 0);		-- internal bank switch mode, latched from PC
	SIGNAL bsw_a13	: std_logic;				-- used for F6
	SIGNAL bsw_a12	: std_logic;				-- used for F8/F6
	SIGNAL superchip: std_logic;				-- 1 if superchip needed
begin

-- latch the 3 bit bankswitch mode in from the PC on the falling edge of pc_n_sel
-- if pc_n_strobe is low, then we actually latch in extra bankswitching data
-- (right now, just one bit to enable the superchip mode)
PROCESS (pc_n_sel, pc_n_strobe, pc_data)
BEGIN
	IF (pc_n_sel'EVENT AND pc_n_sel = '0') THEN
		IF (pc_n_strobe = '1') THEN
			bsw_mode <= pc_data;
		END IF;

		IF (pc_n_strobe = '0') THEN
			superchip <= pc_data(0);
		END IF;
	END IF;
END PROCESS;


-- this is where the actual bank switching stuff resides
PROCESS (bsw_mode,atari_cs,atari_addr,pc_n_strobe, bsw_a12, bsw_a13, superchip)
BEGIN
	-----------------------------------------------------------------------
	-- No bank switching.  Standard 2K/4K cartridges.
	--
	IF (bsw_mode = "000") THEN
		sram_addr <= atari_addr;
		sram_a12 <= '0';
		sram_a13 <= '0';

		sram_n_we <= '1';
		sram_n_oe <= NOT atari_cs;
	END IF;
	--
	-----------------------------------------------------------------------


	-----------------------------------------------------------------------
	-- F8: two 4K banks at FF8 and FF9
	--
	IF (bsw_mode = "001") THEN

		IF (pc_n_strobe = '0') THEN
			bsw_a12 <= '0';
		ELSE

			IF ((atari_addr >= X"000" AND atari_addr <= X"07F") AND superchip = '1') THEN
				-- writing to SRAM (128 bytes)

				sram_addr <= atari_addr;
				sram_a13 <= '0';
				sram_a12 <= '0';
				
				sram_n_oe <= '1';
				sram_n_we <= NOT atari_cs;
			ELSIF ((atari_addr >= X"080" AND atari_addr <= X"0FF") AND superchip = '1') THEN
				-- reading SRAM (128 bytes)

				sram_addr <= atari_addr AND X"07F";
				sram_a13 <= '0';
				sram_a12 <= '0';

				sram_n_we <= '1';
				sram_n_oe <= NOT atari_cs;
			ELSE
				sram_addr <= atari_addr;
				sram_a13 <= '0';
				sram_a12 <= bsw_a12;

				sram_n_we <= '1';
				sram_n_oe <= NOT atari_cs;

				IF atari_cs = '1' THEN
					CASE atari_addr IS
					WHEN X"FF8" =>
						bsw_a12 <= '0';
					WHEN X"FF9" =>
						bsw_a12 <= '1';
--					WHEN X"FFC" =>
--						bsw_a12 <= '0';
					WHEN OTHERS =>
					END CASE;
				END IF;
			END IF;
		END IF;
	END IF;
	--
	-----------------------------------------------------------------------


	-----------------------------------------------------------------------
	-- F6: four 4K banks at FF6, FF7, FF8 and FF9
	--
	IF (bsw_mode = "010") THEN
		IF (pc_n_strobe = '0') THEN
			bsw_a12 <= '0';
			bsw_a13 <= '0';
		ELSE
			IF ((atari_addr >= X"000" AND atari_addr <= X"07F") AND superchip = '1') THEN
				-- writing to SRAM (128 bytes)

				sram_addr <= atari_addr;
				sram_a13 <= '0';
				sram_a12 <= '0';
				
				sram_n_oe <= '1';
				sram_n_we <= NOT atari_cs;
			ELSIF ((atari_addr >= X"080" AND atari_addr <= X"0FF") AND superchip = '1') THEN
				-- reading SRAM (128 bytes)

				sram_addr <= atari_addr AND X"07F";
				sram_a13 <= '0';
				sram_a12 <= '0';

				sram_n_we <= '1';
				sram_n_oe <= NOT atari_cs;
			ELSE
				sram_addr <= atari_addr;
				sram_a13 <= bsw_a13;
				sram_a12 <= bsw_a12;

				sram_n_we <= '1';
				sram_n_oe <= NOT atari_cs;

				-- bank switcher logic
				IF (atari_cs = '1') THEN
					CASE atari_addr IS
					WHEN X"FF6" =>
						bsw_a12 <= '0';
						bsw_a13 <= '0';
					WHEN X"FF7" =>
						bsw_a12 <= '1';
						bsw_a13 <= '0';
					WHEN X"FF8" =>
						bsw_a12 <= '0';
						bsw_a13 <= '1';
					WHEN X"FF9" =>
						bsw_a12 <= '1';
						bsw_a13 <= '1';
--					WHEN X"FFC" =>
--						bsw_a12 <= '0';
--						bsw_a13 <= '0';
					WHEN OTHERS =>
					END CASE;
				END IF;
			END IF;
		END IF;
	END IF;
	--
	-----------------------------------------------------------------------


	-----------------------------------------------------------------------
	-- FA: three 4K banks at FF8 and FF9
	--
	IF (bsw_mode = "011") THEN

		IF (pc_n_strobe = '0') THEN
			bsw_a12 <= '0';
			bsw_a13 <= '0';
		ELSE

			IF (atari_addr >= X"000" AND atari_addr <= X"0FF") THEN
				-- writing to SRAM (128 bytes)

				sram_addr <= atari_addr;
				sram_a13 <= '0';
				sram_a12 <= '0';
				
				sram_n_oe <= '1';
				sram_n_we <= NOT atari_cs;
			ELSIF (atari_addr >= X"100" AND atari_addr <= X"1FF") THEN
				-- reading SRAM (128 bytes)

				sram_addr <= atari_addr AND X"0FF";
				sram_a13 <= '0';
				sram_a12 <= '0';

				sram_n_we <= '1';
				sram_n_oe <= NOT atari_cs;
			ELSE
				sram_addr <= atari_addr;
				sram_a13 <= bsw_a13;
				sram_a12 <= bsw_a12;

				sram_n_we <= '1';
				sram_n_oe <= NOT atari_cs;

				IF atari_cs = '1' THEN
					CASE atari_addr IS
					WHEN X"FF8" =>
						bsw_a12 <= '0';
						bsw_a13 <= '0';
					WHEN X"FF9" =>
						bsw_a12 <= '1';
						bsw_a13 <= '0';
					WHEN X"FFA" =>
						bsw_a12 <= '0';
						bsw_a13 <= '1';
--					WHEN X"FFC" =>
--						bsw_a12 <= '0';
					WHEN OTHERS =>
					END CASE;
				END IF;
			END IF;
		END IF;
	END IF;
	--
	-----------------------------------------------------------------------


	

	-----------------------------------------------------------------------
	-- Not really a bank switch mode per se.  This is used to avoid
	-- contention when the PC is writing to the SRAM to load a ROM image.
	-- 
	IF (bsw_mode = "111") THEN

		sram_addr <= "ZZZZZZZZZZZZ";
		sram_a12 <= 'Z';
		sram_a13 <= 'Z';

		sram_n_oe <= '1';
		sram_n_we <= pc_n_strobe;
	END IF;
	--
	-----------------------------------------------------------------------

END PROCESS;

end behavior;

