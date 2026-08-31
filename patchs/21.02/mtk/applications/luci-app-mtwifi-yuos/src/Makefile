all: mtwifi-sta

# luci.mk invokes "make clean compile" via Build/Compile/Default
compile: all

mtwifi-sta: mtwifi-sta.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<

install: all
	mkdir -p $(DESTDIR)/usr/bin
	$(INSTALL_BIN) mtwifi-sta $(DESTDIR)/usr/bin/

clean:
	rm -f mtwifi-sta

.PHONY: all compile install clean
