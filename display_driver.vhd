library ieee;
use ieee.std_logic_1164.all;

entity display_driver is
    port(
        risk_code : in  std_logic_vector(1 downto 0);
        seg       : out std_logic_vector(6 downto 0)
    );
end display_driver;

architecture rtl of display_driver is
begin
	with risk_code select seg <= 
	"1000000" when "00",   -- O (Ok)
	"0001000" when "01",   -- A (Alerta)
	"1000110" when "10",   -- C (Crítico)
	"0000110" when others; -- E (Erro)
end architecture rtl;
