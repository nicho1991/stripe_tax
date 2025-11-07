import { Head, Link } from '@inertiajs/react'

interface Payout {
  id: number
  name: string
  period_start: string
  period_end: string
  total_amount: number
  total_fees: number
  total_net: number
  primary_currency: string
  payments_count: number
  created_at: string
}

interface Props {
  recent_payouts: Payout[]
  total_payouts: number
}

export default function Index({ recent_payouts, total_payouts }: Props) {
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

  return (
    <>
      <Head title="Dashboard" />

      <div className="container mx-auto px-4 py-8">
        <div className="hero bg-base-200 rounded-lg p-8 mb-8">
          <div className="hero-content text-center">
            <div className="max-w-md">
              <h1 className="text-4xl font-bold">Welcome to Dashboard</h1>
              <p className="py-4">
                You're successfully signed in. Start managing your Stripe tax data.
              </p>
            </div>
          </div>
        </div>

        {/* Upload Section */}
        <div className="mb-8">
          <h2 className="text-2xl font-bold mb-4">Upload Data</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="card bg-base-100 shadow-xl">
              <div className="card-body">
                <h3 className="card-title">Upload Payout CSV</h3>
                <p>Upload your Stripe payout CSV file to get started.</p>
                <div className="card-actions justify-end">
                  <Link href="/payouts/new" className="btn btn-primary">
                    Upload
                  </Link>
                </div>
              </div>
            </div>

            <div className="card bg-base-100 shadow-xl">
              <div className="card-body">
                <h3 className="card-title">Upload Transactions CSV</h3>
                <p>Upload detailed Stripe transaction data for EU classification.</p>
                <div className="card-actions justify-end">
                  <Link href="/transactions/new" className="btn btn-primary">
                    Upload
                  </Link>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* View Section */}
        <div className="mb-8">
          <h2 className="text-2xl font-bold mb-4">View Data</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="card bg-base-100 shadow-xl">
              <div className="card-body">
                <h3 className="card-title">View Payouts</h3>
                <p>View and manage all your payout periods.</p>
                <div className="card-actions justify-end">
                  <Link href="/payouts" className="btn btn-primary">
                    View Payouts
                  </Link>
                </div>
              </div>
            </div>

            <div className="card bg-base-100 shadow-xl">
              <div className="card-body">
                <h3 className="card-title">View Transactions</h3>
                <p>View and manage all your transactions with EU classification.</p>
                <div className="card-actions justify-end">
                  <Link href="/transactions" className="btn btn-primary">
                    View Transactions
                  </Link>
                </div>
              </div>
            </div>

            <div className="card bg-base-100 shadow-xl">
              <div className="card-body">
                <h3 className="card-title">View Customers</h3>
                <p>View customer profiles and their transaction history.</p>
                <div className="card-actions justify-end">
                  <Link href="/customers" className="btn btn-primary">
                    View Customers
                  </Link>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Statistics */}
        <div className="mb-8">
          <div className="card bg-base-100 shadow-xl">
            <div className="card-body">
              <h2 className="card-title">Statistics</h2>
              <p className="text-2xl font-bold">{total_payouts}</p>
              <p className="text-sm text-gray-600">Total Payouts</p>
            </div>
          </div>
        </div>

        {recent_payouts.length > 0 && (
          <div className="card bg-base-100 shadow-xl">
            <div className="card-body">
              <div className="flex justify-between items-center mb-4">
                <h2 className="card-title">Recent Payouts</h2>
                <Link href="/payouts" className="btn btn-ghost btn-sm">
                  View All
                </Link>
              </div>
              <div className="overflow-x-auto">
                <table className="table table-zebra">
                  <thead>
                    <tr>
                      <th>Name</th>
                      <th>Period</th>
                      <th>Payments</th>
                      <th>Total Net</th>
                      <th>Created</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {recent_payouts.map((payout) => (
                      <tr key={payout.id}>
                        <td className="font-semibold">{payout.name}</td>
                        <td>
                          {formatDate(payout.period_start)} -{' '}
                          {formatDate(payout.period_end)}
                        </td>
                        <td>{payout.payments_count}</td>
                        <td className="font-semibold">
                          {formatCurrency(payout.total_net, payout.primary_currency)}
                        </td>
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
            </div>
          </div>
        )}

        {recent_payouts.length === 0 && (
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
        )}
      </div>
    </>
  )
}

