library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.soa_energy_pkg.all;

entity ms_eval_tariff is
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;

        req      : in  std_logic;  -- pulso de 1 ciclo
        done     : out std_logic;  -- pulso de 1 ciclo

        data_in  : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);
        data_out : out std_logic_vector(C_DATA_WIDTH-1 downto 0)
    );
end ms_eval_tariff;

architecture rtl of ms_eval_tariff is

    type t_state is (MS_IDLE, MS_PROCESS, MS_DONE);
    signal state : t_state;

    signal reg_data_in  : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal reg_data_out : std_logic_vector(C_DATA_WIDTH-1 downto 0);

begin

    data_out <= reg_data_out;

    --------------------------------------------------------------------
    -- FSM síncrona simples
    --------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state        <= MS_IDLE;
            reg_data_in  <= (others => '0');
            reg_data_out <= (others => '0');
            done         <= '0';
        elsif rising_edge(clk) then

            -- default a cada ciclo
            done <= '0';

            case state is

                when MS_IDLE =>
                    if req = '1' then
                        reg_data_in <= data_in;              -- captura entrada
                        state       <= MS_PROCESS;
                    end if;

                when MS_PROCESS =>
                    case reg_data_in(7 downto 6) is
							 when "00" => reg_data_out <= x"01"; -- verde  -> peso 1
							 when "01" => reg_data_out <= x"02"; -- amarela-> peso 2
							 when "10" => reg_data_out <= x"03"; -- vermelha->peso3
							 when others => reg_data_out <= x"04"; -- especial->peso4
						  end case;
                    state <= MS_DONE;

                when MS_DONE =>
                    done  <= '1';      -- avisa 1 ciclo que terminou
                    state <= MS_IDLE;

                when others =>
                    state <= MS_IDLE;

            end case;
        end if;
    end process;

end architecture rtl;
