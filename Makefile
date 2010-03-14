DESTDIR=
VERSION=0.8.2
NAME=totem-plugin-arte
PACKAGE=$(NAME)-$(VERSION)

all:
	valac -C arteplus7.vala cache.vala --thread --pkg libsoup-2.4 --pkg totem --pkg gconf-2.0 --vapidir=./deps
	gcc -shared -fPIC `pkg-config --cflags --libs glib-2.0 libsoup-2.4 gtk+-2.0 totem-plparser gconf-2.0` -o libarteplus7.so arteplus7.c cache.c -I./deps -DGETTEXT_PACKAGE="\"totem-arte\""
	msgfmt --output-file=po/de.mo po/de.po
	msgfmt --output-file=po/fr.mo po/fr.po

install:
	mkdir -p $(DESTDIR)/usr/lib/totem/plugins/arteplus7
	cp -f arteplus7.totem-plugin $(DESTDIR)/usr/lib/totem/plugins/arteplus7
	cp -f libarteplus7.so $(DESTDIR)/usr/lib/totem/plugins/arteplus7

	mkdir -p $(DESTDIR)/usr/share/locale/de/LC_MESSAGES
	mkdir -p $(DESTDIR)/usr/share/locale/fr/LC_MESSAGES
	cp -f po/de.mo $(DESTDIR)/usr/share/locale/de/LC_MESSAGES/totem-arte.mo
	cp -f po/fr.mo $(DESTDIR)/usr/share/locale/fr/LC_MESSAGES/totem-arte.mo

install-home:
	mkdir -p ~/.local/share/totem/plugins/
	cp -f arteplus7.totem-plugin ~/.local/share/totem/plugins/
	cp -f libarteplus7.so ~/.local/share/totem/plugins/

uninstall:
	rm -r $(DESTDIR)/usr/lib/totem/plugins/arteplus7
	rm $(DESTDIR)/usr/share/locale/de/LC_MESSAGES/totem-arte.mo
	rm $(DESTDIR)/usr/share/locale/fr/LC_MESSAGES/totem-arte.mo

uninstall-home:
	rm ~/.local/share/totem/plugins/arteplus7.totem-plugin
	rm ~/.local/share/totem/plugins/libarteplus7.so

clean:
	rm arteplus7.c cache.c libarteplus7.so
	rm po/*mo

dist:
	mkdir $(PACKAGE)
	mkdir $(PACKAGE)/po
	mkdir $(PACKAGE)/deps
	cp -f arteplus7.vala cache.vala arteplus7.totem-plugin $(PACKAGE)/
	cp -f Makefile README AUTHORS COPYING NEWS $(PACKAGE)/
	cp -f po/POTFILES.in po/de.po po/fr.po $(PACKAGE)/po/
	cp -f deps/*.h deps/totem.vapi deps/totem.deps $(PACKAGE)/deps/
	tar -pczf $(PACKAGE).tar.gz $(PACKAGE)/
	rm -rf $(PACKAGE)

