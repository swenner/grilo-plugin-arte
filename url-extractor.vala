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

public class RTMPStreamUrlExtractor : StreamUrlExtractor, Extractor
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

    /* Get the Arte Flash player URI */
    // Example:
    // var url_player = "http://videos.arte.tv/blob/web/i18n/view/player_9-3188338-data-4807088.swf";
    regexp = "var url_player = \"(http://.*.swf)\";";
    var flash_player_uri = extract_string_from_page (page_url, regexp);
    if (verbose)
      stdout.printf ("Extract Flash player URI:\t%s\n", flash_player_uri);
    if (flash_player_uri == null)
      throw new ExtractionError.EXTRACTION_FAILED ("Video URL Extraction Error");

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

    /* Get the RTMP uri. */
    // Example:
    // <url quality="hd">rtmp://artestras.fcod.llnwd.net/a3903/o35/MP4:geo/videothek/EUR_DE_FR/arteprod/A7_SGT_ENC_08_037778-021-B_PG_HQ_FR?h=7258f52f54eb0d320f6650e647432f03</url>
    // <url quality="sd">rtmp://artestras.fcod.llnwd.net/a3903/o35/MP4:geo/videothek/EUR_DE_FR/arteprod/A7_SGT_ENC_06_037778-021-B_PG_MQ_FR?h=76c529bce0f034e74dc92a14549d6a4e</url>
    regexp = "quality=\"" + quali_str + "\">(rtmp://.*)</url>";
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
      regexp = "quality=\"" + quali_str + "\">(rtmp://.*)</url>";
      rtmp_uri = extract_string_from_page (url, regexp);
      if (verbose)
        stdout.printf ("Extract RTMP URI:\t\t%s\n", rtmp_uri);

      if (rtmp_uri == null)
        throw new ExtractionError.STREAM_NOT_READY ("This video is not available yet");
    }
    
    /* Build the stream URI
     * To prevent regular disconnections (and so to keep the plugin usable),
     * we need to pass the Flash player uri to GStreamer.
     * We do that by appending it to the stream uri.
     * (see the librtmp manual for more information) */
    // Example:
    // rtmp://artestras.fcod.llnwd.net/a3903/o35/MP4:geo/videothek/EUR_DE_FR/arteprod/A7_SGT_ENC_08_042143-002-A_PG_HQ_FR?h=d7878fae5c9726844d22da78e05f764e swfVfy=1 swfUrl=http://videos.arte.tv/blob/web/i18n/view/player_9-3188338-data-4807088.swf
    string stream_uri = rtmp_uri + " swfVfy=1 swfUrl=" + flash_player_uri;
    if (verbose)
      stdout.printf ("Build stream URI:\t\t%s\n", stream_uri);

    return stream_uri;
  }
}

/* This extractor use "EQ" quality links provided by Arte. */
// While writing this, these links do not work.
// So this extractor stays here, waiting for its time...
public class MP4StreamUrlExtractor : StreamUrlExtractor, Extractor
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

    if (url == null) {
      throw new ExtractionError.EXTRACTION_FAILED ("Video URL Extraction Error");
    }

    /* Get the EQ uri */
    // Example:
    // <url quality="EQ">http://artestras.wmod.rd.llnw.net/geo/arte7/EUR_DE_FR/arteprod/A7_SGT_ENC_16_037778-021-B_PG_EQ_FR.mp4</url>
    regexp = "quality=\"EQ\">(http://.*.mp4)";
    var eq_uri = extract_string_from_page (url, regexp);
    if (verbose)
      stdout.printf ("Extract EQ URI:\t\t%s\n", eq_uri);

    /* Extract the real url */
    // Example:
    // <REF HREF="mms://artestras.wmod.llnwd.net/a3903/o35/geo/arte7/EUR_DE_FR/arteprod/A7_SGT_ENC_16_037778-021-B_PG_EQ_FR.mp4?e=1280957332&amp;h=3ab8ed22003545b1f46c6a595d5c6475"/>
    regexp = "\"(mms://.*)\"";
    var real_url = extract_string_from_page (eq_uri, regexp);
    if (verbose)
      stdout.printf ("Extract Real WMV URL:\t\t%s\n", real_url);

    return real_url;
  }
}

