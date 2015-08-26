/*
 * Totem Arte Plugin allows you to watch streams from arte.tv
 * Copyright (C) 2015 Simon Wenner <simon@wenner.ch>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA.
 *
 * The Totem Arte Plugin project hereby grants permission for non-GPL compatible
 * GStreamer plugins to be used and distributed together with GStreamer, Totem
 * and Totem Arte Plugin. This permission is above and beyond the permissions
 * granted by the GPL license by which Totem Arte Plugin is covered.
 * If you modify this code, you may extend this exception to your version of the
 * code, but you are not obligated to do so. If you do not wish to do so,
 * delete this exception statement from your version.
 *
 */

using Grl;
using GLib;

class GrlArteSource : Grl.Source
{
    private GLib.List<weak Grl.KeyID ?> supported_keys_;
    private GLib.List<weak Grl.KeyID ?> slow_keys_;
    
    private ArteParser parsers[2]; /* array of parsers */
    private GLib.Settings settings;
    private GLib.Settings proxy_settings;
    private Cache cache; /* image thumbnail cache */
    private Language language;
    private VideoQuality quality;
    private ConnectionStatus cs;
    
    construct {
        /* Debug log handling */
#if DEBUG_MESSAGES
        GLib.Log.set_handler ("GrlArte", GLib.LogLevelFlags.LEVEL_DEBUG,
            (domain, levels, msg) => {
                stdout.printf ("%s-DEBUG: %s\n", domain, msg);
            });
#endif
        this.settings = new GLib.Settings (DCONF_ID);
        this.proxy_settings = new GLib.Settings (DCONF_HTTP_PROXY);
        load_properties ();
        
        this.cs = new ConnectionStatus ();
        
        /* Generate the user-agent */
        TimeVal tv = TimeVal ();
        tv.get_current_time ();
        /* First, we need to compute the number of weeks since Epoch */
        int weeks = (int) tv.tv_sec / ( 60 * 60 * 24 * 7 );
        /* We know there is a new Firefox release each 6 weeks.
           And we know Firefox 11.0 was released the 03/13/2012, which
           corresponds to 2201 weeks after Epoch.
           We add a 3 weeks margin and then we can compute the version number! */
        int version = 11 + (weeks - (2201 + 3)) / 6;
        USER_AGENT = USER_AGENT_TMPL.printf(version, version);
        debug (USER_AGENT);
        
        cache = new Cache (Environment.get_user_cache_dir ()
            + CACHE_PATH_SUFFIX);
        parsers[0] = new ArteJSONParser ();
        parsers[1] = new ArteRSSParser ();
    }

    public GrlArteSource ()
    {
        source_id = "grl-arteplus7";
        source_name = "Arte+7";
        source_desc = "Arte+7 video provider";
        supported_media = Grl.MediaType.VIDEO;
        // TODO source_icon

        supported_keys_ = Grl.MetadataKey.list_new(Grl.MetadataKey.ID,
                Grl.MetadataKey.TITLE,
                Grl.MetadataKey.URL,
                Grl.MetadataKey.THUMBNAIL,
                Grl.MetadataKey.DESCRIPTION,
                Grl.MetadataKey.SITE);
                
        slow_keys_ = Grl.MetadataKey.list_new(
                Grl.MetadataKey.URL,
                Grl.MetadataKey.THUMBNAIL);

        // TODO
        // CREATION_DATE, PUBLICATION_DATE
        // EXTERNAL_URL
        // LICENSE
    }
    
    /* loads properties from dconf */
    private void load_properties ()
    {
        string parsed_proxy_uri = "";
        int proxy_port;

        quality = (VideoQuality) settings.get_enum ("quality");
        language = (Language) settings.get_enum ("language");
        use_proxy = proxy_settings.get_boolean ("enabled");

        if (use_proxy) {
            parsed_proxy_uri = proxy_settings.get_string ("host");
            proxy_port = proxy_settings.get_int ("port");
            if (parsed_proxy_uri == "") {
                use_proxy = false; /* necessary to prevent a crash in this case */
            } else {
                proxy_uri = new Soup.URI ("http://" + parsed_proxy_uri + ":" + proxy_port.to_string());
                debug ("Using proxy: %s", proxy_uri.to_string (false));
                proxy_username = proxy_settings.get_string ("authentication-user");
                proxy_password = proxy_settings.get_string ("authentication-password");
            }
        }

        if (language == Language.UNKNOWN) { /* Try to guess user prefer language at first run */
            var env_lang = Environment.get_variable ("LANG");
            if (env_lang != null && env_lang.substring (0,2) == "de") {
                language = Language.GERMAN;
            } else {
                language = Language.FRENCH; /* Otherwise, French is the default language */
            }
            if (!settings.set_enum ("language", (int) language))
                GLib.warning ("Storing the language setting failed.");
        }

        if (quality == VideoQuality.UNKNOWN) {
            quality = VideoQuality.HD; // default quality
            if (!settings.set_enum ("quality", (int) quality))
                GLib.warning ("Storing the quality setting failed.");
        }
    }

    // TODO '?' is missing in the vapi
    public override unowned GLib.List<weak Grl.KeyID?> supported_keys ()
    {
        return supported_keys_;
    }

    public override unowned GLib.List<weak Grl.KeyID?> slow_keys ()
    {
        return slow_keys_;
    }

    private void browse_language (Grl.SourceBrowseSpec bs)
    {
        Grl.Media lang_box = new Grl.MediaBox ();
        lang_box.set_title (_("French"));
        lang_box.set_id (BOX_LANGUAGE_FRENCH);
        bs.callback (bs.source, bs.operation_id, lang_box, 1, null);
        lang_box = new Grl.MediaBox ();
        lang_box.set_title (_("German"));
        lang_box.set_id (BOX_LANGUAGE_GERMAN);
        bs.callback (bs.source, bs.operation_id, lang_box, 0, null);
    }

    public override void browse (Grl.SourceBrowseSpec bs)
    {
        debug ("Browse streams...");

        switch (bs.container.get_id ()) {
        case null:
            browse_language (bs);
            break;
        case BOX_LANGUAGE_FRENCH:
            language = Language.FRENCH;
            refresh_rss_feed (bs);
            break;
        case BOX_LANGUAGE_GERMAN:
            language = Language.GERMAN;
            refresh_rss_feed (bs);
            break;
        }
    }

    public override void search (Grl.SourceSearchSpec ss)
    {
        debug ("Search...");
        // TODO implement
        ss.callback(ss.source, ss.operation_id, null, 0, null);
        debug ("Search finished");
    }

    public override void resolve (Grl.SourceResolveSpec rs)
    {
        debug ("Resolve metadata...");
        // FIXME k's type should be Grl.KeyID not void*
        foreach (var k in rs.keys) {
            if ((Grl.KeyID)k == Grl.MetadataKey.URL) {
                debug ("Resolve URL...");
                // get the stream url
                string stream_url = null;
                try {
                    string page_url = rs.media.get_site ();
                    stream_url = get_stream_url (page_url, quality, language);
                    rs.media.set_url (stream_url);
                } catch (ExtractionError e) {
                    debug ("Stream URL extraction failed.");
                    // TODO error handling (pop-up?)
                }
            }
            
            // TODO resolve thumbnail data here too?
        }
        
        rs.callback(rs.source, rs.operation_id, rs.media, null);
        debug ("Resolve metadata finished");
    }

    private void refresh_rss_feed (Grl.SourceBrowseSpec bs)
    {
        if (!this.cs.is_online) {
            // display offline message
            // TODO tree_view.display_message (_("No internet connection."));

            // invalidate all existing videos
            // TODO tree_view.clear ();

            debug ("Browse streams failed.");
        }

        uint parse_errors = 0;
        uint network_errors = 0;
        uint error_threshold = 0;

        //search_entry.set_sensitive (false);

        debug ("Refreshing Video Feed...");

        /* display loading message */
        // TODO tree_view.display_message (_("Loading..."));

        /* remove all existing videos */
        // TODO tree_view.clear ();

        // download and parse feeds
        // try parsers one by one until enough videos are extracted
        for (int i=0; i<parsers.length; i++)
        {
            var p = parsers[i];
            p.reset ();
            parse_errors = 0;
            network_errors = 0;
            error_threshold = p.get_error_threshold ();

            // get all data chunks of a parser
            while (p.has_data)
            {
                try {
                    // parse
                    unowned GLib.SList<Video> videos = p.parse (language);

                    uint remaining = videos.length();
                    foreach (Video v in videos) {
                        Grl.Media media = new Grl.MediaVideo ();
                        media.set_title (v.title);
                        media.set_site (v.page_url);
                        media.set_description(v.desc);

                        // Uncomment this line to make Totem work (slowly) for now
                        //media.set_url(get_stream_url(v.page_url, quality, language));

                        // TODO dates
                        //media.set_source ("arte source");
                        
                        // get image url
                        if (v.image_url == null) {
                            cache.get_video (ref v);
                        }

                        // thumnails without our cache (totem has a cache too)
                        media.set_thumbnail (v.image_url);

/* TODO should we use our cache?
                        string image_url = v.image_url;//.normalize();
                        Gdk.Pixbuf pb = cache.load_pixbuf (image_url);
                        
                        // FIXME this case never happens because of the default thumb
                        if (true || pb == null) {
                            debug ("image missing.\n");
                            pb = cache.download_pixbuf (v.image_url, v.publication_date);
                        }
                        
                        if (pb != null) {
                            debug ("image file added.\n");
                            media.set_thumbnail_binary(pb.get_pixels(), pb.get_byte_length());
                        }
*/
                        bs.callback (bs.source, bs.operation_id, media, remaining, null);
                        remaining -= 1;
                    }
                    bs.callback (bs.source, bs.operation_id, null, 0, null);

                } catch (MarkupError e) {
                    parse_errors++;
                    GLib.critical ("XML Parse Error: %s", e.message);
                } catch (IOError e) {
                    network_errors++;
                    GLib.critical ("Network problems: %s", e.message);
                }

                // request the next chunk of data
                p.advance ();

                // leave the loop if we got too many errors
                if (parse_errors >= error_threshold || network_errors >= error_threshold)
                    break;
            }

            // the RSS feeds have duplicates
            if (p.has_duplicates ()) {
                // TODO tree_view.check_and_remove_duplicates ();
            }

            // try to recover if we failed to parse some thumbnails URI
            // TODO tree_view.check_and_download_missing_image_urls ();

            // leave the loop if we got enought videos
            if (parse_errors < error_threshold && network_errors < error_threshold)
                break;
        }

        /* while parsing we only used images from the cache */
        // TODO tree_view.check_and_download_missing_thumbnails ();

        // TODO debug ("Video Feed loaded, video count: %u", tree_view.get_size ());

        // show user visible error messages
        if (parse_errors > error_threshold)
        {
            //TODO t.action_error (_("Markup Parser Error"),
            //        _("Sorry, the plugin could not parse the Arte video feed."));
        } else if (network_errors > error_threshold) {
            //TODO t.action_error (_("Network problem"),
            //        _("Sorry, the plugin could not download the Arte video feed.\nPlease verify your network settings and (if any) your proxy settings."));
        }

        //search_entry.set_sensitive (true);
        //search_entry.grab_focus ();

        debug ("Browse streams finished.");
    }
    
    private string get_stream_url (string page_url, VideoQuality q, Language lang)
        throws ExtractionError
    {
        var extractor = new RTMPStreamUrlExtractor ();
        return extractor.get_url (q, lang, page_url);
    }
}

public bool grl_arteplus7_plugin_init (Grl.Registry registry, Grl.Plugin plugin, 
        GLib.List configs)
{
    GrlArteSource source = new GrlArteSource();

    try {
        registry.register_source (plugin, source);
    } catch (GLib.Error e) {
        GLib.message ("ArtePlus7 register source failed: %s", e.message);
        return false;
    }

    GLib.message ("ArtePlus7 loaded!");
    return true;
}

