import { useCallback, useEffect, useState } from 'react'
import Alert from '@cloudscape-design/components/alert'
import Badge from '@cloudscape-design/components/badge'
import Box from '@cloudscape-design/components/box'
import Button from '@cloudscape-design/components/button'
import ColumnLayout from '@cloudscape-design/components/column-layout'
import Container from '@cloudscape-design/components/container'
import Form from '@cloudscape-design/components/form'
import FormField from '@cloudscape-design/components/form-field'
import Header from '@cloudscape-design/components/header'
import SpaceBetween from '@cloudscape-design/components/space-between'
import Textarea from '@cloudscape-design/components/textarea'
import { activateSubscription, getSubscriptionStatus } from '../api/subscription'
import { extractApiError } from '../api/client'
import Spinner from '../components/Spinner'
import type { SubscriptionStatusResponse } from '../types'

const formatDate = (value: string | null) => (value ? new Date(value).toLocaleString() : '—')

function SubscriptionPage() {
  const [status, setStatus] = useState<SubscriptionStatusResponse | null>(null)
  const [licenseKey, setLicenseKey] = useState('')
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  const loadStatus = useCallback(async () => {
    setLoading(true)
    setError('')

    try {
      const result = await getSubscriptionStatus()
      setStatus(result)
    } catch (err) {
      setError(extractApiError(err))
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    let cancelled = false

    const bootstrapStatus = async () => {
      try {
        const result = await getSubscriptionStatus()
        if (!cancelled) {
          setStatus(result)
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

    void bootstrapStatus()

    return () => {
      cancelled = true
    }
  }, [])

  const handleActivate = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    setSaving(true)
    setError('')
    setNotice('')

    try {
      const result = await activateSubscription({ licenseKey: licenseKey.trim() })
      setStatus(result)
      setNotice('License activated successfully.')
      setLicenseKey('')
    } catch (err) {
      setError(extractApiError(err))
    } finally {
      setSaving(false)
    }
  }

  if (loading) {
    return <Spinner label="Loading subscription..." />
  }

  return (
    <SpaceBetween size="l">
      <Header
        variant="h1"
        description="Review the current plan, capacity limits, and activate a new license key."
        actions={<Button onClick={() => void loadStatus()}>Refresh</Button>}
      >
        Subscription
      </Header>

      {error ? <Alert type="error">{error}</Alert> : null}
      {notice ? <Alert type="success">{notice}</Alert> : null}

      <ColumnLayout columns={2}>
        <Container header={<Header variant="h2">Current subscription</Header>}>
          <SpaceBetween size="s">
            <Badge color={status?.active ? 'green' : 'red'}>{status?.active ? 'Active' : 'Inactive'}</Badge>
            <Box><b>Company:</b> {status?.companyName ?? '—'}</Box>
            <Box><b>Plan code:</b> {status?.planCode ?? '—'}</Box>
            <Box><b>Max users:</b> {status?.maxUsers ?? '—'}</Box>
            <Box><b>Max companies:</b> {status?.maxCompanies ?? '—'}</Box>
            <Box><b>License key:</b> {status?.licenseKey ?? '—'}</Box>
            <Box><b>Activated at:</b> {formatDate(status?.activatedAt ?? null)}</Box>
            <Box><b>Expires at:</b> {formatDate(status?.expiresAt ?? null)}</Box>
            <Box variant="h2">Days left: {status?.daysLeft ?? 0}</Box>
          </SpaceBetween>
        </Container>

        <Container header={<Header variant="h2">Activate a license</Header>}>
          <form onSubmit={handleActivate}>
            <Form
              actions={<Button variant="primary" formAction="submit" loading={saving} disabled={!licenseKey.trim()}>Activate license</Button>}
            >
              <FormField label="License key">
                <Textarea
                  rows={7}
                  value={licenseKey}
                  onChange={({ detail }) => setLicenseKey(detail.value)}
                  placeholder="Paste your license key here"
                />
              </FormField>
            </Form>
          </form>
        </Container>
      </ColumnLayout>
    </SpaceBetween>
  )
}

export default SubscriptionPage
