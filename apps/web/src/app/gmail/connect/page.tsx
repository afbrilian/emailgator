'use client'

import { useEffect } from 'react'
import { useQuery } from '@apollo/client'
import { GetConnectGmailUrlDocument } from '@/gql'
import { ProtectedRoute } from '@/lib/auth'

function ConnectGmailPageContent() {
  const { data, loading } = useQuery(GetConnectGmailUrlDocument)

  useEffect(() => {
    if (data?.connectGmailUrl) {
      // Redirect to Gmail OAuth
      window.location.href = data.connectGmailUrl
    }
  }, [data])

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <p className="text-lg">Connecting to Gmail...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen flex items-center justify-center">
      <div className="text-center">
        <p className="text-lg">Redirecting to Gmail authentication...</p>
      </div>
    </div>
  )
}

export default function ConnectGmailPage() {
  return (
    <ProtectedRoute>
      <ConnectGmailPageContent />
    </ProtectedRoute>
  )
}
