PREFIX = /usr

obj = kbdlight.o
bin = kbdlight

$(bin): $(obj)
	$(CC) -o $@ $(obj) $(LDFLAGS)

.PHONY: clean
clean:
	rm -f $(obj) $(bin)

.PHONY: install
install:
	install -Dm 4755 $(bin) $(DESTDIR)$(PREFIX)/sbin/$(bin)

.PHONY: uninstall
uninstall:
	rm -f $(DESTDIR)$(PREFIX)/sbin/$(bin)
