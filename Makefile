DESTDIR=
VERSION=3.0.0
NAME=totem-plugin-arte
PACKAGE=$(NAME)-$(VERSION)
VALA_DEPS=--pkg Totem-1.0 --pkg PeasGtk-1.0 --pkg libsoup-2.4 --pkg gtk+-3.0
CC_ARGS=-X -fPIC -X -shared --Xcc='-D GETTEXT_PACKAGE="\"totem-arte\""'
VALA_ARGS=-D DEBUG_MESSAGES $(CC_ARGS)
VALA_SOURCE=\
	arteplus7.vala \
	arteparser.vala \
	cache.vala \
	url-extractor.vala
EXTRA_DIST=\
	arteplus7.plugin \
	arteplus7-default.png \
	org.gnome.totem.plugins.arteplus7.gschema.xml \
	Makefile README AUTHORS COPYING NEWS ChangeLog

all:
	valac --library=arteplus7 $(VALA_SOURCE) $(VALA_DEPS) $(VALA_ARGS) -o libarteplus7.so 
	msgfmt --output-file=po/de.mo po/de.po
	msgfmt --output-file=po/fr.mo po/fr.po

install:
	mkdir -p $(DESTDIR)/usr/lib/totem/plugins/arteplus7 $(DESTDIR)/usr/share/totem/plugins/arteplus7
	cp -f arteplus7.plugin $(DESTDIR)/usr/lib/totem/plugins/arteplus7
	cp -f libarteplus7.so $(DESTDIR)/usr/lib/totem/plugins/arteplus7
	cp -f arteplus7-default.png $(DESTDIR)/usr/share/totem/plugins/arteplus7

	mkdir -p $(DESTDIR)/usr/share/glib-2.0/schemas
	cp -f org.gnome.totem.plugins.arteplus7.gschema.xml $(DESTDIR)/usr/share/glib-2.0/schemas
	glib-compile-schemas $(DESTDIR)/usr/share/glib-2.0/schemas/

	mkdir -p $(DESTDIR)/usr/share/locale/de/LC_MESSAGES
	mkdir -p $(DESTDIR)/usr/share/locale/fr/LC_MESSAGES
	cp -f po/de.mo $(DESTDIR)/usr/share/locale/de/LC_MESSAGES/totem-arte.mo
	cp -f po/fr.mo $(DESTDIR)/usr/share/locale/fr/LC_MESSAGES/totem-arte.mo

uninstall:
	rm -r $(DESTDIR)/usr/lib/totem/plugins/arteplus7 $(DESTDIR)/usr/share/totem/plugins/arteplus7
	rm $(DESTDIR)/usr/share/glib-2.0/schemas/org.gnome.totem.plugins.arteplus7.gschema.xml
	glib-compile-schemas $(DESTDIR)/usr/share/glib-2.0/schemas/
	rm $(DESTDIR)/usr/share/locale/de/LC_MESSAGES/totem-arte.mo
	rm $(DESTDIR)/usr/share/locale/fr/LC_MESSAGES/totem-arte.mo

clean:
	rm -f arteplus7.c cache.c url-extractor.c libarteplus7.so
	rm -f arteplus7.vapi
	rm -f po/*mo

dist:
	rm -f ChangeLog
	git log --pretty=short > ChangeLog
	mkdir $(PACKAGE)
	mkdir $(PACKAGE)/po
	cp -f $(VALA_SOURCE) $(PACKAGE)/
	cp -f $(EXTRA_DIST) $(PACKAGE)/
	cp -f po/POTFILES.in po/de.po po/fr.po $(PACKAGE)/po/
	tar -pczf $(PACKAGE).tar.gz $(PACKAGE)/
	rm -rf $(PACKAGE)
