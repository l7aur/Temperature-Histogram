library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_top is
    Generic(
        RESOLUTION       : INTEGER := 14
    );
    Port(
        clk              : in  std_logic;
        reset            : in  std_logic;
        temperature      : in std_logic_vector(RESOLUTION - 1 DOWNTO 0);
        rx               : in  std_logic;
        tx               : out std_logic
    );
end uart_top;

architecture Behavioral of uart_top is

component UART_controller is

    port(
        clk              : in  std_logic;
        reset            : in  std_logic;
        tx_enable        : in  std_logic;

        data_in          : in  std_logic_vector (7 downto 0);
        data_out         : out std_logic_vector (7 downto 0);

        rx               : in  std_logic;
        tx               : out std_logic
        );
end component;

signal data_in, data_out: std_logic_vector(7 downto 0);
signal tx_enable : std_logic := '0';

TYPE ASCII_DATA IS ARRAY(0 TO 16) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL byte_code: ASCII_DATA := (
    0   => x"30", 1   => x"31", 2   => x"32", 3   => x"33", 4   => x"34", 5   => x"35",
    6   => x"36", 7   => x"37", 8   => x"38", 9   => x"39", 10  => x"41", 11  => x"42",
    12  => x"43", 13  => x"44", 14  => x"45", 15  => x"46", 16  => x"20"
);

begin
    uart_ctrl: UART_controller port map(
        clk => clk,
        reset => reset,
        tx_enable => tx_enable,
        data_in => data_in,
        data_out => data_out,
        rx => rx,
        tx => tx
    );

    process(clk, reset)
        variable aux : std_logic_vector(4 downto 0) := "00000";
        variable index: integer := -1;
    begin
        if reset = '1' then
            aux     := "00000";
            index   := 0;
        elsif rising_edge(clk) then
            CASE index IS
                WHEN 0   => data_in  <= byte_code(TO_INTEGER(UNSIGNED(temperature(13 DOWNTO 10))));
                WHEN 1   => data_in  <= byte_code(TO_INTEGER(UNSIGNED(temperature(9 DOWNTO 6))));
                WHEN 2   => data_in  <= byte_code(TO_INTEGER(UNSIGNED(temperature(5 DOWNTO 2))));
                WHEN 3   => data_in  <= byte_code(4 * TO_INTEGER(UNSIGNED(temperature(1 DOWNTO 0)))); --shift the value to the right by 2 bits to take into consideration the last 2 '0' bits that are not registered by the sensor
                WHEN 4   => 
                    data_in  <= byte_code(16);
                    tx_enable <= '0';
                WHEN OTHERS =>
                    index := 0;
                    tx_enable <= '0';
            END CASE;
            aux := aux + 1;
            IF aux = "00111" THEN
                index := index + 1;
            END IF;
            IF aux = "11111" THEN
                tx_enable <= '1';
            ELSE
                tx_enable <= '0';
            END IF;
        end if;
    end process;
    
end Behavioral;
