import mongoose from 'mongoose';

const adminAuditLogSchema = new mongoose.Schema({
  adminId: {
    // Changed from ObjectId to Number to match your simple integer userId
    type: Number, 
    required: true,
  },
  action: {
    type: String,
    required: true,
  },
  targetId: {
    // Changed from ObjectId to Number to allow "1", "2", etc.
    type: Number, 
    required: true, 
  },
  details: {
    type: String,
  },
  // Snapshotted at write time so the log stays readable after the user is deleted.
  targetEmail: {
    type: String,
    default: '',
  },
  targetName: {
    type: String,
    default: '',
  },
  targetRole: {
    type: String,
    default: '',
  },
}, { timestamps: true });

const AdminAuditLog = mongoose.model('AdminAuditLog', adminAuditLogSchema);
export default AdminAuditLog;