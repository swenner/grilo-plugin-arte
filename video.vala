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

public interface Serializable : GLib.Object
{
    public abstract string serialize ();
    public abstract bool deserialize (string data);
}

public class Video : Serializable, GLib.Object
{
    public string title = null;
    public string page_url = null;
    public string image_url = null;
    public string desc = null;
    public GLib.TimeVal publication_date;
    public GLib.TimeVal offline_date;

    private string uuid = null;
    const string VERSION = "1.0"; // serialization file version

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

    public string get_uuid ()
    {
        if (uuid == null)
            uuid = Checksum.compute_for_string (ChecksumType.MD5, page_url);

        return uuid;
    }

    public string serialize ()
    {
        string res;
        // Video, Version, Title, PageURL, ImageURL, Description, PubDate, OfflineDate
        res = "Video\n%s\n%s\n%s\n%s\n%s\n%ld\n%ld".printf (VERSION, title, page_url, image_url, desc,
                publication_date.tv_sec, offline_date.tv_sec);
        return res;
    }

    public bool deserialize (string data)
    {
        string[] str = data.split("\n");
        if (VERSION != str[1])
            return false;

        title = str[2];
        //page_url = str[3];
        image_url = str[4];
        desc = str[5];
        publication_date.tv_sec = long.parse(str[6]);
        offline_date.tv_sec = long.parse(str[7]);
        // reset uuid
        uuid = null;

        return true;
    }
}
