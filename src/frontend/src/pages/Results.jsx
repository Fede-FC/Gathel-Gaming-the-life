import { useEffect, useState } from 'react'
import api from '../api/client'

export default function Results() {
  const [results, setResults] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    api.get('/propositions/results')
      .then((r) => setResults(r.data))
      .finally(() => setLoading(false))
  }, [])

  if (loading) return <div className="loading">Cargando...</div>

  return (
    <div className="page">
      <h2>Resultados Finalizados</h2>

      {results.length === 0 ? (
        <p>Aún no tienes predicciones en proposiciones finalizadas.</p>
      ) : (
        <table className="results-table">
          <thead>
            <tr>
              <th>Proposición</th>
              <th>Resultado</th>
              <th>Tu predicción</th>
              <th>Monto</th>
              <th>Estado</th>
              <th>Resuelta</th>
            </tr>
          </thead>
          <tbody>
            {results.map((r, i) => (
              <tr key={i}>
                <td>{r.title}</td>
                <td>{r.is_fulfilled === null ? '—' : r.is_fulfilled ? '✅ Se cumplió' : '❌ No se cumplió'}</td>
                <td>{r.direction === null ? '—' : r.direction ? 'Se cumple' : 'No se cumple'}</td>
                <td>{r.amount ? `${r.amount} ${r.currency_code}` : '—'}</td>
                <td className={r.result === 'WON' ? 'won' : r.result === 'LOST' ? 'lost' : ''}>
                  {r.result || 'PENDING'}
                </td>
                <td>{r.resolved_at ? new Date(r.resolved_at).toLocaleDateString('es-CR') : '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  )
}
