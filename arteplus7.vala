/*
 * Totem Arte Plugin allows you to watch streams from arte.tv
 * Copyright (C) 2009 Simon Wenner <simon@wenner.ch>
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
 */

using GLib;
using Soup;
using Gee;
using Totem;
using Gtk;

public enum VideoQuality {
    UNKNOWN,
    WMV_MQ,
    WMV_HQ,
    FLV_MQ,
    FLV_HQ
}

public enum Language {
    UNKNOWN,
    FRENCH,
    GERMAN
}

public const string USER_AGENT =
    "Mozilla/5.0 (X11; U; Linux x86_64; de; rv:1.9.1.5) Gecko/20091123 Iceweasel/3.5.5 (like Firefox/3.5.5; Debian-3.5.5-1) ";

public class Video : GLib.Object {
    public string title = null;
    public string link = null;
    public string desc = null;
    public string category = null;
    public GLib.TimeVal pub_date;

    private string mq_stream_fake_uri = null;
    private string hq_stream_fake_uri = null;

    public Video() {
    }

    public void print () {
        stdout.printf ("Video: %s: %s, %s\n", title, pub_date.to_iso8601 (), link);
    }

    public string get_stream_uri (VideoQuality q)
    {
        Soup.SessionAsync session = new Soup.SessionAsync ();
        session.user_agent = USER_AGENT;
        // A bug in the vala bindings:
        //Soup.SessionAsync session = new Soup.SessionAsync.with_options(Soup.SESSION_USER_AGENT, USER_AGENT, null);

        if (mq_stream_fake_uri == null) {
            try {
                extract_fake_stream_uris_from_html (session);
            } catch (RegexError e) {
                GLib.warning ("%s", e.message);
            }
        }

        string stream_uri = "";
        Soup.Message msg;
        if (q == VideoQuality.WMV_HQ) {
            msg = new Soup.Message ("GET", this.hq_stream_fake_uri);
        } else {
            msg = new Soup.Message ("GET", this.mq_stream_fake_uri);
        }
        session.send_message(msg);

        try {
            MatchInfo match;
            var regex = new Regex ("HREF=\"(mms://.*)\"");
            regex.match(msg.response_body.data, 0, out match);
            string res = match.fetch(1);
            if (res != null) {
                stream_uri = res;
            }
        } catch (RegexError e) {
            GLib.warning ("%s", e.message);
        }

        return stream_uri;
    }

    private void extract_fake_stream_uris_from_html (Soup.SessionAsync session)
            throws RegexError
    {
        Soup.Message msg = new Soup.Message ("GET", this.link);
        session.send_message(msg);

        MatchInfo match;
        var regex = new Regex ("\"(http://.*_MQ_[\\w]{2}.wmv)\"");
        regex.match(msg.response_body.data, 0, out match);
        string res = match.fetch(1);
        if (res != null) {
            this.mq_stream_fake_uri = res;
        }
        regex = new Regex ("\"(http://.*_HQ_[\\w]{2}.wmv)\"");
        regex.match(msg.response_body.data, 0, out match);
        res = match.fetch(1);
        if (res != null) {
            this.hq_stream_fake_uri = res;
        }
    }
}

public class ArteParser : GLib.Object {
    private const string rss_fr =
        "http://plus7.arte.tv/fr/1697480,templateId=renderRssFeed,CmPage=1697480,CmStyle=1697478,CmPart=com.arte-tv.streaming.xml";
        //"http://plus7.arte.tv/fr/1698112,templateId=renderCarouselXml,CmPage=1697480,CmPart=com.arte-tv.streaming.xml
    private const string rss_de =
        "http://plus7.arte.tv/de/1697480,templateId=renderRssFeed,CmPage=1697480,CmStyle=1697478,CmPart=com.arte-tv.streaming.xml";
        //"http://plus7.arte.tv/de/1698112,templateId=renderCarouselXml,CmPage=1697480,CmPart=com.arte-tv.streaming.xml"
    private Video current_video = null;
    private string current_data = null;

    public ArrayList<Video> videos;

    public ArteParser () {
        videos = new ArrayList<Video>();
    }

    private void open_tag (MarkupParseContext ctx,
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

    private void close_tag (MarkupParseContext ctx,
            string elem) throws MarkupError
    {
        switch (elem) {
            case "item":
                if (current_video != null) {
                    videos.add (current_video);
                    current_video = null;
                }
                break;
            default:
                current_data = null;
                break;
        }
    }

    private void proc_text (MarkupParseContext ctx,
            string text,
            ulong text_len) throws MarkupError
    {
        if (current_video != null) {
            switch (current_data) {
                case "title":
                    current_video.title = text;
                    break;
                case "link":
                    current_video.link = text;
                    break;
                case "description":
                    current_video.desc = text;
                    break;
                case "category":
                    current_video.category = text;
                    break;
                case "pubDate":
                    current_video.pub_date.from_iso8601 (text);
                    break;
            }
        }
    }

    public void parse (Language lang) throws MarkupError
    {
        Soup.Message msg;
        if (lang == Language.GERMAN) {
            msg = new Soup.Message ("GET", rss_de);
        } else {
            msg = new Soup.Message ("GET", rss_fr);
        }

        Soup.SessionAsync session = new Soup.SessionAsync();
        session.user_agent = USER_AGENT;
        session.send_message(msg);

        GLib.debug ("RSS download done.");

        videos.clear();

        MarkupParser parser = {open_tag, close_tag, proc_text, null, null};
        var context = new MarkupParseContext (parser, MarkupParseFlags.TREAT_CDATA_AS_TEXT, this, null);
        // BUG in vala bindings?! MarkupParseContext: No user data should be allowed

        context.parse (msg.response_body.data, (long) msg.response_body.length);
        context.end_parse ();

        GLib.message ("Arte RSS parsing done: %i videos available.", videos.size);
    }
}

class ArtePlugin: Totem.Plugin {
    private Totem.Object t;
    private Gtk.Box main_box;
    private Gtk.TreeView tree_view;
    private ArteParser p;
    private Language language = Language.FRENCH;

    public override bool activate (Totem.Object totem) throws GLib.Error
    {
        GLib.debug ("Activating Plugin.");

        t = totem;
        p = new ArteParser();
        tree_view = new Gtk.TreeView();
        tree_view.row_activated.connect (callback_select_video_in_tree_view);
        refresh_rss_feed ();

        var scroll_win = new Gtk.ScrolledWindow (null, null);
        scroll_win.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
        scroll_win.add_with_viewport (tree_view);

        var button = new Gtk.ToolButton.from_stock (Gtk.STOCK_REFRESH);
        button.clicked.connect (callback_refresh_rss_feed);

        var langs = new Gtk.ComboBox.text ();
        langs.append_text ("German");
        langs.append_text ("French");
        langs.set_active (1); // French is the default language
        langs.changed.connect (callback_language_changed);

        var langs_item = new Gtk.ToolItem ();
        langs_item.add (langs);

        var tbar = new Gtk.Toolbar ();
        tbar.insert (button, 0);
        tbar.insert (langs_item, 1);
        tbar.set_style (Gtk.ToolbarStyle.ICONS);

        main_box = new Gtk.VBox (false, 4);
        main_box.pack_start (tbar, false, false, 0);
        main_box.pack_start (scroll_win, true, true, 0);
        main_box.show_all ();

        totem.add_sidebar_page ("arte", "Arte+7", main_box);
        return true;
    }

    public override void deactivate (Totem.Object totem)
    {
        GLib.debug ("Deactivating Plugin.");
        totem.remove_sidebar_page ("arte");
    }

    private void setup_treeview (TreeView view)
    {
        var listmodel = new ListStore (2, typeof (string), typeof (Video));
        view.set_model (listmodel);

        view.insert_column_with_attributes (-1, "Title", new CellRendererText (), "text", 0, null);
        //view.insert_column_with_attributes (-1, "Date", new CellRendererText (), "text", 1, null);

        TreeIter iter;
        foreach (Video v in p.videos) {
            listmodel.append (out iter);
            listmodel.set (iter, 0, v.title, 1, v, -1);
        }
        // TODO: sort by date?
    }

    public void refresh_rss_feed ()
    {
        try {
            p.parse(language);
        } catch (MarkupError e) {
            GLib.critical ("Error: %s\n", e.message);
            t.action_error ("Markup parser error", "Could not parse the Arte RSS feed.");
        }
        setup_treeview (tree_view);
    }

    private void callback_select_video_in_tree_view (Gtk.Widget sender,
        Gtk.TreePath path,
        Gtk.TreeViewColumn column)
    {
        var tree_view = (TreeView) sender;
        var model = tree_view.get_model ();

        Gtk.TreeIter iter;
        string title;
        Video v;

        model.get_iter(out iter, path);
        model.get(iter, 0, out title);
        model.get(iter, 1, out v);

        t.action_set_mrl_and_play (v.get_stream_uri(VideoQuality.WMV_HQ), null);
        //t.add_to_playlist_and_play (v.get_stream_uri(VideoQuality.WMV_HQ), v.title, false);
        GLib.debug ("Video Loaded: %s", title);
    }

    private void callback_refresh_rss_feed (Gtk.ToolButton toolbutton)
    {
        refresh_rss_feed ();
    }

    private void callback_language_changed (Gtk.ComboBox box)
    {
        Language last = language;
        string text = box.get_active_text ();
        if (text == "German") {
            language = Language.GERMAN;
        } else {
            language = Language.FRENCH;
        }
        if (last != language) {
            refresh_rss_feed ();
        }
    }
}

[ModuleInit]
public GLib.Type register_totem_plugin (GLib.TypeModule module)
{
    GLib.debug ("Registering plugin: ArtePlugin");

    return typeof (ArtePlugin);
}

