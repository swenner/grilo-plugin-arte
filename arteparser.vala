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
using Json;

public abstract class ArteParser : GLib.Object
{
    public bool has_data { get; protected set; default = false; } // more data available
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

    public virtual unowned GLib.SList<Video> parse (Language lang) throws MarkupError, IOError
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

public class ArteJSONParser : ArteParser
{
    private string json_url_fr = "http://www.arte.tv/guide/fr/plus7.json";
    private string json_url_de = "http://www.arte.tv/guide/de/plus7.json";

    public ArteJSONParser ()
    {
        reset ();
    }

    public override void reset ()
    {
        has_data = true;
    }

    public override uint get_error_threshold ()
    {
        return 1; // no errors are tolerated
    }

    public override unowned GLib.SList<Video> parse (Language lang) throws MarkupError, IOError
    {
        videos = new GLib.SList<Video> ();

        Soup.Message msg;
        if (lang == Language.GERMAN) {
            msg = new Soup.Message ("GET", json_url_de);
        } else {
            msg = new Soup.Message ("GET", json_url_fr);
        }

        Soup.SessionAsync session = create_session ();

        session.send_message (msg);

        if (msg.status_code != Soup.KnownStatusCode.OK) {
            throw new IOError.HOST_NOT_FOUND ("videos.arte.tv could not be accessed.");
        }

        var parser = new Json.Parser ();

        try {
            parser.load_from_data ((string) msg.response_body.flatten ().data, -1);
        } catch (GLib.Error e) {
            throw new GLib.MarkupError.PARSE ("Json parsing failed: '%s'", e.message);
        }

        var root_object = parser.get_root ().get_object ();
        var video_array = root_object.get_array_member ("videos");

        foreach (var video in video_array.get_elements ()) {
            var v = video.get_object ();
            var current_video = new Video();

            current_video.title = v.get_string_member ("title");
            current_video.page_url = "http://www.arte.tv" + v.get_string_member ("url");
            current_video.image_url = v.get_string_member ("image_url");
            current_video.desc = v.get_string_member ("desc");
            // TODO current_video.publication_date

            string end_time_str = v.get_string_member ("video_rights_until");

            try {
                var regex = new Regex ("([0-9]+)[:h]([0-9]+)");
                MatchInfo match;
                regex.match(end_time_str, 0, out match);
                string hours_str = match.fetch(1);
                string minutes_str = match.fetch(2);
                int hours = int.parse(hours_str);
                int minutes = int.parse(minutes_str);

                current_video.offline_date = GLib.TimeVal ();
                current_video.offline_date.get_current_time ();
                current_video.offline_date.tv_sec += ((hours * 60 * 60 + minutes * 60));
            } catch (GLib.RegexError e) {
                 GLib.warning ("Offline date parsing failed.");
            }

            videos.append (current_video);
        }

        has_data = false;

        return videos;
    }
}

public class ArteRSSParser : ArteParser
{
    private Video current_video = null;
    private string current_data = null;
    /* official RSS feeds, may contain duplicates */
    private const string[] feeds_fr = {
        "http://www.arte.tv/papi/tvguide-flow/feeds/videos/fr.xml?type=ARTE_PLUS_SEVEN"
    };
    private const string[] feeds_de = {
        "http://www.arte.tv/papi/tvguide-flow/feeds/videos/de.xml?type=ARTE_PLUS_SEVEN"
    };
    private const uint feed_count = feeds_fr.length;
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
    public override bool has_image_urls () { return true; }
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
            case "media:thumbnail":
                if (current_video != null) {
                    for (int i = 0; i < attribute_names.length; i++) {
                        if (attribute_names[i] == "url") {
                            current_video.image_url = attribute_values[i];
                            break;
                        }
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
        if (current_video != null && text_len > 0) {
            var my_text = text;
            if (text.has_suffix("]]>")) {
                // FIXME Why is the end of the CDATA tag kept?
                // We do use MarkupParseFlags.TREAT_CDATA_AS_TEXT...
                my_text = text.slice(0, -3);
            }
            switch (current_data) {
                case "title":
                    current_video.title = my_text;
                    break;
                case "link":
                    current_video.page_url = my_text;
                    break;
                case "description":
                    current_video.desc = sanitise_markup(my_text);
                    break;
                case "dcterms:valid":
                    MatchInfo match;
                    // example value:
                    // start=2014-11-13T06:44+00:00;end=2014-11-20T06:44+00:00;scheme=W3C-DTF
                    try {
                        var regex = new Regex ("start=([0-9T\\-:+]+);end=([0-9T\\-:+]+);");
                        regex.match(my_text, 0, out match);
                    } catch (GLib.RegexError e) {
                        GLib.warning ("Date parsing failed.");
                        break;
                    }
                    // Results are already in the ISO8601 format, but GLib requires seconds...
                    var pub_date = match.fetch(1).replace("+00:00", ":00+00:00");;
                    var off_date = match.fetch(2).replace("+00:00", ":00+00:00");
                    if (!current_video.publication_date.from_iso8601(pub_date)) {
                        GLib.warning ("Publication date '%s' parsing failed.", pub_date);
                    }
                    if (!current_video.offline_date.from_iso8601(off_date)) {
                        GLib.warning ("Offline date '%s' parsing failed.", off_date);
                    }
                    break;
            }
        }
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
        "http://videos.arte.tv/%s/do_delegate/videos/index--3188698,view,asXml.xml?hash=%s////%u/10/";

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
