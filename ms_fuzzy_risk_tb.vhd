-- ####################################################################
-- Testbench para o módulo ms_fuzzy_risk
-- Arquivo: ms_fuzzy_risk_tb.vhd
--
-- Simula e verifica a lógica fuzzy de risco para diferentes combinações
-- de uso normalizado (usage_norm) e condição/modo (cond).
--
-- Compatível com ModelSim-Altera / Quartus II
-- ####################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.soa_resource_pkg.all;

entity ms_fuzzy_risk_tb is
end entity ms_fuzzy_risk_tb;

architecture tb of ms_fuzzy_risk_tb is

    --------------------------------------------------------------------
    -- Sinais internos para mapear as portas de ms_fuzzy_risk
    --------------------------------------------------------------------
    signal clk      : std_logic := '0';
    signal rst_n    : std_logic := '0';

    signal req      : std_logic := '0';
    signal done     : std_logic;

    signal data_in  : std_logic_vector(C_DATA_WIDTH-1 downto 0) := (others => '0');
    signal data_out : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    -- Constante para período de clock (por exemplo, 20 ns → 50 MHz)
    constant CLK_PERIOD : time := 20 ns;

begin

    --------------------------------------------------------------------
    -- Instância do DUT (Device Under Test): ms_fuzzy_risk
    --------------------------------------------------------------------
    dut : entity work.ms_fuzzy_risk
        port map (
            clk      => clk,
            rst_n    => rst_n,
            req      => req,
            done     => done,
            data_in  => data_in,
            data_out => data_out
        );

    --------------------------------------------------------------------
    -- Geração de clock
    --------------------------------------------------------------------
    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    --------------------------------------------------------------------
    -- Estímulos de reset e vetores de teste
    --------------------------------------------------------------------
    stim_proc : process
        -- Procedimento auxiliar para aplicar um vetor de teste
        procedure apply_test(
            constant usage_norm : integer;
            constant cond_bits  : std_logic_vector(1 downto 0);
            constant expected   : std_logic_vector(1 downto 0);
            constant test_name  : string
        ) is
        begin
            -- Configura data_in: bits 3..0 = uso, 5..4 = cond, demais = 0
            data_in <= (others => '0');
            data_in(3 downto 0) <= std_logic_vector(to_unsigned(usage_norm, 4));
            data_in(5 downto 4) <= cond_bits;

            -- Pulso de req (1 ciclo)
            wait until rising_edge(clk);
            req <= '1';
            wait until rising_edge(clk);
            req <= '0';

            -- Espera o done subir
            wait until rising_edge(clk);
            while done = '0' loop
                wait until rising_edge(clk);
            end loop;

            -- Verifica o resultado
            assert data_out(1 downto 0) = expected
                report "FALHA no teste: " & test_name &
                       " | uso=" & integer'image(usage_norm) &
                       " cond=" & std_logic'image(cond_bits(1)) &
                                 std_logic'image(cond_bits(0)) &
                       " | esperado=" &
                           std_logic'image(expected(1)) &
                           std_logic'image(expected(0)) &
                       " obtido=" &
                           std_logic'image(data_out(1)) &
                           std_logic'image(data_out(0))
                severity error;

            report "OK: " & test_name &
                   " | uso=" & integer'image(usage_norm) &
                   " cond=" & std_logic'image(cond_bits(1)) &
                             std_logic'image(cond_bits(0)) &
                   " | risco=" &
                       std_logic'image(data_out(1)) &
                       std_logic'image(data_out(0))
                   severity note;
        end procedure;
    begin
        ----------------------------------------------------------------
        -- 1) Reset inicial
        ----------------------------------------------------------------
        rst_n <= '0';
        req   <= '0';
        data_in <= (others => '0');

        wait for 5*CLK_PERIOD;
        rst_n <= '1';
        wait for 2*CLK_PERIOD;

        ----------------------------------------------------------------
        -- 2) Casos de teste
        ----------------------------------------------------------------

        -- Caso 1: uso baixo, condição boa → esperado OK
        -- cond="00", u=1 → RISK_OK_CODE
        apply_test(
            usage_norm => 1,
            cond_bits  => "00",
            expected   => RISK_OK_CODE,
            test_name  => "Uso baixo, cond boa -> OK"
        );

        -- Caso 2: uso médio, condição boa → esperado WARN
        -- cond="00", u=4 → RISK_WARN_CODE
        apply_test(
            usage_norm => 4,
            cond_bits  => "00",
            expected   => RISK_WARN_CODE,
            test_name  => "Uso médio, cond boa -> WARN"
        );

        -- Caso 3: uso alto, condição boa → esperado CRIT
        -- cond="00", u=9 → RISK_CRIT_CODE
        apply_test(
            usage_norm => 9,
            cond_bits  => "00",
            expected   => RISK_CRIT_CODE,
            test_name  => "Uso alto, cond boa -> CRIT"
        );

        -- Caso 4: condição ruim, uso zero → esperado WARN
        -- cond="10", u=0 → RISK_WARN_CODE
        apply_test(
            usage_norm => 0,
            cond_bits  => "10",
            expected   => RISK_WARN_CODE,
            test_name  => "Uso zero, cond ruim -> WARN"
        );

        -- Caso 5: condição ruim, uso > 0 → esperado CRIT
        -- cond="10", u=3 → RISK_CRIT_CODE
        apply_test(
            usage_norm => 3,
            cond_bits  => "10",
            expected   => RISK_CRIT_CODE,
            test_name  => "Uso > 0, cond ruim -> CRIT"
        );

        ----------------------------------------------------------------
        -- 3) Fim da simulação
        ----------------------------------------------------------------
        report "Todos os testes do ms_fuzzy_risk_tb foram aplicados." severity note;
        wait;
    end process;

end architecture tb;
