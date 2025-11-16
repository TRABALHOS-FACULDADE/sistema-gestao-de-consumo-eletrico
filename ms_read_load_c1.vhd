library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.soa_energy_pkg.all;

entity ms_read_load_c1 is
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;
        req      : in  std_logic;
        done     : out std_logic;
        data_in  : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);
        data_out : out std_logic_vector(C_DATA_WIDTH-1 downto 0)
    );
end ms_read_load_c1;

architecture rtl of ms_read_load_c1 is
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
                        -- nível da carga 1 = bits 1..0
                        reg_out <= (others => '0');
                        reg_out(1 downto 0) <= data_in(1 downto 0);
                        state <= MS_PROCESS;
                    end if;

                when MS_PROCESS =>
                    -- nada especial, só 1 ciclo de "process"
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
