all:
	valac -C arteplus7.vala --thread --pkg libsoup-2.4 --pkg gee-1.0 --pkg totem --vapidir=./deps
	gcc -shared -fPIC `pkg-config --cflags --libs glib-2.0 libsoup-2.4 gee-1.0 gtk+-2.0 totem-plparser` -o libarteplus7.so arteplus7.c -I./deps

install:
	mkdir -p ~/.local/share/totem/plugins/
	cp -f arteplus7.totem-plugin ~/.local/share/totem/plugins/
	cp -f libarteplus7.so ~/.local/share/totem/plugins/

uninstall:
	rm ~/.local/share/totem/plugins/arteplus7.totem-plugin
	rm ~/.local/share/totem/plugins/libarteplus7.so

clean:
	rm arteplus7.c libarteplus7.so
