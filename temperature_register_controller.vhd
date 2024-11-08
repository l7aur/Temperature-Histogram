library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity temperature_register_controller is
    generic(
        RES : integer := 14;
        NO_BINS: integer := 8
    );
    Port(
        clockk : in std_logic;
        rs   : in std_logic;
        raw_data: in std_logic_vector(RES - 1 downto 0);
        select_bin: in std_logic_vector(2 downto 0);
        as: out std_logic_vector(3 downto 0);
        cs: out std_logic_vector(6 downto 0)
--        test_clock: out std_logic
    );
end temperature_register_controller;

architecture Behavioral of temperature_register_controller is

component ssd_display is
    Port(
        clk : in std_logic;
        number_in  : in std_logic_vector(15 downto 0);
        anodes : out std_logic_vector(3 downto 0);
        cathodes: out std_logic_vector(0 to 6)
    );
end component;

component temperature_register is
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
end component;

type matrix is array (0 to NO_BINS - 1) of std_logic_vector(15 downto 0);
signal data_out_matrix: matrix := (others => x"0000");
signal ref_values : matrix:= (
                    0 => x"53C9", --14 deg C
                    1 => x"56E3", --16 deg C
                    2 => x"59FD", --18 deg C
                    3 => x"5D18", --20 deg C
                    4 => x"6032", --22 deg C
                    5 => x"634D", --24 deg C
                    6 => x"6667", --26 deg C
                    7 => x"FFFF");
signal data_wrapper : std_logic_vector(15 downto 0);
signal data_out_wrapper: std_logic_vector(15 downto 0);

signal lefts, rights : matrix := (others => x"0000");

begin
    data_wrapper <= raw_data & "00";
    
    level0: temperature_register port map (
            reg_clk         => clockk,
            reg_r           => rs,
            measured_data   => data_wrapper,
            threshold_min   => ref_values(2),
            threshold_max   => ref_values(3),
            reg_value       => data_out_matrix(3),
            data_out_left   => lefts(3), 
            data_out_right  => rights(3)
        );
        
     --second level
     level1: temperature_register port map (
            reg_clk         => clockk,
            reg_r           => rs,
            measured_data   => lefts(3),
            threshold_min   => ref_values(0),
            threshold_max   => ref_values(1),
            reg_value       => data_out_matrix(1),
            data_out_left   => lefts(1), 
            data_out_right  => rights(1)
        );
      level1bis: temperature_register port map (
            reg_clk         => clockk,
            reg_r           => rs,
            measured_data   => rights(3),
            threshold_min   => ref_values(4),
            threshold_max   => ref_values(5),
            reg_value       => data_out_matrix(5),
            data_out_left   => lefts(5), 
            data_out_right  => rights(5)
        );
        
        --third level
        level2: temperature_register port map (
            reg_clk         => clockk,
            reg_r           => rs,
            measured_data   => lefts(1),
            threshold_min   => x"0008", -- so that zeroes don t count in the register
            threshold_max   => ref_values(0),
            reg_value       => data_out_matrix(0),
            data_out_left   => lefts(0), 
            data_out_right  => rights(0)
        );
        level2bis: temperature_register port map (
            reg_clk         => clockk,
            reg_r           => rs,
            measured_data   => rights(1),
            threshold_min   => ref_values(1),
            threshold_max   => ref_values(2),
            reg_value       => data_out_matrix(2),
            data_out_left   => lefts(2), 
            data_out_right  => rights(2)
        );
        level2bisbis: temperature_register port map (
            reg_clk         => clockk,
            reg_r           => rs,
            measured_data   => lefts(5),
            threshold_min   => ref_values(3),
            threshold_max   => ref_values(4),
            reg_value       => data_out_matrix(4),
            data_out_left   => lefts(4), 
            data_out_right  => rights(4)
        );
        level2bisbisbis: temperature_register port map (
            reg_clk         => clockk,
            reg_r           => rs,
            measured_data   => rights(5),
            threshold_min   => ref_values(5),
            threshold_max   => ref_values(6),
            reg_value       => data_out_matrix(6),
            data_out_left   => lefts(6), 
            data_out_right  => rights(6)
        );
        
        --forth level -> extreme right
        
        level3: temperature_register port map (
            reg_clk         => clockk,
            reg_r           => rs,
            measured_data   => rights(6),
            threshold_min   => ref_values(6),
            threshold_max   => ref_values(7),
            reg_value       => data_out_matrix(7),
            data_out_left   => lefts(7), 
            data_out_right  => rights(7)
        );
   
    with select_bin select data_out_wrapper <= 
        data_out_matrix(0) when "000",
        data_out_matrix(1) when "001",
        data_out_matrix(2) when "010",
        data_out_matrix(3) when "011",
        data_out_matrix(4) when "100",
        data_out_matrix(5) when "101",
        data_out_matrix(6) when "110",
        data_out_matrix(7) when others;
        
    display: ssd_display
        port map(
            clk => clockk,
            number_in => data_out_wrapper,
            anodes => as,
            cathodes => cs
        );
    
end Behavioral;
