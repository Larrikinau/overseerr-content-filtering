# Settings

{% hint style="info" %}
**This is the Content Filtering Fork of Overseerr** - This documentation covers features specific to parental controls and content filtering that are not available in the upstream Overseerr project.
{% endhint %}

## General

### API Key

This is your Overseerr API key, which can be used to integrate Overseerr with third-party applications. Do **not** share this key publicly, as it can be used to gain administrator access!

If you need to generate a new API key for any reason, simply click the button to the right of the text box.

### Application Title

If you aren't a huge fan of the name "Overseerr" and would like to display something different to your users, you can customize the application title!

### Application URL

Set this to the externally-accessible URL of your Overseerr instance.

You must configure this setting in order to enable password reset and [generation](../users/README.md#automatically-generate-password) emails.

### Enable Proxy Support

If you have Overseerr behind a [reverse proxy](../../extending-overseerr/reverse-proxy.md), enable this setting to allow Overseerr to correctly register client IP addresses. For details, please see the [Express documentation](http://expressjs.com/en/guide/behind-proxies.html).

This setting is **disabled** by default.

### Enable CSRF Protection

{% hint style="danger" %}
**This is an advanced setting.** We do not recommend enabling it unless you understand the implications of doing so.
{% endhint %}

CSRF stands for [cross-site request forgery](https://en.wikipedia.org/wiki/Cross-site_request_forgery). When this setting is enabled, all external API access that alters Overseerr application data is blocked.

If you do not use Overseerr integrations with third-party applications to add/modify/delete requests or users, you can consider enabling this setting to protect against malicious attacks.

One caveat, however, is that _HTTPS is required_, meaning that once this setting is enabled, you will no longer be able to access your Overseerr instance over HTTP (including using an IP address and port number).

If you enable this setting and find yourself unable to access Overseerr, you can disable the setting by modifying `settings.json` in `/app/config`.

This setting is **disabled** by default.

### Enable Image Caching

When enabled, Overseerr will proxy and cache images from pre-configured sources (such as TMDB). This can use a significant amount of disk space.

Images are saved in the `config/cache/images` and stale images are cleared out every 24 hours.

You should enable this if you are having issues with loading images directly from TMDB in your browser.

### Display Language

Set the default display language for Overseerr. Users can override this setting in their user settings.

### Discover Region & Discover Language

These settings filter content shown on the "Discover" home page based on regional availability and original language, respectively. Users can override these global settings by configuring these same options in their user settings.

### Hide Available Media

When enabled, media which is already available will not appear on the "Discover" home page, or in the "Recommended" or "Similar" categories or other links on media detail pages.

Available media will still appear in search results, however, so it is possible to locate and view hidden items by searching for them by title.

This setting is **disabled** by default.

### Content Rating Filtering (Curated Quality Filters)

{% hint style="warning" %}
**Administrator Only Feature** - These settings can only be configured by users with Administrator permissions and apply globally to all content discovery.
{% endhint %}

This fork includes advanced content filtering capabilities to help administrators control content quality and appropriateness:

#### Curated Minimum Rating

Set a minimum TMDB rating (0.0-10.0) that content must meet to appear in discovery results. Content with ratings below this threshold will be hidden from:
- Discover pages (Movies, TV Shows, Trending)
- Network browsing (Netflix, HBO, etc.)
- Search results
- Person and Collection pages

**Special Behavior**: Setting this to **0** disables rating filtering entirely, allowing all content regardless of rating.

#### Curated Minimum Votes

Set a minimum number of TMDB votes that content must have received to appear in discovery results. This helps filter out obscure or poorly-rated content.

**Special Behavior**: Setting this to **0** disables vote filtering entirely.

#### How It Works
- Both filters work together - content must meet BOTH criteria to be shown
- Setting either value to 0 disables that specific filter
- Setting both to 0 provides unrestricted browsing
- Filters apply to all discovery mechanisms except direct media detail page access
- These settings complement per-user content rating restrictions (see [User Settings](../users/README.md#content-rating-filters))

### Allow Partial Series Requests

When enabled, users will be able to submit requests for specific seasons of TV series. If disabled, users will only be able to submit requests for all unavailable seasons.

This setting is **enabled** by default.

## Content Rating Controls

{% hint style="info" %}
**Parental Control Features** - These settings enable administrators to enforce content rating restrictions on a per-user basis.
{% endhint %}

This fork includes comprehensive parental control features that allow administrators to restrict content based on official rating systems.

### Per-User Content Filtering

Administrators can configure individual content rating limits for each user through the [User Management](../users/README.md) interface. These restrictions control what content appears in:
- All discovery pages
- Search results  
- Person and collection pages
- Trending and recommendation sections

### Supported Rating Systems

**Movie Ratings (MPAA System):**
- **G** - General Audiences
- **PG** - Parental Guidance Suggested
- **PG-13** - Parents Strongly Cautioned
- **R** - Restricted
- **NC-17** - Adults Only

**TV Ratings (FCC System):**
- **TV-Y** - Children
- **TV-Y7** - Children 7+
- **TV-G** - General Audiences
- **TV-PG** - Parental Guidance Suggested
- **TV-14** - Parents Strongly Cautioned
- **TV-MA** - Mature Audiences

### Rating Filter Behavior

When a user has content rating restrictions:
- Content with ratings above their limit is completely hidden
- Only appropriately-rated content appears in all interface areas
- The filtering is applied server-side for security
- Users cannot override these restrictions themselves

{% hint style="warning" %}
**Administrator Control Only** - Content rating filters can only be modified by users with Administrator permissions. Regular users cannot change their own rating restrictions.
{% endhint %}

## Users

### Enable Local Sign-In

When enabled, users who have configured passwords will be allowed to sign in using their email address.

When disabled, Plex OAuth becomes the only sign-in option, and any "local users" you have created will not be able to sign in to Overseerr.

This setting is **enabled** by default.

### Enable New Plex Sign-In

When enabled, users with access to your Plex server will be able to sign in to Overseerr even if they have not yet been imported. Users will be automatically assigned the permissions configured in the [Default Permissions](#default-permissions) setting upon first sign-in.

This setting is **enabled** by default.

### Global Movie Request Limit & Global Series Request Limit

Select the request limits you would like granted to users.

Unless an [override](../users/README.md#movie-request-limit-and-series-request-limit) is configured, users are granted these global request limits.

Note that users with the **Manage Users** permission are exempt from request limits, since that permission also grants the ability to submit requests on behalf of other users.

### Default Permissions

Select the permissions you would like assigned to new users to have by default upon account creation.

If [Enable New Plex Sign-In](#enable-new-plex-sign-in) is enabled, any user with access to your Plex server will be able to sign in to Overseerr, and they will be granted the permissions you select here upon first sign-in.

This setting only affects new users, and has no impact on existing users. In order to modify permissions for existing users, you will need to [edit the users](../users/README.md#editing-users).

## Plex

### Plex Settings

{% hint style="info" %}
To set up Plex, you can either enter your details manually or select a server retrieved from [plex.tv](https://plex.tv/). Press the button to the right of the "Server" dropdown to retrieve available servers.

Depending on your setup/configuration, you may need to enter your Plex server details manually in order to establish a connection from Overseerr.
{% endhint %}

#### Hostname or IP Address

If you have Overseerr installed on the same network as Plex, you can set this to the local IP address of your Plex server. Otherwise, this should be set to a valid hostname (e.g., `plex.myawesomeserver.com`).

#### Port

This value should be set to the port that your Plex server listens on. The default port that Plex uses is `32400`, but you may need to set this to `443` or some other value if your Plex server is hosted on a VPS or cloud provider.

#### Use SSL

Enable this setting to connect to Plex via HTTPS rather than HTTP. Note that self-signed certificates are _not_ supported.

#### Web App URL (optional)

The **Play on Plex** buttons on media pages link to items on your Plex server. By default, these links use the [Plex Web App](https://support.plex.tv/articles/200288666-opening-plex-web-app/) hosted from plex.tv, but you can provide the URL to the web app on your Plex server and we'll use that instead!

Note that you will need to enter the full path to the web app (e.g., `https://plex.myawesomeserver.com/web`).

### Plex Libraries

In this section, simply select the libraries you would like Overseerr to scan. Overseerr will periodically check the selected libraries for available content to update the media status that is displayed to users.

If you do not see your Plex libraries listed, verify your Plex settings are correct and click the **Sync Libraries** button.

### Manual Library Scan

Overseerr will perform a full scan of your Plex libraries once every 24 hours (recently added items are fetched more frequently). If this is your first time configuring Plex, a one-time full manual library scan is recommended!

## Services

{% hint style="info" %}
**If you keep separate copies of non-4K and 4K content in your media libraries, you will need to set up multiple Radarr/Sonarr instances and link each of them to Overseerr.**

Overseerr checks these linked servers to determine whether or not media has already been requested or is available, so two servers of each type are required _if you keep separate non-4K and 4K copies of media_.

**If you only maintain one copy of media, you can instead simply set up one server and set the "Quality Profile" setting on a per-request basis.**
{% endhint %}

### Radarr/Sonarr Settings

{% hint style="warning" %}
**Only v3 Radarr/Sonarr servers are supported!** If your Radarr/Sonarr server is still running v2, you will need to upgrade in order to add it to Overseerr.
{% endhint %}

#### Default Server

At least one server needs to be marked as "Default" in order for requests to be sent successfully to Radarr/Sonarr.

If you have separate 4K Radarr/Sonarr servers, you need to designate default 4K servers _in addition to_ default non-4K servers.

#### 4K Server

Only select this option if you have separate non-4K and 4K servers. If you only have a single Radarr/Sonarr server, do _not_ check this box!

#### Server Name

Enter a friendly name for the Radarr/Sonarr server.

#### Hostname or IP Address

If you have Overseerr installed on the same network as Radarr/Sonarr, you can set this to the local IP address of your Radarr/Sonarr server. Otherwise, this should be set to a valid hostname (e.g., `radarr.myawesomeserver.com`).

#### Port

This value should be set to the port that your Radarr/Sonarr server listens on. By default, Radarr uses port `7878` and Sonarr uses port `8989`, but you may need to set this to `443` or some other value if your Radarr/Sonarr server is hosted on a VPS or cloud provider.

#### Use SSL

Enable this setting to connect to Radarr/Sonarr via HTTPS rather than HTTP. Note that self-signed certificates are _not_ supported.

#### API Key

Enter your Radarr/Sonarr API key here. Do _not_ share these key publicly, as they can be used to gain administrator access to your Radarr/Sonarr servers!

You can locate the required API keys in Radarr/Sonarr in **Settings &rarr; General &rarr; Security**.

#### URL Base

If you have configured a URL base for your Radarr/Sonarr server, you _must_ enter it here in order for Overseerr to connect to those services!

You can verify whether or not you have a URL base configured in your Radarr/Sonarr server at **Settings &rarr; General &rarr; Host**. (Note that a restart of your Radarr/Sonarr server is required if you modify this setting!)

#### Profiles, Root Folder, Minimum Availability

Select the default settings you would like to use for all new requests. Note that all of these options are required, and that requests will fail if any of these are not configured!

#### External URL (optional)

If the hostname or IP address you configured above is not accessible outside your network, you can set a different URL here. This "external" URL is used to add clickable links to your Radarr/Sonarr servers on media detail pages.

#### Enable Scan (optional)

Enable this setting if you would like to scan your Radarr/Sonarr server for existing media/request status. It is recommended that you enable this setting, so that users cannot submit requests for media which has already been requested or is already available.

#### Enable Automatic Search (optional)

Enable this setting to have Radarr/Sonarr to automatically search for media upon approval of a request.

## Notifications

Please see [Notifications](../notifications/README.md) for details on configuring and enabling notifications.

## Jobs & Cache

Overseerr performs certain maintenance tasks as regularly-scheduled jobs, but they can also be manually triggered on this page.

Overseerr also caches requests to external API endpoints to optimize performance and avoid making unnecessary API calls. If necessary, the cache for any particular endpoint can be cleared by clicking the "Flush Cache" button.
