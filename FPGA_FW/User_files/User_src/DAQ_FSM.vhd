--==================================================================================================
-- Company      : NCSR Demokritos
-- Engineer     : Yiannis Kazas
-- Create Date  : 11/18/2023 07:17:47 PM
-- Module Name  : DAQ_FSM - Behavioral
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Description  : 
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Last Changes : 18-Nov-2023
--==================================================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.user_package.all;
library UNISIM;
use UNISIM.VComponents.all;

--==================================================================================================

entity DAQ_FSM is
    port (
        Reset_i           : IN  std_logic;
        Clk_i             : IN  std_logic; 
        Command_id_i      : IN  command_id_type;
        Trigger_i         : IN  std_logic;
        Cnfg_readout_i    : IN cnfg_readout_type;
        Stat_readout_o    : OUT stat_readout_type;
        Status_fifo_full_i : IN std_logic;
        DAQ_En_o          : OUT  std_logic;  
        Integrator_rst_o  : OUT  std_logic;
        ADC_en_o          : OUT  std_logic;
        debug_o           : OUT  std_logic
    );
end DAQ_FSM;

--==================================================================================================

architecture Behavioral of DAQ_FSM is

--==================================================================================================
    -- Start of Signal Declaration --
--==================================================================================================

    type DAQ_state_type is (DAQ_IDLE,INTEGRATION_STATE);
    signal DAQ_state    : DAQ_state_type;
    signal DAQ_cntr     : integer range 0 to 100_000:= 0;
    signal DAQ_rst      : std_logic:= '1'; 
    signal DAQ_en       : std_logic:= '0';
    signal event_rst    : std_logic:= '0'; 
    signal trigger_prev : std_logic:= '0';
    signal integration_duration : integer range 0 to 1023:= 0;
    signal events_recorded      : integer := 0;
    
    signal debug : std_logic;
    signal state : std_logic;
    signal adc_en : std_logic;
    signal daq_en_int : std_logic;
    signal readout_delay : natural range 0 to 100_000 := 200;
    
    signal rst_event_nb : std_logic:='0';
--==================================================================================================
    -- END of Signal Declaration --
--==================================================================================================


    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- START OF DEBUG CORE --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPONENT DAQ_FSM_DEBUG
    PORT (
        clk : IN STD_LOGIC;
        probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe3 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe6 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        probe7 : IN STD_LOGIC_VECTOR(7 DOWNTO 0)
    );
    END COMPONENT  ;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

begin

    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    DEBUG_DAQ_FSM : DAQ_FSM_DEBUG
    PORT MAP (
        clk => clk_i,
        probe0(0) => rst_event_nb, 
        probe1(0) => state, 
        probe2(0) => adc_en,--trigger_i, 
        probe3(0) => Command_id_i.start_rec, 
        probe4(0) => daq_en, 
        probe5(0) => Command_id_i.stop_rec,--trigger_prev, 
        probe6    => std_logic_vector(to_unsigned(events_recorded,8)),
        probe7    => std_logic_vector(to_unsigned(cnfg_readout_i.nb_events_to_record,8))
    );
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
--==================================================================================================
    -- START OF MAIN BODY --
--==================================================================================================
    debug_o <= '0' when (DAQ_state = DAQ_IDLE) else '1';
    
    ADC_en_o <= adc_en;
    DAQ_En_o <= daq_en;
    Stat_readout_o.events_recorded <= std_logic_vector(to_unsigned(events_recorded,24));    
    integration_duration <= to_integer(unsigned(cnfg_readout_i.integr_dur));
    Stat_readout_o.data_rdy <= rst_event_nb;
    
    
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- Enable signal for Data Acquisition Process --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    process(Clk_i, Reset_i)
    begin
        if (Reset_i = '1') then
            daq_en <= '0';
        elsif rising_edge(Clk_i) then
            if (Command_id_i.start_rec = '1') then
                rst_event_nb <= '0';
                daq_en <= '1';
                stat_readout_o.fsm_status <= x"00";
            elsif (Command_id_i.stop_rec = '1') then --or (events_recorded = cnfg_readout_i.nb_events_to_record) then
                rst_event_nb <= '1';
                daq_en <= '0';
                stat_readout_o.fsm_status <= x"FF";
--            else
--                daq_en <= daq_en;
            end if;
        end if;
    end process;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- Integrator Reset --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    process(DAQ_en,Trigger_i,DAQ_rst,event_rst,trigger_prev)
    begin
        if (DAQ_en = '1') then
            Integrator_rst_o <= (DAQ_rst and (Trigger_i or (not trigger_prev))) or (event_rst); -- Trigger_i = active low ('0' when trigger, '1' when idle)
--            debug            <= (DAQ_rst and (Trigger_i or (not trigger_prev))) or (event_rst);
        else
            Integrator_rst_o <= '1';
--            debug            <= '1';
        end if;
    end process;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- Data Acquisition Sequence --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    process(Clk_i)
    begin
        if rising_edge(Clk_i) then
            if (Reset_i = '1') then
                events_recorded <= 0;
                DAQ_state       <= DAQ_IDLE;
            else        
                
                trigger_prev <= Trigger_i or cnfg_readout_i.edge_det_dis;
                case DAQ_state is
                    --------------
                    -- DAQ IDLE --
                    --------------
                    when DAQ_IDLE => 
                    state <= '0';
                    debug <= '0';
                        event_rst <= '0';
                        DAQ_cntr  <= 0;
                        DAQ_rst   <= '1';
                        adc_en    <= '0';
                        readout_delay <= to_integer(unsigned(cnfg_readout_i.delay));
                        -- 
                        if (rst_event_nb = '1') then
                            events_recorded <= 0;
                        end if;
                        -- if Data acquisition is enabled AND trigger comes    
                        if ((DAQ_en = '1') and (Trigger_i = '0') and (trigger_prev = '1')) and (Status_fifo_full_i = '0') then 
                            DAQ_state <= INTEGRATION_STATE;            -- go to integration state 
                        else                                           -- else
                            DAQ_state <= DAQ_IDLE;                     -- remain in idle state
                        end if;
                    -----------------------
                    -- INTEGRATION STATE --
                    -----------------------
                    when INTEGRATION_STATE => 
                    state <= '1';
                        DAQ_cntr <= DAQ_cntr +1;                            -- start DAQ_cntr
                        DAQ_rst  <= '0';                                    -- integrator circuit is in operation (out of Reset_i state)
                        
                        if (DAQ_cntr = integration_duration) then           -- if DAQ_cntr reaches first integration point
                            adc_en <= '1';                                  -- signal ADC to perform first acquisition     
                        else
                            adc_en <= '0';                                  -- Reset_i ADC_en signal
                        end if; 
                        
                        if (DAQ_cntr = integration_duration + 40) then      -- Allow some time for ADC conversion
                            event_rst <= '1';                               -- and then reset integrator
                        end if;
                        
                        if (DAQ_cntr = integration_duration + readout_delay) then --2000)  then --100     -- Allow some time for correct reset of the integrator --previously 50
                            events_recorded <= events_recorded + 1;
                            DAQ_state       <= DAQ_IDLE;                    -- and then return to idle state
                        else
                            DAQ_state <= INTEGRATION_STATE; 
                        end if;
                end case;
            end if;
        end if;
    end process;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
end Behavioral;
--==================================================================================================
--==================================================================================================
    
