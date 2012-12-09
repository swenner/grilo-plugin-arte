/*
 * Totem Arte Plugin allows you to watch streams from arte.tv
 * Copyright (C) 2012 Simon Wenner <simon@wenner.ch>
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

// unused because GLib.Bus.get_proxy crashes totem (Vala 0.15.2)
[DBus (name = "org.freedesktop.NetworkManager")]
interface NetworkManagerDBus : GLib.Object
{
    [DBus (name = "state")]
    //public abstract uint32 state () throws IOError;
    public signal void state_changed (uint32 state);
}

public class ConnectionStatus : GLib.Object
{
    // Source:
    // http://projects.gnome.org/NetworkManager/developers/api/09/spec.html#type-NM_STATE
    private enum NMState
    {
        UNKNOWN = 0,
        ASLEEP = 10,
        DISCONNECTED = 20,
        DISCONNECTING = 30,
        CONNECTING = 40,
        CONNECTED_LOCAL = 50,
        CONNECTED_SITE = 60,
        CONNECTED_GLOBAL = 70
    }

    //private NetworkManagerDBus nm;
    private GLib.DBusProxy NMProxy;
    private const string NM_SERVICE = "org.freedesktop.NetworkManager";
    private const string NM_IFACE = "org.freedesktop.NetworkManager";
    private const string NM_OBJECT_PATH = "/org/freedesktop/NetworkManager";
    public bool is_online { private set; public get; default = true; }

    public ConnectionStatus ()
    {
        GLib.Bus.watch_name (GLib.BusType.SYSTEM, NM_SERVICE,
                GLib.BusNameWatcherFlags.NONE,
                name_appeared_cb, name_vanished_cb);
    }

    private void name_appeared_cb (GLib.DBusConnection connection, string name, string name_owner)
    {
        try {
            // nicer solutions, but all crash (Vala 0.15.2):
            //this.nm = GLib.Bus.get_proxy_sync<NetworkManagerDBus> (GLib.BusType.SYSTEM, NM_IFACE, NM_OBJECT_PATH);
            //this.nm = connection.get_proxy_sync<NetworkManagerDBus> (name, NM_OBJECT_PATH, 0);
            //this.nm.state_changed.connect ((state) => { stdout.printf ("state: %u\n", state); });
            //int32 state = nm.state ();
            this.NMProxy = new GLib.DBusProxy.sync (connection, 0, null, NM_IFACE, NM_OBJECT_PATH, name);

            Variant variant = this.NMProxy.get_cached_property ("State");
            uint32 state = variant.get_uint32 ();
            this.is_online = (state == NMState.CONNECTED_GLOBAL);

            this.NMProxy.g_signal.connect (proxy_signal_cb);

        } catch (GLib.Error e) {
            this.is_online = true; // online by default
            GLib.warning ("%s", e.message);
        }
    }

    private void name_vanished_cb (GLib.DBusConnection connection, string name)
    {
        // delete the proxy
        this.NMProxy = null;
        this.is_online = true; // online by default
    }

    private void proxy_signal_cb (GLib.DBusProxy obj, string? sender_name, string signal_name, Variant parameters)
    {
        if (signal_name == "StateChanged")
        {
            uint32 state = parameters.get_child_value (0).get_uint32 ();
            this.is_online = (state == NMState.CONNECTED_GLOBAL);
            // emit signal
            status_changed (this.is_online);
        }
    }

    public signal void status_changed (bool is_online);
}
