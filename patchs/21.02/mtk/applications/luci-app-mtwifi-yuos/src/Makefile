all: mtwifi-sta

# luci.mk invokes "make clean compile" via Build/Compile/Default
compile: all

mtwifi-sta: mtwifi-sta.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<

# note: luci.mk does not export INSTALL_BIN into the src/ build, use coreutils install
install: all
	install -d -m0755 $(DESTDIR)/usr/bin
	install -m0755 mtwifi-sta $(DESTDIR)/usr/bin/

clean:
	rm -f mtwifi-sta

.PHONY: all compile install clean
