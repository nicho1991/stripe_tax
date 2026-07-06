import { Head, Link, router } from '@inertiajs/react'

interface Payout {
  id: number
  name: string
  period_start: string
  period_end: string
  arrival_date: string | null
  total_amount: number
  total_fees: number
  total_net: number
  primary_currency: string
  payments_count: number
  created_at: string
}

interface Pagination {
  current_page: number
  total_pages: number
  total_count: number
  per_page: number
}

interface Props {
  payouts: Payout[]
  pagination: Pagination
}

export default function Index({ payouts, pagination }: Props) {
  const formatCurrency = (amount: number, currency: string = 'USD') => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: currency,
      minimumFractionDigits: 2,
    }).format(amount)
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    })
  }

  const handlePageChange = (page: number) => {
    router.get('/payouts', { page }, { preserveState: true })
  }

  return (
    <>
      <Head title="Payouts" />

      <div className="container mx-auto px-4 py-8">
        <div className="flex justify-between items-center mb-6">
          <h1 className="text-3xl font-bold">Payouts</h1>
          <Link href="/payouts/new" className="btn btn-primary">
            Import Payout
          </Link>
        </div>

        {payouts.length === 0 ? (
          <div className="card bg-base-100 shadow-xl">
            <div className="card-body text-center">
              <h2 className="card-title justify-center">No payouts yet</h2>
              <p>Upload your first payout CSV to get started.</p>
              <div className="card-actions justify-center">
                <Link href="/payouts/new" className="btn btn-primary">
                  Upload Payout CSV
                </Link>
              </div>
            </div>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="table table-zebra">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Period</th>
                  <th>Payments</th>
                  <th>Total Amount</th>
                  <th>Total Fees</th>
                  <th>Total Net</th>
                  <th>Created</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {payouts.map((payout) => (
                  <tr key={payout.id}>
                    <td className="font-semibold">{payout.name}</td>
                    <td>
                      {formatDate(payout.period_start)} - {formatDate(payout.period_end)}
                    </td>
                    <td>{payout.payments_count}</td>
                    <td>{formatCurrency(payout.total_amount, payout.primary_currency)}</td>
                    <td>{formatCurrency(payout.total_fees, payout.primary_currency)}</td>
                    <td className="font-semibold">{formatCurrency(payout.total_net, payout.primary_currency)}</td>
                    <td>{formatDate(payout.created_at)}</td>
                    <td>
                      <Link
                        href={`/payouts/${payout.id}`}
                        className="btn btn-sm btn-outline"
                      >
                        View
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Pagination */}
        {pagination.total_pages > 1 && (
          <div className="flex justify-center items-center gap-2 mt-6">
            <button
              onClick={() => handlePageChange(pagination.current_page - 1)}
              disabled={pagination.current_page === 1}
              className="btn btn-sm"
            >
              Previous
            </button>
            <span className="text-sm">
              Page {pagination.current_page} of {pagination.total_pages} ({pagination.total_count} total)
            </span>
            <button
              onClick={() => handlePageChange(pagination.current_page + 1)}
              disabled={pagination.current_page >= pagination.total_pages}
              className="btn btn-sm"
            >
              Next
            </button>
          </div>
        )}
      </div>
    </>
  )
}

