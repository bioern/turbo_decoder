--------------------------------------------------------------------------------
--  Project:    LTE Turbo Decoder
--  Component:  Top module
--  Author:     Vadim Belov
--------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use IEEE.STD_LOGIC_ARITH.ALL;
    use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity lte_turbo_decoder is
    generic (
        WIDTH                   : integer range 1 to 16 := 2
    );          
    port(           
        CLK                     : in std_logic;
        RST                     : in std_logic;
        -- Init         
        INIT                    : in std_logic;
        ITERATIONS              : in std_logic_vector(3 downto 0);    
        SIZE_INDEX              : in std_logic_vector(7 downto 0);   
        -- Input            
        FDVI                    : in std_logic;
        DVI                     : in std_logic;
        DI0                     : in std_logic_vector((WIDTH - 1) downto 0); 
        DI1                     : in std_logic_vector((WIDTH - 1) downto 0); 
        DI2                     : in std_logic_vector((WIDTH - 1) downto 0); 
        RFD                     : out std_logic;
        -- Output           
        t_dvo                   : out std_logic;
        t_do                    : out std_logic_vector((WIDTH + 2) downto 0); 
        FDVO                    : out std_logic;
        DVO                     : out std_logic;
        DO                      : out std_logic
    );
end lte_turbo_decoder;

architecture lte_turbo_decoder_arch of lte_turbo_decoder is

constant INTERNAL_WIDTH         : integer := 4;

-------------------------------------------------------------------------------
-->>>>>>>>>>> declaration component lte_turbo_decoder_encoded_data_sram <<<<<<<<<<<<<<--
------------------------------------------------------------------------------- 
component lte_turbo_decoder_encoded_data_sram
    port (
        clka                    : in std_logic;
        wea                     : in std_logic_vector(0 downto 0);
        addra                   : in std_logic_vector(12 downto 0);
        dina                    : in std_logic_vector((WIDTH-1) downto 0);
        clkb                    : in std_logic;
        addrb                   : in std_logic_vector(12 downto 0);
        doutb                   : out std_logic_vector((WIDTH-1) downto 0)
    );
end component;
-- interface signals
signal sram_a_c_w_dvi           : std_logic := '0';
signal sram_a_c_w_addr          : std_logic_vector(12 downto 0) := (others => '0');
signal sram_a_c_w_di            : std_logic_vector((WIDTH - 1) downto 0) := (others => '0');
signal sram_a_c_r_addr          : std_logic_vector(12 downto 0) := (others => '0');
signal sram_a_c_r_do            : std_logic_vector((WIDTH - 1) downto 0) := (others => '0'); 
signal sram_c_c_w_dvi           : std_logic := '0';
signal sram_c_c_w_addr          : std_logic_vector(12 downto 0) := (others => '0');
signal sram_c_c_w_di            : std_logic_vector((WIDTH - 1) downto 0) := (others => '0');
signal sram_c_c_r_addr          : std_logic_vector(12 downto 0) := (others => '0');
signal sram_c_c_r_do            : std_logic_vector((WIDTH - 1) downto 0) := (others => '0'); 
signal sram_d_c_w_dvi           : std_logic := '0';
signal sram_d_c_w_addr          : std_logic_vector(12 downto 0) := (others => '0');
signal sram_d_c_w_di            : std_logic_vector((WIDTH - 1) downto 0) := (others => '0');
signal sram_d_c_r_addr          : std_logic_vector(12 downto 0) := (others => '0');
signal sram_d_c_r_do            : std_logic_vector((WIDTH - 1) downto 0) := (others => '0'); 

-------------------------------------------------------------------------------
-->>>>>>>>>>> declaration component lte_interleaver <<<<<<<<<<<<<<--
------------------------------------------------------------------------------- 
component lte_interleaver
    generic (
        WIDTH                   : integer range 1 to 256 := 5
--        EFFECT                  : std_logic := '0' -- '0' = interleaver, '1' = deinterleaver
    );  
    port(   
        CLK                     : in std_logic;
        RST                     : in std_logic;
        -- Init 
        INIT                    : in std_logic;
        SIZE_INDEX              : in std_logic_vector(7 downto 0); 
        BLOCK_SIZE              : in std_logic_vector(12 downto 0);
        -- Input    
        FDVI                    : in std_logic;
        MODE                    : in std_logic; 
        DVI                     : in std_logic;
        DI_0                    : in std_logic_vector((WIDTH - 1) downto 0); 
        DI_1                    : in std_logic_vector((WIDTH - 1) downto 0); 
        RFD                     : out std_logic;
        -- Output
        FDVO                    : out std_logic;
        DVO                     : out std_logic;
        DO_0                    : out std_logic_vector((WIDTH - 1) downto 0);
        DO_1                    : out std_logic_vector((WIDTH - 1) downto 0)
    );

end component;
signal interleaver_fdvi         : std_logic := '0';
signal interleaver_mode         : std_logic := '0';
signal interleaver_dvi          : std_logic := '0';
signal interleaver_di_0         : std_logic_vector((INTERNAL_WIDTH - 1) downto 0) := (others => '0');  
signal interleaver_di_1         : std_logic_vector((INTERNAL_WIDTH - 1) downto 0) := (others => '0');  
signal interleaver_rfd          : std_logic := '0';
signal interleaver_fdvo         : std_logic := '0';
signal interleaver_dvo          : std_logic := '0';
signal interleaver_do_0         : std_logic_vector((INTERNAL_WIDTH - 1) downto 0) := (others => '0');  
signal interleaver_do_1         : std_logic_vector((INTERNAL_WIDTH - 1) downto 0) := (others => '0');  
type interleaver_do_type is array(2 downto 0) of std_logic_vector((INTERNAL_WIDTH - 1) downto 0);
signal d_interleaver_do_0       : interleaver_do_type := (others => (others => '0'));
signal d_interleaver_do_1       : interleaver_do_type := (others => (others => '0'));

-------------------------------------------------------------------------------
-->>>>>>>>>>> declaration component bcjr_turbo_decoder <<<<<<<<<<<<<<--
------------------------------------------------------------------------------- 
component bcjr_turbo_decoder
    generic (
        -- Input data width
        WIDTH                   : integer range 1 to 256 := 5;
        ALPHAS_WIDTH            : integer range 1 to 256 := 12;
        DELTAS_WIDTH            : integer range 1 to 256 := 13
    );
    port(
        CLK                     : in std_logic;
        RST                     : in std_logic;
        -- Init         
        INIT                    : in std_logic; 
        BLOCK_SIZE              : in std_logic_vector(12 downto 0);
        -- Input            
        FDVI                    : in std_logic;
        DVI                     : in std_logic;
        DI0                     : in std_logic_vector((INTERNAL_WIDTH - 1) downto 0);  -- uncoded
        DI1                     : in std_logic_vector((INTERNAL_WIDTH - 1) downto 0);  -- encoded   
        -- Output           
        FDVO                    : out std_logic;
        DVO                     : out std_logic;
        DO                      : out std_logic_vector((INTERNAL_WIDTH - 1) downto 0)
    );
end component;
-- interface signals 
type decoder_do_type is array(5 downto 0) of std_logic_vector((INTERNAL_WIDTH - 1) downto 0);
signal decoder_fdvi             : std_logic := '0';
signal decoder_dvi              : std_logic := '0';
signal decoder_di0              : std_logic_vector((INTERNAL_WIDTH - 1) downto 0) := (others => '0');
signal decoder_di1              : std_logic_vector((INTERNAL_WIDTH - 1) downto 0) := (others => '0');
signal decoder_fdvo             : std_logic := '0';
signal decoder_dvo              : std_logic := '0';
signal decoder_do               : std_logic_vector((INTERNAL_WIDTH - 1) downto 0) := (others => '0');

signal decoder_1_fdvi           : std_logic := '0';
signal decoder_1_dvi            : std_logic := '0';
signal decoder_1_di0            : std_logic_vector((INTERNAL_WIDTH - 1) downto 0) := (others => '0');
signal decoder_1_di1            : std_logic_vector((INTERNAL_WIDTH - 1) downto 0) := (others => '0');
signal decoder_1_fdvo           : std_logic := '0';
signal decoder_1_dvo            : std_logic := '0';
signal decoder_1_do             : std_logic_vector((INTERNAL_WIDTH - 1) downto 0) := (others => '0');
type decoder_1_do_type is array(10 downto 0) of std_logic_vector((INTERNAL_WIDTH - 1) downto 0);
signal d_decoder_1_do           : decoder_1_do_type := (others => (others => '0'));

signal decoder_2_fdvi           : std_logic := '0';
signal decoder_2_dvi            : std_logic := '0';
signal decoder_2_di0            : std_logic_vector((INTERNAL_WIDTH - 1) downto 0) := (others => '0');
signal decoder_2_di1            : std_logic_vector((INTERNAL_WIDTH - 1) downto 0) := (others => '0');
signal decoder_2_fdvo           : std_logic := '0';
signal decoder_2_dvo            : std_logic := '0';
signal decoder_2_do             : std_logic_vector((INTERNAL_WIDTH - 1) downto 0) := (others => '0');
signal d_decoder_2_do           : decoder_do_type := (others => (others => '0'));

type size_table_type is array (0 to 187) of integer range 0 to 6200;
-- Constanst
constant size_table : size_table_type := (
    40,    48,  56,   64,   72,   80,   88,   96,   104,  112,  120,  128,  136,  144,  152,  160,  168,  176,  184,  192,
    200,   208, 216,  224,  232,  240,  248,  256,  264,  272,  280,  288,  296,  304,  312,  320,  328,  336,  344,  352,
    360,   368, 376,  384,  392,  400,  408,  416,  424,  432,  440,  448,  456,  464,  472,  480,  488,  496,  504,  512,
    528,   544, 560,  576,  592,  608,  624,  640,  656,  672,  688,  704,  720,  736,  752,  768,  784,  800,  816,  832,
    848,   864, 880,  896,  912,  928,  944,  960,  976,  992,  1008, 1024, 1056, 1088, 1120, 1152, 1184, 1216, 1248, 1280,
    1312, 1344, 1376, 1408, 1440, 1472, 1504, 1536, 1568, 1600, 1632, 1664, 1696, 1728, 1760, 1792, 1824, 1856, 1888, 1920,
    1952, 1984, 2016, 2048, 2112, 2176, 2240, 2304, 2368, 2432, 2496, 2560, 2624, 2688, 2752, 2816, 2880, 2944, 3008, 3072,
    3136, 3200, 3264, 3328, 3392, 3456, 3520, 3584, 3648, 3712, 3776, 3840, 3904, 3968, 4032, 4096, 4160, 4224, 4288, 4352,
    4416, 4480, 4544, 4608, 4672, 4736, 4800, 4864, 4928, 4992, 5056, 5120, 5184, 5248, 5312, 5376, 5440, 5504, 5568, 5632,
    5696, 5760, 5824, 5888, 5952, 6016, 6080, 6144
);

-- work signals
signal d_init                   : std_logic := '0';
signal d_iterations             : std_logic_vector(4 downto 0) := "00010" ;  
signal d_block_size             : std_logic_vector(12 downto 0) := (others => '0'); 
signal decoder_block_size       : std_logic_vector(12 downto 0) := (others => '0'); 
signal d_size_index             : std_logic_vector(7 downto 0) := (others => '0'); 
signal d_dvi                    : std_logic_vector(1 downto 0) := (others => '0'); 
signal d_di0                    : std_logic_vector((WIDTH - 1) downto 0) := (others => '0'); 
signal d_di1                    : std_logic_vector((WIDTH - 1) downto 0) := (others => '0'); 
signal d_di2                    : std_logic_vector((WIDTH - 1) downto 0) := (others => '0'); 
signal in_cnt                   : std_logic_vector(12 downto 0) := (others => '0'); 
signal d_di_tmp                 : std_logic_vector((WIDTH - 1) downto 0) := (others => '0'); 
type e_c_type is array (0 to 2) of std_logic_vector((WIDTH - 1) downto 0);
signal e_c                      : e_c_type := (others => (others => '0'));
signal f_c                      : e_c_type := (others => (others => '0'));
signal stage                    : integer range 0 to 15 := 0;
signal current_iteration        : std_logic_vector(4 downto 0) := (others => '0');

signal interleaver_in_cnt       : std_logic_vector(12 downto 0) := (others => '0'); 
type d_interleaver_in_cnt_type is array (5 downto 0) of std_logic_vector(12 downto 0);
signal d_interleaver_in_cnt     : d_interleaver_in_cnt_type := (others => (others => '0')); 
signal interleaver_in_cnt_circle: std_logic_vector(5 downto 0) := (others => '0');

signal decoder_in_cnt           : std_logic_vector(12 downto 0) := (others => '0'); 
signal d_decoder_in_cnt         : d_interleaver_in_cnt_type := (others => (others => '0')); 
signal decoder_in_cnt_circle    : std_logic_vector(5 downto 0) := (others => '0');

signal out_cnt                  : std_logic_vector(12 downto 0) := (others => '1');
type d_out_cnt_type is array (2 downto 0) of std_logic_vector(12 downto 0);
signal d_out_cnt                : d_out_cnt_type := (others => (others => '1'));
signal out_circle               : std_logic_vector(2 downto 0) := (others => '0'); 
signal a_p_tmp                  : std_logic_vector(INTERNAL_WIDTH downto 0) := (others => '0'); 
signal a_p                      : std_logic_vector(INTERNAL_WIDTH downto 0) := (others => '0'); 
signal dvo_into                 : std_logic := '0';
signal fdvo_into                : std_logic := '0';
signal rfd_into                 : std_logic := '1';

begin

    -- write input data(a_c, c_c, d_c, e_c, f_c) process
    process(CLK, RST)
    begin
        
        if (RST = '1') then

            
        elsif (CLK'event and CLK = '1') then
            
            -- Latching data
            if (INIT = '1') then
                d_iterations <= ext(ITERATIONS,5);
                d_size_index <= SIZE_INDEX;
                d_block_size <= conv_std_logic_vector(size_table(conv_integer(SIZE_INDEX)), 13);
                decoder_block_size <= conv_std_logic_vector(size_table(conv_integer(SIZE_INDEX)), 13) + 3;
            end if;
            
            -- Delay signals
            d_init <= INIT;
            d_dvi <= d_dvi(0) & DVI;
            d_di0 <= DI0;
            d_di1 <= DI1;
            d_di2 <= DI2;

            -- in_cnt
            if (FDVI = '1' and DVI = '1') then
                in_cnt <= (others => '0');
            elsif (DVI = '1') then  
                in_cnt <= in_cnt + 1;
            end if;
                          
            -- write_data_to sram a_c
            if (d_dvi(0) = '1' and in_cnt <= (d_block_size - 1)) then
                sram_a_c_w_dvi <= '1';
                sram_a_c_w_addr <= in_cnt;
                sram_a_c_w_di <= d_di0;
            else
                sram_a_c_w_dvi <= '0';
            end if;

            -- write_data_to sram c_c
            if (d_dvi(0) = '1' and in_cnt <= d_block_size) then
                sram_c_c_w_addr <= in_cnt;
                sram_c_c_w_dvi <= '1';
                sram_c_c_w_di <= d_di1;
            elsif (d_dvi(0) = '1' and in_cnt = (d_block_size + 1)) then
                sram_c_c_w_addr <= in_cnt;
                sram_c_c_w_dvi <= '1';
                sram_c_c_w_di <= d_di0;
            elsif (d_dvi(0) = '1' and in_cnt = (d_block_size + 2)) then
                sram_c_c_w_addr <= in_cnt;
                sram_c_c_w_dvi <= '1';
                sram_c_c_w_di <= d_di_tmp;
            else
                sram_c_c_w_dvi <= '0';
            end if;

            -- write_data_to sram d_c  
            if (d_dvi(0) = '1' and in_cnt <= (d_block_size-1)) then
                sram_d_c_w_dvi <= '1';  
                sram_d_c_w_di <= d_di2;
                sram_d_c_w_addr <= in_cnt;
            elsif (d_dvi(0) = '1' and in_cnt = (d_block_size + 2)) then
                sram_d_c_w_dvi <= '1'; 
                sram_d_c_w_di <= d_di1;
                sram_d_c_w_addr <= d_block_size;
            elsif (d_dvi(0) = '1' and d_dvi(0) = '1' and in_cnt = (d_block_size + 3)) then
                sram_d_c_w_dvi <= '1'; 
                sram_d_c_w_di <= d_di0;
                sram_d_c_w_addr <= (d_block_size + 1);
            elsif (d_dvi(1) = '1' and in_cnt = (d_block_size + 3)) then
                sram_d_c_w_dvi <= '1';
                sram_d_c_w_addr <= (d_block_size + 2);
                sram_d_c_w_di <= d_di_tmp;
            else
                sram_d_c_w_dvi <= '0';
            end if;  

            -- d_di_tmp
            if (d_dvi(0) = '1' and (in_cnt = (d_block_size + 1) or in_cnt = (d_block_size + 3))) then
                d_di_tmp <= d_di2;
            end if;
            
            -- e_c
            if (d_dvi(0) = '1' and in_cnt = d_block_size) then
                e_c(0) <= d_di0;
                e_c(1) <= d_di2;
            elsif (d_dvi(0) = '1' and in_cnt = (d_block_size+1)) then
                e_c(2) <= d_di1;
            end if;
            
            -- f_c
            if (d_dvi(0) = '1' and in_cnt = (d_block_size+2)) then
                f_c(0) <= d_di0;
                f_c(1) <= d_di2;
            elsif (d_dvi(0) = '1' and in_cnt = (d_block_size+3)) then
                f_c(2) <= d_di1;
            end if;     

        end if;
    end process;


    -- main process with general signals
    process(CLK, RST)
    begin
        
        if (RST = '1') then

            stage <= 0;
            
        elsif (CLK'event and CLK = '1') then
            
            -- rfd
            if (in_cnt = (decoder_block_size - 1) and DVI = '1') then
                rfd_into <= '0';
            elsif (out_circle(2) = '1' and d_out_cnt(1) = (d_block_size-1)) then
                rfd_into <= '1';
            end if;
            
            -- stages
            if (INIT = '1' or FDVI = '1') then
                stage <= 0;
            elsif (stage = 1 and interleaver_in_cnt = (d_block_size+1) and current_iteration = d_iterations) then
                stage <= 5;
            elsif ((d_dvi(1) = '1' and in_cnt = (d_block_size + 3)) or 
                   (stage = 4 and d_decoder_in_cnt(3) = (d_block_size+3))) then
                stage <= 1;
            elsif ((stage = 1 or stage = 3) and interleaver_in_cnt = (d_block_size+1)) then
                stage <= stage + 1;
            elsif (stage = 2 and d_decoder_in_cnt(1) = (d_block_size+3)) then
                stage <= 3;
            end if;
        
            -- current_iteration 
            if (FDVI = '1') then
                current_iteration <= (others => '0');
            elsif (stage = 4 and d_decoder_in_cnt(1) = (d_block_size+3)) then
                current_iteration <= current_iteration + 1;
            end if;  
        
            -- reading from sram a_c          
            if (stage = 3 and interleaver_in_cnt < d_block_size) then
                sram_a_c_r_addr <= interleaver_in_cnt;
            elsif (stage = 2 and decoder_in_cnt_circle(0) = '1' and d_decoder_in_cnt(0) < d_block_size) then
                sram_a_c_r_addr <= d_decoder_in_cnt(0);
            elsif (out_circle(0) = '1' and out_cnt < d_block_size) then
                sram_a_c_r_addr <= out_cnt;
            end if;
            
            -- delayed signals
            d_decoder_1_do <= d_decoder_1_do(9 downto 0) & decoder_1_do;
            d_decoder_2_do <= d_decoder_2_do(4 downto 0) & decoder_2_do;
            d_interleaver_do_0 <= d_interleaver_do_0(1 downto 0) & interleaver_do_0;
            d_interleaver_do_1 <= d_interleaver_do_1(1 downto 0) & interleaver_do_1;

        end if;
    end process;

    --working with interleaver process
    process(CLK, RST)
    begin
        
        if (RST = '1') then

            
        elsif (CLK'event and CLK = '1') then

            -- interleaver_in_cnt [1..d_block_size]
            if (stage = 0 or stage = 2 or stage = 4) then
                interleaver_in_cnt <= (others => '0');
            elsif (stage = 1 or stage = 3) then
                if ((stage = 1 and current_iteration = 0 and interleaver_rfd = '1' and interleaver_in_cnt < d_block_size) or
                    ((decoder_1_dvo = '1' or decoder_2_dvo = '1') and interleaver_in_cnt < d_block_size)) then
                    interleaver_in_cnt <= interleaver_in_cnt + 1;
                elsif (interleaver_in_cnt >= d_block_size and interleaver_in_cnt < (d_block_size + 1)) then
                    interleaver_in_cnt <= interleaver_in_cnt + 1;
                end if;
            end if;
            d_interleaver_in_cnt <= d_interleaver_in_cnt(4 downto 0) & interleaver_in_cnt;
            
            -- interleaver_in_cnt_circle
            if ((stage = 1 and current_iteration = 0 and interleaver_rfd = '1' and interleaver_in_cnt < d_block_size) or
                    ((stage = 1 or stage = 3) and (decoder_1_dvo = '1' or decoder_2_dvo = '1') and interleaver_in_cnt < d_block_size)) then
                interleaver_in_cnt_circle <= interleaver_in_cnt_circle(4 downto 0) & '1';
            else
                interleaver_in_cnt_circle <= interleaver_in_cnt_circle(4 downto 0) & '0';
            end if;

            -- interleaver_mode
            if (stage = 1 or stage = 5) then
                interleaver_mode <= '1';
            else
                interleaver_mode <= '0';
            end if;
            
            -- interleaver_dvi
            if (interleaver_in_cnt_circle(1) = '1') then
                interleaver_dvi <= '1';
            else
                interleaver_dvi <= '0';
            end if;              

            -- interleaver fdvi
            if (interleaver_in_cnt_circle(1) = '1' and d_interleaver_in_cnt(1) = 0) then
                interleaver_fdvi <= '1';
            else
                interleaver_fdvi <= '0';
            end if;  

            -- interleaver_di_0 and interleaver_di_1;
            if (interleaver_in_cnt_circle(1) = '1') then
                if (interleaver_mode = '1') then
                    if (current_iteration = 0) then
                        interleaver_di_0 <= (others => '0');
                    else
                        interleaver_di_0 <= d_decoder_2_do(1);
                    end if;
                else
                    interleaver_di_0 <= sxt(sram_a_c_r_do, INTERNAL_WIDTH);
                    interleaver_di_1 <= d_decoder_1_do(1);
                end if;
            end if;

        end if;
    end process;

            
    -- working with decoders process
    process(CLK, RST)
    begin
        
        if (RST = '1') then

            
        elsif (CLK'event and CLK = '1') then

            -- decoder_in_cnt [1..(d_block_size + 3)]
            if (stage < 2 or stage = 3 or stage = 5 or decoder_in_cnt = (d_block_size+3)) then
                decoder_in_cnt <= (others => '0');
            elsif (interleaver_dvo = '1' or (decoder_in_cnt >= d_block_size and decoder_in_cnt < (d_block_size+3))) then
                decoder_in_cnt <= decoder_in_cnt + 1;
            end if;
            d_decoder_in_cnt <= d_decoder_in_cnt(4 downto 0) & decoder_in_cnt;

            -- decoder_in_cnt_circle
            if ((stage = 2 or stage = 4) and (interleaver_dvo = '1' or (decoder_in_cnt >= d_block_size and decoder_in_cnt < (d_block_size+3)))) then
                decoder_in_cnt_circle <= decoder_in_cnt_circle(4 downto 0) & '1';
            else
                decoder_in_cnt_circle <= decoder_in_cnt_circle(4 downto 0) & '0';
            end if;
            
            -- read from c_c
            if (stage = 2 and decoder_in_cnt_circle(0) = '1' and d_decoder_in_cnt(0) < (d_block_size+3)) then
                sram_c_c_r_addr <= d_decoder_in_cnt(0);
            end if;

            -- decoder_1_dvi
            if (stage = 2 and decoder_in_cnt_circle(2) = '1') then
                decoder_1_dvi <= '1';
            else
                decoder_1_dvi <= '0';
            end if;
            
            -- decoder_1_fdvi
            if (stage = 2 and decoder_in_cnt_circle(2) = '1' and d_decoder_in_cnt(2) = 0) then
                decoder_1_fdvi <= '1';
            else
                decoder_1_fdvi <= '0';
            end if;            
            
            -- decoder_1_di0
            if (decoder_in_cnt_circle(2) = '1') then
                if (d_decoder_in_cnt(2) < d_block_size) then
                    if ((sxt(d_interleaver_do_0(2), (INTERNAL_WIDTH + 1))  + sxt(sram_a_c_r_do, (INTERNAL_WIDTH + 1))) = 8) then
                        decoder_1_di0 <= conv_std_logic_vector(7, INTERNAL_WIDTH);
                    elsif ((sxt(d_interleaver_do_0(2), (INTERNAL_WIDTH + 1))  + sxt(sram_a_c_r_do, (INTERNAL_WIDTH + 1))) = 24) then
                        decoder_1_di0 <= conv_std_logic_vector(9, INTERNAL_WIDTH);   
                    else    
                        decoder_1_di0 <= d_interleaver_do_0(2) + sxt(sram_a_c_r_do, INTERNAL_WIDTH);
                    end if;
                elsif (d_decoder_in_cnt(2) = d_block_size) then
                    decoder_1_di0 <= sxt(e_c(0), INTERNAL_WIDTH);
                elsif (d_decoder_in_cnt(2) = (d_block_size+1)) then
                    decoder_1_di0 <= sxt(e_c(1), INTERNAL_WIDTH);                
                elsif (d_decoder_in_cnt(2) = (d_block_size+2)) then
                    decoder_1_di0 <= sxt(e_c(2), INTERNAL_WIDTH);
                end if;
            end if;                        

            -- decoder_1_di1
            if (decoder_in_cnt_circle(2) = '1') then
                decoder_1_di1 <= sxt(sram_c_c_r_do, INTERNAL_WIDTH);
            end if;        
            
------------
            -- read from d_c
            if (stage = 4 and decoder_in_cnt_circle(0) = '1' and d_decoder_in_cnt(0) < (d_block_size+3)) then
                sram_d_c_r_addr <= d_decoder_in_cnt(0);
            end if;

            -- decoder_2_dvi
            if (stage = 4 and decoder_in_cnt_circle(2) = '1') then
                decoder_2_dvi <= '1';
            else
                decoder_2_dvi <= '0';
            end if;
            
            -- decoder_2_fdvi
            if (stage = 4 and decoder_in_cnt_circle(2) = '1' and d_decoder_in_cnt(2) = 0) then
                decoder_2_fdvi <= '1';
            else
                decoder_2_fdvi <= '0';
            end if;            
            
            -- decoder_2_di0
            if (decoder_in_cnt_circle(2) = '1') then
                if (d_decoder_in_cnt(2) < d_block_size) then
                    if ((sxt(d_interleaver_do_0(2), (INTERNAL_WIDTH + 1))  + sxt(d_interleaver_do_1(2), (INTERNAL_WIDTH + 1))) = 8) then
                        decoder_2_di0 <= conv_std_logic_vector(7, INTERNAL_WIDTH);
                    elsif ((sxt(d_interleaver_do_0(2), (INTERNAL_WIDTH + 1))  + sxt(d_interleaver_do_1(2), (INTERNAL_WIDTH + 1))) = 24) then
                        decoder_2_di0 <= conv_std_logic_vector(9, INTERNAL_WIDTH);   
                    else    
                        decoder_2_di0 <= d_interleaver_do_0(2) + d_interleaver_do_1(2);
                    end if;
                elsif (d_decoder_in_cnt(2) = d_block_size) then
                    decoder_2_di0 <= sxt(f_c(0), INTERNAL_WIDTH);
                elsif (d_decoder_in_cnt(2) = (d_block_size+1)) then
                    decoder_2_di0 <= sxt(f_c(1), INTERNAL_WIDTH);                
                elsif (d_decoder_in_cnt(2) = (d_block_size+2)) then
                    decoder_2_di0 <= sxt(f_c(2), INTERNAL_WIDTH);
                end if;
            end if;                        

            -- decoder_2_di1
            if (decoder_in_cnt_circle(2) = '1') then
                decoder_2_di1 <= sxt(sram_d_c_r_do, INTERNAL_WIDTH);
            end if;    

---------
            
            -- decoder_signals
            if (stage = 2 or stage = 3) then
                decoder_fdvi    <= decoder_1_fdvi;
                decoder_dvi     <= decoder_1_dvi;
                decoder_di0     <= decoder_1_di0;
                decoder_di1     <= decoder_1_di1;
            else
                decoder_fdvi    <= decoder_2_fdvi;
                decoder_dvi     <= decoder_2_dvi;
                decoder_di0     <= decoder_2_di0;
                decoder_di1     <= decoder_2_di1;              
            end if;
            
            if (stage = 3 or stage = 4) then
                decoder_1_fdvo  <= decoder_fdvo;
                decoder_1_dvo   <= decoder_dvo;
                decoder_1_do    <= decoder_do;
            else
                decoder_2_fdvo  <= decoder_fdvo;
                decoder_2_dvo   <= decoder_dvo;
                decoder_2_do    <= decoder_do;              
            end if;            

        end if;
    end process;


    -- output
    process(CLK, RST)
    begin
        
        if (RST = '1') then

            
        elsif (CLK'event and CLK = '1') then        

            -- out_cnt
            if (stage = 5 and interleaver_dvo = '1') then
                if (interleaver_fdvo = '1') then
                    out_cnt <= (others => '0');
                else
                    out_cnt <= out_cnt + 1;
                end if;
            end if;
            d_out_cnt <= d_out_cnt(1 downto 0) & out_cnt;
            
            -- out_circle
            if (stage = 5 and interleaver_dvo = '1') then
                out_circle <= out_circle(1 downto 0) & '1';
            else
                out_circle <= out_circle(1 downto 0) & '0';
            end if;            
 
            -- a_p_tmp
            if (out_circle(1) = '1') then
                a_p_tmp <= sxt(d_interleaver_do_0(1), (INTERNAL_WIDTH + 1)) + sxt(d_interleaver_do_1(1), (INTERNAL_WIDTH + 1));
            end if;

            -- a_p
            if (out_circle(2) = '1') then
                a_p <= a_p_tmp + sxt(sram_a_c_r_do, (INTERNAL_WIDTH + 1));
            end if;
            
            -- dvo_into
            dvo_into <= out_circle(2);

            -- fdvo_into
            if (out_circle(2) = '1' and d_out_cnt(1) = 0) then
                fdvo_into <= '1';
            else
                fdvo_into <= '0';
            end if;
            
            -- t_dvo
            t_dvo <= dvo_into;
            t_do <= a_p;
            

        end if;
    end process;

    RFD <= rfd_into;
    DVO <= dvo_into;
    FDVO <= fdvo_into;
    DO <= a_p(WIDTH + 1);



    -------------------------------------------------------------------------------
    -->>>>>>>>>> initializing component sram_input_encoded_data <<<<<<<<<<<<<<<--
    -------------------------------------------------------------------------------
    a_c_sram : lte_turbo_decoder_encoded_data_sram
        port map (
            clka        => CLK,
            wea(0)      => sram_a_c_w_dvi,
            addra       => sram_a_c_w_addr,
            dina        => sram_a_c_w_di,
            clkb        => CLK,
            addrb       => sram_a_c_r_addr,
            doutb       => sram_a_c_r_do
        );

    -------------------------------------------------------------------------------
    -->>>>>>>>>> initializing component sram_input_encoded_data <<<<<<<<<<<<<<<--
    -------------------------------------------------------------------------------
    c_c_sram : lte_turbo_decoder_encoded_data_sram
        port map (
            clka        => CLK,
            wea(0)      => sram_c_c_w_dvi,
            addra       => sram_c_c_w_addr,
            dina        => sram_c_c_w_di,
            clkb        => CLK,
            addrb       => sram_c_c_r_addr,
            doutb       => sram_c_c_r_do
        );
        
    -------------------------------------------------------------------------------
    -->>>>>>>>>> initializing component sram_input_encoded_data <<<<<<<<<<<<<<<--
    -------------------------------------------------------------------------------
    d_c_sram : lte_turbo_decoder_encoded_data_sram
        port map (
            clka        => CLK,
            wea(0)      => sram_d_c_w_dvi,
            addra       => sram_d_c_w_addr,
            dina        => sram_d_c_w_di,
            clkb        => CLK,
            addrb       => sram_d_c_r_addr,
            doutb       => sram_d_c_r_do
        );        

    -------------------------------------------------------------------------------
    -->>>>>>>>>> initializing component lte_interleaver <<<<<<<<<<<<<<<--
    -------------------------------------------------------------------------------
    lte_interleaver_inst : lte_interleaver
        generic map (
            WIDTH   => INTERNAL_WIDTH
        )
        port map (
            CLK          => CLK,
            RST          => RST,
            INIT         => d_init,
            SIZE_INDEX   => d_size_index,
            BLOCK_SIZE   => d_block_size,
            FDVI         => interleaver_fdvi,
            MODE         => interleaver_mode,            
            DVI          => interleaver_dvi,
            DI_0         => interleaver_di_0,
            DI_1         => interleaver_di_1,
            RFD          => interleaver_rfd,
            FDVO         => interleaver_fdvo,
            DVO          => interleaver_dvo,
            DO_0         => interleaver_do_0,
            DO_1         => interleaver_do_1
        );  

    -------------------------------------------------------------------------------
    -->>>>>>>>>> initializing component bcjr_turbo_decoder <<<<<<<<<<<<<<<--
    -------------------------------------------------------------------------------
    bcjr_turbo_decoder_inst : bcjr_turbo_decoder
        generic map (
            WIDTH   => INTERNAL_WIDTH,
            ALPHAS_WIDTH => 18,
            DELTAS_WIDTH => 8
        )
        port map (
            CLK          => CLK,
            RST          => RST,
            INIT         => d_init,
            BLOCK_SIZE   => decoder_block_size,
            FDVI         => decoder_fdvi,
            DVI          => decoder_dvi,
            DI0          => decoder_di0,
            DI1          => decoder_di1,
            FDVO         => decoder_fdvo,
            DVO          => decoder_dvo,
            DO           => decoder_do
        );  


end lte_turbo_decoder_arch;




 