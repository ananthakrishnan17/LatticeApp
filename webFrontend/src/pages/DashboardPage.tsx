import { useCallback, useEffect, useState } from 'react'
import Alert from '@cloudscape-design/components/alert'
import Badge from '@cloudscape-design/components/badge'
import Box from '@cloudscape-design/components/box'
import Button from '@cloudscape-design/components/button'
import ColumnLayout from '@cloudscape-design/components/column-layout'
import Container from '@cloudscape-design/components/container'
import Header from '@cloudscape-design/components/header'
import SpaceBetween from '@cloudscape-design/components/space-between'
import StatusIndicator from '@cloudscape-design/components/status-indicator'
import { getSubscriptionStatus } from '../api/subscription'
import { listUsers } from '../api/users'
import { extractApiError } from '../api/client'
import Spinner from '../components/Spinner'
import type { SubscriptionStatusResponse, UserResponse } from '../types'

const formatDate = (value: string | null) => (value ? new Date(value).toLocaleString() : '—')

function DashboardPage() {
  const [subscription, setSubscription] = useState<SubscriptionStatusResponse | null>(null)
  const [users, setUsers] = useState<UserResponse[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const loadDashboard = useCallback(async () => {
    setLoading(true)
    setError('')

    const [subscriptionResult, usersResult] = await Promise.allSettled([
      getSubscriptionStatus(),
      listUsers(),
    ])

    if (subscriptionResult.status === 'fulfilled') {
      setSubscription(subscriptionResult.value)
    } else {
      setError(extractApiError(subscriptionResult.reason))
    }

    if (usersResult.status === 'fulfilled') {
      setUsers(usersResult.value)
    }

    setLoading(false)
  }, [])

  useEffect(() => {
    let cancelled = false

    const bootstrapDashboard = async () => {
      const [subscriptionResult, usersResult] = await Promise.allSettled([
        getSubscriptionStatus(),
        listUsers(),
      ])

      if (cancelled) {
        return
      }

      if (subscriptionResult.status === 'fulfilled') {
        setSubscription(subscriptionResult.value)
      } else {
        setError(extractApiError(subscriptionResult.reason))
      }

      if (usersResult.status === 'fulfilled') {
        setUsers(usersResult.value)
      }

      setLoading(false)
    }

    void bootstrapDashboard()

    return () => {
      cancelled = true
    }
  }, [])

  if (loading) {
    return <Spinner label="Loading dashboard..." />
  }

  return (
    <SpaceBetween size="l">
      <Header
        variant="h1"
        description="Track license health, plan capacity, and users at a glance."
        actions={<Button onClick={() => void loadDashboard()}>Refresh</Button>}
      >
        Dashboard
      </Header>

      {error ? <Alert type="error">{error}</Alert> : null}

      <ColumnLayout columns={5} variant="text-grid">
        <Container header={<Header variant="h3">Company</Header>}>
          <Box variant="h2">{subscription?.companyName ?? 'Not available'}</Box>
        </Container>
        <Container header={<Header variant="h3">Plan</Header>}>
          <Box variant="h2">{subscription?.planCode ?? '—'}</Box>
        </Container>
        <Container header={<Header variant="h3">License status</Header>}>
          <StatusIndicator type={subscription?.active ? 'success' : 'stopped'}>
            {subscription?.active ? 'Active' : 'Inactive'}
          </StatusIndicator>
        </Container>
        <Container header={<Header variant="h3">Days left</Header>}>
          <Box variant="h2">{subscription?.daysLeft ?? 0}</Box>
        </Container>
        <Container header={<Header variant="h3">Users</Header>}>
          <Box variant="h2">{users.length} / {subscription?.maxUsers ?? '—'}</Box>
        </Container>
      </ColumnLayout>

      <ColumnLayout columns={2}>
        <Container
          header={<Header variant="h2">Subscription summary</Header>}
        >
          <SpaceBetween size="s">
            <Badge color={subscription?.expired ? 'red' : 'blue'}>{subscription?.expired ? 'Expired' : 'Healthy'}</Badge>
            <Box><b>License key:</b> {subscription?.licenseKey ?? '—'}</Box>
            <Box><b>Max companies:</b> {subscription?.maxCompanies ?? '—'}</Box>
            <Box><b>Activated at:</b> {formatDate(subscription?.activatedAt ?? null)}</Box>
            <Box><b>Expires at:</b> {formatDate(subscription?.expiresAt ?? null)}</Box>
          </SpaceBetween>
        </Container>

        <Container header={<Header variant="h2">User access snapshot</Header>}>
          <SpaceBetween size="s">
            {users.length ? users.slice(0, 5).map((user) => (
              <Container key={user.username}>
                <SpaceBetween direction="horizontal" size="xs" alignItems="center">
                  <Box>
                    <div>{user.username}</div>
                    <Box variant="small" color="text-body-secondary">{user.role} · {user.isActive ? 'Active' : 'Inactive'}</Box>
                  </Box>
                  <StatusIndicator type={user.canBill ? 'success' : 'pending'}>
                    {user.canBill ? 'Can bill' : 'Billing off'}
                  </StatusIndicator>
                </SpaceBetween>
              </Container>
            )) : <Box color="text-body-secondary">User details are not available.</Box>}
          </SpaceBetween>
        </Container>
      </ColumnLayout>
    </SpaceBetween>
  )
}

export default DashboardPage
