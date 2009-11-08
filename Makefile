SCRIPT = /usr/local/share/gputils/lkr/16f870.lkr
OBJECTS = serial.o piceeprom.o

all:main.hex

main.hex: $(OBJECTS) main.o $(SCRIPT)
	gplink --map -c -s $(SCRIPT) -o main.hex $(OBJECTS) main.o

%.o:%.asm
	gpasm $(CFLAGS) -c -w2 $<

clean:
	rm -f *~ *.o *.lst *.map *.hex *.cod *.cof memory.hint main.gif *.bin

test.hex: testmain.o
	gplink --map -c -s $(SCRIPT) -o test.hex testmain.o

memory.hint:
	./build-hints.pl > memory.hint

disassemble: main.hex memory.hint
	pic-disassemble -d -D 5 -a -s -I .string -S dummy:_\.org:check_start:check_end:^_ -i main.hex -m main.map -r memory.hint -g main.gif


install: main.hex
	picp /dev/tty.KeySerial1 16f870 -ef && picp /dev/tty.KeySerial1 16f870 -wc `./perl-flags-generator main.hex` -s -wp main.hex
