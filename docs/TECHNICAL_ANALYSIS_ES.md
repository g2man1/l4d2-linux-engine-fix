# Análisis Técnico y Detalle del Parche de Motor para Left 4 Dead 2 (Linux Nativo)

[English](TECHNICAL_ANALYSIS.md) | [Español](TECHNICAL_ANALYSIS_ES.md)

---

Este documento detalla la investigación, depuración de bajo nivel y solución aplicada para corregir los cuelgues súbitos (*crashes*) al escritorio en **Left 4 Dead 2** versión nativa de Linux (`hl2_linux`), originados por fallos en el motor de Valve (`engine.so`) y detonados por contenido de la campaña **Glubtastic 5** (especialmente en el Capítulo 3 / `glubtastic5_3`) o cualquier addon con audios personalizados.

---

## 1. Contexto y Síntomas del Fallo

Al jugar campañas personalizadas en Linux nativo (sin capas de emulación como Proton o Wine), el juego sufría un cierre forzado (*Segmentation Fault / SIGSEGV*) sin mostrar ningún diálogo de error ni volcar mensajes sospechosos en la consola estándar.

Los eventos previos al cierre solían coincidir con la activación de eventos o soundscapes:
```text
You Got The Temple Token!
1/5 Park Tokens Acquired
```
Justo después de este registro, el proceso moría instantáneamente y generaba un volcado minidump (`/tmp/dumps/crash_*.dmp`).

---

## 2. Ingeniería Inversa y Diagnóstico del Crash Dump

Al desensamblar y reconstruir la pila de llamadas (*call stack unwind*) del volcado generado, se ubicó el punto exacto de la falla:

### A. Dirección del Crash en Memoria
- **Registro EIP:** en `libc.so.6` (desplazamiento `+0xc5311`).
- **Instrucción causante:**
  ```assembly
  0xc5311: mov (%eax), %ecx
  ```
- **Estado de registros al momento del colapso:**
  - `EAX = 0x00000000` (Puntero `NULL`).
  - Al intentar leer la memoria apuntada por `EAX` (`0x0`), el procesador disparó una violación de acceso (`SIGSEGV`).
  - Esa rutina corresponde a la implementación optimizada de `strlen()` en la librería estándar de C (`glibc`).

### B. Rastreo del Invocador en `engine.so`
Subiendo por la pila de ejecución, se descubrió la función que originó la llamada:
- Módulo: `bin/engine.so`
- Dirección de retorno: `engine.so + 0x277cfe`
- Instrucción llamadora:
  ```assembly
  0x00277cf6: mov %eax, (%esp)
  0x00277cf9: call strdup@PLT      <-- Invocó strdup(0x0)
  0x00277cfe: mov %eax, 0x8(%ebx)
  ```

---

## 3. Causa Raíz: El Bug Oculto en el Motor de Valve

El motor de audio de Source 1 en Linux incluye un decodificador y analizador de tramas MP3 ubicado entre `0x278000` y `0x27a600` de `engine.so`.

### El ciclo del fallo:
1. **Disparador en el mapa:** Al entrar al parque o recolectar tokens, el mapa activa un *soundscape* con sonidos ambientales en formato MP3 (`glub5/ambient/*.mp3`, como `museum_dioramaracket_04.mp3`).
2. **MP3 sin padding final:** Varios de los archivos MP3 del mod terminan bruscamente en el último fotograma sin bytes de relleno (*padding*) ni etiquetas ID3v1 al cierre.
3. **Escaneo de fin de archivo (EOF):** El motor lee la trama actual y calcula la posición de la siguiente (`offset = 12681`). Al intentar leer en esa posición, se topa con el final del archivo.
4. **Condición de error:**
   ```assembly
   0x0027a417: cmp %edx, %eax    ; Compara (tamaño_archivo - 4) con (offset_actual)
   0x0027a419: jg  0x27a4a0      ; Si se pasa del archivo, salta al generador de excepciones
   ```
5. **Puntero NULL no verificado:**
   En la subrutina `0x27a4a0` (y también en `0x27a5ba`), el código de Valve prepara los datos para lanzar una excepción C++ (`__cxa_throw` con tipo `0x7fd1d8`):
   ```assembly
   0x0027a4ac: movl $0x0, 0x10(%esp)   ; Parámetro 4 = NULL
   0x0027a4b4: movl $0x0, 0xc(%esp)    ; Parámetro 3 = NULL
   0x0027a4c1: movl $0x7, 0x4(%esp)    ; Código de error = 7
   0x0027a4d0: call 0x277cd0           ; Constructor del objeto de excepción
   ```
   Dentro de `0x277cd0`:
   ```assembly
   0x00277cf3: mov 0x14(%ebp), %eax    ; Recupera el Parámetro 3 (que vale 0x0)
   0x00277cf6: mov %eax, (%esp)
   0x00277cf9: call strdup             ; Llama directamente a strdup(NULL)
   ```
6. **El desenlace fatal:**
   En Windows (o con el Miles Sound System antiguo), esta ruta de código no existía o toleraba punteros nulos. Pero en Linux con `glibc`, `strdup(NULL)` ejecuta `strlen(NULL)`, generando un **Segmentation Fault inmediato**.
   El juego muere instantáneamente sin que el bloque `catch` del motor (`0x278770`) llegue a tener la oportunidad de capturar la excepción.

---

## 4. Solución Implementada: `libl4d2_engine_fix.so`

Para solucionar el problema a nivel global y definitivo sin alterar el binario propietario de Valve en disco, se creó una librería compartida en ensamblador x86 de 32 bits puro (`PIC` compatible):

### Código de la Librería (`libl4d2_engine_fix.s`)
```assembly
.text
.globl __x86.get_pc_thunk.bx
.hidden __x86.get_pc_thunk.bx
.type __x86.get_pc_thunk.bx, @function
__x86.get_pc_thunk.bx:
    movl (%esp), %ebx
    ret

.globl strdup
.type strdup, @function
strdup:
    pushl %ebp
    movl %esp, %ebp
    pushl %ebx
    pushl %esi
    pushl %edi
    subl $12, %esp

    call __x86.get_pc_thunk.bx
    addl $_GLOBAL_OFFSET_TABLE_, %ebx

    movl 8(%ebp), %esi        # esi = puntero s
    testl %esi, %esi
    jnz .Lhas_str

    # Si s == NULL -> longitud 0 segura
    xorl %edi, %edi
    jmp .Ldo_alloc

.Lhas_str:
    movl %esi, (%esp)
    call strlen@PLT
    movl %eax, %edi

.Ldo_alloc:
    leal 1(%edi), %eax
    movl %eax, (%esp)
    call malloc@PLT
    testl %eax, %eax
    jz .Ldone

    testl %edi, %edi
    jz .Lzero_term

    movl %edi, 8(%esp)
    movl %esi, 4(%esp)
    movl %eax, (%esp)
    movl %eax, %esi           # Guardar dirección retornada
    call memcpy@PLT
    movl %esi, %eax

.Lzero_term:
    movb $0, (%eax, %edi)

.Ldone:
    addl $12, %esp
    popl %edi
    popl %esi
    popl %ebx
    popl %ebp
    ret
.size strdup, .-strdup

.globl strlen
.type strlen, @function
strlen:
    pushl %ebp
    movl %esp, %ebp
    pushl %edi

    movl 8(%ebp), %edi
    testl %edi, %edi
    jz .Lstrlen_null

    xorl %eax, %eax
    movl $-1, %ecx
    cld
    repne scasb
    notl %ecx
    decl %ecx
    movl %ecx, %eax
    jmp .Lstrlen_done

.Lstrlen_null:
    xorl %eax, %eax

.Lstrlen_done:
    popl %edi
    popl %ebp
    ret
.size strlen, .-strlen
```

### Mecánica de Funcionamiento:
- **Interceptación segura de `strdup`:** Si cualquier rutina de `engine.so` o `client.so` le pasa un puntero `NULL`, la función asigna dinámicamente un buffer de 1 byte con `\0` (cadena vacía válida). El destructor de excepciones de Valve (`0x277c30`) podrá luego hacer `free()` sin problemas de corrupción ni colapso de memoria.
- **Interceptación segura de `strlen`:** Si alguna rutina invoca `strlen(NULL)`, retorna inmediatamente `0` en lugar de desreferenciar la dirección `0x0`.

---

## 5. Inyección Mediante `hl2.sh` (`LD_PRELOAD`)

La librería se instala en el directorio estándar:
`~/.local/lib/libl4d2_engine_fix.so`

En el script de inicio `hl2.sh` del juego, se añade antes de la ejecución de `hl2_linux`:
```bash
export LD_PRELOAD="$HOME/.local/lib/libl4d2_engine_fix.so${LD_PRELOAD:+:$LD_PRELOAD}"
```
Esto garantiza que el enlazador dinámico resuelva `strdup` y `strlen` hacia nuestra versión segura antes de cargar `libc.so.6`.

---

## 6. Alcance y Protección
Este parche actúa como una capa de protección a nivel de motor:
* Intercepta de forma segura cualquier llamada `strdup(NULL)` o `strlen(NULL)` originada por el motor de Source (`engine.so`, `server.so` o librerías asociadas).
* Permite que campañas con estructuras de audio o tablas de cadenas irregulares se ejecuten sin cierres forzados súbitos.
* No altera los binarios del juego en disco ni requiere privilegios de root (`sudo`).
