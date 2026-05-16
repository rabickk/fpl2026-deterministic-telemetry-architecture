library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_module is
    port (
        clk_100MHz : in std_logic;
        reset_n    : in std_logic;
        tmp_sda    : inout std_logic;
        tmp_scl    : inout std_logic;
        uart_txd   : out std_logic;
        seg        : out std_logic_vector(6 downto 0);
        an         : out std_logic_vector(7 downto 0);
        dp         : out std_logic
    );
end top_module;

architecture Behavioral of top_module is

    signal temp_raw   : std_logic_vector(15 downto 0);
    signal ready      : std_logic;

    signal d3, d2, d1, d0 : std_logic_vector(3 downto 0) := (others => '0');

    signal s_temp_x10 : integer range -999 to 9999 := 0;

    signal uart_busy  : std_logic;
    signal uart_start : std_logic := '0';
    signal uart_data  : std_logic_vector(7 downto 0) := x"41";

    -- ? DEBUG SIGNALS
    signal dbg_temp_raw  : std_logic_vector(15 downto 0);
    signal dbg_ready     : std_logic;
    signal dbg_temp_x10  : std_logic_vector(15 downto 0);
    
    signal dbg_sample_tick : std_logic := '0';
signal sample_cnt      : unsigned(23 downto 0) := (others => '0');


    signal dbg_slow_clk : std_logic := '0';
signal slow_cnt     : unsigned(23 downto 0) := (others => '0');


    attribute mark_debug : string;
    attribute mark_debug of dbg_temp_raw  : signal is "true";
    attribute mark_debug of dbg_ready     : signal is "true";
    attribute mark_debug of dbg_temp_x10  : signal is "true";
attribute mark_debug of dbg_slow_clk : signal is "true";
attribute mark_debug of dbg_sample_tick : signal is "true";
begin

process(clk_100MHz, reset_n)
begin
    if reset_n = '0' then
        sample_cnt      <= (others => '0');
        dbg_sample_tick <= '0';
    elsif rising_edge(clk_100MHz) then
        if sample_cnt = 10000000 then
            sample_cnt      <= (others => '0');
            dbg_sample_tick <= '1';
        else
            sample_cnt      <= sample_cnt + 1;
            dbg_sample_tick <= '0';
        end if;
    end if;
end process;

process(clk_100MHz, reset_n)
begin
    if reset_n = '0' then
        slow_cnt     <= (others => '0');
        dbg_slow_clk <= '0';
    elsif rising_edge(clk_100MHz) then
        if slow_cnt = 5000000 then
            slow_cnt     <= (others => '0');
            dbg_slow_clk <= not dbg_slow_clk;
        else
            slow_cnt <= slow_cnt + 1;
        end if;
    end if;
end process;
    -- ? DEBUG BAÐLANTILARI
    dbg_temp_raw <= temp_raw;
    dbg_ready    <= ready;
    dbg_temp_x10 <= std_logic_vector(to_signed(s_temp_x10,16));


    i2c_inst : entity work.i2c_master
        port map (
            clk        => clk_100MHz,
            reset_n    => reset_n,
            sda        => tmp_sda,
            scl        => tmp_scl,
            temp_data  => temp_raw,
            data_ready => ready
        );

    process(clk_100MHz, reset_n)
        variable temp_calc : integer;
        variable abs_temp  : integer;
        variable raw13     : signed(12 downto 0);
    begin
        if reset_n = '0' then
            s_temp_x10 <= 0;
            d3 <= "0000";
            d2 <= "0000";
            d1 <= "0000";
            d0 <= "0000";
            uart_start <= '0';
            uart_data  <= x"41";

        elsif rising_edge(clk_100MHz) then
            uart_start <= '0';

            if ready = '1' then
                -- ADT7420 13-bit sýcaklýk formatý varsayýmý:
                -- temp_raw(15 downto 3) anlamlý veri
                -- 1 LSB = 0.0625 C
                -- sýcaklýk_x10 = raw13 * 0.625
                raw13 := signed(temp_raw(15 downto 3));
                temp_calc := (to_integer(raw13) * 625) / 1000;

                -- saçma veri gelirse eski deðeri koru
                if (temp_calc >= -400) and (temp_calc <= 1250) then
                    s_temp_x10 <= temp_calc;

                    if temp_calc < 0 then
                        abs_temp := -temp_calc;
                    else
                        abs_temp := temp_calc;
                    end if;

                    -- XX.X formatý
                    d3 <= std_logic_vector(to_unsigned((abs_temp / 100) mod 10, 4));
                    d2 <= std_logic_vector(to_unsigned((abs_temp / 10) mod 10, 4));
                    d1 <= std_logic_vector(to_unsigned(abs_temp mod 10, 4));
                    d0 <= "0000";

                    -- UART debug için son rakamý gönder
                    uart_data  <= std_logic_vector(to_unsigned(48 + (abs_temp mod 10), 8));
                    uart_start <= '1';
                end if;
            end if;
        end if;
    end process;

    seg_inst : entity work.seven_seg_controller
        port map (
            clk           => clk_100MHz,
            reset_n       => reset_n,
            digit3        => d3,
            digit2        => d2,
            digit1        => d1,
            digit0        => d0,
            segments      => seg,
            decimal_point => dp,
            anodes        => an
        );

    uart_inst : entity work.uart_tx
        port map (
            clk      => clk_100MHz,
            tx_start => uart_start,
            tx_data  => uart_data,
            tx_out   => uart_txd,
            tx_busy  => uart_busy
        );

end Behavioral;