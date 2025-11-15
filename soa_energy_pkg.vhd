library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package soa_energy_pkg is

    --------------------------------------------------------------------
    -- Larguras básicas
    --------------------------------------------------------------------
    constant C_NUM_SERVICES      : integer := 8;
    constant C_SERVICE_ID_WIDTH  : integer := 4;   -- suporta até 16 serviços
    constant C_DATA_WIDTH        : integer := 8;  -- largura padrão para dados

    --------------------------------------------------------------------
    -- IDs de serviço (exemplo)
    --------------------------------------------------------------------
    constant SVC_ID_INSTANT_PROFILE  : std_logic_vector(C_SERVICE_ID_WIDTH-1 downto 0) := "0010";
    constant SVC_ID_RISK_ANALYSIS    : std_logic_vector(C_SERVICE_ID_WIDTH-1 downto 0) := "0001";
    constant SVC_ID_RECOMMENDATION   : std_logic_vector(C_SERVICE_ID_WIDTH-1 downto 0) := "0011";

    --------------------------------------------------------------------
    -- Tipo de risco (OK / ALERTA / CRÍTICO)
    --------------------------------------------------------------------
    type t_risk_level is (RISK_OK, RISK_WARN, RISK_CRIT);

    --------------------------------------------------------------------
    -- Tipo genérico para resposta de serviço
    --------------------------------------------------------------------
    type t_service_response is record
        data     : std_logic_vector(C_DATA_WIDTH-1 downto 0);
        risk     : t_risk_level;
        valid    : std_logic;
    end record;

end soa_energy_pkg;
