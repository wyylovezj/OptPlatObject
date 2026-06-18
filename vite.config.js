import { fileURLToPath, URL } from 'node:url'

import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueDevTools from 'vite-plugin-vue-devtools'
import fs from 'node:fs'
import path from 'node:path'

function excludePublicFile(files) {
  return {
    name: 'exclude-public-file',
    apply: 'build',
    closeBundle() {
      for (const file of files) {
        const filePath = path.resolve('dist', file)
        if (fs.existsSync(filePath)) {
          fs.unlinkSync(filePath)
        }
      }
    }
  }
}

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    vue(),
    vueDevTools(),
    excludePublicFile(['configuration.js'])
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    },
  },
})
