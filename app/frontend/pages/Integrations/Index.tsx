import { Head, useForm, router, usePage } from '@inertiajs/react'
import { useState } from 'react'

interface StripeAccount {
  id: string | null
  label: string | null
  country: string | null
  default_currency: string | null
}

interface StripeState {
  connected: boolean
  verified: boolean
  masked_key: string | null
  account: StripeAccount
  connected_at: string | null
}

interface Props {
  stripe: StripeState
  errors?: {
    stripe_api_key?: string[]
    base?: string[]
  } | null
}

export default function Index({ stripe, errors }: Props) {
  const { props } = usePage<{ flash?: { notice?: string; alert?: string } }>()
  const flash = props.flash

  const [showInstructions, setShowInstructions] = useState(!stripe.connected)
  const [showReplaceForm, setShowReplaceForm] = useState(false)

  const form = useForm({
    api_key: '',
  })

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    form.post('/integrations/stripe', {
      preserveScroll: true,
      onSuccess: () => form.reset(),
    })
  }

  const testConnection = () => {
    router.post('/integrations/stripe/test', {}, { preserveScroll: true })
  }

  const disconnect = () => {
    if (!confirm('Disconnect Stripe? You can reconnect any time.')) return
    router.delete('/integrations/stripe', { preserveScroll: true })
  }

  return (
    <>
      <Head title="Integrations" />

      <div className="container mx-auto px-4 py-8 max-w-4xl">
        <h1 className="text-3xl font-bold mb-2">Integrations</h1>
        <p className="text-base-content/70 mb-8">
          Connect external services to pull data into your account.
        </p>

        {flash?.notice && (
          <div className="alert alert-success mb-4" role="alert">
            <span>{flash.notice}</span>
          </div>
        )}
        {flash?.alert && (
          <div className="alert alert-error mb-4" role="alert">
            <span>{flash.alert}</span>
          </div>
        )}

        {/* Stripe card */}
        <div className="card bg-base-100 shadow-xl mb-6">
          <div className="card-body">
            <div className="flex items-start justify-between flex-wrap gap-2">
              <div>
                <h2 className="card-title text-2xl">Stripe</h2>
                <p className="text-sm text-base-content/70">
                  Connect your Stripe account to import payouts and transactions.
                </p>
              </div>
              <ConnectionBadge stripe={stripe} />
            </div>

            <div className="divider my-2"></div>

            {/* CONNECTED (verified) */}
            {stripe.connected && stripe.verified && (
              <div className="space-y-4">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <Detail label="Account" value={stripe.account.label || stripe.account.id} />
                  <Detail label="Account ID" value={stripe.account.id} mono />
                  <Detail label="Country" value={stripe.account.country} />
                  <Detail
                    label="Default currency"
                    value={(stripe.account.default_currency || '').toUpperCase()}
                  />
                  <Detail
                    label="Last verified"
                    value={stripe.connected_at ? new Date(stripe.connected_at).toLocaleString() : '—'}
                  />
                  <Detail label="API key" value={stripe.masked_key || '—'} mono />
                </div>

                <div className="card-actions justify-end flex-wrap gap-2">
                  <button
                    type="button"
                    onClick={() => setShowReplaceForm((s) => !s)}
                    className="btn btn-outline"
                  >
                    {showReplaceForm ? 'Cancel replace' : 'Replace API key'}
                  </button>
                  <button
                    type="button"
                    onClick={testConnection}
                    className="btn btn-primary"
                  >
                    Test Connection
                  </button>
                  <button
                    type="button"
                    onClick={disconnect}
                    className="btn btn-error btn-outline"
                  >
                    Disconnect
                  </button>
                </div>

                {showReplaceForm && <ReplaceForm errors={errors} />}
              </div>
            )}

            {/* CONNECTED (saved but not verified) */}
            {stripe.connected && !stripe.verified && (
              <div className="space-y-4">
                <div className="alert alert-warning">
                  <span>
                    API key saved but connection not yet verified. Click <b>Test Connection</b> to
                    confirm the key works and pull your account details.
                  </span>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <Detail label="API key" value={stripe.masked_key || '—'} mono />
                </div>

                <div className="card-actions justify-end flex-wrap gap-2">
                  <button
                    type="button"
                    onClick={() => setShowReplaceForm((s) => !s)}
                    className="btn btn-outline"
                  >
                    {showReplaceForm ? 'Cancel replace' : 'Replace API key'}
                  </button>
                  <button
                    type="button"
                    onClick={testConnection}
                    className="btn btn-primary"
                  >
                    Test Connection
                  </button>
                  <button
                    type="button"
                    onClick={disconnect}
                    className="btn btn-error btn-outline"
                  >
                    Disconnect
                  </button>
                </div>

                {showReplaceForm && <ReplaceForm errors={errors} />}
              </div>
            )}

            {/* NOT CONNECTED */}
            {!stripe.connected && (
              <div className="space-y-4">
                <Instructions
                  open={showInstructions}
                  onToggle={() => setShowInstructions((s) => !s)}
                />

                <form onSubmit={submit} className="space-y-3">
                  <label className="form-control w-full" htmlFor="stripe-api-key">
                    <div className="label">
                      <span className="label-text font-semibold">Stripe restricted API key</span>
                    </div>
                    <input
                      id="stripe-api-key"
                      type="password"
                      autoComplete="off"
                      placeholder="rk_test_..."
                      className={`input input-bordered w-full ${
                        errors?.stripe_api_key ? 'input-error' : ''
                      }`}
                      value={form.data.api_key}
                      onChange={(e) => form.setData('api_key', e.target.value)}
                    />
                    {errors?.stripe_api_key && (
                      <div className="label">
                        <span className="label-text-alt text-error">
                          {errors.stripe_api_key[0]}
                        </span>
                      </div>
                    )}
                  </label>

                  <div className="card-actions justify-end">
                    <button
                      type="submit"
                      disabled={form.processing || form.data.api_key.trim() === ''}
                      className="btn btn-primary"
                    >
                      {form.processing ? 'Saving…' : 'Save API Key'}
                    </button>
                  </div>
                </form>
              </div>
            )}
          </div>
        </div>

        <p className="text-xs text-base-content/60">
          Future integrations (e.g. Google Drive, banks) will appear here.
        </p>
      </div>
    </>
  )
}

function ConnectionBadge({ stripe }: { stripe: StripeState }) {
  if (!stripe.connected) {
    return <span className="badge badge-ghost">Not connected</span>
  }
  if (!stripe.verified) {
    return <span className="badge badge-warning">Saved · not verified</span>
  }
  return <span className="badge badge-success">Connected</span>
}

function Detail({ label, value, mono }: { label: string; value: string | null; mono?: boolean }) {
  return (
    <div>
      <div className="text-xs uppercase tracking-wide text-base-content/60">{label}</div>
      <div className={`mt-1 ${mono ? 'font-mono text-sm' : 'font-semibold'}`}>
        {value || '—'}
      </div>
    </div>
  )
}

function Instructions({ open, onToggle }: { open: boolean; onToggle: () => void }) {
  return (
    <div className="collapse collapse-arrow border border-base-300 bg-base-200/50">
      <input type="checkbox" checked={open} onChange={onToggle} aria-label="Show instructions" />
      <div className="collapse-title font-semibold">
        How to create a Stripe restricted API key
      </div>
      <div className="collapse-content text-sm space-y-3">
        <p>
          A <b>restricted key</b> only has the permissions you explicitly grant — much safer than
          pasting your full secret key.
        </p>
        <ol className="list-decimal list-inside space-y-2">
          <li>
            Sign in to the{' '}
            <a
              className="link link-primary"
              href="https://dashboard.stripe.com/apikeys"
              target="_blank"
              rel="noreferrer"
            >
              Stripe Dashboard → API keys
            </a>
            .
          </li>
          <li>
            Click <b>Create restricted key</b>.
          </li>
          <li>
            Give it a name (e.g. <code>stripe-tax-app</code>) and pick the resources this app
            needs:
            <ul className="list-disc list-inside ml-6 mt-1 space-y-1">
              <li>
                <code>All balances</code> with read access
              </li>
              <li>
                <code>All payouts</code> with read access
              </li>
              <li>
                <code>All balance transactions</code> with read access
              </li>
            </ul>
          </li>
          <li>
            Click <b>Create key</b>, then copy the <code>rk_test_…</code> or <code>rk_live_…</code>{' '}
            value and paste it in the field below.
          </li>
        </ol>
        <p className="text-xs text-base-content/60">
          The key is encrypted at rest. You can rotate or revoke it any time from the Stripe
          dashboard.
        </p>
      </div>
    </div>
  )
}

function ReplaceForm({ errors }: { errors?: Props['errors'] }) {
  const form = useForm({ api_key: '' })

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    form.post('/integrations/stripe', {
      preserveScroll: true,
      onSuccess: () => form.reset(),
    })
  }

  return (
    <form onSubmit={submit} className="space-y-2 border-t border-base-300 pt-4">
      <label className="form-control w-full" htmlFor="stripe-api-key-replace">
        <div className="label">
          <span className="label-text font-semibold">New restricted API key</span>
        </div>
        <input
          id="stripe-api-key-replace"
          type="password"
          autoComplete="off"
          placeholder="rk_test_..."
          className={`input input-bordered w-full ${
            errors?.stripe_api_key ? 'input-error' : ''
          }`}
          value={form.data.api_key}
          onChange={(e) => form.setData('api_key', e.target.value)}
        />
        {errors?.stripe_api_key && (
          <div className="label">
            <span className="label-text-alt text-error">{errors.stripe_api_key[0]}</span>
          </div>
        )}
      </label>
      <div className="card-actions justify-end">
        <button
          type="submit"
          disabled={form.processing || form.data.api_key.trim() === ''}
          className="btn btn-primary"
        >
          {form.processing ? 'Saving…' : 'Save new key'}
        </button>
      </div>
    </form>
  )
}
