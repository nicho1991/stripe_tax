import { Head, Link, router } from '@inertiajs/react'
import { useState } from 'react'

interface Transaction {
  id: number
  transaction_id: string
  created_at_stripe: string
  status: string | null
  decline_reason: string | null
  location_confidence_score: number
  eu_classification: 'undetermined' | 'eu' | 'non_eu'
  has_payment: boolean
  payment_id: number | null
  payout_id: number | null
  customer_id: string | null
  customer_link: string | null
  amount: number | null
  fees: number | null
  currency: string | null
}

interface Props {
  transactions: Transaction[]
  filters: {
    eu_classification?: string
  }
}

export default function Index({ transactions, filters }: Props) {
  const [euFilter, setEuFilter] = useState<string>(filters.eu_classification || '')

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  }

  const formatCurrency = (amount: number | null, currency: string | null = 'USD') => {
    if (amount === null) return '-'
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: currency || 'USD',
      minimumFractionDigits: 2,
    }).format(amount)
  }

  const getEuClassificationBadge = (classification: string) => {
    const badges = {
      eu: <span className="badge badge-success">EU</span>,
      non_eu: <span className="badge badge-error">Non-EU</span>,
      undetermined: <span className="badge badge-warning">Undetermined</span>,
    }
    return badges[classification as keyof typeof badges] || badges.undetermined
  }

  const handleFilterChange = (value: string) => {
    setEuFilter(value)
    const params: any = {}
    if (value) {
      params.eu_classification = value
    }
    router.get('/transactions', params, { preserveState: true })
  }

  return (
    <>
      <Head title="Transactions" />

      <div className="container mx-auto px-4 py-8">
        <div className="flex justify-between items-center mb-6">
          <h1 className="text-3xl font-bold">Transactions</h1>
          <Link href="/transactions/new" className="btn btn-primary">
            Upload Transactions CSV
          </Link>
        </div>

        <div className="mb-4 flex gap-4 items-center">
          <label className="label">
            <span className="label-text">Filter by EU Classification:</span>
          </label>
          <select
            className="select select-bordered"
            value={euFilter}
            onChange={(e) => handleFilterChange(e.target.value)}
          >
            <option value="">All</option>
            <option value="0">Undetermined</option>
            <option value="1">EU</option>
            <option value="2">Non-EU</option>
          </select>
        </div>

        {transactions.length === 0 ? (
          <div className="card bg-base-100 shadow-xl">
            <div className="card-body text-center">
              <h2 className="card-title justify-center">No transactions yet</h2>
              <p>Upload your first transactions CSV to get started.</p>
              <div className="card-actions justify-center">
                <Link href="/transactions/new" className="btn btn-primary">
                  Upload Transactions CSV
                </Link>
              </div>
            </div>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="table table-zebra">
              <thead>
                <tr>
                  <th>Transaction ID</th>
                  <th>Date</th>
                  <th>EU Classification</th>
                  <th>Confidence</th>
                  <th>Amount</th>
                  <th>Fees</th>
                  <th>Customer</th>
                  <th>Has Payment</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {transactions.map((transaction) => (
                  <tr key={transaction.id}>
                    <td className="font-mono text-sm">{transaction.transaction_id}</td>
                    <td>{formatDate(transaction.created_at_stripe)}</td>
                    <td>{getEuClassificationBadge(transaction.eu_classification)}</td>
                    <td>
                      <span className="badge badge-outline">
                        {transaction.location_confidence_score}/3
                      </span>
                    </td>
                    <td>{formatCurrency(transaction.amount, transaction.currency)}</td>
                    <td>{formatCurrency(transaction.fees, transaction.currency)}</td>
                    <td>
                      {transaction.customer_link ? (
                        <Link
                          href={transaction.customer_link}
                          className="badge badge-info"
                        >
                          View Customer
                        </Link>
                      ) : (
                        <span className="badge badge-ghost">-</span>
                      )}
                    </td>
                    <td>
                      {transaction.has_payment && transaction.payout_id ? (
                        <Link
                          href={`/payouts/${transaction.payout_id}`}
                          className="badge badge-info"
                        >
                          Yes
                        </Link>
                      ) : (
                        <span className="badge badge-ghost">No</span>
                      )}
                    </td>
                    <td>
                      <Link
                        href={`/transactions/${transaction.id}`}
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
      </div>
    </>
  )
}

