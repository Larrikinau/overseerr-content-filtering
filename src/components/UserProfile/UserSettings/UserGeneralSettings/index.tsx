import Badge from '@app/components/Common/Badge';
import Button from '@app/components/Common/Button';
import LoadingSpinner from '@app/components/Common/LoadingSpinner';
import PageTitle from '@app/components/Common/PageTitle';
import LanguageSelector from '@app/components/LanguageSelector';
import QuotaSelector from '@app/components/QuotaSelector';
import RegionSelector from '@app/components/RegionSelector';
import type { AvailableLocale } from '@app/context/LanguageContext';
import { availableLanguages } from '@app/context/LanguageContext';
import useLocale from '@app/hooks/useLocale';
import useSettings from '@app/hooks/useSettings';
import { Permission, UserType, useUser } from '@app/hooks/useUser';
import globalMessages from '@app/i18n/globalMessages';
import Error from '@app/pages/_error';
import { ArrowDownOnSquareIcon } from '@heroicons/react/24/outline';
import type { UserSettingsGeneralResponse } from '@server/interfaces/api/userSettingsInterfaces';
import axios from 'axios';
import { Field, Form, Formik } from 'formik';
import { useRouter } from 'next/router';
import { useEffect, useState } from 'react';
import { defineMessages, useIntl } from 'react-intl';
import { useToasts } from 'react-toast-notifications';
import useSWR from 'swr';
import * as Yup from 'yup';

const messages = defineMessages({
  general: 'General',
  generalsettings: 'General Settings',
  displayName: 'Display Name',
  accounttype: 'Account Type',
  plexuser: 'Plex User',
  localuser: 'Local User',
  role: 'Role',
  owner: 'Owner',
  admin: 'Admin',
  user: 'User',
  toastSettingsSuccess: 'Settings saved successfully!',
  toastSettingsFailure: 'Something went wrong while saving settings.',
  region: 'Discover Region',
  regionTip: 'Filter content by regional availability',
  originallanguage: 'Discover Language',
  originallanguageTip: 'Filter content by original language',
  movierequestlimit: 'Movie Request Limit',
  seriesrequestlimit: 'Series Request Limit',
  enableOverride: 'Override Global Limit',
  applanguage: 'Display Language',
  languageDefault: 'Default ({language})',
  discordId: 'Discord User ID',
  discordIdTip:
    'The <FindDiscordIdLink>multi-digit ID number</FindDiscordIdLink> associated with your Discord user account',
  validationDiscordId: 'You must provide a valid Discord user ID',
  plexwatchlistsyncmovies: 'Auto-Request Movies',
  plexwatchlistsyncmoviestip:
    'Automatically request movies on your <PlexWatchlistSupportLink>Plex Watchlist</PlexWatchlistSupportLink>',
  plexwatchlistsyncseries: 'Auto-Request Series',
  plexwatchlistsyncseriestip:
    'Automatically request series on your <PlexWatchlistSupportLink>Plex Watchlist</PlexWatchlistSupportLink>',

  maxMovieRating: 'Maximum Movie Rating',
  maxMovieRatingTip: 'Allow content at the selected rating level and below',
  maxTvRating: 'Maximum TV Rating', 
  maxTvRatingTip: 'Allow TV content at the selected rating level and below',
  ratingFilteringTitle: 'Content Rating Filtering',
  
  curatedFilteringTitle: 'Content Quality Filtering',
  curatedFilteringTip: 'Control minimum quality thresholds for content discovery',
  curatedMinVotes: 'Minimum Vote Count',
  curatedMinVotesTip: 'Only show content with at least this many votes on TMDB',
  curatedMinRating: 'Minimum Rating',
  curatedMinRatingTip: 'Only show content with at least this rating on TMDB',
});

const UserGeneralSettings = () => {
  const intl = useIntl();
  const { addToast } = useToasts();
  const { locale, setLocale } = useLocale();
  const [movieQuotaEnabled, setMovieQuotaEnabled] = useState(false);
  const [tvQuotaEnabled, setTvQuotaEnabled] = useState(false);
  const router = useRouter();
  const {
    user,
    hasPermission,
    revalidate: revalidateUser,
  } = useUser({
    id: Number(router.query.userId),
  });
  const { user: currentUser, hasPermission: currentHasPermission } = useUser();
  const { currentSettings } = useSettings();
  const {
    data,
    error,
    mutate: revalidate,
  } = useSWR<UserSettingsGeneralResponse>(
    user ? `/api/v1/user/${user?.id}/settings/main` : null
  );

  const UserGeneralSettingsSchema = Yup.object().shape({
    discordId: Yup.string()
      .nullable()
      .matches(/^\d{17,19}$/, intl.formatMessage(messages.validationDiscordId)),
  });

  useEffect(() => {
    setMovieQuotaEnabled(
      data?.movieQuotaLimit != undefined && data?.movieQuotaDays != undefined
    );
    setTvQuotaEnabled(
      data?.tvQuotaLimit != undefined && data?.tvQuotaDays != undefined
    );
  }, [data]);

  if (!data && !error) {
    return <LoadingSpinner />;
  }

  if (!data) {
    return <Error statusCode={500} />;
  }

  return (
    <>
      <PageTitle
        title={[
          intl.formatMessage(messages.general),
          intl.formatMessage(globalMessages.usersettings),
        ]}
      />
      <div className="mb-6">
        <h3 className="heading">
          {intl.formatMessage(messages.generalsettings)}
        </h3>
      </div>
      <Formik
        initialValues={{
          displayName: data?.username,
          discordId: data?.discordId,
          locale: data?.locale,
          region: data?.region,
          originalLanguage: data?.originalLanguage,
          movieQuotaLimit: data?.movieQuotaLimit,
          movieQuotaDays: data?.movieQuotaDays,
          tvQuotaLimit: data?.tvQuotaLimit,
          tvQuotaDays: data?.tvQuotaDays,
          watchlistSyncMovies: data?.watchlistSyncMovies,
          watchlistSyncTv: data?.watchlistSyncTv,
          maxMovieRating: data?.maxMovieRating ?? 'Adult',
          maxTvRating: data?.maxTvRating ?? '',
          curatedMinVotes: data?.curatedMinVotes ?? 3000,
          curatedMinRating: data?.curatedMinRating ?? 6.0,
        }}
        validationSchema={UserGeneralSettingsSchema}
        enableReinitialize
        onSubmit={async (values) => {
          try {
            await axios.post(`/api/v1/user/${user?.id}/settings/main`, {
              username: values.displayName,
              discordId: values.discordId,
              locale: values.locale,
              region: values.region,
              originalLanguage: values.originalLanguage,
              movieQuotaLimit: movieQuotaEnabled
                ? values.movieQuotaLimit
                : null,
              movieQuotaDays: movieQuotaEnabled ? values.movieQuotaDays : null,
              tvQuotaLimit: tvQuotaEnabled ? values.tvQuotaLimit : null,
              tvQuotaDays: tvQuotaEnabled ? values.tvQuotaDays : null,
              watchlistSyncMovies: values.watchlistSyncMovies,
              watchlistSyncTv: values.watchlistSyncTv,
              maxMovieRating: values.maxMovieRating,
              maxTvRating: values.maxTvRating,
              curatedMinVotes: values.curatedMinVotes,
              curatedMinRating: values.curatedMinRating,
            });

            if (currentUser?.id === user?.id && setLocale) {
              setLocale(
                (values.locale
                  ? values.locale
                  : currentSettings.locale) as AvailableLocale
              );
            }

            addToast(intl.formatMessage(messages.toastSettingsSuccess), {
              autoDismiss: true,
              appearance: 'success',
            });
          } catch (e) {
            addToast(intl.formatMessage(messages.toastSettingsFailure), {
              autoDismiss: true,
              appearance: 'error',
            });
          } finally {
            revalidate();
            revalidateUser();
          }
        }}
      >
        {({
          errors,
          touched,
          isSubmitting,
          isValid,
          values,
          setFieldValue,
        }) => {
          return (
            <Form className="section">
              <div className="form-row">
                <label className="text-label">
                  {intl.formatMessage(messages.accounttype)}
                </label>
                <div className="mb-1 text-sm font-medium leading-5 text-gray-400 sm:mt-2">
                  <div className="flex max-w-lg items-center">
                    {user?.userType === UserType.PLEX ? (
                      <Badge badgeType="warning">
                        {intl.formatMessage(messages.plexuser)}
                      </Badge>
                    ) : (
                      <Badge badgeType="default">
                        {intl.formatMessage(messages.localuser)}
                      </Badge>
                    )}
                  </div>
                </div>
              </div>
              <div className="form-row">
                <label className="text-label">
                  {intl.formatMessage(messages.role)}
                </label>
                <div className="mb-1 text-sm font-medium leading-5 text-gray-400 sm:mt-2">
                  <div className="flex max-w-lg items-center">
                    {user?.id === 1
                      ? intl.formatMessage(messages.owner)
                      : hasPermission(Permission.ADMIN)
                      ? intl.formatMessage(messages.admin)
                      : intl.formatMessage(messages.user)}
                  </div>
                </div>
              </div>
              <div className="form-row">
                <label htmlFor="displayName" className="text-label">
                  {intl.formatMessage(messages.displayName)}
                </label>
                <div className="form-input-area">
                  <div className="form-input-field">
                    <Field
                      id="displayName"
                      name="displayName"
                      type="text"
                      placeholder={
                        user?.plexUsername ? user.plexUsername : user?.email
                      }
                    />
                  </div>
                  {errors.displayName &&
                    touched.displayName &&
                    typeof errors.displayName === 'string' && (
                      <div className="error">{errors.displayName}</div>
                    )}
                </div>
              </div>
              <div className="form-row">
                <label htmlFor="discordId" className="text-label">
                  {intl.formatMessage(messages.discordId)}
                  {currentUser?.id === user?.id && (
                    <span className="label-tip">
                      {intl.formatMessage(messages.discordIdTip, {
                        FindDiscordIdLink: (msg: React.ReactNode) => (
                          <a
                            href="https://support.discord.com/hc/en-us/articles/206346498-Where-can-I-find-my-User-Server-Message-ID-"
                            target="_blank"
                            rel="noreferrer"
                          >
                            {msg}
                          </a>
                        ),
                      })}
                    </span>
                  )}
                </label>
                <div className="form-input-area">
                  <div className="form-input-field">
                    <Field id="discordId" name="discordId" type="text" />
                  </div>
                  {errors.discordId &&
                    touched.discordId &&
                    typeof errors.discordId === 'string' && (
                      <div className="error">{errors.discordId}</div>
                    )}
                </div>
              </div>
              <div className="form-row">
                <label htmlFor="locale" className="text-label">
                  {intl.formatMessage(messages.applanguage)}
                </label>
                <div className="form-input-area">
                  <div className="form-input-field">
                    <Field as="select" id="locale" name="locale">
                      <option value="" lang={locale}>
                        {intl.formatMessage(messages.languageDefault, {
                          language:
                            availableLanguages[currentSettings.locale].display,
                        })}
                      </option>
                      {(
                        Object.keys(
                          availableLanguages
                        ) as (keyof typeof availableLanguages)[]
                      ).map((key) => (
                        <option
                          key={key}
                          value={availableLanguages[key].code}
                          lang={availableLanguages[key].code}
                        >
                          {availableLanguages[key].display}
                        </option>
                      ))}
                    </Field>
                  </div>
                </div>
              </div>
            {currentHasPermission(Permission.MANAGE_USERS) && (
              <>

              <div className="mt-6">
                <h3 className="mb-2 text-xl font-bold text-white">
                  {intl.formatMessage(messages.ratingFilteringTitle)}
                </h3>
                <p className="text-sm text-gray-400 mb-4">
                  Allow content at the selected rating level and below
                </p>
              </div>

              <div className="form-row">
                <label htmlFor="maxMovieRating" className="text-label">
                  {intl.formatMessage(messages.maxMovieRating)}
                  <span className="label-tip">
                    {intl.formatMessage(messages.maxMovieRatingTip)}
                  </span>
                </label>
                <div className="form-input-area">
                  <div className="form-input-field">
                    <Field as="select" id="maxMovieRating" name="maxMovieRating">
                      <option value="">No restrictions - Allow all content</option>
                      <option value="G">G - Allow only G (block PG and above)</option>
                      <option value="PG">PG - Allow G and PG (block PG-13 and above)</option>
                      <option value="PG-13">PG-13 - Allow G, PG, and PG-13 (block R and above)</option>
                      <option value="R">R - Allow G, PG, PG-13, and R (block Adult/XXX)</option>
                      <option value="Adult">Adult - Block only Adult/XXX content (allow R and below)</option>
                    </Field>
                  </div>
                </div>
              </div>

              <div className="form-row">
                <label htmlFor="maxTvRating" className="text-label">
                  {intl.formatMessage(messages.maxTvRating)}
                  <span className="label-tip">
                    {intl.formatMessage(messages.maxTvRatingTip)}
                  </span>
                </label>
                <div className="form-input-area">
                  <div className="form-input-field">
                    <Field as="select" id="maxTvRating" name="maxTvRating">
                      <option value="">No restriction - Allow all TV content</option>
                      <option value="TV-Y">TV-Y - Allow only TV-Y (block TV-Y7 and above)</option>
                      <option value="TV-Y7">TV-Y7 - Allow TV-Y and TV-Y7 (block TV-G and above)</option>
                      <option value="TV-G">TV-G - Allow TV-Y, TV-Y7, and TV-G (block TV-PG and above)</option>
                      <option value="TV-PG">TV-PG - Allow through TV-PG (block TV-14 and above)</option>
                      <option value="TV-14">TV-14 - Allow through TV-14 (block TV-MA)</option>
                      <option value="TV-MA">TV-MA - Allow all content (no restrictions)</option>
                    </Field>
                  </div>
                </div>
              </div>

              <div className="mt-6">
                <h3 className="mb-2 text-xl font-bold text-white">
                  {intl.formatMessage(messages.curatedFilteringTitle)}
                </h3>
                <p className="text-sm text-gray-400 mb-4">
                  {intl.formatMessage(messages.curatedFilteringTip)}
                </p>
              </div>

              <div className="form-row">
                <label htmlFor="curatedMinVotes" className="text-label">
                  {intl.formatMessage(messages.curatedMinVotes)}
                  <span className="label-tip">
                    {intl.formatMessage(messages.curatedMinVotesTip)}
                  </span>
                </label>
                <div className="form-input-area">
                  <div className="form-input-field">
                    <Field
                      id="curatedMinVotes"
                      name="curatedMinVotes"
                      type="text"
                      placeholder="e.g., 3000"
                      className="block w-full min-w-0 flex-1 rounded-md border border-gray-500 bg-gray-700 text-white transition duration-150 ease-in-out sm:text-sm sm:leading-5"
                    />
                  </div>
                </div>
              </div>

              <div className="form-row">
                <label htmlFor="curatedMinRating" className="text-label">
                  {intl.formatMessage(messages.curatedMinRating)}
                  <span className="label-tip">
                    {intl.formatMessage(messages.curatedMinRatingTip)}
                  </span>
                </label>
                <div className="form-input-area">
                  <div className="form-input-field">
                    <Field
                      id="curatedMinRating"
                      name="curatedMinRating"
                      type="text"
                      placeholder="e.g., 6.5"
                      className="block w-full min-w-0 flex-1 rounded-md border border-gray-500 bg-gray-700 text-white transition duration-150 ease-in-out sm:text-sm sm:leading-5"
                    />
                  </div>
                </div>
              </div>
              </>
            )}

              <div className="form-row">
                <label htmlFor="displayName" className="text-label">
                  <span>{intl.formatMessage(messages.region)}</span>
                  <span className="label-tip">
                    {intl.formatMessage(messages.regionTip)}
                  </span>
                </label>
                <div className="form-input-area">
                  <div className="form-input-field">
                    <RegionSelector
                      name="region"
                      value={values.region ?? ''}
                      isUserSetting
                      onChange={setFieldValue}
                    />
                  </div>
                </div>
              </div>
              <div className="form-row">
                <label htmlFor="originalLanguage" className="text-label">
                  <span>{intl.formatMessage(messages.originallanguage)}</span>
                  <span className="label-tip">
                    {intl.formatMessage(messages.originallanguageTip)}
                  </span>
                </label>
                <div className="form-input-area">
                  <div className="form-input-field">
                    <LanguageSelector
                      setFieldValue={setFieldValue}
                      serverValue={currentSettings.originalLanguage}
                      value={values.originalLanguage}
                      isUserSettings
                    />
                  </div>
                </div>
              </div>
              {currentHasPermission(Permission.MANAGE_USERS) &&
                !hasPermission(Permission.MANAGE_USERS) && (
                  <>
                    <div className="form-row">
                      <label htmlFor="movieQuotaLimit" className="text-label">
                        <span>
                          {intl.formatMessage(messages.movierequestlimit)}
                        </span>
                      </label>
                      <div className="form-input-area">
                        <div className="flex flex-col">
                          <div className="mb-4 flex items-center">
                            <input
                              type="checkbox"
                              checked={movieQuotaEnabled}
                              onChange={() => setMovieQuotaEnabled((s) => !s)}
                            />
                            <span className="ml-2 text-gray-300">
                              {intl.formatMessage(messages.enableOverride)}
                            </span>
                          </div>
                          <QuotaSelector
                            isDisabled={!movieQuotaEnabled}
                            dayFieldName="movieQuotaDays"
                            limitFieldName="movieQuotaLimit"
                            mediaType="movie"
                            onChange={setFieldValue}
                            defaultDays={values.movieQuotaDays}
                            defaultLimit={values.movieQuotaLimit}
                            dayOverride={
                              !movieQuotaEnabled
                                ? data?.globalMovieQuotaDays
                                : undefined
                            }
                            limitOverride={
                              !movieQuotaEnabled
                                ? data?.globalMovieQuotaLimit
                                : undefined
                            }
                          />
                        </div>
                      </div>
                    </div>
                    <div className="form-row">
                      <label htmlFor="tvQuotaLimit" className="text-label">
                        <span>
                          {intl.formatMessage(messages.seriesrequestlimit)}
                        </span>
                      </label>
                      <div className="form-input-area">
                        <div className="flex flex-col">
                          <div className="mb-4 flex items-center">
                            <input
                              type="checkbox"
                              checked={tvQuotaEnabled}
                              onChange={() => setTvQuotaEnabled((s) => !s)}
                            />
                            <span className="ml-2 text-gray-300">
                              {intl.formatMessage(messages.enableOverride)}
                            </span>
                          </div>
                          <QuotaSelector
                            isDisabled={!tvQuotaEnabled}
                            dayFieldName="tvQuotaDays"
                            limitFieldName="tvQuotaLimit"
                            mediaType="tv"
                            onChange={setFieldValue}
                            defaultDays={values.tvQuotaDays}
                            defaultLimit={values.tvQuotaLimit}
                            dayOverride={
                              !tvQuotaEnabled
                                ? data?.globalTvQuotaDays
                                : undefined
                            }
                            limitOverride={
                              !tvQuotaEnabled
                                ? data?.globalTvQuotaLimit
                                : undefined
                            }
                          />
                        </div>
                      </div>
                    </div>
                  </>
                )}
              {hasPermission(
                [Permission.AUTO_REQUEST, Permission.AUTO_REQUEST_MOVIE],
                { type: 'or' }
              ) &&
                user?.userType === UserType.PLEX && (
                  <div className="form-row">
                    <label
                      htmlFor="watchlistSyncMovies"
                      className="checkbox-label"
                    >
                      <span>
                        {intl.formatMessage(messages.plexwatchlistsyncmovies)}
                      </span>
                      <span className="label-tip">
                        {intl.formatMessage(
                          messages.plexwatchlistsyncmoviestip,
                          {
                            PlexWatchlistSupportLink: (
                              msg: React.ReactNode
                            ) => (
                              <a
                                href="https://support.plex.tv/articles/universal-watchlist/"
                                className="text-white transition duration-300 hover:underline"
                                target="_blank"
                                rel="noreferrer"
                              >
                                {msg}
                              </a>
                            ),
                          }
                        )}
                      </span>
                    </label>
                    <div className="form-input-area">
                      <Field
                        type="checkbox"
                        id="watchlistSyncMovies"
                        name="watchlistSyncMovies"
                        onChange={() => {
                          setFieldValue(
                            'watchlistSyncMovies',
                            !values.watchlistSyncMovies
                          );
                        }}
                      />
                    </div>
                  </div>
                )}
              {hasPermission(
                [Permission.AUTO_REQUEST, Permission.AUTO_REQUEST_TV],
                { type: 'or' }
              ) &&
                user?.userType === UserType.PLEX && (
                  <div className="form-row">
                    <label htmlFor="watchlistSyncTv" className="checkbox-label">
                      <span>
                        {intl.formatMessage(messages.plexwatchlistsyncseries)}
                      </span>
                      <span className="label-tip">
                        {intl.formatMessage(
                          messages.plexwatchlistsyncseriestip,
                          {
                            PlexWatchlistSupportLink: (
                              msg: React.ReactNode
                            ) => (
                              <a
                                href="https://support.plex.tv/articles/universal-watchlist/"
                                className="text-white transition duration-300 hover:underline"
                                target="_blank"
                                rel="noreferrer"
                              >
                                {msg}
                              </a>
                            ),
                          }
                        )}
                      </span>
                    </label>
                    <div className="form-input-area">
                      <Field
                        type="checkbox"
                        id="watchlistSyncTv"
                        name="watchlistSyncTv"
                        onChange={() => {
                          setFieldValue(
                            'watchlistSyncTv',
                            !values.watchlistSyncTv
                          );
                        }}
                      />
                    </div>
                  </div>
                )}
              <div className="actions">
                <div className="flex justify-end">
                  <span className="ml-3 inline-flex rounded-md shadow-sm">
                    <Button
                      buttonType="primary"
                      type="submit"
                      disabled={isSubmitting || !isValid}
                    >
                      <ArrowDownOnSquareIcon />
                      <span>
                        {isSubmitting
                          ? intl.formatMessage(globalMessages.saving)
                          : intl.formatMessage(globalMessages.save)}
                      </span>
                    </Button>
                  </span>
                </div>
              </div>
            </Form>
          );
        }}
      </Formik>
    </>
  );
};

export default UserGeneralSettings;
