# PM3 GUI - Tauri 2 + Vue 3 + TypeScript

A modern Proxmark3 client built with Tauri 2, Vue 3, TypeScript, Element Plus, and xterm.js.

## Tech Stack

- **Frontend**: Vue 3 + TypeScript + Vite
- **UI Framework**: Element Plus
- **State Management**: Pinia
- **Routing**: Vue Router
- **Terminal**: xterm.js
- **Desktop**: Tauri 2

## Development

```bash
# Install dependencies
npm install

# Run in development mode
npm run tauri dev

# Build for production
npm run tauri build
```

## Project Structure

```
pm3gui-tauri/
├── src/                  # Vue frontend
│   ├── views/           # Page components
│   ├── router/          # Vue Router config
│   ├── stores/          # Pinia stores
│   ├── App.vue          # Root component
│   └── main.ts          # Entry point
├── src-tauri/           # Rust backend
│   ├── src/
│   │   ├── lib.rs       # Tauri commands & app setup
│   │   └── main.rs      # Entry point
│   ├── capabilities/    # Tauri v2 permissions
│   └── tauri.conf.json  # Tauri configuration
├── package.json
├── vite.config.ts
└── tsconfig.json
```
