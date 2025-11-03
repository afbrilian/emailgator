/* eslint-disable */
import * as types from './graphql';
import { TypedDocumentNode as DocumentNode } from '@graphql-typed-document-node/core';

/**
 * Map of all GraphQL operations in the project.
 *
 * This map has several performance disadvantages:
 * 1. It is not tree-shakeable, so it will include all operations in the project.
 * 2. It is not minifiable, so the string of a GraphQL query will be multiple times inside the bundle.
 * 3. It does not support dead code elimination, so it will add unused operations.
 *
 * Therefore it is highly recommended to use the babel or swc plugin for production.
 * Learn more about it here: https://the-guild.dev/graphql/codegen/plugins/presets/preset-client#reducing-bundle-size
 */
type Documents = {
    "query GetCategories {\n  categories {\n    id\n    name\n    description\n    insertedAt\n    updatedAt\n  }\n}\n\nmutation CreateCategory($name: String!, $description: String) {\n  createCategory(name: $name, description: $description) {\n    id\n    name\n    description\n  }\n}\n\nmutation UpdateCategory($id: ID!, $name: String, $description: String) {\n  updateCategory(id: $id, name: $name, description: $description) {\n    id\n    name\n    description\n  }\n}\n\nmutation DeleteCategory($id: ID!) {\n  deleteCategory(id: $id) {\n    id\n  }\n}": typeof types.GetCategoriesDocument,
    "query GetCategoryEmails($categoryId: ID!) {\n  category(id: $categoryId) {\n    id\n    name\n    description\n  }\n  categoryEmails(categoryId: $categoryId) {\n    id\n    subject\n    from\n    snippet\n    summary\n    archivedAt\n    insertedAt\n    unsubscribeUrls\n    isUnsubscribed\n  }\n}\n\nmutation DeleteEmails($emailIds: [ID!]!) {\n  deleteEmails(emailIds: $emailIds)\n}\n\nmutation UnsubscribeEmails($emailIds: [ID!]!) {\n  unsubscribeEmails(emailIds: $emailIds) {\n    emailId\n    success\n    error\n  }\n}\n\nquery GetEmail($id: ID!) {\n  email(id: $id) {\n    id\n    subject\n    from\n    snippet\n    summary\n    bodyText\n    bodyHtml\n    unsubscribeUrls\n    archivedAt\n    insertedAt\n    updatedAt\n    isUnsubscribed\n    category {\n      id\n      name\n    }\n    unsubscribeAttempts {\n      id\n      method\n      url\n      status\n      evidence\n      insertedAt\n      updatedAt\n    }\n  }\n}": typeof types.GetCategoryEmailsDocument,
    "query GetMe {\n  me {\n    id\n    email\n    name\n  }\n}\n\nquery GetAccounts {\n  accounts {\n    id\n    email\n    insertedAt\n  }\n}\n\nquery GetConnectGmailUrl {\n  connectGmailUrl\n}\n\nmutation DisconnectAccount($id: ID!) {\n  disconnectAccount(id: $id) {\n    id\n  }\n}\n\nmutation TriggerPoll($accountId: ID) {\n  triggerPoll(accountId: $accountId)\n}\n\nquery PollingStatus($accountId: ID) {\n  pollingStatus(accountId: $accountId)\n}": typeof types.GetMeDocument,
};
const documents: Documents = {
    "query GetCategories {\n  categories {\n    id\n    name\n    description\n    insertedAt\n    updatedAt\n  }\n}\n\nmutation CreateCategory($name: String!, $description: String) {\n  createCategory(name: $name, description: $description) {\n    id\n    name\n    description\n  }\n}\n\nmutation UpdateCategory($id: ID!, $name: String, $description: String) {\n  updateCategory(id: $id, name: $name, description: $description) {\n    id\n    name\n    description\n  }\n}\n\nmutation DeleteCategory($id: ID!) {\n  deleteCategory(id: $id) {\n    id\n  }\n}": types.GetCategoriesDocument,
    "query GetCategoryEmails($categoryId: ID!) {\n  category(id: $categoryId) {\n    id\n    name\n    description\n  }\n  categoryEmails(categoryId: $categoryId) {\n    id\n    subject\n    from\n    snippet\n    summary\n    archivedAt\n    insertedAt\n    unsubscribeUrls\n    isUnsubscribed\n  }\n}\n\nmutation DeleteEmails($emailIds: [ID!]!) {\n  deleteEmails(emailIds: $emailIds)\n}\n\nmutation UnsubscribeEmails($emailIds: [ID!]!) {\n  unsubscribeEmails(emailIds: $emailIds) {\n    emailId\n    success\n    error\n  }\n}\n\nquery GetEmail($id: ID!) {\n  email(id: $id) {\n    id\n    subject\n    from\n    snippet\n    summary\n    bodyText\n    bodyHtml\n    unsubscribeUrls\n    archivedAt\n    insertedAt\n    updatedAt\n    isUnsubscribed\n    category {\n      id\n      name\n    }\n    unsubscribeAttempts {\n      id\n      method\n      url\n      status\n      evidence\n      insertedAt\n      updatedAt\n    }\n  }\n}": types.GetCategoryEmailsDocument,
    "query GetMe {\n  me {\n    id\n    email\n    name\n  }\n}\n\nquery GetAccounts {\n  accounts {\n    id\n    email\n    insertedAt\n  }\n}\n\nquery GetConnectGmailUrl {\n  connectGmailUrl\n}\n\nmutation DisconnectAccount($id: ID!) {\n  disconnectAccount(id: $id) {\n    id\n  }\n}\n\nmutation TriggerPoll($accountId: ID) {\n  triggerPoll(accountId: $accountId)\n}\n\nquery PollingStatus($accountId: ID) {\n  pollingStatus(accountId: $accountId)\n}": types.GetMeDocument,
};

/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 *
 *
 * @example
 * ```ts
 * const query = graphql(`query GetUser($id: ID!) { user(id: $id) { name } }`);
 * ```
 *
 * The query argument is unknown!
 * Please regenerate the types.
 */
export function graphql(source: string): unknown;

/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function graphql(source: "query GetCategories {\n  categories {\n    id\n    name\n    description\n    insertedAt\n    updatedAt\n  }\n}\n\nmutation CreateCategory($name: String!, $description: String) {\n  createCategory(name: $name, description: $description) {\n    id\n    name\n    description\n  }\n}\n\nmutation UpdateCategory($id: ID!, $name: String, $description: String) {\n  updateCategory(id: $id, name: $name, description: $description) {\n    id\n    name\n    description\n  }\n}\n\nmutation DeleteCategory($id: ID!) {\n  deleteCategory(id: $id) {\n    id\n  }\n}"): (typeof documents)["query GetCategories {\n  categories {\n    id\n    name\n    description\n    insertedAt\n    updatedAt\n  }\n}\n\nmutation CreateCategory($name: String!, $description: String) {\n  createCategory(name: $name, description: $description) {\n    id\n    name\n    description\n  }\n}\n\nmutation UpdateCategory($id: ID!, $name: String, $description: String) {\n  updateCategory(id: $id, name: $name, description: $description) {\n    id\n    name\n    description\n  }\n}\n\nmutation DeleteCategory($id: ID!) {\n  deleteCategory(id: $id) {\n    id\n  }\n}"];
/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function graphql(source: "query GetCategoryEmails($categoryId: ID!) {\n  category(id: $categoryId) {\n    id\n    name\n    description\n  }\n  categoryEmails(categoryId: $categoryId) {\n    id\n    subject\n    from\n    snippet\n    summary\n    archivedAt\n    insertedAt\n    unsubscribeUrls\n    isUnsubscribed\n  }\n}\n\nmutation DeleteEmails($emailIds: [ID!]!) {\n  deleteEmails(emailIds: $emailIds)\n}\n\nmutation UnsubscribeEmails($emailIds: [ID!]!) {\n  unsubscribeEmails(emailIds: $emailIds) {\n    emailId\n    success\n    error\n  }\n}\n\nquery GetEmail($id: ID!) {\n  email(id: $id) {\n    id\n    subject\n    from\n    snippet\n    summary\n    bodyText\n    bodyHtml\n    unsubscribeUrls\n    archivedAt\n    insertedAt\n    updatedAt\n    isUnsubscribed\n    category {\n      id\n      name\n    }\n    unsubscribeAttempts {\n      id\n      method\n      url\n      status\n      evidence\n      insertedAt\n      updatedAt\n    }\n  }\n}"): (typeof documents)["query GetCategoryEmails($categoryId: ID!) {\n  category(id: $categoryId) {\n    id\n    name\n    description\n  }\n  categoryEmails(categoryId: $categoryId) {\n    id\n    subject\n    from\n    snippet\n    summary\n    archivedAt\n    insertedAt\n    unsubscribeUrls\n    isUnsubscribed\n  }\n}\n\nmutation DeleteEmails($emailIds: [ID!]!) {\n  deleteEmails(emailIds: $emailIds)\n}\n\nmutation UnsubscribeEmails($emailIds: [ID!]!) {\n  unsubscribeEmails(emailIds: $emailIds) {\n    emailId\n    success\n    error\n  }\n}\n\nquery GetEmail($id: ID!) {\n  email(id: $id) {\n    id\n    subject\n    from\n    snippet\n    summary\n    bodyText\n    bodyHtml\n    unsubscribeUrls\n    archivedAt\n    insertedAt\n    updatedAt\n    isUnsubscribed\n    category {\n      id\n      name\n    }\n    unsubscribeAttempts {\n      id\n      method\n      url\n      status\n      evidence\n      insertedAt\n      updatedAt\n    }\n  }\n}"];
/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function graphql(source: "query GetMe {\n  me {\n    id\n    email\n    name\n  }\n}\n\nquery GetAccounts {\n  accounts {\n    id\n    email\n    insertedAt\n  }\n}\n\nquery GetConnectGmailUrl {\n  connectGmailUrl\n}\n\nmutation DisconnectAccount($id: ID!) {\n  disconnectAccount(id: $id) {\n    id\n  }\n}\n\nmutation TriggerPoll($accountId: ID) {\n  triggerPoll(accountId: $accountId)\n}\n\nquery PollingStatus($accountId: ID) {\n  pollingStatus(accountId: $accountId)\n}"): (typeof documents)["query GetMe {\n  me {\n    id\n    email\n    name\n  }\n}\n\nquery GetAccounts {\n  accounts {\n    id\n    email\n    insertedAt\n  }\n}\n\nquery GetConnectGmailUrl {\n  connectGmailUrl\n}\n\nmutation DisconnectAccount($id: ID!) {\n  disconnectAccount(id: $id) {\n    id\n  }\n}\n\nmutation TriggerPoll($accountId: ID) {\n  triggerPoll(accountId: $accountId)\n}\n\nquery PollingStatus($accountId: ID) {\n  pollingStatus(accountId: $accountId)\n}"];

export function graphql(source: string) {
  return (documents as any)[source] ?? {};
}

export type DocumentType<TDocumentNode extends DocumentNode<any, any>> = TDocumentNode extends DocumentNode<  infer TType,  any>  ? TType  : never;