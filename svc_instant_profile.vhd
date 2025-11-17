library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.soa_energy_pkg.all;

entity svc_instant_profile is
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;

        -- Interface com Broker
        req      : in  std_logic;
        busy     : out std_logic;
        done     : out std_logic;
        data_in  : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);  -- níveis + tarifa
        data_out : out std_logic_vector(C_DATA_WIDTH-1 downto 0)   -- potência total approx
    );
end svc_instant_profile;

architecture rtl of svc_instant_profile is

    type t_state is (
        S_IDLE,
        S_READ1,
        S_WAIT_READ1,
        S_PWR1,
        S_WAIT_PWR1,
        S_READ2,
        S_WAIT_READ2,
        S_PWR2,
        S_WAIT_PWR2,
        S_READ3,
        S_WAIT_READ3,
        S_PWR3,
        S_WAIT_PWR3,
        S_SUM,
        S_DONE
    );
    signal state, next_state : t_state;

    --------------------------------------------------------------------
    -- Micro-serviços de leitura de carga
    --------------------------------------------------------------------
    signal read1_req, read1_done : std_logic;
    signal read1_data_out        : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    signal read2_req, read2_done : std_logic;
    signal read2_data_out        : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    signal read3_req, read3_done : std_logic;
    signal read3_data_out        : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    --------------------------------------------------------------------
    -- Única instância de ms_calc_partial_power (reutilizada)
    --------------------------------------------------------------------
    signal pwr_req, pwr_done    : std_logic;
    signal pwr_data_in          : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal pwr_data_out         : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    --------------------------------------------------------------------
    -- Registradores internos: potência por carga e total
    --------------------------------------------------------------------
    signal reg_pwr1   : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal reg_pwr2   : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal reg_pwr3   : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal reg_result : std_logic_vector(C_DATA_WIDTH-1 downto 0);

begin

    --------------------------------------------------------------------
    -- Instâncias dos micro-serviços ms_read_load_cX
    --------------------------------------------------------------------
    u_read1 : entity work.ms_read_load_c1
        port map (
            clk      => clk,
            rst_n    => rst_n,
            req      => read1_req,
            done     => read1_done,
            data_in  => data_in,
            data_out => read1_data_out
        );

    u_read2 : entity work.ms_read_load_c2
        port map (
            clk      => clk,
            rst_n    => rst_n,
            req      => read2_req,
            done     => read2_done,
            data_in  => data_in,
            data_out => read2_data_out
        );

    u_read3 : entity work.ms_read_load_c3
        port map (
            clk      => clk,
            rst_n    => rst_n,
            req      => read3_req,
            done     => read3_done,
            data_in  => data_in,
            data_out => read3_data_out
        );

    --------------------------------------------------------------------
    -- Instância de ms_calc_partial_power (reutilizada)
    --------------------------------------------------------------------
    u_pwr : entity work.ms_calc_partial_power
        port map (
            clk      => clk,
            rst_n    => rst_n,
            req      => pwr_req,
            done     => pwr_done,
            data_in  => pwr_data_in,
            data_out => pwr_data_out
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
    -- Registradores de potência e total
    --------------------------------------------------------------------
    process(clk, rst_n)
        variable v_total : unsigned(C_DATA_WIDTH-1 downto 0);
    begin
        if rst_n = '0' then
            reg_pwr1   <= (others => '0');
            reg_pwr2   <= (others => '0');
            reg_pwr3   <= (others => '0');
            reg_result <= (others => '0');
        elsif rising_edge(clk) then

            if (state = S_WAIT_PWR1) and (pwr_done = '1') then
                reg_pwr1 <= pwr_data_out;
            end if;

            if (state = S_WAIT_PWR2) and (pwr_done = '1') then
                reg_pwr2 <= pwr_data_out;
            end if;

            if (state = S_WAIT_PWR3) and (pwr_done = '1') then
                reg_pwr3 <= pwr_data_out;
            end if;

            -- Soma simples das três potências
            if (state = S_SUM) then
                v_total := resize(unsigned(reg_pwr1), C_DATA_WIDTH)
                         + resize(unsigned(reg_pwr2), C_DATA_WIDTH)
                         + resize(unsigned(reg_pwr3), C_DATA_WIDTH);
                reg_result <= std_logic_vector(v_total);
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- FSM combinacional do serviço
    --------------------------------------------------------------------
    process(state, req, read1_done, read2_done, read3_done, pwr_done)
    begin
        -- defaults
        busy  <= '0';
        done  <= '0';

        read1_req <= '0';
        read2_req <= '0';
        read3_req <= '0';

        pwr_req    <= '0';
        pwr_data_in<= (others => '0');

        next_state <= state;

        case state is

            when S_IDLE =>
                if req = '1' then
                    next_state <= S_READ1;
                end if;

            -- Carga 1
            when S_READ1 =>
                busy      <= '1';
                read1_req <= '1';
                next_state<= S_WAIT_READ1;

            when S_WAIT_READ1 =>
                busy <= '1';
                if read1_done = '1' then
                    next_state <= S_PWR1;
                end if;

            when S_PWR1 =>
                busy       <= '1';
                pwr_req    <= '1';
                pwr_data_in<= read1_data_out;   -- nível da carga 1
                next_state <= S_WAIT_PWR1;

            when S_WAIT_PWR1 =>
                busy <= '1';
                if pwr_done = '1' then
                    next_state <= S_READ2;
                end if;

            -- Carga 2
            when S_READ2 =>
                busy      <= '1';
                read2_req <= '1';
                next_state<= S_WAIT_READ2;

            when S_WAIT_READ2 =>
                busy <= '1';
                if read2_done = '1' then
                    next_state <= S_PWR2;
                end if;

            when S_PWR2 =>
                busy       <= '1';
                pwr_req    <= '1';
                pwr_data_in<= read2_data_out;   -- nível da carga 2
                next_state <= S_WAIT_PWR2;

            when S_WAIT_PWR2 =>
                busy <= '1';
                if pwr_done = '1' then
                    next_state <= S_READ3;
                end if;

            -- Carga 3
            when S_READ3 =>
                busy      <= '1';
                read3_req <= '1';
                next_state<= S_WAIT_READ3;

            when S_WAIT_READ3 =>
                busy <= '1';
                if read3_done = '1' then
                    next_state <= S_PWR3;
                end if;

            when S_PWR3 =>
                busy       <= '1';
                pwr_req    <= '1';
                pwr_data_in<= read3_data_out;   -- nível da carga 3
                next_state <= S_WAIT_PWR3;

            when S_WAIT_PWR3 =>
                busy <= '1';
                if pwr_done = '1' then
                    next_state <= S_SUM;
                end if;

            -- Soma total
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

end rtl;
