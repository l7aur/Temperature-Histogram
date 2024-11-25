library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity demux is
Port(
    data_in: in std_logic;
    select_signal : in std_logic_vector(2 downto 0);
    data_out: out std_logic_vector(0 to 7)
);
end demux;

architecture Behavioral of demux is

begin
    with select_signal select data_out <= 
        data_in & "0000000"  when "000",
        "0" & data_in & "000000" when "001",
        "00" & data_in & "00000" when "010",
        "000" & data_in & "0000" when "011",
        "0000" & data_in & "000" when "100",
        "00000" & data_in & "00" when "101",
        "000000" & data_in & "0" when "110",
        "0000000" & data_in when others;

end Behavioral;