'use client'

import { useEffect, useState } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { useQuery } from '@apollo/client'
import { GetMeDocument } from '@/gql'

/**
 * Custom hook to check authentication status
 */
export function useAuth() {
  const { data, loading, error, refetch } = useQuery(GetMeDocument, {
    errorPolicy: 'ignore', // Don't throw on errors (e.g., unauthenticated)
    fetchPolicy: 'cache-and-network', // Use cache but also check network for fresh data
    // Don't refetch immediately - let the component handle it
    notifyOnNetworkStatusChange: false,
  })

  return {
    user: data?.me || null,
    isAuthenticated: !!data?.me,
    loading,
    error,
    refetch,
  }
}

/**
 * Protected Route Component
 * Redirects to login if not authenticated
 */
export function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const router = useRouter()
  const { isAuthenticated, loading } = useAuth()

  useEffect(() => {
    if (!loading && !isAuthenticated) {
      // Redirect to login (homepage)
      router.push('/')
    }
  }, [isAuthenticated, loading, router])

  // Show loading state while checking auth
  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-[#FF385C]"></div>
      </div>
    )
  }

  // Don't render children if not authenticated (will redirect)
  if (!isAuthenticated) {
    return null
  }

  return <>{children}</>
}

/**
 * Public Route Component
 * Redirects to dashboard if already authenticated
 */
export function PublicRoute({ children }: { children: React.ReactNode }) {
  const router = useRouter()
  const searchParams = useSearchParams()
  const { isAuthenticated, loading, refetch } = useAuth()
  const [checkingAuth, setCheckingAuth] = useState(false)

  // Check if we're coming from OAuth callback
  const isOAuthCallback =
    searchParams?.get('auth') === 'success' || searchParams?.get('gmail') === 'connected'

  useEffect(() => {
    // If coming from OAuth callback, force a refetch after a short delay
    // This ensures the cookie set by the backend is included in the request
    if (isOAuthCallback && !checkingAuth) {
      setCheckingAuth(true)
      // Wait a bit for cookie to be set, then refetch
      const timer = setTimeout(() => {
        refetch()
      }, 300)

      return () => clearTimeout(timer)
    }
  }, [isOAuthCallback, checkingAuth, refetch])

  useEffect(() => {
    // Redirect to dashboard if authenticated
    if (!loading && isAuthenticated) {
      const timer = setTimeout(() => {
        router.push('/dashboard')
      }, 100)

      return () => clearTimeout(timer)
    }
  }, [isAuthenticated, loading, router])

  // Show loading state while checking auth (especially after OAuth callback)
  if (loading || (isOAuthCallback && checkingAuth)) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-[#FF385C]"></div>
      </div>
    )
  }

  // Don't render children if authenticated (will redirect)
  if (isAuthenticated) {
    return null
  }

  return <>{children}</>
}
