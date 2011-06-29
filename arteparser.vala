/*
 * Totem Arte Plugin allows you to watch streams from arte.tv
 * Copyright (C) 2009, 2010, 2011 Simon Wenner <simon@wenner.ch>
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
        context.parse ((string) msg.response_body.flatten ().data,
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
            "http://videos.arte.tv/fr/do_delegate/videos/index-3188626,view,rss.xml";
        xml_de =
            "http://videos.arte.tv/de/do_delegate/videos/index-3188626,view,rss.xml";
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
        "http://videos.arte.tv/%s/do_delegate/videos/index-3188698,view,asXml.xml?hash=%s////%d/10/";

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

    protected override void open_tag (MarkupParseContext ctx,
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

    protected override void close_tag (MarkupParseContext ctx,
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
