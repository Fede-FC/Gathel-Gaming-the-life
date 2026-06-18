import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../api/client'

const EVENT_META = {
  PROPOSITION_CREATED:  { icon: '📝', label: 'creó una proposición' },
  AI_APPROVED:          { icon: '✅', label: 'fue aprobada por IA' },
  AI_REJECTED:          { icon: '🚫', label: 'fue rechazada por IA' },
  PROPOSITION_ACCEPTED: { icon: '🤝', label: 'aceptó una proposición' },
  PROPOSITION_REJECTED: { icon: '❌', label: 'rechazó una proposición' },
  PREDICTION_MADE:      { icon: '🎯', label: 'realizó una predicción' },
  PROPOSITION_RESOLVED: { icon: '🏆', label: 'proposición resuelta' },
}

function timeAgo(dateStr) {
  const diff = Date.now() - new Date(dateStr).getTime()
  const m = Math.floor(diff / 60000)
  if (m < 1)  return 'ahora mismo'
  if (m < 60) return `hace ${m} min`
  const h = Math.floor(m / 60)
  if (h < 24) return `hace ${h} h`
  const d = Math.floor(h / 24)
  return `hace ${d} día${d > 1 ? 's' : ''}`
}

export default function Feed() {
  const [events, setEvents]   = useState([])
  const [loading, setLoading] = useState(true)
  const navigate = useNavigate()

  const load = () => {
    setLoading(true)
    api.get('/feed?size=50')
      .then(r => setEvents(r.data))
      .finally(() => setLoading(false))
  }

  useEffect(() => { load() }, [])

  return (
    <div className="page">
      <div className="page-header">
        <h2>Actividad reciente</h2>
        <button className="btn-primary btn-inline" onClick={load}>Actualizar</button>
      </div>
      <p className="feed-subtitle">
        Ve qué está pasando en la plataforma. Cuando veas algo interesante,
        crea una proposición desde la sección <strong>Proposiciones</strong>.
      </p>

      {loading ? (
        <div className="loading">Cargando actividad...</div>
      ) : events.length === 0 ? (
        <p className="empty-msg">No hay actividad reciente.</p>
      ) : (
        <div className="feed-list">
          {events.map((ev) => {
            const meta = EVENT_META[ev.type_code] || { icon: '📌', label: ev.event_description }
            return (
              <div key={ev.event_id} className="feed-item">
                <div className="feed-icon">{meta.icon}</div>
                <div className="feed-body">
                  <div className="feed-text">
                    <strong>{ev.actor_display || ev.actor_username}</strong>
                    {' '}{meta.label}
                    {ev.proposition_title && (
                      <span
                        className="feed-prop-link"
                        onClick={() => navigate('/propositions')}
                        title={`Proposición #${ev.proposition_id}`}
                      >
                        {' '}«{ev.proposition_title}»
                      </span>
                    )}
                  </div>
                  <div className="feed-time">{timeAgo(ev.created_at)}</div>
                </div>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
