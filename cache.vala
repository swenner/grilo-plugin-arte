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
using Gtk;
using Soup;

public class Cache : GLib.Object
{
    private Soup.SessionAsync session;
    public string cache_path {get; set;}
    public Gdk.Pixbuf default_thumbnail {get; private set;}

    public Cache (string path)
    {
        cache_path = path;
        session = create_session ();

        /* create the caching directory */
        var dir = GLib.File.new_for_path (cache_path);
        if (!dir.query_exists (null)) {
            try {
                dir.make_directory_with_parents (null);
                GLib.debug ("Directory '%s' created", dir.get_path ());
            } catch (Error e) {
                GLib.error ("Could not create caching directory.");
            }
        }

        /* load the default thumbnail */
        try {
            default_thumbnail = new Gdk.Pixbuf.from_file (DEFAULT_THUMBNAIL);
        } catch (Error e) {
            GLib.critical ("%s", e.message);
        }
    }

    public string? get_data_path (string url)
    {
        /* check if file exists in cache */
        string file_path = cache_path
                + Checksum.compute_for_string (ChecksumType.MD5, url);

        var file = GLib.File.new_for_path (file_path);
        if (file.query_exists (null)) {
            return file_path;
        }

        /* get file from the the net */
        var msg = new Soup.Message ("GET", url);
        session.send_message (msg);

        if (msg.response_body.data == null) {
            return null;
        }

        /* store the file on disk */
        try {
            var file_stream = file.create (FileCreateFlags.REPLACE_DESTINATION, null);
            var data_stream = new DataOutputStream (file_stream);
            data_stream.write (msg.response_body.data);

        } catch (Error e) {
            GLib.error ("%s", e.message);
        }

        return file_path;
    }

    public Gdk.Pixbuf load_pixbuf (string? url)
    {
        if (url == null) {
            return default_thumbnail;
        }

        /* check if file exists in cache */
        string file_path = cache_path
                + Checksum.compute_for_string (ChecksumType.MD5, url);
        Gdk.Pixbuf pb = null;

        var file = GLib.File.new_for_path (file_path);
        if (file.query_exists (null)) {
            try {
                pb = new Gdk.Pixbuf.from_file (file_path);
            } catch (Error e) {
                GLib.critical ("%s", e.message);
                return default_thumbnail;
            }
            return pb;
        }

        /* otherwise, use the default thumbnail */
        return default_thumbnail;
    }

    public Gdk.Pixbuf download_pixbuf (string? url)
    {
        if (url == null) {
            return default_thumbnail;
        }

        string file_path = cache_path
                + Checksum.compute_for_string (ChecksumType.MD5, url);
        Gdk.Pixbuf pb = null;

        /* get file from the net */
        var msg = new Soup.Message ("GET", url);
        session.send_message (msg);

        if (msg.response_body.data == null) {
            return default_thumbnail;
        }

        /* rescale it */
        var img_stream = new MemoryInputStream.from_data (msg.response_body.data, null);

        try {
            /* original size: 720px × 406px */
            pb = new Gdk.Pixbuf.from_stream_at_scale (img_stream,
                    THUMBNAIL_WIDTH, -1, true, null);
        } catch (GLib.Error e) {
            GLib.critical ("%s", e.message);
            return default_thumbnail;
        }

        /* store the file on disk as PNG */
        try {
            pb.save (file_path, "png", null);
        } catch (Error e) {
            GLib.critical ("%s", e.message);
        }

        return pb;
    }

    /* Delete files that were created more than x days ago. */
    public void delete_cruft (uint days) {
        GLib.debug ("Cache: Delete files that are older than %u days.", days);
        GLib.TimeVal now = TimeVal ();
        GLib.TimeVal mod_time = TimeVal ();
        now.get_current_time ();
        long deadline = now.tv_sec - days * 24 * 60 * 60;

        var directory = File.new_for_path (cache_path);
        try {
            var enumerator = directory.enumerate_children ("*",
                    GLib.FileQueryInfoFlags.NONE, null);

            GLib.FileInfo file_info;
            while ((file_info = enumerator.next_file (null)) != null) {
                file_info.get_modification_time (out mod_time);
                if (mod_time.tv_sec < deadline) {
                    var file = File.new_for_path (cache_path + file_info.get_name ());
                    file.delete (null);
                    GLib.debug ("Cache: Deleted: %s", file_info.get_name ());
                }
            }
            enumerator.close(null);

        } catch (Error e) {
            GLib.critical ("%s", e.message);
        }
    }
}
