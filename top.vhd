library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

ENTITY top IS
    GENERIC(
        MY_SYSTEM_CLK_FREQ          : INTEGER := 50_000_000;
        MY_HUMIDITY_RESOLUTION      : INTEGER RANGE 0 TO 14 := 14;
        MY_TEMPERATURE_RESOLUTION   : INTEGER RANGE 0 TO 14 := 14
    );
    PORT(
        system_clock                : IN STD_LOGIC;
        system_reset                : IN STD_LOGIC;
        hygro_scl                   : INOUT STD_LOGIC;
        hygro_sda                   : INOUT STD_LOGIC;
        hygro_ack                   : OUT STD_LOGIC;
        t                           : OUT STD_LOGIC_VECTOR(MY_TEMPERATURE_RESOLUTION - 1 DOWNTO 0)
    );
END top;

ARCHITECTURE logic OF top IS
COMPONENT hygro IS
  GENERIC(
    SYS_CLK_FREQ            : INTEGER;                                              --input clock speed from user logic in Hz
    HUMIDITY_RESOLUTION     : INTEGER RANGE 0 TO 14;                                --RH resolution in bits (must be 14, 11, or 8)
    TEMPERATURE_RESOLUTION  : INTEGER RANGE 0 TO 14                                 --temperature resolution in bits (must be 14 or 11)
    );
  PORT(
    clk               : IN    STD_LOGIC;                                            --system clock
    reset_pmod        : IN    STD_LOGIC;                                            --asynchronous active-low reset
    scl               : INOUT STD_LOGIC;                                            --I2C serial clock
    sda               : INOUT STD_LOGIC;                                            --I2C serial data
    pmod_ack_err      : OUT   STD_LOGIC;                                            --I2C slave acknowledge error flag
    relative_humidity : OUT   STD_LOGIC_VECTOR(HUMIDITY_RESOLUTION - 1 DOWNTO 0);   --relative humidity data obtained
    temperature       : OUT   STD_LOGIC_VECTOR(TEMPERATURE_RESOLUTION - 1 DOWNTO 0) --temperature data obtained
    );
END COMPONENT;
SIGNAL h                : STD_LOGIC_VECTOR(MY_HUMIDITY_RESOLUTION - 1 DOWNTO 0);

BEGIN

    hygro_connection : hygro
    GENERIC MAP(
        SYS_CLK_FREQ => MY_SYSTEM_CLK_FREQ, 
        HUMIDITY_RESOLUTION => MY_HUMIDITY_RESOLUTION, 
        TEMPERATURE_RESOLUTION => MY_TEMPERATURE_RESOLUTION)
    PORT MAP(
        clk => system_clock, 
        reset_pmod => system_reset, 
        scl => hygro_scl, 
        sda => hygro_sda, 
        pmod_ack_err => hygro_ack, 
        relative_humidity => h, 
        temperature => t);

END ARCHITECTURE;