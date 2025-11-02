/**
 * Application configuration constants
 * Uses environment variables with sensible defaults for local development
 */

export const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4000'

/**
 * Get the full URL for an API endpoint
 */
export const getApiUrl = (path: string): string => {
  // Remove leading slash if present to avoid double slashes
  const cleanPath = path.startsWith('/') ? path.slice(1) : path
  return `${API_URL}/${cleanPath}`
}

/**
 * Common API endpoints
 */
export const API_ENDPOINTS = {
  graphql: getApiUrl('api/graphql'),
  auth: {
    google: getApiUrl('auth/google'),
    logout: getApiUrl('auth/logout'),
  },
  gmail: {
    connect: getApiUrl('gmail/connect'),
  },
} as const
