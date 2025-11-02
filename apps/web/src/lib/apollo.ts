import { ApolloClient, InMemoryCache, createHttpLink } from '@apollo/client'
import { API_ENDPOINTS } from './config'

const httpLink = createHttpLink({
  uri: API_ENDPOINTS.graphql,
  credentials: 'include', // Important: sends cookies
})

export const client = new ApolloClient({
  link: httpLink,
  cache: new InMemoryCache(),
})
