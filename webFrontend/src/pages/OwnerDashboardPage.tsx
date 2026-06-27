import { useEffect, useState } from 'react'
import { getOwnerDashboard } from '../api/owner'
import type { OwnerDashboardResponse } from '../types'
import { extractApiError } from '../api/client'
import Spinner from '../components/Spinner'

function OwnerDashboardPage() {
  const [data, setData] = useState<OwnerDashboardResponse | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    let cancelled = false
    const fetchData = async () => {
      try {
        const result = await getOwnerDashboard()
        if (!cancelled) {
          setData(result)
        }
      } catch (err) {
        if (!cancelled) {
          setError(extractApiError(err))
        }
      } finally {
        if (!cancelled) {
          setLoading(false)
        }
      }
    }

    void fetchData()
    return () => {
      cancelled = true
    }
  }, [])

  if (loading) return <Spinner fullScreen label="Loading Dashboard..." />

  return (
    <div className="owner-dashboard-container">
      <style>{`
        .owner-dashboard-container {
          min-height: calc(100vh - 64px);
          background: linear-gradient(135deg, #0f172a 0%, #1e1b4b 100%);
          color: #f8fafc;
          padding: 2rem;
          font-family: 'Inter', system-ui, -apple-system, sans-serif;
          position: relative;
          overflow: hidden;
        }

        /* Glassmorphism Blobs */
        .owner-dashboard-container::before,
        .owner-dashboard-container::after {
          content: '';
          position: absolute;
          width: 600px;
          height: 600px;
          border-radius: 50%;
          filter: blur(120px);
          z-index: 0;
          animation: floatBlob 25s infinite ease-in-out alternate;
        }
        .owner-dashboard-container::before {
          background: rgba(99, 102, 241, 0.15);
          top: -200px;
          left: -150px;
        }
        .owner-dashboard-container::after {
          background: rgba(236, 72, 153, 0.15);
          bottom: -200px;
          right: -150px;
          animation-delay: -12s;
        }

        @keyframes floatBlob {
          0% { transform: translate(0, 0) scale(1); }
          100% { transform: translate(60px, 80px) scale(1.1); }
        }

        .dashboard-content {
          position: relative;
          z-index: 10;
          max-width: 1400px;
          margin: 0 auto;
        }

        .dashboard-header {
          display: flex;
          justify-content: space-between;
          align-items: flex-end;
          margin-bottom: 2rem;
        }
        .dashboard-header h1 {
          font-size: 2.5rem;
          font-weight: 800;
          margin: 0;
          background: linear-gradient(to right, #c7d2fe, #fbcfe8);
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
          letter-spacing: -0.02em;
        }
        .dashboard-header p {
          color: #94a3b8;
          margin: 0.5rem 0 0;
          font-size: 1.1rem;
        }

        .metrics-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
          gap: 1.5rem;
          margin-bottom: 3rem;
        }

        .glass-card {
          background: rgba(30, 41, 59, 0.4);
          backdrop-filter: blur(16px);
          -webkit-backdrop-filter: blur(16px);
          border: 1px solid rgba(255, 255, 255, 0.08);
          border-radius: 20px;
          padding: 1.5rem;
          box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
          transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1), border-color 0.3s ease;
        }
        .glass-card:hover {
          transform: translateY(-4px);
          border-color: rgba(255, 255, 255, 0.2);
        }

        .metric-title {
          color: #cbd5e1;
          font-size: 0.95rem;
          font-weight: 500;
          margin-bottom: 0.5rem;
          display: flex;
          align-items: center;
          gap: 0.5rem;
        }
        .metric-value {
          font-size: 2.5rem;
          font-weight: 700;
          color: #fff;
          margin: 0;
        }
        .metric-trend {
          display: inline-flex;
          align-items: center;
          gap: 0.25rem;
          font-size: 0.85rem;
          font-weight: 600;
          padding: 0.25rem 0.75rem;
          border-radius: 99px;
          margin-top: 0.75rem;
        }
        .trend-up { background: rgba(16, 185, 129, 0.15); color: #34d399; }
        .trend-down { background: rgba(239, 68, 68, 0.15); color: #f87171; }
        .trend-neutral { background: rgba(148, 163, 184, 0.15); color: #94a3b8; }

        .branches-section h2 {
          font-size: 1.5rem;
          font-weight: 700;
          color: #e2e8f0;
          margin-bottom: 1.5rem;
        }

        .branches-grid {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
          gap: 1.5rem;
        }

        .branch-card {
          padding: 1.5rem;
          display: flex;
          flex-direction: column;
          gap: 1.25rem;
        }
        .branch-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
        }
        .branch-name {
          font-size: 1.15rem;
          font-weight: 600;
          color: #fff;
        }
        .branch-badge {
          background: rgba(99, 102, 241, 0.2);
          color: #818cf8;
          padding: 0.25rem 0.75rem;
          border-radius: 8px;
          font-size: 0.75rem;
          font-weight: 600;
          text-transform: uppercase;
          letter-spacing: 0.05em;
        }
        .branch-stats {
          display: grid;
          grid-template-columns: 1fr 1fr;
          gap: 1rem;
        }
        .b-stat {
          display: flex;
          flex-direction: column;
          gap: 0.25rem;
        }
        .b-stat-label {
          color: #94a3b8;
          font-size: 0.8rem;
          font-weight: 500;
        }
        .b-stat-val {
          color: #f1f5f9;
          font-size: 1.1rem;
          font-weight: 700;
        }
      `}</style>

      <div className="dashboard-content">
        <div className="dashboard-header">
          <div>
            <h1>Owner Dashboard</h1>
            <p>Real-time overview of your business performance</p>
          </div>
        </div>

        {error && (
          <div style={{ background: 'rgba(239, 68, 68, 0.2)', border: '1px solid #ef4444', color: '#fca5a5', padding: '1rem', borderRadius: '12px', marginBottom: '2rem' }}>
            {error}
          </div>
        )}

        {data && (
          <>
            <div className="metrics-grid">
              <div className="glass-card">
                <div className="metric-title">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>
                  Today's Revenue
                </div>
                <div className="metric-value">₹{data.todayRevenue.toLocaleString()}</div>
                <div className={`metric-trend ${data.trendPercent > 0 ? 'trend-up' : data.trendPercent < 0 ? 'trend-down' : 'trend-neutral'}`}>
                  {data.trendPercent > 0 ? '↑' : data.trendPercent < 0 ? '↓' : '−'} {Math.abs(data.trendPercent)}% vs yesterday
                </div>
              </div>

              <div className="glass-card">
                <div className="metric-title">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>
                  Total Profit
                </div>
                <div className="metric-value">₹{data.totalProfit.toLocaleString()}</div>
              </div>

              <div className="glass-card">
                <div className="metric-title">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="9" cy="21" r="1"/><circle cx="20" cy="21" r="1"/><path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"/></svg>
                  Transactions
                </div>
                <div className="metric-value">{data.transactionCount.toLocaleString()}</div>
              </div>

              <div className="glass-card">
                <div className="metric-title">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
                  Active Staff
                </div>
                <div className="metric-value">{data.activeStaffCount}</div>
              </div>
            </div>

            <div className="branches-section">
              <h2>Branches Overview</h2>
              <div className="branches-grid">
                {data.branches.map((b) => (
                  <div key={b.branchId} className="glass-card branch-card">
                    <div className="branch-header">
                      <div className="branch-name">{b.branchName}</div>
                      <div className="branch-badge">Live</div>
                    </div>
                    <div className="branch-stats">
                      <div className="b-stat">
                        <span className="b-stat-label">Revenue</span>
                        <span className="b-stat-val">₹{b.revenueAmount.toLocaleString()}</span>
                      </div>
                      <div className="b-stat">
                        <span className="b-stat-label">Transactions</span>
                        <span className="b-stat-val">{b.transactionCount}</span>
                      </div>
                      <div className="b-stat">
                        <span className="b-stat-label">Staff</span>
                        <span className="b-stat-val">{b.activeStaffCount}</span>
                      </div>
                      <div className="b-stat">
                        <span className="b-stat-label">Target</span>
                        <span className="b-stat-val" style={{ color: b.targetPercent >= 100 ? '#34d399' : '#f1f5f9' }}>{b.targetPercent}%</span>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
              {data.branches.length === 0 && (
                <div style={{ color: '#94a3b8', textAlign: 'center', padding: '3rem 0', background: 'rgba(30, 41, 59, 0.4)', borderRadius: '16px' }}>
                  No branches available.
                </div>
              )}
            </div>
          </>
        )}
      </div>
    </div>
  )
}

export default OwnerDashboardPage
