library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity display_driver is
    port (
        clk       : in  std_logic;
        rst_n     : in  std_logic;
        data8     : in  std_logic_vector(7 downto 0);

        an        : out std_logic_vector(3 downto 0);  -- 7-seg enable (ativo em 0)
        seg       : out std_logic_vector(6 downto 0)   -- segmentos
    );
end display_driver;

architecture rtl of display_driver is

    signal mux_sel : std_logic := '0';  -- alterna entre dígito alto e baixo
    signal cnt     : unsigned(15 downto 0) := (others => '0');

    signal digit   : std_logic_vector(3 downto 0);
    signal seg_int : std_logic_vector(6 downto 0);

begin

    -- Multiplexador de 1kHz (aprox)
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            cnt     <= (others => '0');
            mux_sel <= '0';
        elsif rising_edge(clk) then
            cnt <= cnt + 1;
            if cnt = 50000 then     -- ajuste para sua frequência de clock
                mux_sel <= not mux_sel;
                cnt     <= (others => '0');
            end if;
        end if;
    end process;

    -- Seleção do dígito
    process(mux_sel, data8)
    begin
        if mux_sel = '0' then
            digit <= data8(3 downto 0);          -- dígito da direita
        else
            digit <= data8(7 downto 4);          -- dígito da esquerda
        end if;
    end process;

    -- Instância do decodificador
    u_hex : entity work.hex7seg
        port map (
            hex => digit,
            seg => seg_int
        );

    -- Saídas
    seg <= seg_int;

    -- Anodos (ativos em zero)
    an <= "1110" when mux_sel = '0' else
          "1101";    -- usa só dois displays
end rtl;
