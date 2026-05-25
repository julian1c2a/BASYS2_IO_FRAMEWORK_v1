LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE D7S_UTILITIES IS
    -- Tipos limpios y estándar
    SUBTYPE D7S_SLV8_t IS STD_LOGIC_VECTOR(7 DOWNTO 0);
    SUBTYPE D7S_SLV4_t IS STD_LOGIC_VECTOR(3 DOWNTO 0);
    
    -- Array de exactamente 4 elementos para los 4 displays (3 a 0)
    TYPE DATO_4DISP7SEGS_T IS ARRAY (3 DOWNTO 0) OF D7S_SLV4_t;
    
    -- Decodificador con opción para encender el punto decimal
    PURE FUNCTION HEXA_TO_7SEGS(CONSTANT arg : D7S_SLV4_t; CONSTANT dp : STD_LOGIC := '0') RETURN D7S_SLV8_t;

END PACKAGE D7S_UTILITIES;

PACKAGE BODY D7S_UTILITIES IS

    PURE FUNCTION HEXA_TO_7SEGS(CONSTANT arg : D7S_SLV4_t; CONSTANT dp : STD_LOGIC := '0') RETURN D7S_SLV8_t IS
        VARIABLE res : D7S_SLV8_t;
    BEGIN
        CASE arg IS
            WHEN "0000" => res := "11000000"; -- 0
            WHEN "0001" => res := "11111001"; -- 1
            WHEN "0010" => res := "10100100"; -- 2
            WHEN "0011" => res := "10110000"; -- 3
            WHEN "0100" => res := "10011001"; -- 4
            WHEN "0101" => res := "10010010"; -- 5
            WHEN "0110" => res := "10000010"; -- 6
            WHEN "0111" => res := "11111000"; -- 7
            WHEN "1000" => res := "10000000"; -- 8
            WHEN "1001" => res := "10011000"; -- 9
            WHEN "1010" => res := "10001000"; -- A
            WHEN "1011" => res := "10000011"; -- b
            WHEN "1100" => res := "10100111"; -- c
            WHEN "1101" => res := "10100001"; -- d
            WHEN "1110" => res := "10000110"; -- E
            WHEN "1111" => res := "10001110"; -- F
            WHEN OTHERS => res := "01111111"; -- .
        END CASE;
        
        -- Lógica del punto decimal (activo a nivel bajo en Basys 2)
        IF dp = '1' THEN
            res(7) := '0';
        END IF;
        
        RETURN res;
    END FUNCTION HEXA_TO_7SEGS;
    
END PACKAGE BODY D7S_UTILITIES;