#include <grilo.h>

extern gboolean
grl_arteplus7_plugin_init (GrlRegistry *registry,
        GrlPlugin *plugin,
        GList *configs);

GRL_PLUGIN_REGISTER (grl_arteplus7_plugin_init, NULL, "grl-arteplus7");
