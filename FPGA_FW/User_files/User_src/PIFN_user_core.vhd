--==================================================================================================
-- Company      : NCSR Demokritos 
-- Engineer     : Yiannis Kazas
-- Create Date  : 16/11/2023 06:40:24 PM
-- Module Name  : PIFN_user_core - Behavioral
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Description  : 
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Last Changes : 19-Nov-2023
--==================================================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.user_package.all;
library UNISIM;
use UNISIM.VComponents.all;

--==================================================================================================

entity PIFN_user_core is
    PORT (
        -- Clocks & resets
        Reset_i              : in std_logic;
        Reset_sys_fifo_o     : out std_logic;
        Clk_system_i         : in std_logic;  -- 50MHz input clock
        Clk_user_o           : out std_logic; -- 50MHz clk, same as clk_system_i
        Clk_100MHz_i         : in std_logic;
        Clk_20MHz_i          : in std_logic;
        -- Control Command
        Cmd_fifo_rd_en_o     : out std_logic;
        Cmd_fifo_empty_i     : in std_logic;
        Command_id_i         : in std_logic_vector(5 downto 0);
        Cmd_strobe_i         : in std_logic;
        -- RX/TX data arrays 
        Control_register_i   : in stdvec8_rx_array;
        Status_register_o    : out stdvec8_tx_array;  
        -- Status_fifo (user data to host pc)
        Status_fifo_full_i   : in std_logic;
        Status_fifo_wr_en_o  : out std_logic;
        Status_fifo_din_o    : out std_logic_vector(15 downto 0);
        -- Control_fifo (data from host pc to user) 
        Control_fifo_dout_i  : in std_logic_vector(7 downto 0);
        Control_fifo_empty_i : in std_logic;
        Control_fifo_rd_en_o : out std_logic;
        
        --------------------------------
            -- User Core Signals --          
        --------------------------------
        -- Comparator Signals (TS3011)
        Trigger_i   : in std_logic;
        -- Integrator Switch (TS5A3166)
        Integrator_rst_o : out std_logic;
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
        -- Trigger pulse for laser driver
        Laser_trig_o : out std_logic;
        -- Debug signals
        Stat_global_o : out stat_global_type;
        Timeout_o : out std_logic
    );
end PIFN_user_core;

--==================================================================================================

architecture Behavioral of PIFN_user_core is

--==================================================================================================
    -- Start of Component Declaration --
--==================================================================================================
    COMPONENT clkRateTool32 is
      PORT (
        clkref   : IN STD_LOGIC;
        clktest  : IN STD_LOGIC;
        clkvalue : IN STD_LOGIC;
        value    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
      );
    END COMPONENT;
--==================================================================================================
    -- END of Component Declaration --
--==================================================================================================



--==================================================================================================
    -- Start of Signal Declaration --
--==================================================================================================

    -- Cmd Controller
    signal Command_id   : command_id_type;
    signal rst_usr_core : std_logic;
    
    --------------------------------
        -- User Core Signals --          
    --------------------------------
    signal stat_global  : stat_global_type;
    signal stat_readout : stat_readout_type;
    
    -- Trigger pulse Generation
    signal cnfg_trig_gen  : cnfg_trig_gen_type;
    signal cnfg_readout   : cnfg_readout_type;
    signal cnfg_global    : cnfg_global_type;
    
    -- ADC signals
    signal adc_sclk     : std_logic_vector(NUM_CHANNELS-1 downto 0) := (others => '0');
    signal adc_en       : std_logic_vector(NUM_CHANNELS-1 downto 0) := (others => '0');
   
    -- Testing sequence
    signal daq_en          : std_logic := '0';
    signal fsm_read_adc    : std_logic := '0';
    signal clr_hit_flag    : std_logic := '0';
    signal hit_flag        : std_logic_vector(NUM_CHANNELS-1 downto 0) := (others => '0');
    
    signal daq_state : std_logic;
    
--    type array8x3bit is array (0 to 7) of std_logic_vector(2 downto 0);
--    constant MUX_ADDR_LUT : array8x3bit := ("
    
--==================================================================================================
    -- END of Signal Declaration --
--==================================================================================================

begin

--==================================================================================================
-- START OF MAIN BODY --
--==================================================================================================

    stat_global_o.adc_en        <= adc_en(0);
    stat_global_o.daq_state     <= daq_state;
    stat_global_o.hit_flag      <= hit_flag(0);
    stat_global_o.clr_hit_flag  <= clr_hit_flag;
    
    
    Clk_user_o       <= Clk_system_i; 
    Reset_sys_fifo_o <= command_id.rst_sys_fifo;
    rst_usr_core     <= Reset_i or command_id.rst_usr_core;
    
    ADC_SCLK_o <= adc_sclk(0);
    MUX_ADDR_o <= "110" when Cnfg_readout.mux_addr = "101" else -- Select MUX input 0 (SiPM_5)
                  "101" when Cnfg_readout.mux_addr = "100" else -- Select MUX input 1 (SiPM_4)
                  "100" when Cnfg_readout.mux_addr = "011" else -- Select MUX input 2 (SiPM_3)
                  "011" when Cnfg_readout.mux_addr = "010" else -- Select MUX Input 3 (SiPM_2)
                  "101" when Cnfg_readout.mux_addr = "001" else -- Select MUX input 6 (SiPM 1)
                  "111";                                        -- Select MUX Input 7 (SiPM 0)

    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- Command Controller for user core --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Command_controller: entity work.cmd_controller
        port map (
            Reset_i          => Reset_i,   
            Clk_user_i       => Clk_system_i,
            -- Control Command
            Cmd_fifo_rd_en_o => Cmd_fifo_rd_en_o,
            Cmd_fifo_empty_i => Cmd_fifo_empty_i,
            Command_id_i     => Command_id_i,
            Cmd_strobe_i     => Cmd_strobe_i,
            Command_id_o     => Command_id
            );       
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- Config Registers --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Config_regs: entity work.cnfg_regs
        port map (
            Reset_i         => rst_usr_core,
            Clk_i           => Clk_system_i,
            Ctrl_regs_i     => Control_register_i,
            Cnfg_global_o   => cnfg_global,
            Cnfg_readout_o  => cnfg_readout,
            Cnfg_trig_gen_o => cnfg_trig_gen
            );      
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            
    
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- Status Registers --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Stat_regs: entity work.status_regs
        port map (
            Reset_i         => rst_usr_core,
            Clk_i           => Clk_system_i,
            Stat_global_i   => stat_global,
            stat_readout_i  => stat_readout,
            Stat_regs_o     => Status_register_o
            );
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    

    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- Data Acquisition Procedure --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   
    DAQ_Sequence: entity work. DAQ_FSM
        port map (
            Reset_i           => rst_usr_core,
            Clk_i             => Clk_system_i,
            Command_id_i      => Command_id,
            Trigger_i         => Trigger_i,
            Cnfg_readout_i    => Cnfg_readout,
            Stat_readout_o    => stat_readout,
            Status_fifo_full_i => Status_fifo_full_i,
            DAQ_en_o          => daq_en,
            Integrator_rst_o  => Integrator_rst_o,
            ADC_en_o          => fsm_read_adc,
            debug_o           => daq_state
        );
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   
    
    
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- FIFO TX Interface --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FIFO_TX_Interface: entity work.TX_Interface
        port map (
            Reset_i        => rst_usr_core, 
            Clk_i          => Clk_system_i, 
            debug_en_i     => command_id.debug_en,
            DAQ_En_i       => daq_en, 
            FIFO_wr_en_o   => Status_fifo_wr_en_o,     
            FIFO_din_o     => Status_fifo_din_o, 
            Status_fifo_full_i => Status_fifo_full_i,
            ADC_data_i     => stat_readout.ADC_data, 
            Hit_flag_i     => hit_flag, 
            Clr_hit_flag_o => Clr_Hit_flag, 
            Rst_BRAM_i     => Command_id.bram_rst,
            BRAM_rd_addr_i => cnfg_readout.bram_rd_addr, 
            BRAM_rd_dout_o => stat_readout.bram_rd_dout,
            Error_o        => stat_global.tx_error 
        );
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- ADC AD7091 Interface --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ADC_iterface_gen: for i in NUM_CHANNELS-1 downto 0 generate
        adc_en(i) <= (Command_id.read_adc and cnfg_readout.adc_addr(i)) or fsm_read_adc;
        ADC_Interface: entity work.ADC_Interface
            port map (
                Rst_i        => rst_usr_core,
                Clk_i        => Clk_system_i,
                ADC_en_i     => adc_en(i),
                ADC_SDO_i    => ADC_SDO_i(i),
                ADC_CONV_o   => ADC_CONV_o(i),
                ADC_CS_o     => ADC_CS_o(i),
                ADC_SCLK_o   => ADC_sclk(i),
                ADC_DATA_o   => stat_readout.adc_data(i)(11 downto 0),
                ADC_busy_o   => stat_readout.adc_busy(i),
                Clr_Hit_flag_i => clr_hit_flag,
                Hit_flag_o     => hit_flag(i)
            );
    end generate;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- DAC DAC7311 Interface --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    DAC_Interface: entity work. SPI_Interface
        port map (
            Clk_spi_i => Clk_20MHz_i,
            Reset_i   => rst_usr_core,
            -- Spi control signals --
            SPI_rd_en_i        => '0',
            SPI_wr_en_i        => Command_id.set_dac,
            SPI_rd_addr_i      => (others => '0'),
            -- SPI data --
            SPI_tx_reg_array_i => cnfg_readout.dac_value,
            SPI_rx_reg_array_o => open,
            -- SPI signals --
            SPI_MISO_i         => '0',
            SPI_CS_o           => DAC_CS_o,
            SPI_SCK_o          => DAC_SCLK_o,
            SPI_MOSI_o         => DAC_DIN_o
        );
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- Laser Trigger Pulse generation --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Pulse_trig_gen: entity work.Trigger_Pulse_gen
        port map ( 
            Reset_i         => rst_usr_core,
            Clk_i           => Clk_100MHz_i,
            Command_id_i    => Command_id,
            cnfg_trig_gen_i => cnfg_trig_gen,
            Trigger_pulse_o => Laser_trig_o
        );
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- Clock Rate tool --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--    -- User clock
--    user_clk_monitor: clkRateTool32
--      Port map (
--       clkref   => Clk_fabric_i,
--       clktest  => Clk_user,
--       clkvalue => Clk_system_i,
--       value    => user_clk_rate);
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


--==================================================================================================
--==================================================================================================

end Behavioral;
