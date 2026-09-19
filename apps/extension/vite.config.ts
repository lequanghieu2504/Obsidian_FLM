import { defineConfig } from 'vite';

export default defineConfig({
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    rollupOptions: {
      input: {
        background: 'src/background/index.ts',
        content: 'src/content/flm-content-script.ts',
        popup: 'popup.html',
      },
      output: { entryFileNames: '[name].js' },
    },
  },
});
