--==================================================================================================
-- Company      : NCSR Demokritos 
-- Engineer     : Yiannis Kazas
-- Create Date  : 16/11/2023 06:40:24 PM
-- Module Name  : ADC_Interface - Behavioral
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

entity ADC_Interface is
    port (
        Rst_i        : IN  std_logic; 
        Clk_i        : IN  std_logic;
        ADC_en_i     : IN  std_logic;
        ADC_SDO_i    : IN  std_logic;
        ADC_CONV_o   : OUT std_logic;
        ADC_CS_o     : OUT std_logic;
        ADC_SCLK_o   : OUT std_logic;
        ADC_DATA_o   : OUT std_logic_vector(11 downto 0);
        ADC_busy_o   : OUT std_logic;
        Clr_Hit_flag_i : IN  std_logic;
        Hit_flag_o     : OUT std_logic
    );
end ADC_Interface;

--==================================================================================================

architecture architecture_ADC_Interface of ADC_Interface is

--==================================================================================================
    -- Start of Signal Declaration
--==================================================================================================

    type state_type is (ADC_IDLE,ADC_RST,ADC_SAMPLING);
    signal ADC_state   : state_type;
    signal ADC_sclk_en : std_logic:= '0';
    signal ADC_cntr    : integer range 0 to 90 := 0;
    signal ADC_sreg    : std_logic_vector(11 downto 0):= (others=> '0');
    signal hit_flag    : std_logic := '0';
    
--==================================================================================================
    -- END of Signal Declaration
--==================================================================================================


begin

--==================================================================================================
    -- Start of Main Body
--==================================================================================================

    ADC_SCLK_o <= not Clk_i and ADC_sclk_en;
    Hit_flag_o <= hit_flag;
    
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- ADC Sequence
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    process(Clk_i)
    begin
        if rising_edge(Clk_i) then
        
            case ADC_state is
                when ADC_IDLE =>
                    ADC_busy_o   <= '0';
                    ADC_CONV_o   <= '1';
                    ADC_CS_o     <= '1';
                    ADC_Sclk_En  <= '0';
                    ADC_cntr     <= 0;
                    
                    if (Clr_Hit_flag_i = '1') then
                        Hit_flag <= '0';
                    else
                        Hit_flag <= Hit_flag;
                    end if;
                    
                    if (Rst_i = '1') then 
                        ADC_state <= ADC_RST;      -- ADC software reset
                    elsif (ADC_en_i = '1') then
                        ADC_state <= ADC_SAMPLING; -- First Integration Acquisition
                    else
                        ADC_state <= ADC_IDLE;
                    end if;
                    
                when ADC_RST =>
                    ADC_busy_o <= '1';
                    ADC_cntr   <= ADC_cntr +1;
                    ADC_DATA_o <= (others=> '0');
                    ADC_sreg   <= (others=> '0');
                    Hit_flag   <= '0';
                    
                    if (ADC_cntr =  82) then
                        ADC_state <= ADC_IDLE;
                    else
                        ADC_state <= ADC_RST;
                    end if;
                    
                    case ADC_cntr is
                        when 0 to 20 =>
                            ADC_CONV_o  <= '0';
                            ADC_CS_o    <= '1';
                            ADC_Sclk_en <= '0'; 
                        when 21 =>
                            ADC_CONV_o  <= '1';
                            ADC_CS_o    <= '1';
                            ADC_Sclk_en <= '0'; 
                        when 32 =>
                            ADC_CONV_o  <= '1';
                            ADC_CS_o    <= '0';
                            ADC_Sclk_en <= '0'; 
                        when 33 to 40 =>
                            ADC_CONV_o  <= '1';
                            ADC_CS_o    <= '0';
                            ADC_Sclk_en <= '1'; 
                        when 41 =>
                            ADC_CONV_o  <= '1';
                            ADC_CS_o    <= '1';
                            ADC_Sclk_en <= '0';
                        when 50 to 69 =>
                            ADC_CONV_o  <= '0';
                            ADC_CS_o    <= '1';
                            ADC_Sclk_en <= '0'; 
                        when 70 =>
                            ADC_CONV_o  <= '1';
                            ADC_CS_o    <= '1';
                            ADC_Sclk_en <= '0'; 
                        when others =>
                            ADC_CONV_o  <= '1';
                            ADC_CS_o    <= '1';
                            ADC_Sclk_en <= '0';
                        end case;
                        
                    
                when ADC_SAMPLING => 
                    ADC_busy_o <= '1';
                    ADC_cntr   <= ADC_cntr + 1;
                    if (ADC_cntr = 46) then
                        ADC_state <= ADC_IDLE;
                    else 
                        ADC_state <= ADC_SAMPLING;
                    end if;
                    
                    case ADC_cntr is 
                        when 0 to 20 =>       -- pull ADC_CONV_o low to start conversion
                            ADC_CONV_o  <= '0';
                            ADC_CS_o    <= '1';
                            ADC_Sclk_en <= '0';
                        when 21 =>            -- pull ADC_CONV_o high before end of conversion for normal operation
                            ADC_CONV_o  <= '1';
                            ADC_CS_o    <= '1';
                            ADC_Sclk_en <= '0'; 
                        when 32 =>            -- pull ADC_CS_o low at end of conversion to transfer data
                            ADC_CONV_o  <= '1';
                            ADC_CS_o    <= '0';
                            ADC_Sclk_en <= '1'; 
                        when 33 to 44 =>      -- send ADC_SCLK_o and receive data for the next 12 clk_cycles
                            ADC_CONV_o  <= '1';
                            ADC_CS_o    <= '0';
                            ADC_Sclk_en <= '1'; 
                            ADC_sreg    <= ADC_sreg (10 downto 0) & ADC_SDO_i; 
                        when 45 =>            -- End of ADC operation
                            hit_flag    <= '1';
                            ADC_CONV_o  <= '1';
                            ADC_CS_o    <= '1';
                            ADC_Sclk_en <= '0'; 
                            ADC_DATA_o  <= ADC_sreg;
                            ADC_sreg    <= (others=>'0');
                        when others =>
                            null;
                    end case;
            end case;
        end if;
    end process;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
        
        end architecture_ADC_Interface;
