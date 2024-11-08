library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity temperature_register is
    Port(
        reg_clk         : in std_logic;
        reg_r           : in std_logic;
        measured_data   : in std_logic_vector(15 downto 0);
        threshold_min   : in std_logic_vector(15 downto 0);
        threshold_max   : in std_logic_vector(15 downto 0);
        reg_value       : out std_logic_vector(15 downto 0);
        data_out_left   : out std_logic_vector(15 downto 0);
        data_out_right  : out std_logic_vector(15 downto 0)
    );
end temperature_register;

architecture Behavioral of temperature_register is

signal internal_state: std_logic_vector(15 downto 0) := x"0000";
signal clk : std_logic;

begin
    f_divider: process(reg_clk, reg_r)
        variable aux : std_logic_vector(23 downto 0) := x"000000";
    begin
        if(reg_r = '0') then
            aux := x"000000";
        elsif(rising_edge(reg_clk)) then
            aux := aux + 1;
        end if;            
        clk <= aux(23);
    end process;

    --counter with enable
    counter: process(clk, reg_r)
    begin
        if reg_r = '0' then
            internal_state <= x"0000";
        elsif rising_edge(clk) then
            if (unsigned(threshold_min) < unsigned(measured_data) and 
                unsigned(measured_data) <= unsigned(threshold_max)) then
                internal_state <= internal_state + 1;
                data_out_left <= x"0000";
                data_out_right <= x"0000";                
            elsif(unsigned(threshold_min) > unsigned(measured_data)) then
                data_out_left <= measured_data;
                data_out_right <= x"0000";
            elsif(unsigned(threshold_min) < unsigned(measured_data)) then
                data_out_right <= measured_data;
                data_out_left <= x"0000";
            else
                data_out_right <= x"0000";
                data_out_left <= x"0000";
            end if;
        end if;
    end process;
    reg_value <= internal_state;
end Behavioral;
