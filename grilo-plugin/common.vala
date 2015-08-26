/*
 * Totem Arte Plugin allows you to watch streams from arte.tv
 * Copyright (C) 2009, 2010, 2011, 2012 Simon Wenner <simon@wenner.ch>
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

public enum VideoQuality
{
    // The strange ordering is for keeping compatibility with saved settings
    UNKNOWN = 0,
    MEDIUM, // 400p
    HD, // 720p
    LOW, // 220p
    HIGH // 400p, much better audio/video bitrate than medium
}

public enum Language
{
    UNKNOWN = 0,
    FRENCH,
    GERMAN
}

public const string BOX_LANGUAGE_FRENCH = "fr";
public const string BOX_LANGUAGE_GERMAN = "de";
public const string BOX_LANGUAGE_VIDEO = "video";

public string USER_AGENT;
private const string USER_AGENT_TMPL =
    "Mozilla/5.0 (X11; Linux x86_64; rv:%d.0) Gecko/20100101 Firefox/%d.0";
public const string DCONF_ID = "org.gnome.Totem.arteplus7";
public const string DCONF_HTTP_PROXY = "org.gnome.system.proxy.http";
public const string CACHE_PATH_SUFFIX = "/totem/plugins/arteplus7/";
public const int THUMBNAIL_WIDTH = 160;
public const string DEFAULT_THUMBNAIL = "/usr/share/totem/plugins/arteplus7/arteplus7-default.png";
public bool use_proxy = false;
public Soup.URI proxy_uri;
public string proxy_username;
public string proxy_password;


public static Soup.Session create_session ()
{
    Soup.Session session;
    if (use_proxy) {
        session = new Soup.Session.with_options (
                Soup.SESSION_USER_AGENT, USER_AGENT,
                Soup.SESSION_PROXY_URI, proxy_uri, null);

        session.authenticate.connect((sess, msg, auth, retrying) => {
            /* check if authentication is needed */
            if (!retrying) {
                auth.authenticate (proxy_username, proxy_password);
            } else {
                GLib.warning ("Proxy authentication failed!\n");
            }
        });
    } else {
        session = new Soup.Session.with_options (
                Soup.SESSION_USER_AGENT, USER_AGENT, null);
    }
    session.timeout = 10; /* 10 seconds timeout, until we give up and show an error message */
    return session;
}

public void debug (string format, ...)
{
#if DEBUG_MESSAGES
    var args = va_list ();
    GLib.logv ("GrlArte", GLib.LogLevelFlags.LEVEL_DEBUG, format, args);
#endif
}
