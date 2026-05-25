LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY D7S;
USE D7S.D7S_UTILITIES.ALL;

-- Este módulo es genérico: sirve para CUALQUIER proyecto con Displays de 7 Segs
ENTITY DISPLAY_CTRL IS
    PORT (
        SIGNAL CLK        : IN STD_LOGIC;
        SIGNAL RST        : IN STD_LOGIC;
        SIGNAL TICK_500HZ : IN STD_LOGIC;
        SIGNAL DATOS_IN   : IN DATO_4DISP7SEGS_T;
        SIGNAL AN         : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        SIGNAL SEG        : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
    );
END ENTITY DISPLAY_CTRL;

ARCHITECTURE RTL OF DISPLAY_CTRL IS
    -- Un contador de 2 bits se desborda solo de 3 a 0. ¡Adiós a los IF complicados!
    SIGNAL S_DISP_INDEX : UNSIGNED(1 DOWNTO 0);
BEGIN

    ROTACION : PROCESS(RST, CLK) IS
    BEGIN
        IF RST = '1' THEN
            S_DISP_INDEX <= (OTHERS => '0');
        ELSIF RISING_EDGE(CLK) THEN
            IF TICK_500HZ = '1' THEN
                S_DISP_INDEX <= S_DISP_INDEX + 1;
            END IF;
        END IF;
    END PROCESS;

    -- Multiplexor físico del hardware (WITH SELECT es más eficiente que el CASE en procesos)
    WITH S_DISP_INDEX SELECT AN <=
        "1110" WHEN "00", -- Display 0 (Derecha)
        "1101" WHEN "01", -- Display 1
        "1011" WHEN "10", -- Display 2
        "0111" WHEN "11", -- Display 3 (Izquierda)
        "1111" WHEN OTHERS;

    -- Pasamos el dato del array y encendemos el punto para el Display 3 y el Display 1
    SEG <= HEXA_TO_7SEGS(DATOS_IN(TO_INTEGER(S_DISP_INDEX)), '1') WHEN (S_DISP_INDEX = "11" OR S_DISP_INDEX = "01") ELSE
           HEXA_TO_7SEGS(DATOS_IN(TO_INTEGER(S_DISP_INDEX)), '0');

END ARCHITECTURE RTL;