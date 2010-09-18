/*
 * Totem Arte Plugin allows you to watch streams from arte.tv
 * Copyright (C) 2009, 2010 Simon Wenner <simon@wenner.ch>
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

using GLib;
using Soup;
using Totem;
using Gtk;
using GConf;

public enum VideoQuality
{
    UNKNOWN = 0,
    WMV_MQ,
    WMV_HQ,
    FLV_MQ,
    FLV_HQ
}

public enum Language
{
    UNKNOWN = 0,
    FRENCH,
    GERMAN
}

public const string USER_AGENT =
    "Mozilla/5.0 (X11; U; Linux x86_64; fr; rv:1.9.2.10) Gecko/20100915 Firefox/3.6.10";
public const string GCONF_ROOT = "/apps/totem/plugins/arteplus7";
public const string GCONF_HTTP_PROXY = "/system/http_proxy";
public const string CACHE_PATH_SUFFIX = "/totem/plugins/arteplus7/";
public const int THUMBNAIL_WIDTH = 160;
public const string DEFAULT_THUMBNAIL = "/usr/share/totem/plugins/arteplus7/arteplus7-default.png";
public bool use_proxy = false;
public Soup.URI proxy_uri;
public string proxy_username;
public string proxy_password;

public static Soup.SessionAsync create_session ()
{
    Soup.SessionAsync session;
    if (use_proxy) {
        session = new Soup.SessionAsync.with_options (
                Soup.SESSION_USER_AGENT, USER_AGENT,
                Soup.SESSION_PROXY_URI, proxy_uri, null);

        session.authenticate.connect((sess, msg, auth, retrying) => {
            /* watch if authentication is needed */
            if (!retrying) {
                auth.authenticate (proxy_username, proxy_password);
            } else {
                GLib.warning ("Proxy authentication failed!\n");
            }
        });
    } else {
        session = new Soup.SessionAsync.with_options (
                Soup.SESSION_USER_AGENT, USER_AGENT, null);
    }
    session.timeout = 15; /* 15 seconds timeout, until we give up and show an error message */
    return session;
}

public class Video : GLib.Object
{
    public string title = null;
    public string page_url = null;
    public string image_url = null;
    public string desc = null;
    public GLib.TimeVal publication_date;
    public GLib.TimeVal offline_date;

    public Video()
    {
         publication_date.tv_sec = 0;
         offline_date.tv_sec = 0;
    }

    public void print ()
    {
        stdout.printf ("Video: %s: %s, %s, %s\n", title,
                publication_date.to_iso8601 (),
                offline_date.to_iso8601 (), page_url);
    }

    public string get_stream_uri (VideoQuality q, Language lang)
        throws ExtractionError
    {
        var extractor = new RTMPStreamUrlExtractor ();
        return extractor.get_url (q, lang, page_url);
    }
}

public abstract class ArteParser : GLib.Object
{
    public string xml_fr;
    public string xml_de;
    public GLib.SList<Video> videos;

    private const MarkupParser parser = {
            open_tag,
            close_tag,
            process_text,
            null,
            null
        };

    public ArteParser ()
    {
        videos = new GLib.SList<Video>();
    }

    public virtual void reset () {}
    public virtual void set_page (int page) {}

    public void parse (Language lang) throws MarkupError, IOError
    {
        Soup.Message msg;
        if (lang == Language.GERMAN) {
            msg = new Soup.Message ("GET", xml_de);
        } else {
            msg = new Soup.Message ("GET", xml_fr);
        }

        Soup.SessionAsync session = create_session ();

        session.send_message (msg);

        if (msg.status_code != Soup.KnownStatusCode.OK) {
            throw new IOError.HOST_NOT_FOUND ("plus7.arte.tv could not be accessed.");
        }

        var context = new MarkupParseContext (parser,
                MarkupParseFlags.TREAT_CDATA_AS_TEXT, this, null);
        context.parse (msg.response_body.flatten ().data,
                (ssize_t) msg.response_body.length);
        context.end_parse ();
    }

    protected virtual void open_tag (MarkupParseContext ctx,
            string elem,
            string[] attribute_names,
            string[] attribute_values) throws MarkupError {}

    protected virtual void close_tag (MarkupParseContext ctx,
            string elem) throws MarkupError {}

    protected virtual void process_text (MarkupParseContext ctx,
            string text,
            size_t text_len) throws MarkupError {}
}

public class ArteRSSParser : ArteParser
{
    private Video current_video = null;
    private string current_data = null;

    public ArteRSSParser ()
    {
        /* Parses the official RSS feed */
        xml_fr =
            "http://videos.arte.tv/fr/do_delegate/videos/arte7/index-3188666,view,rss.xml";
        xml_de =
            "http://videos.arte.tv/de/do_delegate/videos/arte7/index-3188666,view,rss.xml";
    }

    private override void open_tag (MarkupParseContext ctx,
            string elem,
            string[] attribute_names,
            string[] attribute_values) throws MarkupError
    {
        switch (elem) {
            case "item":
                current_video = new Video();
                break;
            default:
                current_data = elem;
                break;
        }
    }

    private override void close_tag (MarkupParseContext ctx,
            string elem) throws MarkupError
    {
        switch (elem) {
            case "item":
                if (current_video != null) {
                    videos.append (current_video);
                    current_video = null;
                }
                break;
            default:
                current_data = null;
                break;
        }
    }

    private override void process_text (MarkupParseContext ctx,
            string text,
            size_t text_len) throws MarkupError
    {
        if (current_video != null) {
            switch (current_data) {
                case "title":
                    current_video.title = text;
                    break;
                case "link":
                    current_video.page_url = text;
                    break;
                case "description":
                    current_video.desc = text;
                    break;
                case "pubDate":
                    current_video.publication_date.from_iso8601 (text);
                    break;
            }
        }
    }
}

public class ArteXMLParser : ArteParser
{
    private Video current_video = null;
    private string current_data = null;
    public int page = 1;
    /* Parses the XML feed of the Flash preview plugin */
    private const string xml_tmpl =
        "http://videos.arte.tv/%s/do_delegate/videos/arte7/index-3211552,view,asXml.xml?hash=%s////%d/10/";

    public ArteXMLParser ()
    {
        reset ();
    }

    public override void reset ()
    {
        videos = new GLib.SList<Video>();
        this.page = 1;
        xml_fr = xml_tmpl.printf ("fr", "fr", page);
        xml_de = xml_tmpl.printf ("de", "de", page);
    }

    public override void set_page (int page)
    {
        this.page = page;
        xml_fr = xml_tmpl.printf ("fr", "fr", page);
        xml_de = xml_tmpl.printf ("de", "de", page);
    }

    private override void open_tag (MarkupParseContext ctx,
            string elem,
            string[] attribute_names,
            string[] attribute_values) throws MarkupError
    {
        switch (elem) {
            case "video":
                current_video = new Video();
                break;
            default:
                current_data = elem;
                break;
        }
    }

    private override void close_tag (MarkupParseContext ctx,
            string elem) throws MarkupError
    {
        switch (elem) {
            case "video":
                if (current_video != null) {
                    videos.prepend (current_video);
                    current_video = null;
                }
                break;
            default:
                current_data = null;
                break;
        }
    }

    private override void process_text (MarkupParseContext ctx,
            string text,
            size_t text_len) throws MarkupError
    {
        if (current_video != null) {
            switch (current_data) {
                case "title":
                    current_video.title = text;
                    break;
                case "targetUrl":
                    current_video.page_url = "http://videos.arte.tv" + text;
                    break;
                case "imageUrl":
                    current_video.image_url = "http://videos.arte.tv" + text;
                    break;
                case "teaserText":
                    current_video.desc = text;
                    break;
                case "startDate":
                    current_video.publication_date.from_iso8601 (text);
                    break;
                case "endDate":
                    current_video.offline_date.from_iso8601 (text);
                    break;
            }
        }
    }
}

class ArtePlugin : Totem.Plugin
{
    private Totem.Object t;
    private Gtk.Entry search_entry; /* search field with buttons inside */
    private Gtk.TreeView tree_view; /* list of movie thumbnails */
    private ArteParser p;
    private Cache cache; /* image thumbnail cache */
    private Language language = Language.FRENCH;
    private VideoQuality quality = VideoQuality.WMV_HQ;
    private GLib.StaticMutex tree_lock;
    private bool use_fallback_feed = false;
    private string? filter = null;

    /* TreeView column names */
    private enum Col {
        IMAGE,
        NAME,
        DESCRIPTION,
        VIDEO_OBJECT,
        N
    }

    public override bool activate (Totem.Object totem) throws GLib.Error
    {
        t = totem;
        load_properties ();
        cache = new Cache (Environment.get_user_cache_dir ()
             + CACHE_PATH_SUFFIX);
        p = new ArteXMLParser ();
        tree_view = new Gtk.TreeView ();

        var renderer = new Totem.CellRendererVideo (false);
        tree_view.insert_column_with_attributes (0, "", renderer,
                "thumbnail", Col.IMAGE,
                "title", Col.NAME, null);
        tree_view.set_headers_visible (false);
        tree_view.set_tooltip_column (Col.DESCRIPTION);
        tree_view.row_activated.connect (callback_select_video_in_tree_view);

        var scroll_win = new Gtk.ScrolledWindow (null, null);
        scroll_win.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
        scroll_win.set_shadow_type (ShadowType.IN);
        scroll_win.add (tree_view);

        /* add a search entry with a refresh and a cleanup icon */
        search_entry = new Gtk.Entry ();
        search_entry.set_icon_from_stock (Gtk.EntryIconPosition.PRIMARY,
                Gtk.STOCK_REFRESH);
        search_entry.set_icon_tooltip_text (Gtk.EntryIconPosition.PRIMARY,
                _("Reload feed"));
        search_entry.set_icon_from_stock (Gtk.EntryIconPosition.SECONDARY,
                Gtk.STOCK_CLEAR);
        search_entry.set_icon_tooltip_text (Gtk.EntryIconPosition.SECONDARY,
                _("Clear the search text"));
        search_entry.set_icon_sensitive (Gtk.EntryIconPosition.SECONDARY, false);
        /* search as you type */
        search_entry.changed.connect ((widget) => {
            Gtk.Entry entry = (Gtk.Entry) widget;
            entry.set_icon_sensitive (Gtk.EntryIconPosition.SECONDARY,
                    (entry.get_text () != ""));

            filter = entry.get_text ().down ();
            var model = (Gtk.TreeModelFilter) tree_view.get_model ();
            model.refilter ();
        });
        /* set focus to the first video on return */
        search_entry.activate.connect ((entry) => {
            tree_view.grab_focus ();
        });
        /* cleanup or refresh on click */
        search_entry.icon_press.connect ((entry, position, event) => {
            if (position == Gtk.EntryIconPosition.PRIMARY)
                callback_refresh_rss_feed (entry);
            else
                entry.set_text ("");
        });

        var main_box = new Gtk.VBox (false, 4);
        main_box.pack_start (search_entry, false, false, 0);
        main_box.pack_start (scroll_win, true, true, 0);
        main_box.show_all ();

        totem.add_sidebar_page ("arte", _("Arte+7"), main_box);
        GLib.Idle.add (refresh_rss_feed);
        /* delete all files in the cache that are older than 8 days
         * with probability 1/5 at every startup */
        if (GLib.Random.next_int () % 5 == 0) {
            GLib.Idle.add (() => {
                cache.delete_cruft (8);
                return false;
            });
        }

        /* Refresh the feed on pressing 'F5' */
        var window = t.get_main_window ();
        window.key_press_event.connect (callback_F5_pressed);

        return true;
    }

    public override void deactivate (Totem.Object totem)
    {
        /* Remove the 'F5' key event handler */
        var window = t.get_main_window ();
        window.key_press_event.disconnect (callback_F5_pressed);
        /* Remove the plugin tab */
        totem.remove_sidebar_page ("arte");
    }

    public override Gtk.Widget create_configure_dialog ()
    {
        var langs = new Gtk.ComboBox.text ();
        langs.append_text (_("German"));
        langs.append_text (_("French"));
        if (language == Language.GERMAN)
            langs.set_active (0);
        else
            langs.set_active (1);
        langs.changed.connect (callback_language_changed);

        var quali_radio_medium = new Gtk.RadioButton.with_mnemonic (null, _("_medium"));
        var quali_radio_high = new Gtk.RadioButton.with_mnemonic_from_widget (
                quali_radio_medium, _("_high"));
        if (quality == VideoQuality.WMV_MQ)
            quali_radio_medium.set_active (true);
        else
            quali_radio_high.set_active (true);

        quali_radio_medium.toggled.connect (callback_quality_toggled);

        var langs_label = new Gtk.Label (_("Language:"));
        var langs_box = new HBox (false, 20);
        langs_box.pack_start (langs_label, false, true, 0);
        langs_box.pack_start (langs, true, true, 0);

        var quali_label = new Gtk.Label (_("Video quality:"));
        var quali_box = new HBox (false, 20);
        quali_box.pack_start (quali_label, false, true, 0);
        quali_box.pack_start (quali_radio_medium, false, true, 0);
        quali_box.pack_start (quali_radio_high, true, true, 0);

        var dialog = new Dialog.with_buttons (_("Arte+7 Plugin Properties"),
                null, Gtk.DialogFlags.MODAL | Gtk.DialogFlags.DESTROY_WITH_PARENT,
                Gtk.STOCK_CLOSE, Gtk.ResponseType.CLOSE, null);
        dialog.has_separator = false;
        dialog.resizable = false;
        dialog.border_width = 5;
        dialog.vbox.spacing = 10;
        dialog.vbox.pack_start (langs_box, false, true, 0);
        dialog.vbox.pack_start (quali_box, false, true, 0);
        dialog.show_all ();

        dialog.response.connect ((source, response_id) => {
            if (response_id == Gtk.ResponseType.CLOSE)
                dialog.destroy ();
        });

        return dialog;
    }

    public bool refresh_rss_feed ()
    {
        if (!tree_lock.trylock ())
            return false;

        search_entry.set_sensitive (false);

        TreeIter iter;

        /* display loading message */
        var tmp_ls = new ListStore (3, typeof (Gdk.Pixbuf),
                typeof (string), typeof (string));
        tmp_ls.prepend (out iter);
        tmp_ls.set (iter,
                Col.IMAGE, null,
                Col.NAME, _("Loading..."),
                Col.DESCRIPTION, null, -1);
        tree_view.set_model (tmp_ls);

        /* download and parse */
        try {
            p.reset ();
            for (int i=1; i<10; i++) {
                p.set_page (i);
                p.parse (language);
                GLib.message ("Fetching page %d: Video count: %u", i, p.videos.length ());
            }
            GLib.message ("Total video count: %u", p.videos.length ());
            /* sort the videos by removal date */
            p.videos.sort ((a, b) => {
                return (int) (((Video) a).offline_date.tv_sec > ((Video) b).offline_date.tv_sec);
            });
        } catch (MarkupError e) {
            GLib.critical ("XML Parse Error: %s", e.message);
            if (!use_fallback_feed) {
                /* The default XML feed parser failed.
                 * Switch to the RSS fallback feed without thumbnails. */
                p = new ArteRSSParser();
                use_fallback_feed = true;
                tree_lock.unlock ();
                /* ... and try again. */
                refresh_rss_feed ();
            } else {
                /* We are screwed! */
                t.action_error (_("Markup Parser Error"),
                    _("Sorry, the plugin could not parse the Arte video feed."));
                tree_lock.unlock ();
            }
            return false;
        } catch (IOError e) {
            /* Network problems */
            t.action_error (_("Network problem"),
                _("Sorry, the plugin could not download the Arte video feed.\nPlease verify your network settings and (if any) your proxy settings."));
            tree_lock.unlock ();
            search_entry.set_sensitive (true);
            return false;
        }

        /* load the video list */
        var listmodel = new ListStore (Col.N, typeof (Gdk.Pixbuf),
                typeof (string), typeof (string), typeof (Video));

        /* save the last move to detect duplicates */
        Video last_video = null;
        int videocount = 0;

        foreach (Video v in p.videos) {
            /* check for duplicates */
            if (last_video != null && v.page_url == last_video.page_url) {
              last_video = v;
              continue;
            }
            last_video = v;
            videocount++;

            listmodel.append (out iter);

            string desc_str;
            /* use the description if available, fallback to the title otherwise */
            if (v.desc != null) {
              desc_str = v.desc;
            } else {
              desc_str = v.title;
            }

            if (v.offline_date.tv_sec > 0) {
                desc_str += "\n";
                var now = GLib.TimeVal ();
                now.get_current_time ();
                double minutes_left = (v.offline_date.tv_sec - now.tv_sec) / 60.0;
                if (minutes_left < 59.0) {
                    if (minutes_left < 1.0)
                        desc_str += _("Less than 1 minute until removal");
                    else
                        desc_str += _("Less than %.0f minutes until removal").printf (minutes_left + 1.0);
                } else if (minutes_left < 60.0 * 24.0) {
                    if (minutes_left <= 60.0)
                        desc_str += _("Less than 1 hour until removal");
                    else
                        desc_str += _("Less than %.0f hours until removal").printf ((minutes_left / 60.0) + 1.0);
                } else if (minutes_left < (60.0 * 24.0) * 2.0) {
                    desc_str += _("1 day until removal");
                } else {
                    desc_str += _("%.0f days until removal").printf (minutes_left / (60.0 * 24.0));
                }
            }

            listmodel.set (iter,
                    Col.IMAGE, cache.load_pixbuf (v.image_url),
                    Col.NAME, v.title,
                    Col.DESCRIPTION, desc_str,
                    Col.VIDEO_OBJECT, v, -1);
        }

        var model_filter = new Gtk.TreeModelFilter (listmodel, null);
        model_filter.set_visible_func (callback_filter_tree);

        tree_view.set_model (model_filter);

        tree_lock.unlock ();
        search_entry.set_sensitive (true);
        search_entry.grab_focus ();
        GLib.message ("Unique video count: %d", videocount);

        /* Download missing thumbnails */
        check_and_download_missing_thumbnails (listmodel);

        return false;
    }

    private bool callback_filter_tree (Gtk.TreeModel model, Gtk.TreeIter iter)
    {
        string title;
        model.get (iter, Col.NAME, out title);
        if (filter == null || title.down ().contains (filter))
            return true;
        else
            return false;
    }

    private void check_and_download_missing_thumbnails (Gtk.ListStore list)
    {
        TreeIter iter;
        Gdk.Pixbuf pb;
        string md5_pb;
        Video v;
        var path = new TreePath.first ();

        string md5_default_pb = Checksum.compute_for_data (ChecksumType.MD5,
                cache.default_thumbnail.get_pixels ());

        for (int i=1; i<=list.length; i++) {
            list.get_iter (out iter, path);
            list.get (iter, Col.IMAGE, out pb);
            md5_pb = Checksum.compute_for_data (ChecksumType.MD5, pb.get_pixels ());
            if (md5_pb == md5_default_pb) {
                list.get (iter, Col.VIDEO_OBJECT, out v);
                if (v.image_url != null) {
                    GLib.message ("Missing thumbnail: %s", v.title); // Debug
                    list.set (iter, Col.IMAGE, cache.download_pixbuf (v.image_url));
                }
            }
            path.next ();
        }
    }

    /* stores properties in gconf */
    private void store_properties ()
    {
        var gc = GConf.Client.get_default ();
        try {
            gc.set_int (GCONF_ROOT + "/quality", (int) quality);
            gc.set_int (GCONF_ROOT + "/language", (int) language);
        } catch (GLib.Error e) {
            GLib.warning ("%s", e.message);
        }
    }

    /* loads properties from gconf */
    private void load_properties ()
    {
        var gc = GConf.Client.get_default ();
        string parsed_proxy_uri = "";
        int proxy_port;
        
        try {
            quality = (VideoQuality) gc.get_int (GCONF_ROOT + "/quality");
            language = (Language) gc.get_int (GCONF_ROOT + "/language");
            use_proxy = gc.get_bool (GCONF_HTTP_PROXY + "/use_http_proxy");
            if (use_proxy) {
                parsed_proxy_uri = gc.get_string (GCONF_HTTP_PROXY + "/host");
                proxy_port = gc.get_int (GCONF_HTTP_PROXY + "/port");
                if (parsed_proxy_uri == "") {
                    use_proxy = false; /* necessary to prevent a crash in this case */
                } else {
                    proxy_uri = new Soup.URI ("http://" + parsed_proxy_uri + ":" + proxy_port.to_string());
                    GLib.message ("Using proxy: %s", proxy_uri.to_string (false));
                    proxy_username = gc.get_string (GCONF_HTTP_PROXY + "/authentication_user");
                    proxy_password = gc.get_string (GCONF_HTTP_PROXY + "/authentication_password");
                }
            }
        } catch (GLib.Error e) {
            GLib.warning ("%s", e.message);
        }
        if (quality == VideoQuality.UNKNOWN) { /* HQ is the default quality */
            quality = VideoQuality.WMV_HQ;
            store_properties ();
        }
        if (language == Language.UNKNOWN) { /* Try to guess user prefer language at first run */
            var env_lang = Environment.get_variable ("LANG");
            if (env_lang != null && env_lang.substring (0,2) == "de") {
                language = Language.GERMAN;
            } else {
                language = Language.FRENCH; /* Otherwise, French is the default language */
            }
            store_properties ();
        }
    }

    private void callback_select_video_in_tree_view (Gtk.TreeView tree_view,
        Gtk.TreePath path,
        Gtk.TreeViewColumn column)
    {
        var model = tree_view.get_model ();

        Gtk.TreeIter iter;
        Video v;

        model.get_iter (out iter, path);
        model.get (iter, Col.VIDEO_OBJECT, out v);

        string uri = null;
        try {
            uri = v.get_stream_uri (quality, language);
        } catch (ExtractionError e) {
            if(e is ExtractionError.STREAM_NOT_READY) {
                /* The video is part of the XML/RSS feed but no stream is available yet */
                t.action_error (_("This video is not available yet"),
                        _("Sorry, the plugin could not find any stream URL.\nIt seems that this video is not available yet, even on the Arte web-player.\n\nPlease retry later."));
            } else if (e is ExtractionError.DOWNLOAD_FAILED) {
                /* Network problems */
                t.action_error (_("Video URL Extraction Error"),
                        _("Sorry, the plugin could not extract a valid stream URL.\nPlease verify your network settings and (if any) your proxy settings."));
            } else {
                /* ExtractionError.EXTRACTION_ERROR or an unspecified error */
                t.action_error (_("Video URL Extraction Error"),
                        _("Sorry, the plugin could not extract a valid stream URL.\nPerhaps this stream is not yet available, you may retry in a few minutes.\n\nBe aware that this service is only available for IPs within Austria, Belgium, Germany, France and Switzerland."));
            }
            return;
        }

        t.add_to_playlist_and_play (uri, v.title, false);
    }

    private void callback_refresh_rss_feed (Gtk.Widget widget)
    {
        use_fallback_feed = false;
        GLib.Idle.add (refresh_rss_feed);
    }

    private void callback_language_changed (Gtk.ComboBox box)
    {
        Language last = language;
        string text = box.get_active_text ();
        if (text == _("German")) {
            language = Language.GERMAN;
        } else {
            language = Language.FRENCH;
        }
        if (last != language) {
            GLib.Idle.add (refresh_rss_feed);
            store_properties ();
        }
    }

    private void callback_quality_toggled (Gtk.ToggleButton button)
    {
        VideoQuality last = quality;
        bool mq_active = button.get_active ();
        if (mq_active) {
            quality = VideoQuality.WMV_MQ;
        } else {
            quality = VideoQuality.WMV_HQ;
        }
        if (last != quality) {
            store_properties ();
        }
    }

    private bool callback_F5_pressed (Gtk.Widget widget, Gdk.EventKey event)
    {
        string key = Gdk.keyval_name (event.keyval);
        if (key == "F5")
        {
            callback_refresh_rss_feed (widget);
        }

        /* propagate the signal to the next handler */
        return false;
    }
}

[ModuleInit]
public GLib.Type register_totem_plugin (GLib.TypeModule module)
{
    return typeof (ArtePlugin);
}
