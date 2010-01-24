DESTDIR=

all:
	valac -C arteplus7.vala --thread --pkg libsoup-2.4 --pkg gee-1.0 --pkg totem --pkg gconf-2.0 --vapidir=./deps
	gcc -shared -fPIC `pkg-config --cflags --libs glib-2.0 libsoup-2.4 gee-1.0 gtk+-2.0 totem-plparser gconf-2.0` -o libarteplus7.so arteplus7.c -I./deps -DGETTEXT_PACKAGE="\"totem-arte\""
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

uninstall:
	rm -r $(DESTDIR)/usr/lib/totem/plugins/arteplus7
	rm $(DESTDIR)/usr/share/locale/de/LC_MESSAGES/totem-arte.mo
	rm $(DESTDIR)/usr/share/locale/fr/LC_MESSAGES/totem-arte.mo

clean:
	rm arteplus7.c libarteplus7.so
	rm po/*mo
