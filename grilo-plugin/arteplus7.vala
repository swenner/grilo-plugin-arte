using Grl;

class ArtePlugin
{
}

//[ModuleInit]
public bool grl_arteplus7_plugin_init (Grl.Registry registry, Grl.Plugin plugin, 
        GLib.List configs)
{
    GLib.message("ArtePlus7 loaded!");
    return true;
}

public Grl.PluginDescriptor arteplus7_descr = new Grl.PluginDescriptor () {
    plugin_id = "grl-arteplus7",
    plugin_init = (GLib.Callback) grl_arteplus7_plugin_init,
    plugin_deinit = null,
    module = null
};

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
  return TRUE;
}

GRL_PLUGIN_REGISTER (grl_foo_plugin_init, NULL, "grl-foo");
*/
