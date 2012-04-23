/*
 * Totem Arte Plugin allows you to watch streams from arte.tv
 * Copyright (C) 2009, 2010, 2011, 2012 Simon Wenner <simon@wenner.ch>
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

public abstract class ArteParser : GLib.Object
{
    public bool has_data { get; protected set; default = false; }
    protected string xml_fr;
    protected string xml_de;
    protected GLib.SList<Video> videos;

    private const MarkupParser parser = {
            open_tag,
            close_tag,
            process_text,
            null,
            null
        };

    public ArteParser () {}
    public virtual void reset () {}
    public virtual bool has_duplicates () { return false; }
    public virtual bool has_image_urls () { return true; }
    public virtual uint get_error_threshold () { return 0; }

    public virtual bool advance ()
    {
        return has_data;
    }

    public unowned GLib.SList<Video> parse (Language lang) throws MarkupError, IOError
    {
        videos = new GLib.SList<Video> ();

        if(!has_data) {
            return videos;
        }

        Soup.Message msg;
        if (lang == Language.GERMAN) {
            msg = new Soup.Message ("GET", xml_de);
        } else {
            msg = new Soup.Message ("GET", xml_fr);
        }

        Soup.SessionAsync session = create_session ();

        session.send_message (msg);

        if (msg.status_code != Soup.KnownStatusCode.OK) {
            throw new IOError.HOST_NOT_FOUND ("videos.arte.tv could not be accessed.");
        }

        var context = new MarkupParseContext (parser,
                MarkupParseFlags.TREAT_CDATA_AS_TEXT, this, null);
        context.parse ((string) msg.response_body.flatten ().data,
                (ssize_t) msg.response_body.length);
        context.end_parse ();

        return videos;
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

    protected string sanitise_markup (string str)
    {
        return str.replace("&", "&amp;");
    }
}

public class ArteRSSParser : ArteParser
{
    private Video current_video = null;
    private string current_data = null;
    /* official RSS feeds by topic, contains duplicats, no image urls and offline dates */
    private const string[] feeds_fr = {
        "http://videos.arte.tv/fr/do_delegate/videos/toutes_les_videos/actualites/index-3188636,view,rss.xml",
        "http://videos.arte.tv/fr/do_delegate/videos/toutes_les_videos/documentaire/index-3188646,view,rss.xml",
        "http://videos.arte.tv/fr/do_delegate/videos/decouverte/index-3188644,view,rss.xml",
        "http://videos.arte.tv/fr/do_delegate/videos/toutes_les_videos/europe/index-3188648,view,rss.xml",
        "http://videos.arte.tv/fr/do_delegate/videos/toutes_les_videos/geopolitique_histoire/index-3188654,view,rss.xml",
        "http://videos.arte.tv/fr/do_delegate/videos/toutes_les_videos/societe/index-3188652,view,rss.xml",
        "http://videos.arte.tv/fr/do_delegate/videos/toutes_les_videos/junior/index-3188656,view,rss.xml",
        "http://videos.arte.tv/fr/do_delegate/videos/toutes_les_videos/cinema_fiction/index-3188642,view,rss.xml",
        "http://videos.arte.tv/fr/do_delegate/videos/toutes_les_videos/arts_cultures_spectacles/index-3188640,view,rss.xml",
        "http://videos.arte.tv/fr/do_delegate/videos/toutes_les_videos/culture_pop_alternative/index-3188638,view,rss.xml",
        "http://videos.arte.tv/fr/do_delegate/videos/toutes_les_videos/environnement_science/index-3188650,view,rss.xml"
    };
    private const string[] feeds_de = {
        "http://videos.arte.tv/de/do_delegate/videos/alle_videos/aktuelles/index-3188636,view,rss.xml",
        "http://videos.arte.tv/de/do_delegate/videos/alle_videos/dokus/index-3188646,view,rss.xml",
        "http://videos.arte.tv/de/do_delegate/videos/entdeckung/index-3188644,view,rss.xml",
        "http://videos.arte.tv/de/do_delegate/videos/alle_videos/europa/index-3188648,view,rss.xml",
        "http://videos.arte.tv/de/do_delegate/videos/alle_videos/geopolitik_geschichte/index-3188654,view,rss.xml",
        "http://videos.arte.tv/de/do_delegate/videos/alle_videos/gesellschaft/index-3188652,view,rss.xml",
        "http://videos.arte.tv/de/do_delegate/videos/alle_videos/junior/index-3188656,view,rss.xml",
        "http://videos.arte.tv/de/do_delegate/videos/alle_videos/kino_serien/index-3188642,view,rss.xml",
        "http://videos.arte.tv/de/do_delegate/videos/alle_videos/kunst_kultur/index-3188640,view,rss.xml",
        "http://videos.arte.tv/de/do_delegate/videos/alle_videos/popkultur_musik/index-3188638,view,rss.xml",
        "http://videos.arte.tv/de/do_delegate/videos/alle_videos/umwelt_wissenschaft/index-3188650,view,rss.xml"
    };
    private const uint feed_count = 11;
    private uint feed_idx = 0;

    public ArteRSSParser ()
    {
        xml_fr = feeds_fr[0];
        xml_de = feeds_de[0];

        reset ();
    }

    public override void reset ()
    {
        has_data = true;
        feed_idx = 0;
    }

    public override bool has_duplicates () { return true; }
    public override bool has_image_urls () { return false; }
    public override uint get_error_threshold ()
    {
        return (uint)(feed_count * 0.5);
    }

    public override bool advance ()
    {
        feed_idx++;
        has_data = feed_idx < feed_count;
        if(has_data)
            set_feed(feed_idx);

        return has_data;
    }

    private void set_feed (uint idx)
    {
        xml_de = feeds_de[idx];
        xml_fr = feeds_fr[idx];
        feed_idx = idx;
    }

    protected override void open_tag (MarkupParseContext ctx,
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

    protected override void close_tag (MarkupParseContext ctx,
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

    protected override void process_text (MarkupParseContext ctx,
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
                    current_video.desc = sanitise_markup(text);
                    break;
                case "pubDate":
                    // date is present, but it does not conform to ISO 8601
                    // example fr:
                    // Sun, 22 Apr 2012 11:46:27 +0200
                    // example de:
                    // Sun, 22 Apr 2012 09:07:19 +0200
                    string iso_date = rss_date_to_iso8601 (text);

                    if (!current_video.publication_date.from_iso8601 (iso_date)) {
                        GLib.warning ("Publication date '%s' parsing failed.", text);
                    }
                    break;
            }
        }
    }

    private static string rss_date_to_iso8601 (string date)
    {
        // in: Sun, 22 Apr 2012 11:46:27 +0200
        // out: 2008-02-01T09:00:22+05:00
        string[] s = date.split(" ");

        if (s.length != 6) {
            GLib.warning ("Conversion to ISO8601 failed.");
            return "";
        }

        string month;
        switch (s[2])
        {
        case "Jan":
            month = "01";
            break;
        case "Feb":
            month = "02";
            break;
        case "Mar":
            month = "03";
            break;
        case "Apr":
            month = "04";
            break;
        case "May":
            month = "05";
            break;
        case "Jun":
            month = "06";
            break;
        case "Jul":
            month = "07";
            break;
        case "Aug":
            month = "08";
            break;
        case "Sep":
            month = "09";
            break;
        case "Oct":
            month = "10";
            break;
        case "Nov":
            month = "11";
            break;
        case "Dec":
            month = "12";
            break;
        default:
            GLib.warning("Conversion to ISO8601 failed. Unknown month: '%s'.", s[2]);
            return "";
        }

        string day = s[1];
        if (day.length < 2) {
            day = "0" + day;
        }

        var builder = new StringBuilder ();
        builder.append (s[3]);
        builder.append ("-");
        builder.append (month);
        builder.append ("-");
        builder.append (day);
        builder.append ("T");
        builder.append (s[4]);
        builder.append ("+0%c:00".printf(s[5][2]));

        return builder.str;
    }
}

public class ArteXMLParser : ArteParser
{
    private Video current_video = null;
    private string current_data = null;
    private uint page = 1;
    /* number of video feed pages available */
    private uint page_limit = 14;
    /* Parses the XML feed of the Flash video wall */
    private const string xml_tmpl =
        "http://videos.arte.tv/%s/do_delegate/videos/index-3188698,view,asXml.xml?hash=%s////%u/10/";

    public ArteXMLParser ()
    {
        reset ();
    }

    public override void reset ()
    {
        set_page (1);
        has_data = true;
    }

    public override uint get_error_threshold ()
    {
        return (uint)(page_limit * 0.5);
    }

    public override bool advance ()
    {
        page++;
        has_data = page <= page_limit;
        if(has_data) {
            set_page (page);
        }
        return has_data;
    }

    private void set_page (uint page)
    {
        this.page = page;
        xml_fr = xml_tmpl.printf ("fr", "fr", page);
        xml_de = xml_tmpl.printf ("de", "de", page);
    }

    protected override void open_tag (MarkupParseContext ctx,
            string elem,
            string[] attribute_names,
            string[] attribute_values) throws MarkupError
    {
        switch (elem) {
            case "video":
                current_video = new Video();
                break;
             case "videowall":
                for (int i = 0; i < attribute_names.length ; i++) {
                    if (attribute_names[i] == "pageMax") {
                        page_limit = (uint) long.parse (attribute_values[i]);
                    }
                }
                break;
            default:
                current_data = elem;
                break;
        }
    }

    protected override void close_tag (MarkupParseContext ctx,
            string elem) throws MarkupError
    {
        switch (elem) {
            case "video":
                if (current_video != null) {
                    if (current_video.offline_date.tv_sec != 0) {
                        // We only parsed the offline date, so we compute the publication date by subtracting 7 days
                        current_video.publication_date.tv_sec = current_video.offline_date.tv_sec - 7*24*60*60;
                    }
                    videos.prepend (current_video);
                    current_video = null;
                }
                break;
            default:
                current_data = null;
                break;
        }
    }

    protected override void process_text (MarkupParseContext ctx,
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
                    current_video.desc = sanitise_markup(text);
                    break;
                case "startDate":
                    // date is present, but it does not conform to ISO 8601
                    // GLib.Date.set_parse fails in about 90% of the cases

                    // examples fr:
                    // mer., 18 avr. 2012, 20h07
                    // hier, 14h36

                    // examples de:
                    // Do, 19. Apr 2012, 00:33
                    // gestern, 15:05
                    break;
                case "endDate":
                    if (!current_video.offline_date.from_iso8601 (text)) {
                        GLib.warning ("Offline date '%s' parsing failed.", text);
                    }
                    break;
            }
        }
    }
}
