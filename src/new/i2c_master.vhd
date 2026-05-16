library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2c_master is
    port (
        clk        : in    std_logic;
        reset_n    : in    std_logic;
        sda        : inout std_logic;
        scl        : inout std_logic;
        temp_data  : out   std_logic_vector(15 downto 0);
        data_ready : out   std_logic
    );
end i2c_master;

architecture Behavioral of i2c_master is

    type state_type is (
        IDLE,
        START_1,
        SEND_ADDR_W,
        ACK_ADDR_W,
        SEND_REG_PTR,
        ACK_REG_PTR,
        START_2,
        SEND_ADDR_R,
        ACK_ADDR_R,
        READ_MSB,
        SEND_ACK,
        READ_LSB,
        SEND_NACK,
        STOP_1,
        STOP_2,
        DONE
    );

    signal state : state_type := IDLE;

    constant SLAVE_ADDR : std_logic_vector(6 downto 0) := "1001011";
    constant REG_TEMP   : std_logic_vector(7 downto 0) := x"00";

    constant DIVIDER : integer := 250;
    signal div_cnt   : integer range 0 to DIVIDER-1 := 0;
    signal tick      : std_logic := '0';

    signal phase     : integer range 0 to 3 := 0;
    signal bit_cnt   : integer range 0 to 7 := 7;
    signal shifter   : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_msb    : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_lsb    : std_logic_vector(7 downto 0) := (others => '0');

    signal sda_oe    : std_logic := '0';
    signal scl_oe    : std_logic := '0';

    signal temp_reg  : std_logic_vector(15 downto 0) := (others => '0');
    signal ready_reg : std_logic := '0';

begin

    sda <= '0' when sda_oe = '1' else 'Z';
    scl <= '0' when scl_oe = '1' else 'Z';

    temp_data  <= temp_reg;
    data_ready <= ready_reg;

    process(clk, reset_n)
    begin
        if reset_n = '0' then
            div_cnt <= 0;
            tick    <= '0';
        elsif rising_edge(clk) then
            if div_cnt = DIVIDER-1 then
                div_cnt <= 0;
                tick    <= '1';
            else
                div_cnt <= div_cnt + 1;
                tick    <= '0';
            end if;
        end if;
    end process;

    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state     <= IDLE;
            phase     <= 0;
            bit_cnt   <= 7;
            shifter   <= (others => '0');
            rx_msb    <= (others => '0');
            rx_lsb    <= (others => '0');
            temp_reg  <= (others => '0');
            ready_reg <= '0';
            sda_oe    <= '0';
            scl_oe    <= '0';

        elsif rising_edge(clk) then
            ready_reg <= '0';

            if tick = '1' then
                case state is

                    when IDLE =>
                        sda_oe  <= '0';
                        scl_oe  <= '0';
                        phase   <= 0;
                        bit_cnt <= 7;
                        state   <= START_1;

                    when START_1 =>
                        case phase is
                            when 0 =>
                                sda_oe <= '0'; scl_oe <= '0'; phase <= 1;
                            when 1 =>
                                sda_oe <= '1'; scl_oe <= '0'; phase <= 2;
                            when 2 =>
                                scl_oe <= '1'; phase <= 3;
                            when others =>
                                shifter <= SLAVE_ADDR & '0';
                                bit_cnt <= 7;
                                phase   <= 0;
                                state   <= SEND_ADDR_W;
                        end case;

                    when SEND_ADDR_W =>
                        case phase is
                            when 0 =>
                                scl_oe <= '1';
                                if shifter(bit_cnt) = '0' then
                                    sda_oe <= '1';
                                else
                                    sda_oe <= '0';
                                end if;
                                phase <= 1;
                            when 1 =>
                                scl_oe <= '0';
                                phase <= 2;
                            when 2 =>
                                phase <= 3;
                            when others =>
                                scl_oe <= '1';
                                if bit_cnt = 0 then
                                    sda_oe <= '0';
                                    phase <= 0;
                                    state <= ACK_ADDR_W;
                                else
                                    bit_cnt <= bit_cnt - 1;
                                    phase <= 0;
                                end if;
                        end case;

                    when ACK_ADDR_W =>
                        case phase is
                            when 0 =>
                                scl_oe <= '1'; sda_oe <= '0'; phase <= 1;
                            when 1 =>
                                scl_oe <= '0'; phase <= 2;
                            when 2 =>
                                phase <= 3;
                            when others =>
                                scl_oe <= '1';
                                shifter <= REG_TEMP;
                                bit_cnt <= 7;
                                phase <= 0;
                                state <= SEND_REG_PTR;
                        end case;

                    when SEND_REG_PTR =>
                        case phase is
                            when 0 =>
                                scl_oe <= '1';
                                if shifter(bit_cnt) = '0' then
                                    sda_oe <= '1';
                                else
                                    sda_oe <= '0';
                                end if;
                                phase <= 1;
                            when 1 =>
                                scl_oe <= '0';
                                phase <= 2;
                            when 2 =>
                                phase <= 3;
                            when others =>
                                scl_oe <= '1';
                                if bit_cnt = 0 then
                                    sda_oe <= '0';
                                    phase <= 0;
                                    state <= ACK_REG_PTR;
                                else
                                    bit_cnt <= bit_cnt - 1;
                                    phase <= 0;
                                end if;
                        end case;

                    when ACK_REG_PTR =>
                        case phase is
                            when 0 =>
                                scl_oe <= '1'; sda_oe <= '0'; phase <= 1;
                            when 1 =>
                                scl_oe <= '0'; phase <= 2;
                            when 2 =>
                                phase <= 3;
                            when others =>
                                scl_oe <= '1';
                                phase <= 0;
                                state <= START_2;
                        end case;

                    when START_2 =>
                        case phase is
                            when 0 =>
                                sda_oe <= '0'; scl_oe <= '0'; phase <= 1;
                            when 1 =>
                                sda_oe <= '1'; scl_oe <= '0'; phase <= 2;
                            when 2 =>
                                scl_oe <= '1'; phase <= 3;
                            when others =>
                                shifter <= SLAVE_ADDR & '1';
                                bit_cnt <= 7;
                                phase   <= 0;
                                state   <= SEND_ADDR_R;
                        end case;

                    when SEND_ADDR_R =>
                        case phase is
                            when 0 =>
                                scl_oe <= '1';
                                if shifter(bit_cnt) = '0' then
                                    sda_oe <= '1';
                                else
                                    sda_oe <= '0';
                                end if;
                                phase <= 1;
                            when 1 =>
                                scl_oe <= '0';
                                phase <= 2;
                            when 2 =>
                                phase <= 3;
                            when others =>
                                scl_oe <= '1';
                                if bit_cnt = 0 then
                                    sda_oe <= '0';
                                    phase <= 0;
                                    state <= ACK_ADDR_R;
                                else
                                    bit_cnt <= bit_cnt - 1;
                                    phase <= 0;
                                end if;
                        end case;

                    when ACK_ADDR_R =>
                        case phase is
                            when 0 =>
                                scl_oe <= '1'; sda_oe <= '0'; phase <= 1;
                            when 1 =>
                                scl_oe <= '0'; phase <= 2;
                            when 2 =>
                                phase <= 3;
                            when others =>
                                scl_oe <= '1';
                                bit_cnt <= 7;
                                sda_oe <= '0';
                                phase <= 0;
                                state <= READ_MSB;
                        end case;

                    when READ_MSB =>
                        case phase is
                            when 0 =>
                                scl_oe <= '1'; sda_oe <= '0'; phase <= 1;
                            when 1 =>
                                scl_oe <= '0';
                                rx_msb(bit_cnt) <= sda;
                                phase <= 2;
                            when 2 =>
                                phase <= 3;
                            when others =>
                                scl_oe <= '1';
                                if bit_cnt = 0 then
                                    phase <= 0;
                                    state <= SEND_ACK;
                                else
                                    bit_cnt <= bit_cnt - 1;
                                    phase <= 0;
                                end if;
                        end case;

                    when SEND_ACK =>
                        case phase is
                            when 0 =>
                                scl_oe <= '1'; sda_oe <= '1'; phase <= 1;
                            when 1 =>
                                scl_oe <= '0'; phase <= 2;
                            when 2 =>
                                phase <= 3;
                            when others =>
                                scl_oe <= '1';
                                sda_oe <= '0';
                                bit_cnt <= 7;
                                phase <= 0;
                                state <= READ_LSB;
                        end case;

                    when READ_LSB =>
                        case phase is
                            when 0 =>
                                scl_oe <= '1'; sda_oe <= '0'; phase <= 1;
                            when 1 =>
                                scl_oe <= '0';
                                rx_lsb(bit_cnt) <= sda;
                                phase <= 2;
                            when 2 =>
                                phase <= 3;
                            when others =>
                                scl_oe <= '1';
                                if bit_cnt = 0 then
                                    phase <= 0;
                                    state <= SEND_NACK;
                                else
                                    bit_cnt <= bit_cnt - 1;
                                    phase <= 0;
                                end if;
                        end case;

                    when SEND_NACK =>
                        case phase is
                            when 0 =>
                                scl_oe <= '1'; sda_oe <= '0'; phase <= 1;
                            when 1 =>
                                scl_oe <= '0'; phase <= 2;
                            when 2 =>
                                phase <= 3;
                            when others =>
                                scl_oe <= '1';
                                phase <= 0;
                                state <= STOP_1;
                        end case;

                    when STOP_1 =>
                        case phase is
                            when 0 =>
                                scl_oe <= '1'; sda_oe <= '1'; phase <= 1;
                            when 1 =>
                                scl_oe <= '0'; phase <= 2;
                            when 2 =>
                                phase <= 3;
                            when others =>
                                state <= STOP_2;
                                phase <= 0;
                        end case;

                    when STOP_2 =>
                        case phase is
                            when 0 =>
                                sda_oe <= '1'; scl_oe <= '0'; phase <= 1;
                            when 1 =>
                                sda_oe <= '0'; scl_oe <= '0'; phase <= 2;
                            when 2 =>
                                phase <= 3;
                            when others =>
                                state <= DONE;
                                phase <= 0;
                        end case;

                    when DONE =>
                        temp_reg  <= rx_msb & rx_lsb;
                        ready_reg <= '1';
                        state     <= IDLE;

                    when others =>
                        state <= IDLE;

                end case;
            end if;
        end if;
    end process;

end Behavioral;