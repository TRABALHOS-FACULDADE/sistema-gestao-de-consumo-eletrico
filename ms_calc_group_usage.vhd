library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.soa_resource_pkg.all;

-- Micro-serviço genérico: converte o nível de um Grupo
-- (0,1,2,3) em "uso do recurso" aproximado.
-- 
-- Exemplo:
--  nível 00 -> uso 4
--  nível 01 -> uso 8
--  nível 10 -> uso 12
--  nível 11 -> uso 16
--
-- Esse micro-serviço é independente do tipo de recurso
-- (energia, CPU, água, largura de banda, etc.)
-- e faz parte da arquitetura de micro-serviços SOA em hardware.

entity ms_calc_group_usage is
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;
        req      : in  std_logic;
        done     : out std_logic;

        -- data_in: os 2 LSB representam o nível do grupo
        -- data_in(1 downto 0) = nível do Grupo (0..3)
        data_in  : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);

        -- data_out: valor aproximado do "uso do recurso"
        -- (unidade arbitrária, adaptável ao domínio da aplicação)
        data_out : out std_logic_vector(C_DATA_WIDTH-1 downto 0)
    );
end ms_calc_group_usage;

architecture rtl of ms_calc_group_usage is

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
                        case data_in(1 downto 0) is
                            when "00" =>
                                reg_out <= std_logic_vector(to_unsigned(0,  C_DATA_WIDTH));  -- 0
                            when "01" =>
                                reg_out <= std_logic_vector(to_unsigned(4,  C_DATA_WIDTH));  -- 4
                            when "10" =>
                                reg_out <= std_logic_vector(to_unsigned(8, C_DATA_WIDTH));  -- 8
                            when others =>
                                reg_out <= std_logic_vector(to_unsigned(12, C_DATA_WIDTH));  -- 12
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
