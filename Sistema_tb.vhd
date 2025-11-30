library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.soa_resource_pkg.all;

entity Sistema_tb is
end entity;

architecture sim of Sistema_tb is

    --------------------------------------------------------------------
    -- Sinais do DUT (Sistema)
    --------------------------------------------------------------------
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
    -- Clock: 50 MHz (período 20 ns)
    --------------------------------------------------------------------
    clk_process : process
    begin
        clk <= '0';
        wait for 10 ns;
        clk <= '1';
        wait for 10 ns;
    end process;

    --------------------------------------------------------------------
    -- DUT
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
    -- Estímulos
    --
    -- Cenário 1: uso baixo → OK
    -- Cenário 2: uso médio (modo normal) → ALERTA
    -- Cenário 3: uso alto (modo ruim) → CRÍTICO
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

        wait for 100 ns;
        rst_n <= '1';
        wait for 100 ns;

        sw <= (others => '0');
        sw(1 downto 0) <= SVC_ID_RESOURCE_RISK;
        sw(2) <= '1';
        sw(3) <= '1';
        sw(4) <= '1';
        sw(7) <= '1';

        -- CENÁRIO 1
        sw(6 downto 5) <= "00";

        btn_g1 <= '0';  wait for 20 ns;
        btn_g1 <= '1';  wait for 80 ns;

        btn_g2 <= '0';  wait for 20 ns;
        btn_g2 <= '1';  wait for 80 ns;

        btn_g3 <= '0';  wait for 20 ns;
        btn_g3 <= '1';  wait for 80 ns;

        btn_req <= '0'; wait for 20 ns;
        btn_req <= '1';

        wait for 400 ns;
		  
        -- CENÁRIO 2
        sw(6 downto 5) <= "01";

        btn_g1 <= '0';  wait for 20 ns;
        btn_g1 <= '1';  wait for 80 ns;

        btn_g2 <= '0';  wait for 20 ns;
        btn_g2 <= '1';  wait for 80 ns;

        btn_g3 <= '0';  wait for 20 ns;
        btn_g3 <= '1';  wait for 80 ns;

        btn_req <= '0'; wait for 20 ns;
        btn_req <= '1';

        wait for 400 ns;

        -- CENÁRIO 3
        sw(6 downto 5) <= "10";

        btn_g1 <= '0';  wait for 20 ns;
        btn_g1 <= '1';  wait for 80 ns;

        btn_g2 <= '0';  wait for 20 ns;
        btn_g2 <= '1';  wait for 80 ns;

        btn_g3 <= '0';  wait for 20 ns;
        btn_g3 <= '1';  wait for 80 ns;

        btn_req <= '0'; wait for 20 ns;
        btn_req <= '1';

        wait for 400 ns;

        ----------------------------------------------------------------
        -- Fim da simulação
        ----------------------------------------------------------------
        wait;
    end process;

end architecture sim;
