import { ApolloClient, InMemoryCache, createHttpLink } from '@apollo/client';

const httpLink = createHttpLink({
  uri: `${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4000'}/api/graphql`,
  credentials: 'include', // Important: sends cookies
});

export const client = new ApolloClient({
  link: httpLink,
  cache: new InMemoryCache(),
});

