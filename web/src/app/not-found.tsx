import { Calendar } from 'lucide-react'

export default function NotFound() {
  return (
    <div className="min-h-screen bg-background flex items-center justify-center p-6">
      <div className="text-center max-w-md">
        <div className="w-20 h-20 rounded-2xl bg-card border border-border flex items-center justify-center mx-auto mb-6">
          <Calendar className="w-10 h-10 text-text-tertiary" />
        </div>

        <h1 className="text-3xl font-bold text-white mb-3">Page Not Found</h1>
        <p className="text-text-secondary mb-8">
          The page you&apos;re looking for doesn&apos;t exist or may have been moved.
        </p>
      </div>
    </div>
  )
}
