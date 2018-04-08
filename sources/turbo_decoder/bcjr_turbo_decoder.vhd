--------------------------------------------------------------------------------
--  Project:    LTE Turbo Decoder
--  Component:  BCJR Turbo Decoder component
--  Author:     Vadim Belov
--------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use IEEE.STD_LOGIC_ARITH.ALL;
    use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity bcjr_turbo_decoder is
    generic (
        -- Input data width
        WIDTH           : integer range 1 to 16 := 4;
        ALPHAS_WIDTH    : integer range 1 to 60 := 18; -- 10
        DELTAS_WIDTH    : integer range 1 to 60 := 8  -- 11
    );
    port(
        CLK          : in std_logic;
        RST          : in std_logic;
        -- Init
        INIT         : in std_logic; 
        BLOCK_SIZE   : in std_logic_vector(12 downto 0);
        -- Input
        FDVI         : in std_logic;
        DVI          : in std_logic;
        DI0          : in std_logic_vector((WIDTH - 1) downto 0);  -- uncoded
        DI1          : in std_logic_vector((WIDTH - 1) downto 0);  -- encoded   
        -- Output
        FDVO         : out std_logic;
        DVO          : out std_logic;
        DO           : out std_logic_vector((WIDTH - 1) downto 0)
    );
end bcjr_turbo_decoder;

architecture bcjr_turbo_decoder_arch of bcjr_turbo_decoder is

-- constants
constant ALPHAS_SRAM_WIDTH    : integer range 1 to 60 := 7; 

-------------------------------------------------------------------------------
-->>>>>>>>>>> declaration component bcjr_turbo_decoder_alphas_sram <<<<<<<<<<<<<<--
------------------------------------------------------------------------------- 
component bcjr_turbo_decoder_alphas_sram
    port (
        clka    : in std_logic;
        wea     : in std_logic_vector(0 downto 0);
        addra   : in std_logic_vector(12 downto 0);
        dina    : in std_logic_vector((ALPHAS_SRAM_WIDTH * 8 - 1) downto 0);
        clkb    : in std_logic;
        addrb   : in std_logic_vector(12 downto 0);
        doutb   : out std_logic_vector((ALPHAS_SRAM_WIDTH * 8 - 1) downto 0)
    );
end component;
-- interface signals
signal alphas_w_dvi        : std_logic := '0';
signal alphas_w_addr       : std_logic_vector(12 downto 0) := (others => '0');
signal alphas_w_di         : std_logic_vector((ALPHAS_SRAM_WIDTH * 8 - 1) downto 0) := (others => '0');
signal alphas_r_addr       : std_logic_vector(12 downto 0) := (others => '0');
signal alphas_r_do         : std_logic_vector((ALPHAS_SRAM_WIDTH * 8 - 1) downto 0) := (others => '0');
signal betas_w_dvi        : std_logic := '0';
signal betas_w_addr       : std_logic_vector(12 downto 0) := (others => '0');
signal betas_w_di         : std_logic_vector((ALPHAS_SRAM_WIDTH * 8 - 1) downto 0) := (others => '0');
signal betas_r_addr       : std_logic_vector(12 downto 0) := (others => '0');
signal betas_r_do         : std_logic_vector((ALPHAS_SRAM_WIDTH * 8 - 1) downto 0) := (others => '0');


-------------------------------------------------------------------------------
-->>>>>>>>>>> declaration component bcjr_turbo_decoder_llrs_sram <<<<<<<<<<<<<<--
------------------------------------------------------------------------------- 
component bcjr_turbo_decoder_llrs_sram
    port (
        clka    : in std_logic;
        wea     : in std_logic_vector(0 downto 0);
        addra   : in std_logic_vector(12 downto 0);
        dina    : in std_logic_vector(((WIDTH * 2) - 1) downto 0);
        douta   : out std_logic_vector(((WIDTH * 2) - 1) downto 0);
        clkb    : in std_logic;
        web     : in std_logic_vector(0 downto 0);
        addrb   : in std_logic_vector(12 downto 0);
        dinb    : in std_logic_vector(((WIDTH * 2) - 1) downto 0);
        doutb   : out std_logic_vector(((WIDTH * 2) - 1) downto 0)
    );
end component;
-- interface_signals
signal sram_llrs_w_dvi          : std_logic := '0';
signal sram_llrs_w_di           : std_logic_vector(((WIDTH * 2) - 1) downto 0) := (others => '0');
signal sram_llrs_addr_1         : std_logic_vector(12 downto 0) := (others => '0');
signal sram_llrs_addr_2         : std_logic_vector(12 downto 0) := (others => '0');
signal sram_llrs_r1_do          : std_logic_vector(((WIDTH * 2) - 1) downto 0) := (others => '0');
signal sram_llrs_r2_do          : std_logic_vector(((WIDTH * 2) - 1) downto 0) := (others => '0');
type llrs_type is array (0 to 1) of std_logic_vector((WIDTH - 1) downto 0); -- 0 - uncoded_llrs, 1 - encoded_llrs
signal llrs_to_sram             : llrs_type := (others => (others => '0'));                              
signal llrs_from_sram_alphas    : llrs_type := (others => (others => '0'));                                                           
signal llrs_from_sram_betas     : llrs_type := (others => (others => '0'));      

-- Decoder signals
type transitions_tmp_type is array (0 to 3) of integer range 0 to 7;
type transitions_type is array (0 to 15) of transitions_tmp_type;
constant transitions           : transitions_type := (
    (0,          0,          0,          0),
    (1,          4,          0,          0),
    (2,          5,          0,          1),
    (3,          1,          0,          1),
    (4,          2,          0,          1),
    (5,          6,          0,          1),
    (6,          7,          0,          0),
    (7,          3,          0,          0),
    (0,          4,          1,          1),
    (1,          0,          1,          1),
    (2,          1,          1,          0),
    (3,          5,          1,          0),
    (4,          6,          1,          0),
    (5,          2,          1,          0),
    (6,          3,          1,          1), 
    (7,          7,          1,          1)
);
                        
type alphas_column_type is array (0 to 7) of std_logic_vector((ALPHAS_WIDTH - 1) downto 0); 
type alphas_column_sram_type is array (0 to 7) of std_logic_vector((ALPHAS_SRAM_WIDTH - 1) downto 0); 
signal alphas_column_to_sram    : alphas_column_type := (others => (others => '0'));
signal alphas_column_to_sram_1  : alphas_column_sram_type := (others => (others => '0'));
signal alphas_column_from_sram  : alphas_column_sram_type := (others => (others => '0'));
signal d_alphas_column_sign     : std_logic_vector(7 downto 0) := (others => '0');
signal betas_column_to_sram     : alphas_column_type := (others => (others => '0'));
signal betas_column_to_sram_1   : alphas_column_sram_type := (others => (others => '0'));
signal betas_column_from_sram   : alphas_column_sram_type := (others => (others => '0'));
signal d_betas_column_sign      : std_logic_vector(7 downto 0) := (others => '0');
type gammas_column_type is array (0 to 15) of std_logic_vector((ALPHAS_WIDTH - 1) downto 0); 
signal alphas_uncoded_gammas_column_past : gammas_column_type := (others => (others => '0'));
signal alphas_encoded_gammas_column_past : gammas_column_type := (others => (others => '0'));
signal betas_uncoded_gammas_column_past : gammas_column_type := (others => (others => '0'));
signal betas_encoded_gammas_column_past : gammas_column_type := (others => (others => '0'));
type deltas_column_type is array (0 to 15) of std_logic_vector((DELTAS_WIDTH - 1) downto 0); 
signal deltas_column : deltas_column_type := (others => (others => '0'));


-- Decoder intermetiate signals
signal alphas_column_past       : alphas_column_type := (others => (others => '0'));
signal alphas_column            : alphas_column_type := (others => (others => '0'));
type d_alphas_column_type is array (3 downto 0) of alphas_column_type; 
signal d_alphas_column          : d_alphas_column_type := (others => (others => (others => '0')));
signal d_betas_column           : d_alphas_column_type := (others => (others => (others => '0')));

signal alphas_column_tmp        : gammas_column_type := (others => (others => '0'));
signal betas_column_past        : alphas_column_type := (others => (others => '0'));
signal betas_column             : alphas_column_type := (others => (others => '0'));
signal betas_column_tmp         : gammas_column_type := (others => (others => '0'));

signal alphas_column_abs        : alphas_column_type := (others => (others => '0'));
signal betas_column_abs         : alphas_column_type := (others => (others => '0'));
type alphas_min_tmp_0_type is array (0 to 3) of std_logic_vector((ALPHAS_WIDTH - 1) downto 0); 
signal alphas_min_tmp_0         : alphas_min_tmp_0_type := (others => (others => '0'));
signal betas_min_tmp_0          : alphas_min_tmp_0_type := (others => (others => '0'));
type alphas_min_tmp_1_type is array (0 to 1) of std_logic_vector((ALPHAS_WIDTH - 1) downto 0); 
signal alphas_min_tmp_1         : alphas_min_tmp_1_type := (others => (others => '0'));
signal betas_min_tmp_1          : alphas_min_tmp_1_type := (others => (others => '0'));
signal alphas_min               : std_logic_vector((ALPHAS_WIDTH - 1) downto 0) := (others => '0');
signal betas_min                : std_logic_vector((ALPHAS_WIDTH - 1) downto 0) := (others => '0');


type prob_type_tmp_0 is array (0 to 3) of std_logic_vector((DELTAS_WIDTH - 1) downto 0); 
signal prob0_tmp_0              : prob_type_tmp_0 := (others => (others => '0'));
signal prob1_tmp_0              : prob_type_tmp_0 := (others => (others => '0'));
type prob_type_tmp_1 is array (0 to 1) of std_logic_vector((DELTAS_WIDTH - 1) downto 0); 
signal prob0_tmp_1              : prob_type_tmp_1 := (others => (others => '0'));
signal prob1_tmp_1              : prob_type_tmp_1 := (others => (others => '0'));
signal prob0                    : std_logic_vector((DELTAS_WIDTH - 1) downto 0) := (others => '0');
signal prob1                    : std_logic_vector((DELTAS_WIDTH - 1) downto 0) := (others => '0');
signal deltas_tmp_1             : deltas_column_type := (others => (others => '0'));
signal deltas_tmp_2             : deltas_column_type := (others => (others => '0'));
signal encoded_gammas_column    : deltas_column_type := (others => (others => '0'));

-- Work signals 
signal d_block_size             : std_logic_vector(12 downto 0) := "0000000101000";
signal d_fdvi                   : std_logic := '0';
signal d_dvi                    : std_logic := '0';
signal d_di0                    : std_logic_vector((WIDTH - 1) downto 0); 
signal d_di1                    : std_logic_vector((WIDTH - 1) downto 0); 
signal bit_cnt                  : std_logic_vector(12 downto 0) := (others => '0');
signal bit_cnt_backward         : std_logic_vector(12 downto 0) := (others => '0');
type d_bit_cnt_type is array (3 downto 0) of std_logic_vector(12 downto 0); 
signal d_bit_cnt                : d_bit_cnt_type := (others => (others => '0'));
signal d_bit_cnt_backward       : d_bit_cnt_type := (others => (others => '0'));
signal stage                    : std_logic_vector(3 downto 0) := (others => '0');
signal d_stage                  : std_logic_vector(3 downto 0) := (others => '0');
signal dvo_into                 : std_logic := '0';
signal fdvo_into                : std_logic := '0'; 
signal result_llr               : std_logic_vector((DELTAS_WIDTH - 1) downto 0) := (others => '0'); 
signal result_llr_abs           : std_logic_vector((DELTAS_WIDTH - 1) downto 0) := (others => '0'); 
signal do_into                  : std_logic_vector((WIDTH - 1) downto 0) := (others => '0'); 
signal out_circle               : std_logic_vector(9 downto 0) := (others => '0');
signal work_circle              : std_logic_vector(9 downto 0) := (others => '0');



begin

    -- main process with general signals
    process(CLK, RST)
    begin
        
        if (RST = '1') then

            
        elsif (CLK'event and CLK = '1') then
            
            -- Delay signals
            d_fdvi <= FDVI;
            d_dvi <= DVI;
            d_di0 <= DI0;
            d_di1 <= DI1;
            d_stage <= stage;
            d_bit_cnt <= d_bit_cnt(2 downto 0) & bit_cnt;
            d_bit_cnt_backward <= d_bit_cnt_backward(2 downto 0) & bit_cnt_backward;
            
            -- Latching init parameters
            if (INIT = '1') then
                d_block_size <= BLOCK_SIZE;
            end if;

            -- Stages counter
            if (INIT = '1' or FDVI = '1') then
                stage <= (others => '0');
            elsif (stage = 0 and alphas_w_addr = (d_block_size - 1) and alphas_w_dvi = '1') then
                stage <= stage + 1;
            elsif (bit_cnt = 0 and work_circle = 256) then
                stage <= stage + 1;
            elsif (bit_cnt = (d_block_size - 1) and out_circle(8) = '1') then
                stage <= stage + 1;
            end if;

            -- Bits counter
            if ((FDVI = '1' and DVI = '1') or (bit_cnt = (d_block_size - 1) and stage = 0) or (bit_cnt = (d_block_size - 1) and work_circle(3) = '1')) then
                bit_cnt <= (others => '0');
            elsif (stage = 0 and DVI = '1') then
                bit_cnt <= bit_cnt + 1;
            elsif (work_circle(3) = '1') then
                bit_cnt <= bit_cnt + 1;
            elsif (out_circle(0) = '1') then
                bit_cnt <= bit_cnt + 1;
            end if;

            if ((FDVI = '1' and DVI = '1') or (bit_cnt = (d_block_size - 1) and stage = 0) or (bit_cnt = (d_block_size - 1) and work_circle(3) = '1')) then
                bit_cnt_backward <= d_block_size - 1;
            elsif (stage = 0 and DVI = '1') then
                bit_cnt_backward <= bit_cnt_backward - 1;
            elsif (work_circle(3) = '1') then
                bit_cnt_backward <= bit_cnt_backward - 1;
            end if;
            
            -- Working with llrs_sram
            if (d_dvi = '1') then
                sram_llrs_w_dvi <= '1';
            else
                sram_llrs_w_dvi <= '0';
            end if;
            if (d_dvi = '1' or work_circle(0) = '1' or out_circle(0) = '1') then
                sram_llrs_addr_1 <= bit_cnt;
                sram_llrs_addr_2 <= bit_cnt_backward;
            end if;
            if (d_dvi = '1') then
                llrs_to_sram(0) <= d_di0;
                llrs_to_sram(1) <= d_di1; 
            end if;
            
            -- Working with alphas_sram and betas_sram
            if (d_dvi = '1' or work_circle(3) = '1') then
                alphas_w_dvi <= '1';
                betas_w_dvi <= '1';
            else
                alphas_w_dvi <= '0';
                betas_w_dvi <= '0';
            end if;
            if (d_dvi = '1' or work_circle(3) = '1') then
                alphas_w_addr <= bit_cnt;
                betas_w_addr <= bit_cnt_backward;
            end if;

            if (d_dvi = '1' or work_circle(7) = '1') then
                alphas_w_dvi <= '1';
                betas_w_dvi <= '1';
            else
                alphas_w_dvi <= '0';
                betas_w_dvi <= '0';
            end if;
            if (d_dvi = '1') then
                alphas_w_addr <= bit_cnt;
                betas_w_addr <= bit_cnt_backward;
            elsif (work_circle(7) = '1') then
                betas_w_addr <= d_bit_cnt_backward(3);
                alphas_w_addr <= d_bit_cnt(3);
            end if;


            -- alphas_r_addr
            if (out_circle(0) = '1') then
                alphas_r_addr <= bit_cnt;
            end if;

            -- betas_r_addr
            if (out_circle(0) = '1') then
                betas_r_addr <= bit_cnt;
            end if;


        end if;
    end process;


    -- alphas and betas
    process(CLK, RST)
    begin
        
        if (RST = '1') then

            
        elsif (CLK'event and CLK = '1') then
       
            -- work_circle
            if ((stage = 0 and alphas_w_addr = (d_block_size - 1) and alphas_w_dvi = '1') or (stage = 1 and bit_cnt < (d_block_size - 1) and work_circle(3) = '1')) then
                work_circle <= work_circle(8 downto 0) & '1';
            else
                work_circle <= work_circle(8 downto 0) & '0';
            end if;

            -- delay signals
            d_alphas_column <= d_alphas_column(2 downto 0) & alphas_column;
            d_betas_column <= d_betas_column(2 downto 0) & betas_column;

            for i in 0 to 15 loop
            
                -- alphas_column    
                if (work_circle(0) = '1' and i <= 7) then 
                    if (bit_cnt = 0 and i = 0) then
                        alphas_column(i) <= (others => '0');
                    else
                        alphas_column(i)(ALPHAS_WIDTH - 1) <= '1';
                        alphas_column(i)(ALPHAS_WIDTH - 2 downto 0) <= (others => '0');
                    end if;                            
                elsif  (bit_cnt > 0 and ((work_circle(1) = '1' and i <= 7) or (work_circle(3) = '1' and i >= 8))) then
                    if (signed(alphas_column_tmp(i)) > signed(alphas_column(transitions(i)(1)))) then
                        alphas_column(transitions(i)(1)) <= alphas_column_tmp(i);
                    end if;
                end if;
                
                -- alphas_column_tmp
                if ((work_circle(0) = '1' and i <= 7) or (work_circle(2) = '1' and i >= 8)) then -- alphas_column_tmp = uncoded gammas + encoded gammas + alphas_column_past
                    if (alphas_column_past(transitions(i)(0))(ALPHAS_WIDTH - 1) = '1' and alphas_column_past(transitions(i)(0))((ALPHAS_WIDTH - 2) downto 0) = 0) then
                        alphas_column_tmp(i) <= alphas_column_past(transitions(i)(0));
                    else    
                        alphas_column_tmp(i) <= alphas_uncoded_gammas_column_past(i) + alphas_encoded_gammas_column_past(i) + alphas_column_past(transitions(i)(0));
                    end if;        
                end if;
                
                -- alphas_uncoded_gammas_column_past and alphas_encoded_gammas_column_past
                 if (work_circle(3) = '1') then
                    if (transitions(i)(2) = 0) then
                        alphas_uncoded_gammas_column_past(i) <= sxt(llrs_from_sram_alphas(0), ALPHAS_WIDTH);
                    else
                        alphas_uncoded_gammas_column_past(i) <= (others => '0');   
                    end if;  
                    if (transitions(i)(3) = 0) then
                        alphas_encoded_gammas_column_past(i) <= sxt(llrs_from_sram_alphas(1), ALPHAS_WIDTH);
                    else
                        alphas_encoded_gammas_column_past(i) <= (others => '0');   
                    end if; 
                end if;
                    
                -- alphas_column_past
                if (bit_cnt = 0) then    
                    if (i = 0) then
                        alphas_column_past(i) <= (others => '0');
                    elsif (i <= 7) then
                        alphas_column_past(i)(ALPHAS_WIDTH - 1) <= '1';
                        alphas_column_past(i)(ALPHAS_WIDTH - 2 downto 0) <= (others => '0');
                    end if;              
                elsif (work_circle(3) = '1' and i >= 8) then                
                    if (signed(alphas_column_tmp(i)) > signed(alphas_column(transitions(i)(1)))) then
                        alphas_column_past(transitions(i)(1)) <= alphas_column_tmp(i);
                    else
                        alphas_column_past(transitions(i)(1)) <= alphas_column(transitions(i)(1));
                    end if;
                end if;

                -- alphas_column_abs  
                if (work_circle(3) = '1') then
                    if (bit_cnt = 0 and i = 0) then
                        alphas_column_abs(i) <= (others => '0');
                    elsif (bit_cnt = 0 and i <= 7) then
                        alphas_column_abs(i)(ALPHAS_WIDTH - 1) <= '0';
                        alphas_column_abs(i)(ALPHAS_WIDTH - 2 downto 0) <= (others => '1');                      
                    elsif  (bit_cnt > 0 and i >= 8) then
                        if (signed(alphas_column_tmp(i)) > signed(alphas_column(transitions(i)(1)))) then
                            alphas_column_abs(transitions(i)(1)) <= abs(signed(alphas_column_tmp(i)));
                        else
                            alphas_column_abs(transitions(i)(1)) <= abs(signed(alphas_column(transitions(i)(1))));
                        end if;
                    end if;
                end if;
                
                -- alphas_column_to_sram 
                if (work_circle(7) = '1' and i <= 7) then  
                    if (d_alphas_column_sign = 0) then
                        alphas_column_to_sram(i) <= d_alphas_column(2)(i) - alphas_min;
                    elsif (d_alphas_column_sign = "11111111") then 
                        alphas_column_to_sram(i) <= d_alphas_column(2)(i) + alphas_min;
                    else
                        alphas_column_to_sram(i) <= d_alphas_column(2)(i);
                    end if;
                
                end if;
                    

                -- betas_column    
                if (work_circle(0) = '1' and i <= 7) then 
                    if (bit_cnt_backward = (d_block_size-1) and i = 0) then
                        betas_column(i) <= (others => '0');
                    else
                        betas_column(i)(ALPHAS_WIDTH - 1) <= '1';
                        betas_column(i)(ALPHAS_WIDTH - 2 downto 0) <= (others => '0');
                    end if;                            
                elsif  (bit_cnt_backward < (d_block_size-1) and ((work_circle(1) = '1' and i <= 7) or (work_circle(3) = '1' and i >= 8))) then
                    if (signed(betas_column_tmp(i)) > signed(betas_column(transitions(i)(0)))) then
                        betas_column(transitions(i)(0)) <= betas_column_tmp(i);
                    end if;
                end if;
                
                -- betas_column_tmp
                if ((work_circle(0) = '1' and i <= 7) or (work_circle(2) = '1' and i >= 8)) then
                    if (betas_column_past(transitions(i)(1))(ALPHAS_WIDTH - 1) = '1' and betas_column_past(transitions(i)(1))((ALPHAS_WIDTH - 2) downto 0) = 0) then
                        betas_column_tmp(i) <= betas_column_past(transitions(i)(1));
                    else    
                        betas_column_tmp(i) <= betas_uncoded_gammas_column_past(i) + betas_encoded_gammas_column_past(i) + betas_column_past(transitions(i)(1));
                    end if;        
                end if;

                
                -- betas_uncoded_gammas_column_past and betas_encoded_gammas_column_past
                 if (work_circle(3) = '1') then
                    if (transitions(i)(2) = 0) then
                        betas_uncoded_gammas_column_past(i) <= sxt(llrs_from_sram_betas(0), ALPHAS_WIDTH);
                    else
                        betas_uncoded_gammas_column_past(i) <= (others => '0');   
                    end if;  
                    if (transitions(i)(3) = 0) then
                        betas_encoded_gammas_column_past(i) <= sxt(llrs_from_sram_betas(1), ALPHAS_WIDTH);
                    else
                        betas_encoded_gammas_column_past(i) <= (others => '0');   
                    end if; 
                end if;
                    
                -- betas_column_past
                if (bit_cnt_backward = (d_block_size-1)) then 
                
                    if (i = 0) then
                        betas_column_past(i) <= (others => '0');
                    elsif (i <= 7) then
                        betas_column_past(i)(ALPHAS_WIDTH - 1) <= '1';
                        betas_column_past(i)(ALPHAS_WIDTH - 2 downto 0) <= (others => '0');
                    end if;    
                    
                elsif (work_circle(3) = '1' and i >= 8) then                

                    if (signed(betas_column_tmp(i)) > signed(betas_column(transitions(i)(0)))) then
                        betas_column_past(transitions(i)(0)) <= betas_column_tmp(i);
                    else
                        betas_column_past(transitions(i)(0)) <= betas_column(transitions(i)(0));
                    end if;
    
                end if;

                -- betas_column_abs  
                if (work_circle(3) = '1') then
                    if (bit_cnt_backward = (d_block_size-1) and i = 0) then
                        betas_column_abs(i) <= (others => '0');
                    elsif (bit_cnt_backward = (d_block_size-1) and i <= 7) then
                        betas_column_abs(i)(ALPHAS_WIDTH - 1) <= '0';
                        betas_column_abs(i)(ALPHAS_WIDTH - 2 downto 0) <= (others => '1');                         
                    elsif  (bit_cnt > 0 and i >= 8) then
                        if (signed(betas_column_tmp(i)) > signed(betas_column(transitions(i)(0)))) then
                            betas_column_abs(transitions(i)(0)) <= abs(signed(betas_column_tmp(i)));
                        else
                            betas_column_abs(transitions(i)(0)) <= abs(signed(betas_column(transitions(i)(0))));
                        end if;
                    end if;
                end if;

                if (work_circle(7) = '1' and i <= 7) then  
                    if (d_betas_column_sign = 0) then
                        betas_column_to_sram(i) <= d_betas_column(2)(i) - betas_min;
                    elsif (d_betas_column_sign = "11111111") then 
                        betas_column_to_sram(i) <= d_betas_column(2)(i) + betas_min;
                    else
                        betas_column_to_sram(i) <= d_betas_column(2)(i);
                    end if;
                
                end if;

               
            end loop;
            
            -- min(abs(alphas))    
            if (work_circle(4) = '1') then
                for j in 0 to 3 loop
                    if (alphas_column_abs(j) < alphas_column_abs(4+j)) then
                        alphas_min_tmp_0(j) <= alphas_column_abs(j);
                    else    
                        alphas_min_tmp_0(j) <= alphas_column_abs(4+j);
                    end if;
                end loop;
            end if;
            
            if (work_circle(5) = '1') then
                for j in 0 to 1 loop
                    if (alphas_min_tmp_0(j) < alphas_min_tmp_0(2+j)) then
                        alphas_min_tmp_1(j) <= alphas_min_tmp_0(j);
                    else    
                        alphas_min_tmp_1(j) <= alphas_min_tmp_0(2+j);
                    end if;
                end loop;
            end if;
          
            if (work_circle(6) = '1') then
                if (alphas_min_tmp_1(0) < alphas_min_tmp_1(1)) then
                    alphas_min <= alphas_min_tmp_1(0);
                else    
                    alphas_min <= alphas_min_tmp_1(1);
                end if;
            end if;

            -- min(abs(betas))    
            if (work_circle(4) = '1') then
                for j in 0 to 3 loop
                    if (betas_column_abs(j) < betas_column_abs(4+j)) then
                        betas_min_tmp_0(j) <= betas_column_abs(j);
                    else    
                        betas_min_tmp_0(j) <= betas_column_abs(4+j);
                    end if;
                end loop;
            end if;
            
            if (work_circle(5) = '1') then
                for j in 0 to 1 loop
                    if (betas_min_tmp_0(j) < betas_min_tmp_0(2+j)) then
                        betas_min_tmp_1(j) <= betas_min_tmp_0(j);
                    else    
                        betas_min_tmp_1(j) <= betas_min_tmp_0(2+j);
                    end if;
                end loop;
            end if;
          
            if (work_circle(6) = '1') then
                if (betas_min_tmp_1(0) < betas_min_tmp_1(1)) then
                    betas_min <= betas_min_tmp_1(0);
                else    
                    betas_min <= betas_min_tmp_1(1);
                end if;
            end if;


        end if;
    end process;


    -- deltas and output
    process(CLK, RST)
    begin
        
        if (RST = '1') then

            
        elsif (CLK'event and CLK = '1') then
        
            -- out_circle
            if (stage = 2 and bit_cnt < (d_block_size-1)) then
                out_circle <= out_circle(8 downto 0) & '1';
            else
                out_circle <= out_circle(8 downto 0) & '0';
            end if;

            for i in 0 to 15 loop

                -- encoded_gammas_column
                if (out_circle(2) = '1') then
                    if (transitions(i)(3) = 0) then
                        encoded_gammas_column(i) <= sxt(llrs_from_sram_alphas(1), DELTAS_WIDTH);
                    else
                        encoded_gammas_column(i) <= (others => '0');   
                    end if;      
                end if;

                -- deltas_tmp
                if (out_circle(2) = '1') then            
                    deltas_tmp_1(i) <= sxt(alphas_column_from_sram(transitions(i)(0)), DELTAS_WIDTH) + sxt(betas_column_from_sram(transitions(i)(1)), DELTAS_WIDTH);
                end if;
                
                if (out_circle(3) = '1') then
                    deltas_tmp_2(i) <= deltas_tmp_1(i) + encoded_gammas_column(i);
                end if;


            end loop;
        
            -- prob0 and prob1
            if (out_circle(4) = '1') then
                for j in 0 to 3 loop
                    if (signed(deltas_tmp_2(j)) > signed(deltas_tmp_2(4+j))) then
                        prob0_tmp_0(j) <= deltas_tmp_2(j);
                    else
                        prob0_tmp_0(j) <= deltas_tmp_2(4+j);
                    end if;
                    if (signed(deltas_tmp_2(8+j)) > signed(deltas_tmp_2(12+j))) then
                        prob1_tmp_0(j) <= deltas_tmp_2(8+j);
                    else
                        prob1_tmp_0(j) <= deltas_tmp_2(12+j);
                    end if;
                end loop;
            end if;
            
            if (out_circle(5) = '1') then
                for j in 0 to 1 loop
                    if (signed(prob0_tmp_0(j)) > signed(prob0_tmp_0(2+j))) then
                        prob0_tmp_1(j) <= prob0_tmp_0(j);
                    else
                        prob0_tmp_1(j) <= prob0_tmp_0(2+j);
                    end if;
                    if (signed(prob1_tmp_0(j)) > signed(prob1_tmp_0(2+j))) then
                        prob1_tmp_1(j) <= prob1_tmp_0(j);
                    else
                        prob1_tmp_1(j) <= prob1_tmp_0(2+j);
                    end if;
                end loop;           
            end if;
            
            if (out_circle(6) = '1') then
                if (signed(prob0_tmp_1(1)) > signed(prob0_tmp_1(0))) then
                    prob0 <= prob0_tmp_1(1);
                else
                    prob0 <= prob0_tmp_1(0);
                end if;
                if (signed(prob1_tmp_1(1)) > signed(prob1_tmp_1(0))) then
                    prob1 <= prob1_tmp_1(1);
                else
                    prob1 <= prob1_tmp_1(0);
                end if;    
            end if;
        
            -- result_llr
            if (out_circle(7) = '1') then                
                result_llr <= prob0 - prob1;       
                result_llr_abs <= abs(signed(prob0 - prob1));            
            end if;

            -- dvo_into
            if (out_circle(8) = '1') then
                dvo_into <= '1';
            else
                dvo_into <= '0';
            end if;
            
            
            -- do_into
            if (out_circle(8) = '1') then
                if (signed(result_llr) > 7) then
                    do_into <= "0111";      
                elsif (result_llr_abs > 7) then
                    do_into <= "1001";
                else
                    do_into <= sxt(result_llr, WIDTH);       
                end if;
            end if;

            -- fdvo_into
            if (out_circle(7) = '1' and bit_cnt = 0) then
                fdvo_into <= '1';
            else
                fdvo_into <= '0';
            end if;
            
            
        end if;
    end process;


    DVO <= dvo_into;
    FDVO <= fdvo_into;
    DO <= do_into;


    -------------------------------------------------------------------------------
    -->>>>>>>>>> initializing component sram_block <<<<<<<<<<<<<<<--
    -------------------------------------------------------------------------------
    alphas_sram : bcjr_turbo_decoder_alphas_sram
        port map (
            clka    => CLK,
            wea(0)  => alphas_w_dvi,
            addra   => alphas_w_addr,
            dina    => alphas_w_di,
            clkb    => CLK,
            addrb   => alphas_r_addr,
            doutb   => alphas_r_do
        );
       
    -------------------------------------------------------------------------------
    -->>>>>>>>>> initializing component sram_block <<<<<<<<<<<<<<<--
    -------------------------------------------------------------------------------
    betas_sram : bcjr_turbo_decoder_alphas_sram
        port map (
            clka    => CLK,
            wea(0)  => betas_w_dvi,
            addra   => betas_w_addr,
            dina    => betas_w_di,
            clkb    => CLK,
            addrb   => betas_r_addr,
            doutb   => betas_r_do
        );

    -------------------------------------------------------------------------------
    -->>>>>>>>>> initializing component bcjr_turbo_decoder_llrs_sram <<<<<<<<<<<<<<<--
    -------------------------------------------------------------------------------
    llrs_sram : bcjr_turbo_decoder_llrs_sram
        port map (
            clka    => CLK,
            wea(0)  => sram_llrs_w_dvi,
            addra   => sram_llrs_addr_1,
            dina    => sram_llrs_w_di,
            douta   => sram_llrs_r1_do,
            clkb    => CLK,
            web(0)  => '0',
            addrb   => sram_llrs_addr_2,
            dinb    => sram_llrs_w_di,
            doutb   => sram_llrs_r2_do
        );

    
    label_1:
    for i in 0 to 1 generate
        begin
        sram_llrs_w_di(((i+1) * WIDTH - 1) downto (i * WIDTH)) <= llrs_to_sram(i);
        llrs_from_sram_alphas(i) <= sram_llrs_r1_do(((i+1) * WIDTH - 1) downto (i * WIDTH));                                                           
        llrs_from_sram_betas(i) <= sram_llrs_r2_do(((i+1) * WIDTH - 1) downto (i * WIDTH)); 
    end generate label_1;  

    label_2:
    for i in 0 to 7 generate
        begin
        alphas_column_to_sram_1(i) <= alphas_column_to_sram(i)(ALPHAS_WIDTH - 1) & alphas_column_to_sram(i)(5 downto 0);
        betas_column_to_sram_1(i) <= betas_column_to_sram(i)(ALPHAS_WIDTH - 1) & betas_column_to_sram(i)(5 downto 0);
        
        alphas_w_di(((i+1) * ALPHAS_SRAM_WIDTH - 1) downto (i * ALPHAS_SRAM_WIDTH)) <= alphas_column_to_sram_1(i);
        alphas_column_from_sram(i) <= alphas_r_do(((i+1) * ALPHAS_SRAM_WIDTH - 1) downto (i * ALPHAS_SRAM_WIDTH));
        
        betas_w_di(((i+1) * ALPHAS_SRAM_WIDTH - 1) downto (i * ALPHAS_SRAM_WIDTH)) <= betas_column_to_sram_1(i);
        betas_column_from_sram(i) <= betas_r_do(((i+1) * ALPHAS_SRAM_WIDTH - 1) downto (i * ALPHAS_SRAM_WIDTH));    
    end generate label_2;   

    label_3:
    for i in 0 to 7 generate
        begin
            d_alphas_column_sign(i) <= d_alphas_column(2)(i)(ALPHAS_WIDTH - 1);
            d_betas_column_sign(i) <= d_betas_column(2)(i)(ALPHAS_WIDTH - 1);
    end generate label_3;  

end bcjr_turbo_decoder_arch;






 