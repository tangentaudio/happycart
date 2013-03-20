---------------------------------------------------------------------------------------------------------------------
-- HappyCart BSW2000
-- Parallel Port Interface CPLD (aka "8255 emulator")
--
-- HappyCart BSW2000 is Copyright (C) 1998, 1999 Stephen Richardson 
-- and HackerWare Hardware Labs
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- The original HappyCart is Copyright (C) 1998 Stephen S Richardson,
-- Michael J Andrews and HackerWare
---------------------------------------------------------------------------------------------------------------------
--
-- HISTORY
-- 04DEC99 SR   epoch
-- 17DEC99 SR   first working version
---------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity parallel is
PORT(
	pc_n_strobe	:	IN std_logic;				-- PC parallel port /strobe line
	pc_n_sel	:	IN std_logic;				-- PC parallel port /select line
	pc_n_init	:	IN std_logic;				-- PC parallel port /initialize line
	pc_n_af		:	IN std_logic;				-- PC parallel port /autofeed line
	pc_data		:	IN std_logic_vector (7 downto 0);	-- PC parallel port data bus
	data		:	OUT std_logic_vector (7 downto 0);	-- SRAM/Atari shared data bus
	sram_addr	:	OUT std_logic_vector (13 downto 0)	-- SRAM address bus
);
end;

architecture behavior of parallel is
begin

PROCESS (pc_n_strobe, pc_n_sel, pc_n_init, pc_n_af, pc_data)
BEGIN
	IF (pc_n_sel = '1' AND pc_n_init = '0' AND pc_n_af = '0') THEN
		-- latching parallel port data on data bus

		data <= pc_data;

	ELSIF (pc_n_sel = '1' AND pc_n_init = '0' AND pc_n_af = '1') THEN
		-- latching parallel port data on lower address

		sram_addr(0) <= pc_data(0);
		sram_addr(1) <= pc_data(1);
		sram_addr(2) <= pc_data(2);
		sram_addr(3) <= pc_data(3);
		sram_addr(4) <= pc_data(4);
		sram_addr(5) <= pc_data(5);
		sram_addr(6) <= pc_data(6);
		sram_addr(7) <= pc_data(7);

	ELSIF (pc_n_sel = '1' AND pc_n_init = '1' AND pc_n_af = '0') THEN
		-- latching parallel port data on upper address

		sram_addr(8) <= pc_data(0);
		sram_addr(9) <= pc_data(1);
		sram_addr(10) <= pc_data(2);
		sram_addr(11) <= pc_data(3);
		sram_addr(12) <= pc_data(4);
		sram_addr(13) <= pc_data(5);
	ELSE
		-- PC is not writing to the SRAM, go to hi-Z state
		data <= "ZZZZZZZZ";
		sram_addr <= "ZZZZZZZZZZZZZZ";

	END IF;

END PROCESS;	
end behavior;

