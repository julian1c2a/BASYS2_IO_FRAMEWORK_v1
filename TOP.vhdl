-- =============================================================================
-- TOP.vhdl  -  Entidad de nivel superior del Framework de E/S para BASYS 2
-- =============================================================================
-- Conecta todos los módulos del framework:
--   · GEN_IO_CLK × 2  → dominios de reloj 500 Hz y 2 Hz
--   · DISPLAY_CTRL    → controlador de displays de 7 segmentos
--   · OP_IDENTITY     → módulo de operación (Nivel 0: identidad)
--   · FSM             → 4 estados: IDLE → ENTRADA → OPERACION → SALIDA
--
-- Protocolo de interacción:
--   · RST    (BTN3, activo alto) : reset asíncrono global.
--   · BTN[0] (activo alto)       : botón de validación/avance de estado.
--   · SW[2:0]                    : índice del último byte a capturar (en IDLE).
--   · SW[7:0]                    : dato a capturar (en ENTRADA).
--   · SW[1:0]                    : selector de ventana de 2 bytes (en SALIDA).
--   · LED[3:0]                   : indicador de estado de la FSM.
-- =============================================================================

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY D7S;
USE D7S.D7S_UTILITIES.ALL;         -- DATO_4DISP7SEGS_T

LIBRARY GENERAL;
USE GENERAL.MEMORY_TYPES.MEMORY_T; -- Array de 8 bytes (UNSIGNED 7:0)

-- -----------------------------------------------------------------------------

ENTITY TOP IS
    PORT (
        SIGNAL CLK : IN  STD_LOGIC;                    -- Reloj maestro 50 MHz (B8)
        SIGNAL RST : IN  STD_LOGIC;                    -- Reset asíncrono activo alto (BTN3 / A7)
        SIGNAL BTN : IN  STD_LOGIC_VECTOR(2 DOWNTO 0); -- Botones de control (activos alto)
        SIGNAL SW  : IN  STD_LOGIC_VECTOR(7 DOWNTO 0); -- Interruptores
        SIGNAL LED : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- LEDs de estado de la FSM
        SIGNAL AN  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0); -- Ánodos de los displays (activos bajo)
        SIGNAL SEG : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)  -- Segmentos de los displays (activos bajo)
    );
END ENTITY TOP;

-- -----------------------------------------------------------------------------

ARCHITECTURE RTL OF TOP IS

    -- -------------------------------------------------------------------------
    -- Constantes de los generadores de reloj
    --   Half-period = MAX_COUNT + 1 ciclos del CLK maestro
    --   f_out = f_clk / (2 * (MAX_COUNT + 1))
    -- -------------------------------------------------------------------------
    CONSTANT C_MAX_500HZ  : POSITIVE := 49_999;      -- 50 MHz / 100 000 = 500 Hz
    CONSTANT C_MAX_IO_CLK : POSITIVE := 12_499_999;  -- 50 MHz / 25 000 000 = 2 Hz

    -- -------------------------------------------------------------------------
    -- Tipo de la FSM
    -- -------------------------------------------------------------------------
    TYPE FSM_STATE_T IS (IDLE, ENTRADA, OPERACION, SALIDA);

    -- -------------------------------------------------------------------------
    -- Señales de los relojes derivados y sus detectores de flanco
    -- -------------------------------------------------------------------------
    SIGNAL S_CLK_500HZ   : STD_LOGIC;
    SIGNAL S_IO_CLK      : STD_LOGIC;

    SIGNAL S_CLK_500HZ_D : STD_LOGIC; -- S_CLK_500HZ retrasado 1 ciclo
    SIGNAL S_IO_CLK_D    : STD_LOGIC; -- S_IO_CLK    retrasado 1 ciclo

    SIGNAL S_TICK_500HZ  : STD_LOGIC; -- Pulso de 1 ciclo @ 500 Hz
    SIGNAL S_IO_RISING   : STD_LOGIC; -- Pulso de 1 ciclo @ 2 Hz

    -- -------------------------------------------------------------------------
    -- Señales de la FSM y control de captura
    -- -------------------------------------------------------------------------
    SIGNAL S_STATE      : FSM_STATE_T;
    SIGNAL S_BTN_VALID  : STD_LOGIC;      -- Botón validado por el dominio 2 Hz

    SIGNAL S_PART_IDX   : UNSIGNED(2 DOWNTO 0); -- Índice del byte en curso (0–7)
    SIGNAL S_N_LAST     : UNSIGNED(2 DOWNTO 0); -- Índice del último byte = SW[2:0]

    -- -------------------------------------------------------------------------
    -- Buffers de datos y señales de operación
    -- -------------------------------------------------------------------------
    SIGNAL S_DATA_IN    : MEMORY_T; -- Buffer de entrada  (8 bytes)
    SIGNAL S_DATA_OUT   : MEMORY_T; -- Buffer de salida   (8 bytes)
    SIGNAL S_START      : STD_LOGIC;
    SIGNAL S_READY      : STD_LOGIC;

    -- -------------------------------------------------------------------------
    -- Datos para los displays y selector de ventana
    -- -------------------------------------------------------------------------
    SIGNAL S_DATOS_DISP : DATO_4DISP7SEGS_T;
    SIGNAL S_WIN_BASE   : INTEGER RANGE 0 TO 6; -- Primer índice de la ventana (0,2,4,6)

BEGIN

    -- =========================================================================
    -- [1]  Generadores de reloj
    -- =========================================================================

    -- 500 Hz → base de multiplexación de los 4 displays (cada dígito activo ~0,5 ms)
    U_CLK_500HZ : ENTITY WORK.GEN_IO_CLK
        GENERIC MAP (MAX_COUNT => C_MAX_500HZ)
        PORT MAP (RST => RST, CLK => CLK, IO_CLK => S_CLK_500HZ);

    -- 2 Hz → dominio de interacción humana con filtrado natural de rebotes
    U_IO_CLK : ENTITY WORK.GEN_IO_CLK
        GENERIC MAP (MAX_COUNT => C_MAX_IO_CLK)
        PORT MAP (RST => RST, CLK => CLK, IO_CLK => S_IO_CLK);

    -- =========================================================================
    -- [2]  Detectores de flanco ascendente (sincronizados al CLK maestro)
    --      Producen un pulso de exactamente 1 ciclo en cada flanco ascendente.
    -- =========================================================================

    P_EDGE_DETECT : PROCESS(RST, CLK) IS
    BEGIN
        IF RST = '1' THEN
            S_CLK_500HZ_D <= '0';
            S_IO_CLK_D    <= '0';
        ELSIF RISING_EDGE(CLK) THEN
            S_CLK_500HZ_D <= S_CLK_500HZ;
            S_IO_CLK_D    <= S_IO_CLK;
        END IF;
    END PROCESS P_EDGE_DETECT;

    S_TICK_500HZ <= S_CLK_500HZ AND NOT S_CLK_500HZ_D;
    S_IO_RISING  <= S_IO_CLK    AND NOT S_IO_CLK_D;

    -- Botón válido: cualquier BTN[2:0] pulsado coincidiendo con el flanco de 2 Hz
    S_BTN_VALID  <= S_IO_RISING AND (BTN(0) OR BTN(1) OR BTN(2));

    -- =========================================================================
    -- [3]  Controlador de displays de 7 segmentos
    -- =========================================================================

    U_DISPLAY : ENTITY D7S.DISPLAY_CTRL
        PORT MAP (
            CLK        => CLK,
            RST        => RST,
            TICK_500HZ => S_TICK_500HZ,
            DATOS_IN   => S_DATOS_DISP,
            AN         => AN,
            SEG        => SEG
        );

    -- =========================================================================
    -- [4]  Módulo de operación  (Nivel 0 por defecto: Identidad)
    --      Para otros niveles, sustituir OP_IDENTITY por el módulo del alumno
    --      conservando la misma interfaz (CLK, RST, START, DATA_IN, DATA_OUT, READY).
    -- =========================================================================

    U_OPERACION : ENTITY WORK.OP_IDENTITY
        PORT MAP (
            CLK      => CLK,
            RST      => RST,
            START    => S_START,
            DATA_IN  => S_DATA_IN,
            DATA_OUT => S_DATA_OUT,
            READY    => S_READY
        );

    -- =========================================================================
    -- [5]  Máquina de Estados (FSM)
    -- =========================================================================
    --
    --  IDLE  ──(BTN_VALID)──► ENTRADA ──(completado)──► OPERACION ──(READY)──► SALIDA
    --   ▲                                                                          │
    --   └────────────────────────────────(BTN_VALID)───────────────────────────────┘
    --
    -- =========================================================================

    P_FSM : PROCESS(RST, CLK) IS
    BEGIN
        IF RST = '1' THEN
            S_STATE    <= IDLE;
            S_PART_IDX <= (OTHERS => '0');
            S_N_LAST   <= (OTHERS => '0');
            S_DATA_IN  <= (OTHERS => (OTHERS => '0'));
            S_START    <= '0';

        ELSIF RISING_EDGE(CLK) THEN
            S_START <= '0'; -- Pulso de un solo ciclo; se sobreescribirá abajo si procede

            CASE S_STATE IS

                -- [0] IDLE ─────────────────────────────────────────────────────
                -- Reposo tras reset. Espera pulsación de BTN[0] para comenzar.
                -- SW[2:0] define el índice del último byte que se capturará.
                WHEN IDLE =>
                    IF S_BTN_VALID = '1' THEN
                        S_N_LAST   <= UNSIGNED(SW(2 DOWNTO 0));
                        S_PART_IDX <= (OTHERS => '0');
                        S_DATA_IN  <= (OTHERS => (OTHERS => '0'));
                        S_STATE    <= ENTRADA;
                    END IF;

                -- [1] ENTRADA ──────────────────────────────────────────────────
                -- Cada pulsación de BTN[0] captura SW[7:0] como un byte del buffer.
                -- Cuando se alcanza el índice S_N_LAST, se lanza la operación.
                WHEN ENTRADA =>
                    IF S_BTN_VALID = '1' THEN
                        S_DATA_IN(TO_INTEGER(S_PART_IDX)) <= UNSIGNED(SW);
                        IF S_PART_IDX = S_N_LAST THEN
                            S_START <= '1';       -- Pulso de disparo (1 ciclo)
                            S_STATE <= OPERACION;
                        ELSE
                            S_PART_IDX <= S_PART_IDX + 1;
                        END IF;
                    END IF;

                -- [2] OPERACION ────────────────────────────────────────────────
                -- Espera la señal READY del módulo de operación.
                -- La transición es automática, sin intervención del usuario.
                WHEN OPERACION =>
                    IF S_READY = '1' THEN
                        S_STATE <= SALIDA;
                    END IF;

                -- [3] SALIDA ───────────────────────────────────────────────────
                -- El resultado es navegable mediante SW[1:0] (selector de ventana).
                -- Una nueva pulsación de BTN[0] reinicia el ciclo desde IDLE.
                WHEN SALIDA =>
                    IF S_BTN_VALID = '1' THEN
                        S_STATE <= IDLE;
                    END IF;

            END CASE;
        END IF;
    END PROCESS P_FSM;

    -- =========================================================================
    -- [6]  Indicadores de estado en LEDs
    --      LED[3:0]: estado de la FSM   (activos alto)
    --      LED[7:4]: reservados para uso del alumno (apagados por defecto)
    -- =========================================================================

    LED(7 DOWNTO 4) <= (OTHERS => '0');

    WITH S_STATE SELECT LED(3 DOWNTO 0) <=
        "0001" WHEN IDLE,
        "0010" WHEN ENTRADA,
        "0100" WHEN OPERACION,
        "1000" WHEN SALIDA,
        "0000" WHEN OTHERS;

    -- =========================================================================
    -- [7]  Multiplexor de ventana para los displays
    --      SW[1:0] selecciona el par de bytes del buffer de salida a mostrar:
    --        "00" → bytes[1:0]  |  "01" → bytes[3:2]
    --        "10" → bytes[5:4]  |  "11" → bytes[7:6]
    --      Cada byte se descompone en 2 nibbles (display big-endian):
    --        Display 3 (izq.) = nibble alto del byte superior del par
    --        Display 0 (der.) = nibble bajo  del byte inferior del par
    -- =========================================================================

    S_WIN_BASE <= TO_INTEGER(UNSIGNED(SW(1 DOWNTO 0))) * 2;

    S_DATOS_DISP(3) <= STD_LOGIC_VECTOR(S_DATA_OUT(S_WIN_BASE + 1)(7 DOWNTO 4));
    S_DATOS_DISP(2) <= STD_LOGIC_VECTOR(S_DATA_OUT(S_WIN_BASE + 1)(3 DOWNTO 0));
    S_DATOS_DISP(1) <= STD_LOGIC_VECTOR(S_DATA_OUT(S_WIN_BASE    )(7 DOWNTO 4));
    S_DATOS_DISP(0) <= STD_LOGIC_VECTOR(S_DATA_OUT(S_WIN_BASE    )(3 DOWNTO 0));

END ARCHITECTURE RTL;
