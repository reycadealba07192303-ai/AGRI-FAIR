import axios from 'axios';

const BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8080/api';
export const API_ORIGIN = BASE_URL.replace(/\/api\/?$/, '');

const API = axios.create({
  baseURL: BASE_URL,
  withCredentials: true
});

API.interceptors.request.use((config) => {
  const token = sessionStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

/**
 * Axios only fills `err.response` when the server actually answered. Without this,
 * a stopped backend or a CORS rejection collapsed into a bare "Login failed".
 */
export function getErrorMessage(err, fallback = 'Something went wrong. Please try again.') {
  const serverMessage = err?.response?.data?.message;
  if (serverMessage) return serverMessage;

  if (err?.response) {
    return `${fallback} (server responded ${err.response.status} ${err.response.statusText || ''})`.trim();
  }

  if (err?.code === 'ECONNABORTED') {
    return 'The server took too long to respond. Please try again.';
  }

  if (err?.request) {
    return `Cannot reach the AgriFair server at ${API_ORIGIN}. Make sure the backend is running (cd backend && npm run dev).`;
  }

  return err?.message || fallback;
}

export const registerUser = (data) => API.post('/auth/register', data);
export const loginUser = (data) => API.post('/auth/login', data);
export const logoutUser = () => API.post('/auth/logout');
export const resendVerificationEmail = (email) =>
  API.post('/auth/resend-verification', { email });

export default API;
