library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity seven_seg_controller is
    port (
        clk           : in  std_logic;
        reset_n       : in  std_logic;
        digit0        : in  std_logic_vector(3 downto 0); -- en sağ
        digit1        : in  std_logic_vector(3 downto 0);
        digit2        : in  std_logic_vector(3 downto 0);
        digit3        : in  std_logic_vector(3 downto 0); -- en sol
        segments      : out std_logic_vector(6 downto 0);
        decimal_point : out std_logic;
        anodes        : out std_logic_vector(7 downto 0)
    );
end seven_seg_controller;

architecture Behavioral of seven_seg_controller is
    signal refresh_counter : unsigned(17 downto 0) := (others => '0');
    signal digit_select    : std_logic_vector(1 downto 0);
    signal active_digit    : std_logic_vector(3 downto 0) := (others => '0');
begin

    process(clk, reset_n)
    begin
        if reset_n = '0' then
            refresh_counter <= (others => '0');
        elsif rising_edge(clk) then
            refresh_counter <= refresh_counter + 1;
        end if;
    end process;

    digit_select <= std_logic_vector(refresh_counter(17 downto 16));

    process(digit_select, digit0, digit1, digit2, digit3)
    begin
        anodes        <= "11111111";
        decimal_point <= '1';
        active_digit  <= "1111";

        case digit_select is
            when "00" =>
                anodes(0)    <= '0';
                active_digit <= digit0;

            when "01" =>
    anodes(1)    <= '0';
    active_digit <= digit1;
    
            when "10" =>
    anodes(2)    <= '0';
    active_digit <= digit2;
    decimal_point <= '0';
    
            when "11" =>
                anodes(3)    <= '0';
                active_digit <= digit3;

            when others =>
                anodes        <= "11111111";
                decimal_point <= '1';
                active_digit  <= "1111";
        end case;
    end process;

   process(active_digit)
begin
    case active_digit is
        -- segments(6 downto 0) = g f e d c b a
        -- active low

        when "0000" => segments <= "1000000"; -- 0
        when "0001" => segments <= "1111001"; -- 1
        when "0010" => segments <= "0100100"; -- 2
        when "0011" => segments <= "0110000"; -- 3
        when "0100" => segments <= "0011001"; -- 4
        when "0101" => segments <= "0010010"; -- 5
        when "0110" => segments <= "0000010"; -- 6
        when "0111" => segments <= "1111000"; -- 7
        when "1000" => segments <= "0000000"; -- 8
        when "1001" => segments <= "0010000"; -- 9
        when others => segments <= "1111111"; -- boş
    end case;
end process;
end Behavioral;