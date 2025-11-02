#!/usr/bin/env node

/**
 * Post-codegen script to remove duplicate DocumentNode exports.
 * 
 * GraphQL Codegen generates two versions of each document:
 * 1. Typed DocumentNode (AST format) - line ~100-220
 * 2. gql template literal - line ~400-600
 * 
 * Apollo Client only needs the gql template literal version.
 * This script removes the duplicate typed DocumentNode versions.
 */

const fs = require('fs');
const path = require('path');

const graphqlFile = path.join(__dirname, '../src/gql/graphql.ts');

if (!fs.existsSync(graphqlFile)) {
  console.log('⚠️  graphql.ts not found, skipping duplicate removal');
  process.exit(0);
}

console.log('🔧 Removing duplicate DocumentNode exports from graphql.ts...');

let content = fs.readFileSync(graphqlFile, 'utf8');
const lines = content.split('\n');

// Pattern to match: export const XDocument = {"kind":"Document"...
const duplicatePattern = /^export const \w+Document = \{"kind":"Document"/;

// Find and remove duplicate lines
let removedCount = 0;
const filteredLines = lines.filter((line, index) => {
  if (duplicatePattern.test(line)) {
    removedCount++;
    console.log(`  ✂️  Removing duplicate at line ${index + 1}: ${line.substring(0, 60)}...`);
    return false;
  }
  return true;
});

if (removedCount === 0) {
  console.log('✅ No duplicates found (or already fixed)');
} else {
  fs.writeFileSync(graphqlFile, filteredLines.join('\n'), 'utf8');
  console.log(`✅ Removed ${removedCount} duplicate DocumentNode export(s)`);
}

// Also fix index.ts to export all necessary documents and hooks
console.log('\n🔧 Fixing index.ts exports...');
const indexFile = path.join(__dirname, '../src/gql/index.ts');

if (!fs.existsSync(indexFile)) {
  console.log('⚠️  index.ts not found, skipping');
  process.exit(0);
}

// List of all documents and hooks we need to export
const exportsToAdd = `export * from "./fragment-masking";
export * from "./gql";
// Re-export documents and hooks from graphql.ts
export type * from "./graphql";
export {
  GetMeDocument,
  GetAccountsDocument,
  GetConnectGmailUrlDocument,
  DisconnectAccountDocument,
  GetCategoriesDocument,
  CreateCategoryDocument,
  UpdateCategoryDocument,
  DeleteCategoryDocument,
  GetCategoryEmailsDocument,
  DeleteEmailsDocument,
  UnsubscribeEmailsDocument,
  useGetMeQuery,
  useGetAccountsQuery,
  useGetConnectGmailUrlQuery,
  useDisconnectAccountMutation,
  useGetCategoriesQuery,
  useCreateCategoryMutation,
  useUpdateCategoryMutation,
  useDeleteCategoryMutation,
  useGetCategoryEmailsQuery,
  useDeleteEmailsMutation,
  useUnsubscribeEmailsMutation,
} from "./graphql";
`;

fs.writeFileSync(indexFile, exportsToAdd, 'utf8');
console.log('✅ Fixed index.ts exports');

