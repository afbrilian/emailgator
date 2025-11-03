'use client'

import { useQuery, useMutation } from '@apollo/client'
import { GetCategoriesDocument, DeleteCategoryDocument } from '@/gql'
import Link from 'next/link'

export default function CategoryList() {
  const { data, loading, error, refetch } = useQuery(GetCategoriesDocument, {
    fetchPolicy: 'cache-and-network', // Always check network for fresh data
    notifyOnNetworkStatusChange: true,
  })
  const [deleteCategory] = useMutation(DeleteCategoryDocument, {
    onCompleted: () => refetch(),
  })

  const categories = data?.categories || []

  const handleDelete = async (id: string) => {
    if (confirm('Are you sure you want to delete this category?')) {
      try {
        await deleteCategory({ variables: { id } })
      } catch (err) {
        console.error('Failed to delete category:', err)
        alert('Failed to delete category')
      }
    }
  }

  return (
    <div className="mb-12">
      <div className="mb-12">
        <h1 className="text-5xl font-bold mb-4 text-gray-900 tracking-tight">Categories</h1>
        <p className="text-xl text-gray-600">Organize your emails with custom categories</p>
      </div>

      <section className="card p-8">
        <div className="flex justify-between items-center mb-6">
          <div>
            <h2 className="text-2xl font-semibold mb-2 text-gray-900">All Categories</h2>
            <p className="text-gray-600">
              {categories.length} {categories.length === 1 ? 'category' : 'categories'}
            </p>
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

        {loading ? (
          <div className="text-center py-12">
            <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-[#FF385C]"></div>
          </div>
        ) : error ? (
          <div className="card p-12 text-center max-w-md mx-auto">
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
            <h3 className="text-xl font-semibold text-gray-900 mb-2">Error loading categories</h3>
            <p className="text-red-600 mb-4">{error.message}</p>
            <button onClick={() => refetch()} className="btn-primary">
              Try Again
            </button>
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
            {categories
              .filter((category): category is NonNullable<typeof category> => !!category)
              .map(category => (
                <div
                  key={category.id || ''}
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
                    <div className="flex gap-2">
                      <Link
                        href={`/categories/${category.id || ''}`}
                        className="p-2 rounded-lg hover:bg-gray-100 transition-colors"
                        title="View category"
                      >
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
                      </Link>
                    </div>
                  </div>
                  <Link
                    href={`/categories/${category.id || ''}`}
                    className="block group-hover:text-[#FF385C] transition-colors"
                  >
                    <h3 className="text-xl font-semibold mb-2 text-gray-900 group-hover:text-[#FF385C] transition-colors">
                      {category.name || ''}
                    </h3>
                  </Link>
                  {category.description && (
                    <p className="text-gray-600 leading-relaxed line-clamp-2 mb-4">
                      {category.description}
                    </p>
                  )}
                  <div className="flex items-center gap-4 pt-4 border-t border-gray-100">
                    <Link
                      href={`/categories/${category.id || ''}`}
                      className="text-sm font-medium text-[#FF385C] hover:text-[#E61E4D] transition-colors"
                    >
                      View Emails →
                    </Link>
                    <button
                      onClick={() => handleDelete(category.id || '')}
                      className="text-sm font-medium text-red-600 hover:text-red-700 transition-colors ml-auto"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              ))}
          </div>
        )}
      </section>
    </div>
  )
}
