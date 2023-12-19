--==================================================================================================
-- Company      : NCSR Demokritos
-- Engineer     : Yiannis Kazas
-- Create Date  : 11/22/2023 01:27:23 PM
-- Module Name  : Cnfg_regs - Behavioral
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Description  : 
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Last Changes : 22-Nov-2023
--==================================================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.user_package.all;

--==================================================================================================

entity Cnfg_regs is
    Port ( 
        Reset_i         : in std_logic;
        Clk_i           : in std_logic;
        Ctrl_regs_i     : in stdvec8_rx_array;
        Cnfg_global_o   : out cnfg_global_type;
        Cnfg_readout_o  : out cnfg_readout_type;
        Cnfg_trig_gen_o : out Cnfg_trig_gen_type      
        );
end Cnfg_regs;

--==================================================================================================

architecture Behavioral of Cnfg_regs is

--==================================================================================================

COMPONENT DEBUG_CNFG_REGS

PORT (
	clk : IN STD_LOGIC;
	probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
	probe2 : IN STD_LOGIC_VECTOR(7 DOWNTO 0)
);
END COMPONENT  ;



begin

CNFG_REGS_DEBUG : DEBUG_CNFG_REGS
PORT MAP (
	clk => clk_i,
	probe0(0) => Ctrl_regs_i(8)(0), 
	probe1 => Ctrl_regs_i(4),
	probe2 => Ctrl_regs_i(5)
);



--==================================================================================================
-- START OF MAIN BODY --
--==================================================================================================

    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- Configuration Registers assignment --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    process(Clk_i)
    begin
        if (Reset_i = '1') then
            Cnfg_global_o.reg_addr_page <= (others => '0');
        elsif rising_edge(Clk_i) then
            -- Register Address Page
            Cnfg_global_o.reg_addr_page                 <= Ctrl_regs_i(1);
            Cnfg_global_o.fifo_packet_size(7 downto 0)  <= Ctrl_regs_i(2);
            Cnfg_global_o.fifo_packet_size(15 downto 8) <= Ctrl_regs_i(3);
            
            Cnfg_readout_o.dac_value(7 downto 0)   <= Ctrl_regs_i(4);
            Cnfg_readout_o.dac_value(15 downto 8)  <= Ctrl_regs_i(5);
            Cnfg_readout_o.integr_dur(7 downto 0)  <= Ctrl_regs_i(6);
            Cnfg_readout_o.integr_dur(15 downto 8) <= Ctrl_regs_i(7);
            Cnfg_readout_o.edge_det_dis            <= Ctrl_regs_i(8)(0);
            Cnfg_readout_o.mux_addr                <= Ctrl_regs_i(9)(2 downto 0);--(8)(3 downto 1);
            Cnfg_readout_o.adc_addr                <= Ctrl_regs_i(9)(NUM_CHANNELS-1 downto 0);
            
            cnfg_trig_gen_o.duration     <= to_integer(unsigned(Ctrl_regs_i(10)));
            cnfg_trig_gen_o.delay        <= to_integer(unsigned(Ctrl_regs_i(11)));
            cnfg_trig_gen_o.nb_of_pulses <= to_integer(unsigned(Ctrl_regs_i(12)));
        end if;
    end process;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


end Behavioral;
--==================================================================================================
--==================================================================================================
