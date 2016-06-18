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

Grl.Media construct_media_container ()
{
#if GRILO_VERSION_3
    return new Grl.Media.container_new ();
#else
    return new Grl.MediaBox ();
#endif
}

Grl.Media construct_media_video ()
{
#if GRILO_VERSION_3
    return new Grl.Media.video_new ();
#else
    return new Grl.MediaVideo ();
#endif
}


class GrlArteSource : Grl.Source
{
    private GLib.List<weak Grl.KeyID ?> supported_keys_;
    
    private ArteParser parsers[1]; /* array of parsers */
    private GLib.Settings settings;
    private GLib.Settings proxy_settings;
    private Language language;
    private VideoQuality quality;
    private UrlExtractor extractor;
    
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
        
        this.extractor = new RTMPStreamUrlExtractor ();
        
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

        parsers[0] = new ArteRSSParser ();
    }

    public GrlArteSource ()
    {
        source_id = "grl-arteplus7";
        source_name = "Arte+7";
        source_desc = "Arte+7 video provider";
#if GRILO_VERSION_3
        supported_media = Grl.SupportedMedia.VIDEO;
#else
        supported_media = Grl.MediaType.VIDEO;
#endif
        source_tags = {"tv", "net:internet", "country:fr", "country:de"};
        source_icon = new FileIcon(File.new_for_path (ICON));

        supported_keys_ = Grl.MetadataKey.list_new(Grl.MetadataKey.ID,
                Grl.MetadataKey.TITLE,
                Grl.MetadataKey.URL,
                Grl.MetadataKey.THUMBNAIL,
                Grl.MetadataKey.DESCRIPTION,
                Grl.MetadataKey.DURATION,
                Grl.MetadataKey.SITE);

        // TODO
        // CREATION_DATE, PUBLICATION_DATE
        // EXTERNAL_URL
        // LICENSE
    }

    private void set_language (Language new_language)
    {
        language = new_language;
        if (!settings.set_enum ("language", (int) new_language)) {
            GLib.warning ("Storing the language setting failed.");
        }
    }

    private void set_quality (VideoQuality new_quality)
    {
        quality = new_quality;
        if (!settings.set_enum ("quality", (int) new_quality)) {
            GLib.warning ("Storing the quality setting failed.");
        }
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
    }

    // TODO '?' is missing in the vapi, fixed in 0.3
    public override unowned GLib.List<weak Grl.KeyID?> supported_keys ()
    {
        return supported_keys_;
    }

    private void browse_language (Grl.SourceBrowseSpec bs)
    {
        Grl.Media lang_box = construct_media_container ();
        lang_box.set_title (_("French"));
        lang_box.set_id (BOX_LANGUAGE_FRENCH);
        bs.callback (bs.source, bs.operation_id, lang_box, 1, null);
        lang_box = construct_media_container ();
        lang_box.set_title (_("German"));
        lang_box.set_id (BOX_LANGUAGE_GERMAN);
        bs.callback (bs.source, bs.operation_id, lang_box, 0, null);
    }

    private void browse_quality (Grl.SourceBrowseSpec bs)
    {
        Grl.Media q_box = construct_media_container ();
        q_box.set_title (_("Low quality (220p)"));
        q_box.set_id (BOX_QUALITY_LOW);
        bs.callback (bs.source, bs.operation_id, q_box, 3, null);

        q_box = construct_media_container ();
        q_box.set_title (_("Medium quality (400p)"));
        q_box.set_id (BOX_QUALITY_MEDIUM);
        bs.callback (bs.source, bs.operation_id, q_box, 2, null);

        q_box = construct_media_container ();
        q_box.set_title (_("High quality (400p, better encoding)"));
        q_box.set_id (BOX_QUALITY_HIGH);
        bs.callback (bs.source, bs.operation_id, q_box, 1, null);

        q_box = construct_media_container ();
        q_box.set_title (_("Best quality (720p)"));
        q_box.set_id (BOX_QUALITY_HD);
        bs.callback (bs.source, bs.operation_id, q_box, 0, null);
    }

    public override void browse (Grl.SourceBrowseSpec bs)
    {
        debug ("Browse streams...");

        switch (bs.container.get_id ()) {
        case null:
            if (language == Language.UNKNOWN || quality == VideoQuality.UNKNOWN) {
                browse_language (bs);
            } else {
                refresh_rss_feed (bs);
            }
            break;
        case BOX_SETTINGS_RESET:
            browse_language (bs);
            break;
        case BOX_LANGUAGE_FRENCH:
            set_language (Language.FRENCH);
            browse_quality (bs);
            break;
        case BOX_LANGUAGE_GERMAN:
            set_language (Language.GERMAN);
            browse_quality (bs);
            break;
        case BOX_QUALITY_LOW:
            set_quality (VideoQuality.LOW);
            refresh_rss_feed (bs);
            break;
        case BOX_QUALITY_MEDIUM:
            set_quality (VideoQuality.MEDIUM);
            refresh_rss_feed (bs);
            break;
        case BOX_QUALITY_HIGH:
            set_quality (VideoQuality.HIGH);
            refresh_rss_feed (bs);
            break;
        case BOX_QUALITY_HD:
            set_quality (VideoQuality.HD);
            refresh_rss_feed (bs);
            break;
        }
    }

    /*public override void search (Grl.SourceSearchSpec ss)
    {
        debug ("Search...");
        // TODO implement
        ss.callback(ss.source, ss.operation_id, null, 0, null);
        debug ("Search finished");
    }
    */

    private void refresh_rss_feed (Grl.SourceBrowseSpec bs)
    {
        uint parse_errors = 0;
        uint network_errors = 0;
        uint error_threshold = 0;

        debug ("Refreshing Video Feed...");

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
                    // Create the "Change language" box
                    Grl.Media media = construct_media_container ();
                    media.set_id (BOX_SETTINGS_RESET);
                    media.set_title (_("↻ Change settings"));
                    bs.callback (bs.source, bs.operation_id, media, remaining + 1, null);
                    foreach (Video v in videos) {
                        media = construct_media_video ();
                        media.set_title (v.title);
                        if (v.duration > 0) {
                            media.set_duration (v.duration);
                        }
                        media.set_site (v.page_url);
                        media.set_description(v.desc);

                        if (quality == VideoQuality.LOW) {
                            media.set_url(v.urls.get("300"));
                        } else if (quality == VideoQuality.MEDIUM) {
                            media.set_url(v.urls.get("800"));
                        } else if (quality == VideoQuality.HIGH) {
                            media.set_url(v.urls.get("1500"));
                        } else {
                            media.set_url(v.urls.get("2200"));
                        }

                        if (media.get_url () == null) {
                            GLib.warning ("Fallback to the old extraction method for %s.",
                                          media.get_title ());
                            try {
                                media.set_url(get_stream_url(v.page_url, quality, language));
                            } catch (ExtractionError e) {
                                GLib.warning ("No playback url found for %s, skipping.",
                                              media.get_title ());
                                remaining -= 1;
                                continue;
                            }
                        }

                        // TODO dates
                        media.set_thumbnail (v.image_url);

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

            // leave the loop if we got enought videos
            if (parse_errors < error_threshold && network_errors < error_threshold)
                break;
        }
        debug ("Browse streams finished.");
    }
    
    private string get_stream_url (string page_url, VideoQuality q, Language lang)
        throws ExtractionError
    {
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

