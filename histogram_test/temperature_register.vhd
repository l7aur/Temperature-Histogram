library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

entity temperature_register is
    Port(
        reg_clk         : in std_logic;
        reg_r           : in std_logic;
        reg_add_one      : in std_logic;
        reg_value       : out std_logic_vector(15 downto 0)
    );
end temperature_register;

architecture Behavioral of temperature_register is

signal internal_state: std_logic_vector(15 downto 0) := x"0000";

begin

    --counter with enable
    counter: process(reg_clk, reg_r)
    begin
        if reg_r = '0' then
            internal_state <= x"0000";
        elsif rising_edge(reg_clk) then
            if reg_add_one = '1' then
                internal_state <= internal_state + 1;
            end if;
        end if;
    end process;
    reg_value <= internal_state;
end Behavioral;
