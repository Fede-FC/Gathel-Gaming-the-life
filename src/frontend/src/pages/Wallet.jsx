import { useEffect, useState } from 'react'
import api from '../api/client'

const TX_LABELS = {
  DEPOSIT:    { label: 'Depósito',    cls: 'tx-in'  },
  WINNING:    { label: 'Ganancia',    cls: 'tx-in'  },
  REFUND:     { label: 'Reembolso',   cls: 'tx-in'  },
  WITHDRAWAL: { label: 'Retiro',      cls: 'tx-out' },
  WAGER:      { label: 'Apuesta',     cls: 'tx-out' },
  COMMISSION: { label: 'Comisión',    cls: 'tx-out' },
  PENALTY:    { label: 'Penalización',cls: 'tx-out' },
}

function fmtAmount(amount, symbol) {
  const abs = Math.abs(amount).toLocaleString('es-CR', { minimumFractionDigits: 2 })
  return `${symbol || ''}${abs}`
}

function usdEquiv(amount, rate) {
  if (!rate) return null
  return (amount * rate).toLocaleString('en-US', { style: 'currency', currency: 'USD' })
}

export default function Wallet() {
  const [currencies, setCurrencies] = useState([])
  const [balances, setBalances]     = useState([])
  const [history, setHistory]       = useState([])
  const [form, setForm]             = useState({ currency_code: '', amount: '' })
  const [loading, setLoading]       = useState(true)
  const [depositing, setDepositing] = useState(false)
  const [msg, setMsg]               = useState({ text: '', type: '' })

  const loadAll = () => {
    setLoading(true)
    Promise.all([
      api.get('/wallet/currencies'),
      api.get('/players/me'),
      api.get('/wallet/history'),
    ]).then(([cur, me, hist]) => {
      setCurrencies(cur.data)
      setBalances(me.data.money_balances || [])
      setHistory(hist.data)
      if (!form.currency_code && cur.data.length > 0)
        setForm(f => ({ ...f, currency_code: cur.data[0].currency_code }))
    }).finally(() => setLoading(false))
  }

  useEffect(() => { loadAll() }, [])

  const selectedCurrency = currencies.find(c => c.currency_code === form.currency_code)
  const amountNum = parseFloat(form.amount) || 0
  const equiv = selectedCurrency?.rate_to_usd
    ? usdEquiv(amountNum, selectedCurrency.rate_to_usd)
    : null

  const handleDeposit = async (e) => {
    e.preventDefault()
    setMsg({ text: '', type: '' })
    setDepositing(true)
    try {
      const res = await api.post('/wallet/deposit', {
        currency_code: form.currency_code,
        amount: amountNum,
      })
      setMsg({ text: res.data.message, type: 'success' })
      setForm(f => ({ ...f, amount: '' }))
      loadAll()
    } catch (err) {
      setMsg({ text: err.response?.data?.detail || 'Error al procesar depósito', type: 'error' })
    } finally {
      setDepositing(false)
    }
  }

  if (loading) return <div className="page"><div className="loading">Cargando billetera...</div></div>

  return (
    <div className="page">
      <h2>Billetera</h2>

      {/* Balances actuales */}
      <section className="wallet-section">
        <h3 className="section-title">Saldo en moneda real</h3>
        {balances.length === 0 ? (
          <p className="empty-msg">No tienes fondos en monedas reales aún.</p>
        ) : (
          <div className="cards-row">
            {balances.map(b => {
              const cur = currencies.find(c => c.currency_code === b.currency_code)
              return (
                <div className="card" key={b.currency_code}>
                  <div className="card-label">{b.currency_code} — {cur?.currency_name || ''}</div>
                  <div className="card-value">
                    {b.currency_symbol}{b.current_balance.toLocaleString('es-CR', { minimumFractionDigits: 2 })}
                  </div>
                  {cur?.rate_to_usd && (
                    <div className="card-sub">
                      ≈ {usdEquiv(b.current_balance, cur.rate_to_usd)}
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        )}
      </section>

      {/* Tipos de cambio */}
      <section className="wallet-section">
        <h3 className="section-title">Tipos de cambio vigentes</h3>
        <div className="exchange-table">
          <div className="exchange-header">
            <span>Moneda</span><span>Código</span><span>Tasa → USD</span><span>Equivalencia</span>
          </div>
          {currencies.map(c => (
            <div className="exchange-row" key={c.currency_code}>
              <span>{c.currency_name}</span>
              <span><code>{c.currency_code}</code></span>
              <span>{c.rate_to_usd ? c.rate_to_usd.toFixed(4) : '—'}</span>
              <span>
                {c.rate_to_usd
                  ? c.currency_code === 'USD'
                    ? '1 USD = 1 USD'
                    : `1 ${c.currency_code} = ${usdEquiv(1, c.rate_to_usd)}`
                  : '—'}
              </span>
            </div>
          ))}
          <div className="exchange-row exchange-note">
            <span colSpan="4">USD es la moneda base de referencia del sistema.</span>
          </div>
        </div>
      </section>

      {/* Formulario depósito */}
      <section className="wallet-section">
        <h3 className="section-title">Ingresar dinero</h3>
        <div className="deposit-card">
          <form className="deposit-form" onSubmit={handleDeposit}>
            <div className="deposit-row">
              <div className="deposit-field">
                <label>Moneda</label>
                <select
                  value={form.currency_code}
                  onChange={e => setForm(f => ({ ...f, currency_code: e.target.value }))}
                >
                  {currencies.map(c => (
                    <option key={c.currency_code} value={c.currency_code}>
                      {c.currency_symbol} {c.currency_code} — {c.currency_name}
                    </option>
                  ))}
                </select>
              </div>
              <div className="deposit-field">
                <label>Monto a depositar</label>
                <input
                  type="number"
                  min="0.01"
                  step="0.01"
                  placeholder="0.00"
                  value={form.amount}
                  onChange={e => setForm(f => ({ ...f, amount: e.target.value }))}
                  required
                />
              </div>
            </div>

            {amountNum > 0 && selectedCurrency && (
              <div className="deposit-equiv">
                {selectedCurrency.currency_symbol}{amountNum.toLocaleString('es-CR', { minimumFractionDigits: 2 })} {form.currency_code}
                {equiv && <> ≈ <strong>{equiv}</strong></>}
                {!equiv && form.currency_code === 'USD' && <> = <strong>{usdEquiv(amountNum, 1)}</strong></>}
              </div>
            )}

            {msg.text && (
              <p className={msg.type === 'success' ? 'success-msg' : 'error-msg'}>{msg.text}</p>
            )}

            <button type="submit" className="btn-primary btn-inline" disabled={depositing}>
              {depositing ? 'Procesando...' : 'Depositar'}
            </button>
          </form>
        </div>
      </section>

      {/* Historial de transacciones */}
      <section className="wallet-section">
        <h3 className="section-title">Historial de transacciones (dinero real)</h3>
        {history.length === 0 ? (
          <p className="empty-msg">Sin transacciones en monedas reales.</p>
        ) : (
          <table className="results-table">
            <thead>
              <tr>
                <th>Fecha</th>
                <th>Tipo</th>
                <th>Descripción</th>
                <th>Monto</th>
                <th>Saldo</th>
              </tr>
            </thead>
            <tbody>
              {history.map((tx, i) => {
                const meta = TX_LABELS[tx.transaction_type] || { label: tx.transaction_type, cls: '' }
                const isIn = tx.amount > 0
                return (
                  <tr key={i}>
                    <td>{new Date(tx.created_at).toLocaleDateString('es-CR')}</td>
                    <td><span className={`badge ${isIn ? 'badge-active' : 'badge-rejected'}`}>{meta.label}</span></td>
                    <td>{tx.description || '—'}</td>
                    <td className={isIn ? 'won' : 'lost'}>
                      {isIn ? '+' : ''}{fmtAmount(tx.amount, tx.currency_symbol)} {tx.currency_code}
                    </td>
                    <td>{fmtAmount(tx.running_balance, tx.currency_symbol)} {tx.currency_code}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        )}
      </section>
    </div>
  )
}
