'use client'

import { createContext, useContext, useState, useEffect, ReactNode } from 'react'
import { useLazyQuery } from '@apollo/client'
import { PollingStatusDocument } from '@/gql'

interface PollingContextType {
  isPollingActive: boolean
  setIsPollingActive: (active: boolean) => void
  startPolling: () => void
  stopPolling: () => void
}

const PollingContext = createContext<PollingContextType | undefined>(undefined)

export function PollingProvider({ children }: { children: ReactNode }) {
  const [isPollingActive, setIsPollingActive] = useState(false)
  const [isPolling, setIsPolling] = useState(false)
  const [checkPollingStatus, { data: pollingStatusData, stopPolling }] = useLazyQuery(
    PollingStatusDocument,
    {
      fetchPolicy: 'network-only',
    }
  )

  // Poll for status when isPolling is true
  useEffect(() => {
    if (isPolling) {
      // Longer delay before first check to allow job to start and be picked up by Oban
      const initialTimeout = setTimeout(() => {
        checkPollingStatus()
      }, 1500)

      // Then poll every 2 seconds
      const interval = setInterval(() => {
        checkPollingStatus()
      }, 2000)

      return () => {
        clearTimeout(initialTimeout)
        clearInterval(interval)
      }
    } else {
      stopPolling?.()
    }
  }, [isPolling, checkPollingStatus, stopPolling])

  // Update isPollingActive - keep it true while isPolling is true OR when status is true
  // Only set to false if status is explicitly false AND we're not actively polling
  useEffect(() => {
    if (isPolling) {
      // While we're in polling mode, keep active true
      setIsPollingActive(true)
    } else if (pollingStatusData?.pollingStatus !== undefined) {
      // Only update based on status if we're not in polling mode
      setIsPollingActive(pollingStatusData.pollingStatus === true)
    }
  }, [pollingStatusData?.pollingStatus, isPolling])

  // Stop polling when status becomes false (only after we've started checking)
  // Don't stop immediately if status is false - give it a few checks
  useEffect(() => {
    // Only stop if we have a status response AND it's false AND we've been polling for a bit
    if (
      pollingStatusData?.pollingStatus === false &&
      isPolling &&
      pollingStatusData !== undefined
    ) {
      // Wait a bit before stopping to ensure the job is really done
      const stopTimeout = setTimeout(() => {
        setIsPolling(false)
      }, 1000)

      return () => clearTimeout(stopTimeout)
    }
  }, [pollingStatusData?.pollingStatus, isPolling, pollingStatusData])

  const startPolling = () => {
    setIsPolling(true)
    setIsPollingActive(true) // Set active immediately when starting
  }

  const stopPollingState = () => {
    setIsPolling(false)
    setIsPollingActive(false)
    stopPolling?.()
  }

  return (
    <PollingContext.Provider
      value={{
        isPollingActive,
        setIsPollingActive,
        startPolling,
        stopPolling: stopPollingState,
      }}
    >
      {children}
    </PollingContext.Provider>
  )
}

export function usePolling() {
  const context = useContext(PollingContext)
  if (context === undefined) {
    throw new Error('usePolling must be used within a PollingProvider')
  }
  return context
}
