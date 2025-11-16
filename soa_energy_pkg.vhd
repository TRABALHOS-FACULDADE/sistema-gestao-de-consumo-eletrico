library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package soa_energy_pkg is

    constant C_SERVICE_ID_WIDTH : integer := 4;
    constant C_DATA_WIDTH       : integer := 8;

    -- IDs de serviços
    constant SVC_ID_RISK_ANALYSIS   : std_logic_vector(C_SERVICE_ID_WIDTH-1 downto 0) := "0001";
    constant SVC_ID_INSTANT_PROFILE : std_logic_vector(C_SERVICE_ID_WIDTH-1 downto 0) := "0010";
    constant SVC_ID_RECOMMENDATION  : std_logic_vector(C_SERVICE_ID_WIDTH-1 downto 0) := "0011";

    -- Códigos de risco (2 LSB de uma palavra de 8 bits)
    constant RISK_OK_CODE   : std_logic_vector(1 downto 0) := "00";
    constant RISK_WARN_CODE : std_logic_vector(1 downto 0) := "01";
    constant RISK_CRIT_CODE : std_logic_vector(1 downto 0) := "10";

end soa_energy_pkg;
