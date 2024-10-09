library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity I2C_controller is
    GENERIC(
        input_clk               : INTEGER := 50_000_000;                --input clock speed from user logic in Hz
        bus_clk                 : INTEGER := 400_000                    --speed of the I2C scl bus in Hz
    );
    PORT(
        clock                   : IN STD_LOGIC;                         --system clock
        r                       : IN STD_LOGIC;                         --active low asynchronous reset
        transaction_requested   : IN STD_LOGIC;                         --latch that enables the transmission of a transaction
        address                 : IN STD_LOGIC_VECTOR(6 DOWNTO 0);      --target address
        read_write              : IN STD_LOGIC;                         --read = '1', write = '0'
        data_to_target          : IN STD_LOGIC_VECTOR(7 DOWNTO 0);      --data to be sent to target

        busy                    : OUT STD_LOGIC;                        --transaction in progress flag
        data_to_source          : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);     --data to be sent to source
        
        ack_flag                : BUFFER STD_LOGIC;                     --acknowledge flag from target
        
        sda                     : INOUT STD_LOGIC;                      --serial data output of I2C bus
        scl                     : INOUT STD_LOGIC                       --serial clock output of I2C bus
    );
end I2C_controller;

architecture Behavioral of I2C_controller is
    --clock generating
    CONSTANT NUMBER_OF_CLOCKS   : INTEGER := (input_clk / bus_clk) / 4; --number of clock cycles in a quarter cycle of scl
    SIGNAL prev_data_clk        : STD_LOGIC;                            --data clock value during the previous system clock
    SIGNAL data_clk             : STD_LOGIC;                            --data clock for sda
    SIGNAL scl_clk              : STD_LOGIC;                            --constantly running internal scl
    SIGNAL stretch              : STD_LOGIC := '0';                     --target is stretching scl flag

    --finite state machine
    TYPE state_machine IS
    (READY, START, COMMAND, TARGET_ACK1, WRITEE, 
     READD, TARGET_ACK2, SOURCE_ACK, STOPP);                            --states of the FSM
    SIGNAL current_state        : state_machine;                        --current state of the FSM
    SIGNAL scl_enable           : STD_LOGIC := '0';                     --enables internal scl to output
    SIGNAL sda_internal         : STD_LOGIC := '1';                     --internal sda
    SIGNAL bit_counter          : INTEGER RANGE 0 TO 7 := 7;            --number of bits in transaction
    SIGNAL data_tx              : STD_LOGIC_VECTOR(7 DOWNTO 0);         --data to write to target (latched)
    SIGNAL data_rx              : STD_LOGIC_VECTOR(7 DOWNTO 0);         --data received from target (to source)
    SIGNAL address_rw_bus       : STD_LOGIC_VECTOR(7 DOWNTO 0);         --address and read/write bus (latched)

    --miscellaneous
    SIGNAL sda_internal_wrapper : STD_LOGIC;
begin
--generate the timing for the bus and data clocks (scl_clk, data_clk)
PROCESS(clock, r)
    VARIABLE aux: INTEGER RANGE 0 TO NUMBER_OF_CLOCKS * 4;              --timing for clock generation
BEGIN
    IF(r = '0') THEN                                                    --if reset is pressed go back to the initial state
        stretch <= '0';
        aux := 0;
    ELSIF (rising_edge(clock)) THEN                                       --on each rising edge
        prev_data_clk <= data_clk;                                      --update the value of the sda data clock
        IF(aux = NUMBER_OF_CLOCKS * 4 - 1) THEN                       --end of timing cycle
            aux := 0;                                                 --reset timer
        ELSIF(stretch = '0') THEN                                       --target is not stretching the scl clock
            aux := aux + 1;                                         --update timer
        END IF;
        CASE aux IS                                                   --
            WHEN 0 TO NUMBER_OF_CLOCKS - 1 =>                           --first quater of the clocking cycle
                scl_clk <= '0';
                data_clk <= '0';    
            WHEN NUMBER_OF_CLOCKS - 1 TO NUMBER_OF_CLOCKS * 2 - 1 =>    --second quarter of the clocking cycle
                scl_clk <= '0';
                data_clk <= '1';
            WHEN NUMBER_OF_CLOCKS * 2 TO NUMBER_OF_CLOCKS * 3 - 1 =>    --third quater of the clocking cycle
                scl_clk <= '1';
                IF(scl = '0') THEN
                    stretch <= '1';
                ELSE
                    stretch <= '0';
                END IF;
                data_clk <= '1';
            WHEN OTHERS =>                                              --last quarter of the clocking cycle
                scl_clk <= '1';
                data_clk <= '0';
            END CASE;
    END IF;
END PROCESS;

--state machine
PROCESS(clock, r)
BEGIN
    IF(r = '0') THEN                                                    --reset is pressed
        current_state <= READY;                                         --return to the initial state
        busy <= '1';                                                    --flag unavailability
        scl_enable <= '0';                                              --set scl HIGH
        sda_internal <= '1';                                            --set sda HIGH
        ack_flag <= '0';                                                --clear acknowledge flag
        bit_counter <= 7;                                               --restart data bit counter
        data_to_source <= x"00";                                        --clear data read port
    ELSIF(rising_edge(clock)) THEN
        IF(data_clk = '1' AND prev_data_clk = '0') THEN                 --rising edge detected on data clock
            CASE current_state IS
                WHEN READY =>
                    IF (transaction_requested = '1') THEN
                        busy <= '1';
                        address_rw_bus <= address & read_write;
                        data_tx <= data_to_target;
                        current_state <= START;
                    ELSE
                        busy <= '1';
                        current_state <= READY;
                    END IF;
                WHEN START =>
                    busy <= '1';
                    sda_internal <= address_rw_bus(bit_counter);
                    current_state <= COMMAND;
                WHEN COMMAND =>
                    IF(bit_counter = 0) THEN
                        sda_internal <= '1';
                        bit_counter <= 7;
                        current_state <= TARGET_ACK1;
                    ELSE
                        bit_counter <= bit_counter - 1;
                        sda_internal <= address_rw_bus(bit_counter - 1);
                        current_state <= COMMAND;
                    END IF;
                WHEN TARGET_ACK1 =>
                    IF(address_rw_bus(0) = '0') THEN
                        sda_internal <= data_tx(bit_counter);
                        current_state <= WRITEE;
                    ELSE
                        sda_internal <= '1';
                        current_state <= READD;
                    END IF;
                WHEN WRITEE =>
                    busy <= '1';
                    IF(bit_counter = 0) THEN
                        sda_internal <= '1';
                        bit_counter <= 7;
                        current_state <= TARGET_ACK2;
                    ELSE
                        bit_counter <= bit_counter - 1;
                        sda_internal <= data_tx(bit_counter - 1);
                        current_state <= WRITEE;
                    END IF;
                WHEN READD =>
                    busy <= '1';
                    IF(bit_counter = 0) THEN
                        IF(transaction_requested = '1' AND address_rw_bus = address & read_write) THEN
                            sda_internal <= '0';
                        ELSE
                            sda_internal <= '1';
                        END IF;
                        bit_counter <= 7;
                        data_to_source <= data_rx;
                        current_state <= SOURCE_ACK;
                    ELSE
                        bit_counter <= bit_counter - 1;
                        current_state <= READD;
                    END IF;
                WHEN TARGET_ACK2 =>
                    IF(transaction_requested = '1') THEN
                        busy <= '0';
                        address_rw_bus <= address & read_write;
                        data_tx <= data_to_target;
                        IF(address_rw_bus = address & read_write) THEN
                            sda_internal <= data_to_target(bit_counter);
                            current_state <= WRITEE;
                        ELSE
                            current_state <= START;
                        END IF;
                    ELSE
                        current_state <= STOPP;
                    END IF;
                WHEN SOURCE_ACK =>
                    IF(transaction_requested = '1') THEN
                        busy <= '0';
                        address_rw_bus <= address & read_write;
                        data_tx <= data_to_target;
                        IF(address_rw_bus = address & read_write) THEN
                            sda_internal <= '1';
                            current_state <= READD;
                        ELSE
                            current_state <= START;
                        END IF;
                    ELSE
                        current_state <= STOPP;
                    END IF;
                WHEN STOPP =>
                    busy <= '0';
                    current_state <= READY;
            END CASE;
        ELSIF(data_clk = '0' AND prev_data_clk = '1') THEN            --falling edge detected on data clock
            CASE current_state IS
                WHEN START =>
                    IF(scl_enable = '0') THEN
                        scl_enable <= '1';
                        ack_flag <= '0';
                    END IF;
                WHEN TARGET_ACK1 =>
                    IF(sda /='0' OR ack_flag = '1') THEN
                        ack_flag <= '1';
                    END IF;
                WHEN READD =>
                    data_rx(bit_counter) <= sda;
                WHEN TARGET_ACK2 =>
                IF(sda /= '0' OR ack_flag = '1') THEN
                    ack_flag <= '1';
                END IF;
                WHEN STOPP =>
                    scl_enable <= '0';
                WHEN OTHERS => 
                    NULL;
            END CASE;
        END IF;
    END IF;
END PROCESS;

--set sda output
WITH current_state SELECT sda_internal_wrapper <=
    prev_data_clk WHEN START,
    NOT prev_data_clk WHEN STOPP,
    sda_internal WHEN OTHERS;

--set scl and sda outputs
scl <= '0' WHEN (scl_enable = '1' AND scl_clk = '0') ELSE 'Z';
sda <= '0' WHEN (sda_internal_wrapper = '0') ELSE 'Z';

end Behavioral;
