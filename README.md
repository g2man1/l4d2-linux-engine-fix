# Left 4 Dead 2 - Linux Native Engine Crash Fix (`libl4d2_engine_fix.so`)

[![Platform](https://img.shields.io/badge/Platform-Linux%20x86%20(32--bit)-orange.svg)](https://store.steampowered.com/app/550/Left_4_Dead_2/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Tested%20%26%20Working-brightgreen.svg)]()

[English](#english) | [Español](#español)

---

<a name="english"></a>
## English

### Problem Overview
When playing custom campaigns (such as **Glubtastic 5**, custom survival maps, or add-ons with custom audio) on **native Linux** (`hl2_linux`), the game frequently crashes directly to desktop with an instant **Segmentation Fault (`SIGSEGV`)**.

### Root Cause
Valve's Linux binary `engine.so` contains a native bug: during soundscape / MP3 metadata parsing (offset `engine.so + 0x277cfe`), it calls `strdup(pString)` with a **`NULL` pointer (`0x0`)**.
Unlike Windows MSVCRT, the GNU C Library (`glibc` / `libc.so.6`) does not tolerate `NULL` in string routines: `strdup` calls `strlen(0x0)`, attempting `mov (%eax), %ecx` at offset `+0xc5311`, which triggers an immediate hardware CPU fault.

### The Solution: `libl4d2_engine_fix.so`
This project provides a lightweight, position-independent (PIC) 32-bit x86 shared library written in pure assembly that intercepts `strdup` and `strlen` via `LD_PRELOAD`:
* **Safe `strdup`:** If `pString == NULL`, it safely allocates a 1-byte buffer with `\0` (valid empty string) instead of crashing.
* **Safe `strlen`:** If `pString == NULL`, it immediately returns `0`.

---

### Quick Installation (1-Click)

Clone this repository and run the automated installer:

```bash
git clone https://github.com/YOUR_USERNAME/l4d2-linux-engine-fix.git
cd l4d2-linux-engine-fix
bash install.sh
```

### Alternative: Steam Launch Options (No file modification)

1. Copy the precompiled library to your local user library directory:
   ```bash
   mkdir -p ~/.local/lib
   cp bin/libl4d2_engine_fix.so ~/.local/lib/
   ```
2. Open **Steam** -> Right-click **Left 4 Dead 2** -> **Properties** -> **General**.
3. In **Launch Options**, paste:
   ```bash
   LD_PRELOAD="$HOME/.local/lib/libl4d2_engine_fix.so" %command%
   ```

---

### Building from Source

To compile the library from `src/libl4d2_engine_fix.s`, you need `gcc` with 32-bit multilib support:

```bash
# Ubuntu / Debian
sudo apt install gcc-multilib make

# Arch Linux
sudo pacman -S lib32-glibc make

# Compile
make
```

### Uninstallation

```bash
bash uninstall.sh
```

---

### Additional Technical Documentation
For in-depth crash dump analysis, step-by-step x86 disassembly, and call stack reconstruction:
* [English Technical Analysis](docs/TECHNICAL_ANALYSIS_EN.md)
* [Análisis Técnico en Español](docs/TECHNICAL_ANALYSIS_ES.md)

---

<a name="español"></a>
## Español

### Descripción del Problema
Al jugar campañas personalizadas (como **Glubtastic 5**, mapas de supervivencia o addons de la Workshop con audios personalizados) en la versión **nativa de Linux** (`hl2_linux`), el juego a menudo sufre cierres forzados súbitos al escritorio (*Segmentation Fault / SIGSEGV*).

### Causa Raíz
El binario nativo de Valve para Linux `engine.so` contiene un error de programación: durante la carga de sonido y tablas de strings (desplazamiento `engine.so + 0x277cfe`), invoca la función `strdup(pString)` pasando un **puntero nulo (`NULL` / `0x0`)**.
A diferencia de Windows, en Linux la librería estándar de C (`glibc` / `libc.so.6`) no permite punteros nulos en rutinas de texto: `strdup` invoca `strlen(0x0)`, ejecutando `mov (%eax), %ecx` en el offset `+0xc5311`, lo que provoca el cierre forzado inmediato del juego.

### La Solución: `libl4d2_engine_fix.so`
Este proyecto implementa una librería compartida en ensamblador x86 de 32 bits puro (`PIC` compatible) que intercepta de forma transparente `strdup` y `strlen` mediante `LD_PRELOAD`:
* **`strdup` seguro:** Si recibe `NULL`, reserva dinámicamente un buffer de 1 byte con `\0` (cadena vacía válida). El juego continúa sin colapsar y permite liberar la memoria de forma segura.
* **`strlen` seguro:** Si recibe `NULL`, retorna inmediatamente `0` en vez de desreferenciar la dirección `0x0`.

---

### Instalación Rápida (1 Clic)

Clona este repositorio y corre el instalador automatizado:

```bash
git clone https://github.com/TU_USUARIO/l4d2-linux-engine-fix.git
cd l4d2-linux-engine-fix
bash install.sh
```

### Método Alternativo: Parámetros de Lanzamiento en Steam

1. Copia la librería precompilada a tu carpeta local de librerías:
   ```bash
   mkdir -p ~/.local/lib
   cp bin/libl4d2_engine_fix.so ~/.local/lib/
   ```
2. Abre **Steam** -> Clic derecho en **Left 4 Dead 2** -> **Propiedades** -> pestaña **General**.
3. En la casilla **Parámetros de lanzamiento**, pega:
   ```bash
   LD_PRELOAD="$HOME/.local/lib/libl4d2_engine_fix.so" %command%
   ```

---

### Compilación desde el Código Fuente

Si deseas compilar la librería tú mismo a partir de `src/libl4d2_engine_fix.s`:

```bash
# Ubuntu / Debian
sudo apt install gcc-multilib make

# Arch Linux
sudo pacman -S lib32-glibc make

# Compilar
make
```

### Desinstalación

```bash
bash uninstall.sh
```

---

### Compatibilidad
* Compatible con **Left 4 Dead 2** (Cliente Linux y Servidores Dedicados `srcds_linux`).
* Probado y verificado en Ubuntu, Debian, Arch Linux y Steam Deck (SteamOS Desktop).
* No interfiere con VAC ni modifica los binarios del juego en disco.

---

### Documentación Técnica Adicional
Para ver el análisis detallado del minidump, el desensamblado x86 paso a paso y la reconstrucción de la pila de llamadas:
* [Análisis Técnico en Español](docs/TECHNICAL_ANALYSIS_ES.md)
* [English Technical Analysis](docs/TECHNICAL_ANALYSIS_EN.md)
