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
	cp -f grl-arteplus7.xml $(DESTDIR)/usr/lib/x86_64-linux-gnu/grilo-0.2/
	cp -f libgrlarteplus7.so $(DESTDIR)/usr/lib/x86_64-linux-gnu/grilo-0.2/

