CC ?= gcc
CFLAGS ?= -m32 -shared -fPIC -nostdlib -Wl,-soname,libl4d2_engine_fix.so

all: bin/libl4d2_engine_fix.so

bin/libl4d2_engine_fix.so: src/libl4d2_engine_fix.s
	@mkdir -p bin
	$(CC) $(CFLAGS) -o $@ $< -lc

clean:
	rm -f bin/libl4d2_engine_fix.so

.PHONY: all clean
