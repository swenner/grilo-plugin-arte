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

        Soup.Session session = create_session ();

        session.send_message (msg);

        if (msg.status_code != Soup.Status.OK) {
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
    /* official RSS feeds */
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

    public override bool has_duplicates () { return false; }
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

