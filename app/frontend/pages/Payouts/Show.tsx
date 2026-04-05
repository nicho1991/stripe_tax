import { Head, Link, router } from '@inertiajs/react'
import { useState, useEffect } from 'react'

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
  eu_classification: 'undetermined' | 'eu' | 'non_eu' | 'stripe_fees'
  has_transaction: boolean
  transaction_id: number | null
  location_confidence_score: number
  enhanced_location_confidence_score: number
  inferred_fields: string[]
  inferred_data: {
    card_address_country?: string
    card_issue_country?: string
    shipping_address_country?: string
  }
  customer_influenced_eu_classification: 'undetermined' | 'eu' | 'non_eu' | 'stripe_fees'
  card_address_country: string | null
  card_issue_country: string | null
  shipping_address_country: string | null
  manual_country_code: string | null
  effective_eu_classification: 'undetermined' | 'eu' | 'non_eu'
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
  errors?: string[]
}

export default function Show({ payout, payments, errors: propErrors }: Props) {
  const [filterType, setFilterType] = useState<string>('all')
  const [filterEuClassification, setFilterEuClassification] = useState<string>('all')
  const [sortBy, setSortBy] = useState<'date' | 'amount' | 'net'>('date')
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc')
  const [showRenameModal, setShowRenameModal] = useState(false)
  const [showDeleteModal, setShowDeleteModal] = useState(false)
  const [newName, setNewName] = useState(payout.name)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [editingPaymentId, setEditingPaymentId] = useState<number | null>(null)
  const [editingCountryCode, setEditingCountryCode] = useState('')
  const [updatingPaymentId, setUpdatingPaymentId] = useState<number | null>(null)

  // Update name when payout changes
  useEffect(() => {
    setNewName(payout.name)
  }, [payout.name])

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

  const getEuClassificationBadge = (classification: string) => {
    const badges = {
      eu: <span className="badge badge-success badge-sm">EU</span>,
      non_eu: <span className="badge badge-error badge-sm">Non-EU</span>,
      undetermined: <span className="badge badge-warning badge-sm">Undetermined</span>,
      stripe_fees: <span className="badge badge-info badge-sm">Stripe Fees</span>,
    }
    return badges[classification as keyof typeof badges] || badges.undetermined
  }

  const filteredPayments = payments.filter((payment) => {
    if (filterType !== 'all' && payment.type !== filterType) return false
    if (filterEuClassification !== 'all') {
      // Use manual country code if set, otherwise customer-influenced if transaction exists, otherwise original
      let classificationToCheck
      if (payment.manual_country_code) {
        classificationToCheck = payment.effective_eu_classification
      } else if (payment.has_transaction) {
        classificationToCheck = payment.customer_influenced_eu_classification
      } else {
        classificationToCheck = payment.eu_classification
      }
      if (classificationToCheck !== filterEuClassification) return false
    }
    return true
  })

  // Calculate filtered stats
  const filteredTotalAmount = filteredPayments.reduce((sum, p) => sum + p.converted_amount, 0)
  const filteredTotalFees = filteredPayments.reduce((sum, p) => sum + p.fees, 0)
  const filteredTotalNet = filteredPayments.reduce((sum, p) => sum + p.net, 0)

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

  // Calculate which EU classifications exist in payments
  const hasEuPayments = payments.some((p) => {
    let classification
    if (p.manual_country_code) {
      classification = p.effective_eu_classification
    } else if (p.has_transaction) {
      classification = p.customer_influenced_eu_classification
    } else {
      classification = p.eu_classification
    }
    return classification === 'eu'
  })

  const hasNonEuPayments = payments.some((p) => {
    let classification
    if (p.manual_country_code) {
      classification = p.effective_eu_classification
    } else if (p.has_transaction) {
      classification = p.customer_influenced_eu_classification
    } else {
      classification = p.eu_classification
    }
    return classification === 'non_eu'
  })

  const hasStripeFeesClassificationPayments = payments.some((p) => {
    const classification = p.has_transaction
      ? p.customer_influenced_eu_classification
      : p.eu_classification
    return classification === 'stripe_fees'
  })

  const hasUndeterminedPayments = payments.some((p) => {
    let classification
    if (p.manual_country_code) {
      classification = p.effective_eu_classification
    } else if (p.has_transaction) {
      classification = p.customer_influenced_eu_classification
    } else {
      classification = p.eu_classification
    }
    return classification === 'undetermined'
  })

  const hasStripeFeePayments = payments.some((p) => p.type === 'Stripe Fee')

  const handleRename = (e: React.FormEvent) => {
    e.preventDefault()
    setIsSubmitting(true)
    router.put(`/payouts/${payout.id}`, {
      payout: { name: newName },
    }, {
      onFinish: () => {
        setIsSubmitting(false)
        setShowRenameModal(false)
      },
    })
  }

  const handleDelete = () => {
    setIsSubmitting(true)
    router.delete(`/payouts/${payout.id}`, {
      onFinish: () => setIsSubmitting(false),
    })
  }

  const handleUpdateCountryCode = async (paymentId: number) => {
    setUpdatingPaymentId(paymentId)
    try {
      const response = await fetch(`/payouts/${payout.id}/update_payment_country`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
        },
        body: JSON.stringify({
          payment_id: paymentId,
          manual_country_code: editingCountryCode,
        }),
      })

      const data = await response.json()
      if (data.success) {
        router.reload()
      }
    } catch (error) {
      console.error('Error updating country code:', error)
    } finally {
      setUpdatingPaymentId(null)
      setEditingPaymentId(null)
      setEditingCountryCode('')
    }
  }

  return (
    <>
      <Head title={`Payout: ${payout.name}`} />

      <div className="container mx-auto px-4 py-8">
        <div className="mb-6">
          <Link href="/payouts" className="btn btn-ghost btn-sm mb-4">
            ← Back to Payouts
          </Link>
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold">{payout.name}</h1>
              <p className="text-gray-600 mt-2">
                Period: {new Date(payout.period_start).toLocaleDateString()} -{' '}
                {new Date(payout.period_end).toLocaleDateString()}
              </p>
            </div>
            <div className="flex gap-2 flex-wrap">
              {hasEuPayments && (
                <a
                  href={`/payouts/${payout.id}/pdf_eu`}
                  className="btn btn-primary btn-sm"
                  download
                >
                  Download EU PDF
                </a>
              )}
              {hasNonEuPayments && (
                <a
                  href={`/payouts/${payout.id}/pdf_non_eu`}
                  className="btn btn-primary btn-sm"
                  download
                >
                  Download Non-EU PDF
                </a>
              )}
              {hasUndeterminedPayments && (
                <a
                  href={`/payouts/${payout.id}/pdf_undetermined`}
                  className="btn btn-primary btn-sm"
                  download
                >
                  Download Undetermined PDF
                </a>
              )}
              {hasStripeFeePayments && (
                <a
                  href={`/payouts/${payout.id}/pdf_stripe_fees`}
                  className="btn btn-primary btn-sm"
                  download
                >
                  Download Stripe Fees PDF
                </a>
              )}
              <button
                onClick={() => setShowRenameModal(true)}
                className="btn btn-outline btn-sm"
              >
                Rename
              </button>
              <button
                onClick={() => setShowDeleteModal(true)}
                className="btn btn-error btn-sm"
              >
                Delete
              </button>
            </div>
          </div>
        </div>

        {/* Rename Modal */}
        {showRenameModal && (
          <div className="modal modal-open">
            <div className="modal-box">
              <h3 className="font-bold text-lg mb-4">Rename Payout</h3>
              {propErrors && propErrors.length > 0 && (
                <div className="alert alert-error mb-4">
                  <ul className="list-disc list-inside">
                    {propErrors.map((error, index) => (
                      <li key={index}>{error}</li>
                    ))}
                  </ul>
                </div>
              )}
              <form onSubmit={handleRename}>
                <div className="form-control mb-4">
                  <label className="label">
                    <span className="label-text">Payout Name</span>
                  </label>
                  <input
                    type="text"
                    value={newName}
                    onChange={(e) => setNewName(e.target.value)}
                    className="input input-bordered w-full"
                    required
                    autoFocus
                  />
                </div>
                <div className="modal-action">
                  <button
                    type="button"
                    onClick={() => {
                      setShowRenameModal(false)
                      setNewName(payout.name)
                    }}
                    className="btn btn-ghost"
                    disabled={isSubmitting}
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="btn btn-primary"
                    disabled={isSubmitting || !newName.trim()}
                  >
                    {isSubmitting ? 'Saving...' : 'Save'}
                  </button>
                </div>
              </form>
            </div>
            <div className="modal-backdrop" onClick={() => setShowRenameModal(false)}></div>
          </div>
        )}

        {/* Delete Confirmation Modal */}
        {showDeleteModal && (
          <div className="modal modal-open">
            <div className="modal-box">
              <h3 className="font-bold text-lg mb-4">Delete Payout</h3>
              <p className="mb-4">
                Are you sure you want to delete <strong>{payout.name}</strong>? This will
                permanently delete the payout and all {payout.payments_count} associated payments.
                This action cannot be undone.
              </p>
              <div className="modal-action">
                <button
                  type="button"
                  onClick={() => setShowDeleteModal(false)}
                  className="btn btn-ghost"
                  disabled={isSubmitting}
                >
                  Cancel
                </button>
                <button
                  onClick={handleDelete}
                  className="btn btn-error"
                  disabled={isSubmitting}
                >
                  {isSubmitting ? 'Deleting...' : 'Delete Payout'}
                </button>
              </div>
            </div>
            <div className="modal-backdrop" onClick={() => setShowDeleteModal(false)}></div>
          </div>
        )}

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
          <div className="stat bg-base-200 rounded-lg shadow">
            <div className="stat-title">
              Total Amount ({payout.primary_currency})
              {filteredPayments.length !== payments.length && (
                <span className="text-xs font-normal text-gray-500 ml-2">
                  ({filteredPayments.length} of {payments.length})
                </span>
              )}
            </div>
            <div className="stat-value text-2xl">
              {formatCurrency(filteredTotalAmount, payout.primary_currency)}
            </div>
          </div>
          <div className="stat bg-base-200 rounded-lg shadow">
            <div className="stat-title">Total Fees ({payout.primary_currency})</div>
            <div className="stat-value text-2xl text-warning">
              {formatCurrency(filteredTotalFees, payout.primary_currency)}
            </div>
          </div>
          <div className="stat bg-base-200 rounded-lg shadow">
            <div className="stat-title">Total Net ({payout.primary_currency})</div>
            <div className="stat-value text-2xl text-success">
              {formatCurrency(filteredTotalNet, payout.primary_currency)}
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
                  <span className="label-text">Filter by EU Classification</span>
                </label>
                <select
                  className="select select-bordered"
                  value={filterEuClassification}
                  onChange={(e) => setFilterEuClassification(e.target.value)}
                >
                  <option value="all">All</option>
                  <option value="undetermined">Undetermined</option>
                  <option value="eu">EU</option>
                  <option value="non_eu">Non-EU</option>
                  {hasStripeFeesClassificationPayments && (
                    <option value="stripe_fees">Stripe Fees</option>
                  )}
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
                     <th>Manual Country</th>
                     <th>EU Classification</th>
                     <th>Confidence</th>
                     <th>Amount</th>
                     <th>Fees</th>
                     <th>Net</th>
                     <th>Currency</th>
                     <th>Actions</th>
                   </tr>
                 </thead>
                 <tbody>
                   {sortedPayments.map((payment) => {
                     const displayClassification = payment.manual_country_code
                       ? payment.effective_eu_classification
                       : (payment.has_transaction ? payment.customer_influenced_eu_classification : payment.eu_classification)

                     return (
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
                           {payment.customer_link ? (
                             <Link
                               href={payment.customer_link}
                               className="link link-info"
                             >
                               {payment.customer_name || payment.customer_email || payment.customer_id || 'View Customer'}
                             </Link>
                           ) : (
                             payment.customer_name || payment.customer_email || 'N/A'
                           )}
                         </td>
                         <td>
                           {editingPaymentId === payment.id ? (
                             <div className="flex gap-1 items-start">
                               <input
                                 type="text"
                                 list={`country-options-${payment.id}`}
                                 className="input input-bordered input-sm w-20"
                                 placeholder="US"
                                 value={editingCountryCode}
                                 onChange={(e) => setEditingCountryCode(e.target.value.toUpperCase())}
                                 maxLength={2}
                                 autoFocus
                                 onKeyDown={(e) => {
                                   if (e.key === 'Enter') {
                                     e.preventDefault()
                                     handleUpdateCountryCode(payment.id)
                                   } else if (e.key === 'Escape') {
                                     setEditingPaymentId(null)
                                     setEditingCountryCode('')
                                   }
                                 }}
                               />
                               <datalist id={`country-options-${payment.id}`}>
                                 {[
                                   payment.card_issue_country,
                                   payment.card_address_country,
                                   payment.shipping_address_country,
                                   ...Object.values(payment.inferred_data).filter(Boolean)
                                 ]
                                   .filter((code): code is string => Boolean(code))
                                   .filter((code, index, self) => self.indexOf(code) === index)
                                   .map((code) => (
                                     <option key={code} value={code.toUpperCase()}>
                                       {code.toUpperCase()}
                                     </option>
                                   ))}
                               </datalist>
                               <div className="flex gap-1">
                                 <button
                                   className="btn btn-sm btn-primary"
                                   onClick={() => handleUpdateCountryCode(payment.id)}
                                   disabled={updatingPaymentId === payment.id}
                                 >
                                   {updatingPaymentId === payment.id ? '...' : '✓'}
                                 </button>
                                 <button
                                   className="btn btn-sm btn-ghost"
                                   onClick={() => {
                                     setEditingPaymentId(null)
                                     setEditingCountryCode('')
                                   }}
                                 >
                                   ✕
                                 </button>
                               </div>
                             </div>
                           ) : (
                             <div className="flex items-center gap-1">
                               {payment.manual_country_code ? (
                                 <div className="flex items-center gap-1">
                                   <code className="badge badge-info">{payment.manual_country_code.toUpperCase()}</code>
                                   <button
                                     className="btn btn-xs btn-ghost"
                                     onClick={() => {
                                       setEditingPaymentId(payment.id)
                                       setEditingCountryCode('')
                                     }}
                                     title="Edit country code"
                                   >
                                     ✏️
                                   </button>
                                 </div>
                               ) : (
                                 <button
                                   className="btn btn-xs btn-outline"
                                   onClick={() => {
                                     setEditingPaymentId(payment.id)
                                     setEditingCountryCode('')
                                   }}
                                   title="Set manual country code"
                                 >
                                   Set
                                 </button>
                               )}
                             </div>
                           )}
                         </td>
                         <td>
                           {payment.manual_country_code ? (
                             <div className="flex items-center gap-1">
                               {getEuClassificationBadge(displayClassification)}
                               <span className="text-xs text-info" title="Manual override">
                                ⚙️
                               </span>
                             </div>
                           ) : payment.has_transaction ? (
                             payment.customer_influenced_eu_classification !== payment.eu_classification ? (
                               <div className="flex items-center gap-1">
                                 {getEuClassificationBadge(displayClassification)}
                                 <span className="text-xs text-info" title="Customer-influenced (different from original)">
                                   *
                                 </span>
                               </div>
                             ) : (
                               getEuClassificationBadge(displayClassification)
                             )
                           ) : (
                             getEuClassificationBadge(displayClassification)
                           )}
                         </td>
                         <td>
                           {payment.has_transaction ? (
                             payment.enhanced_location_confidence_score > payment.location_confidence_score ? (
                               <span className="badge badge-info" title="Enhanced using other customer transactions">
                                 {payment.enhanced_location_confidence_score}/3
                                 <span className="text-xs ml-1">↑</span>
                               </span>
                             ) : (
                               <span className="badge badge-outline">
                                 {payment.enhanced_location_confidence_score}/3
                               </span>
                             )
                           ) : (
                             <span className="text-gray-400 text-sm">-</span>
                           )}
                         </td>
                         <td>{formatCurrency(payment.amount, payment.currency)}</td>
                         <td>{formatCurrency(payment.fees, payment.converted_currency)}</td>
                         <td className="font-semibold">
                           {formatCurrency(payment.net, payment.converted_currency)}
                         </td>
                         <td>
                           {payment.converted_currency || payment.currency || 'N/A'}
                         </td>
                         <td>
                           {payment.has_transaction && payment.transaction_id ? (
                             <Link
                               href={`/transactions/${payment.transaction_id}`}
                               className="btn btn-sm btn-outline"
                               title="View detailed transaction information"
                             >
                               View
                             </Link>
                           ) : (
                             <span className="text-gray-400 text-sm">No transaction</span>
                           )}
                         </td>
                       </tr>
                     )
                   })}
                 </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </>
  )
}

