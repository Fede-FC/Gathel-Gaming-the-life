import { useEffect, useState } from 'react'
import api from '../api/client'

function PredictionModal({ proposition, onClose, onSuccess }) {
  const [form, setForm] = useState({ amount: 1, currency_code: 'POINTS', direction: true })
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const handleSubmit = async (e) => {
    e.preventDefault()
    setLoading(true)
    setError('')
    try {
      await api.post('/predictions', {
        proposition_id: proposition.proposition_id,
        amount: Number(form.amount),
        currency_code: form.currency_code,
        direction: form.direction,
      })
      onSuccess()
    } catch (err) {
      setError(err.response?.data?.detail || 'Error al registrar predicción')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h3>Predecir: {proposition.title}</h3>
        <form onSubmit={handleSubmit}>
          <label>¿Se cumplirá?</label>
          <select
            value={form.direction}
            onChange={(e) => setForm({ ...form, direction: e.target.value === 'true' })}
          >
            <option value="true">Sí</option>
            <option value="false">No</option>
          </select>

          <label>Monto</label>
          <input
            type="number"
            min="1"
            step="0.01"
            value={form.amount}
            onChange={(e) => setForm({ ...form, amount: e.target.value })}
          />

          <label>Moneda</label>
          <select
            value={form.currency_code}
            onChange={(e) => setForm({ ...form, currency_code: e.target.value })}
          >
            <option value="POINTS">Puntos</option>
            <option value="USD">USD</option>
          </select>

          {error && <p className="error-msg">{error}</p>}

          <div className="modal-actions">
            <button type="button" onClick={onClose}>Cancelar</button>
            <button type="submit" disabled={loading}>
              {loading ? 'Enviando...' : 'Predecir'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

function CreatePropositionForm({ onSuccess }) {
  const [open, setOpen] = useState(false)
  const [form, setForm] = useState({
    target_username: '',
    title: '',
    description: '',
    voting_ends_at: '',
  })
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const handleSubmit = async (e) => {
    e.preventDefault()
    setLoading(true)
    setError('')
    try {
      await api.post('/propositions', {
        ...form,
        voting_ends_at: new Date(form.voting_ends_at).toISOString(),
      })
      setOpen(false)
      setForm({ target_username: '', title: '', description: '', voting_ends_at: '' })
      onSuccess()
    } catch (err) {
      setError(err.response?.data?.detail || 'Error al crear proposición')
    } finally {
      setLoading(false)
    }
  }

  if (!open) return (
    <button className="btn-primary" onClick={() => setOpen(true)}>
      + Nueva Proposición
    </button>
  )

  return (
    <div className="create-form">
      <h3>Nueva Proposición</h3>
      <form onSubmit={handleSubmit}>
        <input
          placeholder="Usuario destino"
          value={form.target_username}
          onChange={(e) => setForm({ ...form, target_username: e.target.value })}
          required
        />
        <input
          placeholder="Título de la proposición"
          value={form.title}
          onChange={(e) => setForm({ ...form, title: e.target.value })}
          required
        />
        <textarea
          placeholder="Descripción"
          value={form.description}
          onChange={(e) => setForm({ ...form, description: e.target.value })}
          rows={3}
          required
        />
        <label>Fecha límite de votación</label>
        <input
          type="datetime-local"
          value={form.voting_ends_at}
          onChange={(e) => setForm({ ...form, voting_ends_at: e.target.value })}
          required
        />
        {error && <p className="error-msg">{error}</p>}
        <div className="form-actions">
          <button type="button" onClick={() => setOpen(false)}>Cancelar</button>
          <button type="submit" disabled={loading}>
            {loading ? 'Creando...' : 'Crear'}
          </button>
        </div>
      </form>
    </div>
  )
}

export default function Propositions() {
  const [propositions, setPropositions] = useState([])
  const [selected, setSelected] = useState(null)
  const [loading, setLoading] = useState(true)

  const load = () => {
    setLoading(true)
    api.get('/propositions/active')
      .then((r) => setPropositions(r.data))
      .finally(() => setLoading(false))
  }

  useEffect(() => { load() }, [])

  return (
    <div className="page">
      <div className="page-header">
        <h2>Proposiciones Activas</h2>
        <CreatePropositionForm onSuccess={load} />
      </div>

      {loading ? (
        <div className="loading">Cargando...</div>
      ) : propositions.length === 0 ? (
        <p>No hay proposiciones activas.</p>
      ) : (
        <div className="proposition-list">
          {propositions.map((p) => (
            <div key={p.proposition_id} className="proposition-card">
              <div className="proposition-title">{p.title}</div>
              <div className="proposition-meta">
                <span>Por: {p.creator_username}</span>
                <span>Para: {p.target_username}</span>
                <span>{p.total_predictions} predicciones</span>
              </div>
              <p className="proposition-desc">{p.description}</p>
              <div className="proposition-footer">
                {p.prediction_ends_at && (
                  <span className="deadline">
                    Cierra: {new Date(p.prediction_ends_at).toLocaleString('es-CR')}
                  </span>
                )}
                <button className="btn-predict" onClick={() => setSelected(p)}>
                  Predecir
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {selected && (
        <PredictionModal
          proposition={selected}
          onClose={() => setSelected(null)}
          onSuccess={() => { setSelected(null); load() }}
        />
      )}
    </div>
  )
}
