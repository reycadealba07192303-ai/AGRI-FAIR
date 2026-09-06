import User from '../models/User.js';

export const findUserByUserId = async (userId) => {
  return User.findOne({ userId }).select('+password');
};

export const findUserByUserIdSafe = async (userId) => {
  return User.findOne({ userId });
};

export const updateUserByUserId = async (userId, data) => {
  return User.findOneAndUpdate(
    { userId },
    data,
    { new: true }
  ).select('-password');
};

export const updatePasswordByUserId = async (userId, hashedPassword) => {
  return User.findOneAndUpdate(
    { userId },
    { password: hashedPassword },
    { new: true }
  );
};