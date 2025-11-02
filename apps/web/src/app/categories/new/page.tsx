'use client'

import CategoryForm from '@/components/CategoryForm'
import { ProtectedRoute } from '@/lib/auth'

function NewCategoryPageContent() {
  return (
    <div className="min-h-screen bg-gray-50">
      <CategoryForm />
    </div>
  )
}

export default function NewCategoryPage() {
  return (
    <ProtectedRoute>
      <NewCategoryPageContent />
    </ProtectedRoute>
  )
}
