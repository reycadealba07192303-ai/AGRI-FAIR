import GeoCache from '../models/GeoCache.js';

/**
 * Turns a barangay, city and province into a point on the map.
 *
 * Only the structured part of an address is ever sent. The street line is not:
 * "Blk 48 Lot 71 (white house po bahay namin)" resolves to somewhere confident
 * and wrong, and a rider trusting that ends up further from the door than if
 * they had simply read the words.
 *
 * Barangay level is the right level. It puts the pin in the right part of the
 * right town, which is how a delivery here actually works - the rider gets to
 * the barangay by map and the rest by landmark. It is marked approximate
 * everywhere it is shown, so nobody mistakes it for the door.
 *
 * OpenStreetMap's Nominatim, the same data behind the map tiles. Free, no API
 * key, and used within its terms: a real User-Agent, one request at a time,
 * and every answer cached so a place is asked about once.
 */

const NOMINATIM = 'https://nominatim.openstreetmap.org/search';

// Nominatim asks for an identifying User-Agent and no more than one request a
// second. Both are conditions of use, not suggestions.
const USER_AGENT = 'AgriFair/1.0 (capstone project; rice marketplace)';
const MIN_GAP_MS = 1100;
const TIMEOUT_MS = 5000;

let lastCallAt = 0;
let queue = Promise.resolve();

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/** Serialises calls and keeps a second between them, whoever asks. */
function polite(task) {
  queue = queue.then(async () => {
    const since = Date.now() - lastCallAt;
    if (since < MIN_GAP_MS) await wait(MIN_GAP_MS - since);
    lastCallAt = Date.now();
    return task();
  }, task);

  return queue;
}

const clean = (value) => (typeof value === 'string' ? value.trim() : '');

function cacheKey({ barangay, city, province }) {
  return [barangay, city, province]
    .map((p) => clean(p).toLowerCase())
    .join('|');
}

async function askNominatim(query) {
  const url = new URL(NOMINATIM);
  url.searchParams.set('format', 'json');
  url.searchParams.set('limit', '1');
  url.searchParams.set('countrycodes', 'ph');
  url.searchParams.set('q', query);

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);

  try {
    const res = await fetch(url, {
      headers: { 'User-Agent': USER_AGENT, Accept: 'application/json' },
      signal: controller.signal,
    });

    if (!res.ok) return null;

    const rows = await res.json();
    if (!Array.isArray(rows) || !rows.length) return null;

    const lat = Number(rows[0].lat);
    const lng = Number(rows[0].lon);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;

    return { lat, lng, displayName: rows[0].display_name || '' };
  } catch {
    // Offline, timed out, or rate limited. An address without a pin is still
    // a deliverable address, so this is never fatal.
    return null;
  } finally {
    clearTimeout(timer);
  }
}

/**
 * The approximate point for an address, or null.
 *
 * Tries the barangay first and falls back to the town, because a barangay
 * OpenStreetMap has not mapped should still put the buyer in the right
 * municipality rather than nowhere at all.
 */
export async function locateArea({ barangay, city, province }) {
  const town = clean(city);
  if (!town) return null;

  const key = cacheKey({ barangay, city, province });

  const cached = await GeoCache.findOne({ key });
  if (cached) {
    return cached.found ? { lat: cached.lat, lng: cached.lng } : null;
  }

  const parts = [clean(barangay), town, clean(province), 'Philippines'].filter(Boolean);

  let hit = await polite(() => askNominatim(parts.join(', ')));

  // Barangay unknown to the map: the town on its own is still worth having.
  if (!hit && clean(barangay)) {
    hit = await polite(() =>
      askNominatim([town, clean(province), 'Philippines'].filter(Boolean).join(', ')),
    );
  }

  try {
    await GeoCache.create({
      key,
      found: Boolean(hit),
      lat: hit?.lat ?? null,
      lng: hit?.lng ?? null,
      displayName: hit?.displayName || '',
    });
  } catch {
    // A racing write got there first. The answer is the same either way.
  }

  return hit ? { lat: hit.lat, lng: hit.lng } : null;
}
