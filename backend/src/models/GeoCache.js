import mongoose from 'mongoose';

/**
 * Places we have already looked up.
 *
 * Barangays do not move, so a lookup is worth keeping forever. This exists as
 * much for the tile service as for us: Nominatim is free and asks in return
 * that callers do not re-ask the same question, and one barangay serves every
 * buyer who lives in it.
 *
 * A miss is cached too - `found: false` - so a barangay that OpenStreetMap has
 * never heard of is asked about once rather than on every address that names
 * it.
 */
const geoCacheSchema = new mongoose.Schema({
  /** The normalised query: lowercased "barangay|city|province". */
  key: { type: String, required: true, unique: true, index: true },
  found: { type: Boolean, required: true },
  lat: { type: Number, default: null },
  lng: { type: Number, default: null },
  /** What OpenStreetMap called the place, kept for when a pin looks wrong. */
  displayName: { type: String, default: '' },
  lookedUpAt: { type: Date, default: Date.now },
});

export default mongoose.model('GeoCache', geoCacheSchema);
