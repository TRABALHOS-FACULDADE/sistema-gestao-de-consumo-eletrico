library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.soa_resource_pkg.all;

entity Sistema_tb is
end entity Sistema_tb;

architecture tb of Sistema_tb is

    --------------------------------------------------------------------
    -- Constantes e sinais
    --------------------------------------------------------------------
    constant C_CLK_PERIOD : time := 20 ns;  -- 50 MHz

    signal clk      : std_logic := '0';
    signal rst_n    : std_logic := '0';

    signal sw       : std_logic_vector(9 downto 0) := (others => '0');
    signal btn_req  : std_logic := '1';
    signal btn_g1   : std_logic := '1';
    signal btn_g2   : std_logic := '1';
    signal btn_g3   : std_logic := '1';

    signal leds     : std_logic_vector(7 downto 0);
    signal hex0_seg : std_logic_vector(6 downto 0);
    signal hex2_seg : std_logic_vector(6 downto 0);
    signal hex3_seg : std_logic_vector(6 downto 0);
    signal hex4_seg : std_logic_vector(6 downto 0);

begin

    --------------------------------------------------------------------
    -- DUT: top-level Sistema
    --------------------------------------------------------------------
    uut : entity work.Sistema
        port map (
            clk      => clk,
            rst_n    => rst_n,
            sw       => sw,
            btn_req  => btn_req,
            btn_g1   => btn_g1,
            btn_g2   => btn_g2,
            btn_g3   => btn_g3,
            leds     => leds,
            hex0_seg => hex0_seg,
            hex2_seg => hex2_seg,
            hex3_seg => hex3_seg,
            hex4_seg => hex4_seg
        );

    --------------------------------------------------------------------
    -- Clock 50 MHz
    --------------------------------------------------------------------
    clk_process : process
    begin
        clk <= '0';
        wait for C_CLK_PERIOD / 2;
        clk <= '1';
        wait for C_CLK_PERIOD / 2;
    end process clk_process;

    --------------------------------------------------------------------
    -- Estímulos: 3 cenários encadeados
    --------------------------------------------------------------------
    stim_proc : process
    begin
        ----------------------------------------------------------------
        -- RESET INICIAL
        ----------------------------------------------------------------
        rst_n   <= '0';
        sw      <= (others => '0');
        btn_req <= '1';
        btn_g1  <= '1';
        btn_g2  <= '1';
        btn_g3  <= '1';

        wait for 5 * C_CLK_PERIOD;
        rst_n <= '1';
        wait for 10 * C_CLK_PERIOD;

        -- Sempre usar o serviço de risco
        sw(1 downto 0) <= SVC_ID_RESOURCE_RISK;

        -- Habilita os 3 grupos
        sw(2) <= '1';
        sw(3) <= '1';
        sw(4) <= '1';

        ----------------------------------------------------------------
        -- CENÁRIO 1: tudo leve → esperado OK
        --  - níveis todos 0 (estado inicial do client)
        --  - modo "00" (condição boa)
        ----------------------------------------------------------------
        sw(6 downto 5) <= "00";   -- modo bom
        wait for 10 * C_CLK_PERIOD;

        -- pulso em KEY0 (btn_req)
        btn_req <= '0';
        wait for 2 * C_CLK_PERIOD;
        btn_req <= '1';

        -- tempo para client → broker → serviços → resposta
        wait for 30 * C_CLK_PERIOD;

        ----------------------------------------------------------------
        -- CENÁRIO 2: níveis médios, modo normal → esperado ALERTA
        --  - incrementa G1,G2,G3 duas vezes cada (nível 2)
        --  - modo "01"
        ----------------------------------------------------------------
        sw(6 downto 5) <= "01";   -- modo normal
        wait for 10 * C_CLK_PERIOD;

        -- incrementa G1 duas vezes
        btn_g1 <= '0';  wait for 2 * C_CLK_PERIOD;  btn_g1 <= '1';
        wait for 6 * C_CLK_PERIOD;
        btn_g1 <= '0';  wait for 2 * C_CLK_PERIOD;  btn_g1 <= '1';
        wait for 6 * C_CLK_PERIOD;

        -- incrementa G2 duas vezes
        btn_g2 <= '0';  wait for 2 * C_CLK_PERIOD;  btn_g2 <= '1';
        wait for 6 * C_CLK_PERIOD;
        btn_g2 <= '0';  wait for 2 * C_CLK_PERIOD;  btn_g2 <= '1';
        wait for 6 * C_CLK_PERIOD;

        -- incrementa G3 duas vezes
        btn_g3 <= '0';  wait for 2 * C_CLK_PERIOD;  btn_g3 <= '1';
        wait for 6 * C_CLK_PERIOD;
        btn_g3 <= '0';  wait for 2 * C_CLK_PERIOD;  btn_g3 <= '1';
        wait for 10 * C_CLK_PERIOD;

        -- requisita avaliação
        btn_req <= '0';
        wait for 2 * C_CLK_PERIOD;
        btn_req <= '1';
        wait for 30 * C_CLK_PERIOD;

        ----------------------------------------------------------------
        -- CENÁRIO 3: níveis altos, modo ruim → esperado CRÍTICO
        --  - mais um incremento em cada grupo (nível 3)
        --  - modo "10"
        ----------------------------------------------------------------
        sw(6 downto 5) <= "10";   -- modo ruim
        wait for 10 * C_CLK_PERIOD;

        -- um incremento extra em cada grupo
        btn_g1 <= '0';  wait for 2 * C_CLK_PERIOD;  btn_g1 <= '1';
        wait for 6 * C_CLK_PERIOD;
        btn_g2 <= '0';  wait for 2 * C_CLK_PERIOD;  btn_g2 <= '1';
        wait for 6 * C_CLK_PERIOD;
        btn_g3 <= '0';  wait for 2 * C_CLK_PERIOD;  btn_g3 <= '1';
        wait for 10 * C_CLK_PERIOD;

        -- requisita avaliação de risco
        btn_req <= '0';
        wait for 2 * C_CLK_PERIOD;
        btn_req <= '1';
        wait for 100 * C_CLK_PERIOD;

        ----------------------------------------------------------------
        -- Fim de simulação
        ----------------------------------------------------------------
        wait;
    end process stim_proc;

end architecture tb;
