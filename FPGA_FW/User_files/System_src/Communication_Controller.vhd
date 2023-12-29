--==================================================================================================
-- Company      : NCSR Demokritos
-- Engineer     : Yiannis Kazas
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Project Name : Generic DAQ for Xilinx-7 series FPGAs
-- Module Name  : Communication_Controller - Behavioral
-- Description  : Communication controller for UART-based transactions with the host PC.
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Last Changes : 24-Nov-2023
--==================================================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.user_package.all;
library UNISIM;
use UNISIM.VComponents.all;

--==================================================================================================

entity Communication_Controller is
    Port (
        -- Clks & Resets --
        Clk_uart_i           : in std_logic;
        Clk_user_i           : in std_logic;
        Reset_i              : in std_logic;
        Reset_fifo_i         : in std_logic;
        Sw_reset_o           : out std_logic;
        -- UART Interface
        UART_rx_data_valid_i : in std_logic;                     -- Valid flag for data received from UART
        UART_rx_data_i       : in std_logic_vector(7 downto 0);  -- Data received from UART
        UART_tx_data_en_o    : out std_logic;                    -- Valid flag for data to be transmitted by UART
        UART_tx_data_o       : out std_logic_vector(7 downto 0); -- Data to be transmittedby UART
        UART_tx_active_i     : in std_logic;
        UART_tx_done_i       : in std_logic;
        -- User Interface --
        TX_data_array_i      : in stdvec8_tx_array;              -- data from user core to host pc
        RX_data_array_o      : out stdvec8_rx_array;             -- data from host pc to user core
        -- Tx_fifo (user data to host pc)
        TX_fifo_wr_en_i      : in std_logic;
        TX_fifo_din_i        : in std_logic_vector(15 downto 0);
        TX_fifo_full_o       : out std_logic;
        TX_fifo_empty_o      : out std_logic;
        -- Rx_fifo (data from host pc to user) 
        RX_fifo_rd_en_i      : in std_logic;
        RX_fifo_dout_o       : out std_logic_vector(7 downto 0);
        RX_fifo_empty_o      : out std_logic;
        -- Cmd fifo 
        Cmd_fifo_rd_en_i     : in std_logic;
        Command_id_o         : out std_logic_vector(5 downto 0);
        Cmd_fifo_empty_o     : out std_logic;
        FIFO_pkt_rdy_o       : out std_logic;
        Cnfg_global_i        : cnfg_global_type;
        
--        Fifo_packet_size_i   : in std_logic_vector(7 downto 0);
        Cmd_strobe_o         : out std_logic
        );       
end Communication_Controller;

--==================================================================================================

architecture Behavioral of Communication_Controller is

--==================================================================================================
    -- Start of Component Declaration --
--==================================================================================================
    -- RX Data FIFO
    COMPONENT FIFO_8x65536
      PORT (
        rst         : IN STD_LOGIC;
        wr_clk      : IN STD_LOGIC;
        rd_clk      : IN STD_LOGIC;
        din         : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        wr_en       : IN STD_LOGIC;
        rd_en       : IN STD_LOGIC;
        dout        : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        full        : OUT STD_LOGIC;
        empty       : OUT STD_LOGIC;
        
        wr_rst_busy : OUT STD_LOGIC;
        rd_rst_busy : OUT STD_LOGIC
      );
    END COMPONENT;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- TX Data FIFO
    COMPONENT FIFO_16to8x131072
      PORT (
        rst         : IN STD_LOGIC;
        wr_clk      : IN STD_LOGIC;
        rd_clk      : IN STD_LOGIC;
        din         : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        wr_en       : IN STD_LOGIC;
        rd_en       : IN STD_LOGIC;
        dout        : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        full        : OUT STD_LOGIC;
        empty       : OUT STD_LOGIC;
        prog_full   : OUT STD_LOGIC;
        wr_rst_busy : OUT STD_LOGIC;
        rd_rst_busy : OUT STD_LOGIC
      );
    END COMPONENT;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Command FIFO
    COMPONENT fifo_6x512
      PORT (
        rst : IN STD_LOGIC;
        wr_clk : IN STD_LOGIC;
        rd_clk : IN STD_LOGIC;
        din : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
        wr_en : IN STD_LOGIC;
        rd_en : IN STD_LOGIC;
        dout : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
        full : OUT STD_LOGIC;
        empty : OUT STD_LOGIC;
        wr_rst_busy : OUT STD_LOGIC;
        rd_rst_busy : OUT STD_LOGIC
      );
    END COMPONENT;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Status FIFO
    COMPONENT FIFO_8x512
      PORT (
        clk : IN STD_LOGIC;
        rst : IN STD_LOGIC;
        din : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        wr_en : IN STD_LOGIC;
        rd_en : IN STD_LOGIC;
        dout : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        full : OUT STD_LOGIC;
        empty : OUT STD_LOGIC
      );
    END COMPONENT;
    
--==================================================================================================
    -- End of Component Declaration --
--==================================================================================================

--==================================================================================================
    -- Start of Signal Declaration --
--==================================================================================================
    -- reset sequence 
    signal controller_rst : std_logic := '1';
    signal general_rst    : std_logic := '1';
    signal reset_cntr     : integer range 0 to 300:= 0;
    
    signal UART_tx_data_en : std_logic;
    signal UART_tx_data    : std_logic_vector(7 downto 0);
    
    -- RX & TX fifos
    signal rx_fifo_wr_en : std_logic;
    signal rx_fifo_full  : std_logic;
    signal tx_fifo_rd_en : std_logic;
    signal tx_fifo_empty : std_logic;
    signal tx_fifo_dout  : std_logic_vector(7 downto 0):= (others=>'0');
    signal tx_fifo_full  : std_logic;
    -- Command fifo
    signal cmd_fifo_wr_en : std_logic := '0';
    signal cmd_fifo_full  : std_logic;
    -- Status fifo
    signal status_fifo_wr_en : std_logic;
    signal status_fifo_rd_en : std_logic;
    signal status_fifo_dout  : std_logic_vector(7 downto 0);
    signal status_fifo_full  : std_logic;
    signal status_fifo_empty : std_logic;
    -- fifo reset signals
    signal fifo_reset         : std_logic;
    signal fifo_rst_cntr      : integer :=0; 
    signal fifo_rst_sync      : std_logic;
    signal fifo_rst_sync_cntr : integer := 0;
    
    -- Controller FSM
    type controller_state_type is (Idle, Receive_nb_of_rd_words, Upload_data, Wait_tx_done, Receive_nb_of_wr_words, Download_data, Read_status);
    signal Controller_state : controller_state_type; 
    signal status_reg       : std_logic_vector(7 downto 0) := (others=>'0');
    signal rd_reg_address   : integer range 0 to (2**(RD_ADDR_WIDTH-1)); -- base address for "Read register" command
    signal wr_reg_address   : integer range 0 to (2**(WR_ADDR_WIDTH-1)); -- base address for "Write register" command
    signal words_to_read    : integer range 0 to (2**(RD_ADDR_WIDTH-1)); -- Nb of words to read
    signal fifo_words_rd    : integer range 0 to 65_535 := 0;            -- Nb of fifo-words already uploaded
    signal fifo_packet_size : integer range 0 to 65_535 := 4096;        -- FIFO dispatch packet size
    signal words_to_write   : integer range 0 to (2**(WR_ADDR_WIDTH-1)); -- Nb of words to write
    signal fifo_mode_en     : std_logic;                                 -- '1' = Read/Write from/to fifo, '0' = Read/Write from/to registers
    signal control_cmd_id   : std_logic_vector(5 downto 0);              -- up to 64 control commands are supported
    signal timeout_cntr     : integer range 0 to 100_000 := 0;
    signal fifo_pkt_size_pre_buf : std_logic_vector(15 downto 0);
--==================================================================================================
    -- End of Signal Declaration
--==================================================================================================

    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- Debugging Core --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPONENT Com_ctrl_debug
    PORT (
        clk : IN STD_LOGIC;
        probe0 : IN STD_LOGIC_VECTOR(2 DOWNTO 0); 
        probe1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe2 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
        probe3 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
        probe4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe5 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
        probe6 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
        probe7 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe8 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe9 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe10 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe11 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe12 : IN STD_LOGIC_VECTOR(11 DOWNTO 0)
    );
    END COMPONENT  ;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    signal state             : std_logic_vector(2 downto 0):="000";
    signal fifo_words_std    : std_logic_vector(15 downto 0):=(others=>'0');
    signal flag : std_logic;
    signal fifo_pkt_rdy : std_logic;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

begin

    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    fifo_words_std <= std_logic_vector(to_unsigned(fifo_words_rd,fifo_words_std'length));
    
    DEBUG_Com_ctrl : Com_ctrl_debug
    PORT MAP (
        clk => clk_uart_i,
        probe0     => state, 
        probe1(0)  => fifo_pkt_rdy,--fifo_rst_sync,--UART_tx_done_i, 
        probe2     => fifo_words_std(7 downto 0),--UART_rx_data_i, 
        probe3     => fifo_words_std(15 downto 8),--UART_tx_data_d, 
        probe4(0)  => fifo_reset,--UART_rx_data_valid_i,
        probe5     => TX_fifo_din_i(7 downto 0),--RX_data_array_d(wr_reg_address),
        probe6     => tx_fifo_dout,--RX_data_array_d(0), 
        probe7(0)  => UART_tx_active_i,--tx_fifo_dout,--RX_data_array_d(1), 
        probe8(0)  => tx_fifo_empty,--RX_data_array_d(2), 
        probe9(0)  => reset_fifo_i,--TX_fifo_din_i(15 downto 8),--std_logic_vector(to_unsigned(wr_reg_address,8)),
        probe10(0) => tx_fifo_wr_en_i,
        probe11(0) => tx_fifo_full,--tx_fifo_rd_en,
        probe12    => std_logic_vector(to_unsigned(fifo_packet_size,12)) 
    );
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- END Debug Core --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

--==================================================================================================
-- Start of Main Body --
--==================================================================================================

--    FIFO_pkt_rdy_o    <= fifo_pkt_rdy;
    UART_tx_data_en_o <= UART_tx_data_en;
    UART_tx_data_o    <= UART_tx_data;
    TX_fifo_empty_o   <= tx_fifo_empty;
    TX_fifo_full_o    <= TX_fifo_full;
    Sw_reset_o        <= controller_rst;
    general_rst       <= Reset_i or controller_rst;
    Rx_fifo_dout_o    <= (others=>'0');
    
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- FIFOs Reset Sequence --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    process(Clk_user_i)
    begin
        if rising_edge(clk_user_i) then
            fifo_rst_sync_cntr <= fifo_rst_sync_cntr +1;
            if (fifo_rst_sync_cntr >= 100) then
                fifo_rst_sync <= '0';
                fifo_rst_sync_cntr <= 0;   
            elsif Reset_fifo_i = '1' then
                fifo_rst_sync    <= '1';
                fifo_rst_sync_cntr <= 0;--fifo_rst_cntr +1;
            end if;
        end if;
    end process;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    fifo_rst: process(clk_uart_i)
    begin
        if rising_edge(clk_uart_i) then
            fifo_rst_cntr <= fifo_rst_cntr +1;
            if (fifo_rst_cntr >= 20) then
                fifo_reset    <= '0';
                fifo_rst_cntr <= 0;   
            elsif (reset_i = '1') or (fifo_rst_sync = '1') then
                fifo_reset    <= '1';
                fifo_rst_cntr <= 0;--fifo_rst_cntr +1;
            end if;
        end if;
    end process;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Reset from uart --
        -- 256 consecutive x"FF" words cause the controller to enter reset state 
    uart_reset : process(Clk_uart_i)
    begin
        if rising_edge(Clk_uart_i) then
            if (reset_cntr > 256) then
                controller_rst <= '1';
                reset_cntr     <= 0;
            else
                controller_rst   <= '0';
                if (UART_rx_data_valid_i = '1') then
                    if (UART_rx_data_i = x"FF") then
                        reset_cntr <= reset_cntr +1;
                    else
                        reset_cntr <= 0;
                    end if;
                end if;
            end if;
        end if;    
    end process; -- uart_reset
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- Set Global Settings of System Core --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    fifo_pkt_size_pre_buf(7 downto 0)  <= TX_data_array_i(2);
    fifo_pkt_size_pre_buf(15 downto 8) <= TX_data_array_i(3);
    
    process(general_rst,Clk_uart_i)
    begin
        if (general_rst = '1') then
            fifo_packet_size <= FIFO_PKT_SIZE;
        elsif rising_edge(Clk_uart_i) then
            if (control_cmd_id = SET_GLB_SETTINGS) then
                fifo_packet_size <= to_integer(unsigned(Cnfg_global_i.fifo_packet_size));
            end if;
        end if;
    end process;
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- Communication Controller FSM --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Three types of Commands are supported
    -- A. Read Register   (Command ID = "00" & Register Address[5:0])
    ----- Following word specifies how many words to be read
    -- B. Write Register  (Command ID = "01" & Register Address[5:0])
    ----- Following word specifies how many words to be written
    -- C. Control Command (Command ID = "10" & Control Command[5:0])
    -- (Write => Download from PC to FPGA / Read =>  Upload from FPGA to PC)
    -- (RX => From host PC to FPGA / TX => From FPGA to host PC)
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    controller_fsm : process(general_rst, Clk_uart_i)
    begin
        if (general_rst = '1') then
            Controller_state  <= Idle;
            Status_reg        <= CONTROLLER_IDLE;
            status_fifo_wr_en <= '1';
            fifo_pkt_rdy      <= '0';
        elsif rising_edge(Clk_uart_i) then
            RX_data_array_o(0) <= status_reg;
            case Controller_state is
                --------------------
                -- Idle state --
                --------------------
                -- wait for "Header" to initiate an action
                when Idle =>
                state <= "000";
                flag <= '0';
                    cmd_fifo_wr_en    <= '0';
                    Cmd_strobe_o      <= '0'; -- Self-reset every clock cycle
                    Status_fifo_wr_en <= '0';
                    UART_tx_data_en   <= '0';
                    fifo_words_rd     <= 0;
                    timeout_cntr      <= 0;
    
                    if (UART_rx_data_valid_i = '1') then
                        Status_fifo_wr_en <= '1';
                        -- Read Command
                        if (UART_rx_data_i(7 downto 6) = "00") then 
                            rd_reg_address   <= to_integer(unsigned(UART_rx_data_i(5 downto 0)));
                            Controller_state <= Receive_nb_of_rd_words;
                            Status_reg       <= WAITING_NB_OF_RD_WORDS; 
                        -- Write Command
                        elsif (UART_rx_data_i(7 downto 6) = "01") then
                            wr_reg_address   <= to_integer(unsigned(UART_rx_data_i(5 downto 0)));
                            Controller_state <= Receive_nb_of_wr_words;
                            Status_reg       <= WAITING_NB_OF_WR_WORDS; 
                        -- Control Command, active for 1 clk cycle only - CDC @ user core
                        elsif (UART_rx_data_i(7 downto 6) = "10") then
                            control_cmd_id   <= UART_rx_data_i(5 downto 0);
                            cmd_fifo_wr_en   <= '1';
                            Cmd_strobe_o     <= '1';
                            Controller_state <= Idle;
                            Status_reg       <= RECEIVED_CONTROL_CMD;
                        -- Read Status Registers    
                        elsif (UART_rx_data_i(7 downto 6) = "11") then
                            Controller_state <= Read_status; 
                            Status_reg       <= STATUS_READ_INITIATED;
                        else
                            Controller_state <= Idle;
                            Status_reg       <= INVALID_HEADER;
                        end if;
                    end if;
                    
                -------------------------------------
                -- Receive "Nb of words to read" byte --
                -------------------------------------
                -- read transaction follows
                when Receive_nb_of_rd_words =>
                state <= "001";
                status_fifo_wr_en <= '0';
                    if (UART_rx_data_valid_i = '1') then
                        words_to_read    <= to_integer(unsigned(UART_rx_data_i(5 downto 0))); -- Nb of words to read from registers or nb of 4096-bit packets to read from fifo
                        fifo_mode_en     <= UART_rx_data_i(6);
                        Controller_state <= Upload_data;
                        Status_reg       <= READ_IN_PROGRESS;
                        status_fifo_wr_en <= '1';
                    end if;
                    
                -------------------------------------
                -- Upload data to PC --
                -------------------------------------
                --  read transaction is initiated
                when Upload_data =>
                state <= "010";
                status_fifo_wr_en <= '0';
                    ---------------------
                    -- Read from fifo --
                    if (fifo_mode_en = '1') then
                        UART_tx_data <= tx_fifo_dout;
                        if (UART_tx_active_i = '0')  then
                            -- if fifo has data /// Wrong --> or readout is completed, send data packet of 4095 bits
                            if (tx_fifo_empty = '0') then --or ((tx_fifo_empty = '1') and (Tx_data_array_i(0) = x"FF")) then
                                UART_tx_data_en   <= '1';
                                tx_fifo_rd_en     <= '1';
                                fifo_words_rd     <= fifo_words_rd + 1;
                                timeout_cntr      <= 0;
                                if (fifo_words_rd < FIFO_PACKET_SIZE) then
                                    UART_tx_data_en   <= '1';
                                    tx_fifo_rd_en     <= '1';
                                    fifo_words_rd     <= fifo_words_rd + 1;
                                    Controller_state  <= Wait_tx_done;
                                    fifo_pkt_rdy      <= '0';

                                else 
                                flag <= '1';                           
                                    tx_fifo_rd_en     <= '0';
                                    UART_tx_data_en   <= '0';
                                    Controller_state  <= Idle;
                                    fifo_pkt_rdy    <= '1';
                                    status_reg        <= READ_COMPLETED;
                                    status_fifo_wr_en <= '1';
                                end if;
                            -- Else, if readout is completed, return to IDLE state 
                            elsif (TX_data_array_i(0) = x"FF") then
                                tx_fifo_rd_en     <= '0';
                                UART_tx_data_en <= '0';
                                Controller_state  <= Idle;
                                status_reg        <= READ_COMPLETED;
                                status_fifo_wr_en <= '1';
                            -- if fifo is empty and readout is not completed, wait for readout data    
                            else
                                UART_tx_data_en <= '0';
                                tx_fifo_rd_en     <= '0';
                                -- Timeout counter otherwise it wil stay here forever
                                if (timeout_cntr >= TIMEOUT) then
                                    Controller_state <= IDLE;
                                else
                                    timeout_cntr <= timeout_cntr + 1;
                                end if;
                            end if;
                        else
                            UART_tx_data_en <= '0';
                            tx_fifo_rd_en     <= '0';
                        end if;
                    ------------------------------
                    -- Read from register-array --  
                    else        
                        UART_tx_data <= TX_data_array_i(rd_reg_address);
                        if (UART_tx_active_i = '0') then
                            if (words_to_read > 0) then
                                rd_reg_address    <= rd_reg_address + 1;
                                words_to_read     <= words_to_read - 1;
                                UART_tx_data_en <= '1';
                                Controller_state  <= Wait_tx_done;--Upload_data; 
                            else
                                UART_tx_data_en <= '0';
                                Controller_state  <= Idle;
                                status_reg        <= READ_COMPLETED;
                                status_fifo_wr_en <= '1';
                            end if;
                        else
                            UART_tx_data_en <= '0';
                        end if;
                    end if;
                    
                -------------------------------------
                -- Wait TX Done --
                -------------------------------------
                when Wait_tx_done =>
                state <= "110";
                    status_fifo_rd_en <= '0';
                    status_fifo_wr_en <= '0';
                    tx_fifo_rd_en     <= '0';
                    UART_tx_data_en <= '0';
                    if (UART_tx_done_i = '1') then
                        Controller_state <= Upload_data;
                    end if;
    
                -------------------------------------
                -- Receive "Nb of words to write" byte --
                -------------------------------------
                -- write transaction follows
                when Receive_nb_of_wr_words =>
                state <= "011";
                status_fifo_wr_en <= '0';
                    if (UART_rx_data_valid_i = '1') then
                        words_to_write   <= to_integer(unsigned(UART_rx_data_i(5 downto 0)));
                        fifo_mode_en     <= UART_rx_data_i(6);
                        Controller_state <= Download_data;
                        Status_reg       <= WRITE_IN_PROGRESS;
                        status_fifo_wr_en <= '1';
                    end if;
                    
                -------------------------------------
                -- Download data to FPGA --
                -------------------------------------
                --write transaction is initiated        
                when Download_data =>
                state <= "100";
                status_fifo_wr_en <= '0';
                    if (UART_rx_data_valid_i = '1') then
                        -- Write to FIFO
                        if (fifo_mode_en = '1') then 
                            rx_fifo_wr_en  <= '1';
                            words_to_write <= words_to_write + 1; --when used in fifo mode, "words_to_write" field must be set to '0' by sw or to specify an offset
                            if (words_to_write = FIFO_PACKET_SIZE) then
                                rx_fifo_wr_en    <= '0';
                                Controller_state <= Idle;
                                Status_reg       <= WRITE_COMPLETED;  
                                status_fifo_wr_en <= '1';
                            end if;            
                        -- Write to register-array
                        else
                            if (words_to_write > 0) then 
                                RX_data_array_o(wr_reg_address) <= UART_rx_data_i;
                                wr_reg_address                  <= wr_reg_address + 1;
                                words_to_write                  <= words_to_write - 1;
                                Controller_state                <= Download_data;
                            else
                                Controller_state <= Idle;
                                status_fifo_wr_en <= '1';
                                if (UART_rx_data_i = x"FF") then --end of frame
                                    Status_reg <= WRITE_COMPLETED;
                                else
                                    Status_reg <= INVALID_WRITE_END;
                                end if;
                            end if;
                        end if;        
                    end if;
                    
                -------------------------------------
                -- Read Status --
                -------------------------------------
                -- Read the status of the Controller
                when Read_status =>
                state <= "101";
                status_fifo_wr_en <= '0';
                    -- Read from status fifo
                    if (UART_tx_active_i = '0') then
                        UART_tx_data_en <= '1';
                        if (status_fifo_empty = '0') then
                            UART_tx_data    <= status_fifo_dout;
                            status_fifo_rd_en <= '1';
                            Controller_state  <= Wait_tx_done;
                        else
                            status_fifo_rd_en <= '0';
                            UART_tx_data    <= STATUS_READ_COMPLETED;
                            Controller_state  <= Idle;
                        end if;
                    else
                        UART_tx_data_en   <= '0';
                        status_fifo_rd_en <= '0';
                    end if;                     
                     
                when others =>
                state <= "111";
                    Controller_state  <= Idle;
                    Status_reg        <= INVALID_STATE;
                    status_fifo_wr_en <= '1';
    
            end case;
        end if;             
    end process; 
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    

    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        -- FIFO Instantiation --
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Data from host pc to user core
    RX_fifo : FIFO_8x65536
      PORT MAP (
        rst    => fifo_reset,--general_rst,
        wr_clk => Clk_uart_i,
        rd_clk => Clk_user_i,
        din    => UART_rx_data_i,
        wr_en  => rx_fifo_wr_en,
        rd_en  => '0',--RX_fifo_rd_en_i,
        dout   => open,--RX_fifo_dout_o,
        full   => rx_fifo_full,
        empty  => rx_fifo_empty_o,
        wr_rst_busy => open,--wr_rst_busy,
        rd_rst_busy => open--rd_rst_busy
      );
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Data from user core to host pc 
    -- 8bit-read/16-bit-write
    TX_fifo : FIFO_16to8x131072
      PORT MAP (
        rst    => fifo_reset,--general_rst,
        wr_clk => Clk_user_i,
        rd_clk => Clk_uart_i,
        din    => TX_fifo_din_i,
        wr_en  => TX_fifo_wr_en_i,
        rd_en  => tx_fifo_rd_en,
        dout   => tx_fifo_dout,
        full   =>  TX_fifo_full,
        empty  => tx_fifo_empty,
        prog_full => fifo_pkt_rdy_o,
        wr_rst_busy => open,--wr_rst_busy,
        rd_rst_busy => open--rd_rst_busy
      ); 
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Data from host pc to user core
      Status_fifo : FIFO_8x512
        PORT MAP (
          rst    => fifo_reset,--general_rst,
          clk => Clk_uart_i,
          din    => status_reg,
          wr_en  => status_fifo_wr_en,
          rd_en  => status_fifo_rd_en,--RX_fifo_rd_en_i,
          dout   => status_fifo_dout,--RX_fifo_dout_o,
          full   => status_fifo_full,
          empty  => status_fifo_empty
        );
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Control commands  
    CMD_fifo : fifo_6x512
      PORT MAP (
        rst => fifo_reset,--general_rst,
        wr_clk => Clk_uart_i,
        rd_clk => Clk_user_i,
        din    => control_cmd_id,
        wr_en  => cmd_fifo_wr_en,
        rd_en  => Cmd_fifo_rd_en_i,
        dout   => Command_id_o,
        full   => cmd_fifo_full,
        empty  => Cmd_fifo_empty_o,
        wr_rst_busy => open,--wr_rst_busy,
        rd_rst_busy => open--rd_rst_busy
      );
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

--================================================================================
--================================================================================
end Behavioral;