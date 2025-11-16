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
        data_out : out std_logic_vector(C_DATA_WIDTH-1 downto 0)   -- resposta (código de risco)
    );
end svc_risk_analysis;

architecture rtl of svc_risk_analysis is

    -- Estados do serviço
    type t_state is (
        S_IDLE,
        S_CALL_TARIFF,
        S_WAIT_TARIFF,
        S_COMPUTE_SCORE,
        S_CALL_INDEX,
        S_WAIT_INDEX,
        S_DONE
    );
    signal state, next_state : t_state;

    --------------------------------------------------------------------
    -- Micro-serviço ms_eval_tariff  (peso tarifário 1..4)
    --------------------------------------------------------------------
    signal ms_tariff_req      : std_logic;
    signal ms_tariff_done     : std_logic;
    signal ms_tariff_data_in  : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal ms_tariff_data_out : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    --------------------------------------------------------------------
    -- Micro-serviço ms_risk_index  (score -> OK/WARN/CRIT)
    --------------------------------------------------------------------
    signal ms_index_req      : std_logic;
    signal ms_index_done     : std_logic;
    signal ms_index_data_in  : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal ms_index_data_out : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    --------------------------------------------------------------------
    -- Registradores internos
    --------------------------------------------------------------------
    signal reg_tariff_weight : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal reg_total_level   : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal reg_score         : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal reg_result        : std_logic_vector(C_DATA_WIDTH-1 downto 0);

begin

    --------------------------------------------------------------------
    -- Instância de ms_eval_tariff
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

    --------------------------------------------------------------------
    -- Instância de ms_risk_index
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
    -- Registradores de dados (peso, total_level, score, result)
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
            reg_tariff_weight <= (others => '0');
            reg_total_level   <= (others => '0');
            reg_score         <= (others => '0');
            reg_result        <= (others => '0');
        elsif rising_edge(clk) then

            -- Quando tarifa estiver pronta, calculamos nível total também
            if (state = S_WAIT_TARIFF) and (ms_tariff_done = '1') then
                reg_tariff_weight <= ms_tariff_data_out;

                -- níveis das cargas (2 bits cada)
                v_lvl1 := unsigned("00" & data_in(1 downto 0));
                v_lvl2 := unsigned("00" & data_in(3 downto 2));
                v_lvl3 := unsigned("00" & data_in(5 downto 4));

                v_total := resize(v_lvl1 + v_lvl2 + v_lvl3, C_DATA_WIDTH);
                reg_total_level <= std_logic_vector(v_total);
            end if;

            -- Quando entramos em S_COMPUTE_SCORE, derivamos o score
            if (state = S_COMPUTE_SCORE) then
                v_weight := resize(unsigned(reg_tariff_weight), C_DATA_WIDTH);
                v_total  := unsigned(reg_total_level);

                -- score = (peso_tarifa << 2) + total_level
                v_score := shift_left(v_weight, 2) + v_total;
                reg_score <= std_logic_vector(v_score);
            end if;

            -- Quando risco for calculado
            if (state = S_WAIT_INDEX) and (ms_index_done = '1') then
                reg_result <= ms_index_data_out;  -- código de risco nos 2 LSB
            end if;

        end if;
    end process;

    --------------------------------------------------------------------
    -- FSM combinacional do serviço
    --------------------------------------------------------------------
    process(state, req, ms_tariff_done, ms_index_done)
    begin
        -- valores padrão
        busy      <= '0';
        done      <= '0';

        ms_tariff_req    <= '0';
        ms_tariff_data_in<= (others => '0');

        ms_index_req     <= '0';
        ms_index_data_in <= reg_score;

        next_state       <= state;

        case state is

            when S_IDLE =>
                if req = '1' then
                    next_state <= S_CALL_TARIFF;
                end if;

            when S_CALL_TARIFF =>
                busy             <= '1';
                ms_tariff_req    <= '1';       -- um pulso de req
                ms_tariff_data_in<= data_in;   -- usa os 8 bits de entrada
                next_state       <= S_WAIT_TARIFF;

            when S_WAIT_TARIFF =>
                busy <= '1';
                if ms_tariff_done = '1' then
                    next_state <= S_COMPUTE_SCORE;
                end if;

            when S_COMPUTE_SCORE =>
                busy       <= '1';
                -- registrador de score é atualizado no process síncrono
                next_state <= S_CALL_INDEX;

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
