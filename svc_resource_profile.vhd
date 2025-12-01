library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.soa_resource_pkg.all;

-- Serviço de perfil instantâneo de uso de recurso.
--
-- Interpreta data_in como:
--  data_in(1 downto 0) = nível do Grupo 1 (0..3)
--  data_in(3 downto 2) = nível do Grupo 2 (0..3)
--  data_in(5 downto 4) = nível do Grupo 3 (0..3)
--  data_in(7 downto 6) = modo/política (não usado aqui)
--
-- Ele utiliza micro-serviços para:
--  - ler o nível de cada grupo (ms_read_group_g1/g2/g3)
--  - converter nível -> uso aproximado do recurso (ms_calc_group_usage)
--  - somar os usos individuais em um total (data_out)
--
-- Assim, implementa um "medidor" de uso do recurso por grupos.

entity svc_resource_profile is
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;

        -- Interface com Broker
        req      : in  std_logic;  -- pulso de 1 ciclo para iniciar o serviço
        busy     : out std_logic;
        done     : out std_logic;

        -- Parâmetros de entrada (níveis de grupos + modo)
        data_in  : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);

        -- Saída: uso total aproximado do recurso (soma dos grupos)
        data_out : out std_logic_vector(C_DATA_WIDTH-1 downto 0)
    );
end svc_resource_profile;

architecture rtl of svc_resource_profile is

    --------------------------------------------------------------------
    -- Estados do serviço
    --------------------------------------------------------------------
    type t_state is (
        S_IDLE,
        S_READ1,
        S_WAIT_READ1,
        S_STORE_LVL1,
        S_USE1,
        S_WAIT_USE1,
        S_READ2,
        S_WAIT_READ2,
        S_STORE_LVL2,
        S_USE2,
        S_WAIT_USE2,
        S_READ3,
        S_WAIT_READ3,
        S_STORE_LVL3,
        S_USE3,
        S_WAIT_USE3,
        S_SUM,
        S_DONE
    );
    signal state, next_state : t_state;

    --------------------------------------------------------------------
    -- Micro-serviços de leitura de nível de grupo
    --------------------------------------------------------------------
    signal read1_req, read1_done : std_logic;
    signal read1_data_out        : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    signal read2_req, read2_done : std_logic;
    signal read2_data_out        : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    signal read3_req, read3_done : std_logic;
    signal read3_data_out        : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    --------------------------------------------------------------------
    -- Micro-serviço de cálculo de uso (reutilizado para os 3 grupos)
    --------------------------------------------------------------------
    signal use_req, use_done : std_logic;
    signal use_data_in       : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal use_data_out      : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    --------------------------------------------------------------------
    -- Registradores internos para níveis, usos individuais e total
    --------------------------------------------------------------------
    signal reg_level1  : std_logic_vector(1 downto 0);
    signal reg_level2  : std_logic_vector(1 downto 0);
    signal reg_level3  : std_logic_vector(1 downto 0);

    signal reg_use1    : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal reg_use2    : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal reg_use3    : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    signal reg_result  : std_logic_vector(C_DATA_WIDTH-1 downto 0);

begin

    --------------------------------------------------------------------
    -- Instâncias dos micro-serviços de leitura de nível de grupo
    --------------------------------------------------------------------
    u_read1 : entity work.ms_read_group_gx
        port map (
            clk      => clk,
            rst_n    => rst_n,
            req      => read1_req,
            done     => read1_done,
            data_in  => data_in,
            data_out => read1_data_out
        );

    u_read2 : entity work.ms_read_group_gx
        port map (
            clk      => clk,
            rst_n    => rst_n,
            req      => read2_req,
            done     => read2_done,
            data_in  => data_in,
            data_out => read2_data_out
        );

    u_read3 : entity work.ms_read_group_gx
        port map (
            clk      => clk,
            rst_n    => rst_n,
            req      => read3_req,
            done     => read3_done,
            data_in  => data_in,
            data_out => read3_data_out
        );

    --------------------------------------------------------------------
    -- Instância do micro-serviço de cálculo de uso de grupo
    -- (reutilizada para G1, G2 e G3)
    --------------------------------------------------------------------
    u_use : entity work.ms_calc_group_usage
        port map (
            clk      => clk,
            rst_n    => rst_n,
            req      => use_req,
            done     => use_done,
            data_in  => use_data_in,
            data_out => use_data_out
        );

    -- Saída final
    data_out <= reg_result;

    --------------------------------------------------------------------
    -- Registrador de estado da FSM + registradores de dados
    --------------------------------------------------------------------
    process(clk, rst_n)
        variable v_total : unsigned(C_DATA_WIDTH-1 downto 0);
    begin
        if rst_n = '0' then
            state      <= S_IDLE;
            reg_level1 <= (others => '0');
            reg_level2 <= (others => '0');
            reg_level3 <= (others => '0');
            reg_use1   <= (others => '0');
            reg_use2   <= (others => '0');
            reg_use3   <= (others => '0');
            reg_result <= (others => '0');

        elsif rising_edge(clk) then
            state <= next_state;

            ----------------------------------------------------------------
            -- Captura níveis lidos pelos micro-serviços de leitura
            ----------------------------------------------------------------
            if (state = S_STORE_LVL1) then
                reg_level1 <= read1_data_out(1 downto 0);
            end if;

            if (state = S_STORE_LVL2) then
                reg_level2 <= read2_data_out(1 downto 0);
            end if;

            if (state = S_STORE_LVL3) then
                reg_level3 <= read3_data_out(1 downto 0);
            end if;

            ----------------------------------------------------------------
            -- Armazena uso do Grupo 1 quando cálculo termina
            ----------------------------------------------------------------
            if (state = S_WAIT_USE1) and (use_done = '1') then
                reg_use1 <= use_data_out;
            end if;

            ----------------------------------------------------------------
            -- Armazena uso do Grupo 2
            ----------------------------------------------------------------
            if (state = S_WAIT_USE2) and (use_done = '1') then
                reg_use2 <= use_data_out;
            end if;

            ----------------------------------------------------------------
            -- Armazena uso do Grupo 3
            ----------------------------------------------------------------
            if (state = S_WAIT_USE3) and (use_done = '1') then
                reg_use3 <= use_data_out;
            end if;

            ----------------------------------------------------------------
            -- Soma total dos usos dos grupos em S_SUM
            ----------------------------------------------------------------
            if (state = S_SUM) then
                v_total := resize(unsigned(reg_use1), C_DATA_WIDTH)
                         + resize(unsigned(reg_use2), C_DATA_WIDTH)
                         + resize(unsigned(reg_use3), C_DATA_WIDTH);

                -- (opcional) saturação para evitar overflow em futuras mudanças
                if v_total > to_unsigned(255, C_DATA_WIDTH) then
                    v_total := to_unsigned(255, C_DATA_WIDTH);
                end if;

                reg_result <= std_logic_vector(v_total);
            end if;

        end if;
    end process;

    --------------------------------------------------------------------
    -- FSM combinacional do serviço
    --------------------------------------------------------------------
    process(state, req,
            read1_done, read2_done, read3_done,
            use_done,
            reg_level1, reg_level2, reg_level3)
    begin
        -- valores padrão
        busy        <= '0';
        done        <= '0';

        read1_req   <= '0';
        read2_req   <= '0';
        read3_req   <= '0';

        use_req     <= '0';
        use_data_in <= (others => '0');

        next_state  <= state;

        case state is

            ----------------------------------------------------------------
            when S_IDLE =>
                if req = '1' then
                    next_state <= S_READ1;
                end if;

            ----------------------------------------------------------------
            -- Grupo 1: leitura de nível
            ----------------------------------------------------------------
            when S_READ1 =>
                busy      <= '1';
                read1_req <= '1';          -- pede leitura do nível de G1
                next_state<= S_WAIT_READ1;

            when S_WAIT_READ1 =>
                busy <= '1';
                if read1_done = '1' then
                    next_state <= S_STORE_LVL1;
                end if;

            when S_STORE_LVL1 =>
                busy       <= '1';
                -- nível de G1 será armazenado em reg_level1 no process síncrono
                next_state <= S_USE1;

            -- Grupo 1: cálculo de uso
            when S_USE1 =>
                busy               <= '1';
                use_req            <= '1';
                use_data_in(1 downto 0) <= reg_level1;  -- nível de G1
                next_state         <= S_WAIT_USE1;

            when S_WAIT_USE1 =>
                busy <= '1';
                if use_done = '1' then
                    next_state <= S_READ2;
                end if;

            ----------------------------------------------------------------
            -- Grupo 2: leitura de nível
            ----------------------------------------------------------------
            when S_READ2 =>
                busy      <= '1';
                read2_req <= '1';
                next_state<= S_WAIT_READ2;

            when S_WAIT_READ2 =>
                busy <= '1';
                if read2_done = '1' then
                    next_state <= S_STORE_LVL2;
                end if;

            when S_STORE_LVL2 =>
                busy       <= '1';
                -- nível de G2 será armazenado em reg_level2
                next_state <= S_USE2;

            -- Grupo 2: cálculo de uso
            when S_USE2 =>
                busy               <= '1';
                use_req            <= '1';
                use_data_in(1 downto 0) <= reg_level2;  -- nível de G2
                next_state         <= S_WAIT_USE2;

            when S_WAIT_USE2 =>
                busy <= '1';
                if use_done = '1' then
                    next_state <= S_READ3;
                end if;

            ----------------------------------------------------------------
            -- Grupo 3: leitura de nível
            ----------------------------------------------------------------
            when S_READ3 =>
                busy      <= '1';
                read3_req <= '1';
                next_state<= S_WAIT_READ3;

            when S_WAIT_READ3 =>
                busy <= '1';
                if read3_done = '1' then
                    next_state <= S_STORE_LVL3;
                end if;

            when S_STORE_LVL3 =>
                busy       <= '1';
                -- nível de G3 será armazenado em reg_level3
                next_state <= S_USE3;

            -- Grupo 3: cálculo de uso
            when S_USE3 =>
                busy               <= '1';
                use_req            <= '1';
                use_data_in(1 downto 0) <= reg_level3;  -- nível de G3
                next_state         <= S_WAIT_USE3;

            when S_WAIT_USE3 =>
                busy <= '1';
                if use_done = '1' then
                    next_state <= S_SUM;
                end if;

            ----------------------------------------------------------------
            -- Soma total e finalização
            ----------------------------------------------------------------
            when S_SUM =>
                busy       <= '1';
                next_state <= S_DONE;

            when S_DONE =>
                done       <= '1';
                next_state <= S_IDLE;

            when others =>
                next_state <= S_IDLE;

        end case;
    end process;

end architecture rtl;
