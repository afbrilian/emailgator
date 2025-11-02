'use client'

import { ApolloProvider } from '@apollo/client'
import { client } from '@/lib/apollo'
import { PollingProvider } from '@/lib/polling-context'
import { PollingBanner } from '@/components/PollingBanner'
import './globals.css'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <ApolloProvider client={client}>
          <PollingProvider>
            <PollingBanner />
            {children}
          </PollingProvider>
        </ApolloProvider>
      </body>
    </html>
  )
}
