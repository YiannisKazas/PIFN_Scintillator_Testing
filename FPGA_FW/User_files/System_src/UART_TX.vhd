----------------------------------------------------------------------
-- File Downloaded from http://www.nandland.com
----------------------------------------------------------------------
-- This file contains the UART Transmitter.  This transmitter is able
-- to transmit 8 bits of serial data, one start bit, one stop bit,
-- and no parity bit.  When transmit is complete o_TX_Done will be
-- driven high for one clock cycle.
--
-- Set Generic g_CLKS_PER_BIT as follows:
-- g_CLKS_PER_BIT = (Frequency of Clk_i)/(Frequency of UART)
-- Example: 10 MHz Clock, 115200 baud UART
-- (10000000)/(115200) = 87
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity UART_tx is
  generic (
    g_CLKS_PER_BIT : integer --:= 115     -- Needs to be set correctly
    );
  port (
    Clk_i       : in  std_logic;
    TX_DV_i     : in  std_logic;
    TX_Byte_i   : in  std_logic_vector(7 downto 0);
    TX_Active_o : out std_logic;
    TX_Serial_o : out std_logic;
    TX_Done_o   : out std_logic
    );
end UART_tx;
 
 
architecture RTL of UART_TX is
 
  type t_SM_Main is (s_Idle, s_TX_Start_Bit, s_TX_Data_Bits,
                     s_TX_Stop_Bit, s_Cleanup);
  signal r_SM_Main : t_SM_Main := s_Idle;
 
  signal r_Clk_Count : integer range 0 to g_CLKS_PER_BIT-1 := 0;
  signal r_Bit_Index : integer range 0 to 7 := 0;  -- 8 Bits Total
  signal r_TX_Data   : std_logic_vector(7 downto 0) := (others => '0');
  signal r_TX_Done   : std_logic := '0';
   
-----------------------------------------------------------------------------
--  -- Debug Core --
--  ---------------------------------------------------------------------------
--  COMPONENT UART_rx_debug
--  PORT (
--      clk : IN STD_LOGIC;
--      probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--      probe1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--      probe2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
--      probe3 : IN STD_LOGIC_VECTOR(7 DOWNTO 0)
--  );
--  END COMPONENT  ;
--  ---------------------------------------------------------------------------
--  signal probe0 : STD_LOGIC_VECTOR(0 DOWNTO 0); 
--  signal probe1 : STD_LOGIC_VECTOR(0 DOWNTO 0); 
--  signal probe2 : STD_LOGIC_VECTOR(0 DOWNTO 0);
--  signal probe3 : STD_LOGIC_VECTOR(7 DOWNTO 0);
--  signal tx_serial_sig : std_logic;
--  signal tx_active : std_logic;
  
--  signal clk_counter : integer range 0 to 400:=0;
--  signal clk_div : std_logic:='0';
--  ---------------------------------------------------------------------------
   
   
begin
 
-----------------------------------------------------------------------------
--TX_serial_o <= tx_serial_sig;
--probe0(0) <= tx_active;
--probe1(0) <= tx_serial_sig;
--probe2(0) <= TX_DV_i;
--probe3 <= TX_byte_i;
----
--process(clk_i)
--begin
--    if rising_edge(clk_i) then 
--        if clk_counter = 200 then
--            clk_div <= not clk_div;
--            clk_counter <= 0;
--        else
--            clk_counter <= clk_counter + 1;
--        end if;
--    end if;
--end process;
----
--DEBUG_UART_Tx : UART_rx_debug
--PORT MAP (
--	clk => clk_i,
--	probe0 => probe0, 
--	probe1 => probe1, 
--	probe2 => probe2,
--	probe3 => probe3
--);
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------

  p_UART_TX : process (Clk_i)
  begin
    if rising_edge(Clk_i) then
         
      case r_SM_Main is
 
        when s_Idle =>
          TX_Active_o <= '0';
          TX_serial_o <= '1';         -- Drive Line High for Idle
          r_TX_Done   <= '0';
          r_Clk_Count <= 0;
          r_Bit_Index <= 0;
 
          if TX_DV_i = '1' then
            r_TX_Data <= TX_Byte_i;
            r_SM_Main <= s_TX_Start_Bit;
          else
            r_SM_Main <= s_Idle;
          end if;
 
           
        -- Send out Start Bit. Start bit = 0
        when s_TX_Start_Bit =>
          TX_Active_o <= '1';
          TX_serial_o <= '0';
 
          -- Wait g_CLKS_PER_BIT-1 clock cycles for start bit to finish
          if r_Clk_Count < g_CLKS_PER_BIT-1 then
            r_Clk_Count <= r_Clk_Count + 1;
            r_SM_Main   <= s_TX_Start_Bit;
          else
            r_Clk_Count <= 0;
            r_SM_Main   <= s_TX_Data_Bits;
          end if;
 
           
        -- Wait g_CLKS_PER_BIT-1 clock cycles for data bits to finish          
        when s_TX_Data_Bits =>
          TX_serial_o <= r_TX_Data(r_Bit_Index);
           
          if r_Clk_Count < g_CLKS_PER_BIT-1 then
            r_Clk_Count <= r_Clk_Count + 1;
            r_SM_Main   <= s_TX_Data_Bits;
          else
            r_Clk_Count <= 0;
             
            -- Check if we have sent out all bits
            if r_Bit_Index < 7 then
              r_Bit_Index <= r_Bit_Index + 1;
              r_SM_Main   <= s_TX_Data_Bits;
            else
              r_Bit_Index <= 0;
              r_SM_Main   <= s_TX_Stop_Bit;
            end if;
          end if;
 
 
        -- Send out Stop bit.  Stop bit = 1
        when s_TX_Stop_Bit =>
          TX_serial_o <= '1';
 
          -- Wait g_CLKS_PER_BIT-1 clock cycles for Stop bit to finish
          if r_Clk_Count < g_CLKS_PER_BIT-1 then
            r_Clk_Count <= r_Clk_Count + 1;
            r_SM_Main   <= s_TX_Stop_Bit;
          else
            r_TX_Done   <= '1';
            r_Clk_Count <= 0;
            r_SM_Main   <= s_Cleanup;
          end if;
 
                   
        -- Stay here 1 clock
        when s_Cleanup =>
          TX_Active_o <= '0';
          r_TX_Done   <= '1';
          r_SM_Main   <= s_Idle;
           
             
        when others =>
          r_SM_Main <= s_Idle;
 
      end case;
    end if;
  end process p_UART_TX;
 
  TX_Done_o <= r_TX_Done;
   
end RTL;