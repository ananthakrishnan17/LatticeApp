import Box from '@cloudscape-design/components/box'
import SpaceBetween from '@cloudscape-design/components/space-between'
import SpinnerComponent from '@cloudscape-design/components/spinner'

interface SpinnerProps {
  label?: string
  fullScreen?: boolean
}

function Spinner({ label = 'Loading...', fullScreen = false }: SpinnerProps) {
  return (
    <div style={{ minHeight: fullScreen ? '100vh' : undefined, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: fullScreen ? undefined : '2rem 0' }}>
      <SpaceBetween size="xs" direction="vertical" alignItems="center">
        <SpinnerComponent size="large" />
        <Box color="text-body-secondary" variant="small">
          {label}
        </Box>
      </SpaceBetween>
    </div>
  )
}

export default Spinner
