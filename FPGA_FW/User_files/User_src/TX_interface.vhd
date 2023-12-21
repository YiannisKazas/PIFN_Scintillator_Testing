--==================================================================================================
-- Company      : NCSR Demokritos
-- Engineer     : Yiannis Kazas
-- Create Date  : 11/18/2023 08:50:49 PM
-- Module Name  : TX_interface - Behavioral
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Description  : 
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Last Changes : 22-Nov-2023
--==================================================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.user_package.all;
library UNISIM;
use UNISIM.VComponents.all;
use IEEE.std_logic_misc.all;

--==================================================================================================

entity TX_Interface is
    port (
        Clk_i          : IN std_logic;
        Reset_i        : IN std_logic;
        DAQ_En_i       : IN std_logic;    
        Debug_en_i     : IN std_logic;                
        FIFO_wr_en_o   : OUT  std_logic;                   
        FIFO_din_o     : OUT std_logic_vector(15 downto 0); 
        Status_fifo_full_i : IN std_logic;
        ADC_data_i     : IN  adc_data_type;
        Hit_flag_i     : IN  std_logic_vector(NUM_CHANNELS-1 downto 0);
        Clr_hit_flag_o : OUT std_logic;
        Rst_BRAM_i     : in std_logic;      
        BRAM_rd_addr_i : in std_logic_vector(11 downto 0);  
        BRAM_rd_dout_o : out std_logic_vector(15 downto 0);
        Error_o        : OUT std_logic_vector(NUM_CHANNELS-1 downto 0)
    );
end TX_Interface;

--==================================================================================================

architecture Behavioral of TX_Interface is

--==================================================================================================
    -- Start of Component Declaration --
--==================================================================================================
    COMPONENT BRAM_16x4096
      PORT (
        clka : IN STD_LOGIC;
        wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        addra : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
        dina : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        douta : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
      );
    END COMPONENT;
    --==================================================================================================
    -- END of Component Declaration --
--==================================================================================================

--==================================================================================================
    -- Start of Signal Declaration --
--==================================================================================================

    signal TX_cntr     : integer range 0 to 15 := 0 ; -- Counter controlling transfer sequence
--    signal TX_cntr_rst : std_logic:= '1';
    signal TX_data     : adc_data_type :=(others=> (others =>'0'));
    
    signal hit_flag_prev : std_logic_vector(NUM_CHANNELS-1 downto 0);
    signal hit_flag_edge : std_logic_vector(NUM_CHANNELS-1 downto 0);
    
    signal debug_en : std_logic;
    signal latch_debug_data : std_logic;
    signal debug_data       : adc_data_type := (others => (others => '0')); 
    signal debug_cntr : integer range 0 to 1023 := 0;
    signal wait_cntr  : integer range 0 to 1023 := 0;
--    type state_type is (IDLE,LATCH_DATA, INCREASE_DATA,WAIT_TX_DONE, WAIT_STATE);
--    signal fsm_state : state_type; 
    signal tx_done : std_logic := '0';
    signal state : std_logic_vector(3 downto 0);
    -- BRAM memory signals
    signal bram_wr_en    : std_logic := '0';
    signal bram_addr     : std_logic_vector(11 downto 0) := (others => '0');
    signal bram_addr_int : std_logic_vector(11 downto 0) := (others => '0');
    signal bram_wr_din   : std_logic_vector(15 downto 0) := (others => '0');
    signal bram_rd_dout  : std_logic_vector(15 downto 0) := (others => '0');
    signal bram_tmp_data : unsigned(15 downto 0) := (others => '0');
    signal bram_addr_ext_en : std_logic;
    signal bram_cntr : natural range 0 to 15 :=0;
    
    type bram_state_type is (IDLE, STORE_DATA, RST_RAM);
    signal fsm_state : bram_state_type;
    
    signal clr_hit_flag : std_logic;
    signal fifo_wr_en   : std_logic;
    signal fifo_din     : std_logic_vector(15 downto 0);
        
--==================================================================================================
    -- END of Signal Declaration --
--==================================================================================================

    COMPONENT TX_INTERFACE_DEBUG
    PORT (
        clk : IN STD_LOGIC;
        probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe3 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe5 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
        probe6 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
        probe7 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
        probe8 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        probe9 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        probe10 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
    );
    END COMPONENT  ;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

begin

    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    DEBUG_TX_INTERFACE : TX_INTERFACE_DEBUG
    PORT MAP (
    	clk => clk_i,
    	probe0(0) => daq_en_i, 
    	probe1(0) => hit_flag_edge(0), 
    	probe2(0) => hit_flag_i(0), 
    	probe3(0) => Clr_hit_flag, 
    	probe4(0) => FIFO_wr_en, 
    	probe5 => FIFO_din, 
    	probe6 => tx_data(0), 
    	probe7 => tx_data(1), 
    	probe8 => std_logic_vector(to_unsigned(tx_cntr,4)), 
    	probe9 => state,
    	probe10(0) => Status_fifo_full_i
    );
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- END OF DEBUG CORE --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
--==================================================================================================
    -- START OF MAIN BODY --
--==================================================================================================
    state <= x"1" when fsm_state = STORE_DATA else x"0";
    
    Clr_hit_flag_o <= clr_hit_flag;
    fifo_wr_en_o   <= fifo_wr_en;
    fifo_din_o     <= fifo_din;
--    state <= x"1" when fsm_state = LATCH_DATA else x"2" when fsm_state = INCREASE_DATA else x"3" when fsm_state = WAIT_TX_DONE else x"4" when fsm_state= WAIT_STATE else x"0";
    
--    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--        -- BRAM for histogram data --
--    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--    BRAM_mem : BRAM_16x4096
--      PORT MAP (
--        clka => clk_i,
--        wea(0) => bram_wr_en,
--        addra  => bram_addr,
--        dina   => bram_wr_din,
--        douta  => bram_rd_dout
--        );  
--    bram_addr      <= BRAM_rd_addr_i when bram_addr_ext_en = '1' else bram_addr_int; 
--    BRAM_rd_dout_o <= bram_rd_dout;
--    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- ADC Data buffering --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Find rising edge of hit flag signal
    process(Reset_i, Clk_i)
    begin
        if (Reset_i = '1') then
            hit_flag_prev <= (others => '0');
            hit_flag_edge <= (others => '0');
        elsif rising_edge(clk_i) then
            for CH in NUM_CHANNELS-1 downto 0 loop
                hit_flag_prev(CH) <= Hit_flag_i(CH);
                if (Hit_flag_i(CH) = '1' and hit_flag_prev(CH) = '0') then
                    hit_flag_edge(CH) <= '1';
                else
                    hit_flag_edge(CH) <= '0';
                end if;
            end loop;
        end if;
    end process;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Rising edge of hit flag signal is used to latch adc data
    process(Clk_i)
    begin
        if rising_edge(Clk_i) then
            if (Reset_i = '1') then
                TX_data <= (others => (others => '0'));
            else
                for CH in NUM_CHANNELS-1 downto 0 loop
                    if (hit_flag_edge(CH) = '1') then
                        TX_data(CH) <= ADC_data_i(CH);
                    elsif (latch_debug_data = '1') then
                        TX_data(CH) <= debug_data(CH);
                    end if;
                end loop;
            end if;
        end if;
    end process;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- FIFO-based TX sequence --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    process(Reset_i, Clk_i)
    begin
        if (Reset_i = '1') then
            fsm_state <= IDLE;
        elsif rising_edge(Clk_i) then
            case fsm_state is
                ----------------
                -- IDLE STATE --
                ----------------
                when IDLE =>
                    TX_cntr        <= 0;
                    clr_hit_flag <= '0';
                    FIFO_wr_en   <= '0';
                    FIFO_din     <= (others => '0');
                    if (hit_flag_edge(0) = '1') and (DAQ_en_i = '1') then --and (Status_fifo_full_i = '0') then
                        fsm_state  <= STORE_DATA;
                    end if;
                    
                ----------------
                -- STORE DATA --
                ----------------
                when STORE_DATA =>
                    TX_cntr <= TX_cntr +1;
                    case TX_cntr is
                        when 0 => 
                            tx_done <= '0'; 
                            clr_hit_flag <= '0';
                            FIFO_wr_en   <= '0';
                            FIFO_din     <= (others => '0');
                        when 1 =>
                            FIFO_wr_en <= '0';
                            FIFO_din   <= x"FFFF";--TX_data(0);
                        when 2 =>
                            FIFO_wr_en <= '1';
                            FIFO_din   <= x"FFFF";--TX_data(0);
                        when 3 => 
                            FIFO_wr_en <= '0';
                            FIFO_din   <= TX_data(0);
                        when 4 => 
                            FIFO_wr_en <= '1';
                            FIFO_din   <= TX_data(0);
                        when 5 => 
                            FIFO_wr_en <= '0';
                            FIFO_din   <= TX_data(1);
                        when 6 => 
                            FIFO_wr_en <= '1';
                            FIFO_din   <= TX_data(1);
                        when 7 => 
                            FIFO_wr_en <= '0';
                            FIFO_din   <= TX_data(2);
                        when 8 => 
                            FIFO_wr_en <= '1';
                            FIFO_din   <= TX_data(2);
                        when 9 => 
                            FIFO_wr_en <= '0';
                            FIFO_din   <= TX_data(3);
                        when 10 => 
                            FIFO_wr_en <= '1';
                            FIFO_din   <= TX_data(3);
                        when 11 => 
                            FIFO_wr_en <= '0';
                            FIFO_din   <= TX_data(4);
                        when 12 => 
                            FIFO_wr_en <= '1';
                            FIFO_din   <= TX_data(4);
                        when 13 => 
                            FIFO_wr_en <= '0';
                            FIFO_din   <= TX_data(5);
                        when 14 => 
                            clr_hit_flag <= '1';
                            FIFO_wr_en   <= '1';
                            FIFO_din     <= TX_data(5);
                        when 15 =>
                            clr_hit_flag <= '0';
                            FIFO_wr_en   <= '0';
                            FIFO_din     <= (others => '0');
                            fsm_state      <= IDLE;
                        when others =>
                            clr_hit_flag <= '0';
                            FIFO_wr_en   <= '0';
                            FIFO_din     <= (others => '0');
                    end case;
                                
                when others => 
                    fsm_state <= IDLE;
            end case;
        end if;
    end process;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
            

--    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--        -- Counter that Control TX Sequence --
--    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--    process(Clk_i)
--    begin
--        if rising_edge(Clk_i) then
--            if (Reset_i = '1') then
--                TX_cntr <= 0;
--                Error_o <= (others => '0');
                
--            elsif (DAQ_en_i = '1') and (Status_fifo_full_i = '0') then               -- If DAQ is in Run State
--                if (TX_cntr = 15) then                     -- Reset Counter after 15 clk cycles
--                    TX_cntr <= 0;  
--                elsif (Hit_flag_i(0) = '1') then --(or_reduce(Hit_flag_i) = '1') then   -- Increase counter if Hit flag is asserted
--                    TX_cntr <= TX_cntr +1;
                    
--                    if (and_reduce(Hit_flag_i) = '0') then      -- Raise error flag if hit flag is no asserted for all channels
--                        Error_o <= Hit_flag_i;
--                     else
--                        Error_o <= (others =>'0');
--                    end if;      
                                  
--                end if;   
                 
--            elsif debug_en = '1' then
--                if TX_cntr = 9 then
--                    TX_cntr <= 0;
--                else
--                    TX_cntr <= TX_cntr +1;
--                end if;
                        
--            else                                      -- Reset if DAQ is not in Run State 
--                TX_cntr <= 0;
--                Error_o <= (others => '0');
--            end if;
--        end if;
--    end process;
--    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


--    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--        -- Process for TX Sequence --
--    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--    process(TX_cntr, TX_data)
--    begin
--        case TX_cntr is
--            when 0 => 
--                tx_done <= '0'; 
--                clr_hit_flag <= '0';
--                FIFO_wr_en   <= '0';
--                FIFO_din     <= (others => '0');
--            when 1 =>
--                FIFO_wr_en <= '0';
--                FIFO_din   <= x"FFFF";--TX_data(0);
--            when 2 =>
--                FIFO_wr_en <= '1';
--                FIFO_din   <= x"FFFF";--TX_data(0);
--            when 3 => 
--                FIFO_wr_en <= '0';
--                FIFO_din   <= TX_data(0);
--            when 4 => 
--                FIFO_wr_en <= '1';
--                FIFO_din   <= TX_data(0);
--            when 5 => 
--                FIFO_wr_en <= '0';
--                FIFO_din   <= TX_data(1);
--            when 6 => 
--                FIFO_wr_en <= '1';
--                FIFO_din   <= TX_data(1);
--            when 7 => 
--                FIFO_wr_en <= '0';
--                FIFO_din   <= TX_data(2);
--            when 8 => 
--                FIFO_wr_en <= '1';
--                FIFO_din   <= TX_data(2);
--            when 9 => 
--                FIFO_wr_en <= '0';
--                FIFO_din   <= TX_data(3);
--            when 10 => 
--                FIFO_wr_en <= '1';
--                FIFO_din   <= TX_data(3);
--            when 11 => 
--                FIFO_wr_en <= '0';
--                FIFO_din   <= TX_data(4);
--            when 12 => 
--                FIFO_wr_en <= '1';
--                FIFO_din   <= TX_data(4);
--            when 13 => 
--                FIFO_wr_en <= '0';
--                FIFO_din   <= TX_data(5);
--            when 14 => 
--                clr_hit_flag <= '1';
--                FIFO_wr_en   <= '1';
--                FIFO_din     <= TX_data(5);
--            when 15 =>
--                tx_done <= '1';
--                clr_hit_flag <= '0';
--                FIFO_wr_en   <= '0';
--                FIFO_din     <= (others => '0');
--            when others =>
--                clr_hit_flag <= '0';
--                FIFO_wr_en   <= '0';
--                FIFO_din     <= (others => '0');
--        end case;
--    end process;
--    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


--    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--        -- BRAM-based histogram --
--    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--    process(Reset_i, Clk_i)
--    begin
--        if (Reset_i = '1') then
--            bram_state <= IDLE;
--        elsif rising_edge(Clk_i) then
--            case bram_state is
--                ----------------
--                -- IDLE STATE --
--                ----------------
--                when IDLE =>
--                    bram_cntr        <= 0;
--                    bram_wr_en       <= '0';
--                    bram_addr_ext_en <= '1';
--                    bram_addr_int    <= (others => '0');
--                    if (hit_flag_edge(0) = '1') then
--                        bram_addr_int     <= TX_data(0)(11 downto 0);
--                        bram_addr_ext_en <= '0';
--                        bram_state       <= STORE_DATA;
--                    elsif (Rst_bram_i = '1') then
--                        bram_addr_ext_en <= '0';
--                        bram_state       <= RST_RAM;
--                    end if;
                    
--                ----------------
--                -- STORE DATA --
--                ----------------
--                when STORE_DATA =>
--                    bram_addr_int <= TX_data(0)(11 downto 0);
--                    case bram_cntr is 
--                        when 0 => -- delay 
--                            bram_cntr <= 1;
--                        when 1 => -- delay
--                            bram_cntr <= 2; 
--                        when 2 =>  -- read data from bram
--                            bram_cntr     <= 3;
--                            bram_tmp_data <= unsigned(bram_rd_dout);
--                        when 3 => -- increase bram_cntr value of bram data
--                            bram_cntr     <= 4;
--                            bram_tmp_data <= bram_tmp_data +1;
--                        when 4 => -- delay
--                            bram_cntr <= 5;
--                        when 5 => -- assign new value to bram_din
--                            bram_cntr     <= 6;
--                            bram_wr_din   <= std_logic_vector(bram_tmp_data);
--                        when 6 => 
--                            bram_wr_en <= '1';
--                            bram_cntr  <= 7;
--                        when 7 =>
--                            bram_wr_en <= '0';
--                            bram_state <= IDLE;
--                        when others => 
--                            bram_cntr <= 0;
--                            bram_state <= IDLE;
--                    end case;
                    
--                ---------------
--                -- RESET RAM --
--                ---------------
--                when RST_RAM => 
--                    bram_wr_din <= (others=>'0');
--                    if (bram_addr_int < x"FFF") then
--                        bram_addr_int <= std_logic_vector(unsigned(bram_addr_int) + 1);
--                    else
--                        bram_state <= IDLE;
--                    end if;
                    
--                when others => 
--                    bram_state <= IDLE;
--            end case;
--        end if;
--    end process;
--    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    
    
    
--    process(Reset_i,Clk_i)
--    begin
--        if (Reset_i = '1') then
--            fsm_state <= IDLE;
--        elsif rising_edge(clk_i) then
--            case fsm_state is
            
--                when IDLE =>
--                    wait_cntr <= 0;
--                    debug_cntr <= 0;
--                    debug_data(0) <= x"0001";
--                    debug_data(1) <= x"0002";
--                    debug_data(2) <= x"0003";
--                    debug_data(3) <= x"0004";
--                    latch_debug_data <= '0';
--                    debug_en <= '0';
--                    if (Debug_en_i = '1') then
--                        fsm_state <= LATCH_DATA;
----                        debug_en <= '1';
--                    end if;
--                when LATCH_DATA =>
--                    wait_cntr <= 0;
--                    debug_en <= '1';
--                    latch_debug_data <= '1';
--                    if (debug_cntr >= 1023) then
--                        fsm_state <= IDLE;
--                    else
--                        fsm_state <= INCREASE_DATA;
--                    end if;
                    
--                when INCREASE_DATA =>
--                    debug_cntr <= debug_cntr +1;
--                    Latch_debug_data <= '0';
--                    debug_data(0) <= std_logic_vector(unsigned(debug_data(0)) + 4);
--                    debug_data(1) <= std_logic_vector(unsigned(debug_data(1)) + 4);
--                    debug_data(2) <= std_logic_vector(unsigned(debug_data(2)) + 4);
--                    debug_data(3) <= std_logic_vector(unsigned(debug_data(3)) + 4);
--                    fsm_state <= WAIT_TX_DONE;
                
--                when WAIT_TX_DONE =>    
--                    if (tx_done = '1') then
--                        debug_en <= '0';
--                        fsm_state <= WAIT_STATE;
--                    end if;
                
--                when WAIT_STATE =>
--                    wait_cntr <= wait_cntr +1;
--                    if (wait_cntr >= 499) then
--                        fsm_state <= LATCH_DATA;
--                    end if;
--                when others =>
--                    fsm_state <= IDLE;
--            end case;
--        end if;
--    end process;                    
            
    
    
    
end Behavioral;
--==================================================================================================
--==================================================================================================