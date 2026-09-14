/**
 * The APK ships with the site itself (frontend/public/downloads), so the link
 * works on whatever domain serves the page - the Vercel site, or the laptop's
 * IP during a demo - and needs no third-party host. Absolute, because it is
 * also used as the Android intent fallback and encoded into the QR code.
 */
const SITE_APK_PATH = '/downloads/AgriFair.apk';

const siteApkUrl = () =>
  typeof window !== 'undefined' ? `${window.location.origin}${SITE_APK_PATH}` : SITE_APK_PATH;

/**
 * Turns a Google Drive share link into one that downloads the file itself.
 *
 * A share link opens Drive's preview page, and the older `uc?export=download`
 * form stops at "can't scan this file for viruses" for anything over 100 MB -
 * the APK is about 120 MB. `drive.usercontent.google.com` with `confirm=t`
 * skips both and sends the APK. Links that are not Drive pass through as-is.
 */
export function toDirectDownload(url) {
  const id = url.match(/drive\.google\.com\/file\/d\/([^/?#]+)/)?.[1]
    || url.match(/drive\.google\.com\/(?:uc|open)\?(?:.*&)?id=([^&#]+)/)?.[1];

  return id
    ? `https://drive.usercontent.google.com/download?id=${id}&export=download&confirm=t`
    : url;
}

/**
 * The APK itself. Set VITE_APP_DOWNLOAD_URL only to host it somewhere else; a
 * Drive share link there is turned into a direct download.
 */
const override = import.meta.env.VITE_APP_DOWNLOAD_URL?.trim();
export const APP_DOWNLOAD_URL = override ? toDirectDownload(override) : siteApkUrl();

/** The Android applicationId in mobile/android/app/build.gradle.kts. */
const ANDROID_PACKAGE = 'com.example.mobile_app';

const isAndroid = () =>
  typeof navigator !== 'undefined' && /android/i.test(navigator.userAgent);

/**
 * A link that opens the AgriFair app on its sign-in screen.
 *
 * On Android it is an intent URL. With `fallbackToDownload`, a phone without
 * the app goes to the download - right for a button somebody tapped. Without
 * it, nothing happens when the app is missing, which is what an automatic
 * attempt needs: the page stays put and can offer the download itself.
 *
 * The package is only named alongside the fallback. Naming it alone sends a
 * phone without the app to the Play Store, where this app is not listed.
 */
export function openAppHref({ fallbackToDownload = true } = {}) {
  if (!isAndroid()) return 'agrifair://signin';

  const extras = fallbackToDownload
    ? `package=${ANDROID_PACKAGE};S.browser_fallback_url=${encodeURIComponent(APP_DOWNLOAD_URL)};`
    : '';

  return `intent://signin#Intent;scheme=agrifair;${extras}end`;
}

/**
 * Tries to open the app without a tap, and reports whether it did.
 *
 * A browser cannot ask whether an app is installed. What it can see is the
 * page being hidden when the app comes to the front - so no hide within the
 * wait means the app is not there (or the browser refused to open it).
 */
export function tryOpenApp({ waitMs = 1800 } = {}) {
  return new Promise((resolve) => {
    let settled = false;

    const finish = (opened) => {
      if (settled) return;
      settled = true;
      document.removeEventListener('visibilitychange', onHide);
      window.removeEventListener('pagehide', onPageHide);
      window.removeEventListener('blur', onBlur);
      clearTimeout(timer);
      resolve(opened);
    };

    const onHide = () => {
      if (document.visibilityState === 'hidden') finish(true);
    };
    const onPageHide = () => finish(true);
    const onBlur = () => finish(true);

    document.addEventListener('visibilitychange', onHide);
    window.addEventListener('pagehide', onPageHide);
    window.addEventListener('blur', onBlur);
    const timer = setTimeout(() => finish(false), waitMs);

    window.location.href = openAppHref({ fallbackToDownload: false });
  });
}
