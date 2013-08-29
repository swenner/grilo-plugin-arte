/*
 * Totem Arte Plugin allows you to watch streams from arte.tv
 * Copyright (C) 2013 Nicolas Delvaux <contact@nicolas-delvaux.org>
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

using Gtk;

public class CellRendererVideo : Gtk.CellRenderer
/**
 * This is a simple re-implementation of "Totem.CellRendererVideo".
 * The original widget was removed from Totem since the 3.8 version.
 */

{

    public Gdk.Pixbuf thumbnail { get; set; }
    public string title { get; set; }

    public override void get_size (Widget widget, Gdk.Rectangle? cell_area,
                                   out int x_offset, out int y_offset,
                                   out int width, out int height)
    {
        x_offset = 0;
        y_offset = 0;
        if (this.thumbnail != null) {
            width = this.thumbnail.width;
            height = this.thumbnail.height + 30;
        } else {
            // This is initialization time, nothing to draw
            // These values have no importance
            width = 30;
            height = 30;
        }
    }

    public override void render (Cairo.Context ctx, Widget widget,
                                 Gdk.Rectangle background_area,
                                 Gdk.Rectangle cell_area,
                                 CellRendererState flags)
    {

        if (this.thumbnail == null) {
            // This is initialization time, nothing to draw
            return;
        }

        Gtk.StateFlags state;

        /* Sort out the state (used to draw the title) */
        if (!this.get_sensitive ()) {
            state = Gtk.StateFlags.INSENSITIVE;
        } else if ((flags & Gtk.CellRendererState.SELECTED) == Gtk.CellRendererState.SELECTED) {
            if (widget.has_focus)
                state = Gtk.StateFlags.SELECTED;
            else
                state = Gtk.StateFlags.ACTIVE;
        }  else if ((flags & Gtk.CellRendererState.PRELIT) == Gtk.CellRendererState.PRELIT &&
                widget.get_state_flags () == Gtk.StateFlags.PRELIGHT) {
            state = Gtk.StateFlags.PRELIGHT;
        } else {
            if (widget.get_state_flags () == Gtk.StateFlags.INSENSITIVE)
                state = Gtk.StateFlags.INSENSITIVE;
            else
                state = Gtk.StateFlags.NORMAL;
        }


        /* Draw the title */
        StyleContext context = widget.get_style_context ();
        Pango.Layout layout = widget.create_pango_layout (this.title);
        Pango.FontDescription desc = context.get_font (state);

        desc.set_weight (Pango.Weight.BOLD);
        layout.set_font_description (desc);
        layout.set_ellipsize (Pango.EllipsizeMode.END);
        layout.set_width (cell_area.width * Pango.SCALE);
        layout.set_alignment (Pango.Alignment.CENTER);
        context.set_state (state);
        context.render_layout (ctx,
                               background_area.x,
                               background_area.y + this.thumbnail.height + 8,
                               layout);


        /* Draw the thumbnail */
        Gdk.cairo_set_source_pixbuf (ctx, this.thumbnail,
                                     (background_area.width - this.thumbnail.width) / 2,
                                     cell_area.y + 3);
        Gdk.cairo_rectangle (ctx, cell_area);
        ctx.fill ();

    }
}
