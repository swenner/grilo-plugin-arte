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
    /* TreeView column names */
    private enum Col {
        IMAGE,
        NAME,
        DESCRIPTION,
        VIDEO_OBJECT,
        N
    }

    construct
    {
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

    public void clear ()
    {
        // TODO
    }

    public void add_videos (GLib.SList<Video> videos)
    {
        // TODO
    }
}
