library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.soa_energy_pkg.all;

entity ms_calc_partial_power is
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;
        req      : in  std_logic;
        done     : out std_logic;
        data_in  : in  std_logic_vector(C_DATA_WIDTH-1 downto 0); -- nível em(1..0)
        data_out : out std_logic_vector(C_DATA_WIDTH-1 downto 0)  -- potência approx
    );
end ms_calc_partial_power;

architecture rtl of ms_calc_partial_power is
    type t_state is (MS_IDLE, MS_PROCESS, MS_DONE);
    signal state : t_state;

    signal reg_out : std_logic_vector(C_DATA_WIDTH-1 downto 0);
begin
    data_out <= reg_out;

    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state   <= MS_IDLE;
            reg_out <= (others => '0');
            done    <= '0';
        elsif rising_edge(clk) then
            done <= '0';

            case state is
                when MS_IDLE =>
                    if req = '1' then
                        -- converte nível em "potência" (valores arbitrários p/ demo)
                        case data_in(1 downto 0) is
                            when "00" => reg_out <= "000100"; --  4
                            when "01" => reg_out <= "001000"; --  8
                            when "10" => reg_out <= "001100"; -- 12
                            when others => reg_out <= "010000"; -- 16
                        end case;
                        state <= MS_PROCESS;
                    end if;

                when MS_PROCESS =>
                    state <= MS_DONE;

                when MS_DONE =>
                    done  <= '1';
                    state <= MS_IDLE;

                when others =>
                    state <= MS_IDLE;
            end case;
        end if;
    end process;
end architecture rtl;
