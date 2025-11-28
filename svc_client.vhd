library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.soa_resource_pkg.all;

entity svc_client is
    port (
        clk            : in  std_logic;
        rst_n          : in  std_logic;

        sw             : in  std_logic_vector(9 downto 0);
        btn_req        : in  std_logic;
        btn_g1         : in  std_logic;
        btn_g2         : in  std_logic;
        btn_g3         : in  std_logic;

        req_valid      : out std_logic;
        req_service_id : out std_logic_vector(C_SERVICE_ID_WIDTH-1 downto 0);
        req_data       : out std_logic_vector(C_DATA_WIDTH-1 downto 0);

        resp_valid     : in  std_logic;
        resp_data      : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);

        leds           : out std_logic_vector(7 downto 0);

        level_g1_dbg   : out std_logic_vector(1 downto 0);
        level_g2_dbg   : out std_logic_vector(1 downto 0);
        level_g3_dbg   : out std_logic_vector(1 downto 0)
    );
end svc_client;

architecture rtl of svc_client is

    --------------------------------------------------------------------
    -- FSMs usadas
    --------------------------------------------------------------------
    type t_client_state is (ST_IDLE, ST_CAPTURE, ST_SEND_REQ, ST_WAIT_RESP, ST_SHOW_RESP);
    signal client_state, client_next : t_client_state;

    type t_level_state is (LV_IDLE, LV_WAIT_RELEASE);
    signal lvl_state, lvl_next : t_level_state;

    --------------------------------------------------------------------
    -- Níveis internos
    --------------------------------------------------------------------
    signal level_g1 : std_logic_vector(1 downto 0) := "00";
    signal level_g2 : std_logic_vector(1 downto 0) := "00";
    signal level_g3 : std_logic_vector(1 downto 0) := "00";

    --------------------------------------------------------------------
    -- Botões sincronizados para incremento
    --------------------------------------------------------------------
    signal s_g1_0, s_g1_1 : std_logic;
    signal s_g2_0, s_g2_1 : std_logic;
    signal s_g3_0, s_g3_1 : std_logic;

    signal edge_g1, edge_g2, edge_g3 : std_logic;

    --------------------------------------------------------------------
    -- Botão de requisição
    --------------------------------------------------------------------
    signal s_req_0, s_req_1 : std_logic;
    signal edge_req : std_logic;

    --------------------------------------------------------------------
    -- Dados de requisição e resposta
    --------------------------------------------------------------------
    signal reg_service_id : std_logic_vector(C_SERVICE_ID_WIDTH-1 downto 0);
    signal reg_req_data   : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal reg_resp_data  : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    signal reg_status : std_logic_vector(1 downto 0) := RISK_OK_CODE;

begin

    --------------------------------------------------------------------
    -- Sincronização dos botões (KEYs são ativas em 0)
    --------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            s_req_0 <= '1'; s_req_1 <= '1';
            s_g1_0  <= '1'; s_g1_1  <= '1';
            s_g2_0  <= '1'; s_g2_1  <= '1';
            s_g3_0  <= '1'; s_g3_1  <= '1';

        elsif rising_edge(clk) then
            s_req_0 <= btn_req;
            s_req_1 <= s_req_0;

            s_g1_0 <= btn_g1;  s_g1_1 <= s_g1_0;
            s_g2_0 <= btn_g2;  s_g2_1 <= s_g2_0;
            s_g3_0 <= btn_g3;  s_g3_1 <= s_g3_0;
        end if;
    end process;

    edge_req <= s_req_1 and (not s_req_0);
    edge_g1  <= s_g1_1 and (not s_g1_0);
    edge_g2  <= s_g2_1 and (not s_g2_0);
    edge_g3  <= s_g3_1 and (not s_g3_0);

    --------------------------------------------------------------------
    -- NOVA FSM: Controle de incremento dos níveis
    --------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            lvl_state <= LV_IDLE;
        elsif rising_edge(clk) then
            lvl_state <= lvl_next;
        end if;
    end process;

    process(lvl_state, edge_g1, edge_g2, edge_g3, sw)
    begin
        lvl_next <= lvl_state;

        case lvl_state is
            ------------------------------------------------------------
            when LV_IDLE =>
                if (edge_g1 = '1' and sw(2) = '1') or
                   (edge_g2 = '1' and sw(3) = '1') or
                   (edge_g3 = '1' and sw(4) = '1') then
                    lvl_next <= LV_WAIT_RELEASE;
                end if;

            ------------------------------------------------------------
            when LV_WAIT_RELEASE =>
                -- volta quando todos forem liberados
                if (btn_g1='1' and btn_g2='1' and btn_g3='1') then
                    lvl_next <= LV_IDLE;
                end if;
        end case;
    end process;

    --------------------------------------------------------------------
    -- Lógica síncrona de incremento (somente quando entra em LV_WAIT_RELEASE)
    --------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            level_g1 <= "00";
            level_g2 <= "00";
            level_g3 <= "00";

        elsif rising_edge(clk) then
            if lvl_state = LV_IDLE and lvl_next = LV_WAIT_RELEASE then

                if edge_g1 = '1' and sw(2)='1' then
						  if sw(7) = '1' then
								if level_g1 = "11" then level_g1 <= "00";
								else level_g1 <= std_logic_vector(unsigned(level_g1)+1);
								end if;
							else
								if level_g1 = "00" then level_g1 <= "11";
								else level_g1 <= std_logic_vector(unsigned(level_g1)-1);
								end if;
                    end if;
                end if;

                if edge_g2 = '1' and sw(3)='1' then
                    if sw(7) = '1' then
								if level_g2 = "11" then level_g2 <= "00";
								else level_g2 <= std_logic_vector(unsigned(level_g2)+1);
								end if;
							else
								if level_g2 = "00" then level_g2 <= "11";
								else level_g2 <= std_logic_vector(unsigned(level_g2)-1);
								end if;
                    end if;
                end if;

                if edge_g3 = '1' and sw(4)='1' then
                    if sw(7) = '1' then
								if level_g3 = "11" then level_g3 <= "00";
								else level_g3 <= std_logic_vector(unsigned(level_g3)+1);
								end if;
							else
								if level_g3 = "00" then level_g3 <= "11";
								else level_g3 <= std_logic_vector(unsigned(level_g3)-1);
								end if;
                    end if;
                end if;

            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Exporta níveis para debug
    --------------------------------------------------------------------
    level_g1_dbg <= level_g1;
    level_g2_dbg <= level_g2;
    level_g3_dbg <= level_g3;

    --------------------------------------------------------------------
    -- FSM PRINCIPAL (client → broker → client)
    --------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n='0' then
            client_state <= ST_IDLE;
            reg_status   <= RISK_OK_CODE;

        elsif rising_edge(clk) then
            client_state <= client_next;

            if client_state = ST_CAPTURE then
                reg_service_id <= sw(1 downto 0);

                reg_req_data(1 downto 0) <= level_g1;
                reg_req_data(3 downto 2) <= level_g2;
                reg_req_data(5 downto 4) <= level_g3;
                reg_req_data(7 downto 6) <= sw(6 downto 5);
            end if;

            if client_state = ST_WAIT_RESP and resp_valid='1' then
                reg_resp_data <= resp_data;
                reg_status    <= resp_data(1 downto 0);
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Combinação da FSM PRINCIPAL
    --------------------------------------------------------------------
    process(client_state, edge_req, resp_valid, reg_status)
    begin
        req_valid      <= '0';
        req_service_id <= reg_service_id;
        req_data       <= reg_req_data;

        leds <= (others=>'0');

        case reg_status is
            when RISK_OK_CODE   => leds(0) <= '1';
            when RISK_WARN_CODE => leds(1) <= '1';
            when RISK_CRIT_CODE => leds(2) <= '1';
            when others         => leds    <= (others=>'1');
        end case;

        client_next <= client_state;

        case client_state is
            when ST_IDLE =>
                if edge_req='1' then client_next <= ST_CAPTURE; end if;

            when ST_CAPTURE =>
                client_next <= ST_SEND_REQ;

            when ST_SEND_REQ =>
                req_valid  <= '1';
                client_next <= ST_WAIT_RESP;

            when ST_WAIT_RESP =>
                if resp_valid='1' then client_next <= ST_SHOW_RESP; end if;

            when ST_SHOW_RESP =>
                client_next <= ST_IDLE;

        end case;
    end process;

end architecture rtl;
