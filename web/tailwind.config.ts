import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        // Dark, cinematic theme
        background: '#05070C',
        'background-secondary': '#0B0F17',
        surface: '#111827',
        'surface-secondary': '#0F1522',
        border: '#1F2937',
        'border-light': '#2B3446',

        // Text hierarchy
        'text-primary': '#F4F7FF',
        'text-secondary': '#B9C6DD',
        'text-tertiary': '#7C8AA5',

        // Accent colors
        accent: {
          blue: '#7EA6FF',
          ice: '#C7D7FF',
          cyan: '#7FE7FF',
          violet: '#8B7CFF',
          teal: '#44D7B6',
          green: '#22C55E',
          orange: '#F59E0B',
          red: '#F87171',
        },

        // Brand colors (from app)
        brand: {
          blue: '#3B82F6',
          green: '#22C55E',
          orange: '#F97316',
        },
      },
      fontFamily: {
        display: ['var(--font-display)', 'system-ui', 'sans-serif'],
        body: ['var(--font-body)', 'system-ui', 'sans-serif'],
      },
      fontSize: {
        'hero': ['clamp(2.5rem, 6vw, 4.5rem)', { lineHeight: '1.05', letterSpacing: '-0.025em' }],
        'display': ['clamp(2rem, 4vw, 3rem)', { lineHeight: '1.1', letterSpacing: '-0.02em' }],
        'title': ['clamp(1.5rem, 3vw, 2rem)', { lineHeight: '1.2', letterSpacing: '-0.01em' }],
      },
      animation: {
        'fade-in': 'fadeIn 0.8s ease-out forwards',
        'slide-up': 'slideUp 0.8s ease-out forwards',
        'float': 'float 6s ease-in-out infinite',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideUp: {
          '0%': { opacity: '0', transform: 'translateY(40px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        float: {
          '0%, 100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-12px)' },
        },
      },
      boxShadow: {
        'soft': '0 12px 40px -24px rgba(2, 6, 23, 0.7), 0 4px 12px -6px rgba(2, 6, 23, 0.5)',
        'medium': '0 20px 60px -36px rgba(2, 6, 23, 0.8), 0 8px 20px -10px rgba(2, 6, 23, 0.6)',
        'elevated': '0 30px 80px -48px rgba(2, 6, 23, 0.85), 0 12px 32px -12px rgba(2, 6, 23, 0.7)',
        'phone': '0 25px 50px -12px rgba(0, 0, 0, 0.4), 0 12px 24px -8px rgba(0, 0, 0, 0.3)',
      },
    },
  },
  plugins: [],
}

export default config
