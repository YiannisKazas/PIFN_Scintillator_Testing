--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Company      : NCSR Demokritos/University of Athens
-- Engineer     : Yiannis Kazas
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Project Name : Generic DAQ System
-- Module Name  : System Core - Behavioral
-- Description  : System Core to support basic functions for PYNQ board and UART
--              : communication with the host PC
-- Dependencies : user_package.vhd
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Last Changes : 06-Sep-2020
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.user_package.all;

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- System Clock = 50MHz
    -- Baud Rate    = 500K
entity System_core is
  generic (
     -- CLKS_PER_BIT = System_Clk(Hz) / Baud Rate
        CLKS_PER_BIT : integer := 10--400 -- (156 = 156MHz System Clk, 1M baud rate) --(10 = 100MHz System Clock, 10M baud rate) -- (868 = 100Mhz System Clock, 115200 baud rate) 
      );
  Port ( 
        -- Clocks and Resets --
        Clk_system_i       : in std_logic;
        Clk_user_i         : in std_logic;
        Reset_i            : in std_logic;
        Reset_fifo_i       : in std_logic;
        -- UART -
        UART_rx_serial_i   : in std_logic;
        UART_tx_serial_o   : out std_logic;
        -- User Interface --
        Sw_reset_o         : out std_logic;
        TX_data_array_i    : in stdvec8_tx_array;              -- data from user core to host pc
        RX_data_array_o    : out stdvec8_rx_array;             -- data from host pc to user core
        TX_fifo_wr_en_i    : in std_logic;
        TX_fifo_din_i      : in std_logic_vector(15 downto 0);
        TX_fifo_full_o     : out std_logic;
        TX_fifo_empty_o    : out std_logic;
        RX_fifo_rd_en_i    : in std_logic;
        RX_fifo_dout_o     : out std_logic_vector(7 downto 0);
        RX_fifo_empty_o    : out std_logic;
        Cmd_fifo_rd_en_i   : in std_logic;
        Command_id_o       : out std_logic_vector(5 downto 0);
        Cmd_fifo_empty_o   : out std_logic;
        FIFO_pkt_rdy_o     : out std_logic;
        Cnfg_global_i      : in cnfg_global_type;
        Cmd_strobe_o       : out std_logic
        );
end System_core;
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

architecture Behavioral of System_core is

--================================================================================
-- Start of Signal Declaration
--================================================================================
--constant CLKS_PER_BIT  : integer := 

signal uart_rx_valid   : std_logic;
signal uart_rx_byte    : std_logic_vector(7 downto 0):=(others=>'0');
signal uart_tx_data_en : std_logic;
signal uart_tx_byte    : std_logic_vector(7 downto 0):=(others=>'0');
signal uart_tx_active  : std_logic;
signal uart_tx_done    : std_logic;
--debug
signal uart_tx_data_en_int : std_logic;
signal uart_tx_byte_int    : std_logic_vector(7 downto 0):=(others=>'0');

--================================================================================
-- End of Signal Declaration
--================================================================================

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- DEBUG --
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
signal loopback : stdvec8_rx_array;
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

begin

uart_tx_data_en_int <= uart_tx_data_en; --when switch = '0' else '1';
uart_tx_byte_int    <= uart_tx_byte; --when switch = '0' else x"AA";
--================================================================================
-- Start of Main Body
--================================================================================

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Serial Communication Protocol --
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Communication_Ctrl: entity work.communication_controller
    port map (
        -- Clks & Resets --
        Clk_uart_i           => Clk_system_i,
        Clk_user_i           => Clk_user_i,
        Reset_i              => Reset_i,
        Reset_fifo_i         => Reset_fifo_i,
        Sw_reset_o           => Sw_reset_o,
        -- UART Interface
        UART_rx_data_valid_i => uart_rx_valid,
        UART_rx_data_i       => uart_rx_byte,
        UART_tx_data_en_o    => uart_tx_data_en,
        UART_tx_data_o       => uart_tx_byte,
        UART_tx_active_i     => UART_tx_active,
        UART_tx_done_i       => UART_tx_done,
        -- User Interface --
        TX_data_array_i      => TX_data_array_i,
        RX_data_array_o      => RX_data_array_o,
        -- Tx_fifo (user data to host pc)
        TX_fifo_wr_en_i      => TX_fifo_wr_en_i,
        TX_fifo_din_i        => TX_fifo_din_i,
        TX_fifo_full_o       => TX_fifo_full_o,
        TX_fifo_empty_o      => TX_fifo_empty_o,
        -- Rx_fifo (data from host pc to user) 
        RX_fifo_rd_en_i      => RX_fifo_rd_en_i,
        RX_fifo_dout_o       => RX_fifo_dout_o,
        RX_fifo_empty_o      => RX_fifo_empty_o,
        -- Cmd Fifo
        Cmd_fifo_rd_en_i     => Cmd_fifo_rd_en_i,
        Command_id_o         => Command_id_o,
        Cmd_fifo_empty_o     => Cmd_fifo_empty_o,
        FIFO_pkt_rdy_o       => FIFO_pkt_rdy_o,
        Cnfg_global_i        => Cnfg_global_i,
        
        Cmd_strobe_o        => Cmd_strobe_o
    );
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- UART module --
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- UART RX
UART_RX_module: entity work.UART_RX
    generic map (
        g_CLKS_PER_BIT => CLKS_PER_BIT 
    )    
    port map (
        Clk_i       => Clk_system_i,
        RX_Serial_i => UART_rx_serial_i,
        RX_DV_o     => UART_rx_valid,
        RX_Byte_o   => UART_rx_byte
    );
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- UART TX
UART_TX_module: entity work.UART_TX
    generic map (
        g_CLKS_PER_BIT => CLKS_PER_BIT
    )    
    port map (
        Clk_i       => Clk_system_i,
        TX_DV_i     => UART_tx_data_en_int,
        TX_Byte_i   => UART_tx_byte_int,
        TX_Active_o => UART_tx_active,
        TX_Serial_o => UART_tx_serial_o,
        TX_Done_o   => UART_tx_done
    );
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

end Behavioral;