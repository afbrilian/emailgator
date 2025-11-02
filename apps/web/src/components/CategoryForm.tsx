'use client'

import { useState } from 'react'
import { useMutation } from '@apollo/client'
import { CreateCategoryDocument, UpdateCategoryDocument, GetCategoriesDocument } from '@/gql'
import { useRouter } from 'next/navigation'

interface CategoryFormProps {
  category?: {
    id: string
    name: string
    description?: string
  }
}

export default function CategoryForm({ category }: CategoryFormProps) {
  const router = useRouter()
  const [name, setName] = useState(category?.name || '')
  const [description, setDescription] = useState(category?.description || '')

  const [createCategory, { loading: creating }] = useMutation(CreateCategoryDocument, {
    refetchQueries: [{ query: GetCategoriesDocument }],
    awaitRefetchQueries: true, // Wait for refetch to complete before onCompleted
    onCompleted: () => router.push('/categories'),
  })

  const [updateCategory, { loading: updating }] = useMutation(UpdateCategoryDocument, {
    refetchQueries: [{ query: GetCategoriesDocument }],
    awaitRefetchQueries: true, // Wait for refetch to complete before onCompleted
    onCompleted: () => router.push('/categories'),
  })

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!name.trim()) {
      alert('Category name is required')
      return
    }

    try {
      if (category) {
        await updateCategory({
          variables: {
            id: category.id,
            name: name.trim(),
            description: description.trim() || null,
          },
        })
      } else {
        await createCategory({
          variables: {
            name: name.trim(),
            description: description.trim() || null,
          },
        })
      }
    } catch (err: any) {
      console.error('Failed to save category:', err)
      alert(err.message || 'Failed to save category')
    }
  }

  const loading = creating || updating

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-white">
      <div className="max-w-3xl mx-auto px-6 py-12">
        <div className="card p-10">
          <h2 className="text-4xl font-bold mb-2 text-gray-900 tracking-tight">
            {category ? 'Edit Category' : 'Create New Category'}
          </h2>
          <p className="text-gray-600 mb-8">
            {category ? 'Update your category details' : 'Define how emails should be sorted'}
          </p>

          <form onSubmit={handleSubmit} className="space-y-6">
            <div>
              <label htmlFor="name" className="block text-sm font-semibold mb-3 text-gray-900">
                Category Name <span className="text-[#FF385C]">*</span>
              </label>
              <input
                id="name"
                type="text"
                value={name}
                onChange={e => setName(e.target.value)}
                required
                className="input-field"
                placeholder="e.g., Work, Personal, Newsletters"
                disabled={loading}
              />
            </div>

            <div>
              <label
                htmlFor="description"
                className="block text-sm font-semibold mb-3 text-gray-900"
              >
                Description
              </label>
              <textarea
                id="description"
                value={description}
                onChange={e => setDescription(e.target.value)}
                rows={5}
                className="input-field resize-none"
                placeholder="Describe what types of emails should be sorted into this category. The AI will use this to classify emails accurately..."
                disabled={loading}
              />
              <p className="text-sm text-gray-500 mt-2 leading-relaxed">
                💡 <strong>Tip:</strong> Be specific. For example: &quot;Work-related emails from my
                team, project updates, and meeting invitations&quot; works better than just
                &quot;Work emails&quot;.
              </p>
            </div>

            <div className="flex gap-4 pt-4">
              <button
                type="submit"
                disabled={loading}
                className="btn-primary flex-1 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {loading ? (
                  <span className="flex items-center gap-2">
                    <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
                    Saving...
                  </span>
                ) : category ? (
                  'Update Category'
                ) : (
                  'Create Category'
                )}
              </button>
              <button
                type="button"
                onClick={() => router.back()}
                disabled={loading}
                className="btn-secondary px-8"
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  )
}
