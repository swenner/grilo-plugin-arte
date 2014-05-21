DESTDIR=
VERSION=3.2.1
NAME=totem-plugin-arte
PACKAGE=$(NAME)-$(VERSION)
VALAC=valac
VALA_DEPS=--pkg grilo-0.2 --pkg libsoup-2.4 --pkg gio-2.0 --pkg json-glib-1.0
CC_ARGS=-X -fPIC -X -shared --Xcc="-D GETTEXT_PACKAGE=\"totem-arte\""
VALA_ARGS=-D DEBUG_MESSAGES $(CC_ARGS) -g
VALA_SOURCE=\
	arteplus7.vala \
	plugin_descr.c

all:
	$(VALAC) --library=arteplus7 $(VALA_SOURCE) $(VALA_DEPS) $(VALA_ARGS) -o libgrlarteplus7.so

install:
	cp -f grl-arteplus7.xml $(DESTDIR)/usr/lib/x86_64-linux-gnu/grilo-0.2/
	cp -f libgrlarteplus7.so $(DESTDIR)/usr/lib/x86_64-linux-gnu/grilo-0.2/

