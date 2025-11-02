'use client'

import { useQuery } from '@apollo/client'
import { GetMeDocument, GetAccountsDocument, GetCategoriesDocument } from '@/gql'
import Link from 'next/link'
import { API_ENDPOINTS } from '@/lib/config'
import { ProtectedRoute } from '@/lib/auth'

function DashboardPageContent() {
  const { data: userData } = useQuery(GetMeDocument)
  const { data: accountsData, loading: accountsLoading } = useQuery(GetAccountsDocument)
  const { data: categoriesData, loading: categoriesLoading } = useQuery(GetCategoriesDocument)

  const accounts = accountsData?.accounts || []
  const categories = categoriesData?.categories || []
  const userName = userData?.me?.name || userData?.me?.email?.split('@')[0] || 'User'

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-white">
      {/* Header */}
      <header className="bg-white border-b border-gray-200 sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-6 py-4 flex justify-between items-center">
          <Link href="/dashboard" className="text-2xl font-bold text-gray-900">
            EmailGator
          </Link>
          <div className="flex items-center gap-4">
            <span className="text-gray-600 hidden sm:inline">Welcome, {userName}</span>
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
        <div className="mb-12">
          <h1 className="text-5xl font-bold mb-4 text-gray-900 tracking-tight">Dashboard</h1>
          <p className="text-xl text-gray-600">Manage your Gmail accounts and email categories</p>
        </div>

        {/* Gmail Accounts Section */}
        <section className="card p-8 mb-8">
          <div className="flex justify-between items-center mb-6">
            <div>
              <h2 className="text-2xl font-semibold mb-2 text-gray-900">Gmail Accounts</h2>
              <p className="text-gray-600">Connect your Gmail accounts to start sorting</p>
            </div>
            <Link href="/gmail/connect" className="btn-primary flex items-center gap-2">
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M12 4v16m8-8H4"
                />
              </svg>
              Connect Gmail
            </Link>
          </div>

          {accountsLoading ? (
            <div className="text-center py-12">
              <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-[#FF385C]"></div>
            </div>
          ) : accounts.length === 0 ? (
            <div className="text-center py-12 border-2 border-dashed border-gray-200 rounded-xl">
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
              <p className="text-gray-500 mb-4">No Gmail accounts connected yet</p>
              <Link href="/gmail/connect" className="btn-primary inline-flex items-center gap-2">
                Connect your first account
              </Link>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {accounts.map((account: any) => (
                <div
                  key={account.id}
                  className="border border-gray-200 rounded-xl p-6 hover:shadow-md transition-shadow"
                >
                  <div className="flex items-center gap-3 mb-3">
                    <div className="w-10 h-10 bg-[#FF385C] bg-opacity-10 rounded-full flex items-center justify-center">
                      <svg
                        className="w-5 h-5 text-[#FF385C]"
                        fill="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path d="M24 5.457v13.909c0 .904-.732 1.636-1.636 1.636h-3.819V11.73L12 16.64l-6.545-4.91v9.273H1.636A1.636 1.636 0 0 1 0 19.366V5.457c0-2.023 2.309-3.178 3.927-1.964L5.455 4.64 12 9.548l6.545-4.91 1.528-1.145C21.69 2.28 24 3.434 24 5.457z" />
                      </svg>
                    </div>
                    <div className="flex-1">
                      <p className="font-medium text-gray-900">{account.email}</p>
                      <p className="text-sm text-gray-500">
                        Connected{' '}
                        {new Date(account.insertedAt).toLocaleDateString('en-US', {
                          month: 'short',
                          day: 'numeric',
                          year: 'numeric',
                        })}
                      </p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>

        {/* Categories Section */}
        <section className="card p-8">
          <div className="flex justify-between items-center mb-6">
            <div>
              <div className="flex items-center gap-3 mb-2">
                <h2 className="text-2xl font-semibold text-gray-900">Categories</h2>
                <Link
                  href="/categories"
                  className="text-sm font-medium text-[#FF385C] hover:text-[#E61E4D] transition-colors flex items-center gap-1"
                >
                  View all
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M9 5l7 7-7 7"
                    />
                  </svg>
                </Link>
              </div>
              <p className="text-gray-600">Organize your emails with custom categories</p>
            </div>
            <Link href="/categories/new" className="btn-primary flex items-center gap-2">
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M12 4v16m8-8H4"
                />
              </svg>
              New Category
            </Link>
          </div>

          {categoriesLoading ? (
            <div className="text-center py-12">
              <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-[#FF385C]"></div>
            </div>
          ) : categories.length === 0 ? (
            <div className="text-center py-12 border-2 border-dashed border-gray-200 rounded-xl">
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
                  d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"
                />
              </svg>
              <p className="text-gray-500 mb-4">No categories yet</p>
              <p className="text-sm text-gray-400 mb-6 max-w-md mx-auto">
                Create your first category to start automatically sorting emails
              </p>
              <Link href="/categories/new" className="btn-primary inline-flex items-center gap-2">
                Create Category
              </Link>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {categories.map((category: any) => (
                <Link
                  key={category.id}
                  href={`/categories/${category.id}`}
                  className="card p-6 hover:shadow-lg transition-all duration-200 group"
                >
                  <div className="flex items-start justify-between mb-4">
                    <div className="w-12 h-12 bg-gradient-to-br from-[#FF385C] to-[#E61E4D] rounded-xl flex items-center justify-center group-hover:scale-110 transition-transform">
                      <svg
                        className="w-6 h-6 text-white"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"
                        />
                      </svg>
                    </div>
                    <svg
                      className="w-5 h-5 text-gray-400 group-hover:text-gray-600 transition-colors"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M9 5l7 7-7 7"
                      />
                    </svg>
                  </div>
                  <h3 className="text-xl font-semibold mb-2 text-gray-900 group-hover:text-[#FF385C] transition-colors">
                    {category.name}
                  </h3>
                  {category.description && (
                    <p className="text-gray-600 leading-relaxed line-clamp-2">
                      {category.description}
                    </p>
                  )}
                </Link>
              ))}
            </div>
          )}
        </section>
      </div>
    </div>
  )
}

export default function DashboardPage() {
  return (
    <ProtectedRoute>
      <DashboardPageContent />
    </ProtectedRoute>
  )
}
