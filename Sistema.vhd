library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.soa_resource_pkg.all;

entity Sistema is
    port (
        clk       : in  std_logic;
        rst_n     : in  std_logic;

        -- Entradas físicas (ajuste tamanhos conforme sua placa)
        sw        : in  std_logic_vector(9 downto 0);
        btn_req   : in  std_logic;

        -- Displays / LEDs
        leds      : out std_logic_vector(7 downto 0);
        disp7_an  : out std_logic_vector(3 downto 0);
        disp7_seg : out std_logic_vector(6 downto 0)
    );
end Sistema;

architecture rtl of Sistema is

    --------------------------------------------------------------------
    -- Sinais internos (Client ↔ Broker)
    --------------------------------------------------------------------
    signal client_req_valid   : std_logic;
    signal client_req_id      : std_logic_vector(C_SERVICE_ID_WIDTH-1 downto 0);
    signal client_req_data    : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    signal broker_resp_valid  : std_logic;
    signal broker_resp_data   : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    -- se quiser, sinais mais ricos podem ser usados (record de resposta etc.)
	 
	 signal disp_data : std_logic_vector(7 downto 0);

begin

    --------------------------------------------------------------------
    -- Instância do SERVICE REQUESTER (CLIENT)
    --------------------------------------------------------------------
    u_client : entity work.svc_client
        port map (
            clk            => clk,
            rst_n          => rst_n,

            -- Entradas físicas
            sw             => sw,
            btn_req        => btn_req,

            -- Interface com Broker
            req_valid      => client_req_valid,
            req_service_id => client_req_id,
            req_data       => client_req_data,

            resp_valid     => broker_resp_valid,
            resp_data      => broker_resp_data,

            -- Saídas para usuário (exemplo: LEDs de status)
            leds           => leds
        );

    --------------------------------------------------------------------
    -- Instância do SERVICE REGISTRY / BROKER
    --------------------------------------------------------------------
    u_broker : entity work.svc_broker
        port map (
            clk            => clk,
            rst_n          => rst_n,

            -- Interface com Client
            req_valid      => client_req_valid,
            req_service_id => client_req_id,
            req_data       => client_req_data,

            resp_valid     => broker_resp_valid,
            resp_data      => broker_resp_data

            -- Aqui ainda vão as interfaces com os serviços (svc_xxx)
        );
		
	 disp_data <= broker_resp_data;   -- mostra resposta do serviço no display
	 
	 u_disp : entity work.display_driver
    port map (
        clk   => clk,
        rst_n => rst_n,
        data8 => disp_data,
        an    => disp7_an,
        seg   => disp7_seg
    );


end architecture rtl;
