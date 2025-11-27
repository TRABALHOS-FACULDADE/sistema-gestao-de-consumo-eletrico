library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.soa_resource_pkg.all;

entity ms_fuzzy_risk is
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;

        req      : in  std_logic;  -- pulso de requisição
        done     : out std_logic;  -- pulso de conclusão

        data_in  : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);
        data_out : out std_logic_vector(C_DATA_WIDTH-1 downto 0)
    );
end ms_fuzzy_risk;

architecture rtl of ms_fuzzy_risk is

    type t_state is (MS_IDLE, MS_PROCESS, MS_DONE);
    signal state : t_state;

    signal reg_in  : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal reg_out : std_logic_vector(C_DATA_WIDTH-1 downto 0);

    signal risk_code : std_logic_vector(1 downto 0);

begin

    data_out <= reg_out;

    --------------------------------------------------------------------
    -- "Fuzzy" por faixas (uso_norm + modo → risco)
    --  reg_in(3 downto 0) = uso_normalizado (0..15)
    --  reg_in(5 downto 4) = modo/condição (00=boa, 01=normal, 10/11=ruim)
    --------------------------------------------------------------------
    process(reg_in)
        variable usage  : unsigned(3 downto 0);
        variable cond   : std_logic_vector(1 downto 0);
        variable u      : integer range 0 to 15;
    begin
        usage := unsigned(reg_in(3 downto 0));
        cond  := reg_in(5 downto 4);
        u     := to_integer(usage);

        ----------------------------------------------------------------
        -- Regras calibradas:
        --
        -- cond = "00" (boa):
        --   u <= 3  → OK
        --   4..7    → ALERTA
        --   >= 8    → CRÍTICO
        --
        -- cond = "01" (normal):
        --   u <= 2  → OK
        --   3..6    → ALERTA
        --   >= 7    → CRÍTICO
        --
        -- cond = "10" ou "11" (ruim/crítica):
        --   u <= 1  → ALERTA
        --   >= 2    → CRÍTICO
        ----------------------------------------------------------------
        if cond = "00" then
            if u <=2  then
                risk_code <= RISK_OK_CODE;
            elsif u <= 5 then
                risk_code <= RISK_WARN_CODE;
            else
                risk_code <= RISK_CRIT_CODE;
            end if;

        elsif cond = "01" then
            if u <= 1 then
                risk_code <= RISK_OK_CODE;
            elsif u <= 3 then
                risk_code <= RISK_WARN_CODE;
            else
                risk_code <= RISK_CRIT_CODE;
            end if;

        else
            if u = 0 then
                risk_code <= RISK_WARN_CODE;
            else
                risk_code <= RISK_CRIT_CODE;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- FSM: registra entrada na borda do req e produz saída 1 ciclo depois
    --------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state   <= MS_IDLE;
            reg_in  <= (others => '0');
            reg_out <= (others => '0');
            done    <= '0';

        elsif rising_edge(clk) then
            done <= '0';  -- default

            case state is

                when MS_IDLE =>
                    if req = '1' then
                        -- LATCH da entrada enquanto o serviço de risco ainda
                        -- está em S_CALL_FUZZY fornecendo v_fuzzy_in correto
                        reg_in <= data_in;
                        state  <= MS_PROCESS;
                    end if;

                when MS_PROCESS =>
                    reg_out              <= (others => '0');
                    reg_out(1 downto 0)  <= risk_code;  -- 2 LSB = código de risco
                    state                <= MS_DONE;

                when MS_DONE =>
                    done  <= '1';
                    state <= MS_IDLE;

                when others =>
                    state <= MS_IDLE;

            end case;
        end if;
    end process;

end architecture rtl;
