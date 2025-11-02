import { render, screen } from '@testing-library/react'
import { PollingBanner } from '../PollingBanner'

// Mock the polling context
const mockUsePolling = jest.fn()
jest.mock('@/lib/polling-context', () => ({
  usePolling: () => mockUsePolling(),
}))

describe('PollingBanner', () => {
  it('renders when polling is active', () => {
    mockUsePolling.mockReturnValue({ isPollingActive: true })
    render(<PollingBanner />)
    expect(screen.getByText('Fetching emails...')).toBeInTheDocument()
    expect(screen.getByText('This may take a few moments')).toBeInTheDocument()
  })

  it('does not render when polling is inactive', () => {
    mockUsePolling.mockReturnValue({ isPollingActive: false })
    const { container } = render(<PollingBanner />)
    expect(container.firstChild).toBeNull()
  })
})

