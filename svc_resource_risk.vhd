library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.soa_resource_pkg.all;

-- Serviço de análise de risco de recurso.
-- 
-- Interpreta:
--  - níveis de uso de grupos (3 grupos, 2 bits cada)
--  - modo/política de operação (2 bits)
--
-- Combina:
--  - uso total dos grupos (reg_total_level)
--  - peso do modo (reg_mode_weight, vindo de ms_eval_tariff)
--
-- Para gerar:
--  - um score de risco (reg_score)
--  - um índice de risco (OK / WARN / CRIT) via ms_risk_index
--
-- Layout assumido de data_in (pode ser ajustado na documentação do projeto):
--  data_in(1 downto 0) = nível do Grupo 1
--  data_in(3 downto 2) = nível do Grupo 2
--  data_in(5 downto 4) = nível do Grupo 3
--  data_in(7 downto 6) = modo/política (ex.: econômico/normal/performance/emergência)

entity svc_resource_risk is
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;

        -- Interface com Broker
        req      : in  std_logic;  -- pulso de 1 ciclo
        busy     : out std_logic;
        done     : out std_logic;

        -- Parâmetros de entrada (níveis de grupos + modo)
        data_in  : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);

        -- Resposta: código de risco (por ex., 2 LSB = OK/WARN/CRIT)
        data_out : out std_logic_vector(C_DATA_WIDTH-1 downto 0)
    );
end svc_resource_risk;

architecture rtl of svc_resource_risk is

    -- Estados do serviço
    type t_state is (
        S_IDLE,
        S_CALL_MODE,
        S_WAIT_MODE,
        S_COMPUTE_SCORE,
        S_CALL_INDEX,
        S_WAIT_INDEX,
        S_DONE
    );
    signal state, next_state : t_state;

    --------------------------------------------------------------------
    -- Micro-serviço ms_eval_tariff (agora interpretado como "modo/política")
    -- Converte data_in(7 downto 6) em um peso de modo (1..4, por exemplo).
    --------------------------------------------------------------------
    signal ms_mode_req      : std_logic;
    signal ms_mode_done     : std_logic;
    signal ms_mode_data_in  : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal ms_mode_data_out : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    --------------------------------------------------------------------
    -- Micro-serviço ms_risk_index (score -> OK/WARN/CRIT)
    --------------------------------------------------------------------
    signal ms_index_req      : std_logic;
    signal ms_index_done     : std_logic;
    signal ms_index_data_in  : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal ms_index_data_out : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    --------------------------------------------------------------------
    -- Registradores internos
    --------------------------------------------------------------------
    signal reg_mode_weight : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal reg_total_level : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal reg_score       : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal reg_result      : std_logic_vector(C_DATA_WIDTH-1 downto 0);

begin

    --------------------------------------------------------------------
    -- Instância de ms_eval_tariff (modo/política do recurso)
    --------------------------------------------------------------------
    u_ms_mode : entity work.ms_eval_tariff
        port map (
            clk      => clk,
            rst_n    => rst_n,
            req      => ms_mode_req,
            done     => ms_mode_done,
            data_in  => ms_mode_data_in,
            data_out => ms_mode_data_out
        );

    --------------------------------------------------------------------
    -- Instância de ms_risk_index (classificador de risco)
    --------------------------------------------------------------------
    u_ms_index : entity work.ms_risk_index
        port map (
            clk      => clk,
            rst_n    => rst_n,
            req      => ms_index_req,
            done     => ms_index_done,
            data_in  => ms_index_data_in,
            data_out => ms_index_data_out
        );

    -- Saída do serviço
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
    -- Registradores de dados (peso de modo, nível total, score, resultado)
    --------------------------------------------------------------------
    process(clk, rst_n)
        variable v_lvl1   : unsigned(3 downto 0);
        variable v_lvl2   : unsigned(3 downto 0);
        variable v_lvl3   : unsigned(3 downto 0);
        variable v_total  : unsigned(C_DATA_WIDTH-1 downto 0);
        variable v_weight : unsigned(C_DATA_WIDTH-1 downto 0);
        variable v_score  : unsigned(C_DATA_WIDTH-1 downto 0);
    begin
        if rst_n = '0' then
            reg_mode_weight <= (others => '0');
            reg_total_level <= (others => '0');
            reg_score       <= (others => '0');
            reg_result      <= (others => '0');

        elsif rising_edge(clk) then

            -- Quando o modo for avaliado, calculamos o nível total dos grupos
            if (state = S_WAIT_MODE) and (ms_mode_done = '1') then
                reg_mode_weight <= ms_mode_data_out;

                -- níveis dos grupos (2 bits cada) extraídos de data_in
                v_lvl1 := unsigned("00" & data_in(1 downto 0));
                v_lvl2 := unsigned("00" & data_in(3 downto 2));
                v_lvl3 := unsigned("00" & data_in(5 downto 4));

                v_total := resize(v_lvl1 + v_lvl2 + v_lvl3, C_DATA_WIDTH);
                reg_total_level <= std_logic_vector(v_total);
            end if;

            -- Quando entramos em S_COMPUTE_SCORE, derivamos o score
            if (state = S_COMPUTE_SCORE) then
                v_weight := resize(unsigned(reg_mode_weight), C_DATA_WIDTH);
                v_total  := unsigned(reg_total_level);

                -- score = (peso_modo << 2) + total_level
                v_score   := shift_left(v_weight, 2) + v_total;
                reg_score <= std_logic_vector(v_score);
            end if;

            -- Quando o risco for calculado pelo ms_risk_index
            if (state = S_WAIT_INDEX) and (ms_index_done = '1') then
                reg_result <= ms_index_data_out;  -- código de risco nos 2 LSB
            end if;

        end if;
    end process;

    --------------------------------------------------------------------
    -- FSM combinacional do serviço
    --------------------------------------------------------------------
    process(state, req, ms_mode_done, ms_index_done)
    begin
        -- valores padrão
        busy  <= '0';
        done  <= '0';

        ms_mode_req      <= '0';
        ms_mode_data_in  <= (others => '0');

        ms_index_req     <= '0';
        ms_index_data_in <= reg_score;

        next_state       <= state;

        case state is

            when S_IDLE =>
                if req = '1' then
                    next_state <= S_CALL_MODE;
                end if;

            -- 1) Chama ms_eval_tariff para interpretar o modo/política do recurso
            when S_CALL_MODE =>
                busy            <= '1';
                ms_mode_req     <= '1';       -- um pulso de req
                ms_mode_data_in <= data_in;   -- usa os 8 bits de entrada
                next_state      <= S_WAIT_MODE;

            when S_WAIT_MODE =>
                busy <= '1';
                if ms_mode_done = '1' then
                    next_state <= S_COMPUTE_SCORE;
                end if;

            -- 2) Calcula o score combinando uso total dos grupos e peso do modo
            when S_COMPUTE_SCORE =>
                busy       <= '1';
                next_state <= S_CALL_INDEX;

            -- 3) Chama ms_risk_index para classificar o risco
            when S_CALL_INDEX =>
                busy            <= '1';
                ms_index_req    <= '1';        -- um pulso de req
                ms_index_data_in<= reg_score;
                next_state      <= S_WAIT_INDEX;

            when S_WAIT_INDEX =>
                busy <= '1';
                if ms_index_done = '1' then
                    next_state <= S_DONE;
                end if;

            when S_DONE =>
                done       <= '1';
                next_state <= S_IDLE;

            when others =>
                next_state <= S_IDLE;

        end case;
    end process;

end architecture rtl;
