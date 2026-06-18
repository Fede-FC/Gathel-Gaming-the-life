import { useEffect, useState, useRef } from 'react'
import api from '../api/client'

const STATUS_LABELS = {
  PENDING:          { label: 'Pendiente revisión IA', cls: 'badge-pending' },
  ACTIVE:           { label: 'Activa',                cls: 'badge-active'  },
  PREDICTION_CLOSED:{ label: 'Predicciones cerradas', cls: 'badge-closed'  },
  RESOLVED:         { label: 'Resuelta',              cls: 'badge-resolved'},
  REJECTED:         { label: 'Rechazada',             cls: 'badge-rejected'},
  CANCELLED:        { label: 'Cancelada',             cls: 'badge-rejected'},
}

/* ─── Autocomplete de usuario ─── */
function PlayerSearch({ value, onChange }) {
  const [query, setQuery]     = useState(value)
  const [results, setResults] = useState([])
  const [open, setOpen]       = useState(false)
  const timer = useRef(null)

  useEffect(() => {
    clearTimeout(timer.current)
    if (query.length < 2) { setResults([]); setOpen(false); return }
    timer.current = setTimeout(() => {
      api.get(`/players/search?q=${encodeURIComponent(query)}`)
        .then(r => { setResults(r.data); setOpen(r.data.length > 0) })
        .catch(() => {})
    }, 300)
    return () => clearTimeout(timer.current)
  }, [query])

  const select = (username) => {
    setQuery(username)
    onChange(username)
    setOpen(false)
    setResults([])
  }

  return (
    <div className="autocomplete">
      <input
        placeholder="Buscar usuario destino..."
        value={query}
        onChange={(e) => { setQuery(e.target.value); onChange(e.target.value) }}
        onBlur={() => setTimeout(() => setOpen(false), 150)}
        required
      />
      {open && (
        <ul className="autocomplete-list">
          {results.map((p) => (
            <li key={p.username} onMouseDown={() => select(p.username)}>
              <strong>{p.username}</strong>
              {p.display_name && <span className="ac-display"> — {p.display_name}</span>}
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

/* ─── Modal de predicción ─── */
function PredictionModal({ proposition, playerBalance, onClose, onSuccess }) {
  const [form, setForm]   = useState({ amount: 1, currency_code: 'POINTS', direction: true })
  const [loading, setLoading] = useState(false)
  const [error, setError]     = useState('')

  const isPoints = form.currency_code === 'POINTS'

  const handleCurrencyChange = (currency) => {
    setForm({ ...form, currency_code: currency, amount: currency === 'POINTS' ? 1 : '' })
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (isPoints && Number(form.amount) > 1) {
      setError('Con puntos solo puedes apostar máximo 1 punto por predicción.')
      return
    }
    setLoading(true); setError('')
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

  const moneyBalance = playerBalance?.money_balances?.find(mb => mb.currency_code === form.currency_code)

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h3>Predecir: {proposition.title}</h3>
        <form onSubmit={handleSubmit}>
          <label>¿Se cumplirá?</label>
          <select value={form.direction} onChange={(e) => setForm({ ...form, direction: e.target.value === 'true' })}>
            <option value="true">Sí</option>
            <option value="false">No</option>
          </select>

          <label>Moneda</label>
          <select value={form.currency_code} onChange={(e) => handleCurrencyChange(e.target.value)}>
            <option value="POINTS">Puntos (máx. 1 por predicción)</option>
            <option value="USD">USD (sin límite)</option>
          </select>

          <label>Monto</label>
          {isPoints
            ? <input type="number" value={1} readOnly className="input-locked" />
            : <input type="number" min="0.01" step="0.01" value={form.amount}
                onChange={(e) => setForm({ ...form, amount: e.target.value })} required />
          }

          <div className="balance-hint">
            {isPoints
              ? `Disponible: ${playerBalance?.balance_points?.toLocaleString() ?? '—'} pts`
              : moneyBalance
                ? `Disponible: ${moneyBalance.currency_symbol}${moneyBalance.current_balance.toLocaleString('es-CR', { minimumFractionDigits: 2 })}`
                : `Sin balance en ${form.currency_code}`
            }
          </div>

          {error && <p className="error-msg">{error}</p>}
          <div className="modal-actions">
            <button type="button" onClick={onClose}>Cancelar</button>
            <button type="submit" disabled={loading}>{loading ? 'Enviando...' : 'Predecir'}</button>
          </div>
        </form>
      </div>
    </div>
  )
}

/* ─── Modal de aceptación ─── */
function AcceptModal({ proposition, onClose, onSuccess }) {
  const [endsAt, setEndsAt] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError]     = useState('')

  const handleSubmit = async (e) => {
    e.preventDefault()
    setLoading(true); setError('')
    try {
      await api.post(`/propositions/${proposition.proposition_id}/accept`, {
        prediction_ends_at: new Date(endsAt).toISOString(),
      })
      onSuccess()
    } catch (err) {
      setError(err.response?.data?.detail || 'Error al aceptar proposición')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h3>Aceptar proposición</h3>
        <p className="modal-subtitle">{proposition.title}</p>
        <form onSubmit={handleSubmit}>
          <label>Fecha límite para recibir predicciones</label>
          <input
            type="datetime-local"
            value={endsAt}
            onChange={(e) => setEndsAt(e.target.value)}
            required
          />
          <p className="balance-hint">Al aceptar, la proposición queda disponible para que otros jugadores hagan predicciones hasta la fecha que elijas.</p>
          {error && <p className="error-msg">{error}</p>}
          <div className="modal-actions">
            <button type="button" onClick={onClose}>Cancelar</button>
            <button type="submit" disabled={loading}>{loading ? 'Aceptando...' : 'Aceptar'}</button>
          </div>
        </form>
      </div>
    </div>
  )
}

/* ─── Formulario crear proposición ─── */
function CreatePropositionForm({ onSuccess }) {
  const [open, setOpen]     = useState(false)
  const [form, setForm]     = useState({ target_username: '', title: '', description: '', voting_ends_at: '' })
  const [loading, setLoading] = useState(false)
  const [error, setError]     = useState('')
  const [success, setSuccess] = useState('')

  const handleSubmit = async (e) => {
    e.preventDefault()
    setLoading(true); setError(''); setSuccess('')
    try {
      await api.post('/propositions', { ...form, voting_ends_at: new Date(form.voting_ends_at).toISOString() })
      setOpen(false)
      setForm({ target_username: '', title: '', description: '', voting_ends_at: '' })
      setSuccess('Proposición creada. Visible en "Mis Proposiciones" mientras la IA la revisa.')
      onSuccess()
    } catch (err) {
      setError(err.response?.data?.detail || 'Error al crear proposición')
    } finally {
      setLoading(false)
    }
  }

  return (
    <>
      {success && <p className="success-msg">{success}</p>}
      {!open ? (
        <button className="btn-primary btn-inline" onClick={() => { setSuccess(''); setOpen(true) }}>
          + Nueva Proposición
        </button>
      ) : (
        <div className="create-form">
          <h3>Nueva Proposición</h3>
          <form onSubmit={handleSubmit}>
            <label>Usuario destino</label>
            <PlayerSearch
              value={form.target_username}
              onChange={(v) => setForm({ ...form, target_username: v })}
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
              <button type="submit" disabled={loading}>{loading ? 'Creando...' : 'Crear'}</button>
            </div>
          </form>
        </div>
      )}
    </>
  )
}

/* ─── Tab: Activas ─── */
function ActiveTab({ playerBalance }) {
  const [propositions, setPropositions] = useState([])
  const [selected, setSelected]         = useState(null)
  const [loading, setLoading]           = useState(true)

  const load = () => {
    setLoading(true)
    api.get('/propositions/active').then(r => setPropositions(r.data)).finally(() => setLoading(false))
  }

  useEffect(() => { load() }, [])

  if (loading) return <div className="loading">Cargando...</div>
  if (propositions.length === 0) return <p className="empty-msg">No hay proposiciones activas disponibles para predecir.</p>

  return (
    <>
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
                <span className="deadline">Cierra: {new Date(p.prediction_ends_at).toLocaleString('es-CR')}</span>
              )}
              <button className="btn-predict" onClick={() => setSelected(p)}>Predecir</button>
            </div>
          </div>
        ))}
      </div>
      {selected && (
        <PredictionModal
          proposition={selected}
          playerBalance={playerBalance}
          onClose={() => setSelected(null)}
          onSuccess={() => { setSelected(null); load() }}
        />
      )}
    </>
  )
}

/* ─── Tab: Mis Proposiciones ─── */
function MineTab({ onRefresh }) {
  const [mine, setMine]   = useState([])
  const [loading, setLoading] = useState(true)

  const load = () => {
    setLoading(true)
    api.get('/propositions/mine').then(r => setMine(r.data)).finally(() => setLoading(false))
  }

  useEffect(() => { load() }, [onRefresh])

  if (loading) return <div className="loading">Cargando...</div>
  if (mine.length === 0) return <p className="empty-msg">No has creado ninguna proposición aún.</p>

  return (
    <div className="proposition-list">
      {mine.map((p) => {
        const s = STATUS_LABELS[p.status_code] || { label: p.status_code, cls: 'badge-pending' }
        return (
          <div key={p.proposition_id} className="proposition-card">
            <div className="proposition-header">
              <div className="proposition-title">{p.title}</div>
              <span className={`badge ${s.cls}`}>{s.label}</span>
            </div>
            <div className="proposition-meta">
              <span className="prop-id">ID: {p.proposition_id}</span>
              <span>Para: {p.target_username}</span>
              {p.prediction_ends_at && (
                <span>Cierre: {new Date(p.prediction_ends_at).toLocaleString('es-CR')}</span>
              )}
            </div>
            <p className="proposition-desc">{p.description}</p>
            <div className="proposition-meta">
              <span>Creada: {new Date(p.created_at).toLocaleDateString('es-CR')}</span>
            </div>
          </div>
        )
      })}
    </div>
  )
}

/* ─── Tab: Proposiciones sobre mí ─── */
function IncomingTab({ onUpdate }) {
  const [incoming, setIncoming] = useState([])
  const [loading, setLoading]   = useState(true)
  const [accepting, setAccepting] = useState(null)
  const [msg, setMsg]           = useState('')

  const load = () => {
    setLoading(true)
    api.get('/propositions/incoming').then(r => setIncoming(r.data)).finally(() => setLoading(false))
  }

  useEffect(() => { load() }, [])

  const handleReject = async (prop) => {
    if (!window.confirm(`¿Rechazar la proposición "${prop.title}"? Perderás 1 punto.`)) return
    try {
      await api.post(`/propositions/${prop.proposition_id}/reject`)
      setMsg('Proposición rechazada. Se descontó 1 punto.')
      load(); onUpdate()
    } catch (err) {
      setMsg(err.response?.data?.detail || 'Error al rechazar')
    }
  }

  if (loading) return <div className="loading">Cargando...</div>
  if (incoming.length === 0) return <p className="empty-msg">No tienes proposiciones pendientes sobre ti.</p>

  return (
    <>
      {msg && <p className="success-msg">{msg}</p>}
      <div className="proposition-list">
        {incoming.map((p) => {
          const s = STATUS_LABELS[p.status_code] || { label: p.status_code, cls: 'badge-pending' }
          const canRespond = p.status_code === 'ACTIVE' && !p.is_accepted_by_target
          return (
            <div key={p.proposition_id} className="proposition-card">
              <div className="proposition-header">
                <div className="proposition-title">{p.title}</div>
                <div className="badge-row">
                  <span className={`badge ${s.cls}`}>{s.label}</span>
                  {p.is_accepted_by_target && <span className="badge badge-active">Aceptada</span>}
                </div>
              </div>
              <div className="proposition-meta">
                <span className="prop-id">ID: {p.proposition_id}</span>
                <span>Por: {p.creator_username}</span>
                {p.prediction_ends_at && (
                  <span>Cierre predicciones: {new Date(p.prediction_ends_at).toLocaleString('es-CR')}</span>
                )}
              </div>
              <p className="proposition-desc">{p.description}</p>
              <div className="proposition-meta">
                <span>Recibida: {new Date(p.created_at).toLocaleDateString('es-CR')}</span>
              </div>
              {canRespond && (
                <div className="incoming-actions">
                  <button className="btn-accept" onClick={() => setAccepting(p)}>Aceptar</button>
                  <button className="btn-reject-prop" onClick={() => handleReject(p)}>Rechazar (−1 pt)</button>
                </div>
              )}
            </div>
          )
        })}
      </div>
      {accepting && (
        <AcceptModal
          proposition={accepting}
          onClose={() => setAccepting(null)}
          onSuccess={() => {
            setAccepting(null)
            setMsg('Proposición aceptada. Ya está disponible para predicciones.')
            load(); onUpdate()
          }}
        />
      )}
    </>
  )
}

/* ─── Página principal ─── */
export default function Propositions() {
  const [tab, setTab]           = useState('active')
  const [mineRefresh, setMineRefresh] = useState(0)
  const [playerBalance, setPlayerBalance] = useState(null)

  useEffect(() => {
    api.get('/players/me').then(r => setPlayerBalance(r.data)).catch(() => {})
  }, [])

  const handlePropositionCreated = () => {
    setMineRefresh(n => n + 1)
    setTab('mine')
  }

  const handleUpdate = () => setMineRefresh(n => n + 1)

  return (
    <div className="page">
      <div className="page-header">
        <h2>Proposiciones</h2>
        <CreatePropositionForm onSuccess={handlePropositionCreated} />
      </div>

      <div className="tabs">
        <button className={`tab-btn ${tab === 'active'    ? 'tab-active' : ''}`} onClick={() => setTab('active')}>Activas (predecir)</button>
        <button className={`tab-btn ${tab === 'mine'      ? 'tab-active' : ''}`} onClick={() => setTab('mine')}>Mis proposiciones</button>
        <button className={`tab-btn ${tab === 'incoming'  ? 'tab-active' : ''}`} onClick={() => setTab('incoming')}>Sobre mí</button>
      </div>

      {tab === 'active'   && <ActiveTab playerBalance={playerBalance} />}
      {tab === 'mine'     && <MineTab onRefresh={mineRefresh} />}
      {tab === 'incoming' && <IncomingTab onUpdate={handleUpdate} />}
    </div>
  )
}
