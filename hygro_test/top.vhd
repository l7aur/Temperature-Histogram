----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11.10.2024 15:45:28
-- Design Name: 
-- Module Name: top - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
X

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity top is
    Port(
    clk :  in std_logic;
    reset: in std_logic;
    t : out std_logic_vector(13 downto 0);
--    h : out std_logic_vector(13 downto 0);
    ack: out std_logic;
    hygro_scl                               : INOUT STD_LOGIC;
    hygro_sda                               : INOUT STD_LOGIC
    );
end top;

architecture Behavioral of top is

COMPONENT pmod_hygrometer IS
  GENERIC(
    sys_clk_freq            : INTEGER := 5_000;        --input clock speed from user logic in Hz
    humidity_resolution     : INTEGER RANGE 0 TO 14 := 14;  --RH resolution in bits (must be 14, 11, or 8)
    temperature_resolution  : INTEGER RANGE 0 TO 14 := 14); --temperature resolution in bits (must be 14 or 11)
  PORT(
    clk               : IN    STD_LOGIC;                                            --system clock
    reset_n           : IN    STD_LOGIC;                                            --asynchronous active-low reset
    scl               : INOUT STD_LOGIC;                                            --I2C serial clock
    sda               : INOUT STD_LOGIC;                                            --I2C serial data
    i2c_ack_err       : OUT   STD_LOGIC;                                            --I2C slave acknowledge error flag
    relative_humidity : OUT   STD_LOGIC_VECTOR(humidity_resolution-1 DOWNTO 0);     --relative humidity data obtained
    temperature       : OUT   STD_LOGIC_VECTOR(temperature_resolution-1 DOWNTO 0)); --temperature data obtained
END COMPONENT;
signal h : std_logic_vector(13 downto 0);


begin
    aa: pmod_hygrometer 
    generic map(sys_clk_freq => 50_000_000, humidity_resolution => 14, temperature_resolution => 14)
    port map(clk => clk, reset_n => reset, scl => hygro_scl, sda =>hygro_sda, i2c_ack_err => ack, relative_humidity => h, temperature => t);

end Behavioral;
