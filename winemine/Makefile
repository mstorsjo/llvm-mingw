SRC_PATH=$(word 1, $(dir $(MAKEFILE_LIST)))
vpath %.c $(SRC_PATH)
vpath %.rc $(SRC_PATH)

CC = $(CROSS)gcc
WINDRES = $(CROSS)windres

LDFLAGS += -municode -mwindows -lgdi32
CFLAGS += -municode

all: winemine.exe

winemine.exe: dialog.o main.o winemine.o
	$(CC) -o $@ $+ $(LDFLAGS)

%.o: %.rc
	$(WINDRES) -o $@ $<

clean:
	rm -f winemine.exe *.o
