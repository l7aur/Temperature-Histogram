library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

ENTITY top IS
    GENERIC(
        my_system_clk_freq          : INTEGER := 5_000;
        my_humidity_resolution      : INTEGER RANGE 0 TO 14 := 14;
        my_temperature_resolution   : INTEGER RANGE 0 TO 14 := 14
    );
    PORT(
        system_clock                : IN STD_LOGIC;
        system_reset                : IN STD_LOGIC;
        hygro_scl                   : INOUT STD_LOGIC;
        hygro_sda                   : INOUT STD_LOGIC;
        hygro_ack                   : OUT STD_LOGIC;
        t                           : OUT STD_LOGIC_VECTOR(my_temperature_resolution - 1 DOWNTO 0)
    );
END top;

ARCHITECTURE logic OF top IS
COMPONENT hygro IS
  GENERIC(
    sys_clk_freq            : INTEGER;                                              --input clock speed from user logic in Hz
    humidity_resolution     : INTEGER RANGE 0 TO 14;                                --RH resolution in bits (must be 14, 11, or 8)
    temperature_resolution  : INTEGER RANGE 0 TO 14                                 --temperature resolution in bits (must be 14 or 11)
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
END COMPONENT;

SIGNAL h              : STD_LOGIC_VECTOR(my_humidity_resolution - 1 DOWNTO 0);

BEGIN
    hygro_connection : hygro
    GENERIC MAP(
        sys_clk_freq => my_system_clk_freq, 
        humidity_resolution => my_humidity_resolution, 
        temperature_resolution => my_temperature_resolution)
    PORT MAP(
        clk => system_clock, 
        reset_pmod => system_reset, 
        scl => hygro_scl, 
        sda => hygro_sda, 
        pmod_ack_err => hygro_ack, 
        relative_humidity => h, 
        temperature => t);

END ARCHITECTURE;