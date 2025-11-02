'use client'

import { useQuery, useMutation } from '@apollo/client'
import { GetCategoryEmailsDocument, DeleteEmailsDocument, UnsubscribeEmailsDocument } from '@/gql'
import { useParams } from 'next/navigation'
import { useState } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { ProtectedRoute } from '@/lib/auth'
import emailgatorLogo from '@/images/emailgator-logo.png'

function CategoryDetailPageContent() {
  const params = useParams()
  const categoryId = params.id as string
  const [selectedEmails, setSelectedEmails] = useState<string[]>([])

  const { data, loading, error, refetch } = useQuery(GetCategoryEmailsDocument, {
    variables: { categoryId },
    skip: !categoryId,
  })

  const [deleteEmails] = useMutation(DeleteEmailsDocument, {
    onCompleted: () => {
      setSelectedEmails([])
      refetch()
    },
  })

  const [unsubscribeEmails, { loading: unsubscribeLoading }] = useMutation(UnsubscribeEmailsDocument, {
    onCompleted: () => {
      setSelectedEmails([])
      refetch()
    },
  })

  const handleBulkUnsubscribe = async () => {
    if (selectedEmails.length === 0) return

    try {
      await unsubscribeEmails({
        variables: { emailIds: selectedEmails },
      })
    } catch (error) {
      console.error('Failed to unsubscribe:', error)
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-50 to-white flex items-center justify-center">
        <div className="text-center">
          <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-[#FF385C] mb-4"></div>
          <p className="text-gray-600">Loading emails...</p>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-50 to-white flex items-center justify-center">
        <div className="card p-12 text-center max-w-md">
          <svg
            className="w-16 h-16 mx-auto text-red-500 mb-4"
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
          <h3 className="text-xl font-semibold text-gray-900 mb-2">Error loading emails</h3>
          <p className="text-red-600 mb-4">{error.message}</p>
          <button onClick={() => refetch()} className="btn-primary">
            Try Again
          </button>
        </div>
      </div>
    )
  }

  const emails = data?.categoryEmails || []
  const category = data?.category
  const categoryName = category?.name || 'Category Emails'

  const handleSelectAll = () => {
    // Filter out unsubscribed emails when selecting all
    const unsubscribedEmailIds = emails
      .filter((e: any) => e.isUnsubscribed)
      .map((e: any) => e.id)
    const subscribableEmails = emails
      .filter((e: any) => !e.isUnsubscribed)
      .map((e: any) => e.id)

    if (selectedEmails.length === subscribableEmails.length) {
      setSelectedEmails([])
    } else {
      setSelectedEmails(subscribableEmails)
    }
  }

  const handleToggleEmail = (emailId: string) => {
    const email = emails.find((e: any) => e.id === emailId)
    // Don't allow selecting unsubscribed emails
    if (email?.isUnsubscribed) return
    
    setSelectedEmails(prev =>
      prev.includes(emailId) ? prev.filter(id => id !== emailId) : [...prev, emailId]
    )
  }

  const handleBulkDelete = async () => {
    if (selectedEmails.length === 0) return
    if (!confirm(`Delete ${selectedEmails.length} email(s)?`)) return

    try {
      await deleteEmails({ variables: { emailIds: selectedEmails } })
    } catch (err) {
      console.error('Failed to delete emails:', err)
      alert('Failed to delete emails')
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-white">
      {/* Header */}
      <header className="bg-white border-b border-gray-200 sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-6 py-4 flex justify-between items-center">
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
          <Link
            href="/categories"
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
            Back to Categories
          </Link>
        </div>
      </header>

      <div className="max-w-7xl mx-auto px-6 py-12">
        <div className="flex justify-between items-start mb-8">
          <div>
            <h1 className="text-5xl font-bold mb-2 text-gray-900 tracking-tight">
              {categoryName}
            </h1>
            <p className="text-xl text-gray-600">
              {emails.length} {emails.length === 1 ? 'email' : 'emails'} in this category
            </p>
          </div>
          {selectedEmails.length > 0 && (
            <div className="flex items-center gap-4 bg-white rounded-xl px-6 py-4 shadow-sm border border-gray-200">
              <span className="text-gray-700 font-medium">{selectedEmails.length} selected</span>
              <button
                onClick={handleBulkUnsubscribe}
                disabled={unsubscribeLoading}
                className="btn-secondary flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
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
                    Unsubscribe Selected
                  </>
                )}
              </button>
              <button
                onClick={handleBulkDelete}
                className="btn-primary bg-red-600 hover:bg-red-700"
              >
                Delete Selected
              </button>
            </div>
          )}
        </div>

        {emails.length === 0 ? (
          <div className="card p-16 text-center">
            <svg
              className="w-20 h-20 mx-auto text-gray-400 mb-6"
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
            <h3 className="text-2xl font-semibold text-gray-900 mb-2">No emails yet</h3>
            <p className="text-gray-600 max-w-md mx-auto">
              Emails will appear here once they&apos;re automatically sorted into this category.
            </p>
          </div>
        ) : (
          <>
            <div className="mb-6">
              <label className="flex items-center gap-3 cursor-pointer group">
                <input
                  type="checkbox"
                  checked={
                    emails.length > 0 &&
                    selectedEmails.length === emails.filter((e: any) => !e.isUnsubscribed).length &&
                    emails.filter((e: any) => !e.isUnsubscribed).length > 0
                  }
                  onChange={handleSelectAll}
                  className="w-5 h-5 rounded border-gray-300 text-[#FF385C] focus:ring-[#FF385C] cursor-pointer"
                />
                <span className="text-gray-700 font-medium group-hover:text-gray-900">
                  Select all {emails.filter((e: any) => !e.isUnsubscribed).length} subscribable emails
                  {emails.filter((e: any) => e.isUnsubscribed).length > 0 && (
                    <span className="text-gray-500 text-sm ml-2">
                      ({emails.filter((e: any) => e.isUnsubscribed).length} already unsubscribed)
                    </span>
                  )}
                </span>
              </label>
            </div>

            <div className="space-y-4">
              {emails.map((email: any) => {
                const isUnsubscribed = email.isUnsubscribed || false
                const isSelected = selectedEmails.includes(email.id)
                
                return (
                <div
                  key={email.id}
                  className={`card p-6 transition-all duration-200 ${
                    isSelected
                      ? 'ring-2 ring-[#FF385C] shadow-md'
                      : 'hover:shadow-md'
                  } ${isUnsubscribed ? 'opacity-75' : ''}`}
                >
                  <div className="flex items-start gap-4">
                    <input
                      type="checkbox"
                      checked={isSelected}
                      onChange={() => handleToggleEmail(email.id)}
                      onClick={(e) => e.stopPropagation()}
                      disabled={isUnsubscribed}
                      className={`w-5 h-5 rounded border-gray-300 text-[#FF385C] focus:ring-[#FF385C] mt-1 ${
                        isUnsubscribed ? 'cursor-not-allowed opacity-50' : 'cursor-pointer'
                      }`}
                    />
                    <Link
                      href={`/emails/${email.id}`}
                      className="flex-1 cursor-pointer hover:opacity-90 transition-opacity"
                    >
                      <div className="flex items-start justify-between mb-3">
                        <h3 className="text-xl font-semibold text-gray-900 pr-4">
                          {email.subject || '(No subject)'}
                        </h3>
                        <div className="flex items-center gap-2">
                          {isUnsubscribed && (
                            <span className="inline-flex items-center gap-1 text-xs font-medium text-blue-700 bg-blue-50 px-3 py-1 rounded-full whitespace-nowrap">
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
                          {email.archivedAt && (
                            <span className="inline-flex items-center gap-1 text-xs font-medium text-green-700 bg-green-50 px-3 py-1 rounded-full whitespace-nowrap">
                              <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                                <path
                                  fillRule="evenodd"
                                  d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                                  clipRule="evenodd"
                                />
                              </svg>
                              Archived
                            </span>
                          )}
                        </div>
                      </div>
                      <p className="text-sm text-gray-600 mb-3 flex items-center gap-2">
                        <svg
                          className="w-4 h-4"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth={2}
                            d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
                          />
                        </svg>
                        {email.from}
                      </p>
                      {email.summary && (
                        <p className="text-gray-700 mb-3 leading-relaxed bg-gray-50 rounded-lg p-4 border border-gray-100">
                          <span className="font-medium text-gray-900">Summary:</span>{' '}
                          {email.summary}
                        </p>
                      )}
                      {!email.summary && email.snippet && (
                        <p className="text-gray-600 leading-relaxed line-clamp-2">
                          {email.snippet}
                        </p>
                      )}
                      {email.insertedAt && (
                        <p className="text-xs text-gray-400 mt-3">
                          {new Date(email.insertedAt).toLocaleDateString('en-US', {
                            month: 'short',
                            day: 'numeric',
                            year: 'numeric',
                            hour: 'numeric',
                            minute: '2-digit',
                          })}
                        </p>
                      )}
                    </Link>
                  </div>
                </div>
                )
              })}
            </div>
          </>
        )}
      </div>
    </div>
  )
}

export default function CategoryDetailPage() {
  return (
    <ProtectedRoute>
      <CategoryDetailPageContent />
    </ProtectedRoute>
  )
}
