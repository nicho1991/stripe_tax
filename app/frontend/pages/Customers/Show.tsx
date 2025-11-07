import { Head, Link } from '@inertiajs/react'

interface Customer {
  customer_id: string
  customer_name: string | null
  customer_email: string | null
}

interface Transaction {
  id: number
  transaction_id: string
  created_at_stripe: string
  status: string | null
  decline_reason: string | null
  card_address_country: string | null
  card_issue_country: string | null
  shipping_address_country: string | null
  location_confidence_score: number
  enhanced_location_confidence_score: number
  inferred_fields: string[]
  inferred_data: {
    card_address_country?: string
    card_issue_country?: string
    shipping_address_country?: string
  }
  eu_classification: 'undetermined' | 'eu' | 'non_eu'
  customer_influenced_eu_classification: 'undetermined' | 'eu' | 'non_eu'
  has_payment: boolean
  payment_id: number | null
}

interface Summary {
  transaction_count: number
  total_amount: number
  eu_count: number
  non_eu_count: number
  undetermined_count: number
}

interface Props {
  customer: Customer
  transactions: Transaction[]
  summary: Summary
}

export default function Show({ customer, transactions, summary }: Props) {
  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  }

  const formatCurrency = (amount: number, currency: string = 'USD') => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: currency,
      minimumFractionDigits: 2,
    }).format(amount)
  }

  const getEuClassificationBadge = (classification: string) => {
    const badges = {
      eu: <span className="badge badge-success badge-sm">EU</span>,
      non_eu: <span className="badge badge-error badge-sm">Non-EU</span>,
      undetermined: <span className="badge badge-warning badge-sm">Undetermined</span>,
    }
    return badges[classification as keyof typeof badges] || badges.undetermined
  }

  const getLocationFieldDisplay = (
    field: 'card_address_country' | 'card_issue_country' | 'shipping_address_country',
    transaction: Transaction
  ) => {
    const originalValue = transaction[field]
    const inferredValue = transaction.inferred_data[field]
    const isInferred = transaction.inferred_fields.includes(field)

    if (originalValue) {
      return <span>{originalValue}</span>
    } else if (inferredValue) {
      return (
        <span className="text-info" title="Inferred from other customer transactions">
          {inferredValue} <span className="text-xs">(inferred)</span>
        </span>
      )
    } else {
      return <span className="text-gray-400">-</span>
    }
  }

  return (
    <>
      <Head title={`Customer ${customer.customer_name || customer.customer_id}`} />

      <div className="container mx-auto px-4 py-8">
        <div className="mb-6">
          <Link href="/customers" className="btn btn-ghost btn-sm mb-4">
            ← Back to Customers
          </Link>
          <h1 className="text-3xl font-bold">Customer Profile</h1>
        </div>

        {/* Customer Information */}
        <div className="card bg-base-100 shadow-xl mb-6">
          <div className="card-body">
            <h2 className="card-title">Customer Information</h2>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label className="label">
                  <span className="label-text font-semibold">Customer ID</span>
                </label>
                <p className="font-mono text-sm">{customer.customer_id}</p>
              </div>
              <div>
                <label className="label">
                  <span className="label-text font-semibold">Name</span>
                </label>
                <p>{customer.customer_name || <span className="text-gray-400">Not available</span>}</p>
              </div>
              <div>
                <label className="label">
                  <span className="label-text font-semibold">Email</span>
                </label>
                <p>{customer.customer_email || <span className="text-gray-400">Not available</span>}</p>
              </div>
            </div>
          </div>
        </div>

        {/* Summary Stats */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
          <div className="stat bg-base-200 rounded-lg">
            <div className="stat-title">Total Transactions</div>
            <div className="stat-value text-2xl">{summary.transaction_count}</div>
          </div>
          <div className="stat bg-base-200 rounded-lg">
            <div className="stat-title">Total Amount</div>
            <div className="stat-value text-2xl">{formatCurrency(summary.total_amount)}</div>
          </div>
          <div className="stat bg-base-200 rounded-lg">
            <div className="stat-title">EU Transactions</div>
            <div className="stat-value text-2xl text-success">{summary.eu_count}</div>
          </div>
          <div className="stat bg-base-200 rounded-lg">
            <div className="stat-title">Non-EU Transactions</div>
            <div className="stat-value text-2xl text-error">{summary.non_eu_count}</div>
          </div>
        </div>

        {/* Transactions Table */}
        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h2 className="card-title mb-4">Transactions</h2>
            {transactions.length === 0 ? (
              <p className="text-gray-400">No transactions found for this customer.</p>
            ) : (
              <div className="overflow-x-auto">
                <table className="table table-zebra">
                  <thead>
                    <tr>
                      <th>Transaction ID</th>
                      <th>Date</th>
                      <th>Status</th>
                      <th>Location Confidence</th>
                      <th>Enhanced Confidence</th>
                      <th>Card Country</th>
                      <th>Card Issue</th>
                      <th>Shipping Country</th>
                      <th>EU Classification</th>
                      <th>Customer-Influenced EU</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {transactions.map((transaction) => {
                      const hasEnhancement = transaction.enhanced_location_confidence_score > transaction.location_confidence_score
                      const euDiffers = transaction.customer_influenced_eu_classification !== transaction.eu_classification

                      return (
                        <tr key={transaction.id}>
                          <td className="font-mono text-sm">{transaction.transaction_id}</td>
                          <td>{formatDate(transaction.created_at_stripe)}</td>
                          <td>
                            <span className={`badge ${transaction.status === 'Paid' ? 'badge-success' : 'badge-error'}`}>
                              {transaction.status || 'Unknown'}
                            </span>
                          </td>
                          <td>
                            <span className="badge badge-outline">
                              {transaction.location_confidence_score}/3
                            </span>
                          </td>
                          <td>
                            {hasEnhancement ? (
                              <span className="badge badge-info" title="Enhanced using other customer transactions">
                                {transaction.enhanced_location_confidence_score}/3
                                <span className="text-xs ml-1">↑</span>
                              </span>
                            ) : (
                              <span className="badge badge-outline">
                                {transaction.enhanced_location_confidence_score}/3
                              </span>
                            )}
                          </td>
                          <td>{getLocationFieldDisplay('card_address_country', transaction)}</td>
                          <td>{getLocationFieldDisplay('card_issue_country', transaction)}</td>
                          <td>{getLocationFieldDisplay('shipping_address_country', transaction)}</td>
                          <td>{getEuClassificationBadge(transaction.eu_classification)}</td>
                          <td>
                            {euDiffers ? (
                              <div className="flex items-center gap-1">
                                {getEuClassificationBadge(transaction.customer_influenced_eu_classification)}
                                <span className="text-xs text-info" title="Different from original classification">
                                  *
                                </span>
                              </div>
                            ) : (
                              getEuClassificationBadge(transaction.customer_influenced_eu_classification)
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
                      )
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      </div>
    </>
  )
}

