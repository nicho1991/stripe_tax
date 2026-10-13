import { Head, Link, router } from '@inertiajs/react'
import { useState } from 'react'

interface Props {
  user: {
    id: number
    email_address: string
    stripe_configured: boolean
    stripe_last4: string | null
    stripe_placeholder: string
  }
  errors?: string[]
  flash?: { notice?: string; alert?: string }
}

export default function Index({ user, errors, flash }: Props) {
  // The form submits the typed secret; if the user clicks Save without
  // touching the field we treat it as a no-op (the placeholder check
  // happens server-side too — see SettingsController).
  const [stripeSecret, setStripeSecret] = useState('')
  const [submitting, setSubmitting] = useState(false)

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault()
    setSubmitting(true)
    router.patch('/settings', {
      user: { stripe_secret_key: stripeSecret }
    }, {
      onFinish: () => setSubmitting(false)
    })
  }

  const handleRemove = (e: React.MouseEvent) => {
    e.preventDefault()
    if (!confirm('Remove your Stripe API key? You\'ll need to set it again before you can fetch from Stripe.')) return
    setSubmitting(true)
    router.visit('/settings/stripe_secret_key', {
      method: 'delete',
      onFinish: () => setSubmitting(false)
    })
  }

  return (
    <>
      <Head title="Settings" />

      <div className="container mx-auto px-4 py-8 max-w-2xl">
        <div className="mb-6">
          <Link href="/dashboard" className="btn btn-ghost btn-sm mb-4">
            ← Back to Dashboard
          </Link>
          <h1 className="text-3xl font-bold">Settings</h1>
          <p className="text-gray-600 mt-2">
            Manage your Stripe integration. Your API key is encrypted at rest.
          </p>
        </div>

        {flash?.notice && (
          <div className="alert alert-success mb-4">
            <span>{flash.notice}</span>
          </div>
        )}
        {flash?.alert && (
          <div className="alert alert-warning mb-4">
            <span>{flash.alert}</span>
          </div>
        )}

        {errors && errors.length > 0 && (
          <div className="alert alert-error mb-4">
            <ul className="list-disc list-inside">
              {errors.map((e, i) => (
                <li key={i}>{e}</li>
              ))}
            </ul>
          </div>
        )}

        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h2 className="card-title">Account</h2>
            <p className="text-sm text-gray-600">
              Signed in as <span className="font-mono">{user.email_address}</span>
            </p>

            <div className="divider" />

            <h2 className="card-title">Stripe API key</h2>
            <p className="text-sm text-gray-600 mb-2">
              Required for the "Fetch from Stripe" tab on the New Payout page.
              Get your key at{' '}
              <a
                href="https://dashboard.stripe.com/apikeys"
                className="link link-info"
                target="_blank"
                rel="noreferrer"
              >
                dashboard.stripe.com/apikeys
              </a>{' '}
              — use <code className="text-xs">sk_test_…</code> for testing,
              <code className="text-xs">sk_live_…</code> for production.
            </p>

            {user.stripe_configured ? (
              <div className="alert alert-success mb-4">
                <div>
                  <span>Stripe API key configured.</span>
                  {user.stripe_last4 && (
                    <span className="text-sm font-mono ml-2">
                      Ending in …{user.stripe_last4}
                    </span>
                  )}
                </div>
              </div>
            ) : (
              <div className="alert alert-warning mb-4">
                <span>No Stripe API key configured — the "Fetch from Stripe" tab on the New Payout page will be disabled.</span>
              </div>
            )}

            <form onSubmit={handleSave}>
              <div className="form-control mb-4">
                <label className="label">
                  <span className="label-text">
                    {user.stripe_configured ? 'Replace API key (paste new value to update)' : 'Paste your Stripe API key'}
                  </span>
                </label>
                <input
                  type="password"
                  autoComplete="off"
                  spellCheck={false}
                  value={stripeSecret}
                  onChange={(e) => setStripeSecret(e.target.value)}
                  placeholder={user.stripe_placeholder}
                  className="input input-bordered w-full font-mono"
                />
              </div>

              <div className="card-actions justify-between">
                {user.stripe_configured && (
                  <button
                    type="button"
                    onClick={handleRemove}
                    className="btn btn-error btn-outline"
                    disabled={submitting}
                  >
                    Remove key
                  </button>
                )}
                <button
                  type="submit"
                  className="btn btn-primary"
                  disabled={submitting || stripeSecret.trim().length === 0}
                >
                  {submitting ? 'Saving…' : 'Save'}
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </>
  )
}