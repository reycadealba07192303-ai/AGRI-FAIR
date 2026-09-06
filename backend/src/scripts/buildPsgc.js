/**
 * Turns the PSA's Philippine Standard Geographic Code into the three files
 * the address picker reads.
 *
 * Run when the PSGC is republished:
 *   node src/scripts/buildPsgc.js
 *
 * The point of a build step is that the data is fetched and checked once, here,
 * rather than the app depending on someone else's API every time a person types
 * an address. Source: https://psgc.gitlab.io/api
 */
import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT_DIR = path.join(__dirname, '../data');
const API = 'https://psgc.gitlab.io/api';

/**
 * NCR has no province - its cities hang off districts - so the picker needs a
 * stand-in, or seventeen cities are unreachable in a province-then-city flow.
 */
const METRO_MANILA = { code: 'NCR', name: 'Metro Manila' };
const NCR_REGION = '130000000';

/**
 * Two cities belong to no province in the PSGC, and both would be unreachable
 * in a province-then-city picker without a home.
 *
 * Isabela City is administratively under Region IX but sits on Basilan.
 * Cotabato City is under Region XII and surrounded by Maguindanao. In each
 * case the second is where someone living there would look.
 */
const PARENTLESS = {
  '099701000': '150700000', // Isabela City   -> Basilan
  '129804000': '153800000', // Cotabato City  -> Maguindanao
};

async function get(pathname) {
  const response = await fetch(`${API}/${pathname}/`);
  if (!response.ok) {
    throw new Error(`PSGC ${pathname} responded ${response.status}`);
  }
  return response.json();
}

/** Sorted by name, since that is the order the picker shows them in. */
const byName = (a, b) => a.name.localeCompare(b.name);

async function build() {
  console.log('fetching...');

  const [provinces, cities, barangays] = await Promise.all([
    get('provinces'),
    get('cities-municipalities'),
    get('barangays'),
  ]);

  console.log(
    `  ${provinces.length} provinces, ${cities.length} cities, ${barangays.length} barangays`
  );

  const provinceList = [
    ...provinces.map((p) => ({ code: p.code, name: p.name })),
    METRO_MANILA,
  ].sort(byName);

  const parentOf = (city) => {
    if (city.provinceCode) return city.provinceCode;
    if (PARENTLESS[city.code]) return PARENTLESS[city.code];
    if (city.regionCode === NCR_REGION) return METRO_MANILA.code;
    return null;
  };

  const citiesByProvince = {};
  let orphanCities = 0;

  for (const city of cities) {
    const parent = parentOf(city);
    if (!parent) {
      orphanCities += 1;
      continue;
    }

    (citiesByProvince[parent] ??= []).push({
      code: city.code,
      name: city.name,
      ...(city.oldName ? { oldName: city.oldName } : {}),
    });
  }

  for (const list of Object.values(citiesByProvince)) list.sort(byName);

  const barangaysByCity = {};
  let orphanBarangays = 0;

  for (const barangay of barangays) {
    // A barangay's parent is its city or municipality; a handful sit directly
    // under a sub-municipality of Manila, which carries the city code anyway.
    const parent = barangay.cityCode || barangay.municipalityCode;
    if (!parent) {
      orphanBarangays += 1;
      continue;
    }

    // Only the name is stored. Nothing addresses a barangay by code here, and
    // keeping the codes roughly doubles the file for no use.
    (barangaysByCity[parent] ??= []).push(barangay.name);
  }

  for (const list of Object.values(barangaysByCity)) list.sort();

  await fs.mkdir(OUT_DIR, { recursive: true });

  await fs.writeFile(
    path.join(OUT_DIR, 'psgc-provinces.json'),
    JSON.stringify(provinceList)
  );
  await fs.writeFile(
    path.join(OUT_DIR, 'psgc-cities.json'),
    JSON.stringify(citiesByProvince)
  );
  await fs.writeFile(
    path.join(OUT_DIR, 'psgc-barangays.json'),
    JSON.stringify(barangaysByCity)
  );

  const size = async (name) =>
    `${Math.round((await fs.stat(path.join(OUT_DIR, name))).size / 1024)} KB`;

  console.log('\nwritten to src/data:');
  console.log(`  provinces  ${provinceList.length}  ${await size('psgc-provinces.json')}`);
  console.log(
    `  cities     ${Object.keys(citiesByProvince).length} provinces covered  ${await size('psgc-cities.json')}`
  );
  console.log(
    `  barangays  ${Object.keys(barangaysByCity).length} cities covered  ${await size('psgc-barangays.json')}`
  );

  // Silence here would mean the shapes changed and places went missing without
  // anyone noticing.
  if (orphanCities) console.warn(`\n⚠ ${orphanCities} cities had no parent province`);
  if (orphanBarangays) console.warn(`⚠ ${orphanBarangays} barangays had no parent city`);

  const covered = new Set(Object.keys(citiesByProvince));
  const empty = provinceList.filter((p) => !covered.has(p.code));
  if (empty.length) {
    console.warn(`⚠ ${empty.length} provinces have no cities: ${empty.map((p) => p.name).join(', ')}`);
  }
}

build().catch((err) => {
  console.error(err);
  process.exit(1);
});
