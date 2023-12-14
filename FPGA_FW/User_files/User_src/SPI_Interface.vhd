--================================================================================================
-- Company      : NCSR Demokritos
-- Engineer     : Yiannis Kazas
-- Create Date  : 17/03/2023 01:30:47 PM
-- Module Name  : SPI_Interface - Behavioral
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Description  : 
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Last Changes : 16-Nov-2023
--==================================================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.user_package.all;

--==================================================================================================
entity SPI_Interface is
port (
    -- Clocks & Resets --
    Clk_spi_i          : in  std_logic;
    Reset_i            : in  std_logic;
    -- Spi control signals --
    SPI_rd_en_i        : in  std_logic;
    SPI_wr_en_i        : in  std_logic;
    SPI_rd_addr_i      : in  std_logic_vector(3 downto 0);
    -- SPI data --
    SPI_tx_reg_array_i : in  std_logic_vector(SPI_TX_REG_ARRAY_VECTOR-1 downto 0);
    SPI_rx_reg_array_o : out std_logic_vector(SPI_RX_REG_ARRAY_VECTOR-1 downto 0);
    -- SPI signals --
    SPI_MISO_i    : in  std_logic;
    SPI_CS_o      : out std_logic;
    SPI_SCK_o     : out std_logic;
    SPI_MOSI_o    : out std_logic
);
end SPI_Interface;
--==================================================================================================

architecture Behavioral of SPI_Interface is

--==================================================================================================
    -- Start of Signal Declaration
--==================================================================================================
    type spi_state_type is (IDLE, SEND_REG_ADDRESS, SPI_READ, SPI_WRITE);
    signal SPI_state : spi_state_type:= IDLE;
    
    signal spi_sck_en       : std_logic:='0';
    signal transaction_mode : std_logic:='0';
    signal spi_data_valid   : std_logic:='0';
    signal spi_addr         : std_logic_vector(3 downto 0);
    signal spi_dout         : std_logic_vector(SPI_RX_REG_ARRAY_VECTOR-1 downto 0):=(others=>'0');
    signal spi_counter      : integer range 0 to SPI_TX_REG_ARRAY_VECTOR:=0;
    signal spi_words        : integer range 0 to WORDS_TO_READ :=0;
    
    signal spi_wr_en_synced : std_logic:='0';
    signal spi_wr_req       : std_logic:='0';
    signal spi_wr_done      : std_logic:='0';
    signal spi_rd_en_synced : std_logic:='0';
    
    -- debug signals
    signal state : std_logic_vector(3 downto 0);
    signal spi_cs : std_logic;
    signal spi_mosi : std_logic;
--==================================================================================================
    -- END of Signal Declaration
--==================================================================================================


    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPONENT SPI_DEBUG
    PORT (
        clk : IN STD_LOGIC;
        probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe2 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
        probe3 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe6 : IN STD_LOGIC_VECTOR(3 DOWNTO 0); 
        probe7 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe8 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe9 : IN STD_LOGIC_VECTOR(16 DOWNTO 0)
    );
    END COMPONENT  ;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


begin

    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

--    DEBUG_SPI : SPI_DEBUG
--    PORT MAP (
--        clk => clk_spi_i,
--        probe0(0) => Reset_i, 
--        probe1(0) => spi_wr_en_i, 
--        probe2    => spi_tx_reg_array_i, 
--        probe3(0) => spi_cs, 
--        probe4(0) => spi_sck_en, 
--        probe5(0) => spi_mosi, 
--        probe6    => state, 
--        probe7(0) => spi_wr_req, 
--        probe8(0) => spi_wr_en_synced,
--        probe9    => std_logic_vector(to_unsigned(spi_counter,17))
--    );
    

--==================================================================================================
    -- Start of Main Body
--==================================================================================================

    SPI_SCK_o <= (not Clk_spi_i) when (spi_sck_en = '1') else '0';
    SPI_CS_o  <= spi_cs;
    SPI_MOSI_o <= spi_mosi;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CDC_spi_wr: entity work.CDC_sync 
        port map (
        Reset_i  => reset_i,
        Clk_i    => Clk_spi_i,
        data_in  => Spi_wr_en_i,
        data_out => spi_wr_req
      );    
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CDC_spi_rd: entity work.CDC_sync 
        port map (
        Reset_i  => reset_i,
        Clk_i    => Clk_spi_i,
        data_in  => Spi_rd_en_i,
        data_out => spi_rd_en_synced
      );    
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- Configure Output Data register --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    process(Reset_i, Clk_spi_i)
    begin
        if (Reset_i = '1') then
            SPI_rx_reg_array_o <= (others=>'0');
        else
            if rising_edge(Clk_spi_i) then
                if (spi_data_valid = '1') then
                    SPI_rx_reg_array_o <= spi_dout;
                end if;
            end if;
        end if;
    end process;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- Configure SPI write-enable requests --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    process(Reset_i, Clk_Spi_i)
    begin
        if (reset_i = '1') then
            spi_wr_en_synced <= '0';
        elsif rising_edge(clk_spi_i) then
            if (spi_wr_req = '1') then
                spi_wr_en_synced <= '1';
            elsif (spi_wr_done = '1') then
                spi_wr_en_synced <= '0';
            else
                spi_wr_en_synced <= spi_wr_en_synced;
            end if;
        end if;
    end process;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- SPI master FSM --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    process(Reset_i, Clk_spi_i)
    begin
        if (Reset_i = '1') then
            SPI_state      <= IDLE;
            spi_dout       <= (others=>'0');
            spi_data_valid <= '0';
        else
            if rising_edge(Clk_spi_i) then
                case SPI_state is
                    -----------------
                    -- IDLE State --
                    -----------------
                    when IDLE =>
                    state <= x"0";
                        spi_sck_en <= '0';
                        spi_mosi <= '0';
                        spi_cs   <= '1';
                        spi_data_valid  <= spi_data_valid;
                        spi_counter     <= 0;
                        spi_words       <= 0;
                        spi_wr_done     <= '0';
                        --spi_dout       <= (others=>'0');
                        if (spi_rd_en_synced = '1') then
                            SPI_state        <= SEND_REG_ADDRESS;
                            spi_addr         <= SPI_rd_addr_i;
                            transaction_mode <= '1';
                        elsif (spi_wr_req = '1') then
                            SPI_state <= SPI_WRITE;
--                        elsif (SPI_wr_en_synced = '1') then
--                            SPI_state        <= SEND_REG_ADDRESS;
--                            transaction_mode <= '0';
                        else
                            SPI_state <= IDLE;
                            spi_addr  <= (others=>'0');
                        end if;
                        
                    ----------------------------
                    -- Send Register Address --
                    ----------------------------
                    when SEND_REG_ADDRESS =>
                    state <= x"1";
                        spi_counter <= spi_counter + 1;
                        case spi_counter is
                            when 0 =>                       -- Deassert cs
                                spi_cs   <= '1';
                                spi_sck_en <= '0';
                                spi_mosi <= '0';
                            when 1 to 4 =>                  -- Start sck and send register address
                                spi_cs   <= '0';
                                spi_sck_en <= '1';
                                spi_mosi <= spi_addr(4 - spi_counter);
                            when 5  =>                      -- Set bit to specify Rd/Wr transaction
                                spi_cs   <= '0';
                                spi_sck_en      <= '1';
                                spi_mosi <= transaction_mode; -- '1'=Read, '0'=Write
                                spi_counter     <= 0;
                                if (transaction_mode = '1') then
                                    SPI_state   <= SPI_READ;
                                else
                                    SPI_state   <= SPI_WRITE;
                                end if;
                            when others =>
                                SPI_state <= IDLE;
                        end case;
                        
                    ----------------------------
                    -- SPI Read --
                    ----------------------------
                    when SPI_READ =>
                    state <= x"2";
                        spi_counter <= spi_counter + 1;
                        case spi_counter is
                            when 0 to (SPI_WORD_WIDTH-2)  =>  -- Store Read Data
                                spi_data_valid  <= '0';
                                spi_cs   <= '0';
                                spi_sck_en      <= '1';
                                spi_mosi <= '0';
                                spi_dout        <= spi_dout(SPI_RX_REG_ARRAY_VECTOR-2 downto 0) & SPI_MISO_i;
                            when SPI_WORD_WIDTH-1 =>    
                                spi_data_valid  <= '1';
                                spi_cs   <= '0';
                                spi_sck_en      <= '1';
                                spi_mosi <= '0';
                                spi_dout        <= spi_dout(SPI_RX_REG_ARRAY_VECTOR-2 downto 0) & SPI_MISO_i;
                                spi_words       <= spi_words +1;
                                -- Read transaction in bursts specified by the "WORDS_TO_READ" constant
                                if (spi_words >= WORDS_TO_READ) then
                                    spi_counter <= SPI_WORD_WIDTH;
                                else
                                    spi_counter <= 0;
                                end if;
                            when SPI_WORD_WIDTH =>
                                spi_cs   <= '0';
                                spi_sck_en      <= '0';
                                spi_mosi <= '0';
                                spi_dout        <= spi_dout(SPI_RX_REG_ARRAY_VECTOR-2 downto 0) & SPI_MISO_i;
                                spi_counter     <= 0;
                                SPI_state       <= IDLE;
                            when others =>
                                SPI_state <= IDLE;
                        end case;
                        
                    ----------------------------
                    -- SPI Write --
                    ----------------------------
                    when SPI_WRITE =>
                    state <= x"3";
                        spi_counter <= spi_counter +1;
                        case spi_counter is
                            -- Send serially all data in the SPI_TX_reg_array_i
                            when 0 to (SPI_WORD_WIDTH-2) =>
                                spi_cs     <= '0';
                                spi_sck_en <= '1';
                                spi_mosi   <= SPI_tx_reg_array_i((SPI_TX_REG_ARRAY_VECTOR-1) - (spi_counter));
                                SPI_state  <= SPI_WRITE;
                            when SPI_WORD_WIDTH-1 =>    
                                spi_cs   <= '0';
                                spi_sck_en <= '1';
                                spi_mosi <= SPI_tx_reg_array_i((SPI_TX_REG_ARRAY_VECTOR-1) - (spi_counter));
                                SPI_state       <= SPI_WRITE;
                                spi_wr_done <= '1';
                            when SPI_WORD_WIDTH =>
                                spi_cs    <= '0';
                                spi_sck_en  <= '0';
                                spi_mosi  <= SPI_tx_reg_array_i(0);--'0';
                                spi_counter <= 0;
                                SPI_state   <= IDLE;
                                
                            when others =>
                                SPI_state <= IDLE;
                        end case;
                    ----------------------------
                    when others =>
                        SPI_state <= IDLE;
                end case;
            end if;
        end if;
    end process;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

--==================================================================================================
--==================================================================================================

end behavioral;
