import API from './authApi';

export const fetchAllUsers = () => API.get('/superadmin/users');
export const suspendUser = (id) => API.put(`/superadmin/users/${id}/suspend`);
export const activateUser = (id) => API.put(`/superadmin/users/${id}/activate`);
export const deleteUserAccount = (id) => API.delete(`/superadmin/users/${id}`);
export const fetchPendingApprovals = () => API.get('/superadmin/approvals/pending');
export const approveSeller = (id) => API.put(`/superadmin/approvals/${id}/approve`);
export const createUserAccount = (data) => API.post('/superadmin/users', data);
export const updateUserAccount = (id, data) => API.put(`/superadmin/users/${id}`, data);
export const fetchAuditLogs = (params) => API.get('/superadmin/audit-logs', { params });
export const fetchUserAnalytics = (id) => API.get(`/superadmin/users/${id}/analytics`);
export const fetchPlatformRevenue = () => API.get('/superadmin/analytics/revenue');
export const fetchBusinessAnalytics = () => API.get('/superadmin/analytics/businesses');
