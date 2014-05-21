using Grl;
using GLib;

class GrlArteSource : Grl.Source
{
    private GLib.List<weak Grl.KeyID ?> keys;

    public GrlArteSource ()
    {
        source_id = "grl-arteplus7";
        source_name = "Arte+7";
        source_desc = "Arte+7 media provider";

        /* TODO broken?
        keys = Grl.MetadataKey.list_new(Grl.MetadataKey.ID,
                Grl.MetadataKey.TITLE,
                Grl.MetadataKey.URL,
                Grl.MetadataKey.THUMBNAIL);
        */

        keys = new GLib.List<weak Grl.KeyID ?>();
        keys.append(Grl.MetadataKey.ID);
        keys.append(Grl.MetadataKey.TITLE);
        keys.append(Grl.MetadataKey.URL);
        keys.append(Grl.MetadataKey.THUMBNAIL);
        // FIXME keys.append(Grl.MetadataKey.INVALID); // BGO #730548
        // Missing too: GRL_METADATA_KEY_SIZE, GRL_METADATA_KEY_TITLE_FROM_FILENAME
    }

    // TODO '?' is missing in the vapi
    public override unowned GLib.List<weak Grl.KeyID?> supported_keys ()
    {
        return keys;
    }

    // TODO are some operations slow?
    //public override unowned GLib.List<weak Grl.KeyID?> slow_keys ()

    // TODO ? missing in the vapi
    public override void browse (Grl.Media? container, GLib.List<Grl.KeyID?> keys,
            Grl.OperationOptions options, Grl.SourceResultCb callback)
    {
        // TODO
    }

    // TODO ? missing in the vapi
    public override void search (string text, GLib.List<Grl.KeyID?> keys,
            Grl.OperationOptions options, Grl.SourceResultCb callback)
    {
        // TODO
    }
}

public bool grl_arteplus7_plugin_init (Grl.Registry registry, Grl.Plugin plugin, 
        GLib.List configs)
{
    GrlArteSource source = new GrlArteSource();

    try {
        registry.register_source (plugin, source);
    } catch (GLib.Error e) {
        GLib.message("ArtePlus7 register source failed: %s", e.message);
        return false;
    }

    GLib.message("ArtePlus7 loaded!");
    return true;
}

