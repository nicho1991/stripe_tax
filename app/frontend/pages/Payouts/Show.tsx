import { Head, Link } from '@inertiajs/react'
import { useState } from 'react'

interface Payment {
  id: number
  type: string
  stripe_id: string
  created_at_stripe: string
  description: string | null
  amount: number
  currency: string | null
  converted_amount: number
  fees: number
  net: number
  converted_currency: string | null
  details: string | null
  customer_id: string | null
  customer_email: string | null
  customer_name: string | null
}

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
  payout: Payout
  payments: Payment[]
}

export default function Show({ payout, payments }: Props) {
  const [filterType, setFilterType] = useState<string>('all')
  const [sortBy, setSortBy] = useState<'date' | 'amount' | 'net'>('date')
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc')

  const formatCurrency = (amount: number, currency: string | null = 'USD') => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: currency || 'USD',
      minimumFractionDigits: 2,
    }).format(amount)
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  }

  const filteredPayments = payments.filter((payment) => {
    if (filterType === 'all') return true
    return payment.type === filterType
  })

  const sortedPayments = [...filteredPayments].sort((a, b) => {
    let comparison = 0
    switch (sortBy) {
      case 'date':
        comparison =
          new Date(a.created_at_stripe).getTime() -
          new Date(b.created_at_stripe).getTime()
        break
      case 'amount':
        comparison = a.amount - b.amount
        break
      case 'net':
        comparison = a.net - b.net
        break
    }
    return sortOrder === 'asc' ? comparison : -comparison
  })

  const uniqueTypes = Array.from(new Set(payments.map((p) => p.type)))

  return (
    <>
      <Head title={`Payout: ${payout.name}`} />

      <div className="container mx-auto px-4 py-8">
        <div className="mb-6">
          <Link href="/payouts" className="btn btn-ghost btn-sm mb-4">
            ← Back to Payouts
          </Link>
          <h1 className="text-3xl font-bold">{payout.name}</h1>
          <p className="text-gray-600 mt-2">
            Period: {new Date(payout.period_start).toLocaleDateString()} -{' '}
            {new Date(payout.period_end).toLocaleDateString()}
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
          <div className="stat bg-base-200 rounded-lg shadow">
            <div className="stat-title">Total Amount ({payout.primary_currency})</div>
            <div className="stat-value text-2xl">
              {formatCurrency(payout.total_amount, payout.primary_currency)}
            </div>
          </div>
          <div className="stat bg-base-200 rounded-lg shadow">
            <div className="stat-title">Total Fees ({payout.primary_currency})</div>
            <div className="stat-value text-2xl text-warning">
              {formatCurrency(payout.total_fees, payout.primary_currency)}
            </div>
          </div>
          <div className="stat bg-base-200 rounded-lg shadow">
            <div className="stat-title">Total Net ({payout.primary_currency})</div>
            <div className="stat-value text-2xl text-success">
              {formatCurrency(payout.total_net, payout.primary_currency)}
            </div>
          </div>
        </div>

        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <div className="flex flex-wrap gap-4 mb-4 items-center">
              <div className="form-control">
                <label className="label">
                  <span className="label-text">Filter by Type</span>
                </label>
                <select
                  className="select select-bordered"
                  value={filterType}
                  onChange={(e) => setFilterType(e.target.value)}
                >
                  <option value="all">All Types</option>
                  {uniqueTypes.map((type) => (
                    <option key={type} value={type}>
                      {type}
                    </option>
                  ))}
                </select>
              </div>

              <div className="form-control">
                <label className="label">
                  <span className="label-text">Sort By</span>
                </label>
                <select
                  className="select select-bordered"
                  value={sortBy}
                  onChange={(e) => setSortBy(e.target.value as 'date' | 'amount' | 'net')}
                >
                  <option value="date">Date</option>
                  <option value="amount">Amount</option>
                  <option value="net">Net</option>
                </select>
              </div>

              <div className="form-control">
                <label className="label">
                  <span className="label-text">Order</span>
                </label>
                <select
                  className="select select-bordered"
                  value={sortOrder}
                  onChange={(e) => setSortOrder(e.target.value as 'asc' | 'desc')}
                >
                  <option value="desc">Descending</option>
                  <option value="asc">Ascending</option>
                </select>
              </div>

              <div className="ml-auto">
                <span className="text-sm text-gray-600">
                  Showing {sortedPayments.length} of {payments.length} payments
                </span>
              </div>
            </div>

            <div className="overflow-x-auto">
              <table className="table table-zebra">
                <thead>
                  <tr>
                    <th>Type</th>
                    <th>Date</th>
                    <th>Stripe ID</th>
                    <th>Customer</th>
                    <th>Amount</th>
                    <th>Fees</th>
                    <th>Net</th>
                    <th>Currency</th>
                  </tr>
                </thead>
                <tbody>
                  {sortedPayments.map((payment) => (
                    <tr key={payment.id}>
                      <td>
                        <span
                          className={`badge ${
                            payment.type === 'Charge' ? 'badge-success' : 'badge-warning'
                          }`}
                        >
                          {payment.type}
                        </span>
                      </td>
                      <td>{formatDate(payment.created_at_stripe)}</td>
                      <td>
                        <code className="text-xs">{payment.stripe_id}</code>
                      </td>
                      <td>
                        {payment.customer_name || payment.customer_email || 'N/A'}
                      </td>
                      <td>{formatCurrency(payment.amount, payment.currency)}</td>
                      <td>{formatCurrency(payment.fees, payment.converted_currency)}</td>
                      <td className="font-semibold">
                        {formatCurrency(payment.net, payment.converted_currency)}
                      </td>
                      <td>
                        {payment.converted_currency || payment.currency || 'N/A'}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </>
  )
}

