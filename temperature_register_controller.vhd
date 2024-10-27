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
        reg_add_one      : in std_logic;
        reg_value       : out std_logic_vector(15 downto 0)
    );
end component;

component demux is
Port(
    data_in: in std_logic;
    select_signal : in std_logic_vector(2 downto 0);
    data_out: out std_logic_vector(7 downto 0)
);
end component;

signal increment: std_logic_vector(0 to NO_BINS - 1) := (others => '0');

type matrix is array (0 to NO_BINS - 1) of std_logic_vector(15 downto 0);
signal m : matrix:= (others => x"0000");
signal ref_value1 : std_logic_vector(15 downto 0) := x"53C9"; --14 deg C
signal ref_value2 : std_logic_vector(15 downto 0) := x"56E3"; --16 deg C
signal ref_value3 : std_logic_vector(15 downto 0) := x"59FD"; --18 deg C
signal ref_value4 : std_logic_vector(15 downto 0) := x"5D18"; --20 deg C
signal ref_value5 : std_logic_vector(15 downto 0) := x"6032"; --22 deg C
signal ref_value6 : std_logic_vector(15 downto 0) := x"634D"; --24 deg C
signal ref_value7 : std_logic_vector(15 downto 0) := x"6667"; --26 deg C
signal wrapper : std_logic_vector(15 downto 0);
signal comparison_signal: std_logic_vector(2 downto 0);
signal clk: std_logic;
signal data_out_wrapper: std_logic_vector(15 downto 0);

begin
    f_divider: process(clockk, rs)
        variable aux : std_logic_vector(23 downto 0) := x"000000";
    begin
        if(rs = '0') then
            aux := x"000000";
        elsif(rising_edge(clockk)) then
            aux := aux + 1;
        end if;            
        clk <= aux(23);
    end process;
    
    wrapper <= raw_data & "00";
    generate_registers: for i in 0 to NO_BINS - 1 generate
        registerI: temperature_register
                    port map(
                        reg_clk => clk,
                        reg_r => rs,
                        reg_add_one => increment(i),
                        reg_value => m(i)
                    );
    end generate;
    
    register_demux: demux 
        port map(
            data_in => '1',
            select_signal => comparison_signal,
            data_out => increment
        );
    
    compare_process: process(clk)
    begin
        if rising_edge(clk) then
            if (unsigned(wrapper) < unsigned(ref_value1)) then
                comparison_signal <= "000";
            elsif (unsigned(wrapper) < unsigned(ref_value2)) then
                comparison_signal <= "001";
            elsif (unsigned(wrapper) < unsigned(ref_value3)) then
                comparison_signal <= "010";
            elsif (unsigned(wrapper) < unsigned(ref_value4)) then
                comparison_signal <= "011";
            elsif (unsigned(wrapper) < unsigned(ref_value5)) then
                comparison_signal <= "100";
            elsif (unsigned(wrapper) < unsigned(ref_value6)) then
                comparison_signal <= "101";
            elsif (unsigned(wrapper) < unsigned(ref_value7)) then
                comparison_signal <= "110";
            else
                comparison_signal <= "111";
            end if; 
        end if;
    end process;

    with select_bin select data_out_wrapper <= 
        m(0) when "000",
        m(1) when "001",
        m(2) when "010",
        m(3) when "011",
        m(4) when "100",
        m(5) when "101",
        m(6) when "110",
        m(7) when others;
    
    display: ssd_display
        port map(
            clk => clockk,
            number_in => data_out_wrapper,
            anodes => as,
            cathodes => cs
        );
    
end Behavioral;
