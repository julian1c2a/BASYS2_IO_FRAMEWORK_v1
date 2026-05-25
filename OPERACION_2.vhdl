LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY GENERAL;
USE GENERAL.MEMORY_TYPES.C_DBUS_WIDTH;
USE GENERAL.MEMORY_TYPES.C_ABUS_WIDTH;
USE GENERAL.MEMORY_TYPES.C_DBUS_MSB;
USE GENERAL.MEMORY_TYPES.C_ABUS_MSB;
USE GENERAL.MEMORY_TYPES.MEMORY_T;


ENTITY OPERATION_2 IS
    PORT (
        SIGNAL CLK      : IN  STD_LOGIC;
        SIGNAL RST      : IN  STD_LOGIC;
        SIGNAL START    : IN  STD_LOGIC;
        SIGNAL DATA_IN  : IN  MEMORY_T; -- Buffer de hasta 8 bytes
        SIGNAL DATA_OUT : OUT MEMORY_T;
        SIGNAL READY    : OUT STD_LOGIC
    );
END ENTITY OPERATION_2;


ARCHITECTURE UNIQUE OF OPERATION_2 IS
    SIGNAL ACC : MEMORY_T;
	 SIGNAL STATE : STD_LOGIC;
BEGIN
    PROCESS(CLK, RST)
    BEGIN
        IF RST = '1' THEN
            DATA_OUT <= (OTHERS => (OTHERS => '0'));
            READY    <= '0';
			STATE    <= '0';
        ELSIF RISING_EDGE(CLK) THEN
            IF START = '1' AND STATE = '0' THEN
                -- Ciclo 1: calcular DATA_IN[i] * 2 (modulo 256)
                ACC(0)  <= DATA_IN(0) + DATA_IN(0);
                ACC(1)  <= DATA_IN(1) + DATA_IN(1);
                ACC(2)  <= DATA_IN(2) + DATA_IN(2);
                ACC(3)  <= DATA_IN(3) + DATA_IN(3);
                ACC(4)  <= DATA_IN(4) + DATA_IN(4);
                ACC(5)  <= DATA_IN(5) + DATA_IN(5);
                ACC(6)  <= DATA_IN(6) + DATA_IN(6);
                ACC(7)  <= DATA_IN(7) + DATA_IN(7);
				READY   <= '0';
                STATE   <= '1';
            ELSIF START = '1' AND STATE = '1' THEN
                -- Ciclo 2: volcar resultado
                DATA_OUT <= ACC;
                READY    <= '1';
				STATE    <= '0';
            ELSE
                READY    <= '0';
                STATE    <= '0';  -- reset para permitir nueva operacion
            END IF;
        END IF;
    END PROCESS;
END ARCHITECTURE UNIQUE;

