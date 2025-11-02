'use client'

import { useEffect } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { useRouter, useSearchParams } from 'next/navigation'
import { PublicRoute } from '@/lib/auth'
import { API_ENDPOINTS } from '@/lib/config'
import emailgatorLogo from '@/images/emailgator-logo.png'

function HomePage() {
  const router = useRouter()
  const searchParams = useSearchParams()

  useEffect(() => {
    // Check for OAuth callback success
    // Let PublicRoute handle the redirect - it will check auth status properly
    // This avoids race conditions with cookie setting
    if (searchParams?.get('auth') === 'success' || searchParams?.get('gmail') === 'connected') {
      // Small delay to ensure cookies are set, then let PublicRoute redirect
      // The PublicRoute will detect authentication and redirect to dashboard
    }
  }, [searchParams, router])

  return (
    <main className="min-h-screen bg-gradient-to-br from-white via-gray-50 to-white">
      {/* Navigation */}
      <nav className="max-w-7xl mx-auto px-6 py-6 flex justify-between items-center">
        <Link href="/" className="flex items-center gap-3">
          <Image
            src={emailgatorLogo}
            alt="EmailGator"
            width={40}
            height={40}
            className="object-contain"
          />
          <span className="text-2xl font-bold text-gray-900">EmailGator</span>
        </Link>
        <Link href={API_ENDPOINTS.auth.google} className="btn-secondary">
          Sign in
        </Link>
      </nav>

      {/* Hero Section */}
      <div className="max-w-7xl mx-auto px-6 py-20">
        <div className="max-w-4xl mx-auto text-center">
          <div className="flex justify-center mb-8">
            <Image
              src={emailgatorLogo}
              alt="EmailGator Logo"
              width={120}
              height={120}
              className="object-contain"
            />
          </div>
          <h1 className="text-7xl font-bold mb-6 text-gray-900 tracking-tight leading-tight">
            AI-powered email
            <span className="block text-[#FF385C] mt-2">sorting made simple</span>
          </h1>

          <p className="text-2xl text-gray-600 mb-12 max-w-2xl mx-auto leading-relaxed">
            Automatically organize your inbox with AI. Create custom categories, get smart
            summaries, and never miss what matters.
          </p>

          <div className="flex flex-col sm:flex-row gap-4 justify-center items-center mb-20">
            <Link
              href={API_ENDPOINTS.auth.google}
              className="btn-primary text-lg px-10 py-5 inline-flex items-center gap-3"
            >
              <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
                <path
                  d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                  fill="#4285F4"
                />
                <path
                  d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                  fill="#34A853"
                />
                <path
                  d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                  fill="#FBBC05"
                />
                <path
                  d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                  fill="#EA4335"
                />
              </svg>
              Get started with Google
            </Link>
          </div>

          {/* Features Grid */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mt-32">
            <div className="card p-8 text-left">
              <div className="w-12 h-12 bg-[#FF385C] bg-opacity-10 rounded-full flex items-center justify-center mb-4">
                <svg
                  className="w-6 h-6 text-[#FF385C]"
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
              </div>
              <h3 className="text-xl font-semibold mb-2 text-gray-900">Smart Sorting</h3>
              <p className="text-gray-600 leading-relaxed">
                AI automatically categorizes your emails into custom folders you create.
              </p>
            </div>

            <div className="card p-8 text-left">
              <div className="w-12 h-12 bg-[#FF385C] bg-opacity-10 rounded-full flex items-center justify-center mb-4">
                <svg
                  className="w-6 h-6 text-[#FF385C]"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                  />
                </svg>
              </div>
              <h3 className="text-xl font-semibold mb-2 text-gray-900">Smart Summaries</h3>
              <p className="text-gray-600 leading-relaxed">
                Get instant AI-generated summaries so you know what&apos;s important at a glance.
              </p>
            </div>

            <div className="card p-8 text-left">
              <div className="w-12 h-12 bg-[#FF385C] bg-opacity-10 rounded-full flex items-center justify-center mb-4">
                <svg
                  className="w-6 h-6 text-[#FF385C]"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"
                  />
                </svg>
              </div>
              <h3 className="text-xl font-semibold mb-2 text-gray-900">Auto Archive</h3>
              <p className="text-gray-600 leading-relaxed">
                Emails are automatically archived in Gmail after being sorted and categorized.
              </p>
            </div>
          </div>
        </div>
      </div>
    </main>
  )
}

export default function Home() {
  return (
    <PublicRoute>
      <HomePage />
    </PublicRoute>
  )
}
