import { useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import api from '../api/client'

export default function Register() {
  const { login } = useAuth()
  const navigate = useNavigate()
  const [form, setForm] = useState({ username: '', email: '', password: '', display_name: '' })
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      await api.post('/auth/register', {
        username: form.username,
        email: form.email,
        password: form.password,
        display_name: form.display_name || undefined,
      })
      await login(form.username, form.password)
      navigate('/')
    } catch (err) {
      setError(err.response?.data?.detail || 'Error al registrar usuario')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="login-container">
      <div className="login-card">
        <h1>Gathel</h1>
        <p className="login-subtitle">Crear cuenta</p>
        <form onSubmit={handleSubmit}>
          <input
            type="text"
            placeholder="Usuario *"
            value={form.username}
            onChange={(e) => setForm({ ...form, username: e.target.value })}
            required
          />
          <input
            type="email"
            placeholder="Email *"
            value={form.email}
            onChange={(e) => setForm({ ...form, email: e.target.value })}
            required
          />
          <input
            type="text"
            placeholder="Nombre para mostrar (opcional)"
            value={form.display_name}
            onChange={(e) => setForm({ ...form, display_name: e.target.value })}
          />
          <input
            type="password"
            placeholder="Contraseña *"
            value={form.password}
            onChange={(e) => setForm({ ...form, password: e.target.value })}
            required
            minLength={6}
          />
          {error && <p className="error-msg">{error}</p>}
          <button type="submit" disabled={loading}>
            {loading ? 'Creando cuenta...' : 'Registrarse'}
          </button>
        </form>
        <p className="login-hint">
          ¿Ya tienes cuenta? <Link to="/login" className="link-subtle">Inicia sesión</Link>
        </p>
      </div>
    </div>
  )
}
