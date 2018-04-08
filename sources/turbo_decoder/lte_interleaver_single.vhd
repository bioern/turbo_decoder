--------------------------------------------------------------------------------
--  Project:    LTE Turbo Decoder
--  Component:  LTE Interleaver Single
--  Author:     Vadim Belov
--------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use IEEE.STD_LOGIC_ARITH.ALL;
    use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity lte_interleaver is
    generic (
        WIDTH               : integer range 1 to 256 := 8;
        EFFECT              : std_logic := '0' -- '0' = interleaver, '1' = deinterleaver
    );
    port(
        CLK                 : in std_logic;
        RST                 : in std_logic;
        -- Init
        INIT                : in std_logic;
        SIZE_INDEX          : in std_logic_vector(7 downto 0); 
        BLOCK_SIZE          : in std_logic_vector(12 downto 0);
        -- Input
        READ_INPUT          : in std_logic; -- read input stored data from last step (ONLY for interleaver)
        FDVI                : in std_logic;
        DVI                 : in std_logic;
        DI                  : in std_logic_vector((WIDTH - 1) downto 0); 
        RFD                 : out std_logic;
        -- Output
        FDVO                : out std_logic;
        DVO                 : out std_logic;
        DO                  : out std_logic_vector((WIDTH - 1) downto 0)
    );
end lte_interleaver;

architecture lte_interleaver_arch of lte_interleaver is

-------------------------------------------------------------------------------
-->>>>>>>>>>> declaration component lte_interleaver_divider <<<<<<<<<<<<<<--
------------------------------------------------------------------------------- 
component lte_interleaver_divider
    port (
        clk          : in std_logic;
        rfd          : out std_logic;
        dividend     : in std_logic_vector(25 downto 0);
        divisor      : in std_logic_vector(12 downto 0);
        quotient     : out std_logic_vector(25 downto 0);
        fractional   : out std_logic_vector(12 downto 0)
    );
end component;
-- interface signals
signal div_rfd                  : std_logic := '0';
signal div_dividend             : std_logic_vector(25 downto 0) := (others => '0'); 
signal div_divisor              : std_logic_vector(12 downto 0) := (others => '0'); 
signal div_quotient             : std_logic_vector(25 downto 0) := (others => '0'); 
signal div_fractional           : std_logic_vector(12 downto 0) := (others => '0'); 
signal div_tact                 : std_logic_vector(5 downto 0) := (others => '1');

-------------------------------------------------------------------------------
-->>>>>>>>>>> declaration component lte_interleaver_table_sram <<<<<<<<<<<<<<--
------------------------------------------------------------------------------- 
component lte_interleaver_table_sram
    port (
        clka    : in std_logic;
        wea     : in std_logic_vector(0 downto 0);
        addra   : in std_logic_vector(12 downto 0);
        dina    : in std_logic_vector(12 downto 0);
        clkb    : in std_logic;
        addrb   : in std_logic_vector(12 downto 0);
        doutb   : out std_logic_vector(12 downto 0)
    );
end component;
-- interface signals
signal s_w_dvi                  : std_logic := '0';
signal s_w_addr                 : std_logic_vector(12 downto 0) := (others => '0');
signal s_w_di                   : std_logic_vector(12 downto 0) := (others => '0');
signal s_r_addr                 : std_logic_vector(12 downto 0) := (others => '0');
signal s_r_do                   : std_logic_vector(12 downto 0) := (others => '0');

-------------------------------------------------------------------------------
-->>>>>>>>>>> declaration component lte_interleaver_data_sram <<<<<<<<<<<<<<--
------------------------------------------------------------------------------- 
component lte_interleaver_data_sram
    port (
        clka    : in std_logic;
        wea     : in std_logic_vector(0 downto 0);
        addra   : in std_logic_vector(12 downto 0);
        dina    : in std_logic_vector((WIDTH - 1) downto 0);
        clkb    : in std_logic;
        addrb   : in std_logic_vector(12 downto 0);
        doutb   : out std_logic_vector((WIDTH - 1) downto 0)
    );
end component;
-- interface signals
signal s_data_w_dvi             : std_logic := '0';
signal s_data_w_addr            : std_logic_vector(12 downto 0) := (others => '0');
signal s_data_w_di              : std_logic_vector((WIDTH - 1) downto 0) := (others => '0');
signal s_data_r_addr            : std_logic_vector(12 downto 0) := (others => '0');
signal s_data_r_do              : std_logic_vector((WIDTH - 1) downto 0) := (others => '0');


type f_type is array (0 to 187) of integer range 0 to 1000;
-- Constanst
constant f1 : f_type := (
            3,  7,  19, 7,  7,  11, 5,  11, 7,  41, 103,15, 9,  17, 9,  21, 101, 
            21, 57, 23, 13, 27, 11, 27, 85, 29, 33, 15, 17, 33, 103,19, 19, 37, 
            19, 21, 21, 115,193,21, 133,81, 45, 23, 243,151,155,25, 51, 47, 91,
            29, 29, 247,29, 89, 91, 157,55, 31, 17, 35, 227,65, 19, 37, 41, 39,
            185,43, 21, 155,79, 139,23, 217,25, 17, 127,25, 239,17, 137,215,29, 
            15, 147,29, 59, 65, 55, 31, 17, 171,67, 35, 19, 39, 19, 199,21, 211, 
            21, 43, 149,45, 49, 71, 13, 17, 25, 183,55, 127,27, 29, 29, 57, 45, 
            31, 59, 185,113,31, 17, 171,209,253,367,265,181,39, 27, 127,143,43, 
            29, 45, 157,47, 13, 111,443,51, 51, 451,257,57, 313,271,179,331,363, 
            375,127,31, 33, 43, 33, 477,35, 233,357,337,37, 71, 71, 37, 39, 127, 
            39, 39, 31, 113,41, 251,43, 21, 43, 45, 45, 161,89, 323,47, 23, 47,
            263
);
constant f2 : f_type := (
            10, 12, 42, 16, 18, 20, 22, 24, 26, 84, 90, 32, 34, 108,38, 120,84, 
            44, 46, 48, 50, 52, 36, 56, 58, 60, 62, 32, 198,68, 210,36, 74, 76, 
            78, 120,82, 84, 86, 44, 90, 46, 94, 48, 98, 40, 102,52, 106,72, 110, 
            168,114,58, 118,180,122,62, 84, 64, 66, 68, 420,96, 74, 76, 234,80, 
            82, 252,86, 44, 120,92, 94, 48, 98, 80, 102,52, 106,48, 110,112,114, 
            58, 118,60, 122,124,84, 64, 66, 204,140,72, 74, 76, 78, 240,82, 252, 
            86, 88, 60, 92, 846,48, 28, 80, 102,104,954,96, 110,112,114,116,354, 
            120,610,124,420,64, 66, 136,420,216,444,456,468,80, 164,504,172,88, 
            300,92, 188,96, 28, 240,204,104,212,192,220,336,228,232,236,120,244, 
            248,168,64, 130,264,134,408,138,280,142,480,146,444,120,152,462,234, 
            158,80, 96, 902,166,336,170,86, 174,176,178,120,182,184,186,94, 190, 
            480
);

-- work signals
type state_machine is (INIT_ST, WAIT_ST, WRITE_ST, READ_OUTPUT_ST, READ_INPUT_ST); 
signal state                    : state_machine := WAIT_ST; 
signal d_size_index             : std_logic_vector(7 downto 0) := (others => '0'); 
signal d_block_size             : std_logic_vector(12 downto 0) := (others => '0'); 
signal rfd_into                 : std_logic := '0';
signal d_init                   : std_logic_vector(1 downto 0) := (others => '0'); 

--signal table_forming_cnt        : std_logic_vector(12 downto 0) := (others => '0');
--signal table_forming_circle     : std_logic_vector(20 downto 0) := (others => '0');
signal i_cnt                    : std_logic_vector(12 downto 0) := (others => '0'); 
type d_i_cnt_type is array (32 downto 0) of std_logic_vector(12 downto 0);
signal d_i_cnt                  : d_i_cnt_type := (others => (others => '0'));  
signal i_circle                 : std_logic_vector(32 downto 0) := (others => '0'); 
signal t1                       : std_logic_vector(12 downto 0) := (others => '0'); 
signal t2                       : std_logic_vector(25 downto 0) := (others => '0'); 

signal d_fdvi                   : std_logic_vector(2 downto 0) := (others => '0');
signal d_dvi                    : std_logic_vector(2 downto 0) := (others => '0');
type d_di_type is array (2 downto 0) of std_logic_vector((WIDTH - 1) downto 0);
signal d_di                     : d_di_type := (others => (others => '0'));  
signal in_cnt                   : std_logic_vector(12 downto 0) := (others => '0'); 
signal out_cnt                  : std_logic_vector(12 downto 0) := (others => '1');
type d_out_cnt_type is array (3 downto 0) of std_logic_vector(12 downto 0);
signal d_out_cnt                : d_out_cnt_type := (others => (others => '1'));
signal out_circle               : std_logic_vector(3 downto 0) := (others => '0'); 
signal dvo_into                 : std_logic := '0';
signal fdvo_flag                : std_logic := '0';
signal fdvo_into                : std_logic := '0';
signal do_into                  : std_logic_vector((WIDTH - 1) downto 0) := (others => '0'); 


begin

    -- main process with state and interleaver table forming
    process(CLK, RST)
    begin
        
        if (RST = '1') then

            
        elsif (CLK'event and CLK = '1') then

            case state is
                when INIT_ST => 
                    if (i_cnt = d_block_size and i_circle = 0) then
                        state <= WAIT_ST;
                    end if;
                when WAIT_ST =>   
                    if (INIT = '1') then
                        state <= INIT_ST;
                    elsif (FDVI = '1' and DVI = '1') then
                        state <= WRITE_ST;
                    elsif (READ_INPUT = '1') then
                        state <= READ_INPUT_ST;
                    end if; 
                when WRITE_ST => 
                    if (INIT = '1') then
                        state <= INIT_ST;
                    elsif (in_cnt = (d_block_size-2) and DVI = '1') then
                        state <= READ_OUTPUT_ST;
                    end if;
                when READ_OUTPUT_ST => 
                    if (INIT = '1') then
                        state <= INIT_ST;
                    elsif (out_cnt = (d_block_size+3)) then
                        state <= WAIT_ST;
                    end if;   
                when READ_INPUT_ST => 
                    if (INIT = '1') then
                        state <= INIT_ST;
                    elsif (out_cnt = (d_block_size+3)) then
                        state <= WAIT_ST;
                    end if; 
            end case;
            
            -- Latching data
            if (INIT = '1') then
                d_size_index <= SIZE_INDEX;
                d_block_size <= BLOCK_SIZE;
            end if;
        
            -- delay singnals
            d_init <= d_init(0) & INIT;
            
            
        -- Interleaver table forming
            -- Interleaver counter
            if (state = INIT_ST and div_rfd = '1') then
                if (d_init > 0) then
                    i_cnt <= (others => '0');
                elsif (i_cnt < d_block_size) then
                    i_cnt <= i_cnt + 1;
                end if;
            end if;
            d_i_cnt <= d_i_cnt(31 downto 0) & i_cnt;

            -- i_circle
            if (state = INIT_ST and div_rfd = '1' and i_cnt < (d_block_size - 1)) then
                i_circle <= i_circle(31 downto 0) & '1';
            else    
                i_circle <= i_circle(31 downto 0) & '0';
            end if;

            -- (i*((f1 + f2*i) mod K)) mod K

            -- t1 = (f1 + f2*i) mod K
            if (i_circle(0) = '1') then
                if (i_cnt = 0) then
                    t1 <= conv_std_logic_vector(f1(conv_integer(d_size_index)), 13); 
                else
                    t1 <= t1 + conv_std_logic_vector(f2(conv_integer(d_size_index)),13);
                end if;
            elsif (i_circle(1) = '1') then
                if (t1 >= d_block_size) then
                    t1 <= t1 - d_block_size;
                end if;
            end if;
            
            -- t3 = i*((f1 + f2*i) mod K)
            if (i_circle(2) = '1') then
                t2 <= d_i_cnt(0) * t1;
            end if;

            -- Writing interleaver to memmory
            if (i_circle(32) = '1') then
                s_w_dvi <= '1';
                s_w_addr <= d_i_cnt(31);
                s_w_di <= div_fractional;
            else
                s_w_dvi <= '0';
            end if;
 
        end if;
    end process;


    -- interleaver work circle
    process(CLK, RST)
    begin
        
        if (RST = '1') then

            
        elsif (CLK'event and CLK = '1') then

            -- Delays
            d_fdvi <= d_fdvi(1 downto 0) & FDVI;
            d_dvi <= d_dvi(1 downto 0) & DVI;
            d_di <= d_di(1 downto 0) & DI;

            -- RFD flag
            if (INIT = '1' or state = INIT_ST or state = READ_OUTPUT_ST or state = READ_INPUT_ST) then
                rfd_into <= '0';
            else
                rfd_into <= '1';
            end if;
        
            -- Input counter
            if (FDVI = '1' and DVI = '1') then
                in_cnt <= (others => '0');
            elsif (DVI = '1') then
                in_cnt <= in_cnt + 1;
            elsif (in_cnt >= (d_block_size-1) and in_cnt <= (d_block_size + 2)) then
                in_cnt <= in_cnt + 1;
            end if;
            
            -- read interleaver from sram
            if (EFFECT = '0' and out_cnt < d_block_size) then  
                s_r_addr <= out_cnt;
            elsif (EFFECT = '1' and in_cnt < d_block_size) then
                s_r_addr <= in_cnt;
            end if;
            
            -- Writing data
            if (EFFECT = '0' and d_dvi(0) = '1') then
                s_data_w_dvi <= '1';
                s_data_w_di <= d_di(0);
                s_data_w_addr <= in_cnt;                
            elsif (EFFECT = '1' and d_dvi(2) = '1') then
                s_data_w_dvi <= '1';
                s_data_w_di <= d_di(2);
                s_data_w_addr <= s_r_do;
            else
                s_data_w_dvi <= '0';
            end if;
  
            -- Output counter
            if (state /= READ_OUTPUT_ST and state /= READ_INPUT_ST) then
                out_cnt <= (others => '0');
            elsif ((state = READ_OUTPUT_ST or state = READ_INPUT_ST) and out_cnt < (d_block_size + 3)) then
                out_cnt <= out_cnt + 1;
            end if;
            d_out_cnt <= d_out_cnt(2 downto 0) & out_cnt;

            -- out_circle 
            if ((state = READ_OUTPUT_ST or state = READ_INPUT_ST) and out_cnt < d_block_size) then
                out_circle <= out_circle(2 downto 0) & '1';
            else
                out_circle <= out_circle(2 downto 0) & '0';
            end if;
            
            -- Reading data
            if (state = READ_OUTPUT_ST and out_circle(1) = '1') then
                if (EFFECT = '0') then
                    s_data_r_addr <= s_r_do;
                else
                    s_data_r_addr <= d_out_cnt(1);
                end if;
            elsif (state = READ_INPUT_ST and EFFECT = '0') then
                s_data_r_addr <= out_cnt;
            end if;            
            
            -- dvo and do
            if (state = READ_OUTPUT_ST and out_circle(3) = '1') then
                do_into <= s_data_r_do;
                dvo_into <= '1';         
            elsif (state = READ_INPUT_ST and EFFECT = '0' and out_circle(1) = '1') then
                do_into <= s_data_r_do;
                dvo_into <= '1';                  
            else
                dvo_into <= '0';
            end if; 
            
            --fdvo
            if (state = READ_OUTPUT_ST and out_circle(3) = '1' and d_out_cnt(3) = 0) then
                fdvo_into <= '1';
            elsif (state = READ_INPUT_ST and EFFECT = '0' and out_circle(1) = '1' and d_out_cnt(1) = 0) then
                fdvo_into <= '1'; 
            else
                fdvo_into <= '0';
            end if;   
            
        end if;
    end process;

    -------------------------------------------------------------------------------
    -->>>>>>>>>> initializing component lte_interleaver_divider <<<<<<<<<<<<<<<--
    -------------------------------------------------------------------------------
    -- Latency = 29 tacts;
    lte_interleaver_divider_inst : lte_interleaver_divider
        port map (
                clk         => CLK,
                rfd         => div_rfd,
                dividend    => div_dividend,
                divisor     => div_divisor,
                quotient    => div_quotient,
                fractional  => div_fractional
        ); 

    -------------------------------------------------------------------------------
    -->>>>>>>>>> initializing component lte_interleaver_table_sram <<<<<<<<<<<<<<<--
    -------------------------------------------------------------------------------
    lte_interleaver_table_sram_inst : lte_interleaver_table_sram
        port map (
            clka    => CLK,
            wea(0)  => s_w_dvi,
            addra   => s_w_addr,
            dina    => s_w_di,
            clkb    => CLK,
            addrb   => s_r_addr,
            doutb   => s_r_do
        );

    -------------------------------------------------------------------------------
    -->>>>>>>>>> initializing component lte_interleaver_data_sram <<<<<<<<<<<<<<<--
    -------------------------------------------------------------------------------
    lte_interleaver_data_sram_inst : lte_interleaver_data_sram
        port map (
            clka    => CLK,
            wea(0)  => s_data_w_dvi,
            addra   => s_data_w_addr,
            dina    => s_data_w_di,
            clkb    => CLK,
            addrb   => s_data_r_addr,
            doutb   => s_data_r_do
        );
   
    div_dividend <= t2;
    div_divisor <= d_block_size;
    RFD <= rfd_into;
    FDVO <= fdvo_into;
    DVO <= dvo_into;
    DO <= do_into;

    
    
end lte_interleaver_arch;



