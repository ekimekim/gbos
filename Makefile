
# avoid implicit rules for clarity
.SUFFIXES: .asm .o .gb
.PHONY: run clean

ASMS := $(wildcard *.asm)
OBJS := $(ASMS:.asm=.o)
INCLUDES := $(wildcard include/*.asm)

%.o: %.asm $(INCLUDES)
	rgbasm -i include/ -v -o $@ $<

rom.gb: $(OBJS)
	rgblink -n game.sym -o $@ $^
	rgbfix -v -p 0 $@

bgb: rom.gb
	bgb $<

clean:
	rm -f *.o *.sym rom.gb

all: rom.gb
