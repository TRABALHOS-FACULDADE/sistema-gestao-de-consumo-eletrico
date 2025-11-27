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
        btn_req        : in  std_logic;  -- KEY0
        btn_g1         : in  std_logic;  -- KEY1
        btn_g2         : in  std_logic;  -- KEY2
        btn_g3         : in  std_logic;  -- KEY3

        -- Interface com Broker
        req_valid      : out std_logic;
        req_service_id : out std_logic_vector(C_SERVICE_ID_WIDTH-1 downto 0);
        req_data       : out std_logic_vector(C_DATA_WIDTH-1 downto 0);

        -- Retorno do Broker
        resp_valid     : in  std_logic;
        resp_data      : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);

        -- Saída para feedback (STATUS nos LEDs)
        leds           : out std_logic_vector(7 downto 0);

        -- DEBUG: níveis dos grupos (para displays HEX2/3/4)
        level_g1_dbg   : out std_logic_vector(1 downto 0);
        level_g2_dbg   : out std_logic_vector(1 downto 0);
        level_g3_dbg   : out std_logic_vector(1 downto 0)
    );
end svc_client;

architecture rtl of svc_client is

    type t_state is (ST_IDLE, ST_CAPTURE, ST_SEND_REQ, ST_WAIT_RESP, ST_SHOW_RESP);
    signal state, next_state : t_state;

    -- Níveis internos
    signal level_g1 : std_logic_vector(1 downto 0) := "00";
    signal level_g2 : std_logic_vector(1 downto 0) := "00";
    signal level_g3 : std_logic_vector(1 downto 0) := "00";

    -- Sincronização de botões
    signal s_req_0, s_req_1 : std_logic;
    signal s_g1_0,  s_g1_1  : std_logic;
    signal s_g2_0,  s_g2_1  : std_logic;
    signal s_g3_0,  s_g3_1  : std_logic;

    signal edge_req : std_logic;
    signal edge_g1  : std_logic;
    signal edge_g2  : std_logic;
    signal edge_g3  : std_logic;

    -- Registradores de requisição / resposta
    signal reg_service_id : std_logic_vector(C_SERVICE_ID_WIDTH-1 downto 0);
    signal reg_req_data   : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal reg_resp_data  : std_logic_vector(C_DATA_WIDTH-1 downto 0);
	 
	 signal reg_status : std_logic_vector(1 downto 0) := RISK_OK_CODE;

begin

    --------------------------------------------------------------------
    -- Sincronização (KEYs ativas em 0) e detecção de borda de DESCIDA
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

            s_g1_0  <= btn_g1;
            s_g1_1  <= s_g1_0;

            s_g2_0  <= btn_g2;
            s_g2_1  <= s_g2_0;

            s_g3_0  <= btn_g3;
            s_g3_1  <= s_g3_0;
        end if;
    end process;

    edge_req <= s_req_1 and (not s_req_0); -- 1->0
    edge_g1  <= s_g1_1  and (not s_g1_0);
    edge_g2  <= s_g2_1  and (not s_g2_0);
    edge_g3  <= s_g3_1  and (not s_g3_0);

    -- Atualiza níveis dos grupos (0..3)
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            level_g1 <= "00";
            level_g2 <= "00";
            level_g3 <= "00";
        elsif rising_edge(clk) then

            if (edge_g1 = '1') and (sw(2) = '1') then
                if level_g1 = "11" then
                    level_g1 <= "00";
                else
                    level_g1 <= std_logic_vector(unsigned(level_g1) + 1);
                end if;
            end if;

            if (edge_g2 = '1') and (sw(3) = '1') then
                if level_g2 = "11" then
                    level_g2 <= "00";
                else
                    level_g2 <= std_logic_vector(unsigned(level_g2) + 1);
                end if;
            end if;

            if (edge_g3 = '1') and (sw(4) = '1') then
                if level_g3 = "11" then
                    level_g3 <= "00";
                else
                    level_g3 <= std_logic_vector(unsigned(level_g3) + 1);
                end if;
            end if;

        end if;
    end process;

    -- Exporta níveis para debug
    level_g1_dbg <= level_g1;
    level_g2_dbg <= level_g2;
    level_g3_dbg <= level_g3;

    -- Registradores de requisição / resposta + estado
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            reg_service_id <= (others => '0');
            reg_req_data   <= (others => '0');
            reg_resp_data  <= (others => '0');
            state          <= ST_IDLE;
        elsif rising_edge(clk) then
            state <= next_state;

            if (state = ST_CAPTURE) then
                reg_service_id <= (others => '0');
                reg_service_id(1 downto 0) <= sw(1 downto 0); -- serviço em SW1..SW0

                reg_req_data(1 downto 0) <= level_g1;
                reg_req_data(3 downto 2) <= level_g2;
                reg_req_data(5 downto 4) <= level_g3;
                reg_req_data(7 downto 6) <= sw(6 downto 5);   -- modo/política
            end if;

            if (state = ST_WAIT_RESP) and (resp_valid = '1') then
                reg_resp_data <= resp_data;
					 reg_status    <= resp_data(1 downto 0);
            end if;
        end if;
    end process;

    -- FSM do client
    process(state, edge_req, resp_valid, reg_resp_data)
    begin
         leds           <= (others => '0');
			req_valid      <= '0';
			req_service_id <= reg_service_id;
			req_data       <= reg_req_data;
			next_state     <= state;

			-- LEDs permanentes baseados no reg_status
			case reg_status is
				 when RISK_OK_CODE   => leds(0) <= '1';          -- LED0 = OK
				 when RISK_WARN_CODE => leds(1) <= '1';          -- LED1 = ALERTA
				 when RISK_CRIT_CODE => leds(2) <= '1';          -- LED2 = CRÍTICO
				 when others         => leds    <= (others=>'1');-- erro
			end case;

			-- E a FSM fica só para controlar req/resp, sem mexer nos LEDs
			case state is
				 when ST_IDLE =>
					  if edge_req = '1' then
							next_state <= ST_CAPTURE;
					  end if;

				 when ST_CAPTURE =>
					  next_state <= ST_SEND_REQ;

				 when ST_SEND_REQ =>
					  req_valid  <= '1';
					  next_state <= ST_WAIT_RESP;

				 when ST_WAIT_RESP =>
					  if resp_valid = '1' then
							next_state <= ST_SHOW_RESP;
					  end if;

				 when ST_SHOW_RESP =>
					  next_state <= ST_IDLE;

				 when others =>
					  next_state <= ST_IDLE;
end case;
    end process;

end architecture rtl;
