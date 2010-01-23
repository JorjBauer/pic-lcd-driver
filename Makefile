SCRIPT = /usr/local/share/gputils/lkr/16f627.lkr
OBJECTS = serial.o piceeprom.o lcd.o memory.o serbuf.o
#CFLAGS = -DSERIAL_ECHO

#SERIAL = /dev/tty.KeySerial1
SERIAL = `ls /dev/tty.PL2303-*|head -1`


all:main.hex

main.hex: $(OBJECTS) main.o $(SCRIPT)
	gplink --map -c -s $(SCRIPT) -o main.hex $(OBJECTS) main.o

%.o:%.asm
	gpasm $(CFLAGS) -c -w2 $<

clean:
	rm -f *~ *.o *.lst *.map *.hex *.cod *.cof memory.hint main.gif *.bin version.inc

test.hex: testmain.o
	gplink --map -c -s $(SCRIPT) -o test.hex testmain.o

memory.hint:
	./build-hints.pl > memory.hint

disassemble: main.hex memory.hint
	pic-disassemble -d -D 7 -a -s -o -I .string -S dummy:_\.org:check_start:check_end -i main.hex -m main.map -r memory.hint -g main.gif

install: main.hex
	picp $(SERIAL) 16f627 -ef && picp $(SERIAL) 16f627 -wc `./perl-flags-generator main.hex` -s -wp main.hex

lcd.o: version.inc

version.inc:
	./perl-version-generator > version.inc

.PHONY: version.inc

