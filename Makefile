sources = $(wildcard *.vala)
VALAC = valac
VALAFLAGS = --pkg=gtk+-3.0 --pkg=json-glib-1.0 --pkg=gio-unix-2.0

all: xi-gtk

xi-gtk: $(sources)
	$(VALAC) -o $@ $(VALAFLAGS) $^

clean:
	rm -f xi-gtk

.PHONY: all clean
