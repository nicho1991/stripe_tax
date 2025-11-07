import { Head, Link, useForm } from '@inertiajs/react'
import { useRef } from 'react'

interface Props {
  errors?: {
    csv_file?: string[]
    base?: string[]
  }
  warnings?: string[]
}

export default function New({ errors: initialErrors, warnings: initialWarnings }: Props) {
  const fileInputRef = useRef<HTMLInputElement>(null)

  const { data, setData, post, processing, errors } = useForm({
    csv_file: null as File | null,
  })

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    setData('csv_file', file)
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    post('/transactions', {
      forceFormData: true,
    })
  }

  const allErrors = initialErrors || errors
  const allWarnings = initialWarnings || []

  return (
    <>
      <Head title="Upload Transactions CSV" />

      <div className="container mx-auto px-4 py-8">
        <div className="mb-6">
          <Link href="/transactions" className="btn btn-ghost btn-sm mb-4">
            ← Back to Transactions
          </Link>
          <h1 className="text-3xl font-bold">Upload Transactions CSV</h1>
        </div>

        <div className="card bg-base-100 shadow-xl max-w-2xl">
          <div className="card-body">
            {allErrors?.base && (
              <div className="alert alert-error mb-4">
                <ul className="list-disc list-inside">
                  {allErrors.base.map((error, index) => (
                    <li key={index}>{error}</li>
                  ))}
                </ul>
              </div>
            )}

            {allWarnings.length > 0 && (
              <div className="alert alert-warning mb-4">
                <div>
                  <h3 className="font-bold">Warnings</h3>
                  <ul className="list-disc list-inside mt-2">
                    {allWarnings.map((warning, index) => (
                      <li key={index} className="text-sm">{warning}</li>
                    ))}
                  </ul>
                </div>
              </div>
            )}

            <form onSubmit={handleSubmit}>
              <div className="form-control mb-4">
                <label className="label">
                  <span className="label-text">CSV File</span>
                </label>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept=".csv"
                  onChange={handleFileChange}
                  className="file-input file-input-bordered w-full"
                  required
                />
                {allErrors?.csv_file && (
                  <label className="label">
                    <span className="label-text-alt text-error">
                      {allErrors.csv_file[0]}
                    </span>
                  </label>
                )}
                <label className="label">
                  <span className="label-text-alt">
                    Upload Stripe unified_payments CSV file. Duplicate transactions will be skipped or warned if they differ.
                  </span>
                </label>
              </div>

              <div className="card-actions justify-end">
                <Link href="/transactions" className="btn btn-ghost">
                  Cancel
                </Link>
                <button
                  type="submit"
                  className="btn btn-primary"
                  disabled={processing || !data.csv_file}
                >
                  {processing ? 'Uploading...' : 'Upload CSV'}
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </>
  )
}

