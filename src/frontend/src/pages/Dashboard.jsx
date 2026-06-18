import { useEffect, useState } from 'react'
import api from '../api/client'

export default function Dashboard() {
  const [data, setData] = useState(null)
  const [error, setError] = useState('')

  useEffect(() => {
    api.get('/players/me')
      .then((r) => setData(r.data))
      .catch(() => setError('No se pudo cargar el dashboard'))
  }, [])

  if (error) return <div className="error-msg">{error}</div>
  if (!data)  return <div className="loading">Cargando...</div>

  return (
    <div className="page">
      <h2>Bienvenido, {data.display_name || data.username}</h2>

      <div className="cards-row">
        <div className="card">
          <div className="card-label">Balance de Puntos</div>
          <div className="card-value">{data.balance_points.toLocaleString()} pts</div>
        </div>

        {data.money_balances && data.money_balances.length > 0
          ? data.money_balances.map((mb) => (
            <div className="card" key={mb.currency_code}>
              <div className="card-label">Balance {mb.currency_code}</div>
              <div className="card-value">
                {mb.currency_symbol}{mb.current_balance.toLocaleString('es-CR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </div>
            </div>
          ))
          : (
            <div className="card">
              <div className="card-label">Balance Dinero Real</div>
              <div className="card-value card-value--muted">Sin fondos</div>
            </div>
          )
        }

        <div className="card">
          <div className="card-label">Última actividad</div>
          <div className="card-value card-value--sm">
            {data.last_transaction_date
              ? new Date(data.last_transaction_date).toLocaleDateString('es-CR')
              : '—'}
          </div>
        </div>
      </div>
    </div>
  )
}
