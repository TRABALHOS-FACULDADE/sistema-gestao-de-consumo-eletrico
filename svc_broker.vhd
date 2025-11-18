library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.soa_resource_pkg.all;

entity svc_broker is
    port (
        clk            : in  std_logic;
        rst_n          : in  std_logic;

        -- Interface com Client
        req_valid      : in  std_logic;
        req_service_id : in  std_logic_vector(C_SERVICE_ID_WIDTH-1 downto 0);
        req_data       : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);

        resp_valid     : out std_logic;
        resp_data      : out std_logic_vector(C_DATA_WIDTH-1 downto 0)
    );
end svc_broker;

architecture rtl of svc_broker is

    type t_state is (ST_IDLE, ST_DECODE, ST_DISPATCH, ST_WAIT_SVC, ST_RETURN_RESP, ST_ERROR);
    signal state, next_state : t_state;

    --------------------------------------------------------------------
    -- Sinais para svc_resource_risk
    --------------------------------------------------------------------
    signal svc_risk_req      : std_logic;
    signal svc_risk_busy     : std_logic;
    signal svc_risk_done     : std_logic;
    signal svc_risk_data_in  : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal svc_risk_data_out : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    --------------------------------------------------------------------
    -- Sinais para svc_resource_profile
    --------------------------------------------------------------------
    signal svc_prof_req      : std_logic;
    signal svc_prof_busy     : std_logic;
    signal svc_prof_done     : std_logic;
    signal svc_prof_data_in  : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal svc_prof_data_out : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    --------------------------------------------------------------------
    -- Registradores internos
    --------------------------------------------------------------------
    signal reg_service_id : std_logic_vector(C_SERVICE_ID_WIDTH-1 downto 0);
    signal reg_req_data   : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal reg_resp_data  : std_logic_vector(C_DATA_WIDTH-1 downto 0);

begin

    --------------------------------------------------------------------
    -- Instância de svc_resource_risk
    --------------------------------------------------------------------
    u_svc_risk : entity work.svc_resource_risk
        port map (
            clk      => clk,
            rst_n    => rst_n,
            req      => svc_risk_req,
            busy     => svc_risk_busy,
            done     => svc_risk_done,
            data_in  => svc_risk_data_in,
            data_out => svc_risk_data_out
        );

    --------------------------------------------------------------------
    -- Instância de svc_resource_profile
    --------------------------------------------------------------------
    u_svc_prof : entity work.svc_resource_profile
        port map (
            clk      => clk,
            rst_n    => rst_n,
            req      => svc_prof_req,
            busy     => svc_prof_busy,
            done     => svc_prof_done,
            data_in  => svc_prof_data_in,
            data_out => svc_prof_data_out
        );

    --------------------------------------------------------------------
    -- Registradores de entrada e resposta
    --------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            reg_service_id <= (others => '0');
            reg_req_data   <= (others => '0');
            reg_resp_data  <= (others => '0');
        elsif rising_edge(clk) then

            -- Captura requisição do Client
            if (state = ST_IDLE) and (req_valid = '1') then
                reg_service_id <= req_service_id;
                reg_req_data   <= req_data;
            end if;

            -- Captura resposta do serviço selecionado
            if (state = ST_WAIT_SVC) then
                if (reg_service_id = SVC_ID_RESOURCE_RISK) and (svc_risk_done = '1') then
                    reg_resp_data <= svc_risk_data_out;
                elsif (reg_service_id = SVC_ID_RESOURCE_PROFILE) and (svc_prof_done = '1') then
                    reg_resp_data <= svc_prof_data_out;
                end if;
            end if;

        end if;
    end process;

    --------------------------------------------------------------------
    -- Registrador de estado da FSM
    --------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state <= ST_IDLE;
        elsif rising_edge(clk) then
            state <= next_state;
        end if;
    end process;

    --------------------------------------------------------------------
    -- FSM combinacional do Broker
    --------------------------------------------------------------------
    process(state, req_valid, reg_service_id,
            svc_risk_done, svc_prof_done, reg_resp_data)
    begin
        -- Defaults
        resp_valid <= '0';
        resp_data  <= reg_resp_data;

        svc_risk_req     <= '0';
        svc_risk_data_in <= reg_req_data;

        svc_prof_req     <= '0';
        svc_prof_data_in <= reg_req_data;

        next_state       <= state;

        case state is

            ----------------------------------------------------------------
            when ST_IDLE =>
                if req_valid = '1' then
                    next_state <= ST_DECODE;
                end if;

            ----------------------------------------------------------------
            when ST_DECODE =>
                if (reg_service_id = SVC_ID_RESOURCE_RISK) or
                   (reg_service_id = SVC_ID_RESOURCE_PROFILE) then
                    next_state <= ST_DISPATCH;
                else
                    next_state <= ST_ERROR;
                end if;

            ----------------------------------------------------------------
            when ST_DISPATCH =>
                -- Um único ciclo de req para o serviço correspondente
                if reg_service_id = SVC_ID_RESOURCE_RISK then
                    svc_risk_req     <= '1';
                    svc_risk_data_in <= reg_req_data;
                    next_state       <= ST_WAIT_SVC;

                elsif reg_service_id = SVC_ID_RESOURCE_PROFILE then
                    svc_prof_req     <= '1';
                    svc_prof_data_in <= reg_req_data;
                    next_state       <= ST_WAIT_SVC;

                else
                    next_state       <= ST_ERROR;
                end if;

            ----------------------------------------------------------------
            when ST_WAIT_SVC =>
                if (reg_service_id = SVC_ID_RESOURCE_RISK) and (svc_risk_done = '1') then
                    next_state <= ST_RETURN_RESP;
                elsif (reg_service_id = SVC_ID_RESOURCE_PROFILE) and (svc_prof_done = '1') then
                    next_state <= ST_RETURN_RESP;
                end if;

            ----------------------------------------------------------------
            when ST_RETURN_RESP =>
                resp_valid <= '1';
                resp_data  <= reg_resp_data;
                next_state <= ST_IDLE;

            ----------------------------------------------------------------
            when ST_ERROR =>
                resp_valid <= '1';
                resp_data  <= (others => '1');  -- código de erro simples
                next_state <= ST_IDLE;

            ----------------------------------------------------------------
            when others =>
                next_state <= ST_IDLE;

        end case;
    end process;

end architecture rtl;
