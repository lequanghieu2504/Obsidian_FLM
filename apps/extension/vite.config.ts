import { defineConfig } from 'vite';

export default defineConfig({
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    rollupOptions: {
      input: 'src/background/index.ts',
      output: { entryFileNames: 'background.js' },
    },
  },
});
