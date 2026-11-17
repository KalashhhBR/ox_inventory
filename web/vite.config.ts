import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  base: './',
  publicDir: false,
  build: {
    outDir: 'build',
    target: 'esnext',
    emptyOutDir: true,
    rolldownOptions: {
      output: {
        // klsh: flat output (no assets/ folder) so deploy tools can reach the files
        assetFileNames: '[name][extname]',
        entryFileNames: '[name].js',
        chunkFileNames: '[name].js',
      },
    },
  },
});
