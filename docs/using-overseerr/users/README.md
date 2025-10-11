# Users

{% hint style="info" %}
**Content Filtering Fork Features** - This documentation covers user management features specific to the Content Filtering Fork, including parental controls and content rating restrictions.
{% endhint %}

## Owner Account

The user account created during Overseerr setup is the "Owner" account, which cannot be deleted or modified by other users. This account's credentials are used to authenticate with Plex.

## Adding Users

There are currently two methods to add users to Overseerr: importing Plex users and creating "local users." All new users are created with the [default permissions](../settings/README.md#default-permissions) defined in **Settings &rarr; Users**.

### Importing Plex Users

Clicking the **Import Plex Users** button on the **User List** page will fetch the list of users with access to the Plex server from [plex.tv](https://www.plex.tv/), and add them to Overseerr automatically.

Importing Plex users is not required, however. Any user with access to the Plex server can log in to Overseerr even if they have not been imported, and will be assigned the configured [default permissions](../settings/README.md#default-permissions) upon their first login.

### Creating Local Users

If you would like to grant Overseerr access to a user who doesn't have their own Plex account and/or access to the Plex server, you can manually add them by clicking the **Create Local User** button.

#### Email Address

Enter a valid email address at which the user can receive messages pertaining to their account and other notifications. The email address currently cannot be modified after the account is created.

#### Automatically Generate Password

If an [application URL](../settings/README.md#application-url) is set and [email notifications](../notifications/email.md) have been configured and enabled, Overseerr can automatically generate a password for the new user.

#### Password

If you would prefer to manually configure a password, enter a password here that is a minimum of 8 characters.

## Editing Users

From the **User List**, you can click the **Edit** button to modify a particular user's settings.

You can also click the check boxes and click the **Bulk Edit** button to set user permissions for multiple users at once.

### General

#### Display Name

You can optionally set a "friendly name" for any user. This name will be used in lieu of their Plex username (for users imported from Plex) or their email address (for manually-created local users).

#### Display Language

Users can override the [global display language](../settings/README.md#display-language) to use Overseerr in their preferred language.

#### Discover Region & Discover Language

Users can override the [global filter settings](../settings/README.md#discover-region-and-discover-language) to suit their own preferences.

#### Movie Request Limit & Series Request Limit

You can override the default settings and assign different request limits for specific users by checking the **Enable Override** box and selecting the desired request limit and time period.

Unless an override is configured, users are granted the global request limits.

Note that users with the **Manage Users** permission are exempt from request limits, since that permission also grants the ability to submit requests on behalf of other users.

Users are also unable to modify their own request limits.

### Content Rating Filters

{% hint style="warning" %}
**Administrator Only Feature** - Content rating filters can only be configured by users with Administrator permissions. Users cannot modify their own content restrictions.
{% endhint %}

The Content Filtering Fork includes comprehensive parental control capabilities that allow administrators to restrict content based on official rating systems.

#### Maximum Movie Rating

Set the highest movie rating (MPAA system) that this user can view. Content with higher ratings will be completely hidden from the user's interface.

**Supported Movie Ratings (in ascending order of restriction):**
- **G** - General Audiences (all ages appropriate)
- **PG** - Parental Guidance Suggested (some material may not be suitable for children)
- **PG-13** - Parents Strongly Cautioned (inappropriate for children under 13)
- **R** - Restricted (under 17 requires accompanying adult)
- **NC-17** - Adults Only (no one 17 and under admitted)

#### Maximum TV Rating

Set the highest TV rating (FCC system) that this user can view. Content with higher ratings will be completely hidden from the user's interface.

**Supported TV Ratings (in ascending order of restriction):**
- **TV-Y** - Children (appropriate for all children)
- **TV-Y7** - Children 7+ (appropriate for children 7 and older)
- **TV-G** - General Audiences (suitable for all ages)
- **TV-PG** - Parental Guidance Suggested (may be unsuitable for younger children)
- **TV-14** - Parents Strongly Cautioned (inappropriate for children under 14)
- **TV-MA** - Mature Audiences (specifically designed for adults)

#### How Content Filtering Works

When content rating restrictions are applied to a user:

- **Complete Content Hiding**: Restricted content is entirely hidden from the user's view
- **Universal Application**: Filtering applies to all areas of the interface:
  - Discover pages (Movies, TV Shows, Trending)
  - Search results
  - Person and collection pages
  - Network browsing (Netflix, HBO, etc.)
  - Recommendations and related content
- **Server-Side Security**: Filtering is enforced at the API level for security
- **Cannot Be Overridden**: Users cannot bypass or modify their own restrictions

#### Setting Up Content Restrictions

1. Navigate to **User List** and click **Edit** for the target user
2. Locate the **Content Rating Filters** section
3. Select appropriate maximum ratings for movies and TV shows
4. Save the user settings

{% hint style="info" %}
**Example Use Case**: For a child user, you might set Maximum Movie Rating to **PG** and Maximum TV Rating to **TV-PG**. This ensures they only see family-friendly content throughout the entire Overseerr interface.
{% endhint %}

### Password

All "local users" are assigned passwords upon creation, but users imported from Plex can also optionally configure passwords to enable sign-in using their email address.

Passwords must be a minimum of 8 characters long.

### Notifications

Users can configure their personal notification settings here. Please see [Notifications](../notifications/README.md) for details on configuring and enabling notifications.

### Permissions

Users cannot modify their own permissions. Users with the **Manage Users** permission can manage permissions of other users, except those of users with the **Admin** permission.

## Deleting Users

When users are deleted, all of their data and request history is also cleared from the database.
