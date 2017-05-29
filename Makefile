
# avoid implicit rules for clarity
.SUFFIXES: .asm .o .gb
.PHONY: bgb clean tests

ASMS := $(wildcard *.asm)
OBJS := $(ASMS:.asm=.o)
INCLUDES := $(wildcard include/*.asm)
ASSETS := $(shell find assets/ -type f)
TESTS := $(wildcard tests/*.py)

all: rom.gb tests/.uptodate

include/assets/.uptodate: $(ASSETS) tools/assets_to_asm.py
	python tools/assets_to_asm.py assets/ include/assets/
	touch $@

tests/.uptodate: $(TESTS) tools/unit_test_gen.py $(OBJS)
	python tools/unit_test_gen.py .
	touch "$@"

tests: tests/.uptodate

%.o: %.asm $(INCLUDES) include/assets/.uptodate
	rgbasm -i include/ -v -o $@ $<

rom.gb: $(OBJS)
	rgblink -n rom.sym -o $@ $^
	rgbfix -v -p 0 $@

bgb: rom.gb
	bgb $<

clean:
	rm -f *.o *.sym rom.gb include/assets/.uptodate include/assets/*.asm tests/*/*.{asm,o,sym,gb}
