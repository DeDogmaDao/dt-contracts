module.exports = {
  root: true,
  parserOptions: {
    ecmaVersion: 8,
    sourceType: 'module',
  },
  extends: ['eslint:recommended', 'airbnb-base'],
  env: {
    node: true,
    mocha: true,
  },
  rules: {
    strict: 0,
    'max-len': ['error', { code: 120 }],
    'quote-props': 'off',
    'no-param-reassign': 'off',
    'no-underscore-dangle': 'off',
    'func-names': ['error', 'as-needed'],
    'prefer-const': 'warn',
    radix: 'off',
    'no-restricted-syntax': ['error', "BinaryExpression[operator='at']"],
    'no-await-in-loop': 'off',
    'no-trailing-spaces': 'off',
    'no-throw-literal': 'off',
    'object-curly-spacing': 'off',
    'object-curly-newline': [
      'error',
      {
        ObjectExpression: { multiline: true, minProperties: 6, consistent: true },
        ObjectPattern: { multiline: true, minProperties: 6, consistent: true },
        ImportDeclaration: { multiline: true, minProperties: 6, consistent: true },
        ExportDeclaration: { multiline: true, minProperties: 6, consistent: true },
      },
    ],
    'global-require': 'off',
    'import/no-dynamic-require': 'off',
    'node/no-unsupported-features/es-syntax': ['error', { ignores: ['modules'] }],
  },
}
