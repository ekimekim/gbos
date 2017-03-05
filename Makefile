
# avoid implicit rules for clarity
.SUFFIXES: .asm .o .gb
.PHONY: run clean tiles bgb

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
	rm *.o *.sym game.gb

all: rom.gb
