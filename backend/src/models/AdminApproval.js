import mongoose from 'mongoose';

const adminApprovalSchema = new mongoose.Schema({
  adminId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  status: {
    type: String,
    enum: ['pending', 'approved', 'rejected'],
    default: 'pending',
  },
  approvedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
  },
  approvedAt: {
    type: Date,
  }
}, { timestamps: true });

const AdminApproval = mongoose.model('AdminApproval', adminApprovalSchema);
export default AdminApproval;
