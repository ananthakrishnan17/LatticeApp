import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import App from './App.tsx'
import { appBasePath } from './config/appBasePath.ts'
import { AuthProvider } from './context/AuthContext.tsx'
import { GridNavigationProvider } from './context/GridNavigationContext.tsx'
import './index.css'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <BrowserRouter basename={appBasePath}>
      <GridNavigationProvider>
        <AuthProvider>
          <App />
        </AuthProvider>
      </GridNavigationProvider>
    </BrowserRouter>
  </StrictMode>,
)
