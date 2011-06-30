/*
 * Totem Arte Plugin allows you to watch streams from arte.tv
 * Copyright (C) 2011 Simon Wenner <simon@wenner.ch>
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
using Totem;

public class VideoListView : Gtk.TreeView
{
    private Cache cache;
    private string? filter = null;

    /* TreeView column names */
    private enum Col {
        IMAGE,
        NAME,
        DESCRIPTION,
        VIDEO_OBJECT,
        N
    }

    public VideoListView (Cache c)
    {
        cache = c;

        /* setup cell style */
        var renderer = new Totem.CellRendererVideo (false);
        insert_column_with_attributes (0, "", renderer,
                "thumbnail", Col.IMAGE,
                "title", Col.NAME, null);
        set_headers_visible (false);
        set_tooltip_column (Col.DESCRIPTION);

        /* context menu on right click */
        this.button_press_event.connect (callback_right_click);

        /* context menu on shift-f10 (or menu key) */
        this.popup_menu.connect (callback_menu_key);

        /* double click a video */
        this.row_activated.connect (callback_select_video_in_tree_view);
    }

    public signal void video_selected (string url, string title);

    public void display_loading_message ()
    {
        TreeIter iter;

        var msg_ls = new ListStore (3, typeof (Gdk.Pixbuf),
                typeof (string), typeof (string));
        msg_ls.prepend (out iter);
        msg_ls.set (iter,
                Col.IMAGE, null,
                Col.NAME, _("Loading..."),
                Col.DESCRIPTION, null, -1);
        this.set_model (msg_ls);
    }

    public void set_filter (string? str)
    {
        filter = str;
    }

    public void clear ()
    {
        // TODO
    }

    public void add_videos (GLib.SList<Video> videos)
    {
        TreeIter iter;

        var listmodel = new ListStore (Col.N, typeof (Gdk.Pixbuf),
                typeof (string), typeof (string), typeof (Video));

        /* save the last move to detect duplicates */
        Video last_video = null;
        int videocount = 0;

        foreach (Video v in videos) {
            /* check for duplicates */
            if (last_video != null && v.page_url == last_video.page_url) {
              last_video = v;
              continue;
            }
            last_video = v;
            videocount++;

            listmodel.append (out iter);

            string desc_str;
            /* use the description if available, fallback to the title otherwise */
            if (v.desc != null) {
              desc_str = v.desc;
            } else {
              desc_str = v.title;
            }

            if (v.offline_date.tv_sec > 0) {
                desc_str += "\n";
                var now = GLib.TimeVal ();
                now.get_current_time ();
                double minutes_left = (v.offline_date.tv_sec - now.tv_sec) / 60.0;
                if (minutes_left < 59.0) {
                    if (minutes_left < 1.0)
                        desc_str += _("Less than 1 minute until removal");
                    else
                        desc_str += _("Less than %.0f minutes until removal").printf (minutes_left + 1.0);
                } else if (minutes_left < 60.0 * 24.0) {
                    if (minutes_left <= 60.0)
                        desc_str += _("Less than 1 hour until removal");
                    else
                        desc_str += _("Less than %.0f hours until removal").printf ((minutes_left / 60.0) + 1.0);
                } else if (minutes_left < (60.0 * 24.0) * 2.0) {
                    desc_str += _("1 day until removal");
                } else {
                    desc_str += _("%.0f days until removal").printf (minutes_left / (60.0 * 24.0));
                }
            }

            listmodel.set (iter,
                    Col.IMAGE, cache.load_pixbuf (v.image_url),
                    Col.NAME, v.title,
                    Col.DESCRIPTION, desc_str,
                    Col.VIDEO_OBJECT, v, -1);
        }

        var model_filter = new Gtk.TreeModelFilter (listmodel, null);
        model_filter.set_visible_func (callback_filter_tree);

        this.set_model (model_filter);

        GLib.debug ("Unique video count: %d", videocount);
    }

    public void check_and_download_missing_thumbnails ()
    {
        TreeIter iter;
        Gdk.Pixbuf pb;
        string md5_pb;
        Video v;
        var path = new TreePath.first ();
        Gtk.ListStore list = (Gtk.ListStore)((Gtk.TreeModelFilter) this.get_model()).get_model();

        string md5_default_pb = Checksum.compute_for_data (ChecksumType.MD5,
                cache.default_thumbnail.get_pixels ());

        for (int i=1; i<=list.iter_n_children (null); i++) {
            list.get_iter (out iter, path);
            list.get (iter, Col.IMAGE, out pb);
            md5_pb = Checksum.compute_for_data (ChecksumType.MD5, pb.get_pixels ());
            if (md5_pb == md5_default_pb) {
                list.get (iter, Col.VIDEO_OBJECT, out v);
                if (v.image_url != null) {
                    GLib.debug ("Download missing thumbnail: %s", v.title);
                    list.set (iter, Col.IMAGE, cache.download_pixbuf (v.image_url));
                }
            }
            path.next ();
        }
    }

    private bool callback_right_click (Gdk.EventButton event)
    {
        if (event.button == 3)
            show_popup_menu (event);

        return false;
    }

    private bool callback_menu_key ()
    {
        show_popup_menu (null);

        /* do NOT propagate the signal */
        return true;
    }

    private void show_popup_menu (Gdk.EventButton? event)
    {
        var menu = new Gtk.Menu ();
        var menu_web = new ImageMenuItem.from_stock (Gtk.Stock.JUMP_TO, null);
        menu_web.set_label (_("_Open in Web Browser"));
        menu_web.activate.connect (callback_open_in_web_browser);
        
        menu.attach (menu_web, 0, 1, 0, 1);

        menu.attach_to_widget (this, null);
        menu.show_all();
        menu.select_first (false);

        if (event == null) {
            /* called by menu key (Shift + F10) */
            menu.popup (null, null, menu_position, 0, get_current_event_time ());
        } else {
            menu.popup (null, null, null, 3, event.time);
        }
    }

    private void callback_open_in_web_browser ()
    {
        TreeIter iter;
        TreePath path;
        Video v;
        string url;

        /* retrieve url of the selected video */
        path = this.get_selection ().get_selected_rows (null).data;
        this.model.get_iter (out iter, path);
        this.model.get (iter, Col.VIDEO_OBJECT, out v);
        url = v.page_url;

        try {
            Process.spawn_command_line_async ("xdg-open " + url);
        } catch (SpawnError e) {
            GLib.critical ("Fail to spawn process: " + e.message);
        }
    }

    private void menu_position (Menu menu, out int x, out int y, out bool push_in)
    {
        int wy;
        Gdk.Rectangle rect;
        Gtk.Requisition requisition;
        Gtk.Allocation allocation;

        TreePath path = this.get_selection ().get_selected_rows (null).data;
        this.get_cell_area (path, null, out rect);

        wy = rect.y;
        this.get_bin_window ().get_origin (out x, out y);
        menu.get_preferred_size (null, out requisition);
        this.get_allocation(out allocation);

        x += 10;
        wy = int.max (y + 5, y + wy + 5);
        wy = int.min (wy, y + allocation.height - requisition.height - 5);
        y = wy;

        push_in = true;
    }

    private bool callback_filter_tree (Gtk.TreeModel model, Gtk.TreeIter iter)
    {
        string title;
        model.get (iter, Col.NAME, out title);
        if (filter == null || title.down ().contains (filter))
            return true;
        else
            return false;
    }

    private void callback_select_video_in_tree_view (Gtk.TreeView tree_view,
        Gtk.TreePath path,
        Gtk.TreeViewColumn column)
    {
        Gtk.TreeIter iter;
        Video v;

        var model = this.get_model ();
        model.get_iter (out iter, path);
        model.get (iter, Col.VIDEO_OBJECT, out v);

        if (v != null) {
            /* emmit signal */
            video_selected (v.page_url, v.title);
        }
    }
}
