library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.soa_resource_pkg.all;

entity svc_resource_risk is
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;

        -- Interface com Broker
        req      : in  std_logic;  -- pulso de 1 ciclo
        busy     : out std_logic;
        done     : out std_logic;
        data_in  : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);  -- níveis + modo
        data_out : out std_logic_vector(C_DATA_WIDTH-1 downto 0)   -- código de risco (LSBs)
    );
end svc_resource_risk;

architecture rtl of svc_resource_risk is

    --------------------------------------------------------------------
    -- Estados do serviço de risco
    --------------------------------------------------------------------
    type t_state is (
        S_IDLE,
        S_CALL_PROFILE,
        S_WAIT_PROFILE,
        S_CALL_TARIFF,
        S_WAIT_TARIFF,
        S_CALL_FUZZY,
        S_WAIT_FUZZY,
        S_DONE
    );
    signal state, next_state : t_state;

    --------------------------------------------------------------------
    -- Serviço de perfil (svc_resource_profile)
    --------------------------------------------------------------------
    signal prof_req      : std_logic;
    signal prof_busy     : std_logic;
    signal prof_done     : std_logic;
    signal prof_data_in  : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal prof_data_out : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    --------------------------------------------------------------------
    -- Micro-serviço ms_eval_tariff  (peso tarifário / condição)
    --------------------------------------------------------------------
    signal ms_tariff_req      : std_logic;
    signal ms_tariff_done     : std_logic;
    signal ms_tariff_data_in  : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal ms_tariff_data_out : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    --------------------------------------------------------------------
    -- Micro-serviço ms_fuzzy_risk  (uso + modo -> OK/WARN/CRIT)
    --------------------------------------------------------------------
    signal ms_fuzzy_req      : std_logic;
    signal ms_fuzzy_done     : std_logic;
    signal ms_fuzzy_data_in  : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal ms_fuzzy_data_out : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    --------------------------------------------------------------------
    -- Registradores internos
    --------------------------------------------------------------------
    signal reg_total_usage   : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal reg_tariff_info   : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal reg_result        : std_logic_vector(C_DATA_WIDTH-1 downto 0);

begin

    --------------------------------------------------------------------
    -- Instância do serviço de perfil (mantido na arquitetura)
    --------------------------------------------------------------------
    u_svc_prof : entity work.svc_resource_profile
        port map (
            clk      => clk,
            rst_n    => rst_n,
            req      => prof_req,
            busy     => prof_busy,
            done     => prof_done,
            data_in  => prof_data_in,   -- níveis + modo
            data_out => prof_data_out   -- uso total (8 bits)
        );

    --------------------------------------------------------------------
    -- Instância de ms_eval_tariff (mantido para uso futuro)
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
    -- Instância de ms_fuzzy_risk
    --------------------------------------------------------------------
    u_ms_fuzzy : entity work.ms_fuzzy_risk
        port map (
            clk      => clk,
            rst_n    => rst_n,
            req      => ms_fuzzy_req,
            done     => ms_fuzzy_done,
            data_in  => ms_fuzzy_data_in,
            data_out => ms_fuzzy_data_out
        );

    -- Resultado final entregue ao Broker
    data_out <= reg_result;

    --------------------------------------------------------------------
    -- Registrador de estado + registradores de dados
    --------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state           <= S_IDLE;
            reg_total_usage <= (others => '0');
            reg_tariff_info <= (others => '0');
            reg_result      <= (others => '0');
        elsif rising_edge(clk) then
            state <= next_state;

            -- captura uso total vindo do svc_resource_profile (para debug/uso futuro)
            if (state = S_WAIT_PROFILE) and (prof_done = '1') then
                reg_total_usage <= prof_data_out;
            end if;

            -- captura info tarifária (opcional, pra debug/uso futuro)
            if (state = S_WAIT_TARIFF) and (ms_tariff_done = '1') then
                reg_tariff_info <= ms_tariff_data_out;
            end if;

            -- captura código de risco fuzzy
            if (state = S_WAIT_FUZZY) and (ms_fuzzy_done = '1') then
                reg_result <= ms_fuzzy_data_out;  -- 2 LSBs = código de risco
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- FSM combinacional do serviço de risco
    --------------------------------------------------------------------
    process(state, req,
            prof_done, ms_tariff_done, ms_fuzzy_done,
            data_in)
        -- vamos usar diretamente os níveis dos grupos aqui
        variable lvl1  : unsigned(1 downto 0);
        variable lvl2  : unsigned(1 downto 0);
        variable lvl3  : unsigned(1 downto 0);
        variable sum   : integer range 0 to 9;
        variable u4    : unsigned(3 downto 0);  -- uso normalizado 0..9 (cabem em 4 bits)
        variable v_fuzzy_in : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    begin
        -- defaults
        busy  <= '0';
        done  <= '0';

        prof_req          <= '0';
        prof_data_in      <= (others => '0');

        ms_tariff_req     <= '0';
        ms_tariff_data_in <= (others => '0');

        ms_fuzzy_req      <= '0';
        ms_fuzzy_data_in  <= (others => '0');

        next_state        <= state;

        case state is

            ----------------------------------------------------------------
            when S_IDLE =>
                if req = '1' then
                    next_state <= S_CALL_PROFILE;
                end if;

            ----------------------------------------------------------------
            -- 1) Chama o serviço de perfil para calcular uso total (arquitetura)
            ----------------------------------------------------------------
            when S_CALL_PROFILE =>
                busy         <= '1';
                prof_req     <= '1';        -- pulso de requisição
                prof_data_in <= data_in;    -- passa níveis + modo
                next_state   <= S_WAIT_PROFILE;

            when S_WAIT_PROFILE =>
                busy <= '1';
                if prof_done = '1' then
                    next_state <= S_CALL_TARIFF;
                end if;

            ----------------------------------------------------------------
            -- 2) Chama ms_eval_tariff para obter peso/condição (mantido)
            ----------------------------------------------------------------
            when S_CALL_TARIFF =>
                busy              <= '1';
                ms_tariff_req     <= '1';
                ms_tariff_data_in <= data_in;  -- usa bits de modo em ms_eval_tariff
                next_state        <= S_WAIT_TARIFF;

            when S_WAIT_TARIFF =>
                busy <= '1';
                if ms_tariff_done = '1' then
                    next_state <= S_CALL_FUZZY;
                end if;

            ----------------------------------------------------------------
            -- 3) Monta entrada e chama ms_fuzzy_risk (uso_norm + modo)
            --    AGORA: uso_norm é derivado DIRETAMENTE dos níveis 0..3
            --    que você está vendo em HEX2/3/4.
            ----------------------------------------------------------------
            when S_CALL_FUZZY =>
                busy <= '1';

                -- níveis dos grupos, cada um 0..3
                lvl1 := unsigned(data_in(1 downto 0));
                lvl2 := unsigned(data_in(3 downto 2));
                lvl3 := unsigned(data_in(5 downto 4));

                sum  := to_integer(lvl1) + to_integer(lvl2) + to_integer(lvl3); -- 0..9

                -- mapeia sum 0..9 para 0..9 em 4 bits (já cabe direto)
                if sum < 0 then
                    u4 := (others => '0');
                elsif sum > 9 then
                    u4 := to_unsigned(9, 4);
                else
                    u4 := to_unsigned(sum, 4);
                end if;

                -- monta o vetor de entrada para a fuzzy
                v_fuzzy_in              := (others => '0');
                v_fuzzy_in(3 downto 0)  := std_logic_vector(u4);      -- uso normalizado 0..9
                v_fuzzy_in(5 downto 4)  := data_in(7 downto 6);       -- modo/condição (SW6..SW5)

                ms_fuzzy_data_in <= v_fuzzy_in;
                ms_fuzzy_req     <= '1';                        -- req no mesmo ciclo
                next_state       <= S_WAIT_FUZZY;

            when S_WAIT_FUZZY =>
                busy <= '1';
                if ms_fuzzy_done = '1' then
                    next_state <= S_DONE;
                end if;

            ----------------------------------------------------------------
            -- 4) Entrega resultado ao Broker
            ----------------------------------------------------------------
            when S_DONE =>
                done       <= '1';   -- um ciclo com done=1
                next_state <= S_IDLE;

            when others =>
                next_state <= S_IDLE;

        end case;
    end process;

end architecture rtl;
