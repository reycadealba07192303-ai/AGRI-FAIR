import os from 'node:os'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

/**
 * The laptop's address on the local network, for the dev server only.
 *
 * Opened as localhost, the landing page would put "localhost" into its QR code
 * and download link - which, scanned by a phone, is the phone itself. With
 * this, the page swaps in the laptop's Wi-Fi address so a phone on the same
 * network can scan and install. Production builds get an empty value and use
 * the site's own address.
 */
function lanAddress() {
  const candidates = Object.entries(os.networkInterfaces())
    .flatMap(([name, addrs]) => (addrs || []).map((a) => ({ name, ...a })))
    .filter((a) => a.family === 'IPv4' && !a.internal)
    .filter((a) => /^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/.test(a.address))
    // Virtual adapters (WSL, Docker, VPNs) are rarely what the phone can reach.
    .filter((a) => !/vethernet|virtual|vmware|docker|wsl|tailscale|zerotier/i.test(a.name));

  const wifi = candidates.find((a) => /wi-?fi|wlan|wireless/i.test(a.name));
  return (wifi || candidates[0])?.address || ''
}

// https://vite.dev/config/
export default defineConfig(({ command }) => ({
  plugins: [
    react({
      babel: {
        plugins: [['babel-plugin-react-compiler']],
      },
    }),
  ],
  define: {
    __AGRIFAIR_LAN_HOST__: JSON.stringify(command === 'serve' ? lanAddress() : ''),
  },
  // Listen on the LAN too, so a phone on the same Wi-Fi can open the site -
  // the rider activation link points at the laptop's IP.
  server: {
    host: true,
  },
}))
