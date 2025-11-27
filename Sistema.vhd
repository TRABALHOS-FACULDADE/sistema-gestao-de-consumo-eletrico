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

        -- HEX0: status (OK/AL/CR)
        hex0_seg  : out std_logic_vector(6 downto 0);

        -- HEX2, HEX3, HEX4: níveis dos grupos 1, 2 e 3
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

    -- função auxiliar para converter 0..3 em 7 segmentos (ativo em 0)
    function lvl_to_7seg(lvl : std_logic_vector(1 downto 0))
        return std_logic_vector is
        variable seg : std_logic_vector(6 downto 0);
    begin
        case lvl is
            when "00" => seg := "1000000"; -- 0
            when "01" => seg := "1111001"; -- 1
            when "10" => seg := "0100100"; -- 2
            when others => seg := "0110000"; -- 3
        end case;
        return seg;
    end function;

begin

    --------------------------------------------------------------------
    -- CLIENT
    --------------------------------------------------------------------
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

    --------------------------------------------------------------------
    -- BROKER
    --------------------------------------------------------------------
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

    --------------------------------------------------------------------
    -- HEX0: status do sistema (OK/AL/CR)
    --------------------------------------------------------------------
    u_disp_status : entity work.display_driver
        port map (
            risk_code => broker_resp_data(1 downto 0),
            seg       => hex0_seg
        );

    --------------------------------------------------------------------
    -- HEX2: nível do Grupo 1 (mostra 0..3 quando SW2=1, apaga se SW2=0)
    --------------------------------------------------------------------
    process(sw(2), level_g1_dbg)
    begin
        if sw(2) = '1' then
            hex2_seg <= lvl_to_7seg(level_g1_dbg);
        else
            hex2_seg <= (others => '1'); -- tudo apagado (ativo em 0)
        end if;
    end process;

    --------------------------------------------------------------------
    -- HEX3: nível do Grupo 2
    --------------------------------------------------------------------
    process(sw(3), level_g2_dbg)
    begin
        if sw(3) = '1' then
            hex3_seg <= lvl_to_7seg(level_g2_dbg);
        else
            hex3_seg <= (others => '1');
        end if;
    end process;

    --------------------------------------------------------------------
    -- HEX4: nível do Grupo 3
    --------------------------------------------------------------------
    process(sw(4), level_g3_dbg)
    begin
        if sw(4) = '1' then
            hex4_seg <= lvl_to_7seg(level_g3_dbg);
        else
            hex4_seg <= (others => '1');
        end if;
    end process;

end architecture rtl;
