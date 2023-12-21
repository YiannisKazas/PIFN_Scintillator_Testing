--==================================================================================================
-- Company      : NCSR Demokritos
-- Engineer     : Yiannis Kazas
-- Create Date  : 11/22/2023 12:11:23 PM
-- Module Name  : status_regs - Behavioral
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Description  : 
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Last Changes : 22-Nov-2023
--==================================================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.user_package.all;
library UNISIM;
use UNISIM.VComponents.all;

--==================================================================================================

entity status_regs is
    Port ( 
        Reset_i         : in std_logic;
        Clk_i           : in std_logic;
        Stat_global_i   : in stat_global_type;
        stat_readout_i  : in stat_readout_type;
        Stat_regs_o     : out stdvec8_tx_array
    );
end status_regs;

--==================================================================================================

architecture Behavioral of status_regs is

--==================================================================================================
    -- Start of Signal Declaration --
--==================================================================================================


begin


--==================================================================================================
-- START OF MAIN BODY --
--==================================================================================================


    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- Status Register Assignment --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    process(Clk_i, Reset_i)
    begin
        if (Reset_i = '1') then
            Stat_regs_o <= (others=>(others=>'0'));
        elsif rising_edge(Clk_i) then
            Stat_regs_o(0) <= Stat_readout_i.fsm_status;
            -- Hardware used
            Stat_regs_o(1) <= x"03"; -- x"1" = KC705 Board, x"2" = PYNQ-Z2 Board, x"3" = Arty Board
            -- Firmware Version 0.0.2
            Stat_regs_o(2) <= x"02"; 
            -- Project ID
            Stat_regs_o(3) <= x"03"; -- x"1" = TDC, x"2" = RaSoLo360, x"3" = PIFN Testing
            -- Test and Debug
            Stat_regs_o(4) <= Stat_global_i.debug; 
            
            Stat_regs_o(5)  <= stat_readout_i.ADC_data(0)(7 downto 0);
            Stat_regs_o(6)  <= stat_readout_i.ADC_data(0)(15 downto 8);
            Stat_regs_o(7)  <= stat_readout_i.ADC_data(1)(7 downto 0);
            Stat_regs_o(8)  <= stat_readout_i.ADC_data(1)(15 downto 8);
            Stat_regs_o(9)  <= stat_readout_i.ADC_data(2)(7 downto 0);
            Stat_regs_o(10) <= stat_readout_i.ADC_data(2)(15 downto 8);
            Stat_regs_o(11) <= stat_readout_i.ADC_data(3)(7 downto 0);
            Stat_regs_o(12) <= stat_readout_i.ADC_data(3)(15 downto 8);
            
            Stat_regs_o(13) <= stat_readout_i.events_recorded(7 downto 0);
            Stat_regs_o(14) <= stat_readout_i.events_recorded(15 downto 8);
            Stat_regs_o(15) <= stat_readout_i.events_recorded(23 downto 16);

            Stat_regs_o(16)(NUM_CHANNELS-1 downto 0) <= Stat_global_i.tx_error;
            
            Stat_regs_o(17) <= stat_readout_i.bram_rd_dout(7 downto 0);
            Stat_regs_o(18) <= stat_readout_i.bram_rd_dout(15 downto 8);
        end if;
    end process;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
end Behavioral;
--==================================================================================================
--==================================================================================================
