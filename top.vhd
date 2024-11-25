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
        ------------------------------------------------
        hygro_scl                   : INOUT STD_LOGIC;
        hygro_sda                   : INOUT STD_LOGIC;
        hygro_ack                   : OUT STD_LOGIC;
        ------------------------------------------------
        debug_bins_selector         : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        debug_anodes                : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        debug_cathodes              : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        ------------------------------------------------
        r_antenna                   : IN STD_LOGIC;
        t_antenna                   : OUT STD_LOGIC;
        ------------------------------------------------
        temp                        : OUT STD_LOGIC_VECTOR(13 DOWNTO 0)
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
    clk                     : IN    STD_LOGIC;                                            --system clock
    reset_pmod              : IN    STD_LOGIC;                                            --asynchronous active-low reset
    scl                     : INOUT STD_LOGIC;                                            --I2C serial clock
    sda                     : INOUT STD_LOGIC;                                            --I2C serial data
    pmod_ack_err            : OUT   STD_LOGIC;                                            --I2C slave acknowledge error flag
    relative_humidity       : OUT   STD_LOGIC_VECTOR(HUMIDITY_RESOLUTION - 1 DOWNTO 0);   --relative humidity data obtained
    temperature             : OUT   STD_LOGIC_VECTOR(TEMPERATURE_RESOLUTION - 1 DOWNTO 0) --temperature data obtained
    );
END COMPONENT;
SIGNAL h                    : STD_LOGIC_VECTOR(MY_HUMIDITY_RESOLUTION - 1 DOWNTO 0);
SIGNAL t                    : STD_LOGIC_VECTOR(MY_TEMPERATURE_RESOLUTION - 1 DOWNTO 0);

COMPONENT temperature_register_controller IS
    GENERIC(
        RES                 : integer := 14;
        NO_BINS             : integer := 8
    );
    PORT(
        clockk              : IN STD_LOGIC;
        rs                  : IN STD_LOGIC;
        raw_data            : IN STD_LOGIC_VECTOR(RES - 1 DOWNTO 0);
        select_bin          : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        as                  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        cs                  : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)
    );
END COMPONENT;

COMPONENT uart_top IS
    GENERIC(
        RESOLUTION       : INTEGER := 14
    );
    PORT(
        clk              : in  std_logic;
        reset            : in  std_logic;
        temperature      : in std_logic_vector(RESOLUTION - 1 DOWNTO 0);
        rx               : in  std_logic;
        tx               : out std_logic
    );
END COMPONENT;

SIGNAL n_reset : STD_LOGIC;

BEGIN
    temp <= t;
    n_reset <= not system_reset;
    
    send_data_to : uart_top 
    GENERIC MAP(
        RESOLUTION              => MY_TEMPERATURE_RESOLUTION)
    PORT MAP(
        clk                     => system_clock,
        reset                   => n_reset,
        temperature             => t,
        rx                      => r_antenna,
        tx                      => t_antenna);
        
    hygro_connection : hygro
    GENERIC MAP(
        SYS_CLK_FREQ            => MY_SYSTEM_CLK_FREQ, 
        HUMIDITY_RESOLUTION     => MY_HUMIDITY_RESOLUTION, 
        TEMPERATURE_RESOLUTION  => MY_TEMPERATURE_RESOLUTION)
    PORT MAP(
        clk                     => system_clock, 
        reset_pmod              => system_reset, 
        scl                     => hygro_scl, 
        sda                     => hygro_sda, 
        pmod_ack_err            => hygro_ack, 
        relative_humidity       => h, 
        temperature             => t);

    histogram_binning: temperature_register_controller
    GENERIC MAP(
        RES                     => MY_TEMPERATURE_RESOLUTION,
        NO_BINS                 => 8
    )
    PORT MAP(
        clockk                  => system_clock,
        rs                      => system_reset,
        raw_data                => t,
        select_bin              => debug_bins_selector,
        as                      => debug_anodes,
        cs                      => debug_cathodes
    );

END ARCHITECTURE;