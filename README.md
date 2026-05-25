# Framework de Entrada/Salida Genérico para BASYS 2

Este proyecto consiste en el desarrollo de una infraestructura en VHDL para gestionar la 
entrada de datos en formato binario natural, procesar una operación lógica/aritmética y 
visualizar resultados de gran tamaño (hasta 8 bytes) mediante un sistema de ventanas en 
los 4 displays de 7 segmentos.

## Arquitectura de Relojes

Para asegurar una interacción humana estable y evitar rebotes mecánicos, el sistema 
utiliza tres dominios de reloj:

- **Master CLK (50 MHz):** Sincronía general del sistema y lógica de alta velocidad.
- **TICK 500 Hz:** Generado para la multiplexación de los ánodos de los displays (basado 
	 en `SYSTEM_CONSTANTS.vhdl`).
- **IO_CLK (2 Hz):** Reloj de interacción lenta para el filtrado de la interfaz de 
    usuario.

## Protocolo de Seguridad para Botones (Debouncing Natural)

Aunque el reloj de 2 Hz filtra la mayoría de los rebotes, se recomienda implementar un 
Detector de Flanco de Subida sobre el botón sincronizado.

Esto evita que, si un usuario mantiene pulsado el botón más de 0.5 segundos, el sistema 
salte dos estados seguidos.

**Lógica recomendada:** El sistema solo registrará un cambio si detecta que el botón ha 
pasado de `0` a `1` en un instante en que el `IO_CLK` esté en un flanco activo.

## Máquina de Estados (FSM)

El progreso del sistema se monitoriza mediante los LED `[3:0]`, que indican el estado 
actual:

### [0] ESTADO IDLE (LED: `0001`)

Estado de reposo tras reset (`BTN3`que sipone un `RST` para nuestro sistema). El sistema 
espera la pulsación de un botón de control (en principio nos quedan `BTN[2:0]`) para 
iniciar la carga.

### [1] ENTRADA DE DATOS (LED: `0010`)

- **Configuración:** Mediante `SW[2:0]`, el usuario define la longitud $N$ (número de 
    partes) del dato de entrada.
- **Captura secuencial:** El sistema concatena los valores de los switches en un registro
    único de binario natural. Cada validación (Botón + Flanco 2 Hz) guarda el fragmento 
	 actual y avanza el índice.

### [2] OPERACIÓN (LED: `0100`)

Este estado se activa al completar la carga del buffer de entrada.

- **Transición automática:** La operación genera una señal `Ready/Valid`. Al detectarse, 
    la FSM transita inmediatamente al estado de salida sin esperar intervención humana.

### [3] SALIDA Y VISUALIZACIÓN (LED: `1000`)

El resultado se almacena en el buffer de salida (hasta 16 nibbles / 8 bytes).

- **Navegación por ventanas:** Se usa `SW[1:0]` para seleccionar qué 2 bytes (4 nibbles) 
  del resultado se envían a los displays.

  - `00`: Bytes 0-1
  - `01`: Bytes 2-3
  - `10`: Bytes 4-5
  - `11`: Bytes 6-7

Una pulsación del botón de control reinicia el ciclo y retorna al estado IDLE.

## Asignación de Hardware (Mapping)

| Periférico     | Función |
|----------------|---------|
| `CLK`          | Señal de reloj del sistema.  |
| `BTN3`         | Señal de reset: reinicio asíncrono de toda la lógica. |
| `BTN[2:0]`     | Control: validación de entrada y cambio de estado (sincronizado a 2 Hz). |
| `READY`        | Control: la operación ha terminado con éxito. |
| `SW[7:0]`      | Datos/Configuración: longitud, valor de datos y selector de ventana. |
| `Displays 7S`  | Salida: visualización hexadecimal mediante `DISPLAY_CTRL`. |
| `LEDs`         | Estado: monitorización de la FSM (IDLE/IN/OP/OUT). |

## Especificaciones Técnicas

- **Cálculo de constante:** Para `GEN_IO_CLK`, usar `MAX_COUNT = 12,500,000`.
- **Manejo de tipos:** Se recomienda el uso de `UNSIGNED` para la concatenación del binario 
    natural, para facilitar la operación aritmética posterior.

> **Nota técnica:** La Basys 2 incorpora resistencias de pull-down externas en los 
    botones. Por ello, la lógica de control debe definirse como activa en nivel 
	 alto (`1`).
