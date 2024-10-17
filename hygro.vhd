LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY hygro IS
  GENERIC(
    sys_clk_freq            : INTEGER := 50_000_000;                                --input clock speed from user logic in Hz
    humidity_resolution     : INTEGER RANGE 0 TO 14 := 14;                          --RH resolution in bits (must be 14, 11, or 8)
    temperature_resolution  : INTEGER RANGE 0 TO 14 := 14                           --temperature resolution in bits (must be 14 or 11)
  );
  PORT(
    clk               : IN    STD_LOGIC;                                            --system clock
    reset_pmod        : IN    STD_LOGIC;                                            --asynchronous active-low reset
    scl               : INOUT STD_LOGIC;                                            --I2C serial clock
    sda               : INOUT STD_LOGIC;                                            --I2C serial data
    pmod_ack_err      : OUT   STD_LOGIC;                                            --I2C slave acknowledge error flag
    relative_humidity : OUT   STD_LOGIC_VECTOR(humidity_resolution - 1 DOWNTO 0);   --relative humidity data obtained
    temperature       : OUT   STD_LOGIC_VECTOR(temperature_resolution - 1 DOWNTO 0) --temperature data obtained
    );
END hygro;

ARCHITECTURE behavior OF hygro IS
  CONSTANT hygrometer_addr : STD_LOGIC_VECTOR(6 DOWNTO 0) := "1000000";             --I2C address of the hygrometer pmod
  TYPE machine IS(STARTT, CONFIGUREE, INITIATEE, PAUSEE, READD, OUTPUTT);           --needed states
  SIGNAL state                : machine;                                            --state machine
  SIGNAL i2c_enable           : STD_LOGIC;                                          --i2c enable signal
  SIGNAL i2c_addr             : STD_LOGIC_VECTOR(6 DOWNTO 0);                       --i2c address signal
  SIGNAL i2c_rw               : STD_LOGIC;                                          --i2c read/write command signal
  SIGNAL i2c_write_data       : STD_LOGIC_VECTOR(7 DOWNTO 0);                       --i2c write data
  SIGNAL i2c_read_data        : STD_LOGIC_VECTOR(7 DOWNTO 0);                       --i2c read data
  SIGNAL i2c_busy             : STD_LOGIC;                                          --i2c busy signal
  SIGNAL busy_prev            : STD_LOGIC;                                          --previous value of i2c busy signal
  SIGNAL rh_time              : INTEGER;                                            --clock cycles needed for humidity measurement
  SIGNAL temp_time            : INTEGER;                                            --clock cycles needed for temperature measurement
  SIGNAL rh_res_bits          : STD_LOGIC_VECTOR(1 DOWNTO 0);                       --bits to set humidity resolution in sensor register
  SIGNAL temp_res_bit         : STD_LOGIC;                                          --bit to set temperature resolution in sensor register
  SIGNAL humidity_data        : STD_LOGIC_VECTOR(15 DOWNTO 0);                      --humidity data buffer
  SIGNAL temperature_data     : STD_LOGIC_VECTOR(15 DOWNTO 0);                      --temperature data buffer

  COMPONENT i2c IS
  GENERIC(
    input_clk : INTEGER;                                  --input clock speed from user logic in Hz
    bus_clk   : INTEGER                                   --speed the i2c bus (scl) will run at in Hz
  );
  PORT(
    clk           : IN     STD_LOGIC;                     --system clock
    reset_i2c     : IN     STD_LOGIC;                     --active low reset
    ena           : IN     STD_LOGIC;                     --latch in COMMANDD
    addr          : IN     STD_LOGIC_VECTOR(6 DOWNTO 0);  --address of target slave
    rw            : IN     STD_LOGIC;                     --'0' is write, '1' is read
    write_data    : IN     STD_LOGIC_VECTOR(7 DOWNTO 0);  --data to write to slave
    busy          : OUT    STD_LOGIC;                     --indicates transaction in progress
    read_data     : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0);  --data read from slave
    ack_error     : BUFFER STD_LOGIC;                     --flag if improper acknowledge from slave
    sda           : INOUT  STD_LOGIC;                     --serial data output of i2c bus
    scl           : INOUT  STD_LOGIC                      --serial clock output of i2c bus
  );
END COMPONENT;

BEGIN

  --instantiate the i2c master
  i2c_state_machine: i2c
    GENERIC MAP(input_clk => sys_clk_freq, bus_clk => 4)
    PORT MAP(clk => clk, reset_i2c => reset_pmod, ena => i2c_enable, addr => i2c_addr,
             rw => i2c_rw, write_data => i2c_write_data, busy => i2c_busy,
             read_data => i2c_read_data, ack_error => pmod_ack_err, sda => sda,
             scl => scl);
               
  --determine the bits to set the relative humidity resolution in the sensor's configuration register
  WITH humidity_resolution SELECT
    rh_res_bits <= "10" WHEN 8,
                   "01" WHEN 11,
                   "00" WHEN OTHERS;             

  --determine the number of clock cycles required for a humidity measurement at the given resolution
  WITH humidity_resolution SELECT
    rh_time <= sys_clk_freq/400 WHEN 8,      --2.50ms
               sys_clk_freq/259 WHEN 11,     --3.85ms
               sys_clk_freq/153 WHEN OTHERS; --6.50ms
           
  --determine the bits to set the temperature resolution in the sensor's configuration register
  WITH temperature_resolution SELECT
    temp_res_bit <= '1' WHEN 11,
                    '0' WHEN OTHERS;
              
  --determine the number of clock cycles required for a temperature measurement at the given resolution
  WITH temperature_resolution SELECT
    temp_time <= sys_clk_freq/273 WHEN 11,     --3.65ms
                 sys_clk_freq/157 WHEN OTHERS; --6.35ms            
             
  PROCESS(clk, reset_pmod)
    VARIABLE busy_cnt   : INTEGER RANGE 0 TO 4 := 0;                  --counts the I2C busy signal transistions
    VARIABLE pwr_up_cnt : INTEGER RANGE 0 TO sys_clk_freq / 10 := 0;    --counts 100ms to wait before communicating
    VARIABLE PAUSEE_cnt  : INTEGER;                                   --counter to wait for measurements to complete
  BEGIN
  
    IF(reset_pmod = '0') THEN                    --reset activated
      pwr_up_cnt := 0;                          --clear power up counter
      i2c_enable <= '0';                        --clear I2C enable
      busy_cnt := 0;                            --clear busy counter
      PAUSEE_cnt := 0;                          --clear PAUSEE counter
      relative_humidity <= (OTHERS => '0');     --clear the relative humidity result output
      temperature <= (OTHERS => '0');           --clear the temperature result output
      state <= STARTT;                          --return to STARTT state

    ELSIF(clk'EVENT AND clk = '1') THEN         --rising edge of system clock
      CASE state IS                             --state machine
      
        --give hygrometer 100ms to power up before communicating
        WHEN STARTT =>
          IF(pwr_up_cnt < sys_clk_freq/10) THEN     --100ms not yet reached
            pwr_up_cnt := pwr_up_cnt + 1;           --increment power up counter
          ELSE                                      --100ms reached
            pwr_up_cnt := 0;                        --clear power up counter
            state <= CONFIGUREE;                    --advance to CONFIGUREE the hygrometer
          END IF;
        
        --CONFIGUREE the device (set acquisition mode to measure both temp & rh, and set resolutions)
        WHEN CONFIGUREE =>
          busy_prev <= i2c_busy;                                        --capture the value of the previous i2c busy signal
          IF(busy_prev = '0' AND i2c_busy = '1') THEN                   --i2c busy just went high
            busy_cnt := busy_cnt + 1;                                   --counts the times busy has gone from low to high during transaction
          END IF;
          CASE busy_cnt IS                                              --busy_cnt keeps track of which command we are on
            WHEN 0 =>                                                   --no command latched in yet
              i2c_enable <= '1';                                        --initiate the transaction
              i2c_addr <= hygrometer_addr;                              --set the address of the hygrometer
              i2c_rw <= '0';                                            --command 1 is a write
              i2c_write_data <= "00000010";                             --set the register pointer to the Configuration Register
            WHEN 1 =>                                                   --1st busy high: command 1 latched, okay to issue command 2
              i2c_write_data <= "00010" & temp_res_bit & rh_res_bits;   --set acquisition mode and resolutions
            WHEN 2 =>                                                   --2nd busy high: command 2 latched
              i2c_write_data <= "00000000";                             --send 2nd byte of Configuration Register
            WHEN 3 =>                                                   --3nd busy high: command 3 latched
              i2c_enable <= '0';                                        --deassert enable to stop transaction after command 3
              IF(i2c_busy = '0') THEN                                   --transaction complete
                busy_cnt := 0;                                          --reset busy_cnt for next transaction
                state <= INITIATEE;                                     --advance to the INITIATEE state
              END IF;
            WHEN OTHERS => NULL;
          END CASE;
       
        --INITIATEE the measurements
        WHEN INITIATEE =>
          busy_prev <= i2c_busy;                                  --capture the value of the previous i2c busy signal
          IF(busy_prev = '0' AND i2c_busy = '1') THEN             --i2c busy just went high
            busy_cnt := busy_cnt + 1;                             --counts the times busy has gone from low to high during transaction
          END IF;
          CASE busy_cnt IS                                        --busy_cnt keeps track of which command we are on
            WHEN 0 =>                                             --no command latched in yet
              i2c_enable <= '1';                                  --initiate the transaction
              i2c_addr <= hygrometer_addr;                        --set the address of the hygrometer
              i2c_rw <= '0';                                      --command 1 is a write
              i2c_write_data <= "00000000";                       --set the register pointer to the Temperature Register
            WHEN 1 =>                                             --1st busy high: command 1 latched
              i2c_enable <= '0';                                  --deassert enable to stop transaction after command 1
              IF(i2c_busy = '0') THEN                             --transaction complete
                busy_cnt := 0;                                    --reset busy_cnt for next transaction
                state <= PAUSEE;                                  --advance to the PAUSEE state
              END IF;
            WHEN OTHERS => NULL;
          END CASE;   
      
        --wait for humidity and temperature measurements to complete
        WHEN PAUSEE =>
          IF(PAUSEE_cnt < rh_time + temp_time) THEN     --measurement times not met
            PAUSEE_cnt := PAUSEE_cnt + 1;               --increment PAUSEE counter
          ELSE                                          --measurement times met
            PAUSEE_cnt := 0;                            --reset PAUSEE counter
            state <= READD;                             --advance to reading data results
          END IF;
       
        --retreive the relative humidity and temperature measurement results 
        WHEN READD =>
          busy_prev <= i2c_busy;                                    --capture the value of the previous i2c busy signal
          IF(busy_prev = '0' AND i2c_busy = '1') THEN               --i2c busy just went high
            busy_cnt := busy_cnt + 1;                               --counts the times busy has gone from low to high during transaction
          END IF;
          CASE busy_cnt IS                                          --busy_cnt keeps track of which command we are on
            WHEN 0 =>                                               --no command latched in yet
              i2c_enable <= '1';                                    --initiate the transaction
              i2c_addr <= hygrometer_addr;                          --set the address of the hygrometer
              i2c_rw <= '1';                                        --command 1 is a read
            WHEN 1 =>                                               --1st busy high: command 1 latched
              IF(i2c_busy = '0') THEN                               --indicates data read in command 1 is ready
                temperature_data(15 DOWNTO 8) <= i2c_read_data;     --retrieve temperature high-byte data from command 1
              END IF;
            WHEN 2 =>                                               --2nd busy high: command 2 latched
              IF(i2c_busy = '0') THEN                               --indicates data read in command 2 is ready
                temperature_data(7 DOWNTO 0) <= i2c_read_data;      --retrieve temperature low-byte data from command 2
              END IF;
            WHEN 3 =>                                               --3rd busy high: command 3 latched
              IF(i2c_busy = '0') THEN                               --indicates data read in command 3 is ready
                humidity_data(15 DOWNTO 8) <= i2c_read_data;        --retrieve humidity high-byte data from command 3
              END IF;
            WHEN 4 =>                                               --4th busy high: command 4 latched
              i2c_enable <= '0';                                    --deassert enable to stop transaction after command 4
              IF(i2c_busy = '0') THEN                               --indicates data read in command 4 is ready
                humidity_data(7 DOWNTO 0) <= i2c_read_data;         --retrieve humidity low-byte data from command 4
                busy_cnt := 0;                                      --reset busy_cnt for next transaction
                state <= OUTPUTT;                                   --advance to output the result
              END IF;
            WHEN OTHERS => NULL;
          END CASE;
  
        --output the relative humidity and temperature data
        WHEN OUTPUTT =>
          relative_humidity <= humidity_data(15 DOWNTO 16-humidity_resolution);     --write relative humidity data to output
          temperature <= temperature_data(15 DOWNTO 16-temperature_resolution);     --write temperature data to output
          state <= INITIATEE;                                                       --initiate next measurement

        --default to STARTT state
        WHEN OTHERS =>
          state <= STARTT;

      END CASE;
    END IF;
  END PROCESS;  
END behavior;
