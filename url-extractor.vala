/*
 * Totem Arte Plugin allows you to watch streams from arte.tv
 * Copyright (C) 2010, 2011, 2012 Simon Wenner <simon@wenner.ch>
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

public errordomain ExtractionError
{
    DOWNLOAD_FAILED,
    EXTRACTION_FAILED,
    STREAM_NOT_READY,
    ACCESS_RESTRICTED
}

public interface UrlExtractor : GLib.Object
{
    public abstract string get_url (VideoQuality q, Language lang, string page_url)
            throws ExtractionError;
}

public class IndirectUrlExtractor : GLib.Object
{
    protected Soup.SessionAsync session;

    public IndirectUrlExtractor()
    {
        session = create_session ();
    }

    protected string extract_string_from_page (string url, string regexp)
            throws ExtractionError
    {
        /* Download */
        var msg = new Soup.Message ("GET", url);
        this.session.send_message(msg);
        if (msg.response_body.data == null)
            throw new ExtractionError.DOWNLOAD_FAILED ("Video URL Extraction Error");

        /* Extract */
        string res = null;
        try {
            MatchInfo match;
            var regex = new Regex (regexp);
            regex.match((string) msg.response_body.flatten ().data, 0, out match);
            res = match.fetch(1);
        } catch (RegexError e) {
            GLib.warning ("%s", e.message);
            throw new ExtractionError.EXTRACTION_FAILED (e.message);
        }

        return res;
    }
}

public class RTMPStreamUrlExtractor : IndirectUrlExtractor, UrlExtractor
{
    public string get_url (VideoQuality q, Language lang, string page_url)
            throws ExtractionError
    {
        string regexp;
        debug ("Initial Page URL:\t\t'%s'", page_url);

        /* JSON uri */
        regexp = "arte_vp_url=\"(http://.*.json)\">";
        var json_uri = extract_string_from_page (page_url, regexp);
        debug ("Extract JSON URI:\t'%s'", json_uri);
        if (json_uri == null)
            throw new ExtractionError.EXTRACTION_FAILED ("Video URL Extraction Error");


        /* download and parse the main JSON file */
        var message = new Soup.Message ("GET", json_uri);
        this.session.send_message (message);

        string rtmp_uri = null;

        // TODO detect if a video is only availabe after 23:00

        try {
            var parser = new Json.Parser ();
            parser.load_from_data ((string) message.response_body.flatten ().data, -1);

            var root_object = parser.get_root ().get_object ();
            var player_object = root_object.get_object_member ("videoJsonPlayer");
            var streams_object = player_object.get_object_member ("VSR");
            Json.Object video_object;

            switch (q) {
                case VideoQuality.LOW:
                    video_object = streams_object.get_object_member ("RTMP_LQ_1");
                    break;
                case VideoQuality.HIGH:
                    video_object = streams_object.get_object_member ("RTMP_SQ_1");
                    break;
                default: // MEDIUM is the default
                    video_object = streams_object.get_object_member ("RTMP_MQ_1"); // or "RTMP_EQ_1" ?
                    break;
            }

            string streamer = video_object.get_string_member ("streamer");
            string url = video_object.get_string_member ("url");
            debug ("Streamer base:\t'%s'", streamer);
            debug ("Streamer path:\t'%s'", url);

            rtmp_uri = streamer + "mp4:" + url;

        } catch (Error e) {
            throw new ExtractionError.EXTRACTION_FAILED ("Video URL Extraction Error");
        }


        // Try to figure out the player URI
        string player_uri;
        try {
            regexp = "content=\"(http.*.swf)\\?";
            var embeded_uri = "http://player.arte.tv/v2/index.php?json_url=" + json_uri + "&config=arte_tvguide";
            player_uri = extract_string_from_page (embeded_uri, regexp);
            debug ("Extract player URI:\t'%s'", player_uri);
            if (player_uri == null) {
                throw new ExtractionError.EXTRACTION_FAILED ("Player URL Extraction Error");
            }
        } catch (Error e) {
            // Do not abort and try to play the video with a known old player URI.
            // The server does not seems to always check the player validity, so it may work anyway.
            debug ("Failed to extract the flash player URI! Trying to fallback...");
            player_uri = "http://www.arte.tv/playerv2/jwplayer5/mediaplayer.5.7.1894.swf";
        }


        string stream_uri = rtmp_uri + " swfVfy=1 swfUrl=" + player_uri;
        debug ("Build stream URI:\t\t'%s'", stream_uri);

        return stream_uri;
    }
}

public class ImageUrlExtractor : IndirectUrlExtractor, UrlExtractor
{
    public string get_url (VideoQuality q, Language lang, string page_url)
            throws ExtractionError
    {
        // takes a video page url and returns the image url
        // Example: <link rel="image_src" href="http://videos.arte.tv/image/web/i18n/view/ai_wei_wei_jpg_1-4008448-imageData-4966655,h,102,w,180.jpg"/>
        string regexp, image_url;

        regexp = "<link rel=\"image_src\" href=\"(http://.*.jpg)\"/>";
        image_url = extract_string_from_page (page_url, regexp);

        if (image_url == null)
            throw new ExtractionError.EXTRACTION_FAILED ("Image URL Extraction Error");

        return image_url;
    }
}
