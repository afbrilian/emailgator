'use client'

import CategoryList from '@/components/CategoryList'
import { ProtectedRoute } from '@/lib/auth'
import Link from 'next/link'
import Image from 'next/image'
import { API_ENDPOINTS } from '@/lib/config'
import emailgatorLogo from '@/images/emailgator-logo.png'

function CategoriesPageContent() {
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
          <div className="flex items-center gap-4">
            <Link
              href="/dashboard"
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
              Dashboard
            </Link>
            <Link
              href={API_ENDPOINTS.auth.logout}
              className="text-gray-600 hover:text-gray-900 text-sm font-medium"
            >
              Sign out
            </Link>
          </div>
        </div>
      </header>

      <div className="max-w-7xl mx-auto px-6 py-12">
        <CategoryList />
      </div>
    </div>
  )
}

export default function CategoriesPage() {
  return (
    <ProtectedRoute>
      <CategoriesPageContent />
    </ProtectedRoute>
  )
}
