library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package soa_resource_pkg is

    constant C_SERVICE_ID_WIDTH : integer := 2;
    constant C_DATA_WIDTH       : integer := 8;

    -- Nenhum serviço
    constant SVC_ID_NONE              : std_logic_vector(C_SERVICE_ID_WIDTH-1 downto 0) := "00";

    -- IDs de serviços válidos
    constant SVC_ID_RESOURCE_RISK     : std_logic_vector(C_SERVICE_ID_WIDTH-1 downto 0) := "01";
    constant SVC_ID_RESOURCE_PROFILE  : std_logic_vector(C_SERVICE_ID_WIDTH-1 downto 0) := "10";

    -- Códigos de risco (2 LSB)
    constant RISK_OK_CODE   : std_logic_vector(1 downto 0) := "00";
    constant RISK_WARN_CODE : std_logic_vector(1 downto 0) := "01";
    constant RISK_CRIT_CODE : std_logic_vector(1 downto 0) := "10";

end soa_resource_pkg;
