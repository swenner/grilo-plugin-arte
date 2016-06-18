DESTDIR=
VERSION=1.0.0
NAME=grilo-plugin-arte
PACKAGE=$(NAME)-$(VERSION)
VALAC=valac

GRILO_VERSION=2

VALA_ARGS=-D DEBUG_MESSAGES $(CC_ARGS) -g
ifeq ($(GRILO_VERSION),2)
    # vala bindings are missing in Debian Jessie, ok in Stretch and Ubuntu >= 16.04
    #VALA_DEPS=--pkg grilo-0.2 --pkg libsoup-2.4 --pkg gio-2.0 --pkg json-glib-1.0
    #CC_ARGS=-X -fPIC -X -shared --Xcc="-D GETTEXT_PACKAGE=\"grilo-arte\""
    VALA_DEPS=--pkg libsoup-2.4 --pkg gio-2.0 --pkg json-glib-1.0 --pkg gmodule-2.0
    CC_ARGS=-X -fPIC -X -shared --Xcc="-D GETTEXT_PACKAGE=\"grilo-arte\"" -X -std=c99 --Xcc=-I/usr/include/grilo-0.2 grilo-0.2.vapi
else
    # Grilo Version 0.3
    VALA_ARGS+= -D GRILO_VERSION_3
    VALA_DEPS=--pkg libsoup-2.4 --pkg gio-2.0 --pkg json-glib-1.0 --pkg gmodule-2.0 --pkg grilo-0.3
    CC_ARGS=-X -fPIC -X -shared --Xcc="-D GETTEXT_PACKAGE=\"grilo-arte\"" -X -std=c99
endif

VALA_SOURCE=\
	arteparser.vala \
	url-extractor.vala \
	video.vala \
	common.vala \
	grl-arteplus7.vala \
	grl-arteplus7-plugin.c
EXTRA_DIST=\
	grilo-0.2.vapi \
	grl-arteplus7.xml \
	arteplus7.png \
	org.gnome.totem.plugins.arteplus7.gschema.xml \
	Makefile README AUTHORS COPYING NEWS ChangeLog

# This directory can be arch-specific. Let's autodetect it.
GRILO_PLUGIN_DIR=$(DESTDIR)/$(shell pkg-config --variable=plugindir grilo-0.$(GRILO_VERSION))

all:
	$(VALAC) --library=arteplus7 $(VALA_SOURCE) $(VALA_DEPS) $(VALA_ARGS) -o libgrlarteplus7.so
	msgfmt --output-file=po/de.mo po/de.po
	msgfmt --output-file=po/fr.mo po/fr.po

install:
	mkdir -p $(GRILO_PLUGIN_DIR) $(DESTDIR)/usr/share/grilo-plugins/grl-arteplus7
ifeq ($(GRILO_VERSION),2)
	cp -f grl-arteplus7.xml $(GRILO_PLUGIN_DIR)
endif
	cp -f libgrlarteplus7.so $(GRILO_PLUGIN_DIR)
	cp -f arteplus7.png $(DESTDIR)/usr/share/grilo-plugins/grl-arteplus7/

	mkdir -p $(DESTDIR)/usr/share/glib-2.0/schemas
	cp -f org.gnome.totem.plugins.arteplus7.gschema.xml $(DESTDIR)/usr/share/glib-2.0/schemas
ifeq ($(DISABLE_SCHEMAS_COMPILE),)
	glib-compile-schemas $(DESTDIR)/usr/share/glib-2.0/schemas/
endif
	mkdir -p $(DESTDIR)/usr/share/locale/de/LC_MESSAGES
	mkdir -p $(DESTDIR)/usr/share/locale/fr/LC_MESSAGES
	cp -f po/de.mo $(DESTDIR)/usr/share/locale/de/LC_MESSAGES/grilo-arte.mo
	cp -f po/fr.mo $(DESTDIR)/usr/share/locale/fr/LC_MESSAGES/grilo-arte.mo

uninstall:
	rm $(GRILO_PLUGIN_DIR)/grl-arteplus7.xml $(GRILO_PLUGIN_DIR)/libgrlarteplus7.so
	rm $(DESTDIR)/usr/share/glib-2.0/schemas/org.gnome.totem.plugins.arteplus7.gschema.xml
	rm -r $(DESTDIR)/usr/share/grilo-plugins/grl-arteplus7/
ifeq ($(DISABLE_SCHEMAS_COMPILE),)
	glib-compile-schemas $(DESTDIR)/usr/share/glib-2.0/schemas/
endif
	rm $(DESTDIR)/usr/share/locale/de/LC_MESSAGES/grilo-arte.mo
	rm $(DESTDIR)/usr/share/locale/fr/LC_MESSAGES/grilo-arte.mo

clean:
	rm -f libgrlarteplus7.so
	rm -f arteplus7.vapi
	rm -f po/*mo

dist:
	rm -f ChangeLog
	git log --pretty=short > ChangeLog
	mkdir $(PACKAGE)
	mkdir $(PACKAGE)/po
	cp -f $(VALA_SOURCE) $(PACKAGE)/
	cp -f $(EXTRA_DIST) $(PACKAGE)/
	cp -f po/POTFILES.in po/grilo-arte.pot po/de.po po/fr.po $(PACKAGE)/po/
	tar -pcJf $(PACKAGE).tar.xz $(PACKAGE)/
	rm -rf $(PACKAGE)
