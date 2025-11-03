/**
 * GraphQL Codegen configuration
 * Uses environment variable for API URL to support multiple environments
 */
const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4000'

module.exports = {
  schema: `${apiUrl}/api/graphql`,
  documents: 'src/**/*.graphql',
  generates: {
    'src/gql/': {
      preset: 'client',
      config: {
        withHooks: true,
      },
    },
    'src/gql/graphql-hooks.ts': {
      plugins: ['typescript', 'typescript-operations', 'typescript-react-apollo'],
      config: {
        withHooks: true,
        withHOC: false,
        withComponent: false,
      },
    },
  },
}
