library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity ssd_display is
    Port(
        clk : in std_logic;
        number_in  : in std_logic_vector(15 downto 0);
        anodes : out std_logic_vector(3 downto 0);
        cathodes: out std_logic_vector(0 to 6)
    );
end ssd_display;

architecture Behavioral of ssd_display is

type constant_array is array (0 to 15) of std_logic_vector(0 to 6);
constant digits: constant_array := (
    0 => "1000000", -- 0
    1 => "1111001", -- 1
    2 => "0100100", -- 2
    3 => "0110000", -- 3
    4 => "0011001", -- 4
    5 => "0010010", -- 5
    6 => "0000010", -- 6
    7 => "1111000", -- 7
    8 => "0000000", -- 8
    9 => "0010000", -- 9
    10 => "0000100", -- A
    11 => "0000011", -- B
    12 => "1000110", -- C
    13 => "0100001", -- D
    14 => "0000110", -- E
    15 => "0001110"  -- F
);

signal lighting_anodes : std_logic_vector(1 downto 0) := "00";

begin
    freq_divider: process(clk)
        variable aux: std_logic_vector(19 downto 0) := x"00000";
    begin
        if rising_edge(clk) then
            aux := aux + 1;
        end if;
        lighting_anodes <= aux(19 downto 18);
    end process;
    
    with lighting_anodes select anodes <= 
        "1110" when "00",
        "1101" when "01",
        "1011" when "10",
        "0111" when others;
            
    with lighting_anodes select cathodes <=
        digits(TO_INTEGER(UNSIGNED(number_in(3 downto 0)))) when "00",
        digits(TO_INTEGER(UNSIGNED(number_in(7 downto 4)))) when "01",
        digits(TO_INTEGER(UNSIGNED(number_in(11 downto 8)))) when "10",
        digits(TO_INTEGER(UNSIGNED(number_in(15 downto 12)))) when others;    
end Behavioral;
