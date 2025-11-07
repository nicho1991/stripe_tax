import { Head, Link, useForm } from '@inertiajs/react'
import { useState, useRef } from 'react'

interface Props {
  errors?: {
    csv_file?: string[]
    period_name?: string[]
    base?: string[]
  }
}

export default function New({ errors: initialErrors }: Props) {
  const [csvPreview, setCsvPreview] = useState<{
    period_name: string
    period_start: string
    period_end: string
    row_count: number
  } | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const { data, setData, post, processing, errors } = useForm({
    csv_file: null as File | null,
    period_name: '',
  })

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    setData('csv_file', file)

    // Parse CSV on client side to preview period info
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

      // Skip header, parse dates from rows
      const dates: Date[] = []
      for (let i = 1; i < lines.length; i++) {
        const columns = lines[i].split(',')
        if (columns.length >= 3) {
          const dateStr = columns[2]?.trim()
          if (dateStr) {
            // Parse format: "2025-10-08 17:36"
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

        // Generate period name
        let periodName = ''
        if (
          minDate.getFullYear() === maxDate.getFullYear() &&
          minDate.getMonth() === maxDate.getMonth()
        ) {
          periodName = minDate.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })
        } else if (minDate.getFullYear() === maxDate.getFullYear()) {
          periodName = `${minDate.toLocaleDateString('en-US', {
            month: 'long',
          })} - ${maxDate.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}`
        } else {
          periodName = `${minDate.toLocaleDateString('en-US', {
            month: 'long',
            year: 'numeric',
          })} - ${maxDate.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}`
        }

        setCsvPreview({
          period_name: periodName,
          period_start: minDate.toISOString().split('T')[0],
          period_end: maxDate.toISOString().split('T')[0],
          row_count: lines.length - 1,
        })

        // Pre-fill period name if not already set
        if (!data.period_name) {
          setData('period_name', periodName)
        }
      }
    } catch (error) {
      console.error('Error parsing CSV preview:', error)
    }
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    post('/payouts', {
      forceFormData: true,
    })
  }

  const allErrors = initialErrors || errors

  return (
    <>
      <Head title="Upload Payout CSV" />

      <div className="container mx-auto px-4 py-8">
        <div className="mb-6">
          <Link href="/payouts" className="btn btn-ghost btn-sm mb-4">
            ← Back to Payouts
          </Link>
          <h1 className="text-3xl font-bold">Upload Payout CSV</h1>
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
              </div>

              {csvPreview && (
                <div className="alert alert-info mb-4">
                  <div>
                    <h3 className="font-bold">CSV Preview</h3>
                    <p className="text-sm">
                      <strong>Rows:</strong> {csvPreview.row_count}
                      <br />
                      <strong>Period:</strong> {csvPreview.period_start} to{' '}
                      {csvPreview.period_end}
                    </p>
                  </div>
                </div>
              )}

              <div className="form-control mb-4">
                <label className="label">
                  <span className="label-text">Period Name</span>
                </label>
                <input
                  type="text"
                  value={data.period_name}
                  onChange={(e) => setData('period_name', e.target.value)}
                  className="input input-bordered w-full"
                  placeholder="e.g., October 2025"
                  required
                />
                {allErrors?.period_name && (
                  <label className="label">
                    <span className="label-text-alt text-error">
                      {allErrors.period_name[0]}
                    </span>
                  </label>
                )}
                {csvPreview && (
                  <label className="label">
                    <span className="label-text-alt">
                      Default: {csvPreview.period_name}
                    </span>
                  </label>
                )}
              </div>

              {csvPreview && (
                <div className="mb-4 p-4 bg-base-200 rounded-lg">
                  <h4 className="font-semibold mb-2">Period Details (Read-only)</h4>
                  <div className="grid grid-cols-2 gap-4 text-sm">
                    <div>
                      <strong>Start:</strong> {csvPreview.period_start}
                    </div>
                    <div>
                      <strong>End:</strong> {csvPreview.period_end}
                    </div>
                  </div>
                </div>
              )}

              <div className="card-actions justify-end">
                <Link href="/payouts" className="btn btn-ghost">
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

