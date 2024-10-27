LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;

ENTITY i2c IS
  GENERIC(
    INPUT_CLK : INTEGER := 50_000_000;                  --input clock speed from user logic in Hz
    BUS_CLK   : INTEGER := 400_000                      --speed the i2c bus (scl) will run at in Hz
  );
  PORT(
    clk           : IN     STD_LOGIC;                    --system clock
    reset_i2c     : IN     STD_LOGIC;                    --active low reset
    ena           : IN     STD_LOGIC;                    --latch in command
    addr          : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); --address of target slave
    rw            : IN     STD_LOGIC;                    --'0' is write, '1' is read
    write_data    : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); --data to write to slave
    busy          : OUT    STD_LOGIC;                    --indicates transaction in progress
    read_data     : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
    ack_error     : BUFFER STD_LOGIC;                    --flag if improper acknowledge from slave
    sda           : INOUT  STD_LOGIC;                    --serial data output of i2c bus
    scl           : INOUT  STD_LOGIC                     --serial clock output of i2c bus
  );
END i2c;

ARCHITECTURE logic OF i2c IS
  TYPE machine IS
    (READYY, STARTT, COMMANDD, ACKK1, WRITEE, READD, ACKK2, M_ACKK, STOPP); --needed states
  CONSTANT MY_LIMIT         : INTEGER := (INPUT_CLK / BUS_CLK) / 4;        --number of clocks in 1/4 cycle of scl
  SIGNAL state              : machine;                                      --state machine
  SIGNAL data_clk           : STD_LOGIC;                                    --data clock for sda
  SIGNAL data_clk_prev      : STD_LOGIC;                                    --data clock during previous system clock
  SIGNAL scl_clk            : STD_LOGIC;                                    --constantly running internal scl
  SIGNAL scl_ena            : STD_LOGIC := '0';                             --enables internal scl to output
  SIGNAL sda_int            : STD_LOGIC := '1';                             --internal sda
  SIGNAL sda_ena_wrapper    : STD_LOGIC;                                    --enables internal sda to output
  SIGNAL addr_rw            : STD_LOGIC_VECTOR(7 DOWNTO 0);                 --latched in address and read/writeite
  SIGNAL data_tx            : STD_LOGIC_VECTOR(7 DOWNTO 0);                 --latched in data to write to slave
  SIGNAL data_rx            : STD_LOGIC_VECTOR(7 DOWNTO 0);                 --data received from slave
  SIGNAL bit_cnt            : INTEGER RANGE 0 TO 7 := 7;                    --tracks bit number in transaction
  SIGNAL stretch            : STD_LOGIC := '0';                             --identifies if slave is stretching scl
BEGIN

  --generate the timing f or the bus clock (scl_clk) and the data clock (data_clk)
  PROCESS(clk, reset_i2c)
    VARIABLE count  :  INTEGER RANGE 0 TO MY_LIMIT * 4;     --timing for clock generation
  BEGIN
      IF(reset_i2c = '0') THEN                              --reset asserted
        stretch <= '0';
        count := 0;
    ELSIF(clk'EVENT AND clk = '1') THEN
        data_clk_prev <= data_clk;                          --store previous value of data clock
        IF(count = MY_LIMIT * 4 - 1) THEN                   --end of timing cycle
          count := 0;                                       --reset timer
        ELSIF(stretch = '0') THEN                           --clock stretching from slave not detected
          count := count + 1;                               --continue clock generation timing
        END IF;
      CASE count IS
        WHEN 0 TO MY_LIMIT - 1 =>                             --first 1/4 cycle of clocking
          scl_clk <= '0';
          data_clk <= '0';
        WHEN MY_LIMIT TO MY_LIMIT * 2 - 1 =>                --second 1/4 cycle of clocking
          scl_clk <= '0';
          data_clk <= '1';
        WHEN MY_LIMIT * 2 TO MY_LIMIT * 3 - 1 =>            --third 1/4 cycle of clocking
          scl_clk <= '1';                                   --release scl
          IF(scl = '0') THEN                                --detect if slave is stretching clock
            stretch <= '1';
          ELSE
            stretch <= '0';
          END IF;
          data_clk <= '1';
        WHEN OTHERS =>                                      --last 1/4 cycle of clocking
          scl_clk <= '1';
          data_clk <= '0';
      END CASE;
    END IF;
  END PROCESS;

  --state machine and writing to sda during scl low (data_clk rising edge)
  PROCESS(clk, reset_i2c)
  BEGIN
      IF(reset_i2c = '0') THEN                          --reset asserted
        state <= READYY;                                --return to initial state
        busy <= '1';                                    --indicate not available
        scl_ena <= '0';                                 --sets scl high impedance
        sda_int <= '1';                                 --sets sda high impedance
        ack_error <= '0';                               --clear acknowledge error flag
        bit_cnt <= 7;                                   --reSTARTTs data bit counter
        read_data <= "00000000";                        --clear data read port
    ELSIF(rising_edge(clk)) THEN
      IF(data_clk = '1' AND data_clk_prev = '0') THEN   --data clock rising edge
        CASE state IS
          WHEN READYY =>                                --idle state
            IF(ena = '1') THEN                          --transaction requested
              busy <= '1';                              --flag busy
              addr_rw <= addr & rw;                     --collect requested slave address and command
              data_tx <= write_data;                --collect requested data to write
              state <= STARTT;                          --go to STARTT bit
            ELSE                                        --remain idle
              busy <= '0';                              --unflag busy
              state <= READYY;                          --remain idle
            END IF;
          WHEN STARTT =>                                --start bit of transaction
            busy <= '1';                                --resume busy if continuous mode
            sda_int <= addr_rw(bit_cnt);                --set first address bit to bus
            state <= COMMANDD;                          --go to COMMANDD
          WHEN COMMANDD =>                              --address and command byte of transaction
            IF(bit_cnt = 0) THEN                        --command transmit finished
              sda_int <= '1';                           --release sda for slave acknowledge
              bit_cnt <= 7;                             --reset bit counter for "byte" states
              state <= ACKK1;                           --go to slave acknowledge (COMMANDD)
            ELSE                                        --next clock cycle of COMMANDD state
              bit_cnt <= bit_cnt - 1;                   --keep track of transaction bits
              sda_int <= addr_rw(bit_cnt-1);            --write address/command bit to bus
              state <= COMMANDD;                        --continue with COMMANDD
            END IF;
          WHEN ACKK1 =>                                 --slave acknowledge bit (COMMANDD)
            IF(addr_rw(0) = '0') THEN                   --writing COMMANDD
              sda_int <= data_tx(bit_cnt);              --writing first bit of data
              state <= WRITEE;                          --go to write byte
            ELSE                                        --read command
              sda_int <= '1';                           --release sda from incoming data
              state <= READD;                           --go to read byte
            END IF;
          WHEN WRITEE =>                                --writing byte of transaction
            busy <= '1';                                --resume busy if continuous mode
            IF(bit_cnt = 0) THEN                        --write byte transmit finished
              sda_int <= '1';                           --release sda for slave acknowledge
              bit_cnt <= 7;                             --reset bit counter for "byte" states
              state <= ACKK2;                           --go to slave acknowledge (write)
            ELSE                                        --next clock cycle of write state
              bit_cnt <= bit_cnt - 1;                   --keep track of transaction bits
              sda_int <= data_tx(bit_cnt - 1);          --writing next bit to bus
              state <= WRITEE;                          --continue writing
            END IF;
          WHEN READD =>                                   --read byte of transaction
            busy <= '1';                                  --resume busy if continuous mode
            IF(bit_cnt = 0) THEN                          --read byte receive finished
              IF(ena = '1' AND addr_rw = addr & rw) THEN  --continuing with another read at same address
                sda_int <= '0';                           --acknowledge the byte has been received
              ELSE                                        --stopping or continuing with a write
                sda_int <= '1';                           --send a no-acknowledge (before STOPP or repeated STARTT)
              END IF;
              bit_cnt <= 7;                               --reset bit counter for "byte" states
              read_data <= data_rx;                       --output received data
              state <= M_ACKK;                            --go to master acknowledge
            ELSE                                          --next clock cycle of read state
              bit_cnt <= bit_cnt - 1;                     --keep track of transaction bits
              state <= READD;                             --continue reading
            END IF;
          WHEN ACKK2 =>                                   --slave acknowledge bit (write)
            IF(ena = '1') THEN                            --continue transaction
              busy <= '0';                                --continue is accepted
              addr_rw <= addr & rw;                       --collect requested slave address and COMMANDD
              data_tx <= write_data;                      --collect requested data to write
              IF(addr_rw = addr & rw) THEN                --continue transaction with another write
                sda_int <= write_data(bit_cnt);           --write first bit of data
                state <= WRITEE;                          --go to write byte
              ELSE                                        --continue transaction with a read or new slave
                state <= STARTT;                          --go to repeated STARTT
              END IF;
            ELSE                                          --complete transaction
              state <= STOPP;                             --go to stop bit
            END IF;
          WHEN M_ACKK =>                                  --master acknowledge bit after a read
            IF(ena = '1') THEN                            --continue transaction
              busy <= '0';                                --continue is accepted and data received is available on bus
              addr_rw <= addr & rw;                       --collect requested slave address and COMMANDD
              data_tx <= write_data;                  --collect requested data to write
              IF(addr_rw = addr & rw) THEN                --continue transaction with another read
                sda_int <= '1';                           --release sda from incoming data
                state <= READD;                           --go to read byte
              ELSE                                        --continue transaction with a writing or new slave
                state <= STARTT;                          --repeated start
              END IF;    
            ELSE                                          --complete transaction
              state <= STOPP;                             --go to STOPP bit
            END IF;
          WHEN STOPP =>                                   --stop bit of transaction
            busy <= '0';                                  --unflag busy
            state <= READYY;                              --go to idle state
        END CASE;    
      ELSIF(data_clk = '0' AND data_clk_prev = '1') THEN  --data clock falling edge
        CASE state IS
          WHEN STARTT =>                  
            IF(scl_ena = '0') THEN                        --starting new transaction
              scl_ena <= '1';                             --enable scl output
              ack_error <= '0';                           --reset acknowledge error output
            END IF;
          WHEN ACKK1 =>                                   --receiving slave acknowledge (COMMANDD)
            IF(sda /= '0' OR ack_error = '1') THEN        --no-acknowledge or previous no-acknowledge
              ack_error <= '1';                           --set error output if no-acknowledge
            END IF;
          WHEN READD =>                                   --receiving slave data
            data_rx(bit_cnt) <= sda;                      --receive current slave data bit
          WHEN ACKK2 =>                                   --receiving slave acknowledge (write)
            IF(sda /= '0' OR ack_error = '1') THEN        --no-acknowledge or previous no-acknowledge
              ack_error <= '1';                           --set error output if no-acknowledge
            END IF;
          WHEN STOPP =>
            scl_ena <= '0';                               --disable scl
          WHEN OTHERS =>
            NULL;
        END CASE;
      END IF;
    END IF;
  END PROCESS;  

  --set sda output
  WITH state SELECT
    sda_ena_wrapper <= data_clk_prev WHEN STARTT,         --generate STARTT condition
                 NOT data_clk_prev WHEN STOPP,            --generate STOPP condition
                 sda_int WHEN OTHERS;                     --set to internal sda signal    
      
  --set scl and sda outputs
  scl <= '0' WHEN (scl_ena = '1' AND scl_clk = '0') ELSE 'Z';
  sda <= '0' WHEN sda_ena_wrapper = '0' ELSE 'Z';
  
END logic;
