--==================================================================================================
-- Company      : NCSR Demokritos
-- Engineer     : Yiannis Kazas
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Project Name : 
-- Module Name  : User Package
-- Description  : 
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Last Changes : 20-Nov-2023
--==================================================================================================

library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

package user_package is

--==================================================================================================
-- System Core --
--==================================================================================================

    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Command Controller Settings & Type Definitions --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    constant RD_ADDR_WIDTH    : integer := 6; -- 
    constant WR_ADDR_WIDTH    : integer := 6;
    constant FIFO_PKT_SIZE    : integer := 4096;
    constant TIMEOUT          : integer := 10_000; -- Timeout counter for FIFO-Read transactions
    constant RESET_SYSTEM     : std_logic_vector(5 downto 0):= "11" & x"F"; -- Reset System
    constant SET_GLB_SETTINGS : std_logic_vector(5 downto 0):= "00" & x"F"; -- Reset System
    type stdvec8_tx_array is array ((2**(RD_ADDR_WIDTH-1)) downto 0) of std_logic_vector(7 downto 0);
    type stdvec8_rx_array is array ((2**(WR_ADDR_WIDTH-1)) downto 0) of std_logic_vector(7 downto 0);     
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Status Register Messages for the Command Controller --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- status messages 
    constant CONTROLLER_IDLE         : std_logic_vector(7 downto 0):= x"00";
    constant WAITING_HEADER          : std_logic_vector(7 downto 0):= x"01";
    constant WAITING_NB_OF_RD_WORDS  : std_logic_vector(7 downto 0):= x"02";
    constant WAITING_NB_OF_WR_WORDS  : std_logic_vector(7 downto 0):= x"03";
    constant WAITING_WR_DATA         : std_logic_vector(7 downto 0):= x"04";
    constant RECEIVED_CONTROL_CMD    : std_logic_vector(7 downto 0):= x"05";
    constant READ_IN_PROGRESS        : std_logic_vector(7 downto 0):= x"06"; 
    constant WRITE_IN_PROGRESS       : std_logic_vector(7 downto 0):= x"07";  
    constant WRITE_COMPLETED         : std_logic_vector(7 downto 0):= x"08";  
    constant READ_COMPLETED          : std_logic_vector(7 downto 0):= x"09";  
    constant STATUS_READ_INITIATED   : std_logic_vector(7 downto 0):= x"0A";  
    constant STATUS_READ_COMPLETED   : std_logic_vector(7 downto 0):= x"0B";  
    -- error messages
    constant INVALID_START_OF_FRAME  : std_logic_vector(7 downto 0):= x"F0";
    constant INVALID_HEADER          : std_logic_vector(7 downto 0):= x"F1";
    constant INVALID_WRITE_END       : std_logic_vector(7 downto 0):= x"F2";
    constant INVALID_STATE           : std_logic_vector(7 downto 0):= x"F3";
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--==================================================================================================
--==================================================================================================

    
--==================================================================================================
-- User Core --
--==================================================================================================

    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Command ID --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Commands with ID "XX" & x"F" are reserved for System Core
    constant RESET_USER_CORE  : std_logic_vector(5 downto 0):= "11" & x"0"; -- Reset User Core Sub-module
    constant RESET_SYS_FIFO   : std_logic_vector(5 downto 0):= "11" & x"1"; -- Reset System TX FIFO
    constant CNFG_DAC         : std_logic_vector(5 downto 0):= "00" & x"1"; -- Set Threshold DAC
    constant SAMPLE_ADC       : std_logic_vector(5 downto 0):= "00" & x"2"; -- Sample ADC
    constant START_DAQ        : std_logic_vector(5 downto 0):= "00" & x"3"; -- Start Data Acquisition Process
    constant STOP_DAQ         : std_logic_vector(5 downto 0):= "00" & x"4"; -- Stop Data Acquisition Process
    constant START_LASER_TRIG : std_logic_vector(5 downto 0):= "00" & x"5"; -- Send Trigger Pulse to Laser
    constant FORCE_TRIG       : std_logic_vector(5 downto 0):= "00" & x"6"; -- Force Data Acquisition (for debugging purposes)
    constant STOP_LASER_TRIG  : std_logic_vector(5 downto 0):= "00" & x"7"; -- Send Trigger Pulse to Laser
    constant START_DEBUG      : std_logic_vector(5 downto 0):= "00" & x"8"; -- Enable TX interface debug
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    type Command_id_type is
    record
        rst_system   : std_logic;
        rst_usr_core : std_logic;
        rst_sys_fifo : std_logic;
        set_dac      : std_logic;
        read_adc     : std_logic;
        start_rec    : std_logic;
        stop_rec     : std_logic;
        start_trig   : std_logic;
        stop_trig    : std_logic;
        force_daq    : std_logic;
        debug_en     : std_logic;
    end record;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- SPI configuration --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    constant SPI_WORD_WIDTH          : integer := 16; -- Nb of bits per spi word
    constant SPI_TX_REG_ARRAY_WIDTH  : integer := 1; -- Nb of spi words for TX register
    constant SPI_RX_REG_ARRAY_WIDTH  : integer := 1;  -- Nb of spi words for RX register
    constant SPI_TX_REG_ARRAY_VECTOR : integer := (SPI_TX_REG_ARRAY_WIDTH*SPI_WORD_WIDTH);
    constant SPI_RX_REG_ARRAY_VECTOR : integer := (SPI_RX_REG_ARRAY_WIDTH*SPI_WORD_WIDTH);

    constant SPI_WR_ADDR_INIT        : integer := 0;--std_logic_vector(3 downto 0) := x"2";
    constant WORDS_TO_READ           : integer := 1;
    
    constant SPI_CLK_RATIO           : integer := 3;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- System Settings --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    constant NUM_CHANNELS : integer := 6; -- Nb of conversion channels in the system 
    
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Configuration Registers --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Goobal Configuration
    type Cnfg_global_type is
    record
        reg_addr_page    : std_logic_vector(7 downto 0);
        fifo_packet_size : std_logic_vector(15 downto 0);
    end record;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Configure Readout
    type Cnfg_readout_type is
    record
        dac_value    : std_logic_vector(15 downto 0);
        integr_dur   : std_logic_vector(15 downto 0);
        edge_det_dis : std_logic;
        adc_addr     : std_logic_vector(NUM_CHANNELS-1 downto 0);
        mux_addr     : std_logic_vector(2 downto 0);
    end record;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Trigger Generation Parameters --
    type Cnfg_trig_gen_type is
    record
        -- Laser trigger pulse gen
        start        : std_logic;
        stop         : std_logic;
        delay        : natural range 0 to 255;
        duration     : natural range 0 to 255;
        nb_of_pulses : natural range 0 to 255;
    end record;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Status Registers --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Readout Data  
    type adc_data_type is array (NUM_CHANNELS-1 downto 0) of std_logic_vector(15 downto 0);
    
    type stat_readout_type is
    record
        adc_data        : adc_data_type;
        adc_busy        : std_logic_vector(NUM_CHANNELS-1 downto 0);
        events_recorded : std_logic_vector(23 downto 0);
        fsm_status      : std_logic_vector(7 downto 0);
    end record;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Debug and Settings  
    type stat_global_type is
    record
--        fsm_status  : std_logic_vector(7 downto 0);
        tx_error    : std_logic_vector(NUM_CHANNELS-1 downto 0);
        debug       : std_logic_vector(7 downto 0);
    end record;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  
    
    
--==================================================================================================
--==================================================================================================


end user_package;
package body user_package is
end user_package;