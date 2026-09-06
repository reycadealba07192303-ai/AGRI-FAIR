import express from 'express';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DATA_DIR = path.join(__dirname, '../data');

/**
 * Philippine places, for the address picker.
 *
 * Read once into memory at startup: the three files are half a megabyte
 * together, and reading them from disk on every keystroke in a picker would be
 * the slowest part of typing an address.
 *
 * Built by src/scripts/buildPsgc.js from the PSA's PSGC. Rebuild when it is
 * republished - places are created and renamed every few years.
 */
function load(name) {
  try {
    return JSON.parse(fs.readFileSync(path.join(DATA_DIR, name), 'utf-8'));
  } catch (err) {
    console.error(
      `[geo] could not read ${name}. Run: node src/scripts/buildPsgc.js`,
      err.message
    );
    return null;
  }
}

const provinces = load('psgc-provinces.json') || [];
const citiesByProvince = load('psgc-cities.json') || {};
const barangaysByCity = load('psgc-barangays.json') || {};

const router = express.Router();

const send = (res, data) => res.json({ success: true, data });

// Public: someone filling in a delivery address has not necessarily signed in
// yet, and there is nothing private about the list of Philippine towns.
router.get('/provinces', (req, res) => send(res, provinces));

router.get('/provinces/:code/cities', (req, res) => {
  const cities = citiesByProvince[req.params.code];

  if (!cities) {
    return res.status(404).json({
      success: false,
      message: 'No cities listed for that province.',
    });
  }

  return send(res, cities);
});

router.get('/cities/:code/barangays', (req, res) => {
  const barangays = barangaysByCity[req.params.code];

  if (!barangays) {
    return res.status(404).json({
      success: false,
      message: 'No barangays listed for that city or municipality.',
    });
  }

  return send(res, barangays);
});

/** Says whether the data was built, so a missing file is visible early. */
router.get('/', (req, res) =>
  send(res, {
    provinces: provinces.length,
    provincesWithCities: Object.keys(citiesByProvince).length,
    citiesWithBarangays: Object.keys(barangaysByCity).length,
    ready: provinces.length > 0,
  })
);

export default router;
