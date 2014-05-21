using Grl;
using GLib;

class ArtePlugin
{
}

public bool grl_arteplus7_plugin_init (Grl.Registry registry, Grl.Plugin plugin, 
        GLib.List configs)
{
    GLib.message("ArtePlus7 loaded!");
    return true;
}

/*
gboolean
grl_foo_plugin_init (GrlRegistry *registry,
                     GrlPlugin *plugin,
                     GList *configs)
{
    gchar *api_key;
    GrlConfig *config;

    config = GRL_CONFIG (configs->data);

    api_key = grl_config_get_api_key (config);
    if (!api_key) {
    GRL_INFO ("Missing API Key, cannot load plugin");
    return FALSE;
    }

    GrlFooSource *source = grl_foo_source_new (api_key);
    grl_registry_register_source (registry,
                                plugin,
                                GRL_SOURCE (source),
                                NULL);
    g_free (api_key);

    g_message("Arteplus7 loaded!");
    return TRUE;
}
*/
