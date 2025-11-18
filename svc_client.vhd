library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.soa_resource_pkg.all;

entity svc_client is
    port (
        clk            : in  std_logic;
        rst_n          : in  std_logic;

        -- Entradas físicas
        sw             : in  std_logic_vector(9 downto 0);
        btn_req        : in  std_logic;

        -- Interface com Broker
        req_valid      : out std_logic;
        req_service_id : out std_logic_vector(C_SERVICE_ID_WIDTH-1 downto 0);
        req_data       : out std_logic_vector(C_DATA_WIDTH-1 downto 0);

        resp_valid     : in  std_logic;
        resp_data      : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);

        -- Saída simples para feedback
        leds           : out std_logic_vector(7 downto 0)
    );
end svc_client;

architecture rtl of svc_client is

	 signal btn_pressed : std_logic;

    type t_state is (ST_IDLE, ST_CAPTURE, ST_SEND_REQ, ST_WAIT_RESP, ST_SHOW_RESP);
    signal state, next_state : t_state;

    -- sincronização do botão
    signal btn_sync0, btn_sync1 : std_logic;
    signal btn_req_edge         : std_logic;

    -- registradores internos
    signal reg_service_id    : std_logic_vector(C_SERVICE_ID_WIDTH-1 downto 0);
    signal reg_req_data      : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal reg_resp_data     : std_logic_vector(C_DATA_WIDTH-1 downto 0);

begin

    --------------------------------------------------------------------
    -- Registrador de estado (FSM)
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
    -- Sincronizador e detecção de borda do btn_req
    --------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            btn_sync0 <= '0';
            btn_sync1 <= '0';
        elsif rising_edge(clk) then
            btn_sync0 <= btn_req;
            btn_sync1 <= btn_sync0;
        end if;
    end process;

    btn_req_edge <= btn_sync0 and not btn_sync1;
	 btn_pressed <= not btn_sync1;  -- KEY ativo em 0 -> pressed = 1 quando botão apertado

    --------------------------------------------------------------------
    -- FSM combinacional: próxima transição e saídas
    --------------------------------------------------------------------
    process(state, btn_req_edge, resp_valid, reg_service_id, reg_req_data, reg_resp_data)
    begin
        -- valores default
        req_valid      <= '0';
        req_service_id <= reg_service_id;  -- sempre dirigidos pelos registradores
        req_data       <= reg_req_data;
        leds           <= (others => '0');
        next_state     <= state;

        case state is

            when ST_IDLE =>
                leds(0) <= '1';  -- indica IDLE
                if btn_pressed = '1' then
                    next_state <= ST_CAPTURE;
                end if;

            when ST_CAPTURE =>
                -- nada nas saídas ainda; apenas aguardamos o clock registrar sw
                leds(2) <= '1';
                next_state <= ST_SEND_REQ;

            when ST_SEND_REQ =>
                req_valid  <= '1';   -- 1 ciclo de requisição
                leds(3)    <= '1';   -- indica envio
                next_state <= ST_WAIT_RESP;

            when ST_WAIT_RESP =>
                leds(1) <= '1';      -- aguardando resposta
                if resp_valid = '1' then
                    next_state <= ST_SHOW_RESP;
                end if;

            when ST_SHOW_RESP =>
                leds <= reg_resp_data(7 downto 0); -- mostra resp armazenada
                next_state <= ST_IDLE;

            when others =>
                next_state <= ST_IDLE;

        end case;
    end process;

    --------------------------------------------------------------------
    -- Registradores de entrada (SERVICE_ID, DATA) e resposta
    --------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            reg_service_id <= (others => '0');
            reg_req_data   <= (others => '0');
            reg_resp_data  <= (others => '0');
        elsif rising_edge(clk) then
            -- captura SERVICE_ID e DATA quando entramos em ST_CAPTURE
            if state = ST_IDLE and btn_pressed = '1' then
                reg_service_id <= sw(3 downto 0);         -- SERVICE_ID
                reg_req_data   <= "00" & sw(9 downto 4);  -- DATA (6 bits + padding)
            end if;

            -- captura resposta vinda do Broker
            if (state = ST_WAIT_RESP) and (resp_valid = '1') then
                reg_resp_data <= resp_data;
            end if;
        end if;
    end process;

end architecture rtl;
