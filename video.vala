/*
 * Totem Arte Plugin allows you to watch streams from arte.tv
 * Copyright (C) 2010, 2011 Simon Wenner <simon@wenner.ch>
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
