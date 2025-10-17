# React + TypeScript + Vite

This template provides a minimal setup to get React working in Vite with HMR and some ESLint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) uses [Babel](https://babeljs.io/) (or [oxc](https://oxc.rs) when used in [rolldown-vite](https://vite.dev/guide/rolldown)) for Fast Refresh
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) uses [SWC](https://swc.rs/) for Fast Refresh

## React Compiler

The React Compiler is not enabled on this template because of its impact on dev & build performances. To add it, see [this documentation](https://react.dev/learn/react-compiler/installation).

## Expanding the ESLint configuration

If you are developing a production application, we recommend updating the configuration to enable type-aware lint rules:

# Power Pages SPA - Part 1: Deploying SPA to Power Pages

This project demonstrates how to create and deploy a React Single Page Application (SPA) to Power Pages. This is Part 1 of a two-part series focusing on the deployment process and basic SPA setup.

## 🎯 What You'll Learn

- How to create a React TypeScript SPA with Vite
- How to build and prepare your SPA for Power Pages deployment
- How to integrate your SPA with Power Pages infrastructure
- Best practices for Power Pages SPA development

## 🚀 Tech Stack

- **React 19** - Modern React with latest features
- **TypeScript** - Type-safe development
- **Vite** - Fast build tool and dev server
- **React Router DOM** - Client-side routing
- **ESLint** - Code linting and quality

## 📋 Prerequisites

- Node.js (version 18 or higher)
- npm or yarn package manager
- Power Apps environment with Power Pages enabled
- Basic knowledge of React and TypeScript

## 🛠️ Getting Started

### 1. Install Dependencies

```bash
npm install
```

### 2. Start Development Server

```bash
npm run dev
```

The application will be available at `http://localhost:5173`

### 3. Build for Production

```bash
npm run build
```

This creates a `dist` folder with optimized production files.

## 📁 Project Structure

```
├── src/
│   ├── components/     # React components
│   ├── pages/         # Page components
│   ├── hooks/         # Custom React hooks
│   ├── utils/         # Utility functions
│   └── main.tsx       # Application entry point
├── public/            # Static assets
├── dist/              # Production build output
└── .powerpages-site/  # Power Pages configuration
```

## 🌐 Deploying to Power Pages

### Step 1: Build Your Application

```bash
npm run build
```

### Step 2: Upload to Power Pages

1. Open your Power Pages site in the design studio
2. Navigate to the **Code** section
3. Upload the contents of the `dist` folder
4. Configure your main page to serve the `index.html`

### Step 3: Configure Routing

For client-side routing to work properly in Power Pages:

1. Set up URL rewriting rules
2. Configure the Power Pages site to serve your SPA for all routes
3. Ensure proper fallback to `index.html`

## 🔧 Available Scripts

| Script            | Description                              |
| ----------------- | ---------------------------------------- |
| `npm run dev`     | Start development server with hot reload |
| `npm run build`   | Build production-ready application       |
| `npm run lint`    | Run ESLint to check code quality         |
| `npm run preview` | Preview production build locally         |

## 📝 Development Guidelines

### File Organization

- Keep components modular and reusable
- Use TypeScript interfaces for type definitions
- Organize files by feature, not by file type

### Styling

- Use CSS modules or styled-components for component styling
- Follow consistent naming conventions
- Keep styles co-located with components

### Routing

- Use React Router for client-side navigation
- Implement proper route guards if needed
- Consider lazy loading for better performance

## 🚧 Common Issues & Solutions

### Build Issues

- Ensure all dependencies are installed
- Check TypeScript configuration for errors
- Verify build output in `dist` folder

### Power Pages Integration

- Check file upload limits in Power Pages
- Verify proper MIME type configurations
- Ensure static assets are properly referenced

## 🔗 Related Resources

- [Power Pages Documentation](https://docs.microsoft.com/power-pages/)
- [React Documentation](https://react.dev/)
- [Vite Documentation](https://vitejs.dev/)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)

## 📈 Next Steps

Once you've successfully deployed your basic SPA, continue to **Part 2** to learn about:

- Adding authentication to your Power Pages SPA
- Integrating with Power Platform services
- Securing your application with proper authentication flows

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is part of the Power Platform learning series and is available for educational purposes.

You can also install [eslint-plugin-react-x](https://github.com/Rel1cx/eslint-react/tree/main/packages/plugins/eslint-plugin-react-x) and [eslint-plugin-react-dom](https://github.com/Rel1cx/eslint-react/tree/main/packages/plugins/eslint-plugin-react-dom) for React-specific lint rules:

```js
// eslint.config.js
import reactX from "eslint-plugin-react-x";
import reactDom from "eslint-plugin-react-dom";

export default defineConfig([
  globalIgnores(["dist"]),
  {
    files: ["**/*.{ts,tsx}"],
    extends: [
      // Other configs...
      // Enable lint rules for React
      reactX.configs["recommended-typescript"],
      // Enable lint rules for React DOM
      reactDom.configs.recommended,
    ],
    languageOptions: {
      parserOptions: {
        project: ["./tsconfig.node.json", "./tsconfig.app.json"],
        tsconfigRootDir: import.meta.dirname,
      },
      // other options...
    },
  },
]);
```
