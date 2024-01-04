--==================================================================================================
-- Company      : NCSR Demokritos
-- Engineer     : Yiannis Kazas
-- Create Date  : 16/11/2023 06:40:24 PM
-- Module Name  : PIFN_System_top - Behavioral
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Description  : 
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Last Changes : 16-Nov-2023
--==================================================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.user_package.all;
library UNISIM;
use UNISIM.VComponents.all;

--==================================================================================================

entity PIFN_System_top is
    generic (
       -- System Clock = 40MHz
       -- Baud Rate    = 5M ---//500k
       -- CLKS_PER_BIT = System_Clk(Hz) / Baud Rate
        CLKS_PER_BIT : integer := 8  
    );
    PORT (
        --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--
            -- signals to/from Arty board --
        --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--
        --***** clock & resets *****--
        Clk_100MHz_i     : in std_logic; -- On-board oscillator, 100MHz        
        --***** uart/usb pins *****--
        UART_rx_serial_i : in std_logic;
        UART_tx_serial_o : out std_logic;
        --***** leds & buttons *****--
        Switch_i         : in std_logic_vector(3 downto 0);
        Button_i         : in std_logic_vector(3 downto 0);
        LED_o            : out std_logic_vector(3 downto 0);
        --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--
            --***** User Core Signals *****--
        --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--
        -- Comparator Signals (TS3011)
        Trigger_i   : in std_logic;
        -- Integrator Switch (TS5A3166)
        Integrator_rst_o : out std_logic_vector(NUM_CHANNELS-1 downto 0);
        -- DAC signals (DAC7311)
        DAC_CS_o    : out std_logic;
        DAC_SCLK_o  : out std_logic;
        DAC_DIN_o   : out std_logic;
        -- ADC Signals (AD7091)
        ADC_SDO_i   : in std_logic_vector(NUM_CHANNELS-1 downto 0);
        ADC_CONV_o  : out std_logic_vector(NUM_CHANNELS-1 downto 0);
        ADC_CS_o    : out std_logic_vector(NUM_CHANNELS-1 downto 0);
        ADC_SCLK_o  : out std_logic;--_vector(NUM_CHANNELS-1 downto 0);
        -- MUX signals (TMUX1108)
        MUX_ADDR_o  : out std_logic_vector(2 downto 0);
        -- Trigger Pulse for laser driver
        Laser_trig_o : out std_logic;
        -- DEBUGGING SIGNALS
        Hit_flag_dbg     : out std_logic;
        ADC_en_dbg       : out std_logic;
        DAQ_state_dbg    : out std_logic;
        Clr_hit_flag_dbg : out std_logic        
    );
end PIFN_System_top;

--==================================================================================================

architecture Behavioral of PIFN_System_top is

--==================================================================================================

--==================================================================================================
-- Start of Component Declaration
--==================================================================================================
    component Clk_gen
    port
     (-- Clock in ports
      -- Clock out ports
      clk_out1          : out    std_logic;
      clk_out2          : out    std_logic;
      -- Status and control signals
      reset             : in     std_logic;
      locked            : out    std_logic;
      clk_in1           : in     std_logic
     );
    end component;
--==================================================================================================
-- END of Component Declaration
--==================================================================================================

--==================================================================================================
-- Start of Signal Declaration
--==================================================================================================
    -- clocks
    signal clk_100MHz         : std_logic;
    signal clk_40MHz          : std_logic;
    signal clk_20MHz          : std_logic;
    signal clk_user           : std_logic;
    -- resets
    signal reset_hw           : std_logic;  -- reset from hardware
    signal reset_sw           : std_logic;  -- reset from software
    signal usr_core_reset     : std_logic;  -- reset to user core      
    -- Register arrays
    signal Status_register    : stdvec8_tx_array;   
    signal Control_register   : stdvec8_rx_array; 
    -- Signals for tx fifo (from user core to host pc)
    signal Status_fifo_wr_en  : std_logic;
    signal Status_fifo_din    : std_logic_vector(15 downto 0);  
    signal Status_fifo_full   : std_logic;
    signal Status_fifo_empty  : std_logic;
    -- signals for rx fifo (from host pc to user core)
    signal Control_fifo_rd_en : std_logic;
    signal Control_fifo_dout  : std_logic_vector(7 downto 0);
    signal Control_fifo_empty : std_logic;
    -- Control Command ID
    signal Command_id         : std_logic_vector(5 downto 0);
    signal Cmd_strobe         : std_logic;
    signal Cmd_fifo_rd_en     : std_logic;
    signal Cmd_fifo_empty     : std_logic;
    signal rst_sys_fifo       : std_logic;
    -- 
    
    signal timeout : std_logic;
    signal integrator_rst : std_logic;
    
    signal stat_global  : stat_global_type;
    signal cnfg_global  : cnfg_global_type;
    signal fifo_pkt_rdy : std_logic;
    
--==================================================================================================
-- END of Signal Declaration
--==================================================================================================

begin

--==================================================================================================
-- START OF MAIN BODY --
--==================================================================================================

    Reset_hw <= Button_i(3);
    LED_o(1) <= Trigger_i;
    LED_o(2) <= Status_fifo_full;
    LED_o(3) <= Status_fifo_empty;
    
    ADC_en_dbg       <= stat_global.adc_en;
    Hit_flag_dbg     <= stat_global.hit_flag;
    Clr_hit_flag_dbg <= stat_global.clr_hit_flag;
    DAQ_state_dbg    <= Trigger_i;--Status_fifo_full;--stat_global.daq_state;
    
    Integr_rst_gen: for c in 0 to NUM_CHANNELS-1 generate
        Integrator_rst_o(c) <= integrator_rst;
    end generate;
    
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- Clock Generation --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- global clock buffer
    clk_100MHz_bufg: bufg    port map (i => Clk_100MHz_i, o => Clk_100MHz);
    -- Clock generator
    Clock_gen : Clk_gen
       port map ( 
      -- Clock out ports  
       clk_out1 => clk_20MHz,
       clk_out2 => clk_40MHz,
      -- Status and control signals                
       reset => Reset_hw,
       locked => LED_o(0),
       -- Clock in ports
       clk_in1 => Clk_100MHz
     );
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- System Core --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--        sys_controller_rst <= Reset or 
        Sys_core: entity work.system_core
          generic map (
            CLKS_PER_BIT => CLKS_PER_BIT 
          )    
          Port map ( 
            -- Clocks and Resets --
            Clk_system_i       => clk_40MHz,
            Clk_user_i         => clk_user,
            Reset_i            => Reset_hw,
            Reset_fifo_i       => rst_sys_fifo,
            -- UART -
            UART_rx_serial_i   => UART_rx_serial_i,
            UART_tx_serial_o   => UART_tx_serial_o,
            -- User Interface --
            Sw_reset_o         => reset_sw,
            TX_data_array_i    => Status_register,
            RX_data_array_o    => Control_register,
            TX_fifo_wr_en_i    => Status_fifo_wr_en,
            TX_fifo_din_i      => Status_fifo_din,
            TX_fifo_full_o     => Status_fifo_full,
            TX_fifo_empty_o    => Status_fifo_empty,
            RX_fifo_rd_en_i    => Control_fifo_rd_en,
            RX_fifo_dout_o     => Control_fifo_dout,
            RX_fifo_empty_o    => Control_fifo_empty,
            Cmd_fifo_rd_en_i   => Cmd_fifo_rd_en,
            Command_id_o       => Command_id,
            Cmd_fifo_empty_o   => Cmd_fifo_empty,
            FIFO_pkt_rdy_o     => fifo_pkt_rdy,
            Cnfg_global_i      => cnfg_global,
            Cmd_strobe_o       => Cmd_strobe
            );
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    

    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- DPC User Core Implementation --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    usr_core_reset <= Reset_hw or reset_sw;
    PIFN_usr_core: entity work.PIFN_user_core
        port map (
            ----------------------------------------
                -- Generic-DAQ signals --
            ----------------------------------------
            -- Clocks & resets
            Reset_i              => usr_core_reset, -- Reset from hw or sw
            Reset_sys_fifo_o     => rst_sys_fifo,
            Clk_system_i         => clk_40MHz,
            Clk_user_o           => clk_user,       -- same as system_clk
            Clk_100MHz_i         => Clk_100MHz,
            Clk_20MHz_i          => Clk_20MHz,
            -- Control Command
            Cmd_fifo_rd_en_o     => Cmd_fifo_rd_en,
            Cmd_fifo_empty_i     => Cmd_fifo_empty,
            Command_id_i         => Command_id,
            Cmd_strobe_i         => Cmd_strobe,
            -- RX/TX data arrays 
            Control_register_i   => Control_register, 
            Status_register_o    => Status_register, 
            -- Status_fifo (user data to host pc)
            Status_fifo_full_i   => Status_fifo_full,
            Status_fifo_wr_en_o  => Status_fifo_wr_en,
            Status_fifo_din_o    => Status_fifo_din,
            -- Control_fifo (data from host pc to user) 
            Control_fifo_dout_i  => Control_fifo_dout,
            Control_fifo_empty_i => Control_fifo_empty,
            Control_fifo_rd_en_o => Control_fifo_rd_en,
            FIFO_pkt_rdy_i       => fifo_pkt_rdy,
            ----------------------------------------
                -- Application specific signals --
            ----------------------------------------
            -- Comparator Signals (TS3011)
            Trigger_i   => Trigger_i,
            -- Integrator Switch (TS5A3166)
            Integrator_rst_o => Integrator_rst,
            -- DAC signals (DAC7311)
            DAC_CS_o    => DAC_CS_o,
            DAC_SCLK_o  => DAC_SCLK_o,
            DAC_DIN_o   => DAC_DIN_o,
            -- ADC Signals (AD7091)
            ADC_SDO_i   => ADC_SDO_i,
            ADC_CONV_o  => ADC_CONV_o,
            ADC_CS_o    => ADC_CS_o,
            ADC_SCLK_o  => ADC_SCLK_o,
            -- MUX signals (TMUX1108)
            MUX_ADDR_o  => MUX_ADDR_o,
            -- Trigger pulse for laser driver
            Laser_trig_o => Laser_trig_o,
            -- Debug signals
            Stat_global_o => stat_global,
            Cnfg_global_o => cnfg_global,
            Timeout_o => timeout
        );
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

end Behavioral;
--==================================================================================================
--==================================================================================================
