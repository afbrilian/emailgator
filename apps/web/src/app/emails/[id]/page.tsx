'use client'

import { useMutation } from '@apollo/client'
import { useGetEmailQuery, GetEmailDocument } from '@/gql/graphql'
import { UnsubscribeEmailsDocument, DeleteEmailsDocument } from '@/gql'
import { useParams, useRouter } from 'next/navigation'
import Image from 'next/image'
import Link from 'next/link'
import { ProtectedRoute } from '@/lib/auth'
import { useState, useEffect, useRef } from 'react'
import emailgatorLogo from '@/images/emailgator-logo.png'

function EmailDetailPageContent() {
  const params = useParams()
  const router = useRouter()
  const emailId = params.id as string

  const { data, loading, error, refetch } = useGetEmailQuery({
    variables: { id: emailId },
    skip: !emailId,
    fetchPolicy: 'cache-and-network', // Always check network for fresh data
  })

  const [unsubscribeEmail, { loading: unsubscribeLoading }] = useMutation(
    UnsubscribeEmailsDocument,
    {
      refetchQueries: [{ query: GetEmailDocument, variables: { id: emailId } }],
      awaitRefetchQueries: false, // Don't wait, we'll poll manually
    }
  )
  const [deleteEmail, { loading: deleteLoading }] = useMutation(DeleteEmailsDocument, {
    refetchQueries: [{ query: GetEmailDocument, variables: { id: emailId } }],
  })
  const [unsubscribeStatus, setUnsubscribeStatus] = useState<'idle' | 'success' | 'error'>('idle')
  const pollIntervalRef = useRef<NodeJS.Timeout | null>(null)
  const pollTimeoutRef = useRef<NodeJS.Timeout | null>(null)

  const email = data?.email
  // @ts-expect-error - isUnsubscribed field exists but types may not be generated yet
  const isUnsubscribed = (email as { isUnsubscribed?: boolean })?.isUnsubscribed || false

  // Cleanup polling on unmount or when unsubscribed
  useEffect(() => {
    return () => {
      if (pollIntervalRef.current) {
        clearInterval(pollIntervalRef.current)
      }
      if (pollTimeoutRef.current) {
        clearTimeout(pollTimeoutRef.current)
      }
    }
  }, [])

  // Stop polling if we detect unsubscribe completed
  useEffect(() => {
    if (isUnsubscribed && pollIntervalRef.current) {
      clearInterval(pollIntervalRef.current)
      pollIntervalRef.current = null
      if (pollTimeoutRef.current) {
        clearTimeout(pollTimeoutRef.current)
        pollTimeoutRef.current = null
      }
      setUnsubscribeStatus('success')
    }
  }, [isUnsubscribed])

  const handleUnsubscribe = async () => {
    if (!email || isUnsubscribed) return

    try {
      const result = await unsubscribeEmail({
        variables: { emailIds: [email.id] },
      })

      const unsubscribeResult = result.data?.unsubscribeEmails?.[0]
      if (unsubscribeResult?.success) {
        setUnsubscribeStatus('success')

        // Since unsubscribe is async (Oban job), poll for status updates
        // Try refetching immediately
        const { data: refetchData } = await refetch()

        // Check if already unsubscribed after immediate refetch
        // @ts-expect-error - isUnsubscribed field exists but types may not be generated yet
        const alreadyUnsubscribed = (refetchData?.email as { isUnsubscribed?: boolean })
          ?.isUnsubscribed

        // If still not unsubscribed, start polling
        if (!alreadyUnsubscribed) {
          pollIntervalRef.current = setInterval(async () => {
            const { data: pollData } = await refetch()
            // @ts-expect-error - isUnsubscribed field exists but types may not be generated yet
            if ((pollData?.email as { isUnsubscribed?: boolean })?.isUnsubscribed) {
              if (pollIntervalRef.current) {
                clearInterval(pollIntervalRef.current)
                pollIntervalRef.current = null
              }
              if (pollTimeoutRef.current) {
                clearTimeout(pollTimeoutRef.current)
                pollTimeoutRef.current = null
              }
              setUnsubscribeStatus('success')
            }
          }, 2000) // Check every 2 seconds

          // Stop polling after 30 seconds
          pollTimeoutRef.current = setTimeout(() => {
            if (pollIntervalRef.current) {
              clearInterval(pollIntervalRef.current)
              pollIntervalRef.current = null
            }
          }, 30000)
        }
      } else {
        setUnsubscribeStatus('error')
      }
    } catch (error) {
      console.error('Failed to unsubscribe:', error)
      setUnsubscribeStatus('error')
    }
  }

  const handleDelete = async () => {
    if (!email) return
    if (!confirm('Are you sure you want to delete this email? This action cannot be undone.')) {
      return
    }

    try {
      await deleteEmail({
        variables: { emailIds: [email.id] },
      })
      // Navigate back to the category page or dashboard
      if (email.category) {
        router.push(`/categories/${email.category.id}`)
      } else {
        router.push('/dashboard')
      }
    } catch (error) {
      console.error('Failed to delete email:', error)
      alert('Failed to delete email')
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-50 to-white flex items-center justify-center">
        <div className="text-center">
          <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-[#FF385C] mb-4"></div>
          <p className="text-gray-600">Loading email...</p>
        </div>
      </div>
    )
  }

  if (error || !email) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-50 to-white flex items-center justify-center">
        <div className="text-center">
          <svg
            className="w-16 h-16 mx-auto text-gray-400 mb-4"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
          <h3 className="text-2xl font-semibold text-gray-900 mb-2">Email not found</h3>
          <p className="text-gray-600 mb-6">
            The email you&apos;re looking for doesn&apos;t exist or you don&apos;t have access to
            it.
          </p>
          <button onClick={() => router.back()} className="btn-primary">
            Go Back
          </button>
        </div>
      </div>
    )
  }

  const hasBodyContent = email.bodyHtml || email.bodyText
  // @ts-expect-error - unsubscribeUrls field exists but types may not be generated yet
  const hasUnsubscribeUrl =
    (email as { unsubscribeUrls?: string[] | null })?.unsubscribeUrls &&
    (email as { unsubscribeUrls?: string[] | null }).unsubscribeUrls!.length > 0

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-white">
      {/* Header */}
      <header className="bg-white border-b border-gray-200 sticky top-0 z-10">
        <div className="max-w-4xl mx-auto px-6 py-4 flex justify-between items-center">
          <Link href="/dashboard" className="flex items-center gap-3">
            <Image
              src={emailgatorLogo}
              alt="EmailGator"
              width={32}
              height={32}
              className="object-contain"
            />
            <span className="text-2xl font-bold text-gray-900">EmailGator</span>
          </Link>
          <div className="flex items-center gap-4">
            <button
              onClick={() => router.back()}
              className="text-gray-600 hover:text-gray-900 text-sm font-medium flex items-center gap-2"
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M15 19l-7-7 7-7"
                />
              </svg>
              Back
            </button>
            <button
              onClick={handleUnsubscribe}
              disabled={
                unsubscribeLoading ||
                isUnsubscribed ||
                unsubscribeStatus === 'success' ||
                !hasUnsubscribeUrl
              }
              className={`btn-secondary flex items-center gap-2 ${
                isUnsubscribed || unsubscribeStatus === 'success'
                  ? 'bg-green-100 text-green-700 border-green-300 cursor-not-allowed'
                  : unsubscribeStatus === 'error'
                    ? 'bg-red-100 text-red-700 border-red-300'
                    : !hasUnsubscribeUrl
                      ? 'bg-gray-100 text-gray-400 border-gray-300 cursor-not-allowed'
                      : ''
              }`}
              title={!hasUnsubscribeUrl ? 'No unsubscribe URL found in this email' : undefined}
            >
              {unsubscribeLoading ? (
                <>
                  <svg
                    className="w-4 h-4 animate-spin"
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
                  Unsubscribing...
                </>
              ) : isUnsubscribed || unsubscribeStatus === 'success' ? (
                <>
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M5 13l4 4L19 7"
                    />
                  </svg>
                  Unsubscribed
                </>
              ) : (
                <>
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636"
                    />
                  </svg>
                  Unsubscribe
                </>
              )}
            </button>
            <button
              onClick={handleDelete}
              disabled={deleteLoading}
              className="btn-secondary bg-red-50 text-red-700 border-red-300 hover:bg-red-100 flex items-center gap-2"
            >
              {deleteLoading ? (
                <>
                  <svg
                    className="w-4 h-4 animate-spin"
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
                  Deleting...
                </>
              ) : (
                <>
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                    />
                  </svg>
                  Delete
                </>
              )}
            </button>
          </div>
        </div>
      </header>

      <div className="max-w-4xl mx-auto px-6 py-12">
        {/* Email Header */}
        <div className="card p-8 mb-6">
          <div className="mb-6 flex items-center gap-3 flex-wrap">
            {!hasUnsubscribeUrl && (
              <span
                className="inline-flex items-center gap-1 px-3 py-1 rounded-full text-sm font-medium text-amber-700 bg-amber-50"
                title="No unsubscribe URL found in this email"
              >
                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fillRule="evenodd"
                    d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z"
                    clipRule="evenodd"
                  />
                </svg>
                No unsubscribe URL
              </span>
            )}
            {isUnsubscribed && (
              <span className="inline-flex items-center gap-1 px-3 py-1 rounded-full text-sm font-medium text-blue-700 bg-blue-50">
                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fillRule="evenodd"
                    d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                    clipRule="evenodd"
                  />
                </svg>
                Unsubscribed
              </span>
            )}
            {email.category && (
              <span className="inline-block px-3 py-1 rounded-full text-sm font-medium bg-[#FF385C] bg-opacity-10 text-[#FF385C]">
                {email.category.name}
              </span>
            )}
            <h1 className="text-4xl font-bold mb-4 text-gray-900 tracking-tight">
              {email.subject || '(No Subject)'}
            </h1>
            <div className="flex flex-wrap items-center gap-4 text-sm text-gray-600">
              <div className="flex items-center gap-2">
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
                  />
                </svg>
                <span className="font-medium">{email.from}</span>
              </div>
              {email.insertedAt && (
                <div className="flex items-center gap-2">
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                    />
                  </svg>
                  <span>
                    {new Date(email.insertedAt).toLocaleDateString('en-US', {
                      month: 'long',
                      day: 'numeric',
                      year: 'numeric',
                      hour: 'numeric',
                      minute: '2-digit',
                    })}
                  </span>
                </div>
              )}
            </div>
          </div>

          {email.summary && (
            <div className="bg-gradient-to-br from-blue-50 to-indigo-50 rounded-lg p-6 border border-blue-100 mb-6">
              <h3 className="text-sm font-semibold text-blue-900 mb-2 uppercase tracking-wide">
                AI Summary
              </h3>
              <p className="text-gray-700 leading-relaxed">{email.summary}</p>
            </div>
          )}
        </div>

        {/* Unsubscribe Attempts History */}
        {/* @ts-expect-error - unsubscribeAttempts field exists but types may not be generated yet */}
        {(() => {
          const emailWithAttempts = email as {
            unsubscribeAttempts?: Array<{
              id: string
              status: string
              method: string
              url?: string
              evidence?: unknown
              insertedAt?: string
              updatedAt?: string
            }>
          }
          return emailWithAttempts?.unsubscribeAttempts &&
            emailWithAttempts.unsubscribeAttempts.length > 0 ? (
            <div className="card p-6 mb-6">
              <h2 className="text-xl font-semibold text-gray-900 mb-4">Unsubscribe History</h2>
              <div className="space-y-3">
                {emailWithAttempts.unsubscribeAttempts.map(
                  (attempt: {
                    id: string
                    status: string
                    method: string
                    url?: string
                    evidence?: unknown
                    insertedAt?: string
                    updatedAt?: string
                  }) => (
                    <div
                      key={attempt.id}
                      className={`border rounded-lg p-4 ${
                        attempt.status === 'success'
                          ? 'bg-green-50 border-green-200'
                          : 'bg-red-50 border-red-200'
                      }`}
                    >
                      <div className="flex items-start justify-between mb-2">
                        <div className="flex items-center gap-2">
                          {attempt.status === 'success' ? (
                            <svg
                              className="w-5 h-5 text-green-600"
                              fill="currentColor"
                              viewBox="0 0 20 20"
                            >
                              <path
                                fillRule="evenodd"
                                d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                                clipRule="evenodd"
                              />
                            </svg>
                          ) : (
                            <svg
                              className="w-5 h-5 text-red-600"
                              fill="currentColor"
                              viewBox="0 0 20 20"
                            >
                              <path
                                fillRule="evenodd"
                                d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                                clipRule="evenodd"
                              />
                            </svg>
                          )}
                          <span
                            className={`font-medium ${
                              attempt.status === 'success' ? 'text-green-800' : 'text-red-800'
                            }`}
                          >
                            {attempt.status === 'success' ? 'Success' : 'Failed'}
                          </span>
                          <span className="text-sm text-gray-600">
                            via{' '}
                            {attempt.method === 'http'
                              ? 'HTTP'
                              : attempt.method === 'playwright'
                                ? 'Playwright'
                                : 'None'}
                          </span>
                        </div>
                        {attempt.insertedAt && (
                          <span className="text-xs text-gray-500">
                            {new Date(attempt.insertedAt).toLocaleString('en-US', {
                              month: 'short',
                              day: 'numeric',
                              year: 'numeric',
                              hour: 'numeric',
                              minute: '2-digit',
                            })}
                          </span>
                        )}
                      </div>
                      {attempt.url && attempt.url !== '' && (
                        <div className="text-sm text-gray-700 mb-2">
                          <span className="font-medium">URL:</span>{' '}
                          <a
                            href={attempt.url}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="text-blue-600 hover:underline break-all"
                          >
                            {attempt.url.length > 60
                              ? `${attempt.url.substring(0, 60)}...`
                              : attempt.url}
                          </a>
                        </div>
                      )}
                      {attempt.evidence && typeof attempt.evidence === 'object' && (
                        <div className="text-sm text-gray-700">
                          {attempt.evidence.error && (
                            <div className="mt-2">
                              <span className="font-medium">Error:</span>{' '}
                              <span className="text-red-700">{attempt.evidence.error}</span>
                            </div>
                          )}
                          {attempt.evidence.status && (
                            <div className="mt-1">
                              <span className="font-medium">Status:</span> {attempt.evidence.status}
                            </div>
                          )}
                          {attempt.evidence.actions &&
                            Array.isArray(attempt.evidence.actions) &&
                            attempt.evidence.actions.length > 0 && (
                              <div className="mt-1">
                                <span className="font-medium">Actions:</span>{' '}
                                <span className="text-gray-600">
                                  {attempt.evidence.actions.join(', ')}
                                </span>
                              </div>
                            )}
                        </div>
                      )}
                    </div>
                  )
                )}
              </div>
            </div>
          ) : null
        })()}

        {/* Email Body */}
        <div className="card p-8">
          {hasBodyContent ? (
            <div className="prose prose-lg max-w-none">
              {email.bodyHtml ? (
                <div dangerouslySetInnerHTML={{ __html: email.bodyHtml }} className="email-body" />
              ) : (
                <div className="whitespace-pre-wrap text-gray-800 leading-relaxed">
                  {email.bodyText}
                </div>
              )}
            </div>
          ) : (
            <div className="text-center py-12">
              <svg
                className="w-16 h-16 mx-auto text-gray-400 mb-4"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                />
              </svg>
              <p className="text-gray-500">No email content available</p>
            </div>
          )}
        </div>
      </div>

      <style jsx global>{`
        .email-body {
          color: #1f2937;
          line-height: 1.75;
        }
        .email-body :global(p) {
          margin-bottom: 1rem;
        }
        .email-body :global(a) {
          color: #ff385c;
          text-decoration: underline;
        }
        .email-body :global(a:hover) {
          color: #e61e4d;
        }
        .email-body :global(img) {
          max-width: 100%;
          height: auto;
          border-radius: 0.5rem;
          margin: 1rem 0;
        }
        .email-body :global(blockquote) {
          border-left: 4px solid #ff385c;
          padding-left: 1rem;
          margin: 1rem 0;
          font-style: italic;
          color: #6b7280;
        }
        .email-body :global(pre) {
          background-color: #f3f4f6;
          padding: 1rem;
          border-radius: 0.5rem;
          overflow-x: auto;
          margin: 1rem 0;
        }
        .email-body :global(code) {
          background-color: #f3f4f6;
          padding: 0.25rem 0.5rem;
          border-radius: 0.25rem;
          font-size: 0.875rem;
        }
      `}</style>
    </div>
  )
}

export default function EmailDetailPage() {
  return (
    <ProtectedRoute>
      <EmailDetailPageContent />
    </ProtectedRoute>
  )
}
