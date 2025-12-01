library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.soa_resource_pkg.all;

entity Sistema is
    port (
        clk       : in  std_logic;
        rst_n     : in  std_logic;

        sw        : in  std_logic_vector(9 downto 0);
        btn_req   : in  std_logic;
        btn_g1    : in  std_logic;
        btn_g2    : in  std_logic;
        btn_g3    : in  std_logic;

        leds      : out std_logic_vector(7 downto 0);

        hex0_seg  : out std_logic_vector(6 downto 0);

        hex2_seg  : out std_logic_vector(6 downto 0);
        hex3_seg  : out std_logic_vector(6 downto 0);
        hex4_seg  : out std_logic_vector(6 downto 0)
    );
end Sistema;


architecture rtl of Sistema is

    signal client_req_valid  : std_logic;
    signal client_req_id     : std_logic_vector(C_SERVICE_ID_WIDTH-1 downto 0);
    signal client_req_data   : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    signal broker_resp_valid : std_logic;
    signal broker_resp_data  : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    -- níveis exportados pelo client
    signal level_g1_dbg      : std_logic_vector(1 downto 0);
    signal level_g2_dbg      : std_logic_vector(1 downto 0);
    signal level_g3_dbg      : std_logic_vector(1 downto 0);

begin

    u_client : entity work.svc_client
        port map (
            clk            => clk,
            rst_n          => rst_n,
            sw             => sw,
            btn_req        => btn_req,
            btn_g1         => btn_g1,
            btn_g2         => btn_g2,
            btn_g3         => btn_g3,

            req_valid      => client_req_valid,
            req_service_id => client_req_id,
            req_data       => client_req_data,

            resp_valid     => broker_resp_valid,
            resp_data      => broker_resp_data,

            leds           => leds,

            level_g1_dbg   => level_g1_dbg,
            level_g2_dbg   => level_g2_dbg,
            level_g3_dbg   => level_g3_dbg
        );

    u_broker : entity work.svc_broker
        port map (
            clk            => clk,
            rst_n          => rst_n,
            req_valid      => client_req_valid,
            req_service_id => client_req_id,
            req_data       => client_req_data,
            resp_valid     => broker_resp_valid,
            resp_data      => broker_resp_data
        );

    u_disp_status : entity work.display_driver
        port map (
            risk_code => broker_resp_data(1 downto 0),
            seg       => hex0_seg
        );

    u_hex2 : entity work.lvl_display_7seg
        port map (
            en  => sw(2),
            lvl => level_g1_dbg,
            seg => hex2_seg
        );

    u_hex3 : entity work.lvl_display_7seg
        port map (
            en  => sw(3),
            lvl => level_g2_dbg,
            seg => hex3_seg
        );

    u_hex4 : entity work.lvl_display_7seg
        port map (
            en  => sw(4),
            lvl => level_g3_dbg,
            seg => hex4_seg
        );

end architecture rtl;
