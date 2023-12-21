--==================================================================================================
-- Company      : NCSR Demokritos
-- Engineer     : Yiannis Kazas
-- Create Date  : 25/08/2022 06:40:24 PM
-- Module Name  : Cmd_controller - Behavioral
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Description  : 
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Last Changes : 25-Aug-2022
--==================================================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.user_package.all;
library UNISIM;
use UNISIM.VComponents.all;

--==================================================================================================
entity Cmd_controller is
  Port (-- Clocks & Resets 
        Reset_i          : in std_logic;
        Clk_user_i       : in std_logic; -- 20MHz
        -- Control Command
        Cmd_fifo_rd_en_o : out std_logic;
        Cmd_fifo_empty_i : in std_logic;
        Command_id_i     : in std_logic_vector(5 downto 0);
        Cmd_strobe_i     : in std_logic;
        Command_id_o     : out command_id_type
         );
end Cmd_controller;
--==================================================================================================

architecture Behavioral of Cmd_controller is

--==================================================================================================
    -- Start of Signal Declaration
--==================================================================================================
-- TX & RX registers
signal status_register     : std_logic_vector(7 downto 0)  :=(others=>'0');
signal status_reg_from_fsm : std_logic_vector(7 downto 0)  :=(others=>'0');

signal user_status_reg  : std_logic_vector(7 downto 0)  :=(others=>'0');
signal Board_cnfg       : std_logic_vector(7 downto 0)  :=x"FF";--(others=>'0');

-- Main FSM
type Cmd_controller_state_type is (Cmd_Idle, Read_Cmds, Send_Cmds, System_reset, SPI_Interface, Extend_Cmds);
signal Cmd_controller_state : Cmd_controller_state_type;

signal cmd_sync_counter : integer range 0 to 300 := 0; 

signal state : std_logic_vector(3 downto 0);

--==================================================================================================
    -- END of Signal Declaration
--==================================================================================================


begin


--==================================================================================================
    -- Start of Main Body
--==================================================================================================

    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- Main Controller FSM --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Dispatches Control Commands and handles CDC sync 
    process(Reset_i, clk_user_i)
    begin
        if (Reset_i = '1') then
            cmd_controller_state <= CMD_Idle;
        elsif rising_edge(clk_user_i) then
        
            case Cmd_controller_state is
                when CMD_Idle =>
                state <= x"0";
                    -- self reset on every clk cycle
                    cmd_sync_counter          <= 0;
                    Command_id_o.rst_system   <= '0';
                    Command_id_o.rst_sys_fifo <= '0';
                    Command_id_o.rst_usr_core <= '0';
                    Command_id_o.set_dac      <= '0';
                    Command_id_o.read_adc     <= '0';
                    Command_id_o.start_rec    <= '0';
                    Command_id_o.stop_rec     <= '0';
                    Command_id_o.start_trig   <= '0';
                    Command_id_o.stop_trig    <= '0';
                    Command_id_o.force_daq    <= '0';
                    Command_id_o.debug_en     <= '0';
                    Command_id_o.bram_rst     <= '0';
                    if (Cmd_fifo_empty_i = '0') then
                        Cmd_fifo_rd_en_o     <= '1';
                        Cmd_controller_state <= Read_Cmds;
                    end if;
                
                when Read_Cmds =>
                state <= x"1";
                    Cmd_fifo_rd_en_o     <= '0';   
                    Cmd_controller_state <= Send_Cmds;
                
                when Send_Cmds =>
                    if (Command_id_i = RESET_SYSTEM) then
                        Cmd_controller_state    <=  CMD_Idle;
                        Command_id_o.rst_system <= '1';
                    elsif (Command_id_i = RESET_USER_CORE) then
                        Cmd_controller_state      <= CMD_Idle;
                        Command_id_o.rst_usr_core <= '1';
                    elsif (Command_id_i = RESET_SYS_FIFO) then
                        Cmd_controller_state      <= CMD_Idle;
                        Command_id_o.rst_sys_fifo <= '1';
                    elsif (Command_id_i = CNFG_DAC) then
                        Cmd_controller_state <=  SPI_INTERFACE;
                        Command_id_o.set_dac <= '1';
                    elsif (Command_id_i = SAMPLE_ADC) then
                        Cmd_controller_state  <=  CMD_Idle;
                        Command_id_o.read_adc <= '1';
                    elsif (Command_id_i = START_DAQ) then
                        Cmd_controller_state   <=  CMD_Idle;
                        Command_id_o.start_rec <= '1';
                    elsif (Command_id_i = STOP_DAQ) then
                        Cmd_controller_state  <=  CMD_Idle;
                        Command_id_o.stop_rec <= '1';
                    elsif (Command_id_i = START_LASER_TRIG) then
                        Cmd_controller_state  <=  CMD_Idle;
                        Command_id_o.start_trig <= '1';
                    elsif (Command_id_i = STOP_LASER_TRIG) then
                        Cmd_controller_state  <=  CMD_Idle;
                        Command_id_o.stop_trig <= '1';
                    elsif (Command_id_i = FORCE_TRIG) then
                        Cmd_controller_state   <=  CMD_Idle;
                        Command_id_o.force_daq <= '1';
                    elsif (Command_id_i = START_DEBUG) then
                        Cmd_controller_state  <=  CMD_Idle;
                        Command_id_o.debug_en <= '1';
                    elsif (Command_id_i = RESET_BRAM) then
                        Cmd_controller_state  <=  CMD_Idle;
                        Command_id_o.bram_rst <= '1';
                        
                    else
                        Cmd_controller_state <= CMD_Idle;
                    end if;
                                
                -- extend cmd duration to synchronize with 20MHz clock used for SPI 
                when SPI_Interface =>
                state <= x"2";
                    cmd_sync_counter <= cmd_sync_counter + 1;
                    if (cmd_sync_counter >= SPI_CLK_RATIO) then
                        Cmd_controller_state <= CMD_Idle;
                    end if; 
                    
                when Extend_Cmds =>
                state <= x"3";
                    cmd_sync_counter <= cmd_sync_counter + 1;
                    if (cmd_sync_counter >= 5) then
                        Cmd_controller_state <= CMD_Idle;
                    end if; 
                                
                when others =>
                    Cmd_controller_state <= CMD_Idle;
            end case;    
        end if;
    end process;            
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


--==================================================================================================
--==================================================================================================

end Behavioral;
