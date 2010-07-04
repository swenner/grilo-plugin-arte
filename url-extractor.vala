/*
 * Totem Arte Plugin allows you to watch streams from arte.tv
 * Copyright (C) 2010 Simon Wenner <simon@wenner.ch>
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

errordomain ExtractionError
{
    DOWNLOAD_FAILED,
    EXTRACTION_FAILED,
    STREAM_NOT_READY
}

public interface Extractor : GLib.Object
{
  public abstract string get_url (VideoQuality q, Language lang, string page_url)
      throws ExtractionError;
}

public class StreamUrlExtractor : GLib.Object
{
  protected Soup.SessionAsync session;
  protected const bool verbose = true; /* enables debug messages */

  public StreamUrlExtractor()
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
      regex.match(msg.response_body.flatten ().data, 0, out match);
      res = match.fetch(1);
    } catch (RegexError e) {
        GLib.warning ("%s", e.message);
        throw new ExtractionError.EXTRACTION_FAILED (e.message);
    }

    return res;
  }
}

public class MP4StreamUrlExtractor : StreamUrlExtractor, Extractor
{
  public string get_url (VideoQuality q, Language lang, string page_url)
      throws ExtractionError
  {
    // TODO

    return "INVALID";
  }
}

/* Dead Extractor since July 3, 2010 */
public class WMVStreamUrlExtractor : StreamUrlExtractor, Extractor
{
  public string get_url (VideoQuality q, Language lang, string page_url)
      throws ExtractionError
  {
    string regexp, url;
    if (verbose)
      stdout.printf ("Initial Page URL:\t\t%s\n", page_url);

    /* Setup the language string */
    string lang_str = "fr";
    if (lang == Language.GERMAN)
      lang_str = "de";

    /* Setup quality string */
    string quali_str = "hd";
    if (q == VideoQuality.WMV_MQ)
      quali_str = "sd";

    /* Get the Flash XML data */
    // Example:
    // vars_player.videorefFileUrl = "http://videos.arte.tv/de/do_delegate/videos/geheimnisvolle_pflanzen-3219416,view,asPlayerXml.xml";
    regexp = "videorefFileUrl = \"(http://.*.xml)\";";
    url = extract_string_from_page (page_url, regexp);
    if (verbose)
      stdout.printf ("Extract Flash Videoref:\t\t%s\n", url);

    if (url == null)
      throw new ExtractionError.EXTRACTION_FAILED ("Video URL Extraction Error");

    /* Get the language specific flash XML data */
    // Example:
    // <video lang="de" ref="http://videos.arte.tv/de/do_delegate/videos/geheimnisvolle_pflanzen-3219418,view,asPlayerXml.xml"/>
    // <video lang="fr" ref="http://videos.arte.tv/fr/do_delegate/videos/secrets_de_plantes-3219420,view,asPlayerXml.xml"/>
    regexp = "video lang=\"" + lang_str + "\" ref=\"(http://.*.xml)\"";
    url = extract_string_from_page (url, regexp);
    if (verbose)
      stdout.printf ("Extract Flash Lang Videoref:\t%s\n", url);

    if (url == null)
      throw new ExtractionError.EXTRACTION_FAILED ("Video URL Extraction Error");

    /* Get the RTMP uri, we don't have to care about the hash. */
    // Example:
    // <url quality="hd">rtmp://artestras.fcod.llnwd.net/a3903/o35/geo/videothek/EUR_DE_FR/arteprod/A7_SGT_ENC_16_037811-000-A_PG_HQ_FR?h=d25651dc20ccdf2e8fce4839fccbd6b7</url>
    // <url quality="sd">rtmp://artestras.fcod.llnwd.net/a3903/o35/geo/videothek/EUR_DE_FR/arteprod/A7_SGT_ENC_14_037811-000-A_PG_MQ_FR?h=53699c6ac8729bcb3af3a89520c0c46c</url>
    regexp = "quality=\"" + quali_str + "\">(rtmp://.*)[?]h=";
    var rtmp_uri = extract_string_from_page (url, regexp);
    if (verbose)
      stdout.printf ("Extract RTMP URI:\t\t%s\n", rtmp_uri);

    /* sometimes only one quality level is available */
    if (rtmp_uri == null) {
      if (q == VideoQuality.WMV_HQ) {
        q = VideoQuality.WMV_MQ;
        quali_str = "sd";
        GLib.message ("No high quality stream available. Fallback to medium quality.");
      } else if (q == VideoQuality.WMV_MQ) {
        q = VideoQuality.WMV_HQ;
        quali_str = "hd";
        GLib.message ("No medium quality stream available. Fallback to high quality.");
      }
      regexp = "quality=\"" + quali_str + "\">(rtmp://.*)[?]h=";
      rtmp_uri = extract_string_from_page (url, regexp);
      if (verbose)
        stdout.printf ("Extract RTMP URI:\t\t%s\n", rtmp_uri);

      if (rtmp_uri == null)
        throw new ExtractionError.STREAM_NOT_READY ("This video is not available yet");
    }

    /* Get the video id and server id from the RTMP uri */
    // Example:
    // rtmp://artestras.fcod.llnwd.net/a3903/o35/geo/videothek/EUR_DE_FR/arteprod/A7_SGT_ENC_16_037811-000-A_PG_HQ_FR
    regexp = "videothek/(.*)/arteprod/(.*)";
    string sid = null, id = null;
    try {
      MatchInfo match;
      var regex = new Regex (regexp);
      regex.match(rtmp_uri, 0, out match);
      sid = match.fetch(1);
      id = match.fetch(2);
    } catch (RegexError e) {
        GLib.warning ("%s", e.message);
    }
    if (verbose) {
      stdout.printf ("Extract Server ID:\t\t%s\n", sid);
      stdout.printf ("Extract Video ID:\t\t%s\n", id);
    }

    if (sid == null || id == null)
      throw new ExtractionError.EXTRACTION_FAILED ("Video URL Extraction Error");

    /* Get the encoding of the video */
    // Example:
    // A7_SGT_ENC_16_042378-018-A_PG_HQ_FR
    regexp = "(.*ENC_)([0-9]*)(_.*)";
    string enc = null, front = null, tail = null;
    try {
      MatchInfo match;
      var regex = new Regex (regexp);
      regex.match(id, 0, out match);
      front = match.fetch(1);
      enc = match.fetch(2);
      tail = match.fetch(3);
    } catch (RegexError e) {
        GLib.warning ("%s", e.message);
    }
    if (verbose)
      stdout.printf ("Extract Video Encoding:\t\t%s\n", enc);

    if (front == null || enc == null || tail == null)
      throw new ExtractionError.EXTRACTION_FAILED ("Video URL Extraction Error");

    /* Subtract 8 from the encoding, this gives us WMV encoding */
    int new_enc = enc.to_int () - 8;
    if (verbose)
      stdout.printf ("New Video Encoding:\t\t%02d\n", new_enc);

    /* Build the new video ID with the new encoding */
    string new_id = front + "%02d".printf(new_enc) + tail;

    /* Build the new URI to the WMV server */
    string wmv_url = "http://artestras.wmod.rd.llnw.net/geo/arte7/" + sid +
                     "/arteprod/" + new_id + ".wmv";
    if (verbose)
      stdout.printf ("Build new WMV URI:\t\t%s\n", wmv_url);

    /* Extract the real url */
    // Example:
    // <REF HREF="mms://artestras.wmod.llnwd.net/a3903/o35/geo/arte7/ALL/arteprod/A7_SGT_ENC_08_042378-018-A_PG_HQ_FR.wmv?e=1274541080&amp;h=b9da65df4958eb14d1c1f17c9e03c460"/>
    regexp = "\"(mms://.*)\"";
    var real_url = extract_string_from_page (wmv_url, regexp);
    if (verbose)
      stdout.printf ("Extract Real WMV URL:\t\t%s\n", real_url);

    /* We did it!!! :-) */
    return real_url;
  }
}
