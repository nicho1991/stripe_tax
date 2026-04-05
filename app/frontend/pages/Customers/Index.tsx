import { Head, Link, router } from '@inertiajs/react'

interface Customer {
  customer_id: string
  customer_name: string | null
  customer_email: string | null
  transaction_count: number
  total_amount: number
  primary_currency: string
  eu_classification_summary: 'undetermined' | 'eu' | 'non_eu' | 'stripe_fees'
}

interface Pagination {
  current_page: number
  total_pages: number
  total_count: number
  per_page: number
}

interface Props {
  customers: Customer[]
  pagination: Pagination
}

export default function Index({ customers, pagination }: Props) {
  const formatCurrency = (amount: number, currency: string = 'USD') => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: currency,
      minimumFractionDigits: 2,
    }).format(amount)
  }

  const getEuClassificationBadge = (classification: string) => {
    const badges = {
      eu: <span className="badge badge-success">EU</span>,
      non_eu: <span className="badge badge-error">Non-EU</span>,
      undetermined: <span className="badge badge-warning">Undetermined</span>,
      stripe_fees: <span className="badge badge-info">Stripe Fees</span>,
    }
    return badges[classification as keyof typeof badges] || badges.undetermined
  }

  const getCustomerDisplayName = (customer: Customer) => {
    if (customer.customer_name) return customer.customer_name
    if (customer.customer_email) return customer.customer_email
    return customer.customer_id
  }

  const handlePageChange = (page: number) => {
    router.get('/customers', { page }, { preserveState: true })
  }

  return (
    <>
      <Head title="Customers" />

      <div className="container mx-auto px-4 py-8">
        <div className="flex justify-between items-center mb-6">
          <h1 className="text-3xl font-bold">Customers</h1>
        </div>

        {customers.length === 0 ? (
          <div className="card bg-base-100 shadow-xl">
            <div className="card-body text-center">
              <h2 className="card-title justify-center">No customers yet</h2>
              <p>Customers will appear here once you have transactions with customer information.</p>
            </div>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="table table-zebra">
              <thead>
                <tr>
                  <th>Customer</th>
                  <th>Customer ID</th>
                  <th>Email</th>
                  <th>Transactions</th>
                  <th>Total Amount</th>
                  <th>EU Classification</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {customers.map((customer) => (
                  <tr key={customer.customer_id}>
                    <td className="font-semibold">{getCustomerDisplayName(customer)}</td>
                    <td className="font-mono text-sm">{customer.customer_id}</td>
                    <td>{customer.customer_email || '-'}</td>
                    <td>{customer.transaction_count}</td>
                    <td>{formatCurrency(customer.total_amount, customer.primary_currency)}</td>
                    <td>{getEuClassificationBadge(customer.eu_classification_summary)}</td>
                    <td>
                      <Link
                        href={`/customers/${customer.customer_id}`}
                        className="btn btn-sm btn-outline"
                      >
                        View Profile
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

