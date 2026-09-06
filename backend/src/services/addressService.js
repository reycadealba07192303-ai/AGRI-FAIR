import { findUserByUserId } from '../repositories/userRepository.js';

/**
 * A buyer's saved delivery addresses.
 *
 * The rule the whole thing rests on: exactly one address is the default, and
 * the list is never left without one. Checkout reads that default, so two of
 * them - or none - means it has to guess.
 */
function assertOneDefault(addresses) {
  if (!addresses.length) return;
  if (addresses.some((a) => a.isDefault)) return;

  // The list lost its default - the one marked was deleted. The first one
  // takes over rather than leaving checkout with nothing to preselect.
  addresses[0].isDefault = true;
}

function clean(payload = {}) {
  const text = (value) => (typeof value === 'string' ? value.trim() : '');

  return {
    label: text(payload.label) || 'Home',
    fullName: text(payload.fullName),
    contact: text(payload.contact),
    line: text(payload.line),
    barangay: text(payload.barangay),
    city: text(payload.city),
    province: text(payload.province),
    notes: text(payload.notes),
  };
}

function validate(fields) {
  if (!fields.fullName) throw new Error('Who is receiving this? Add a name.');
  if (!fields.contact) throw new Error('Add a contact number for the rider.');
  if (!fields.line) throw new Error('Add the street or purok.');
  if (!fields.city) throw new Error('Add the city or municipality.');
}

export const addressService = {
  async list(userId) {
    const user = await findUserByUserId(userId);
    if (!user) throw new Error('User not found');

    return user.addresses || [];
  },

  async add(userId, payload) {
    const user = await findUserByUserId(userId);
    if (!user) throw new Error('User not found');

    const fields = clean(payload);
    validate(fields);

    // The first address saved is the default whatever the caller asked for -
    // a list of one with no default would leave checkout empty.
    const makeDefault = payload.isDefault === true || user.addresses.length === 0;

    if (makeDefault) {
      for (const existing of user.addresses) {
        existing.isDefault = false;
      }
    }

    user.addresses.push({ ...fields, isDefault: makeDefault });
    assertOneDefault(user.addresses);
    await user.save();

    return user.addresses;
  },

  async update(userId, addressId, payload) {
    const user = await findUserByUserId(userId);
    if (!user) throw new Error('User not found');

    const address = user.addresses.id(addressId);
    if (!address) throw new Error('Address not found');

    const fields = clean({ ...address.toObject(), ...payload });
    validate(fields);

    address.set(fields);

    if (payload.isDefault === true) {
      for (const other of user.addresses) {
        other.isDefault = other._id.equals(address._id);
      }
    }

    assertOneDefault(user.addresses);
    await user.save();

    return user.addresses;
  },

  async remove(userId, addressId) {
    const user = await findUserByUserId(userId);
    if (!user) throw new Error('User not found');

    const address = user.addresses.id(addressId);
    if (!address) throw new Error('Address not found');

    address.deleteOne();
    assertOneDefault(user.addresses);
    await user.save();

    return user.addresses;
  },
};
