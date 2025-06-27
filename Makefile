all: os.img

os.img: boot.o
	copy /b boot.o os.img > nul

boot.o: boot.asm
	nasm -f bin boot.asm -o boot.o

clean:
	del /q *.o *.img > nul 2>&1
