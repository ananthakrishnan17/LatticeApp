import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { appBasePath } from '../config/appBasePath'
import { extractApiError } from '../api/client'
import Spinner from '../components/Spinner'
import { useAuth } from '../context/AuthContext'
import useTranslation from '../hooks/useTranslation'

interface FormValues {
  username: string
  password: string
}

interface FormErrors {
  username?: string
  password?: string
}

function LoginPage() {
  const { baseUrl, isAuthenticated, loading, login, username } = useAuth()
  const { t } = useTranslation()
  const navigate = useNavigate()
  const [form, setForm] = useState<FormValues>({
    username: username ?? '',
    password: '',
  })
  const [fieldErrors, setFieldErrors] = useState<FormErrors>({})
  const [error, setError] = useState('')
  const [submitting, setSubmitting] = useState(false)

  const backendUrlLooksWrong = (() => {
    if (!baseUrl) return false
    try {
      const url = new URL(baseUrl)
      if (url.origin !== window.location.origin) return false
      const normalizedPath = url.pathname.replace(/\/+$/, '') || '/'
      const normalizedAppPath = appBasePath.replace(/\/+$/, '') || '/'
      return normalizedPath === normalizedAppPath
    } catch {
      return false
    }
  })()
  
  const canAttemptLogin = Boolean(baseUrl) && !backendUrlLooksWrong

  useEffect(() => {
    if (isAuthenticated && !loading) {
      navigate('/pos', { replace: true })
    }
  }, [isAuthenticated, loading, navigate])

  const validate = (): boolean => {
    const next: FormErrors = {}
    if (!form.username.trim()) next.username = 'Username is required'
    if (!form.password.trim()) next.password = 'Password is required'
    setFieldErrors(next)
    return Object.keys(next).length === 0
  }

  const handleChange = (field: keyof FormValues, value: string) => {
    setForm((current) => ({ ...current, [field]: value }))
    if (field in fieldErrors) {
      setFieldErrors((current) => ({ ...current, [field]: undefined }))
    }
  }

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    if (!canAttemptLogin) {
      setError('Configure a valid backend URL in Setup before signing in.')
      return
    }
    if (!validate()) return
    setSubmitting(true)
    setError('')

    try {
      await login({ ...form, baseUrl, tenantCode: '' })
      navigate('/pos', { replace: true })
    } catch (err) {
      setError(extractApiError(err))
    } finally {
      setSubmitting(false)
    }
  }

  if (loading && isAuthenticated) {
    return <Spinner fullScreen label="Restoring session..." />
  }

  return (
    <div className="login-layout">
      <style>{`
        /* Global & Layout */
        .login-layout {
          display: flex;
          flex-direction: row-reverse;
          min-height: 100vh;
          width: 100vw;
          font-family: 'Inter', system-ui, -apple-system, sans-serif;
          background: #0f172a;
          overflow: hidden;
          position: relative;
        }

        /* Left Side: Brand Showcase (Banner) */
        .brand-showcase {
          flex: 1;
          display: none;
          position: relative;
          background-image: url('https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?auto=format&fit=crop&q=80&w=1920');
          background-size: cover;
          background-position: center;
          overflow: hidden;
          align-items: center;
          justify-content: center;
          padding: 3rem;
        }
        .brand-showcase::before {
          content: '';
          position: absolute;
          inset: 0;
          background: linear-gradient(135deg, rgba(30, 27, 75, 0.85) 0%, rgba(49, 46, 129, 0.75) 100%);
          z-index: 1;
        }
        @media (min-width: 1024px) {
          .brand-showcase { display: flex; }
        }

        .brand-content {
          position: relative;
          z-index: 10;
          color: white;
          max-width: 500px;
        }
        .brand-logo-big {
          width: 80px;
          height: 80px;
          background: linear-gradient(135deg, #6366f1, #d946ef);
          border-radius: 20px;
          display: flex;
          align-items: center;
          justify-content: center;
          box-shadow: 0 20px 40px rgba(99, 102, 241, 0.4);
          margin-bottom: 2rem;
        }
        .brand-title {
          font-size: 3.5rem;
          font-weight: 800;
          line-height: 1.1;
          margin: 0 0 1.5rem 0;
          background: linear-gradient(to right, #ffffff, #c7d2fe);
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
        }
        .brand-subtitle {
          font-size: 1.25rem;
          color: #94a3b8;
          line-height: 1.6;
        }

        /* Right Side: Login Form */
        .login-side {
          flex: 1;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          padding: 2rem;
          position: relative;
          z-index: 10;
        }
        .login-card {
          width: 100%;
          max-width: 420px;
          background: rgba(30, 41, 59, 0.7);
          backdrop-filter: blur(24px);
          -webkit-backdrop-filter: blur(24px);
          border: 1px solid rgba(255, 255, 255, 0.08);
          border-radius: 24px;
          padding: 2.5rem;
          box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
        }

        .login-header-mobile {
          display: flex;
          flex-direction: column;
          align-items: center;
          margin-bottom: 2rem;
        }
        @media (min-width: 1024px) {
          .login-header-mobile { display: none; }
        }
        .mobile-logo {
          width: 64px;
          height: 64px;
          background: linear-gradient(135deg, #6366f1, #d946ef);
          border-radius: 16px;
          display: flex;
          align-items: center;
          justify-content: center;
          margin-bottom: 1rem;
          box-shadow: 0 10px 25px rgba(99, 102, 241, 0.3);
        }

        .form-header h2 {
          color: white;
          font-size: 1.75rem;
          font-weight: 700;
          margin: 0 0 0.5rem 0;
        }
        .form-header p {
          color: #94a3b8;
          font-size: 0.95rem;
          margin: 0 0 2rem 0;
        }

        /* Input Groups */
        .form-group {
          margin-bottom: 1.5rem;
          position: relative;
        }
        .form-label {
          display: block;
          color: #cbd5e1;
          font-size: 0.85rem;
          font-weight: 600;
          margin-bottom: 0.5rem;
          text-transform: uppercase;
          letter-spacing: 0.05em;
        }
        .input-wrapper {
          position: relative;
        }
        .input-icon {
          position: absolute;
          left: 1rem;
          top: 50%;
          transform: translateY(-50%);
          color: #64748b;
          pointer-events: none;
          transition: color 0.3s;
        }
        .form-input {
          width: 100%;
          background: rgba(15, 23, 42, 0.6);
          border: 1px solid rgba(255, 255, 255, 0.1);
          border-radius: 12px;
          padding: 1rem 1rem 1rem 3rem;
          color: white;
          font-size: 1rem;
          transition: all 0.3s ease;
          box-sizing: border-box;
        }
        .form-input:focus {
          outline: none;
          border-color: #818cf8;
          background: rgba(15, 23, 42, 0.9);
          box-shadow: 0 0 0 4px rgba(129, 140, 248, 0.15);
        }
        .form-input:focus + .input-icon {
          color: #818cf8;
        }
        .form-input.is-invalid {
          border-color: #ef4444;
        }
        .form-error {
          color: #f87171;
          font-size: 0.85rem;
          margin-top: 0.5rem;
          display: flex;
          align-items: center;
          gap: 0.25rem;
        }

        /* Buttons & Alerts */
        .submit-btn {
          width: 100%;
          background: linear-gradient(135deg, #6366f1, #a855f7);
          color: white;
          border: none;
          border-radius: 12px;
          padding: 1rem;
          font-size: 1.05rem;
          font-weight: 600;
          cursor: pointer;
          transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
          box-shadow: 0 8px 20px rgba(99, 102, 241, 0.3);
          display: flex;
          align-items: center;
          justify-content: center;
          margin-top: 1rem;
        }
        .submit-btn:hover:not(:disabled) {
          transform: translateY(-2px);
          box-shadow: 0 12px 25px rgba(99, 102, 241, 0.4);
        }
        .submit-btn:active:not(:disabled) {
          transform: translateY(0);
        }
        .submit-btn:disabled {
          background: rgba(255, 255, 255, 0.1);
          color: rgba(255, 255, 255, 0.3);
          box-shadow: none;
          cursor: not-allowed;
        }

        .alert-error {
          background: rgba(239, 68, 68, 0.1);
          border: 1px solid rgba(239, 68, 68, 0.2);
          color: #fca5a5;
          padding: 1rem;
          border-radius: 12px;
          font-size: 0.9rem;
          margin-bottom: 1.5rem;
          display: flex;
          align-items: center;
          justify-content: space-between;
        }
        
        .alert-warning {
          background: rgba(245, 158, 11, 0.1);
          border: 1px solid rgba(245, 158, 11, 0.2);
          color: #fcd34d;
          padding: 1rem;
          border-radius: 12px;
          font-size: 0.9rem;
          margin-top: 1.5rem;
          line-height: 1.5;
        }

        .footer-links {
          text-align: center;
          margin-top: 2rem;
        }
        .footer-link {
          color: #94a3b8;
          font-size: 0.9rem;
          text-decoration: none;
          transition: color 0.2s;
        }
        .footer-link:hover {
          color: white;
        }

        .spinner {
          width: 22px;
          height: 22px;
          border: 2px solid rgba(255, 255, 255, 0.3);
          border-radius: 50%;
          border-top-color: #fff;
          animation: spin 0.8s linear infinite;
        }
        @keyframes spin {
          to { transform: rotate(360deg); }
        }
      `}</style>

      {/* LEFT: BRAND SHOWCASE */}
      <div className="brand-showcase">
        <div className="brand-content">
          <div className="brand-logo-big">
            <svg viewBox="0 0 24 24" width="40" height="40" fill="none" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/>
            </svg>
          </div>
          <h1 className="brand-title">Welcome to<br/>NammaNanban.</h1>
          <p className="brand-subtitle">
            The next-generation POS system designed to streamline your business, track your performance, and deliver exceptional experiences.
          </p>
        </div>
      </div>

      {/* RIGHT: LOGIN FORM */}
      <div className="login-side">
        <div className="login-header-mobile">
          <div className="mobile-logo">
            <svg viewBox="0 0 24 24" width="32" height="32" fill="none" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/>
            </svg>
          </div>
          <h1 style={{ color: 'white', margin: 0, fontSize: '1.5rem' }}>NammaNanban</h1>
        </div>

        <div className="login-card">
          <div className="form-header">
            <h2>{t.signIn || 'Sign In'}</h2>
            <p>{t.loginTitle || 'Enter your credentials to access your account'}</p>
          </div>

          <form onSubmit={handleSubmit}>
            <div className="form-group">
              <label className="form-label" htmlFor="username">{t.username}</label>
              <div className="input-wrapper">
                <input
                  id="username"
                  className={`form-input ${fieldErrors.username ? 'is-invalid' : ''}`}
                  value={form.username}
                  onChange={(e) => handleChange('username', e.target.value)}
                  placeholder="Username or Phone"
                  autoFocus
                />
                <svg className="input-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
              </div>
              {fieldErrors.username && (
                <span className="form-error">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
                  {fieldErrors.username}
                </span>
              )}
            </div>

            <div className="form-group">
              <label className="form-label" htmlFor="password">{t.password}</label>
              <div className="input-wrapper">
                <input
                  id="password"
                  type="password"
                  className={`form-input ${fieldErrors.password ? 'is-invalid' : ''}`}
                  value={form.password}
                  onChange={(e) => handleChange('password', e.target.value)}
                  placeholder="••••••••"
                />
                <svg className="input-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
              </div>
              {fieldErrors.password && (
                <span className="form-error">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
                  {fieldErrors.password}
                </span>
              )}
            </div>

            {error && (
              <div className="alert-error">
                <span>{error}</span>
                <button type="button" style={{ background: 'none', border: 'none', color: '#fca5a5', cursor: 'pointer', padding: 0 }} onClick={() => setError('')}>
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
                </button>
              </div>
            )}

            <button type="submit" className="submit-btn" disabled={!canAttemptLogin || submitting}>
              {submitting ? <div className="spinner"></div> : (t.signIn || 'Sign In to Dashboard')}
            </button>
          </form>

          {(!baseUrl || backendUrlLooksWrong) && (
            <div className="alert-warning">
              {backendUrlLooksWrong
                ? <span>Backend URL is pointing at the app itself (<code>{baseUrl}</code>). <Link to="/bootstrap" style={{ color: '#fff', fontWeight: 600 }}>Open Setup</Link></span>
                : <span>Backend URL is not configured. <Link to="/bootstrap" style={{ color: '#fff', fontWeight: 600 }}>Open Setup</Link> to connect.</span>
              }
            </div>
          )}
        </div>

        <div className="footer-links">
          <Link to="/bootstrap" className="footer-link">⚙ {t.configureServer || 'Configure Server Connection'}</Link>
        </div>
      </div>
    </div>
  )
}

export default LoginPage
