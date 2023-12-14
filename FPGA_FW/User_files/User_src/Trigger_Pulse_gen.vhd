--==================================================================================================
-- Company      : NCSR Demokritos
-- Engineer     : Yiannis Kazas
-- Create Date: 11/21/2023 02:32:09 PM
-- Module Name  : Trigger_Pulse_gen - Behavioral
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Description  : 
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Last Changes : 21-Nov-2023
--==================================================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.user_package.all;
library UNISIM;
use UNISIM.VComponents.all;

--==================================================================================================

entity Trigger_Pulse_gen is
    Port ( 
        Reset_i         : in std_logic;
        Clk_i           : in std_logic;
        Command_id_i    : in command_id_type;
        cnfg_trig_gen_i : in cnfg_trig_gen_type;
        Trigger_pulse_o : out std_logic    
    );
end Trigger_Pulse_gen;

--==================================================================================================


architecture Behavioral of Trigger_Pulse_gen is


--==================================================================================================
    -- Start of Signal Declaration --
--==================================================================================================
   
    signal start_trig : std_logic;
    signal stop_trig  : std_logic;
    
    signal trig_delay     : natural range 0 to 255;
    signal trig_duration  : natural range 0 to 255;
    signal nb_of_pulses   : natural range 0 to 255;
    signal trig_duration_cntr : natural range 0 to 255;
    signal trig_delay_cntr    : natural range 0 to 255;
    signal pulse_cntr         : natural range 0 to 255;
    
    type trigger_fsm_type is (IDLE,SEND_PULSE, DELAY);
    signal trigger_fsm     : trigger_fsm_type;
    signal trigger_pulse   : std_logic;
    signal trigger_counter : integer;

--==================================================================================================
    -- END of Signal Declaration --
--==================================================================================================

begin


--==================================================================================================
-- START OF MAIN BODY --
--==================================================================================================

    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- CDC Sync of Control signals
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CDC_start: entity work.CDC_sync 
        port map (
        Reset_i  => Reset_i,
        Clk_i    => Clk_i,
        data_in  => command_id_i.start_trig,
        data_out => start_trig
      );    
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CDC_stop: entity work.CDC_sync 
        port map (
        Reset_i  => Reset_i,
        Clk_i    => Clk_i,
        data_in  => command_id_i.stop_trig,
        data_out => stop_trig
      );    
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    process(clk_i) 
    begin
        if rising_edge(Clk_i) then
            trig_duration <= cnfg_trig_gen_i.duration;
            trig_delay    <= cnfg_trig_gen_i.delay;
            nb_of_pulses  <= cnfg_trig_gen_i.nb_of_pulses;
        end if;
    end process;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- Trigger Pulse Generation --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    process(reset_i, Clk_i)
    begin  
        if (Reset_i = '1') then
            Trigger_pulse_o    <= '0'; 
            trig_duration_cntr <= 0;
            trig_delay_cntr    <= 0;
            pulse_cntr         <= 0;
            trigger_fsm        <= IDLE;
        elsif rising_edge(Clk_i) then
            case trigger_fsm is
                when IDLE =>
                    Trigger_pulse_o    <= '0'; 
                    trig_duration_cntr <= 0;
                    trig_delay_cntr    <= 0;
                    pulse_cntr         <= 0;
                    if (start_trig = '1') then
                        trigger_fsm <= SEND_PULSE;
                    end if;
                    
                when SEND_PULSE =>
                    Trigger_pulse_o    <= '1';
                    trig_delay_cntr    <= 0;
                    trig_duration_cntr <= trig_duration_cntr +1;
                    if (trig_duration_cntr >= trig_duration) then
                        pulse_cntr  <= pulse_cntr + 1;
                        trigger_fsm <= DELAY;
                    end if;
                    
                when DELAY =>
                    Trigger_pulse_o    <= '0';
                    trig_duration_cntr <= 0;
                    if ((nb_of_pulses /= 0) and (pulse_cntr >= nb_of_pulses)) or (stop_trig = '1') then
                        trigger_fsm <= IDLE;
                    elsif (trig_delay_cntr >= trig_delay) then
                        trigger_fsm <= SEND_PULSE;
                    else
                        trig_delay_cntr    <= trig_delay_cntr + 1;
                        trigger_fsm <= DELAY;
                    end if;
                    
                when others =>
                    trigger_fsm <= IDLE;
            end case;
        end if;
    end process;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    
end Behavioral;
--==================================================================================================
--==================================================================================================
