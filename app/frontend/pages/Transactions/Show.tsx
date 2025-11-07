import { Head, Link } from '@inertiajs/react'

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
  eu_classification: 'undetermined' | 'eu' | 'non_eu'
  has_payment: boolean
  payment_id: number | null
  customer_id: string | null
  customer_link: string | null
  raw_data: any
}

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
  customer_link: string | null
  eu_classification: 'undetermined' | 'eu' | 'non_eu'
  payout_id: number
}

interface Props {
  transaction: Transaction
  payment: Payment | null
}

export default function Show({ transaction, payment }: Props) {
  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  }

  const formatCurrency = (amount: number, currency: string | null = 'USD') => {
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

  return (
    <>
      <Head title={`Transaction ${transaction.transaction_id}`} />

      <div className="container mx-auto px-4 py-8">
        <div className="mb-6">
          <Link href="/transactions" className="btn btn-ghost btn-sm mb-4">
            ← Back to Transactions
          </Link>
          <h1 className="text-3xl font-bold">Transaction Details</h1>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Transaction Details */}
          <div className="card bg-base-100 shadow-xl">
            <div className="card-body">
              <h2 className="card-title">Transaction Information</h2>
              
              <div className="space-y-4">
                <div>
                  <label className="label">
                    <span className="label-text font-semibold">Transaction ID</span>
                  </label>
                  <p className="font-mono text-sm">{transaction.transaction_id}</p>
                </div>

                <div>
                  <label className="label">
                    <span className="label-text font-semibold">Created Date</span>
                  </label>
                  <p>{formatDate(transaction.created_at_stripe)}</p>
                </div>

                <div>
                  <label className="label">
                    <span className="label-text font-semibold">Status</span>
                  </label>
                  <p>
                    <span className={`badge ${transaction.status === 'Paid' ? 'badge-success' : 'badge-error'}`}>
                      {transaction.status || 'Unknown'}
                    </span>
                  </p>
                </div>

                {transaction.decline_reason && (
                  <div>
                    <label className="label">
                      <span className="label-text font-semibold">Decline Reason</span>
                    </label>
                    <p className="text-error">{transaction.decline_reason}</p>
                  </div>
                )}

                <div>
                  <label className="label">
                    <span className="label-text font-semibold">EU Classification</span>
                  </label>
                  <p>{getEuClassificationBadge(transaction.eu_classification)}</p>
                </div>

                <div>
                  <label className="label">
                    <span className="label-text font-semibold">Location Confidence</span>
                  </label>
                  <p>
                    <span className="badge badge-outline">
                      {transaction.location_confidence_score}/3 indicators
                    </span>
                  </p>
                </div>
              </div>
            </div>
          </div>

          {/* Location Indicators */}
          <div className="card bg-base-100 shadow-xl">
            <div className="card-body">
              <h2 className="card-title">Location Indicators</h2>
              
              <div className="space-y-4">
                <div>
                  <label className="label">
                    <span className="label-text font-semibold">Card Address Country</span>
                  </label>
                  <p>{transaction.card_address_country || <span className="text-gray-400">Not available</span>}</p>
                </div>

                <div>
                  <label className="label">
                    <span className="label-text font-semibold">Card Issue Country</span>
                  </label>
                  <p>{transaction.card_issue_country || <span className="text-gray-400">Not available</span>}</p>
                </div>

                <div>
                  <label className="label">
                    <span className="label-text font-semibold">Shipping Address Country</span>
                  </label>
                  <p>{transaction.shipping_address_country || <span className="text-gray-400">Not available</span>}</p>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Linked Payment */}
        {payment ? (
          <div className="card bg-base-100 shadow-xl mt-6">
            <div className="card-body">
              <div className="flex justify-between items-center mb-4">
                <h2 className="card-title">Linked Payment</h2>
                <Link href={`/payouts/${payment.payout_id}`} className="btn btn-sm btn-outline">
                  View Payout
                </Link>
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="label">
                    <span className="label-text font-semibold">Payment Type</span>
                  </label>
                  <p>{payment.type}</p>
                </div>

                <div>
                  <label className="label">
                    <span className="label-text font-semibold">EU Classification</span>
                  </label>
                  <p>{getEuClassificationBadge(payment.eu_classification)}</p>
                </div>

                <div>
                  <label className="label">
                    <span className="label-text font-semibold">Amount</span>
                  </label>
                  <p>{formatCurrency(payment.amount, payment.currency)}</p>
                </div>

                <div>
                  <label className="label">
                    <span className="label-text font-semibold">Converted Amount</span>
                  </label>
                  <p>{formatCurrency(payment.converted_amount, payment.converted_currency)}</p>
                </div>

                <div>
                  <label className="label">
                    <span className="label-text font-semibold">Fees</span>
                  </label>
                  <p>{formatCurrency(payment.fees, payment.converted_currency)}</p>
                </div>

                <div>
                  <label className="label">
                    <span className="label-text font-semibold">Net</span>
                  </label>
                  <p className="font-semibold">{formatCurrency(payment.net, payment.converted_currency)}</p>
                </div>

                {payment.customer_email && (
                  <div>
                    <label className="label">
                      <span className="label-text font-semibold">Customer Email</span>
                    </label>
                    <p>{payment.customer_email}</p>
                  </div>
                )}

                {payment.customer_name && (
                  <div>
                    <label className="label">
                      <span className="label-text font-semibold">Customer Name</span>
                    </label>
                    <p>{payment.customer_name}</p>
                  </div>
                )}

                {payment.customer_link && (
                  <div>
                    <label className="label">
                      <span className="label-text font-semibold">Customer Profile</span>
                    </label>
                    <p>
                      <Link href={payment.customer_link} className="btn btn-sm btn-outline">
                        View Customer Profile
                      </Link>
                    </p>
                  </div>
                )}
              </div>
            </div>
          </div>
        ) : (
          <div className="card bg-base-100 shadow-xl mt-6">
            <div className="card-body">
              <h2 className="card-title">Linked Payment</h2>
              <p className="text-gray-400">No payment linked to this transaction.</p>
            </div>
          </div>
        )}

        {/* Raw Data */}
        {transaction.raw_data && (
          <div className="card bg-base-100 shadow-xl mt-6">
            <div className="card-body">
              <h2 className="card-title">Raw Data</h2>
              <div className="mt-4">
                <pre className="bg-base-200 p-4 rounded-lg overflow-x-auto text-sm">
                  <code>{JSON.stringify(transaction.raw_data, null, 2)}</code>
                </pre>
              </div>
            </div>
          </div>
        )}
      </div>
    </>
  )
}

