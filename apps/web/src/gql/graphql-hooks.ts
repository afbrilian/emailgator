import { gql } from '@apollo/client';
import * as Apollo from '@apollo/client';
export type Maybe<T> = T | null;
export type InputMaybe<T> = Maybe<T>;
export type Exact<T extends { [key: string]: unknown }> = { [K in keyof T]: T[K] };
export type MakeOptional<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]?: Maybe<T[SubKey]> };
export type MakeMaybe<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]: Maybe<T[SubKey]> };
export type MakeEmpty<T extends { [key: string]: unknown }, K extends keyof T> = { [_ in K]?: never };
export type Incremental<T> = T | { [P in keyof T]?: P extends ' $fragmentName' | '__typename' ? T[P] : never };
const defaultOptions = {} as const;
/** All built-in and custom scalars, mapped to their actual values */
export type Scalars = {
  ID: { input: string; output: string; }
  String: { input: string; output: string; }
  Boolean: { input: boolean; output: boolean; }
  Int: { input: number; output: number; }
  Float: { input: number; output: number; }
  Datetime: { input: any; output: any; }
  Json: { input: any; output: any; }
};

export type Account = {
  __typename?: 'Account';
  email?: Maybe<Scalars['String']['output']>;
  id?: Maybe<Scalars['ID']['output']>;
  insertedAt?: Maybe<Scalars['Datetime']['output']>;
  updatedAt?: Maybe<Scalars['Datetime']['output']>;
};

export type Category = {
  __typename?: 'Category';
  description?: Maybe<Scalars['String']['output']>;
  id?: Maybe<Scalars['ID']['output']>;
  insertedAt?: Maybe<Scalars['Datetime']['output']>;
  name?: Maybe<Scalars['String']['output']>;
  updatedAt?: Maybe<Scalars['Datetime']['output']>;
};

export type Email = {
  __typename?: 'Email';
  archivedAt?: Maybe<Scalars['Datetime']['output']>;
  bodyHtml?: Maybe<Scalars['String']['output']>;
  bodyText?: Maybe<Scalars['String']['output']>;
  category?: Maybe<Category>;
  from?: Maybe<Scalars['String']['output']>;
  gmailMessageId?: Maybe<Scalars['String']['output']>;
  id?: Maybe<Scalars['ID']['output']>;
  insertedAt?: Maybe<Scalars['Datetime']['output']>;
  isUnsubscribed?: Maybe<Scalars['Boolean']['output']>;
  snippet?: Maybe<Scalars['String']['output']>;
  subject?: Maybe<Scalars['String']['output']>;
  summary?: Maybe<Scalars['String']['output']>;
  unsubscribeAttempts?: Maybe<Array<Maybe<UnsubscribeAttempt>>>;
  unsubscribeUrls?: Maybe<Array<Maybe<Scalars['String']['output']>>>;
  updatedAt?: Maybe<Scalars['Datetime']['output']>;
};

export type RootMutationType = {
  __typename?: 'RootMutationType';
  createCategory?: Maybe<Category>;
  deleteCategory?: Maybe<Category>;
  deleteEmails?: Maybe<Array<Maybe<Scalars['ID']['output']>>>;
  disconnectAccount?: Maybe<Account>;
  triggerPoll?: Maybe<Scalars['Boolean']['output']>;
  unsubscribeEmails?: Maybe<Array<Maybe<UnsubscribeResult>>>;
  updateCategory?: Maybe<Category>;
};


export type RootMutationTypeCreateCategoryArgs = {
  description?: InputMaybe<Scalars['String']['input']>;
  name: Scalars['String']['input'];
};


export type RootMutationTypeDeleteCategoryArgs = {
  id: Scalars['ID']['input'];
};


export type RootMutationTypeDeleteEmailsArgs = {
  emailIds: Array<Scalars['ID']['input']>;
};


export type RootMutationTypeDisconnectAccountArgs = {
  id: Scalars['ID']['input'];
};


export type RootMutationTypeTriggerPollArgs = {
  accountId?: InputMaybe<Scalars['ID']['input']>;
};


export type RootMutationTypeUnsubscribeEmailsArgs = {
  emailIds: Array<Scalars['ID']['input']>;
};


export type RootMutationTypeUpdateCategoryArgs = {
  description?: InputMaybe<Scalars['String']['input']>;
  id: Scalars['ID']['input'];
  name?: InputMaybe<Scalars['String']['input']>;
};

export type RootQueryType = {
  __typename?: 'RootQueryType';
  accounts?: Maybe<Array<Maybe<Account>>>;
  categories?: Maybe<Array<Maybe<Category>>>;
  category?: Maybe<Category>;
  categoryEmails?: Maybe<Array<Maybe<Email>>>;
  connectGmailUrl?: Maybe<Scalars['String']['output']>;
  email?: Maybe<Email>;
  me?: Maybe<User>;
  pollingStatus?: Maybe<Scalars['Boolean']['output']>;
};


export type RootQueryTypeCategoryArgs = {
  id: Scalars['ID']['input'];
};


export type RootQueryTypeCategoryEmailsArgs = {
  categoryId: Scalars['ID']['input'];
};


export type RootQueryTypeEmailArgs = {
  id: Scalars['ID']['input'];
};


export type RootQueryTypePollingStatusArgs = {
  accountId?: InputMaybe<Scalars['ID']['input']>;
};

export type UnsubscribeAttempt = {
  __typename?: 'UnsubscribeAttempt';
  evidence?: Maybe<Scalars['Json']['output']>;
  id?: Maybe<Scalars['ID']['output']>;
  insertedAt?: Maybe<Scalars['Datetime']['output']>;
  method?: Maybe<Scalars['String']['output']>;
  status?: Maybe<Scalars['String']['output']>;
  updatedAt?: Maybe<Scalars['Datetime']['output']>;
  url?: Maybe<Scalars['String']['output']>;
};

export type UnsubscribeResult = {
  __typename?: 'UnsubscribeResult';
  emailId?: Maybe<Scalars['ID']['output']>;
  error?: Maybe<Scalars['String']['output']>;
  success?: Maybe<Scalars['Boolean']['output']>;
};

export type User = {
  __typename?: 'User';
  email?: Maybe<Scalars['String']['output']>;
  id?: Maybe<Scalars['ID']['output']>;
  insertedAt?: Maybe<Scalars['Datetime']['output']>;
  name?: Maybe<Scalars['String']['output']>;
  updatedAt?: Maybe<Scalars['Datetime']['output']>;
};

export type GetCategoriesQueryVariables = Exact<{ [key: string]: never; }>;


export type GetCategoriesQuery = { __typename?: 'RootQueryType', categories?: Array<{ __typename?: 'Category', id?: string | null, name?: string | null, description?: string | null, insertedAt?: any | null, updatedAt?: any | null } | null> | null };

export type CreateCategoryMutationVariables = Exact<{
  name: Scalars['String']['input'];
  description?: InputMaybe<Scalars['String']['input']>;
}>;


export type CreateCategoryMutation = { __typename?: 'RootMutationType', createCategory?: { __typename?: 'Category', id?: string | null, name?: string | null, description?: string | null } | null };

export type UpdateCategoryMutationVariables = Exact<{
  id: Scalars['ID']['input'];
  name?: InputMaybe<Scalars['String']['input']>;
  description?: InputMaybe<Scalars['String']['input']>;
}>;


export type UpdateCategoryMutation = { __typename?: 'RootMutationType', updateCategory?: { __typename?: 'Category', id?: string | null, name?: string | null, description?: string | null } | null };

export type DeleteCategoryMutationVariables = Exact<{
  id: Scalars['ID']['input'];
}>;


export type DeleteCategoryMutation = { __typename?: 'RootMutationType', deleteCategory?: { __typename?: 'Category', id?: string | null } | null };

export type GetCategoryEmailsQueryVariables = Exact<{
  categoryId: Scalars['ID']['input'];
}>;


export type GetCategoryEmailsQuery = { __typename?: 'RootQueryType', category?: { __typename?: 'Category', id?: string | null, name?: string | null, description?: string | null } | null, categoryEmails?: Array<{ __typename?: 'Email', id?: string | null, subject?: string | null, from?: string | null, snippet?: string | null, summary?: string | null, archivedAt?: any | null, insertedAt?: any | null, unsubscribeUrls?: Array<string | null> | null, isUnsubscribed?: boolean | null } | null> | null };

export type DeleteEmailsMutationVariables = Exact<{
  emailIds: Array<Scalars['ID']['input']> | Scalars['ID']['input'];
}>;


export type DeleteEmailsMutation = { __typename?: 'RootMutationType', deleteEmails?: Array<string | null> | null };

export type UnsubscribeEmailsMutationVariables = Exact<{
  emailIds: Array<Scalars['ID']['input']> | Scalars['ID']['input'];
}>;


export type UnsubscribeEmailsMutation = { __typename?: 'RootMutationType', unsubscribeEmails?: Array<{ __typename?: 'UnsubscribeResult', emailId?: string | null, success?: boolean | null, error?: string | null } | null> | null };

export type GetEmailQueryVariables = Exact<{
  id: Scalars['ID']['input'];
}>;


export type GetEmailQuery = { __typename?: 'RootQueryType', email?: { __typename?: 'Email', id?: string | null, subject?: string | null, from?: string | null, snippet?: string | null, summary?: string | null, bodyText?: string | null, bodyHtml?: string | null, unsubscribeUrls?: Array<string | null> | null, archivedAt?: any | null, insertedAt?: any | null, updatedAt?: any | null, isUnsubscribed?: boolean | null, category?: { __typename?: 'Category', id?: string | null, name?: string | null } | null, unsubscribeAttempts?: Array<{ __typename?: 'UnsubscribeAttempt', id?: string | null, method?: string | null, url?: string | null, status?: string | null, evidence?: any | null, insertedAt?: any | null, updatedAt?: any | null } | null> | null } | null };

export type GetMeQueryVariables = Exact<{ [key: string]: never; }>;


export type GetMeQuery = { __typename?: 'RootQueryType', me?: { __typename?: 'User', id?: string | null, email?: string | null, name?: string | null } | null };

export type GetAccountsQueryVariables = Exact<{ [key: string]: never; }>;


export type GetAccountsQuery = { __typename?: 'RootQueryType', accounts?: Array<{ __typename?: 'Account', id?: string | null, email?: string | null, insertedAt?: any | null } | null> | null };

export type GetConnectGmailUrlQueryVariables = Exact<{ [key: string]: never; }>;


export type GetConnectGmailUrlQuery = { __typename?: 'RootQueryType', connectGmailUrl?: string | null };

export type DisconnectAccountMutationVariables = Exact<{
  id: Scalars['ID']['input'];
}>;


export type DisconnectAccountMutation = { __typename?: 'RootMutationType', disconnectAccount?: { __typename?: 'Account', id?: string | null } | null };

export type TriggerPollMutationVariables = Exact<{
  accountId?: InputMaybe<Scalars['ID']['input']>;
}>;


export type TriggerPollMutation = { __typename?: 'RootMutationType', triggerPoll?: boolean | null };

export type PollingStatusQueryVariables = Exact<{
  accountId?: InputMaybe<Scalars['ID']['input']>;
}>;


export type PollingStatusQuery = { __typename?: 'RootQueryType', pollingStatus?: boolean | null };


export const GetCategoriesDocument = gql`
    query GetCategories {
  categories {
    id
    name
    description
    insertedAt
    updatedAt
  }
}
    `;

/**
 * __useGetCategoriesQuery__
 *
 * To run a query within a React component, call `useGetCategoriesQuery` and pass it any options that fit your needs.
 * When your component renders, `useGetCategoriesQuery` returns an object from Apollo Client that contains loading, error, and data properties
 * you can use to render your UI.
 *
 * @param baseOptions options that will be passed into the query, supported options are listed on: https://www.apollographql.com/docs/react/api/react-hooks/#options;
 *
 * @example
 * const { data, loading, error } = useGetCategoriesQuery({
 *   variables: {
 *   },
 * });
 */
export function useGetCategoriesQuery(baseOptions?: Apollo.QueryHookOptions<GetCategoriesQuery, GetCategoriesQueryVariables>) {
        const options = {...defaultOptions, ...baseOptions}
        return Apollo.useQuery<GetCategoriesQuery, GetCategoriesQueryVariables>(GetCategoriesDocument, options);
      }
export function useGetCategoriesLazyQuery(baseOptions?: Apollo.LazyQueryHookOptions<GetCategoriesQuery, GetCategoriesQueryVariables>) {
          const options = {...defaultOptions, ...baseOptions}
          return Apollo.useLazyQuery<GetCategoriesQuery, GetCategoriesQueryVariables>(GetCategoriesDocument, options);
        }
export function useGetCategoriesSuspenseQuery(baseOptions?: Apollo.SkipToken | Apollo.SuspenseQueryHookOptions<GetCategoriesQuery, GetCategoriesQueryVariables>) {
          const options = baseOptions === Apollo.skipToken ? baseOptions : {...defaultOptions, ...baseOptions}
          return Apollo.useSuspenseQuery<GetCategoriesQuery, GetCategoriesQueryVariables>(GetCategoriesDocument, options);
        }
export type GetCategoriesQueryHookResult = ReturnType<typeof useGetCategoriesQuery>;
export type GetCategoriesLazyQueryHookResult = ReturnType<typeof useGetCategoriesLazyQuery>;
export type GetCategoriesSuspenseQueryHookResult = ReturnType<typeof useGetCategoriesSuspenseQuery>;
export type GetCategoriesQueryResult = Apollo.QueryResult<GetCategoriesQuery, GetCategoriesQueryVariables>;
export const CreateCategoryDocument = gql`
    mutation CreateCategory($name: String!, $description: String) {
  createCategory(name: $name, description: $description) {
    id
    name
    description
  }
}
    `;
export type CreateCategoryMutationFn = Apollo.MutationFunction<CreateCategoryMutation, CreateCategoryMutationVariables>;

/**
 * __useCreateCategoryMutation__
 *
 * To run a mutation, you first call `useCreateCategoryMutation` within a React component and pass it any options that fit your needs.
 * When your component renders, `useCreateCategoryMutation` returns a tuple that includes:
 * - A mutate function that you can call at any time to execute the mutation
 * - An object with fields that represent the current status of the mutation's execution
 *
 * @param baseOptions options that will be passed into the mutation, supported options are listed on: https://www.apollographql.com/docs/react/api/react-hooks/#options-2;
 *
 * @example
 * const [createCategoryMutation, { data, loading, error }] = useCreateCategoryMutation({
 *   variables: {
 *      name: // value for 'name'
 *      description: // value for 'description'
 *   },
 * });
 */
export function useCreateCategoryMutation(baseOptions?: Apollo.MutationHookOptions<CreateCategoryMutation, CreateCategoryMutationVariables>) {
        const options = {...defaultOptions, ...baseOptions}
        return Apollo.useMutation<CreateCategoryMutation, CreateCategoryMutationVariables>(CreateCategoryDocument, options);
      }
export type CreateCategoryMutationHookResult = ReturnType<typeof useCreateCategoryMutation>;
export type CreateCategoryMutationResult = Apollo.MutationResult<CreateCategoryMutation>;
export type CreateCategoryMutationOptions = Apollo.BaseMutationOptions<CreateCategoryMutation, CreateCategoryMutationVariables>;
export const UpdateCategoryDocument = gql`
    mutation UpdateCategory($id: ID!, $name: String, $description: String) {
  updateCategory(id: $id, name: $name, description: $description) {
    id
    name
    description
  }
}
    `;
export type UpdateCategoryMutationFn = Apollo.MutationFunction<UpdateCategoryMutation, UpdateCategoryMutationVariables>;

/**
 * __useUpdateCategoryMutation__
 *
 * To run a mutation, you first call `useUpdateCategoryMutation` within a React component and pass it any options that fit your needs.
 * When your component renders, `useUpdateCategoryMutation` returns a tuple that includes:
 * - A mutate function that you can call at any time to execute the mutation
 * - An object with fields that represent the current status of the mutation's execution
 *
 * @param baseOptions options that will be passed into the mutation, supported options are listed on: https://www.apollographql.com/docs/react/api/react-hooks/#options-2;
 *
 * @example
 * const [updateCategoryMutation, { data, loading, error }] = useUpdateCategoryMutation({
 *   variables: {
 *      id: // value for 'id'
 *      name: // value for 'name'
 *      description: // value for 'description'
 *   },
 * });
 */
export function useUpdateCategoryMutation(baseOptions?: Apollo.MutationHookOptions<UpdateCategoryMutation, UpdateCategoryMutationVariables>) {
        const options = {...defaultOptions, ...baseOptions}
        return Apollo.useMutation<UpdateCategoryMutation, UpdateCategoryMutationVariables>(UpdateCategoryDocument, options);
      }
export type UpdateCategoryMutationHookResult = ReturnType<typeof useUpdateCategoryMutation>;
export type UpdateCategoryMutationResult = Apollo.MutationResult<UpdateCategoryMutation>;
export type UpdateCategoryMutationOptions = Apollo.BaseMutationOptions<UpdateCategoryMutation, UpdateCategoryMutationVariables>;
export const DeleteCategoryDocument = gql`
    mutation DeleteCategory($id: ID!) {
  deleteCategory(id: $id) {
    id
  }
}
    `;
export type DeleteCategoryMutationFn = Apollo.MutationFunction<DeleteCategoryMutation, DeleteCategoryMutationVariables>;

/**
 * __useDeleteCategoryMutation__
 *
 * To run a mutation, you first call `useDeleteCategoryMutation` within a React component and pass it any options that fit your needs.
 * When your component renders, `useDeleteCategoryMutation` returns a tuple that includes:
 * - A mutate function that you can call at any time to execute the mutation
 * - An object with fields that represent the current status of the mutation's execution
 *
 * @param baseOptions options that will be passed into the mutation, supported options are listed on: https://www.apollographql.com/docs/react/api/react-hooks/#options-2;
 *
 * @example
 * const [deleteCategoryMutation, { data, loading, error }] = useDeleteCategoryMutation({
 *   variables: {
 *      id: // value for 'id'
 *   },
 * });
 */
export function useDeleteCategoryMutation(baseOptions?: Apollo.MutationHookOptions<DeleteCategoryMutation, DeleteCategoryMutationVariables>) {
        const options = {...defaultOptions, ...baseOptions}
        return Apollo.useMutation<DeleteCategoryMutation, DeleteCategoryMutationVariables>(DeleteCategoryDocument, options);
      }
export type DeleteCategoryMutationHookResult = ReturnType<typeof useDeleteCategoryMutation>;
export type DeleteCategoryMutationResult = Apollo.MutationResult<DeleteCategoryMutation>;
export type DeleteCategoryMutationOptions = Apollo.BaseMutationOptions<DeleteCategoryMutation, DeleteCategoryMutationVariables>;
export const GetCategoryEmailsDocument = gql`
    query GetCategoryEmails($categoryId: ID!) {
  category(id: $categoryId) {
    id
    name
    description
  }
  categoryEmails(categoryId: $categoryId) {
    id
    subject
    from
    snippet
    summary
    archivedAt
    insertedAt
    unsubscribeUrls
    isUnsubscribed
  }
}
    `;

/**
 * __useGetCategoryEmailsQuery__
 *
 * To run a query within a React component, call `useGetCategoryEmailsQuery` and pass it any options that fit your needs.
 * When your component renders, `useGetCategoryEmailsQuery` returns an object from Apollo Client that contains loading, error, and data properties
 * you can use to render your UI.
 *
 * @param baseOptions options that will be passed into the query, supported options are listed on: https://www.apollographql.com/docs/react/api/react-hooks/#options;
 *
 * @example
 * const { data, loading, error } = useGetCategoryEmailsQuery({
 *   variables: {
 *      categoryId: // value for 'categoryId'
 *   },
 * });
 */
export function useGetCategoryEmailsQuery(baseOptions: Apollo.QueryHookOptions<GetCategoryEmailsQuery, GetCategoryEmailsQueryVariables> & ({ variables: GetCategoryEmailsQueryVariables; skip?: boolean; } | { skip: boolean; }) ) {
        const options = {...defaultOptions, ...baseOptions}
        return Apollo.useQuery<GetCategoryEmailsQuery, GetCategoryEmailsQueryVariables>(GetCategoryEmailsDocument, options);
      }
export function useGetCategoryEmailsLazyQuery(baseOptions?: Apollo.LazyQueryHookOptions<GetCategoryEmailsQuery, GetCategoryEmailsQueryVariables>) {
          const options = {...defaultOptions, ...baseOptions}
          return Apollo.useLazyQuery<GetCategoryEmailsQuery, GetCategoryEmailsQueryVariables>(GetCategoryEmailsDocument, options);
        }
export function useGetCategoryEmailsSuspenseQuery(baseOptions?: Apollo.SkipToken | Apollo.SuspenseQueryHookOptions<GetCategoryEmailsQuery, GetCategoryEmailsQueryVariables>) {
          const options = baseOptions === Apollo.skipToken ? baseOptions : {...defaultOptions, ...baseOptions}
          return Apollo.useSuspenseQuery<GetCategoryEmailsQuery, GetCategoryEmailsQueryVariables>(GetCategoryEmailsDocument, options);
        }
export type GetCategoryEmailsQueryHookResult = ReturnType<typeof useGetCategoryEmailsQuery>;
export type GetCategoryEmailsLazyQueryHookResult = ReturnType<typeof useGetCategoryEmailsLazyQuery>;
export type GetCategoryEmailsSuspenseQueryHookResult = ReturnType<typeof useGetCategoryEmailsSuspenseQuery>;
export type GetCategoryEmailsQueryResult = Apollo.QueryResult<GetCategoryEmailsQuery, GetCategoryEmailsQueryVariables>;
export const DeleteEmailsDocument = gql`
    mutation DeleteEmails($emailIds: [ID!]!) {
  deleteEmails(emailIds: $emailIds)
}
    `;
export type DeleteEmailsMutationFn = Apollo.MutationFunction<DeleteEmailsMutation, DeleteEmailsMutationVariables>;

/**
 * __useDeleteEmailsMutation__
 *
 * To run a mutation, you first call `useDeleteEmailsMutation` within a React component and pass it any options that fit your needs.
 * When your component renders, `useDeleteEmailsMutation` returns a tuple that includes:
 * - A mutate function that you can call at any time to execute the mutation
 * - An object with fields that represent the current status of the mutation's execution
 *
 * @param baseOptions options that will be passed into the mutation, supported options are listed on: https://www.apollographql.com/docs/react/api/react-hooks/#options-2;
 *
 * @example
 * const [deleteEmailsMutation, { data, loading, error }] = useDeleteEmailsMutation({
 *   variables: {
 *      emailIds: // value for 'emailIds'
 *   },
 * });
 */
export function useDeleteEmailsMutation(baseOptions?: Apollo.MutationHookOptions<DeleteEmailsMutation, DeleteEmailsMutationVariables>) {
        const options = {...defaultOptions, ...baseOptions}
        return Apollo.useMutation<DeleteEmailsMutation, DeleteEmailsMutationVariables>(DeleteEmailsDocument, options);
      }
export type DeleteEmailsMutationHookResult = ReturnType<typeof useDeleteEmailsMutation>;
export type DeleteEmailsMutationResult = Apollo.MutationResult<DeleteEmailsMutation>;
export type DeleteEmailsMutationOptions = Apollo.BaseMutationOptions<DeleteEmailsMutation, DeleteEmailsMutationVariables>;
export const UnsubscribeEmailsDocument = gql`
    mutation UnsubscribeEmails($emailIds: [ID!]!) {
  unsubscribeEmails(emailIds: $emailIds) {
    emailId
    success
    error
  }
}
    `;
export type UnsubscribeEmailsMutationFn = Apollo.MutationFunction<UnsubscribeEmailsMutation, UnsubscribeEmailsMutationVariables>;

/**
 * __useUnsubscribeEmailsMutation__
 *
 * To run a mutation, you first call `useUnsubscribeEmailsMutation` within a React component and pass it any options that fit your needs.
 * When your component renders, `useUnsubscribeEmailsMutation` returns a tuple that includes:
 * - A mutate function that you can call at any time to execute the mutation
 * - An object with fields that represent the current status of the mutation's execution
 *
 * @param baseOptions options that will be passed into the mutation, supported options are listed on: https://www.apollographql.com/docs/react/api/react-hooks/#options-2;
 *
 * @example
 * const [unsubscribeEmailsMutation, { data, loading, error }] = useUnsubscribeEmailsMutation({
 *   variables: {
 *      emailIds: // value for 'emailIds'
 *   },
 * });
 */
export function useUnsubscribeEmailsMutation(baseOptions?: Apollo.MutationHookOptions<UnsubscribeEmailsMutation, UnsubscribeEmailsMutationVariables>) {
        const options = {...defaultOptions, ...baseOptions}
        return Apollo.useMutation<UnsubscribeEmailsMutation, UnsubscribeEmailsMutationVariables>(UnsubscribeEmailsDocument, options);
      }
export type UnsubscribeEmailsMutationHookResult = ReturnType<typeof useUnsubscribeEmailsMutation>;
export type UnsubscribeEmailsMutationResult = Apollo.MutationResult<UnsubscribeEmailsMutation>;
export type UnsubscribeEmailsMutationOptions = Apollo.BaseMutationOptions<UnsubscribeEmailsMutation, UnsubscribeEmailsMutationVariables>;
export const GetEmailDocument = gql`
    query GetEmail($id: ID!) {
  email(id: $id) {
    id
    subject
    from
    snippet
    summary
    bodyText
    bodyHtml
    unsubscribeUrls
    archivedAt
    insertedAt
    updatedAt
    isUnsubscribed
    category {
      id
      name
    }
    unsubscribeAttempts {
      id
      method
      url
      status
      evidence
      insertedAt
      updatedAt
    }
  }
}
    `;

/**
 * __useGetEmailQuery__
 *
 * To run a query within a React component, call `useGetEmailQuery` and pass it any options that fit your needs.
 * When your component renders, `useGetEmailQuery` returns an object from Apollo Client that contains loading, error, and data properties
 * you can use to render your UI.
 *
 * @param baseOptions options that will be passed into the query, supported options are listed on: https://www.apollographql.com/docs/react/api/react-hooks/#options;
 *
 * @example
 * const { data, loading, error } = useGetEmailQuery({
 *   variables: {
 *      id: // value for 'id'
 *   },
 * });
 */
export function useGetEmailQuery(baseOptions: Apollo.QueryHookOptions<GetEmailQuery, GetEmailQueryVariables> & ({ variables: GetEmailQueryVariables; skip?: boolean; } | { skip: boolean; }) ) {
        const options = {...defaultOptions, ...baseOptions}
        return Apollo.useQuery<GetEmailQuery, GetEmailQueryVariables>(GetEmailDocument, options);
      }
export function useGetEmailLazyQuery(baseOptions?: Apollo.LazyQueryHookOptions<GetEmailQuery, GetEmailQueryVariables>) {
          const options = {...defaultOptions, ...baseOptions}
          return Apollo.useLazyQuery<GetEmailQuery, GetEmailQueryVariables>(GetEmailDocument, options);
        }
export function useGetEmailSuspenseQuery(baseOptions?: Apollo.SkipToken | Apollo.SuspenseQueryHookOptions<GetEmailQuery, GetEmailQueryVariables>) {
          const options = baseOptions === Apollo.skipToken ? baseOptions : {...defaultOptions, ...baseOptions}
          return Apollo.useSuspenseQuery<GetEmailQuery, GetEmailQueryVariables>(GetEmailDocument, options);
        }
export type GetEmailQueryHookResult = ReturnType<typeof useGetEmailQuery>;
export type GetEmailLazyQueryHookResult = ReturnType<typeof useGetEmailLazyQuery>;
export type GetEmailSuspenseQueryHookResult = ReturnType<typeof useGetEmailSuspenseQuery>;
export type GetEmailQueryResult = Apollo.QueryResult<GetEmailQuery, GetEmailQueryVariables>;
export const GetMeDocument = gql`
    query GetMe {
  me {
    id
    email
    name
  }
}
    `;

/**
 * __useGetMeQuery__
 *
 * To run a query within a React component, call `useGetMeQuery` and pass it any options that fit your needs.
 * When your component renders, `useGetMeQuery` returns an object from Apollo Client that contains loading, error, and data properties
 * you can use to render your UI.
 *
 * @param baseOptions options that will be passed into the query, supported options are listed on: https://www.apollographql.com/docs/react/api/react-hooks/#options;
 *
 * @example
 * const { data, loading, error } = useGetMeQuery({
 *   variables: {
 *   },
 * });
 */
export function useGetMeQuery(baseOptions?: Apollo.QueryHookOptions<GetMeQuery, GetMeQueryVariables>) {
        const options = {...defaultOptions, ...baseOptions}
        return Apollo.useQuery<GetMeQuery, GetMeQueryVariables>(GetMeDocument, options);
      }
export function useGetMeLazyQuery(baseOptions?: Apollo.LazyQueryHookOptions<GetMeQuery, GetMeQueryVariables>) {
          const options = {...defaultOptions, ...baseOptions}
          return Apollo.useLazyQuery<GetMeQuery, GetMeQueryVariables>(GetMeDocument, options);
        }
export function useGetMeSuspenseQuery(baseOptions?: Apollo.SkipToken | Apollo.SuspenseQueryHookOptions<GetMeQuery, GetMeQueryVariables>) {
          const options = baseOptions === Apollo.skipToken ? baseOptions : {...defaultOptions, ...baseOptions}
          return Apollo.useSuspenseQuery<GetMeQuery, GetMeQueryVariables>(GetMeDocument, options);
        }
export type GetMeQueryHookResult = ReturnType<typeof useGetMeQuery>;
export type GetMeLazyQueryHookResult = ReturnType<typeof useGetMeLazyQuery>;
export type GetMeSuspenseQueryHookResult = ReturnType<typeof useGetMeSuspenseQuery>;
export type GetMeQueryResult = Apollo.QueryResult<GetMeQuery, GetMeQueryVariables>;
export const GetAccountsDocument = gql`
    query GetAccounts {
  accounts {
    id
    email
    insertedAt
  }
}
    `;

/**
 * __useGetAccountsQuery__
 *
 * To run a query within a React component, call `useGetAccountsQuery` and pass it any options that fit your needs.
 * When your component renders, `useGetAccountsQuery` returns an object from Apollo Client that contains loading, error, and data properties
 * you can use to render your UI.
 *
 * @param baseOptions options that will be passed into the query, supported options are listed on: https://www.apollographql.com/docs/react/api/react-hooks/#options;
 *
 * @example
 * const { data, loading, error } = useGetAccountsQuery({
 *   variables: {
 *   },
 * });
 */
export function useGetAccountsQuery(baseOptions?: Apollo.QueryHookOptions<GetAccountsQuery, GetAccountsQueryVariables>) {
        const options = {...defaultOptions, ...baseOptions}
        return Apollo.useQuery<GetAccountsQuery, GetAccountsQueryVariables>(GetAccountsDocument, options);
      }
export function useGetAccountsLazyQuery(baseOptions?: Apollo.LazyQueryHookOptions<GetAccountsQuery, GetAccountsQueryVariables>) {
          const options = {...defaultOptions, ...baseOptions}
          return Apollo.useLazyQuery<GetAccountsQuery, GetAccountsQueryVariables>(GetAccountsDocument, options);
        }
export function useGetAccountsSuspenseQuery(baseOptions?: Apollo.SkipToken | Apollo.SuspenseQueryHookOptions<GetAccountsQuery, GetAccountsQueryVariables>) {
          const options = baseOptions === Apollo.skipToken ? baseOptions : {...defaultOptions, ...baseOptions}
          return Apollo.useSuspenseQuery<GetAccountsQuery, GetAccountsQueryVariables>(GetAccountsDocument, options);
        }
export type GetAccountsQueryHookResult = ReturnType<typeof useGetAccountsQuery>;
export type GetAccountsLazyQueryHookResult = ReturnType<typeof useGetAccountsLazyQuery>;
export type GetAccountsSuspenseQueryHookResult = ReturnType<typeof useGetAccountsSuspenseQuery>;
export type GetAccountsQueryResult = Apollo.QueryResult<GetAccountsQuery, GetAccountsQueryVariables>;
export const GetConnectGmailUrlDocument = gql`
    query GetConnectGmailUrl {
  connectGmailUrl
}
    `;

/**
 * __useGetConnectGmailUrlQuery__
 *
 * To run a query within a React component, call `useGetConnectGmailUrlQuery` and pass it any options that fit your needs.
 * When your component renders, `useGetConnectGmailUrlQuery` returns an object from Apollo Client that contains loading, error, and data properties
 * you can use to render your UI.
 *
 * @param baseOptions options that will be passed into the query, supported options are listed on: https://www.apollographql.com/docs/react/api/react-hooks/#options;
 *
 * @example
 * const { data, loading, error } = useGetConnectGmailUrlQuery({
 *   variables: {
 *   },
 * });
 */
export function useGetConnectGmailUrlQuery(baseOptions?: Apollo.QueryHookOptions<GetConnectGmailUrlQuery, GetConnectGmailUrlQueryVariables>) {
        const options = {...defaultOptions, ...baseOptions}
        return Apollo.useQuery<GetConnectGmailUrlQuery, GetConnectGmailUrlQueryVariables>(GetConnectGmailUrlDocument, options);
      }
export function useGetConnectGmailUrlLazyQuery(baseOptions?: Apollo.LazyQueryHookOptions<GetConnectGmailUrlQuery, GetConnectGmailUrlQueryVariables>) {
          const options = {...defaultOptions, ...baseOptions}
          return Apollo.useLazyQuery<GetConnectGmailUrlQuery, GetConnectGmailUrlQueryVariables>(GetConnectGmailUrlDocument, options);
        }
export function useGetConnectGmailUrlSuspenseQuery(baseOptions?: Apollo.SkipToken | Apollo.SuspenseQueryHookOptions<GetConnectGmailUrlQuery, GetConnectGmailUrlQueryVariables>) {
          const options = baseOptions === Apollo.skipToken ? baseOptions : {...defaultOptions, ...baseOptions}
          return Apollo.useSuspenseQuery<GetConnectGmailUrlQuery, GetConnectGmailUrlQueryVariables>(GetConnectGmailUrlDocument, options);
        }
export type GetConnectGmailUrlQueryHookResult = ReturnType<typeof useGetConnectGmailUrlQuery>;
export type GetConnectGmailUrlLazyQueryHookResult = ReturnType<typeof useGetConnectGmailUrlLazyQuery>;
export type GetConnectGmailUrlSuspenseQueryHookResult = ReturnType<typeof useGetConnectGmailUrlSuspenseQuery>;
export type GetConnectGmailUrlQueryResult = Apollo.QueryResult<GetConnectGmailUrlQuery, GetConnectGmailUrlQueryVariables>;
export const DisconnectAccountDocument = gql`
    mutation DisconnectAccount($id: ID!) {
  disconnectAccount(id: $id) {
    id
  }
}
    `;
export type DisconnectAccountMutationFn = Apollo.MutationFunction<DisconnectAccountMutation, DisconnectAccountMutationVariables>;

/**
 * __useDisconnectAccountMutation__
 *
 * To run a mutation, you first call `useDisconnectAccountMutation` within a React component and pass it any options that fit your needs.
 * When your component renders, `useDisconnectAccountMutation` returns a tuple that includes:
 * - A mutate function that you can call at any time to execute the mutation
 * - An object with fields that represent the current status of the mutation's execution
 *
 * @param baseOptions options that will be passed into the mutation, supported options are listed on: https://www.apollographql.com/docs/react/api/react-hooks/#options-2;
 *
 * @example
 * const [disconnectAccountMutation, { data, loading, error }] = useDisconnectAccountMutation({
 *   variables: {
 *      id: // value for 'id'
 *   },
 * });
 */
export function useDisconnectAccountMutation(baseOptions?: Apollo.MutationHookOptions<DisconnectAccountMutation, DisconnectAccountMutationVariables>) {
        const options = {...defaultOptions, ...baseOptions}
        return Apollo.useMutation<DisconnectAccountMutation, DisconnectAccountMutationVariables>(DisconnectAccountDocument, options);
      }
export type DisconnectAccountMutationHookResult = ReturnType<typeof useDisconnectAccountMutation>;
export type DisconnectAccountMutationResult = Apollo.MutationResult<DisconnectAccountMutation>;
export type DisconnectAccountMutationOptions = Apollo.BaseMutationOptions<DisconnectAccountMutation, DisconnectAccountMutationVariables>;
export const TriggerPollDocument = gql`
    mutation TriggerPoll($accountId: ID) {
  triggerPoll(accountId: $accountId)
}
    `;
export type TriggerPollMutationFn = Apollo.MutationFunction<TriggerPollMutation, TriggerPollMutationVariables>;

/**
 * __useTriggerPollMutation__
 *
 * To run a mutation, you first call `useTriggerPollMutation` within a React component and pass it any options that fit your needs.
 * When your component renders, `useTriggerPollMutation` returns a tuple that includes:
 * - A mutate function that you can call at any time to execute the mutation
 * - An object with fields that represent the current status of the mutation's execution
 *
 * @param baseOptions options that will be passed into the mutation, supported options are listed on: https://www.apollographql.com/docs/react/api/react-hooks/#options-2;
 *
 * @example
 * const [triggerPollMutation, { data, loading, error }] = useTriggerPollMutation({
 *   variables: {
 *      accountId: // value for 'accountId'
 *   },
 * });
 */
export function useTriggerPollMutation(baseOptions?: Apollo.MutationHookOptions<TriggerPollMutation, TriggerPollMutationVariables>) {
        const options = {...defaultOptions, ...baseOptions}
        return Apollo.useMutation<TriggerPollMutation, TriggerPollMutationVariables>(TriggerPollDocument, options);
      }
export type TriggerPollMutationHookResult = ReturnType<typeof useTriggerPollMutation>;
export type TriggerPollMutationResult = Apollo.MutationResult<TriggerPollMutation>;
export type TriggerPollMutationOptions = Apollo.BaseMutationOptions<TriggerPollMutation, TriggerPollMutationVariables>;
export const PollingStatusDocument = gql`
    query PollingStatus($accountId: ID) {
  pollingStatus(accountId: $accountId)
}
    `;

/**
 * __usePollingStatusQuery__
 *
 * To run a query within a React component, call `usePollingStatusQuery` and pass it any options that fit your needs.
 * When your component renders, `usePollingStatusQuery` returns an object from Apollo Client that contains loading, error, and data properties
 * you can use to render your UI.
 *
 * @param baseOptions options that will be passed into the query, supported options are listed on: https://www.apollographql.com/docs/react/api/react-hooks/#options;
 *
 * @example
 * const { data, loading, error } = usePollingStatusQuery({
 *   variables: {
 *      accountId: // value for 'accountId'
 *   },
 * });
 */
export function usePollingStatusQuery(baseOptions?: Apollo.QueryHookOptions<PollingStatusQuery, PollingStatusQueryVariables>) {
        const options = {...defaultOptions, ...baseOptions}
        return Apollo.useQuery<PollingStatusQuery, PollingStatusQueryVariables>(PollingStatusDocument, options);
      }
export function usePollingStatusLazyQuery(baseOptions?: Apollo.LazyQueryHookOptions<PollingStatusQuery, PollingStatusQueryVariables>) {
          const options = {...defaultOptions, ...baseOptions}
          return Apollo.useLazyQuery<PollingStatusQuery, PollingStatusQueryVariables>(PollingStatusDocument, options);
        }
export function usePollingStatusSuspenseQuery(baseOptions?: Apollo.SkipToken | Apollo.SuspenseQueryHookOptions<PollingStatusQuery, PollingStatusQueryVariables>) {
          const options = baseOptions === Apollo.skipToken ? baseOptions : {...defaultOptions, ...baseOptions}
          return Apollo.useSuspenseQuery<PollingStatusQuery, PollingStatusQueryVariables>(PollingStatusDocument, options);
        }
export type PollingStatusQueryHookResult = ReturnType<typeof usePollingStatusQuery>;
export type PollingStatusLazyQueryHookResult = ReturnType<typeof usePollingStatusLazyQuery>;
export type PollingStatusSuspenseQueryHookResult = ReturnType<typeof usePollingStatusSuspenseQuery>;
export type PollingStatusQueryResult = Apollo.QueryResult<PollingStatusQuery, PollingStatusQueryVariables>;