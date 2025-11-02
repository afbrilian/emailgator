'use client'

import { useQuery, useMutation } from '@apollo/client'
import { GetEmailDocument, UnsubscribeEmailsDocument } from '@/gql'
import { useParams, useRouter } from 'next/navigation'
import Image from 'next/image'
import Link from 'next/link'
import { ProtectedRoute } from '@/lib/auth'
import { useState } from 'react'
import emailgatorLogo from '@/images/emailgator-logo.png'

function EmailDetailPageContent() {
  const params = useParams()
  const router = useRouter()
  const emailId = params.id as string

  const { data, loading, error } = useQuery(GetEmailDocument, {
    variables: { id: emailId },
    skip: !emailId,
  })

  const [unsubscribeEmail, { loading: unsubscribeLoading }] = useMutation(UnsubscribeEmailsDocument)
  const [unsubscribeStatus, setUnsubscribeStatus] = useState<'idle' | 'success' | 'error'>('idle')

  const email = data?.email

  const handleUnsubscribe = async () => {
    if (!email) return

    try {
      const result = await unsubscribeEmail({
        variables: { emailIds: [email.id] },
      })

      const unsubscribeResult = result.data?.unsubscribeEmails?.[0]
      if (unsubscribeResult?.success) {
        setUnsubscribeStatus('success')
      } else {
        setUnsubscribeStatus('error')
      }
    } catch (error) {
      console.error('Failed to unsubscribe:', error)
      setUnsubscribeStatus('error')
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
          <p className="text-gray-600 mb-6">The email you're looking for doesn't exist or you don't have access to it.</p>
          <button
            onClick={() => router.back()}
            className="btn-primary"
          >
            Go Back
          </button>
        </div>
      </div>
    )
  }

  const hasUnsubscribeUrls = email.unsubscribeUrls && email.unsubscribeUrls.length > 0
  const hasBodyContent = email.bodyHtml || email.bodyText

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
            {hasUnsubscribeUrls && (
              <button
                onClick={handleUnsubscribe}
                disabled={unsubscribeLoading || unsubscribeStatus === 'success'}
                className={`btn-secondary flex items-center gap-2 ${
                unsubscribeStatus === 'success'
                  ? 'bg-green-100 text-green-700 border-green-300'
                  : unsubscribeStatus === 'error'
                  ? 'bg-red-100 text-red-700 border-red-300'
                  : ''
              }`}
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
              ) : unsubscribeStatus === 'success' ? (
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
          )}
        </div>
      </header>

      <div className="max-w-4xl mx-auto px-6 py-12">
        {/* Email Header */}
        <div className="card p-8 mb-6">
          <div className="mb-6">
            {email.category && (
              <span className="inline-block px-3 py-1 rounded-full text-sm font-medium bg-[#FF385C] bg-opacity-10 text-[#FF385C] mb-4">
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
              <h3 className="text-sm font-semibold text-blue-900 mb-2 uppercase tracking-wide">AI Summary</h3>
              <p className="text-gray-700 leading-relaxed">{email.summary}</p>
            </div>
          )}
        </div>

        {/* Email Body */}
        <div className="card p-8">
          {hasBodyContent ? (
            <div className="prose prose-lg max-w-none">
              {email.bodyHtml ? (
                <div
                  dangerouslySetInnerHTML={{ __html: email.bodyHtml }}
                  className="email-body"
                />
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

