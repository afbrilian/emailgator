/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        airbnb: {
          red: '#FF385C',
          'red-dark': '#E61E4D',
          'red-light': '#FF5A5F',
          'gray-100': '#F7F7F7',
          'gray-200': '#EBEBEB',
          'gray-300': '#DDDDDD',
          'gray-800': '#222222',
        },
      },
      fontFamily: {
        sans: [
          '-apple-system',
          'BlinkMacSystemFont',
          'Segoe UI',
          'Roboto',
          'Oxygen',
          'Ubuntu',
          'Cantarell',
          'Fira Sans',
          'Droid Sans',
          'Helvetica Neue',
          'sans-serif',
        ],
      },
      boxShadow: {
        'soft': '0 2px 16px rgba(0, 0, 0, 0.08)',
        'medium': '0 4px 24px rgba(0, 0, 0, 0.12)',
      },
    },
  },
  plugins: [],
}

