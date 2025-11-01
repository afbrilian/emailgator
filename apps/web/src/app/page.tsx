'use client';

import { useEffect } from 'react';
import Link from 'next/link';

export default function Home() {
  return (
    <main className="min-h-screen p-8">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-4xl font-bold mb-8">EmailGator</h1>
        <p className="text-xl mb-8">AI-powered email sorting</p>
        
        <div className="space-y-4">
          <Link
            href="/auth/google"
            className="inline-block bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700"
          >
            Sign in with Google
          </Link>
        </div>
      </div>
    </main>
  );
}

