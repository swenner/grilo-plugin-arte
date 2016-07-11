/*
 * Totem Arte Plugin allows you to watch streams from arte.tv
 * Copyright (C) 2015 Simon Wenner <simon@wenner.ch>
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

#include <grilo.h>

extern gboolean
grl_arteplus7_plugin_init (GrlRegistry *registry,
        GrlPlugin *plugin,
        GList *configs);


#ifdef GRILO_VERSION_3
GRL_PLUGIN_DEFINE (0, //GRL_MAJOR,
                   3, //GRL_MINOR,
                   "grlarteplus7",
                   "Arte+7",
                   "A plugin to watch video streams from the Franco-German TV Channel Arte.",
                   "Simon Wenner, Nicolas Delvaux",
                   "1.0.0",
                   "LGPL",
                   "https://github.com/swenner/grilo-plugin-arte",
                   grl_arteplus7_plugin_init,
                   NULL,
                   NULL);
#else
GRL_PLUGIN_REGISTER (grl_arteplus7_plugin_init, NULL, "grl-arteplus7");
#endif
