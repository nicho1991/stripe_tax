import { Head, Link, useForm } from '@inertiajs/react'
import { useState, useRef } from 'react'

interface Props {
  errors?: {
    csv_file?: string[]
    arrival_date?: string[]
    base?: string[]
  }
  // Server-supplied via the payouts#new props. The new
  // Settings page lets each user set their own encrypted Stripe
  // API key; the value flows through Current.user.stripe_configured?
  // on the server (with ENV / credentials fallback for dev) so we
  // don't need a window-global.
  stripe_configured?: boolean
}

type Tab = 'csv' | 'stripe'

export default function New({ errors: initialErrors, stripe_configured: stripeConfigured = false }: Props) {
  const [csvPreview, setCsvPreview] = useState<{
    period_name: string
    arrival_date: string
    period_start: string
    period_end: string
    row_count: number
  } | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const [tab, setTab] = useState<Tab>('csv')

  const csvForm = useForm({
    csv_file: null as File | null,
    arrival_date: '',
  })

  const fetchForm = useForm({
    start_date: '',
    end_date: '',
  })

  const baseErrors = initialErrors?.base || []

  const csvErrors = {
    csv_file: csvForm.errors?.csv_file,
    arrival_date: csvForm.errors?.arrival_date,
    base: baseErrors,
  }

  // fetchForm's typed errors don't include `base`; we union with the
  // initial base errors so the panel shows either controller-side
  // errors or form-side errors when both are present.
  const fetchFormErrors = fetchForm.errors as
    { start_date?: string[]; end_date?: string[]; base?: string[] } | undefined
  const fetchErrors = {
    start_date: fetchFormErrors?.start_date,
    end_date: fetchFormErrors?.end_date,
    base: fetchFormErrors?.base || baseErrors,
  }

  const handleCsvFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    csvForm.setData('csv_file', file)

    // Parse CSV on client side to preview period info. The default
    // arrival_date is max(row Created) + 3 days, which is Stripe's
    // typical payout-window buffer — a sensible pre-fill.
    const reader = new FileReader()
    reader.onload = (event) => {
      const text = event.target?.result as string
      parseCsvPreview(text)
    }
    reader.readAsText(file)
  }

  const parseCsvPreview = (csvText: string) => {
    try {
      const lines = csvText.split('\n').filter((line) => line.trim())
      if (lines.length < 2) return

      const dates: Date[] = []
      for (let i = 1; i < lines.length; i++) {
        const columns = lines[i].split(',')
        if (columns.length >= 3) {
          const dateStr = columns[2]?.trim()
          if (dateStr) {
            const dateMatch = dateStr.match(/(\d{4}-\d{2}-\d{2})/)
            if (dateMatch) {
              const date = new Date(dateMatch[1])
              if (!isNaN(date.getTime())) {
                dates.push(date)
              }
            }
          }
        }
      }

      if (dates.length > 0) {
        const minDate = new Date(Math.min(...dates.map((d) => d.getTime())))
        const maxDate = new Date(Math.max(...dates.map((d) => d.getTime())))
        // Stripe's typical payout-window buffer — most payouts land
        // 2-7 days after the last charge in the period.
        const defaultArrival = new Date(maxDate.getTime() + 3 * 24 * 60 * 60 * 1000)
          .toISOString().split('T')[0]

        const periodName = derivePayoutName(defaultArrival)
        setCsvPreview({
          period_name: periodName,
          arrival_date: defaultArrival,
          period_start: minDate.toISOString().split('T')[0],
          period_end: maxDate.toISOString().split('T')[0],
          row_count: lines.length - 1,
        })

        // Only pre-fill the form once per file selection — never
        // overwrite a value the user has already adjusted.
        if (!csvForm.data.arrival_date) {
          csvForm.setData('arrival_date', defaultArrival)
        }
      }
    } catch (error) {
      console.error('Error parsing CSV preview:', error)
    }
  }

  // Mirror of `PayoutName.from(date)` on the Ruby side — kept
  // in-sync manually because we don't have shared code between TS
  // and Ruby. Returns "JUN 1 - 2026" / "Unknown Period" for nil.
  const derivePayoutName = (arrivalDate: string): string => {
    if (!arrivalDate) return 'Will be derived from Payout Date'
    const date = new Date(arrivalDate)
    if (isNaN(date.getTime())) return 'Unknown Period'
    const month = date.toLocaleDateString('en-US', { month: 'short' }).toUpperCase()
    const day = date.getDate()
    const year = date.getFullYear()
    return `${month} ${day} - ${year}`
  }

  const handleCsvSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    csvForm.post('/payouts', { forceFormData: true })
  }

  const handleFetchSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    fetchForm.post('/payouts/fetch', { forceFormData: true })
  }

  return (
    <>
      <Head title="Import Payout" />

      <div className="container mx-auto px-4 py-8">
        <div className="mb-6">
          <Link href="/payouts" className="btn btn-ghost btn-sm mb-4">
            ← Back to Payouts
          </Link>
          <h1 className="text-3xl font-bold">Import Payout</h1>
          <p className="text-gray-600 mt-2">
            Upload a Stripe payout CSV, or fetch directly from the Stripe API.
          </p>
        </div>

        {!stripeConfigured && (
          <div className="alert alert-warning mb-4 max-w-2xl">
            <span>
              Stripe API credentials aren't configured for your account — the
              &quot;Fetch from Stripe&quot; tab is disabled.{' '}
              <Link href="/settings" className="link link-info">
                Set your Stripe API key in Settings
              </Link>{' '}
              to enable it.
            </span>
          </div>
        )}

        <div role="tablist" className="tabs tabs-bordered mb-6 max-w-2xl">
          <button
            type="button"
            role="tab"
            className={`tab ${tab === 'csv' ? 'tab-active' : ''}`}
            onClick={() => setTab('csv')}
          >
            Upload CSV
          </button>
          <button
            type="button"
            role="tab"
            className={`tab ${tab === 'stripe' ? 'tab-active' : ''}`}
            onClick={() => setTab('stripe')}
            disabled={!stripeConfigured}
          >
            Fetch from Stripe
          </button>
        </div>

        {/* CSV tab */}
        {tab === 'csv' && (
          <div className="card bg-base-100 shadow-xl max-w-2xl">
            <div className="card-body">
              {csvErrors.base && csvErrors.base.length > 0 && (
                <div className="alert alert-error mb-4">
                  <ul className="list-disc list-inside">
                    {csvErrors.base.map((error: string, index: number) => (
                      <li key={index}>{error}</li>
                    ))}
                  </ul>
                </div>
              )}

              <form onSubmit={handleCsvSubmit}>
                <div className="form-control mb-4">
                  <label className="label">
                    <span className="label-text">CSV File</span>
                  </label>
                  <input
                    ref={fileInputRef}
                    type="file"
                    accept=".csv"
                    onChange={handleCsvFileChange}
                    className="file-input file-input-bordered w-full"
                    required
                  />
                  {csvErrors.csv_file && (
                    <label className="label">
                      <span className="label-text-alt text-error">
                        {csvErrors.csv_file[0]}
                      </span>
                    </label>
                  )}
                </div>

                {csvPreview && (
                  <div className="alert alert-info mb-4">
                    <div>
                      <h3 className="font-bold">CSV Preview</h3>
                      <p className="text-sm">
                        <strong>Rows:</strong> {csvPreview.row_count}
                        <br />
                        <strong>Activity:</strong> {csvPreview.period_start} to{' '}
                        {csvPreview.period_end}
                      </p>
                    </div>
                  </div>
                )}

                <div className="form-control mb-4">
                  <label className="label">
                    <span className="label-text">Payout Name</span>
                  </label>
                  <input
                    type="text"
                    value={csvForm.data.arrival_date ? derivePayoutName(csvForm.data.arrival_date) : ''}
                    readOnly
                    placeholder="Will be derived from Payout Date below"
                    className="input input-bordered w-full bg-base-200 cursor-not-allowed"
                  />
                  <label className="label">
                    <span className="label-text-alt">
                      Derived from the Payout Date (Stripe&apos;s arrival date).
                      Rename later from the payout page.
                    </span>
                  </label>
                </div>

                <div className="form-control mb-4">
                  <label className="label">
                    <span className="label-text">Payout Date</span>
                  </label>
                  <input
                    type="date"
                    value={csvForm.data.arrival_date}
                    onChange={(e) => csvForm.setData('arrival_date', e.target.value)}
                    className="input input-bordered w-full"
                    required
                  />
                  {csvErrors.arrival_date && (
                    <label className="label">
                      <span className="label-text-alt text-error">
                        {csvErrors.arrival_date[0]}
                      </span>
                    </label>
                  )}
                  <label className="label">
                    <span className="label-text-alt">
                      Defaults to max(row date) + 3 days when you select a CSV.
                      Set this to the date Stripe actually paid out.
                    </span>
                  </label>
                </div>

                <div className="card-actions justify-end">
                  <Link href="/payouts" className="btn btn-ghost">
                    Cancel
                  </Link>
                  <button
                    type="submit"
                    className="btn btn-primary"
                    disabled={csvForm.processing || !csvForm.data.csv_file}
                  >
                    {csvForm.processing ? 'Uploading...' : 'Upload CSV'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Fetch from Stripe tab */}
        {tab === 'stripe' && (
          <div className="card bg-base-100 shadow-xl max-w-2xl">
            <div className="card-body">
              {fetchErrors.base && fetchErrors.base.length > 0 && (
                <div className="alert alert-error mb-4">
                  <ul className="list-disc list-inside">
                    {fetchErrors.base.map((error: string, index: number) => (
                      <li key={index}>{error}</li>
                    ))}
                  </ul>
                </div>
              )}

              <form onSubmit={handleFetchSubmit}>
                <div className="form-control mb-4">
                  <label className="label">
                    <span className="label-text">Start date</span>
                  </label>
                  <input
                    type="date"
                    value={fetchForm.data.start_date}
                    onChange={(e) => fetchForm.setData('start_date', e.target.value)}
                    className="input input-bordered w-full"
                    required
                  />
                  <label className="label">
                    <span className="label-text-alt">
                      Earliest payout arrival_date to look for.
                    </span>
                  </label>
                </div>

                <div className="form-control mb-4">
                  <label className="label">
                    <span className="label-text">End date</span>
                  </label>
                  <input
                    type="date"
                    value={fetchForm.data.end_date}
                    onChange={(e) => fetchForm.setData('end_date', e.target.value)}
                    className="input input-bordered w-full"
                    required
                  />
                  <label className="label">
                    <span className="label-text-alt">
                      Latest payout arrival_date to look for (inclusive).
                    </span>
                  </label>
                </div>

                <div className="card-actions justify-end">
                  <Link href="/payouts" className="btn btn-ghost">
                    Cancel
                  </Link>
                  <button
                    type="submit"
                    className="btn btn-primary"
                    disabled={fetchForm.processing || !fetchForm.data.start_date || !fetchForm.data.end_date}
                  >
                    {fetchForm.processing ? 'Fetching...' : 'Fetch from Stripe'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}
      </div>
    </>
  )
}