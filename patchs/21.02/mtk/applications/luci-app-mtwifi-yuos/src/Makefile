all: mtwifi-sta

mtwifi-sta: mtwifi-sta.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<

install: all
	mkdir -p $(DESTDIR)/usr/bin
	$(INSTALL_BIN) mtwifi-sta $(DESTDIR)/usr/bin/

clean:
	rm -f mtwifi-sta

.PHONY: all install clean
