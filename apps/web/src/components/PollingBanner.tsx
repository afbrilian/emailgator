'use client'

import { usePolling } from '@/lib/polling-context'
import { useEffect } from 'react'

export function PollingBanner() {
  const { isPollingActive } = usePolling()

  // Add class to body when banner is visible to prevent content overlap
  useEffect(() => {
    if (isPollingActive) {
      document.body.classList.add('polling-active')
    } else {
      document.body.classList.remove('polling-active')
    }
    return () => {
      document.body.classList.remove('polling-active')
    }
  }, [isPollingActive])

  if (!isPollingActive) {
    return null
  }

  return (
    <div 
      className="fixed top-0 left-0 right-0 z-50 bg-blue-50 border-b border-blue-200 shadow-sm pointer-events-none"
      style={{ height: '60px' }}
    >
      <div className="max-w-7xl mx-auto px-6 py-3 flex items-center gap-3 h-full">
        <svg
          className="w-5 h-5 text-blue-600 animate-spin pointer-events-auto"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
          />
        </svg>
        <div className="flex-1 pointer-events-auto">
          <p className="text-sm font-medium text-blue-900">Fetching emails...</p>
          <p className="text-xs text-blue-700">This may take a few moments</p>
        </div>
      </div>
    </div>
  )
}

