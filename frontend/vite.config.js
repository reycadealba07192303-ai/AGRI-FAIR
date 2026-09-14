import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    react({
      babel: {
        plugins: [['babel-plugin-react-compiler']],
      },
    }),
  ],
  // Listen on the LAN too, so a phone on the same Wi-Fi can open the site -
  // the rider activation link points at the laptop's IP.
  server: {
    host: true,
  },
})
