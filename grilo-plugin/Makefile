DESTDIR=
VERSION=3.2.1
NAME=grilo-plugin-arte
PACKAGE=$(NAME)-$(VERSION)
VALAC=valac
# vala bindings are missing in debian stable
#VALA_DEPS=--pkg grilo-0.2 --pkg libsoup-2.4 --pkg gio-2.0 --pkg json-glib-1.0
VALA_DEPS=--pkg libsoup-2.4 --pkg gio-2.0 --pkg json-glib-1.0 --pkg gmodule-2.0 --pkg gdk-3.0

CC_ARGS=-X -fPIC -X -shared --Xcc="-D GETTEXT_PACKAGE=\"totem-arte\"" -X -std=c99
VALA_ARGS=-D DEBUG_MESSAGES $(CC_ARGS) -g
VALA_SOURCE=\
	../arteparser.vala \
	../cache.vala \
	../url-extractor.vala \
	../video.vala \
	../connection-status.vala \
	common.vala \
	grl-arteplus7.vala \
	grl-arteplus7-plugin.c

all:
	$(VALAC) --library=arteplus7 $(VALA_SOURCE) $(VALA_DEPS) $(VALA_ARGS) -o libgrlarteplus7.so --Xcc=-I/usr/include/grilo-0.2 grilo-0.2.vapi

install:
	mkdir -p $(DESTDIR)/usr/lib/x86_64-linux-gnu/grilo-0.2 $(DESTDIR)/usr/share/totem/plugins/arteplus7
	cp -f grl-arteplus7.xml $(DESTDIR)/usr/lib/x86_64-linux-gnu/grilo-0.2/
	cp -f libgrlarteplus7.so $(DESTDIR)/usr/lib/x86_64-linux-gnu/grilo-0.2/
	cp -f ../arteplus7-default.png $(DESTDIR)/usr/share/totem/plugins/arteplus7

	mkdir -p $(DESTDIR)/usr/share/glib-2.0/schemas
	cp -f ../org.gnome.totem.plugins.arteplus7.gschema.xml $(DESTDIR)/usr/share/glib-2.0/schemas
ifeq ($(DISABLE_SCHEMAS_COMPILE),)
	glib-compile-schemas $(DESTDIR)/usr/share/glib-2.0/schemas/
endif

uninstall:
	rm $(DESTDIR)/usr/lib/x86_64-linux-gnu/grilo-0.2/grl-arteplus7.xml $(DESTDIR)/usr/lib/x86_64-linux-gnu/grilo-0.2/libgrlarteplus7.so
	rm $(DESTDIR)/usr/share/glib-2.0/schemas/org.gnome.totem.plugins.arteplus7.gschema.xml
	rm -r $(DESTDIR)/usr/share/totem/plugins/arteplus7
	glib-compile-schemas $(DESTDIR)/usr/share/glib-2.0/schemas/

clean:
	rm -f libgrlarteplus7.so
	rm -f arteplus7.vapi
