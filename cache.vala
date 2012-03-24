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
                debug ("Directory '%s' created", dir.get_path ());
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

    public bool get_video (ref Video v)
    {
        bool success = false;

        // check the cache
        string file_path = cache_path + v.get_uuid () + ".video";

        var file = GLib.File.new_for_path (file_path);
        if (file.query_exists (null)) {
            uint8[] data;
            try {
                file.load_contents (null, out data, null);
                success = v.deserialize ((string) data);
             } catch (Error e) {
                GLib.error ("%s", e.message);
            }

            if (success)
                return true;
        }

        // download it
        var extractor = new ImageUrlExtractor ();
        debug ("Download missing image url: %s", v.title);
        try {
            v.image_url = extractor.get_url (VideoQuality.UNKNOWN, Language.UNKNOWN, v.page_url);

            // write to cache
            var file_stream = file.create (FileCreateFlags.REPLACE_DESTINATION);
            var data_stream = new DataOutputStream (file_stream);
            data_stream.put_string (v.serialize());

            // set the last modification to the video offline date
            GLib.FileInfo fi = file.query_info(GLib.FILE_ATTRIBUTE_TIME_MODIFIED,
                GLib.FileQueryInfoFlags.NONE, null);
            fi.set_modification_time(v.offline_date);
            file.set_attributes_from_info(fi, GLib.FileQueryInfoFlags.NONE, null);
        } catch (ExtractionError e) {
            GLib.critical ("Image url extraction failed: %s", e.message);
            return false;
        } catch (Error e) {
            GLib.critical ("Caching video object failed: %s", e.message);
            return false;
        }

        return true;
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

    public Gdk.Pixbuf download_pixbuf (string? url, TimeVal date)
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

        /* set the last modification to the video offline date */
        try {
            GLib.File file = File.new_for_path (file_path);
            GLib.FileInfo fi = file.query_info(GLib.FILE_ATTRIBUTE_TIME_MODIFIED,
                GLib.FileQueryInfoFlags.NONE, null);
            fi.set_modification_time(date);
            file.set_attributes_from_info(fi, GLib.FileQueryInfoFlags.NONE, null);
        } catch (Error e) {
            GLib.critical ("%s", e.message);
        }

        return pb;
    }

    /* Delete outdated files (we set modification dates to relative videos offline dates). */
    public void delete_cruft () {
        debug ("Cache: Delete outdated files.");
        GLib.TimeVal now = TimeVal ();
        GLib.TimeVal mod_time;
        now.get_current_time ();
        /* Add a 2 hours margin (videos are not removed immediately) */
        now.tv_sec -= 7200;

        uint deleted_file_count = 0;

        var directory = File.new_for_path (cache_path);
        try {
            var enumerator = directory.enumerate_children (GLib.FILE_ATTRIBUTE_TIME_MODIFIED+
                ","+GLib.FILE_ATTRIBUTE_STANDARD_NAME, GLib.FileQueryInfoFlags.NONE, null);

            GLib.FileInfo file_info;
            while ((file_info = enumerator.next_file (null)) != null) {
                mod_time = file_info.get_modification_time ();
                if (mod_time.tv_sec < now.tv_sec) {
                    var file = File.new_for_path (cache_path + file_info.get_name ());
                    file.delete (null);
                    deleted_file_count++;
                }
            }
            enumerator.close(null);

        } catch (Error e) {
            GLib.critical ("%s", e.message);
        }
        debug ("Cache: Deleted %u files.", deleted_file_count);
    }
}
