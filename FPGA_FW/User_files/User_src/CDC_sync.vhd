----------------------------------------------------------------------------------
-- Company      : ADVEOS
-- Engineer     : Yiannis Kazas
----------------------------------------------------------------------------------
-- Project Name : ADVEOS Generic DAQ
-- Module Name  : CDC_sync - Behavioral
-- Description  : 
-- Dependencies : user_package.vhd
----------------------------------------------------------------------------------
-- Last Changes : 7-Dec-2019
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

----------------------------------------------------------------------------------
entity CDC_sync is
  Port (
        reset_i   : in std_logic;
        clk_i     : in std_logic;
        data_in   : in std_logic;
        data_out  : out std_logic
   );
end CDC_sync;
----------------------------------------------------------------------------------

architecture Behavioral of CDC_sync is

--==================================================================================
-- Start of Signal Declaration
--==================================================================================
signal data_pre_sync     : std_logic:='0';
signal data_sync         : std_logic:='0';
--==================================================================================
-- END of Signal Declaration
--==================================================================================

begin

--==================================================================================
-- Start of Main Body
--==================================================================================
process(Reset_i, Clk_i)
begin
    if (Reset_i = '1') then
        data_out          <= '0';
        data_pre_sync     <= '0';
        data_sync         <= '0';
    elsif rising_edge(Clk_i) then
        data_pre_sync     <= data_in;
        data_sync         <= data_pre_sync;
        data_out          <= data_sync;    
    end if;
end process;            
--==================================================================================
-- End of Main Body
--==================================================================================

end Behavioral;
