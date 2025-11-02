module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/__tests__/**/*.test.js'],
  testTimeout: 30000, // 30 seconds for browser automation tests
  coveragePathIgnorePatterns: ['/node_modules/', '/__tests__/'],
};

