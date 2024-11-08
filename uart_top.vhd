library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_top is
    Port(
        clk              : in  std_logic;
        reset            : in  std_logic;
        led              : out std_logic;
        rx               : in  std_logic;
        tx               : out std_logic
    );
end aurt_top;

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

type data is array(0 to 4) of std_logic_vector(7 downto 0);
signal myData : data := (
    0 => x"48",
    1 => x"65",
    2 => x"6C",
    3 => x"6C",
    4 => x"6F"
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
        variable aux : std_logic_vector(23 downto 0) := x"000000";
    begin
        if reset = '1' then
            aux := x"000000";
        elsif rising_edge(clk) then
            aux := aux + 1;
            tx_enable <= aux(23);
        end if;
    end process;
    
    led <= tx_enable;
    process(clk, reset)
        variable aux: std_logic_vector(23 downto 0) := x"000000";
        variable index : std_logic_vector(1 downto 0) := "00";
    begin
        if reset = '1' then
            aux := x"000000";
            index := "00";
        elsif rising_edge(clk) then
            aux := aux + 1;
            if aux = x"FFFFFF" then
                index := index + 1;
            end if;
            data_in <= myData(TO_INTEGER(UNSIGNED(index)));
        end if;
    end process;
    
end Behavioral;
