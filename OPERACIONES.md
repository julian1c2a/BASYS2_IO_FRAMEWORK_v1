# Catálogo de Operaciones: Del Bit a la Aritmética

Este documento detalla diferentes niveles de implementación para el Estado 2 (Operación) del framework. El 
objetivo es que cada grupo de alumnos pueda elegir un nivel de complejidad o progresar gradualmente entre niveles.

## Nivel 0: Identidad (Prueba de Integración)

Es la operación más sencilla, pero también la más importante para validar el hardware.

- **Lógica:** El buffer de salida es una copia exacta del buffer de entrada.
- **Utilidad:** Verifica que la concatenación de nibbles y el sistema de ventanas de salida funcionan 
  correctamente.
- **Implementación:** `Registro_Salida <= Registro_Entrada;`

## Nivel 1: Manipulación de Bits y Lógica Simple

Operaciones que no requieren acarreo, pero transforman el dato de entrada.

- **Inversor bit a bit (NOT):** Invierte todos los bits introducidos. Es útil para comprender la lógica 
  negativa.
- **Desplazamiento (Shifter):** Realiza un desplazamiento lógico a la izquierda o a la derecha del número 
  binario natural completo.
- **Espejo (Mirror):** El primer nibble introducido pasa a ser el último y viceversa 
  (inversión del arreglo).

## Nivel 2: Aritmética Básica (Un Solo Argumento)

Operaciones sobre el número binario natural completo.

- **Incrementador/Decrementador:** Suma o resta `1` al número total. Requiere gestionar el desbordamiento 
  (carry out).
- **Sumador/Restador:** Suma o resta un constante al número total. Requiere gestionar el desbordamiento 
  (carry out).
- **Multiplicador por constante:** Por ejemplo, multiplicar el valor de entrada por 2, 4 u 8 
  (desplazamientos de bits alineados).
- **Cálculo de valor absoluto:** Si se asume que la entrada está en complemento a dos, mostrar en la 
  salida el valor absoluto.

## Nivel 3: Operaciones Complejas (Doble Argumento o Procesamiento)

Nivel orientado a proyectos que busquen mayor profundidad técnica.

- **Suma de bloques:** Si se introducen $N$ datos, la operación consiste en la suma acumulada de todos 
  ellos.
- **Detector de máximos/mínimos:** El sistema recorre el buffer de entrada y devuelve el valor máximo 
  (o mínimo) introducido, junto con su posición.
- **Multiplicador de 4 bits x 4 bits:** Se toman los dos primeros nibbles del buffer y se realiza una 
  multiplicación, mostrando un resultado de 8 bits en la salida.

## Notas de Implementación en VHDL

### Conversión de Tipos

Para operar con el binario natural, se recomienda realizar la conversión a `UNSIGNED` de forma explícita 
y masiva:

```vhdl
-- Ejemplo de concatenación para operación
signal n_natural : unsigned(31 downto 0); -- Para 8 nibbles
-- ...
n_natural <= unsigned(Reg_In(7) & Reg_In(6) & ... & Reg_In(0));
```

### Gestión de la Señal `READY`

Incluso si la operación implementada es la Identidad (Nivel 0), el módulo debe generar un pulso de `READY` 
para que la FSM pueda transitar al estado de salida.

### Sugerencia Docente

Se recomienda comenzar siempre por el Nivel 0. Una vez que el alumno observa sus propios datos reflejados y 
puede navegar por ellos mediante los switches, la motivación para implementar niveles superiores aumenta de 
forma significativa.
