library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx is
    port (
        clk      : in  std_logic;
        tx_start : in  std_logic;
        tx_data  : in  std_logic_vector(7 downto 0);
        tx_out   : out std_logic;
        tx_busy  : out std_logic
    );
end uart_tx;

architecture rtl of uart_tx is
    constant CLKS_PER_BIT : integer := 868;

    signal clk_cnt        : integer range 0 to CLKS_PER_BIT-1 := 0;
    signal bit_idx        : integer range 0 to 9 := 0;
    signal shift_reg      : std_logic_vector(9 downto 0) := (others => '1');
    signal r_tx_busy      : std_logic := '0';
    signal r_tx_out       : std_logic := '1';

    signal tx_start_d     : std_logic := '0';
    signal tx_start_pulse : std_logic := '0';
begin

    tx_busy <= r_tx_busy;
    tx_out  <= r_tx_out;

    process(clk)
    begin
        if rising_edge(clk) then
            tx_start_d     <= tx_start;
            tx_start_pulse <= tx_start and not tx_start_d;

            if r_tx_busy = '0' then
                r_tx_out <= '1';
                clk_cnt  <= 0;
                bit_idx  <= 0;

                if tx_start_pulse = '1' then
                    shift_reg <= '1' & tx_data & '0';
                    r_tx_busy <= '1';
                end if;

            else
                r_tx_out <= shift_reg(bit_idx);

                if clk_cnt = CLKS_PER_BIT-1 then
                    clk_cnt <= 0;

                    if bit_idx = 9 then
                        r_tx_busy <= '0';
                        bit_idx   <= 0;
                    else
                        bit_idx <= bit_idx + 1;
                    end if;
                else
                    clk_cnt <= clk_cnt + 1;
                end if;
            end if;
        end if;
    end process;

end rtl;