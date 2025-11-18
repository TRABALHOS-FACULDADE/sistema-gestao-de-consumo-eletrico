library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.soa_resource_pkg.all;

-- Lê o nível do Grupo 2 (bits 3..2 de data_in)
-- e o devolve nos 2 LSB de data_out.

entity ms_read_group_g2 is
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;
        req      : in  std_logic;
        done     : out std_logic;

        data_in  : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);
        data_out : out std_logic_vector(C_DATA_WIDTH-1 downto 0)
    );
end ms_read_group_g2;

architecture rtl of ms_read_group_g2 is

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
                        reg_out <= (others => '0');
                        reg_out(1 downto 0) <= data_in(3 downto 2);  -- nível G2
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
