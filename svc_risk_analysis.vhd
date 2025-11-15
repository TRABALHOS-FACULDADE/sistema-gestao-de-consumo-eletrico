library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.soa_energy_pkg.all;

entity svc_risk_analysis is
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;

        -- Interface com Broker
        req      : in  std_logic;  -- pulso de 1 ciclo
        busy     : out std_logic;
        done     : out std_logic;
        data_in  : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);  -- parâmetros
        data_out : out std_logic_vector(C_DATA_WIDTH-1 downto 0)   -- resposta
    );
end svc_risk_analysis;

architecture rtl of svc_risk_analysis is

    type t_state is (
        S_IDLE,
        S_CALL_PROFILE,  -- placeholder para futuro
        S_CALL_TARIFF,
        S_WAIT_TARIFF,
        S_CALL_INDEX,    -- placeholder para futuro
        S_WAIT_INDEX,    -- placeholder para futuro
        S_DONE
    );
    signal state, next_state : t_state;

    -- Micro-serviço: ms_eval_tariff
    signal ms_tariff_req      : std_logic;
    signal ms_tariff_done     : std_logic;
    signal ms_tariff_data_in  : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal ms_tariff_data_out : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    -- Resultado final do serviço
    signal reg_result         : std_logic_vector(C_DATA_WIDTH-1 downto 0);

begin

    --------------------------------------------------------------------
    -- Instância do micro-serviço ms_eval_tariff
    --------------------------------------------------------------------
    u_ms_tariff : entity work.ms_eval_tariff
        port map (
            clk      => clk,
            rst_n    => rst_n,
            req      => ms_tariff_req,
            done     => ms_tariff_done,
            data_in  => ms_tariff_data_in,
            data_out => ms_tariff_data_out
        );

    data_out <= reg_result;

    --------------------------------------------------------------------
    -- Registrador de estado
    --------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state <= S_IDLE;
        elsif rising_edge(clk) then
            state <= next_state;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Registrador do resultado
    --------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            reg_result <= (others => '0');
        elsif rising_edge(clk) then
            -- captura saída do micro-serviço quando ele termina
            if (state = S_WAIT_TARIFF) and (ms_tariff_done = '1') then
                reg_result <= ms_tariff_data_out;
            end if;
            -- no futuro você pode somar com outros resultados aqui (perfil, index etc.)
        end if;
    end process;

    --------------------------------------------------------------------
    -- FSM combinacional do serviço
    --------------------------------------------------------------------
    process(state, req, ms_tariff_done, reg_result, data_in)
    begin
        -- valores padrão
        busy             <= '0';
        done             <= '0';
        ms_tariff_req    <= '0';
        ms_tariff_data_in<= data_in;  -- para este teste, passa direto o data_in
        next_state       <= state;

        case state is

            when S_IDLE =>
                if req = '1' then
                    next_state <= S_CALL_PROFILE;  -- futuro: poderia chamar outro serviço
                end if;

            when S_CALL_PROFILE =>
                busy       <= '1';
                -- ainda não temos perfil, então pulamos direto para tarifa
                next_state <= S_CALL_TARIFF;

            when S_CALL_TARIFF =>
                busy             <= '1';
                ms_tariff_req    <= '1';          -- pulso de 1 ciclo
                ms_tariff_data_in<= data_in;      -- usa entrada do serviço
                next_state       <= S_WAIT_TARIFF;

            when S_WAIT_TARIFF =>
                busy <= '1';
                if ms_tariff_done = '1' then
                    -- reg_result será carregado no process síncrono
                    next_state <= S_CALL_INDEX;   -- ou direto S_DONE se não tiver index
                end if;

            when S_CALL_INDEX =>
                busy       <= '1';
                -- placeholder para no futuro chamar ms_risk_index
                next_state <= S_DONE;

            when S_WAIT_INDEX =>
                busy       <= '1';
                -- placeholder se precisar esperar outro micro-serviço
                next_state <= S_DONE;

            when S_DONE =>
                done       <= '1';     -- avisa ao Broker que terminou
                next_state <= S_IDLE;

            when others =>
                next_state <= S_IDLE;

        end case;
    end process;

end architecture rtl;
